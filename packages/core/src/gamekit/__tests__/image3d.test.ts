import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';
import { BlenderClient, BlenderTools } from '../blender.js';
import { buildScript, findSkillDir, ImageTo3d, outputDir } from '../image3d.js';
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
    expect(outputDir(['--blend', 'a.blend', '--out', '/x/review/02'])).toBe('/x/review/02');
    expect(outputDir(['--out', '/x/review/04_validate.json'])).toBe('/x/review');
    expect(outputDir(['--help'])).toBeUndefined();
  });

  test('guide serves the skill references and the template helpers', async () => {
    const tool = new ImageTo3d(offline);
    expect((await tool.call({ action: 'guide', topic: 'categories' })).content[0].text).toMatch(/Environment pieces/);
    const template = parse(await tool.call({ action: 'guide', topic: 'template' }));
    expect(template.helpers.some((h: string) => h.startsWith('def skin_chain('))).toBe(true);
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
    const make = `import bpy, numpy as np
W, H = 400, 600
y, x = np.mgrid[0:H, 0:W]
inside = ((x - W / 2) / (0.45 * H * 0.8 / 1.2)) ** 2 + ((y - (H - 0.05 * H - 0.45 * H)) / (0.45 * H)) ** 2 <= 1
img = np.ones((H, W, 4), np.float32); img[inside, :3] = 0.15
im = bpy.data.images.new("ref", W, H, alpha=True)
im.pixels.foreach_set(np.ascontiguousarray(img[::-1]).ravel())
im.filepath_raw = "${ref}"; im.file_format = "PNG"; im.save()`;
    expect(spawnSync(process.env.BLENDER_BIN!, ['--background', '--python-expr', make]).status).toBe(0);
    const tool = new ImageTo3d(offline);
    const run = async (script: string, args: string[]) => parse(await tool.call({ action: 'run', script, args }));
    expect((await run('init_master', ['--out', master, '--name', 'PR_Egg', '--height', '1.2', '--ref-front', ref, '--subject-frac', '0.9', '--ground-frac', '0.05'])).ok).toBe(true);
    const gate = async (code: string, out: string) => {
      expect(parse(await tool.call({ action: 'build', master, phase: '02_blockout', code })).ok).toBe(true);
      expect((await run('review_render', ['--blend', master, '--out', path.join(asset, out), '--views', 'front', '--mode', 'clay'])).ok).toBe(true);
      const sheet = await tool.call({ action: 'run', script: 'compose_review', args: ['--ref', ref, '--render', path.join(asset, out, 'clay_front.png'), '--out', path.join(asset, out, 'compare_front.png'), '--measure'] });
      expect(sheet.content.some((c: any) => c.type === 'image')).toBe(true);
      return parse(sheet).json['compare_front.json'];
    };
    const egg = await gate('def build(scene, args):\n    own(sphere("PR_Egg_Body_LOD0", 0.4, location=(0, 0, 0.6), scale=(1, 1, 1.5)))', 'egg');
    expect(egg.iou).toBeGreaterThan(0.95);
    const ball = await gate('def build(scene, args):\n    own(sphere("PR_Egg_Body_LOD0", 0.5, location=(0, 0, 0.5)))', 'ball');
    expect(ball.iou).toBeLessThan(0.85);
    expect(Math.max(...ball.band_width_diff)).toBeGreaterThan(0.05);
    const broken = parse(await tool.call({ action: 'build', master, phase: '02_blockout', code: 'def build(scene, args):\n    sphere("X", 0.5, nope=1)' }));
    expect(broken.ok).toBe(false);
    expect(broken.log).toMatch(/unexpected keyword argument/);
    fs.rmSync(asset, { recursive: true, force: true });
  }, 300_000);
});
