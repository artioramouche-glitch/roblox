/**
 * blender_image_to_3d: the "blender-image-to-3d" skill (integrations/blender-image-to-3d, MIT,
 * Majid Manzarpour) inside the MCP, for every AI client. Reference images become a game-ready
 * model through measured gates: calibrated master .blend, re-runnable build scripts, renders
 * compared to the reference (silhouette IoU, band widths), validation, baking.
 *
 * The skill's scripts open, rebuild and save the master file, so they run in a separate
 * background Blender (blender --background --python <script> -- <args>) and never touch the
 * scene open in the user's Blender. "load" then appends the result into that open Blender,
 * where blender_scene and blender_to_roblox take over.
 */

import { execFile } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import type { BlenderClient } from './blender.js';
import { text, withImages, type ToolResult } from './result.js';
import { PathFinder } from '../managers/path-finder.js';

export const SKILL_SCRIPTS = ['init_master', 'review_render', 'compose_review', 'world_gate', 'validate', 'bake_maps', 'export_delivery', 'roundtrip'] as const;

const GUIDE_FILES: Record<string, string> = {
  skill: 'SKILL.md',
  categories: path.join('references', 'categories.md'),
  delivery: path.join('references', 'delivery-and-acceptance.md'),
  rigging: path.join('references', 'rigging-animation.md'),
  blender5: path.join('references', 'blender-5-notes.md'),
};

/** What to do with a script's output, for models that need the next step spelled out. */
const NEXT: Record<string, string> = {
  init_master: 'Write the blockout: blender_image_to_3d { action: "build", master, phase: "02_blockout", code }.',
  build: 'Gate it: run review_render on the master (--mode clay, --ref-cam AZ EL LENS), then compose_review against the matching reference view.',
  review_render: 'Compare each render with its reference view: run compose_review { args: ["--ref", <ref>, "--render", <render png>, "--out", <sheet png>, "--measure", "--gameplay-px", "128"] }.',
  compose_review: 'Under the phase tolerance (blockout IoU >= 0.85, bands within 0.05; forms 0.90 / 0.03)? Then the next phase. Otherwise write the misses as measurements, fix the constants in the build code, build again.',
  world_gate: 'Hold the iou to the phase tolerance; red = only in the reference (missing), blue = only in the model (too much).',
  validate: 'Fix every FAIL (exit 1) and explain each warning before baking.',
  bake_maps: 'Gate: review_render --mode material --turntable 12 on the baked file. Then load it into the open Blender.',
  export_delivery: 'Check the export with roundtrip { args: ["--file", <exported file>, "--out", <dir>, "--expect-height", <m>] }.',
  roundtrip: 'For Roblox, send it with load + blender_to_roblox instead of uploading this file.',
  load: 'Look at it with blender_scene { object, screenshot: true, reference }, then blender_to_roblox { name, objects: [<collection>] } (ask before uploading).',
};

/** The skill folder: next to dist/ in the npm package (blender/image-to-3d), integrations/ in a clone. */
export function findSkillDir(): string | null {
  if (process.env.BLENDER_IMAGE_TO_3D_DIR && fs.existsSync(path.join(process.env.BLENDER_IMAGE_TO_3D_DIR, 'SKILL.md'))) return process.env.BLENDER_IMAGE_TO_3D_DIR;
  return PathFinder.find({ shapes: [['blender', 'image-to-3d'], ['integrations', 'blender-image-to-3d']], requireAll: ['SKILL.md', path.join('scripts', 'init_master.py')] });
}

/** Where the Blender binary usually is when it is not on PATH. */
function installedBlenders(): string[] {
  if (process.platform === 'darwin') return ['/Applications/Blender.app/Contents/MacOS/Blender'];
  if (process.platform !== 'win32') return [];
  const root = path.join(process.env.ProgramFiles || 'C:\\Program Files', 'Blender Foundation');
  if (!fs.existsSync(root)) return [];
  return fs.readdirSync(root)
    .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
    .map((dir) => path.join(root, dir, 'blender.exe'));
}

/** The folder a script writes to: the value of --out (its parent when --out is a file). */
export function outputDir(argv: string[]): string | undefined {
  const at = argv.indexOf('--out');
  const out = at >= 0 ? argv[at + 1] : undefined;
  if (!out) return undefined;
  return path.extname(out) ? path.dirname(out) : out;
}

/** Fills the skill's build template: our phase name, the AI's build(scene, args). */
export function buildScript(template: string, phase: string, code: string): string {
  const start = template.indexOf('\ndef build(scene, args):');
  const end = template.indexOf('\nif __name__ == "__main__":');
  if (start < 0 || end < start || !/^PHASE = ".*"/m.test(template)) throw new Error('assets/build_template.py changed: its build() or PHASE line was not found.');
  return `${template.slice(0, start).replace(/^PHASE = ".*"/m, `PHASE = ${JSON.stringify(phase)}`)}\n${code.trim()}\n\n${template.slice(end)}`;
}

/** Appends collections of a .blend into the open Blender, in one collection named after the asset. */
export function loadPython(req: { path: string; name: string; collections: string[] }): string {
  return `
import bpy, json, re
REQ = json.loads(${JSON.stringify(JSON.stringify(req))})
def drop(o):
    data = o.data
    bpy.data.objects.remove(o, do_unlink=True)
    if data is not None and data.users == 0:
        if isinstance(data, bpy.types.Mesh):
            bpy.data.meshes.remove(data)
        elif isinstance(data, bpy.types.Armature):
            bpy.data.armatures.remove(data)
        elif isinstance(data, bpy.types.Curve):
            bpy.data.curves.remove(data)

target = bpy.data.collections.get(REQ["name"])
if target is None:
    target = bpy.data.collections.new(REQ["name"])
    bpy.context.scene.collection.children.link(target)
# a reload replaces the previous copy (materials and textures too), so names stay free of .001
old_mats = set()
for o in list(target.all_objects):
    old_mats.update(s.material for s in o.material_slots if s.material)
    drop(o)
old_images = set(n.image for m in old_mats if m.node_tree for n in m.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image)
for m in old_mats:
    if m.users == 0:
        bpy.data.materials.remove(m)
for img in old_images:
    if img.users == 0:
        bpy.data.images.remove(img)
with bpy.data.libraries.load(REQ["path"], link=False) as (src, dst):
    missing = [c for c in REQ["collections"] if c not in src.collections]
    dst.collections = [c for c in REQ["collections"] if c in src.collections]
loaded, skipped = [], []
lod = re.compile(r"_LOD[1-9]\\d*$")
for c in dst.collections:
    for o in c.all_objects:
        if lod.search(o.name):
            skipped.append(o.name)  # Roblox makes its own mesh LODs
        elif o.name not in target.objects:
            target.objects.link(o)
            loaded.append(o)
    bpy.data.collections.remove(c)
for n in skipped:
    o = bpy.data.objects.get(n)
    if o is not None and not o.users_collection:
        drop(o)
# the skill sets only the shader; blender_scene (Workbench) shows the viewport display colour
for m in {s.material for o in loaded for s in o.material_slots if s.material and s.material.node_tree}:
    bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf and not bsdf.inputs["Base Color"].is_linked:
        m.diffuse_color = bsdf.inputs["Base Color"].default_value
        m.metallic = bsdf.inputs["Metallic"].default_value
        m.roughness = bsdf.inputs["Roughness"].default_value
tris = sum(sum(max(0, len(p.vertices) - 2) for p in o.data.polygons) for o in loaded if o.type == 'MESH')
# the marker BlenderClient.pythonJson reads (not imported: blender.ts imports this module)
print("@@GAMEKIT@@" + json.dumps({"collection": target.name, "objects": [o.name for o in loaded], "triangles": tris,
                                  "skippedLods": skipped, "missingCollections": missing}))
`;
}

export class ImageTo3d {
  private bin?: string;

  constructor(private client: BlenderClient) {}

  async call(args: Record<string, any>): Promise<ToolResult> {
    const dir = findSkillDir();
    if (!dir) throw new Error('The blender-image-to-3d skill folder was not found (integrations/blender-image-to-3d in the repo, blender/image-to-3d in the npm package). Set BLENDER_IMAGE_TO_3D_DIR to it.');
    const action = String(args.action ?? 'guide');
    const timeoutMs = Math.max(30, Math.min(3600, Number(args.timeout) || 600)) * 1000;
    switch (action) {
      case 'guide': return this.guide(dir, String(args.topic ?? 'skill'));
      case 'run': {
        const script = String(args.script ?? '');
        if (!(SKILL_SCRIPTS as readonly string[]).includes(script)) throw new Error(`script must be one of: ${SKILL_SCRIPTS.join(', ')}`);
        // compose_review.py needs a system Python with Pillow; this port runs in Blender's own Python
        const file = script === 'compose_review' ? 'compose_review_bpy.py' : `${script}.py`;
        return this.headless(path.join(dir, 'scripts', file), Array.isArray(args.args) ? args.args.map(String) : [], timeoutMs, script);
      }
      case 'build': return this.build(dir, args, timeoutMs);
      case 'load': return this.load(args);
      default: throw new Error('action must be guide, run, build or load');
    }
  }

  private guide(dir: string, topic: string): ToolResult {
    if (topic === 'template') {
      // the helper signatures and their first docstring line, not the 600-line file
      const lines = fs.readFileSync(path.join(dir, 'assets', 'build_template.py'), 'utf8').split(/\r?\n/);
      const helpers = lines.flatMap((line, i) => {
        if (!/^def \w+\(/.test(line)) return [];
        let end = i;
        while (!/\):$/.test(lines[end]) && end < i + 5) end++; // signatures that wrap
        const signature = lines.slice(i, end + 1).map((l) => l.trim()).join(' ').replace(/:$/, '');
        const doc = /^\s+"""/.test(lines[end + 1] ?? '') ? `  # ${lines[end + 1].trim().replace(/"""/g, '')}` : '';
        return [`${signature}${doc}`];
      });
      return text({ file: path.join(dir, 'assets', 'build_template.py'), helpers, write: 'action "build" with code defining build(scene, args); objects you make get own(ob) so a rebuild replaces them.' });
    }
    const file = GUIDE_FILES[topic];
    if (!file) throw new Error(`topic must be one of: ${[...Object.keys(GUIDE_FILES), 'template'].join(', ')}`);
    const body = fs.readFileSync(path.join(dir, file), 'utf8');
    return text(`${body}\n\n(Through this MCP: each "scripts/X.py -- args" command above is blender_image_to_3d { action: "run", script: "X", args: [...] } with absolute paths; build/NN_phase.py is action "build". Roblox version of the phases: roblox_guide image3d.)`);
  }

  private async build(dir: string, args: Record<string, any>, timeoutMs: number): Promise<ToolResult> {
    const master = String(args.master ?? '');
    const phase = String(args.phase ?? '');
    if (!path.isAbsolute(master) || !master.endsWith('.blend')) throw new Error('"master" must be the absolute path of the master .blend (made by script init_master)');
    if (!/^[\w-]+$/.test(phase)) throw new Error('"phase" is required: letters, digits, _ and - only, e.g. "02_blockout"');
    const file = path.join(path.dirname(master), 'build', `${phase}.py`);
    if (args.code !== undefined) {
      const code = String(args.code);
      if (!/^def build\(/m.test(code)) throw new Error('code must define build(scene, args) (a top-level "def build(scene, args):")');
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, buildScript(fs.readFileSync(path.join(dir, 'assets', 'build_template.py'), 'utf8'), phase, code));
    } else if (!fs.existsSync(file)) {
      throw new Error(`No ${file} yet: pass code (a build(scene, args) function) to write it.`);
    }
    return this.headless(file, ['--master', master], timeoutMs, 'build', { script: file });
  }

  private async load(args: Record<string, any>): Promise<ToolResult> {
    const file = String(args.master ?? '');
    if (!path.isAbsolute(file) || !file.endsWith('.blend')) throw new Error('"master" must be the absolute path of the .blend to load (the _baked.blend once textures are baked)');
    const name = String(args.name ?? path.basename(file, '.blend').replace(/_(master|baked)$/, '')).replace(/[^\w-]/g, '_');
    const collections = Array.isArray(args.collections) && args.collections.length ? args.collections.map(String) : ['LOW', 'RIG_DEF'];
    const loaded = await this.client.pythonJson(loadPython({ path: file, name, collections }), 120_000);
    return text({ ok: true, ...loaded, next: NEXT.load });
  }

  /** The Blender to run headless: BLENDER_BIN, the one the user has open, then the usual install places. */
  async binary(): Promise<string> {
    const env = process.env.BLENDER_BIN || process.env.BLENDER_EXE;
    if (env) return env;
    if (this.bin) return this.bin;
    const live = await this.client.python('import bpy\nprint(bpy.app.binary_path)', 10_000).then((s) => s.trim()).catch(() => '');
    this.bin = [live, ...installedBlenders()].find((p) => p && fs.existsSync(p)) || 'blender';
    return this.bin;
  }

  private async headless(script: string, argv: string[], timeoutMs: number, label: string, extra: Record<string, unknown> = {}): Promise<ToolResult> {
    const bin = await this.binary();
    const started = Date.now() - 500;
    // --python-exit-code: a Python exception fails the run instead of exiting 0
    const run = await new Promise<{ code: number | null; stdout: string; stderr: string; error?: NodeJS.ErrnoException }>((resolve) => {
      execFile(bin, ['--background', '--python-exit-code', '1', '--python', script, '--', ...argv], { timeout: timeoutMs, maxBuffer: 64 * 1024 * 1024, windowsHide: true }, (error, stdout, stderr) => {
        resolve({ code: error ? (typeof error.code === 'number' ? error.code : null) : 0, stdout: String(stdout), stderr: String(stderr), error: error as NodeJS.ErrnoException | undefined });
      });
    });
    if (run.error?.code === 'ENOENT') {
      throw new Error(`Blender not found ("${bin}"). Set BLENDER_BIN to the Blender executable (e.g. C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe), or connect Blender (N > MCP for Blender > Connect) so the MCP can ask it.`);
    }
    const timedOut = (run.error as { killed?: boolean } | undefined)?.killed === true;
    // render progress, Blender's banner and the MCP addon's own lines are noise
    const log = `${run.stdout}\n${run.stderr}`.split(/\r?\n/).filter((l) => l.trim() && !/^(Fra:\d+|BlenderMCP\b|Blender \d|Blender quit)/.test(l));
    const out = outputDir(argv);
    const files = out && fs.existsSync(out)
      ? fs.readdirSync(out).map((f) => path.join(out, f)).filter((f) => fs.statSync(f).isFile() && fs.statSync(f).mtimeMs >= started)
      : [];
    const json: Record<string, unknown> = {};
    for (const f of files.filter((f) => f.endsWith('.json'))) {
      const body = fs.readFileSync(f, 'utf8');
      try {
        json[path.basename(f)] = body.length > 8000 ? `${body.slice(0, 8000)}... (truncated, read ${f})` : JSON.parse(body);
      } catch {
        json[path.basename(f)] = body.slice(0, 2000);
      }
    }
    // compare sheets and gate diffs first: they are what the AI must look at
    const rank = (f: string) => (/compare|diff_/.test(path.basename(f)) ? 0 : /turntable_(0[1-9]|[1-9])/.test(f) ? 2 : 1);
    const images = files.filter((f) => /\.(png|jpe?g)$/i.test(f) && fs.statSync(f).size < 4 * 1024 * 1024).sort((a, b) => rank(a) - rank(b)).slice(0, 6);
    const summary = {
      ok: run.code === 0,
      exitCode: run.code,
      problem: timedOut ? `Stopped after ${timeoutMs / 1000}s: raise timeout, or run it with start_job.` : undefined,
      ...extra,
      log: log.slice(-60).join('\n').slice(-6000),
      files: files.map((f) => path.basename(f)),
      outDir: out,
      json,
      next: run.code === 0 ? NEXT[label] : 'Read the log: fix the arguments or the build code, then run it again ("--help" in args lists the options).',
    };
    return withImages(summary, images.map((f) => ({ label: path.basename(f), data: fs.readFileSync(f).toString('base64'), mimeType: /\.png$/i.test(f) ? 'image/png' : 'image/jpeg' })));
  }
}
