/**
 * look_at_game: lets the AI SEE what it built. Frames the game (or one model) from several
 * angles with the Studio camera, screenshots each view, then puts the camera back.
 * Weak models skip visual checks; one call makes it easy.
 */

import fs from 'fs';
import path from 'path';
import type { GameKitHost, ToolDef } from './tools.js';
import { runLuauJson, splitPath } from './installer.js';
import { errorMessage, luauJson, resultImages, resultJson, sleep, withImages, type ToolResult } from './result.js';

export const VIEWS = ['iso', 'aerial', 'front', 'back', 'left', 'right', 'top', 'player'] as const;
type View = (typeof VIEWS)[number];

const IMAGE_TYPES: Record<string, string> = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };

export const VISUAL_TOOLS: ToolDef[] = [
  {
    name: 'look_at_game',
    category: 'read',
    tier: 'starter',
    description: 'SEE the game: small screenshots of the map or one model from several angles. Use after building. reference: the picture to copy, shown next to the screenshots to compare. Needs Game Settings > Security > Allow Mesh / Image APIs.',
    inputSchema: {
      type: 'object',
      properties: {
        target: { type: 'string', description: 'e.g. "Workspace/GameKit/Lobby" (default the whole map)' },
        reference: { type: 'string', description: 'Absolute path of the picture to copy (.png/.jpg/.jpeg/.webp)' },
        views: { type: 'array', items: { type: 'string', enum: [...VIEWS] }, description: 'default ["iso", "top", "player"]; with a reference ["aerial", "iso"]' },
        zoom: { type: 'number', description: '<1 closer, >1 farther' },
        size: { type: 'number', description: 'Image size in pixels (default 640, max 1280)' },
      },
    },
  },
];

const FRAME_LUAU = `
local HttpService = game:GetService("HttpService")
local req = HttpService:JSONDecode(__REQ__)
local cam = workspace.CurrentCamera
local function findPath(segments)
	local node = game
	for _, name in segments do
		local child = if node == game then game:FindFirstChild(name) or game:GetService(name) else node:FindFirstChild(name)
		if not child then return nil end
		node = child
	end
	return node
end
local target = if req.target then findPath(req.target) else (workspace:FindFirstChild("GameKit") or workspace)
if not target then return HttpService:JSONEncode({ ok = false, error = "Target not found" }) end
local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
local count, bigParts = 0, {}
local function add(part)
	local cf, half = part.CFrame, part.Size / 2
	local r = cf - cf.Position
	local ex = Vector3.new(
		math.abs(r.XVector.X) * half.X + math.abs(r.YVector.X) * half.Y + math.abs(r.ZVector.X) * half.Z,
		math.abs(r.XVector.Y) * half.X + math.abs(r.YVector.Y) * half.Y + math.abs(r.ZVector.Y) * half.Z,
		math.abs(r.XVector.Z) * half.X + math.abs(r.YVector.Z) * half.Y + math.abs(r.ZVector.Z) * half.Z)
	minV = minV:Min(cf.Position - ex)
	maxV = maxV:Max(cf.Position + ex)
	count += 1
end
local candidates = target:GetDescendants()
if target:IsA("BasePart") then table.insert(candidates, target) end
for _, d in candidates do
	if d:IsA("BasePart") and not d:IsA("Terrain") and d.Transparency < 1 then
		-- A huge baseplate would make everything tiny: frame the content, not the floor.
		if target == workspace and (d.Size.X > 600 or d.Size.Z > 600) then
			table.insert(bigParts, d)
		else
			add(d)
		end
	end
end
if count == 0 then for _, d in bigParts do add(d) end end
if count == 0 then
	minV, maxV = Vector3.new(-50, 0, -50), Vector3.new(50, 20, 50)
end
local spawnPos = nil
for _, d in workspace:GetDescendants() do
	if d:IsA("SpawnLocation") then spawnPos = d.Position; break end
end
local cf = cam.CFrame
local focus = cam.Focus
return HttpService:JSONEncode({
	ok = true, parts = count,
	min = { minV.X, minV.Y, minV.Z }, max = { maxV.X, maxV.Y, maxV.Z },
	spawn = if spawnPos then { spawnPos.X, spawnPos.Y, spawnPos.Z } else nil,
	camera = { cf:GetComponents() }, focus = { focus:GetComponents() }, fov = cam.FieldOfView,
})
`;

function cameraLuau(eye: number[], lookAt: number[]): string {
  return `
local cam = workspace.CurrentCamera
local eye = Vector3.new(${eye.map((n) => n.toFixed(3)).join(', ')})
local at = Vector3.new(${lookAt.map((n) => n.toFixed(3)).join(', ')})
cam.CFrame = CFrame.lookAt(eye, at)
cam.Focus = CFrame.new(at)
task.wait(0.25)
return "ok"`;
}

function restoreLuau(camera: number[], focus: number[]): string {
  return `
local cam = workspace.CurrentCamera
cam.CFrame = CFrame.new(${camera.map((n) => n.toFixed(4)).join(', ')})
cam.Focus = CFrame.new(${focus.map((n) => n.toFixed(4)).join(', ')})
return "ok"`;
}

export function viewEye(view: View, center: number[], size: number[], distance: number, spawn?: number[]): { eye: number[]; at: number[] } {
  const [cx, cy, cz] = center;
  const dir: Record<Exclude<View, 'player'>, number[]> = {
    iso: [1, 0.8, 1],
    aerial: [0, 1, 1], // 45 degrees down from the south: the usual angle of concept art and map renders
    front: [0, 0.35, 1],
    back: [0, 0.35, -1],
    left: [-1, 0.35, 0],
    right: [1, 0.35, 0],
    top: [0, 1, 0.08],
  };
  if (view === 'player') {
    const from = spawn ?? [cx, cy - size[1] / 2, cz + size[2] / 2 + 10];
    const eye = [from[0], from[1] + 6, from[2]];
    // Look at the center of the map, at eye height, so the horizon is level.
    const at = Math.hypot(cx - eye[0], cz - eye[2]) < 5 ? [eye[0], eye[1], eye[2] - 50] : [cx, eye[1] - 2, cz];
    return { eye, at };
  }
  const d = dir[view];
  const len = Math.hypot(d[0], d[1], d[2]);
  return { eye: [cx + (d[0] / len) * distance, cy + (d[1] / len) * distance, cz + (d[2] / len) * distance], at: [cx, cy, cz] };
}

/** The picture the user wants copied, read from disk so it sits next to the screenshots. */
export function referenceImage(file: string): { label: string; data: string; mimeType: string } {
  const mimeType = IMAGE_TYPES[path.extname(file).toLowerCase()];
  if (!path.isAbsolute(file)) throw new Error(`reference must be an absolute path: ${file}`);
  if (!mimeType) throw new Error(`reference is not an image (png, jpg, jpeg, webp): ${file}`);
  if (!fs.existsSync(file)) throw new Error(`reference not found: ${file}`);
  const data = fs.readFileSync(file);
  if (data.length > 5_000_000) throw new Error('reference is over 5 MB: save a smaller copy (1920 px is plenty)');
  return { label: 'Reference (the target to copy)', data: data.toString('base64'), mimeType };
}

export async function lookAtGame(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  if (!host.callTool) throw new Error('Screenshots are not available in this server.');
  const reference = args.reference ? referenceImage(String(args.reference)) : undefined;
  const views = (Array.isArray(args.views) && args.views.length ? args.views : reference ? ['aerial', 'iso'] : ['iso', 'top', 'player'])
    .filter((v: string): v is View => (VIEWS as readonly string[]).includes(v))
    .slice(0, 6) as View[];
  const frame = await runLuauJson<any>(host, FRAME_LUAU.replace('__REQ__', () => luauJson({ target: args.target ? splitPath(String(args.target)) : null })), 'Frame camera');
  if (!frame?.ok) throw new Error(frame?.error ?? 'Could not frame the target');
  const center = [0, 1, 2].map((i) => (frame.min[i] + frame.max[i]) / 2);
  const size = [0, 1, 2].map((i) => frame.max[i] - frame.min[i]);
  const fov = ((Number(frame.fov) || 70) * Math.PI) / 180;
  const radius = Math.hypot(size[0], size[1], size[2]) / 2;
  const distance = Math.max(25, Math.min(4000, (radius / Math.tan(fov / 2)) * 1.05 * (Number(args.zoom) > 0 ? Number(args.zoom) : 1)));

  const images: Array<{ label: string; data: string; mimeType: string }> = [];
  const problems: string[] = [];
  try {
    for (const view of views) {
      const { eye, at } = viewEye(view, center, size, distance, frame.spawn);
      const moved = await host.runLuau(cameraLuau(eye, at));
      if (!moved?.success) {
        problems.push(`${view}: camera: ${moved?.error ?? 'failed'}`);
        continue;
      }
      await sleep(150);
      try {
        const shot = await host.callTool('capture_screenshot', { maxSize: Math.max(256, Math.min(1280, Number(args.size) || 640)) });
        const found = resultImages(shot);
        if (found.length) images.push({ label: `View: ${view}`, ...found[0] });
        else problems.push(`${view}: ${JSON.stringify(resultJson(shot)).slice(0, 300)}`);
      } catch (error) {
        problems.push(`${view}: ${errorMessage(error)}`);
      }
      if (problems.length && !images.length && problems.length >= 2) break; // screenshots are not working at all
    }
  } finally {
    await host.runLuau(restoreLuau(frame.camera, frame.focus)).catch(() => undefined);
  }
  return withImages({
    target: args.target ?? 'Workspace/GameKit',
    parts: frame.parts,
    sizeStuds: size.map((n) => Math.round(n)),
    views: images.map((i) => i.label.replace('View: ', '')),
    problems: problems.length ? problems : undefined,
    fix: problems.length && !images.length ? 'Screenshots need Studio in Edit mode with the viewport visible, and Game Settings > Security > "Allow Mesh / Image APIs" = ON.' : undefined,
    checklist: 'Look for: floating or clipping parts, empty/flat areas (populate_world), unreadable text, too dark/bright lighting (set_environment), paths blocked by decor.',
    compare: reference
      ? 'Compare with the reference image: list every difference (missing objects, wrong place, size, shape, color, lighting), fix the biggest first, then look again. Not finished while a landmark is missing or the layout differs.'
      : undefined,
  }, reference ? [reference, ...images] : images);
}
