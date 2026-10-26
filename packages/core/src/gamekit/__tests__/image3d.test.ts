import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';
import { BlenderClient, BlenderTools } from '../blender.js';
import { buildScript, findSkillDir, ImageTo3d, loadPython, outputDir } from '../image3d.js';
import { guideText } from '../knowledge.js';
import type { GameKitHost } from '../tools.js';

const parse = (result: any) => JSON.parse(result.content[0].text);
const offline = { python: async () => { throw new Error('offline'); } } as unknown as BlenderClient;
const host = { isStudioConnected: () => false, runLuau: async () => '' } as unknown as GameKitHost;

describe('blender_image_to_3d', () => {
  const dir = findSkillDir()!;

  test('the vendored skill is found, and the guide points to it', () => {
    expect(fs.existsSync(path.join(dir, 'scripts', 'compose_review_bpy.py'))).toBe(true);
    expect(guideText('image3d')).toMatch(/blender_image_to_3d|compose_review/);
  });

  test('build fills the template: our phase, the AI build(), the template main kept', () => {
    const template = fs.readFileSync(path.join(dir, 'assets', 'build_template.py'), 'utf8');
    const script = buildScript(template, '02_blockout', 'def build(scene, args):\n    own(box("PR_A_LOD0", (1, 1, 1)))');
    expect(script).toContain('PHASE = "02_blockout"');
    expect(script).toContain('own(box("PR_A_LOD0"');
    expect(script).not.toContain('log("nothing built yet")');
    expect(script).toContain('def lod_copy(');
    expect(script.trimEnd().endsWith('log("saved", a.master)')).toBe(true);
    const withKit = buildScript(template, '03_forms', 'def build(scene, args):\n    pass', 'def hex_bolt(location):\n    pass');
    expect(withKit.indexOf('def hex_bolt(')).toBeGreaterThan(withKit.indexOf('def lod_copy('));
    expect(withKit.indexOf('def hex_bolt(')).toBeLessThan(withKit.indexOf('def build(scene, args):\n    pass'));
    expect(outputDir(['--blend', 'a.blend', '--out', '/x/review/02'])).toBe('/x/review/02');
    expect(outputDir(['--out', '/x/review/04_validate.json'])).toBe('/x/review');
    expect(outputDir(['--help'])).toBeUndefined();
  });

  test('guide serves the skill references and the template helpers', async () => {
    const tool = new ImageTo3d(offline);
    expect((await tool.call({ action: 'guide', topic: 'categories' })).content[0].text).toMatch(/Environment pieces/);
    const template = parse(await tool.call({ action: 'guide', topic: 'template' }));
    expect(template.helpers.some((h: string) => h.startsWith('def skin_chain('))).toBe(true);
    expect(template.helpers.find((h: string) => h.startsWith('def cylinder('))).toMatch(/radius_top=None, base_at_origin=False\)  # Cylinder/);
    expect(template.detailKit.some((h: string) => h.startsWith('def padlock('))).toBe(true);
    expect(template.detailKit.some((h: string) => h.startsWith('def _'))).toBe(false);
    await expect(tool.call({ action: 'guide', topic: 'nope' })).rejects.toThrow(/topic must be/);
  });

  test('bad requests are refused before Blender runs', async () => {
    const tool = new ImageTo3d(offline);
    await expect(tool.call({ action: 'run', script: 'rm' })).rejects.toThrow(/script must be one of/);
    await expect(tool.call({ action: 'build', master: 'rel.blend', phase: '02' })).rejects.toThrow(/absolute/);
    const master = path.join(os.tmpdir(), 'PR_A_master.blend');
    await expect(tool.call({ action: 'build', master, phase: '../x' })).rejects.toThrow(/phase/);
    await expect(tool.call({ action: 'build', master, phase: '02', code: 'print(1)' })).rejects.toThrow(/build\(scene, args\)/);
    await expect(tool.call({ action: 'load', master: 'a.blend' })).rejects.toThrow(/absolute/);
  });

  test('safe mode leaves only the guide', async () => {
    const tools = new BlenderTools(host, offline);
    process.env.BLENDER_MCP_SAFE_MODE = '1';
    try {
      const run = await tools.call('blender_image_to_3d', { action: 'run', script: 'validate', args: ['--help'] });
      expect(run.isError).toBe(true);
      expect(run.content[0].text).toMatch(/safe mode|SAFE_MODE/i);
      expect((await tools.call('blender_image_to_3d', { action: 'guide' })).isError).toBeUndefined();
    } finally {
      delete process.env.BLENDER_MCP_SAFE_MODE;
    }
  });

  // Real Blender, opt-in: BLENDER_BIN=<blender executable> npm test
  (process.env.BLENDER_BIN ? test : test.skip)('a matching blockout passes the silhouette gate, a wrong one fails it', async () => {
    const asset = fs.mkdtempSync(path.join(os.tmpdir(), 'PR_Egg-'));
    const master = path.join(asset, 'PR_Egg_master.blend');
    const ref = path.join(asset, 'front.png').replace(/\\/g, '/');
    // a dark egg 0.8 x 1.2 m on white: subject 90% of the image height, base 5% above the bottom
    // the same egg, brown on a dark grey grid like a viewport screenshot: only a matte makes it measurable
    const dirty = path.join(asset, 'dirty.png').replace(/\\/g, '/');
    // and with bands in its upper half that the plain model lacks: only the detail check sees them
    const striped = path.join(asset, 'striped.png').replace(/\\/g, '/');
    const make = `import bpy, numpy as np
W, H = 400, 600
y, x = np.mgrid[0:H, 0:W]
inside = ((x - W / 2) / (0.45 * H * 0.8 / 1.2)) ** 2 + ((y - (H - 0.05 * H - 0.45 * H)) / (0.45 * H)) ** 2 <= 1
def save(img, path):
    im = bpy.data.images.new("ref", W, H, alpha=True)
    im.pixels.foreach_set(np.ascontiguousarray(img[::-1]).ravel())
    im.filepath_raw = path; im.file_format = "PNG"; im.save()
img = np.ones((H, W, 4), np.float32); img[inside, :3] = 0.15
save(img, "${ref}")
img = np.ones((H, W, 4), np.float32); img[..., :3] = 0.25
img[(x % 40 < 2) | (y % 40 < 2), :3] = 0.32
img[np.abs(y - 0.4 * x - 100) < 2, :3] = (0.6, 0.15, 0.15)
img[inside, :3] = (0.40, 0.22, 0.12)
save(img, "${dirty}")
img = np.ones((H, W, 4), np.float32); img[inside, :3] = 0.15
img[inside & (y < H / 2) & (y % 24 < 4), :3] = 0.6
save(img, "${striped}")`;
    expect(spawnSync(process.env.BLENDER_BIN!, ['--background', '--python-expr', make]).status).toBe(0);
    const tool = new ImageTo3d(offline);
    const run = async (script: string, args: string[]) => parse(await tool.call({ action: 'run', script, args }));
    expect((await run('init_master', ['--out', master, '--name', 'PR_Egg', '--height', '1.2', '--ref-front', ref, '--subject-frac', '0.9', '--ground-frac', '0.05'])).ok).toBe(true);
    const first = parse(await tool.call({ action: 'build', master, phase: '02_blockout', code: 'def build(scene, args):\n    pass' }));
    expect(first.warning).toMatch(/asset-brief/);
    const matte = path.join(asset, 'dirty_matte.png');
    const matted = await run('make_matte', ['--ref', dirty, '--out', matte]);
    expect(matted.log).toMatch(/1 blob\(s\) kept of 1/);
    const gate = async (code: string, out: string) => {
      expect(parse(await tool.call({ action: 'build', master, phase: '02_blockout', code })).ok).toBe(true);
      expect((await run('review_render', ['--blend', master, '--out', path.join(asset, out), '--views', 'front', '--mode', 'clay'])).ok).toBe(true);
      const sheet = await tool.call({ action: 'run', script: 'compose_review', args: ['--ref', ref, '--render', path.join(asset, out, 'clay_front.png'), '--out', path.join(asset, out, 'compare_front.png'), '--measure'] });
      expect(sheet.content.some((c: any) => c.type === 'image')).toBe(true);
      return parse(sheet).json['compare_front.json'];
    };
    const egg = await gate('def build(scene, args):\n    own(sphere("PR_Egg_Body_LOD0", 0.4, location=(0, 0, 0.6), scale=(1, 1, 1.5)))', 'egg');
    expect(egg.iou).toBeGreaterThan(0.95);
    const vsMatte = await run('compose_review', ['--ref', matte, '--render', path.join(asset, 'egg', 'clay_front.png'), '--out', path.join(asset, 'egg', 'compare_matte.png'), '--measure']);
    expect(vsMatte.json['compare_matte.json'].iou).toBeGreaterThan(0.95);
    const cam = await run('fit_camera', ['--blend', master, '--matte', matte, '--out', path.join(asset, 'camera'), '--az', '-10', '10', '--el', '0', '10', '--lens', '85']);
    expect(cam.json['fit_camera.json'].best.iou).toBeGreaterThan(0.95);
    const detail = async (r: string, name: string) => (await run('compose_review', ['--ref', r, '--render', path.join(asset, 'egg', 'clay_front.png'), '--out', path.join(asset, 'egg', `${name}.png`), '--measure', '--detail'])).json[`${name}.json`];
    const plain = await detail(ref, 'detail_plain');
    const banded = await detail(striped, 'detail_striped');
    expect(plain.iou).toBeGreaterThan(0.95);
    expect(banded.iou).toBeGreaterThan(0.95); // same silhouette: IoU cannot tell them apart
    const missing = banded.detail.flags.filter((f: string) => /the reference has/.test(f));
    expect(missing.length).toBeGreaterThan(plain.detail.flags.filter((f: string) => /the reference has/.test(f)).length);
    expect(missing.every((f: string) => Number(/^r(\d+)/.exec(f)![1]) <= 3)).toBe(true); // the bands are in the upper half
    const ball = await gate('def build(scene, args):\n    own(sphere("PR_Egg_Body_LOD0", 0.5, location=(0, 0, 0.5)))', 'ball');
    expect(ball.iou).toBeLessThan(0.85);
    expect(Math.max(...ball.band_width_diff)).toBeGreaterThan(0.05);
    const broken = parse(await tool.call({ action: 'build', master, phase: '02_blockout', code: 'def build(scene, args):\n    sphere("X", 0.5, nope=1)' }));
    expect(broken.ok).toBe(false);
    expect(broken.log).toMatch(/unexpected keyword argument/);

    // load, twice, as the open Blender would run it: LOD1 skipped, no .001, display colour from the shader,
    // and the second copy stays where the first one was moved to
    expect(parse(await tool.call({ action: 'build', master, phase: '02_blockout', code: 'def build(scene, args):\n    egg = own(sphere("PR_Egg_Body_LOD0", 0.4, location=(0, 0, 0.6)))\n    assign(egg, material("M_Egg", color=(0.9, 0.5, 0.6, 1)))\n    own(lod_copy(egg, 1, 0.5))' })).ok).toBe(true);
    const snippet = loadPython({ path: master, name: 'PR_Egg', collections: ['LOW', 'RIG_DEF'] });
    const check = path.join(asset, 'load_check.py');
    fs.writeFileSync(check, `${snippet}\nbpy.data.objects["PR_Egg_Body_LOD0"].location.x += 5\n${snippet}\nimport bpy\nprint("NAMES", sorted(o.name for o in bpy.data.objects if o.name.startswith("PR_")), sorted(m.name for m in bpy.data.materials if m.name.startswith("M_")), round(bpy.data.materials["M_Egg"].diffuse_color[0], 2), round(bpy.data.objects["PR_Egg_Body_LOD0"].location.x, 2))\n`);
    const loaded = spawnSync(process.env.BLENDER_BIN!, ['--background', '--factory-startup', '--python-exit-code', '1', '--python', check], { encoding: 'utf8' });
    expect(loaded.status).toBe(0);
    expect(loaded.stdout).toContain(`NAMES ['PR_Egg_Body_LOD0'] ['M_Egg'] 0.9 5.0`);
    expect(loaded.stdout).toContain(`"keptPlacement": [5.0, 0.0, 0.0]`);

    // the detail kit builds and merges every part
    const kit = parse(await tool.call({ action: 'build', master, phase: '03_kit', code: `
def build(scene, args):
    parts = [hex_bolt((0, -0.5, 0.5), "-Y")]
    parts += metal_plate((0, -0.4, 0.6), 0.2, 0.15, 0.015, "-Y", bolts=(2, 2))
    parts += corner_cap(0.5, -0.4, 0, bolts=(1, 1), side_bolts=(1, 2))
    parts += plank_stack("plank", (0.8, 0.6, 0.4), 3, (0, 0, 0))
    parts.append(strap("strap", arch_points(0.3, 0.2, 0.4), 0.03, 0, 0.1))
    parts.append(prism("lid", arch_points(0.3, 0.2, 0.4), -0.4, 0.4))
    parts.append(tube("pipe", [(0, 0, 1), (0.2, 0, 1.1), (0.4, 0, 1)], 0.02))
    lock = padlock((0, -0.3, 0.1), "-Y")
    parts += lock["body"] + ring_handle((0.4, 0, 0.3), "+X", bolts=0)
    whole = merge("PR_Egg_Kit_LOD0", parts, material("M_Kit"))
    keys = merge("PR_Egg_KitKey_LOD0", lock["keyhole"])
    log("triangles", tri_count([whole, keys]))
` }));
    expect(kit.ok).toBe(true);
    expect(kit.log).toMatch(/triangles \d{3,}/);
    fs.rmSync(asset, { recursive: true, force: true });
  }, 300_000);
});
