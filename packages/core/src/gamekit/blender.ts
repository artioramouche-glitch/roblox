/**
 * Blender bridge. Talks straight to the "MCP for Blender" addon
 * (integrations/blender-mcp/addon.py) over its local TCP socket, so the AI gets Blender
 * and Roblox Studio through ONE MCP server: no Python MCP server, no telemetry.
 *
 * Protocol (addon side): one JSON object {type, params} per command, answered by one JSON
 * object {status: "success"|"error", result | message}. Commands run one at a time on
 * Blender's main thread, so they are queued here too.
 *
 * blender_to_roblox is the pipeline: export the Blender model (triangle budget, texture
 * and material checks) -> upload it as a Roblox Model (Open Cloud) -> insert it in Studio,
 * scaled from meters to studs and standing on the ground.
 */

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import type { GameKitHost, ToolDef } from './tools.js';
import { errorMessage, resultJson, sleep, text, vec3, withImages, type ToolResult, type Vec3 } from './result.js';
import { placeModelLuau } from './props.js';
import { runLuauJson } from './installer.js';
import { PathFinder } from '../managers/path-finder.js';

/** 1 stud = 0.28 m (Roblox avatar scale), so a 1.8 m human is ~6.4 studs. */
export const STUDS_PER_METER = 1 / 0.28;
export const DEFAULT_MAX_TRIANGLES = 20000;

export class BlenderOfflineError extends Error {
  constructor(host: string, port: number) {
    super(`Blender is not reachable on ${host}:${port}. ${BLENDER_SETUP.join(' ')}`);
  }
}

export const BLENDER_SETUP = [
  '1. Install Blender 3.0+ (4.x recommended) from blender.org.',
  '2. Install the addon once: Blender > Edit > Preferences > Add-ons > Install from disk > choose integrations/blender-mcp/addon.py from this repo (or run "npm run install-blender-addon"), then tick "Interface: MCP for Blender".',
  '3. In the 3D viewport press N > tab "MCP for Blender" > "Connect to MCP server" (port 9876).',
  '4. Call blender_status again.',
];

interface BlenderReply {
  status?: string;
  result?: unknown;
  message?: string;
}

export class BlenderClient {
  private chain: Promise<unknown> = Promise.resolve();

  constructor(
    readonly host = process.env.BLENDER_HOST || '127.0.0.1',
    readonly port = Number(process.env.BLENDER_PORT || 9876),
  ) {}

  /** Sends one command; commands are serialised (the addon handles one at a time). */
  command<T = any>(type: string, params: Record<string, unknown> = {}, timeoutMs = 180_000): Promise<T> {
    const run = () => this.send<T>(type, params, timeoutMs);
    const next = this.chain.then(run, run);
    this.chain = next.catch(() => undefined);
    return next;
  }

  private send<T>(type: string, params: Record<string, unknown>, timeoutMs: number): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const socket = net.createConnection({ host: this.host, port: this.port });
      const chunks: Buffer[] = [];
      let settled = false;
      const finish = (error: Error | null, value?: T) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        socket.destroy();
        if (error) reject(error);
        else resolve(value as T);
      };
      const timer = setTimeout(() => finish(new Error(`Blender did not answer "${type}" within ${Math.round(timeoutMs / 1000)}s (is a modal dialog open in Blender?)`)), timeoutMs);
      socket.on('connect', () => socket.write(JSON.stringify({ type, params })));
      socket.on('data', (chunk) => {
        chunks.push(chunk);
        let reply: BlenderReply;
        try {
          reply = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        } catch {
          return; // incomplete JSON: wait for more
        }
        if (reply.status === 'error') finish(new Error(reply.message || `Blender command "${type}" failed`));
        else finish(null, (reply.result ?? {}) as T);
      });
      socket.on('error', (error: NodeJS.ErrnoException) => {
        finish(error.code === 'ECONNREFUSED' || error.code === 'ECONNRESET' ? new BlenderOfflineError(this.host, this.port) : error);
      });
      socket.on('close', () => finish(new Error(`Blender closed the connection before answering "${type}"`)));
    });
  }

  /** Runs Python in Blender and returns what it printed. */
  async python(code: string, timeoutMs?: number): Promise<string> {
    const result = await this.command<{ result?: string }>('execute_code', { code }, timeoutMs);
    return String(result?.result ?? '');
  }

  /** Runs one of our own snippets that prints `MARKER{json}` and returns the parsed JSON. */
  async pythonJson<T = any>(code: string, timeoutMs?: number): Promise<T> {
    const output = await this.python(code, timeoutMs);
    const at = output.lastIndexOf(MARKER);
    if (at < 0) throw new Error(`Blender script returned no result. Output: ${output.slice(0, 500) || '(none)'}`);
    return JSON.parse(output.slice(at + MARKER.length).trim().split('\n')[0]) as T;
  }
}

const MARKER = '@@GAMEKIT@@';

/** Python literal for a JSON-able value (JSON is valid Python after json.loads). */
function pyJson(value: unknown): string {
  return `json.loads(${JSON.stringify(JSON.stringify(value ?? null))})`;
}

// --- Python snippets ---------------------------------------------------------------------------

export function sceneSummaryPython(): string {
  return `
import bpy, json
scene = bpy.context.scene
objs = []
for o in scene.objects:
    item = {"name": o.name, "type": o.type, "location": [round(v, 3) for v in o.location], "dimensions_m": [round(v * scene.unit_settings.scale_length, 3) for v in o.dimensions]}
    if o.type == 'MESH' and o.data:
        item["triangles"] = sum(max(0, len(p.vertices) - 2) for p in o.data.polygons)
        item["materials"] = [s.material.name for s in o.material_slots if s.material]
    objs.append(item)
out = {"scene": scene.name, "blender": bpy.app.version_string, "unitScale": scene.unit_settings.scale_length,
       "objectCount": len(objs), "objects": objs[:80], "moreObjects": max(0, len(objs) - 80)}
print("${MARKER}" + json.dumps(out))
`;
}

export interface ExportRequest {
  objects?: string[];
  format: 'fbx' | 'glb';
  path: string;
  maxTriangles: number;
  decimate: boolean;
  textureMax: number;
}

/**
 * Exports meshes for Roblox without touching the user's scene for good: a temporary
 * Decimate modifier brings heavy meshes under the triangle budget during export only.
 */
export function exportPython(req: ExportRequest): string {
  return `
import bpy, json, os
from mathutils import Vector
REQ = ${pyJson(req)}
out = {"warnings": [], "objects": []}
try:
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
except Exception:
    pass
scene = bpy.context.scene
picked = []
if REQ.get("objects"):
    for n in REQ["objects"]:
        o = bpy.data.objects.get(n)
        if o is None:
            out["warnings"].append("Object not found in Blender: " + n)
            continue
        picked.append(o)
        picked.extend(o.children_recursive)
else:
    picked = [o for o in scene.objects if o.visible_get()]
meshes = []
for o in picked:
    if o.type == 'MESH' and o not in meshes:
        meshes.append(o)
if not meshes:
    raise Exception("Nothing to export: no visible mesh (create/import a model first, or pass objects: [names]).")
depsgraph = bpy.context.evaluated_depsgraph_get()
lo = Vector((1e18, 1e18, 1e18))
hi = Vector((-1e18, -1e18, -1e18))
added = []
total = 0
for o in meshes:
    ev = o.evaluated_get(depsgraph)
    me = ev.to_mesh()
    tris = sum(max(0, len(p.vertices) - 2) for p in me.polygons)
    ev.to_mesh_clear()
    for corner in o.bound_box:
        w = o.matrix_world @ Vector(corner)
        lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
        hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    mats = [s.material for s in o.material_slots if s.material]
    info = {"name": o.name, "triangles": tris, "materials": len(mats)}
    if tris > REQ["maxTriangles"]:
        if REQ["decimate"]:
            ratio = max(0.01, (REQ["maxTriangles"] * 0.95) / tris)
            mod = o.modifiers.new("GameKitDecimate", 'DECIMATE')
            mod.ratio = ratio
            added.append((o, mod.name))
            info["exportedTriangles"] = int(tris * ratio)
            out["warnings"].append("%s had %d triangles: decimated to ~%d for Roblox (limit %d per mesh)." % (o.name, tris, int(tris * ratio), REQ["maxTriangles"]))
        else:
            out["warnings"].append("%s has %d triangles (Roblox limit %d per mesh): the upload may be rejected." % (o.name, tris, REQ["maxTriangles"]))
    total += info.get("exportedTriangles", tris)
    if len(mats) > 1:
        out["warnings"].append("%s uses %d materials: Roblox splits it into one MeshPart per material." % (o.name, len(mats)))
    for m in mats:
        if m.use_nodes and m.node_tree:
            for node in m.node_tree.nodes:
                img = getattr(node, "image", None)
                if node.type == 'TEX_IMAGE' and img and max(img.size[0], img.size[1]) > REQ["textureMax"]:
                    out["warnings"].append("Texture %s is %dx%d: Roblox downsizes textures above %d px." % (img.name, img.size[0], img.size[1], REQ["textureMax"]))
    out["objects"].append(info)
for o in bpy.context.view_layer.objects:
    try:
        o.select_set(False)
    except Exception:
        pass
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
os.makedirs(os.path.dirname(REQ["path"]), exist_ok=True)
try:
    if REQ["format"] == "fbx":
        bpy.ops.export_scene.fbx(filepath=REQ["path"], use_selection=True, object_types={'MESH'}, use_mesh_modifiers=True,
            apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z', axis_up='Y', path_mode='COPY', embed_textures=True, bake_anim=False)
    else:
        bpy.ops.export_scene.gltf(filepath=REQ["path"], export_format='GLB', use_selection=True, export_apply=True)
finally:
    for o, name in added:
        mod = o.modifiers.get(name)
        if mod:
            o.modifiers.remove(mod)
size = (hi - lo) * scene.unit_settings.scale_length
out.update({"path": REQ["path"], "bytes": os.path.getsize(REQ["path"]), "meshes": len(meshes), "triangles": total,
            "sizeMeters": [round(size.x, 3), round(size.y, 3), round(size.z, 3)]})
print("${MARKER}" + json.dumps(out))
`;
}

/** Reads a file Blender wrote (when Blender runs on another machine) as base64 chunks. */
function readFilePython(filePath: string, offset: number, length: number): string {
  return `
import base64, json
with open(${JSON.stringify(filePath)}, "rb") as f:
    f.seek(${offset})
    data = f.read(${length})
print("${MARKER}" + json.dumps({"data": base64.b64encode(data).decode("ascii"), "n": len(data)}))
`;
}

// --- Safe mode: reuse the vendored AST validator when BLENDER_MCP_SAFE_MODE=1 ------------------

function safeModeEnabled(): boolean {
  return /^(1|true|yes|on)$/i.test(process.env.BLENDER_MCP_SAFE_MODE ?? '');
}

function vendoredSourceDir(): string | null {
  if (process.env.BLENDER_MCP_DIR && fs.existsSync(path.join(process.env.BLENDER_MCP_DIR, 'blender_mcp', 'safe_mode.py'))) {
    return process.env.BLENDER_MCP_DIR;
  }
  return PathFinder.find({ shapes: [['integrations', 'blender-mcp', 'src']], requireAll: [path.join('blender_mcp', 'safe_mode.py')] });
}

/** Returns an error message when safe mode rejects the script, null when it may run. */
export function safeModeViolation(code: string): string | null {
  if (!safeModeEnabled()) return null;
  const src = vendoredSourceDir();
  if (!src) return 'BLENDER_MCP_SAFE_MODE is on but integrations/blender-mcp was not found (set BLENDER_MCP_DIR to its "src" folder).';
  // Load safe_mode.py on its own: importing the blender_mcp package would pull in the MCP server.
  const script = [
    'import sys, importlib.util',
    'spec = importlib.util.spec_from_file_location("gk_safe_mode", sys.argv[1])',
    'mod = importlib.util.module_from_spec(spec)',
    'spec.loader.exec_module(mod)',
    'try:',
    '    mod.validate_code(sys.stdin.read())',
    'except mod.SandboxViolation as exc:',
    '    print(str(exc), file=sys.stderr)',
    '    sys.exit(3)',
  ].join('\n');
  const file = path.join(src, 'blender_mcp', 'safe_mode.py');
  for (const python of [process.env.BLENDER_MCP_PYTHON, 'python3', 'python'].filter(Boolean) as string[]) {
    const run = spawnSync(python, ['-c', script, file], { input: code, encoding: 'utf8', timeout: 15000, env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' } });
    if (run.error) continue;
    if (run.status === 0) return null;
    const lines = (run.stderr || '').trim().split('\n');
    const last = lines[lines.length - 1] || 'invalid script';
    if (run.status === 3) return `Rejected by safe mode: ${last}. Only bpy, bmesh, mathutils and pure-python modules; no eval/exec/open/os/subprocess.`;
    return `Safe mode could not validate the script (${last}), so it was not run.`;
  }
  return 'BLENDER_MCP_SAFE_MODE is on but no Python was found to validate the script (set BLENDER_MCP_PYTHON).';
}

// --- Tools ---------------------------------------------------------------------------------------

const ASSET_SOURCES = ['polyhaven', 'sketchfab', 'polypizza', 'hyper3d', 'hunyuan3d'] as const;

export const BLENDER_TOOLS: ToolDef[] = [
  {
    name: 'blender_status',
    category: 'read',
    description: 'Check the link to Blender (for custom 3D models) and list the Blender scene. When connected, the other blender_* tools appear. Explains how to install the Blender addon if needed.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'blender_to_roblox',
    category: 'write',
    tier: 'starter',
    description: 'Send a model from Blender into the Roblox game: exports it (auto-reduces meshes over 20k triangles, checks textures/materials), uploads it as a Roblox Model (needs ROBLOX_OPEN_CLOUD_API_KEY + ROBLOX_CREATOR_USER_ID/GROUP_ID), inserts it in Studio at the right size (1 m = 3.57 studs) standing on the ground. Without a key it exports the file and explains the 2-click manual import. Also works with an existing assetId (skips Blender). Can take 1-2 min: run it through start_job to keep working.',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Name of the model in Roblox (and on the uploaded asset)' },
        objects: { type: 'array', items: { type: 'string' }, description: 'Blender object names to export (default: all visible meshes)' },
        position: { type: 'array', items: { type: 'number' }, description: '[x, y, z] in studs where the model stands (bottom center). Default [0, 0, 0]' },
        size: { type: 'number', description: 'Largest dimension in studs (default: real size from Blender, 1 m = 3.57 studs)' },
        yaw: { type: 'number', description: 'Rotation around the vertical axis, degrees' },
        parent: { type: 'string', description: 'Where to put it (default "Workspace/GameKit/Props")' },
        format: { type: 'string', enum: ['fbx', 'glb'], description: 'Export format (default fbx)' },
        maxTriangles: { type: 'number', description: 'Triangle budget per mesh (default 20000)' },
        decimate: { type: 'boolean', description: 'Reduce meshes above the budget automatically (default true)' },
        anchored: { type: 'boolean', description: 'Anchor the parts (default true)' },
        collide: { type: 'boolean', description: 'Players collide with it (default true)' },
        assetId: { type: 'number', description: 'Skip Blender: insert this existing Roblox model asset instead' },
        existing: { type: 'string', description: 'Skip Blender and upload: only resize/place a model already in Studio, e.g. "Workspace/MyImport" (after a manual Import 3D)' },
        description: { type: 'string', description: 'Asset description on Roblox' },
      },
      required: ['name'],
    },
  },
  {
    name: 'blender_python',
    category: 'write',
    tier: 'blender',
    description: 'Run Python (bpy) inside Blender to model, edit or render. Work in small steps; print() what you need to see. Use real-world meters (a door is 2 m high). Tip: keep models under 20k triangles and one material per mesh for Roblox, then call blender_to_roblox.',
    inputSchema: { type: 'object', properties: { code: { type: 'string', description: 'Python code using bpy/bmesh/mathutils' } }, required: ['code'] },
  },
  {
    name: 'blender_scene',
    category: 'read',
    tier: 'blender',
    description: 'Look at the Blender scene: objects with size in meters, triangle counts and materials; details of one object; and/or a screenshot of the Blender viewport.',
    inputSchema: {
      type: 'object',
      properties: {
        object: { type: 'string', description: 'Name of one object for full details' },
        screenshot: { type: 'boolean', description: 'Also return a viewport screenshot' },
        maxSize: { type: 'number', description: 'Screenshot size in pixels (default 800)' },
      },
    },
  },
  {
    name: 'blender_assets',
    category: 'write',
    tier: 'blender',
    description: `Get ready-made 3D content into Blender: search/download free models and textures (${ASSET_SOURCES.slice(0, 3).join(', ')}) or generate a model from text with AI (hyper3d, hunyuan3d). Sources must be enabled in the Blender addon panel (API keys for sketchfab/polypizza/hyper3d/hunyuan3d). Then send it to the game with blender_to_roblox.`,
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['status', 'search', 'download', 'generate', 'poll', 'import', 'texture'], description: 'status: which sources are enabled; search; download (by id); generate (text prompt, AI); poll (AI job); import (finished AI job); texture (apply a Poly Haven texture to an object)' },
        source: { type: 'string', enum: [...ASSET_SOURCES] },
        query: { type: 'string', description: 'search: keywords; generate: short English description of the model' },
        id: { type: 'string', description: 'download: asset id / uid; poll/import: job id (subscription_key, request_id, job_id or task_uuid)' },
        assetType: { type: 'string', enum: ['models', 'textures', 'hdris', 'all'], description: 'polyhaven search/download (default models)' },
        categories: { type: 'string', description: 'Optional category filter' },
        resolution: { type: 'string', description: 'polyhaven: 1k, 2k, 4k (default 1k)' },
        targetSize: { type: 'number', description: 'sketchfab/polypizza: normalize the largest dimension to this many meters' },
        name: { type: 'string', description: 'import: object name in Blender' },
        url: { type: 'string', description: 'import (hunyuan3d): model URL from the poll result' },
        object: { type: 'string', description: 'texture: Blender object to texture' },
        limit: { type: 'number', description: 'search: max results (default 20)' },
      },
      required: ['action'],
    },
  },
  {
    name: 'blender_command',
    category: 'write',
    tier: 'builder',
    description: 'Advanced: send a raw command to the Blender addon ({type, params}), e.g. get_scene_info, get_object_info, execute_code, search_polyhaven_assets. Prefer the other blender_* tools.',
    inputSchema: { type: 'object', properties: { type: { type: 'string' }, params: { type: 'object' } }, required: ['type'] },
  },
];

export const BLENDER_TOOL_NAMES = new Set(BLENDER_TOOLS.map((t) => t.name));

export interface BlenderToolsOptions {
  /** Called once Blender answered, so the blender tools can be listed. */
  onConnected?: () => void;
}

export class BlenderTools {
  constructor(
    private host: GameKitHost,
    readonly client = new BlenderClient(),
    private options: BlenderToolsOptions = {},
  ) {}

  async call(name: string, args: Record<string, any>): Promise<ToolResult> {
    switch (name) {
      case 'blender_status': return this.status();
      case 'blender_python': return this.python(args);
      case 'blender_scene': return this.scene(args);
      case 'blender_assets': return this.assets(args);
      case 'blender_command': return text(await this.connected(() => this.client.command(String(args.type), args.params ?? {})));
      case 'blender_to_roblox': return this.toRoblox(args);
      default: throw new Error(`Unknown Blender tool: ${name}`);
    }
  }

  private async connected<T>(fn: () => Promise<T>): Promise<T> {
    const value = await fn();
    this.options.onConnected?.();
    return value;
  }

  async status(): Promise<ToolResult> {
    try {
      const scene = await this.connected(() => this.client.pythonJson(sceneSummaryPython(), 30_000));
      return text({
        connected: true,
        address: `${this.client.host}:${this.client.port}`,
        ...scene,
        tools: 'blender_python (model with bpy), blender_scene (look), blender_assets (Poly Haven / Sketchfab / Poly Pizza / AI generation), blender_to_roblox (send to the game)',
        tips: [
          'Model in meters (a character is ~1.8 m, a door 2 m). blender_to_roblox converts to studs.',
          'Keep each mesh under 20k triangles and 1 material; apply a texture of 1024 px max.',
          'Put the model at the origin with its base at Z = 0.',
        ],
      });
    } catch (error) {
      return text({ connected: false, address: `${this.client.host}:${this.client.port}`, problem: errorMessage(error).split('. 1.')[0], fix: BLENDER_SETUP });
    }
  }

  async python(args: Record<string, any>): Promise<ToolResult> {
    const code = String(args.code ?? '');
    if (!code.trim()) throw new Error('code is required');
    const violation = safeModeViolation(code);
    if (violation) return { content: [{ type: 'text', text: violation }], isError: true };
    const output = await this.connected(() => this.client.python(code));
    return text({ ok: true, output: output.length > 20000 ? `${output.slice(0, 20000)}\n... (truncated)` : output || '(no output: print() what you want to see)' });
  }

  async scene(args: Record<string, any>): Promise<ToolResult> {
    const info = args.object
      ? await this.connected(() => this.client.command('get_object_info', { name: String(args.object) }))
      : await this.connected(() => this.client.pythonJson(sceneSummaryPython(), 30_000));
    if (!args.screenshot) return text(info);
    const file = path.join(os.tmpdir(), `gamekit-blender-${process.pid}-${Date.now()}.png`);
    try {
      await this.client.command('get_viewport_screenshot', { max_size: Number(args.maxSize ?? 800), filepath: file, format: 'png' });
      const data = fs.readFileSync(file).toString('base64');
      return withImages(info, [{ label: 'Blender viewport', data }]);
    } catch (error) {
      return text({ ...(typeof info === 'object' ? info : { info }), screenshotError: errorMessage(error) });
    } finally {
      fs.rmSync(file, { force: true });
    }
  }

  async assets(args: Record<string, any>): Promise<ToolResult> {
    const action = String(args.action ?? 'status');
    const source = String(args.source ?? '');
    const c = <T = any>(type: string, params: Record<string, unknown> = {}) => this.connected(() => this.client.command<T>(type, params));
    if (action === 'status') {
      const statuses: Record<string, unknown> = {};
      for (const s of ASSET_SOURCES) {
        const cmd = s === 'hunyuan3d' ? 'get_hunyuan3d_status' : `get_${s}_status`;
        try {
          statuses[s] = await c(cmd);
        } catch (error) {
          statuses[s] = { error: errorMessage(error) };
        }
      }
      return text({ sources: statuses, note: 'Enable a source in Blender: N panel > MCP for Blender > Asset Libraries / AI Model Generation.' });
    }
    if (!(ASSET_SOURCES as readonly string[]).includes(source)) throw new Error(`source must be one of: ${ASSET_SOURCES.join(', ')}`);
    const limit = Number(args.limit ?? 20);
    switch (`${action}:${source}`) {
      case 'search:polyhaven': return text(await c('search_polyhaven_assets', { asset_type: args.assetType ?? 'models', categories: args.categories ?? null }));
      case 'download:polyhaven': return text(await c('download_polyhaven_asset', { asset_id: this.need(args.id, 'id'), asset_type: args.assetType ?? 'models', resolution: args.resolution ?? '1k', file_format: null }));
      case 'texture:polyhaven': return text(await c('set_texture', { object_name: this.need(args.object, 'object'), texture_id: this.need(args.id, 'id') }));
      case 'search:sketchfab': return text(await c('search_sketchfab_models', { query: this.need(args.query, 'query'), categories: args.categories ?? null, count: limit, downloadable: true }));
      case 'download:sketchfab': return text(await c('download_sketchfab_model', { uid: this.need(args.id, 'id'), normalize_size: true, target_size: Number(args.targetSize ?? 1) }));
      case 'search:polypizza': return text(await c('search_polypizza_models', { query: this.need(args.query, 'query'), category: args.categories ?? null, licence: null, animated: false, limit }));
      case 'download:polypizza': return text(await c('download_polypizza_model', { model_id: this.need(args.id, 'id'), normalize_size: args.targetSize !== undefined, target_size: Number(args.targetSize ?? 1) }));
      case 'generate:hyper3d': {
        const job = await c<any>('create_rodin_job', { text_prompt: this.need(args.query, 'query'), images: null, bbox_condition: null });
        const id = job?.jobs?.subscription_key ?? job?.request_id ?? job?.uuid;
        return text({ job, id, taskUuid: job?.uuid, next: 'Call blender_assets {action:"poll", source:"hyper3d", id} every ~20s until done, then {action:"import", source:"hyper3d", id: <taskUuid or request id>, name}.' });
      }
      // Hyper3D runs in one of two modes (addon panel): MAIN_SITE takes subscription_key /
      // task_uuid, FAL_AI takes request_id. Try the first, fall back to the second.
      case 'poll:hyper3d': {
        const id = this.need(args.id, 'id');
        return text(await c('poll_rodin_job_status', { subscription_key: id }).catch(() => c('poll_rodin_job_status', { request_id: id })));
      }
      case 'import:hyper3d': {
        const id = this.need(args.id, 'id');
        const objectName = this.need(args.name, 'name');
        return text(await c('import_generated_asset', { name: objectName, task_uuid: id }).catch(() => c('import_generated_asset', { name: objectName, request_id: id })));
      }
      case 'generate:hunyuan3d': {
        const job = await c<any>('create_hunyuan_job', { text_prompt: this.need(args.query, 'query'), image: null });
        const id = job?.Response?.JobId ? `job_${job.Response.JobId}` : undefined;
        return text({ job, id, next: 'Call blender_assets {action:"poll", source:"hunyuan3d", id} until status DONE, then {action:"import", source:"hunyuan3d", name, url: <.glb url from ResultFile3Ds>}.' });
      }
      case 'poll:hunyuan3d': return text(await c('poll_hunyuan_job_status', { job_id: this.need(args.id, 'id') }));
      case 'import:hunyuan3d': return text(await c('import_generated_asset_hunyuan', { name: this.need(args.name, 'name'), zip_file_url: this.need(args.url, 'url') }));
      default:
        throw new Error(`Action "${action}" is not available for ${source}. search/download: polyhaven, sketchfab, polypizza; texture: polyhaven; generate/poll/import: hyper3d, hunyuan3d.`);
    }
  }

  private need(value: unknown, name: string): string {
    if (value === undefined || value === null || String(value).trim() === '') throw new Error(`"${name}" is required for this action`);
    return String(value);
  }

  /** Export -> upload -> insert. Every step reports what happened, so a weak model can recover. */
  async toRoblox(args: Record<string, any>): Promise<ToolResult> {
    const name = String(args.name ?? 'BlenderModel').replace(/[^\w -]/g, '').trim() || 'BlenderModel';
    const steps: Record<string, unknown> = {};
    let assetId = Number(args.assetId) || 0;
    let sizeMeters: Vec3 | undefined;

    if (!assetId && !args.existing) {
      const format = args.format === 'glb' ? 'glb' : 'fbx';
      const dir = path.join(os.tmpdir(), 'roblox-ultimate-mcp', 'blender');
      const file = path.join(dir, `${name.replace(/\s+/g, '_')}-${Date.now()}.${format}`);
      const exported = await this.connected(() => this.client.pythonJson(exportPython({
        objects: Array.isArray(args.objects) ? args.objects.map(String) : undefined,
        format,
        path: file,
        maxTriangles: Math.max(500, Number(args.maxTriangles ?? DEFAULT_MAX_TRIANGLES)),
        decimate: args.decimate !== false,
        textureMax: 1024,
      })));
      sizeMeters = exported.sizeMeters;
      steps.export = exported;
      const localFile = await this.ensureLocal(exported.path, exported.bytes);
      steps.file = localFile;

      if (!this.host.hasOpenCloudKey?.()) {
        return text({
          ok: true,
          uploaded: false,
          file: localFile,
          steps,
          why: 'No Open Cloud API key, so the model was exported but not uploaded.',
          manualImport: [
            'In Studio: Home (Accueil) tab > Import 3D > choose the file above > Import.',
            `Then call blender_to_roblox again with {"name": "${name}", "existing": "Workspace/<imported model name>"} to size and place it.`,
          ],
          automatic: 'To make it automatic: create an Open Cloud API key with asset:read + asset:write (create.roblox.com > Open Cloud > API Keys), set ROBLOX_OPEN_CLOUD_API_KEY and ROBLOX_CREATOR_USER_ID in the MCP config.',
        });
      }
      if (!this.host.callTool) throw new Error('This server cannot call upload_asset internally.');
      const upload = resultJson(await this.host.callTool('upload_asset', {
        filePath: localFile, assetType: 'Model', displayName: name, description: String(args.description ?? `${name} (made in Blender)`),
      }));
      steps.upload = upload;
      assetId = Number(upload?.response?.assetId ?? upload?.assetId ?? 0);
      if (!assetId) {
        return text({ ok: false, file: localFile, steps, problem: 'Upload did not return an asset id.', fix: 'Check the Open Cloud key scopes (asset:read, asset:write) and ROBLOX_CREATOR_USER_ID / ROBLOX_CREATOR_GROUP_ID, or import the file manually (Home > Import 3D).' });
      }
    }

    if (!this.host.isStudioConnected()) {
      return text({ ok: false, assetId, steps, problem: 'Studio is not connected, the model was not inserted.', next: `Connect Studio, then call blender_to_roblox {"name": "${name}", "assetId": ${assetId}}.` });
    }

    const targetSize = Number(args.size) > 0
      ? Number(args.size)
      : sizeMeters ? Math.max(...sizeMeters) * STUDS_PER_METER : undefined;
    const place = {
      name,
      assetId,
      existing: args.existing ? String(args.existing) : undefined,
      parent: String(args.parent ?? 'Workspace/GameKit/Props'),
      position: vec3(args.position, [0, 0, 0]),
      size: targetSize,
      yaw: Number(args.yaw ?? 0),
      anchored: args.anchored !== false,
      collide: args.collide !== false,
      replace: true,
    };
    // Freshly uploaded models can take a little while before Studio can load them.
    let inserted: any;
    const attempts = steps.upload ? 8 : 1;
    for (let attempt = 1; attempt <= attempts; attempt++) {
      inserted = await runLuauJson(this.host, placeModelLuau(place), 'Insert model');
      if (inserted?.ok || attempt === attempts) break;
      await sleep(Math.min(20000, 3000 * attempt));
    }
    steps.insert = inserted;
    return text({
      ok: !!inserted?.ok,
      assetId,
      path: inserted?.path,
      sizeStuds: inserted?.size,
      steps,
      next: inserted?.ok
        ? 'Check it with look_at_game (or capture_screenshot). Clone it around with populate_world {items:[{from: "<path>", count: 10}]}.'
        : 'Roblox may still be processing/moderating the upload: wait a minute and call blender_to_roblox again with {"name", "assetId"}.',
    });
  }

  /** Blender may run on another machine: fetch the exported file over the socket if needed. */
  private async ensureLocal(filePath: string, bytes: number): Promise<string> {
    if (fs.existsSync(filePath)) return filePath;
    if (bytes > 50 * 1024 * 1024) throw new Error(`Exported file is on the Blender machine (${filePath}) and too big to transfer (${bytes} bytes).`);
    const local = path.join(os.tmpdir(), 'roblox-ultimate-mcp', 'blender', path.basename(filePath));
    fs.mkdirSync(path.dirname(local), { recursive: true });
    const parts: Buffer[] = [];
    const chunk = 4 * 1024 * 1024;
    for (let offset = 0; offset < bytes; offset += chunk) {
      const piece = await this.client.pythonJson<{ data: string; n: number }>(readFilePython(filePath, offset, chunk));
      parts.push(Buffer.from(piece.data, 'base64'));
      if (piece.n < chunk) break;
    }
    fs.writeFileSync(local, Buffer.concat(parts));
    return local;
  }
}
