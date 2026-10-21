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
import { errorMessage, luauJson, resultJson, sleep, text, vec3, withImages, type ToolResult, type Vec3 } from './result.js';
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

/**
 * Is the Blender addon listening? A bare TCP connect, closed at once. Used at startup so
 * the blender_* tools are already in the first tools/list when Blender is open: some
 * clients never re-read the list after tools/list_changed.
 */
export function probeBlender(
  host = process.env.BLENDER_HOST || '127.0.0.1',
  port = Number(process.env.BLENDER_PORT || 9876),
  timeoutMs = 500,
): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port });
    let settled = false;
    const done = (ok: boolean) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(timeoutMs, () => done(false));
    socket.once('connect', () => done(true));
    socket.once('error', () => done(false));
  });
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
  /** Export armatures with their skinned meshes (characters, creatures). Default: when one is found. */
  rig?: boolean;
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
armatures = []
for o in picked:
    if o.type == 'MESH' and o not in meshes:
        meshes.append(o)
    if o.type == 'ARMATURE' and o not in armatures:
        armatures.append(o)
for o in list(meshes):
    for mod in o.modifiers:
        if mod.type == 'ARMATURE' and mod.object and mod.object not in armatures:
            armatures.append(mod.object)
rig = bool(armatures) and REQ.get("rig") is not False
if rig:
    # Roblox skinning limits: 4 bone influences per vertex, keep rigs under ~100 bones.
    for a in armatures:
        n = len(a.data.bones)
        if n > 100:
            out["warnings"].append("%s has %d bones: keep Roblox rigs under ~100 bones." % (a.name, n))
    for o in meshes:
        heavy = 0
        for v in o.data.vertices:
            if sum(1 for g in v.groups if g.weight > 0.001) > 4:
                heavy += 1
        if heavy:
            out["warnings"].append("%s: %d vertices have more than 4 bone weights (Roblox keeps 4). Weight Paint > Limit Total (4)." % (o.name, heavy))
    out["bones"] = sum(len(a.data.bones) for a in armatures)
    out["armatures"] = [a.name for a in armatures]
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
for o in meshes + (armatures if rig else []):
    o.select_set(True)
bpy.context.view_layer.objects.active = armatures[0] if rig else meshes[0]
os.makedirs(os.path.dirname(REQ["path"]), exist_ok=True)
try:
    if REQ["format"] == "fbx":
        bpy.ops.export_scene.fbx(filepath=REQ["path"], use_selection=True, object_types={'MESH', 'ARMATURE'} if rig else {'MESH'}, use_mesh_modifiers=True,
            apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z', axis_up='Y', path_mode='COPY', embed_textures=True, bake_anim=False,
            add_leaf_bones=False, use_armature_deform_only=True, primary_bone_axis='Y', secondary_bone_axis='X')
    else:
        bpy.ops.export_scene.gltf(filepath=REQ["path"], export_format='GLB', use_selection=True, export_apply=True)
finally:
    for o, name in added:
        mod = o.modifiers.get(name)
        if mod:
            o.modifiers.remove(mod)
size = (hi - lo) * scene.unit_settings.scale_length
out.update({"path": REQ["path"], "bytes": os.path.getsize(REQ["path"]), "meshes": len(meshes), "triangles": total, "rigged": rig,
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

export interface AnimationRequest {
  armature?: string;
  action?: string;
  fps: number;
  maxFrames: number;
  /** Meters -> studs for bone translations (the model is inserted at real size). */
  scale: number;
  /** Also export an FBX with this animation baked (Studio Animation Editor > Import > From FBX). */
  fbxPath?: string;
}

/**
 * Samples one Blender action: for every sampled frame, each bone's pose relative to its
 * rest pose (matrix_basis: bone space, which the FBX export keeps for Roblox Bones).
 */
export function animationPython(req: AnimationRequest): string {
  return `
import bpy, json, os
REQ = ${pyJson(req)}
out = {"warnings": []}
scene = bpy.context.scene
arm = bpy.data.objects.get(REQ["armature"]) if REQ.get("armature") else None
if arm is None:
    arm = next((o for o in scene.objects if o.type == 'ARMATURE'), None)
if arm is None or arm.type != 'ARMATURE':
    raise Exception("No armature in the Blender scene (rig the character first, or pass armature: <name>).")
if arm.animation_data is None:
    arm.animation_data_create()
previous = arm.animation_data.action
action = bpy.data.actions.get(REQ["action"]) if REQ.get("action") else (previous or next(iter(bpy.data.actions), None))
if action is None:
    raise Exception("No animation (action) found. Animate the armature in Blender first, or pass action: <name>. Actions: " + ", ".join(a.name for a in bpy.data.actions))
arm.animation_data.action = action
fps = scene.render.fps / scene.render.fps_base
start, end = int(action.frame_range[0]), int(action.frame_range[1])
step = max(1, round(fps / REQ["fps"]))
while (end - start) / step + 1 > REQ["maxFrames"]:
    step += 1
frames = list(range(start, end + 1, step))
if frames[-1] != end:
    frames.append(end)
bones = [{"name": b.name, "parent": b.parent.name if b.parent else None} for b in arm.data.bones if b.use_deform or any(c.use_deform for c in b.children_recursive)]
names = set(b["name"] for b in bones)
current = scene.frame_current
samples = []
try:
    for f in frames:
        scene.frame_set(f)
        poses = {}
        for pb in arm.pose.bones:
            if pb.name not in names:
                continue
            loc, rot, _ = pb.matrix_basis.decompose()
            if loc.length < 1e-5 and abs(rot.w) > 0.999999:
                continue
            k = REQ["scale"]
            poses[pb.name] = [round(loc.x * k, 4), round(loc.y * k, 4), round(loc.z * k, 4), round(rot.x, 5), round(rot.y, 5), round(rot.z, 5), round(rot.w, 5)]
        samples.append({"t": round((f - start) / fps, 4), "p": poses})
    if REQ.get("fbxPath"):
        for o in bpy.context.view_layer.objects:
            try:
                o.select_set(False)
            except Exception:
                pass
        arm.select_set(True)
        for child in arm.children_recursive:
            if child.type == 'MESH':
                child.select_set(True)
        bpy.context.view_layer.objects.active = arm
        os.makedirs(os.path.dirname(REQ["fbxPath"]), exist_ok=True)
        bpy.ops.export_scene.fbx(filepath=REQ["fbxPath"], use_selection=True, object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False,
            use_armature_deform_only=True, bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
            apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z', axis_up='Y', path_mode='COPY', embed_textures=True)
        out["fbx"] = REQ["fbxPath"]
finally:
    scene.frame_set(current)
    arm.animation_data.action = previous
out.update({"armature": arm.name, "action": action.name, "actions": [a.name for a in bpy.data.actions], "fps": fps,
            "length": round((end - start) / fps, 3), "frames": len(samples), "bones": bones, "samples": samples})
print("${MARKER}" + json.dumps(out))
`;
}

export interface KeyframeRequest {
  name: string;
  bones: Array<{ name: string; parent?: string | null }>;
  samples: Array<{ t: number; p: Record<string, number[]> }>;
  loop: boolean;
  priority: string;
  /** Studio path of the rigged model (its Bones decide the root pose name). */
  rig?: string;
}

/**
 * Builds a KeyframeSequence in ServerStorage/GameKit/Animations (poses follow the bone
 * hierarchy under the part holding the bones), registers a temporary id to test it right
 * away, and gives the rig an AnimationController + Animator when it has no Humanoid.
 */
export function keyframeLuau(req: KeyframeRequest): string {
  return `
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local req = HttpService:JSONDecode(${luauJson(req)})

local function child(parent, name, className)
	local found = parent:FindFirstChild(name)
	if not found then
		found = Instance.new(className)
		found.Name = name
		found.Parent = parent
	end
	return found
end

local result = { ok = true, warnings = {} }
local rootName = "HumanoidRootPart"
local rig = nil
if req.rig then
	rig = game
	for segment in string.gmatch(req.rig, "[^/%.]+") do
		if rig == game and segment == "game" then continue end
		rig = if rig == game then game:FindFirstChild(segment) or game:GetService(segment) else rig:FindFirstChild(segment)
		if not rig then break end
	end
	if not rig then
		table.insert(result.warnings, "Rig not found: " .. req.rig)
	else
		local bone = rig:FindFirstChildWhichIsA("Bone", true)
		local holder = bone and bone:FindFirstAncestorWhichIsA("BasePart")
		if holder then
			rootName = holder.Name
		else
			table.insert(result.warnings, "The rig has no Bones: import it with blender_to_roblox (a rigged FBX).")
		end
		if not rig:FindFirstChildWhichIsA("Humanoid", true) and not rig:FindFirstChildWhichIsA("AnimationController") then
			local controller = Instance.new("AnimationController")
			controller.Parent = rig
			Instance.new("Animator").Parent = controller
			result.addedAnimator = true
		end
	end
end

local parentOf = {}
for _, b in req.bones do
	parentOf[b.name] = b.parent
end

local kfs = Instance.new("KeyframeSequence")
kfs.Name = req.name
kfs.Loop = req.loop
local okPriority, priority = pcall(function() return (Enum.AnimationPriority :: any)[req.priority] end)
kfs.Priority = if okPriority and priority then priority else Enum.AnimationPriority.Action
for _, sample in req.samples do
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = sample.t
	local root = Instance.new("Pose")
	root.Name = rootName
	root.Parent = keyframe
	local poses = {}
	local function poseFor(boneName)
		if poses[boneName] then return poses[boneName] end
		local pose = Instance.new("Pose")
		pose.Name = boneName
		local p = sample.p[boneName]
		if p then
			pose.CFrame = CFrame.new(p[1], p[2], p[3], p[4], p[5], p[6], p[7])
		end
		local parentName = parentOf[boneName]
		pose.Parent = if parentName then poseFor(parentName) else root
		poses[boneName] = pose
		return pose
	end
	for _, b in req.bones do
		poseFor(b.name)
	end
	keyframe.Parent = kfs
end

local folder = child(child(ServerStorage, "GameKit", "Folder"), "Animations", "Folder")
local old = folder:FindFirstChild(req.name)
if old then old:Destroy() end
kfs.Parent = folder
local okId, tempId = pcall(function() return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs) end)
local animation = Instance.new("Animation")
animation.Name = "TestAnimation"
animation.AnimationId = if okId then tempId else ""
animation.Parent = kfs
result.path = kfs:GetFullName()
result.keyframes = #req.samples
result.rootPose = rootName
result.tempId = if okId then tempId else nil
return HttpService:JSONEncode(result)
`;
}

/** Gives a model an AnimationController + Animator unless it already animates (Humanoid). */
export function animatorLuau(modelPath: string): string {
  return `
local HttpService = game:GetService("HttpService")
local node = game
for segment in string.gmatch(${luauJson(modelPath)}, "[^/%.]+") do
	if node == game and segment == "game" then continue end
	node = if node == game then game:FindFirstChild(segment) or game:GetService(segment) else node:FindFirstChild(segment)
	if not node then break end
end
if not node then return HttpService:JSONEncode({ ok = false, error = "model not found" }) end
local bones = node:FindFirstChildWhichIsA("Bone", true) ~= nil
if node:FindFirstChildWhichIsA("Humanoid", true) or node:FindFirstChildWhichIsA("AnimationController", true) then
	return HttpService:JSONEncode({ ok = true, bones = bones, added = false })
end
local controller = Instance.new("AnimationController")
controller.Parent = node
Instance.new("Animator").Parent = controller
return HttpService:JSONEncode({ ok = true, bones = bones, added = true })
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
const IMAGE_EXTENSIONS = new Set(['.png', '.jpg', '.jpeg', '.webp']);

/**
 * Reference images for AI generation: http(s) URLs, or absolute paths of local image files.
 * Their bytes go to a third-party API, so anything that is not an image file is refused.
 */
function referenceImages(value: unknown): { urls: string[]; files: string[] } {
  const list = value === undefined || value === null ? [] : Array.isArray(value) ? value.map(String) : [String(value)];
  const urls: string[] = [];
  const files: string[] = [];
  for (const item of list) {
    if (/^https?:\/\//i.test(item)) {
      urls.push(item);
      continue;
    }
    if (!path.isAbsolute(item)) throw new Error(`Image path must be absolute: ${item}`);
    if (!IMAGE_EXTENSIONS.has(path.extname(item).toLowerCase())) throw new Error(`Not an image file (png, jpg, jpeg, webp): ${item}`);
    if (!fs.existsSync(item)) throw new Error(`Image not found: ${item}`);
    files.push(item);
  }
  if (urls.length && files.length) throw new Error('Give either image URLs or local image files, not both.');
  return { urls, files };
}

export const BLENDER_TOOLS: ToolDef[] = [
  {
    name: 'blender_status',
    category: 'read',
    description: 'Blender link for custom 3D models: checks the connection, lists the scene, explains the addon setup. When connected, more blender_* tools appear.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'blender_to_roblox',
    category: 'write',
    tier: 'starter',
    description: 'Send a Blender model into the game: export (<= 20k triangles/mesh), upload (Open Cloud key), insert at real size on the ground. Without a key: exported file + manual import. Slow: use start_job. roblox_guide blender.',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        objects: { type: 'array', items: { type: 'string' }, description: 'Blender objects (default all visible meshes)' },
        position: { type: 'array', items: { type: 'number' }, description: '[x,y,z] bottom center, studs' },
        size: { type: 'number', description: 'Largest dimension in studs (default real size)' },
        yaw: { type: 'number' },
        assetId: { type: 'number', description: 'Insert an existing Roblox model instead' },
        existing: { type: 'string', description: 'Only resize/place a model already in Studio' },
        rig: { type: 'boolean', description: 'Export the armature too (default: when the model has one)' },
      },
      required: ['name'],
    },
  },
  {
    name: 'blender_animation',
    category: 'write',
    tier: 'blender',
    description: 'Blender action (animation of an armature) -> Roblox KeyframeSequence in ServerStorage/GameKit/Animations, testable at once (temporary id), + an animated FBX for Animation Editor import. Import the rigged model first with blender_to_roblox.',
    inputSchema: {
      type: 'object',
      properties: {
        rig: { type: 'string', description: 'Studio path of the rigged model (from blender_to_roblox)' },
        action: { type: 'string', description: 'Blender action (default: the current one)' },
        armature: { type: 'string' },
        name: { type: 'string', description: 'Animation name (default: the action name)' },
        fps: { type: 'number', description: 'Keyframes per second (default 30)' },
        loop: { type: 'boolean', description: 'default true' },
        priority: { type: 'string', enum: ['Core', 'Idle', 'Movement', 'Action'] },
        fbx: { type: 'boolean', description: 'Also export an animated FBX (default true)' },
      },
    },
  },
  {
    name: 'blender_python',
    category: 'write',
    tier: 'blender',
    description: 'Run Python (bpy) in Blender, in small steps; print() what you need. Model in meters, base at Z=0, < 20k triangles, 1 material per mesh.',
    inputSchema: { type: 'object', properties: { code: { type: 'string' } }, required: ['code'] },
  },
  {
    name: 'blender_scene',
    category: 'read',
    tier: 'blender',
    description: 'Blender scene: objects (meters, triangles, materials), one object in detail, and/or a viewport screenshot.',
    inputSchema: {
      type: 'object',
      properties: { object: { type: 'string' }, screenshot: { type: 'boolean' }, maxSize: { type: 'number', description: 'default 640' } },
    },
  },
  {
    name: 'blender_assets',
    category: 'write',
    tier: 'blender',
    description: 'Ready-made 3D content into Blender: search/download (polyhaven, sketchfab, polypizza) or AI generation from text and/or reference images (hyper3d, hunyuan3d: generate, poll, import). Enable sources in the addon panel.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['status', 'search', 'download', 'generate', 'poll', 'import', 'texture'] },
        source: { type: 'string', enum: [...ASSET_SOURCES] },
        query: { type: 'string' },
        images: {
          type: 'array',
          items: { type: 'string' },
          description: 'generate: reference images (e.g. concept views on a white background). Absolute .png/.jpg/.jpeg/.webp paths or http(s) URLs. hyper3d: several views of one object (paths with Rodin Mode "hyper3d.ai", URLs with "fal.ai"); hunyuan3d: exactly 1, used instead of query',
        },
        id: { type: 'string' },
        assetType: { type: 'string', enum: ['models', 'textures', 'hdris', 'all'] },
        categories: { type: 'string' },
        resolution: { type: 'string' },
        targetSize: { type: 'number', description: 'meters' },
        name: { type: 'string' },
        url: { type: 'string' },
        object: { type: 'string' },
        limit: { type: 'number' },
      },
      required: ['action'],
    },
  },
  {
    name: 'blender_command',
    category: 'write',
    tier: 'builder',
    description: 'Advanced: raw command to the Blender addon ({type, params}).',
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
      case 'blender_animation': return this.animation(args);
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
      await this.client.command('get_viewport_screenshot', { max_size: Number(args.maxSize ?? 640), filepath: file, format: 'png' });
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
        const { urls, files } = referenceImages(args.images);
        const prompt = args.query ? String(args.query) : null;
        if (!prompt && !urls.length && !files.length) throw new Error('"query" or "images" is required to generate');
        // MAIN_SITE mode uploads the bytes as [suffix, base64] pairs; FAL_AI mode takes URLs.
        const images = files.length ? files.map((f) => [path.extname(f), fs.readFileSync(f).toString('base64')]) : urls.length ? urls : null;
        const job = await c<any>('create_rodin_job', { text_prompt: prompt, images, bbox_condition: null });
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
        const { urls, files } = referenceImages(args.images);
        const image = [...files, ...urls];
        if (image.length > 1) throw new Error('hunyuan3d takes one image: pick the clearest view (front or three-quarter).');
        // The official API refuses a prompt and an image together: the image wins.
        const job = await c<any>('create_hunyuan_job', image.length
          ? { text_prompt: null, image: image[0] }
          : { text_prompt: this.need(args.query, 'query'), image: null });
        const id = job?.Response?.JobId ? `job_${job.Response.JobId}` : undefined;
        return text({ job, id, ...(image.length && args.query ? { note: 'query ignored: hunyuan3d generates from the image alone' } : {}), next: 'Call blender_assets {action:"poll", source:"hunyuan3d", id} until status DONE, then {action:"import", source:"hunyuan3d", name, url: <.glb url from ResultFile3Ds>}.' });
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
    let rigged = false;

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
        rig: args.rig === false ? false : undefined,
      })));
      rigged = exported.rigged === true;
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
    if (inserted?.ok && rigged && inserted.path) {
      // A skinned model needs an Animator to play animations (Humanoid rigs already have one).
      steps.animator = await runLuauJson(this.host, animatorLuau(String(inserted.path)), 'Add Animator').catch((e) => errorMessage(e));
    }
    return text({
      ok: !!inserted?.ok,
      assetId,
      path: inserted?.path,
      sizeStuds: inserted?.size,
      rigged: rigged || undefined,
      steps,
      next: !inserted?.ok
        ? 'Roblox may still be processing/moderating the upload: wait a minute and call blender_to_roblox again with {"name", "assetId"}.'
        : rigged
          ? `Rigged model ready. Animate it: blender_animation {"rig": "${inserted.path}", "action": "<Blender action>"} for each animation (Idle, Walk, Attack...).`
          : 'Check it with look_at_game (or capture_screenshot). Clone it around with populate_world {items:[{from: "<path>", count: 10}]}.',
    });
  }

  async animation(args: Record<string, any>): Promise<ToolResult> {
    const dir = path.join(os.tmpdir(), 'roblox-ultimate-mcp', 'blender');
    const tag = String(args.name ?? args.action ?? 'Animation').replace(/[^\w-]/g, '_');
    const sampled = await this.connected(() => this.client.pythonJson(animationPython({
      armature: args.armature ? String(args.armature) : undefined,
      action: args.action ? String(args.action) : undefined,
      fps: Math.max(5, Math.min(60, Number(args.fps) || 30)),
      maxFrames: 400,
      scale: STUDS_PER_METER,
      fbxPath: args.fbx === false ? undefined : path.join(dir, `${tag}-${Date.now()}.fbx`),
    }), 300_000));
    const name = String(args.name ?? sampled.action ?? 'Animation').replace(/[^\w -]/g, '').trim() || 'Animation';
    let fbx: string | undefined;
    if (sampled.fbx) {
      try {
        fbx = await this.ensureLocal(sampled.fbx, fs.existsSync(sampled.fbx) ? fs.statSync(sampled.fbx).size : 20 * 1024 * 1024);
      } catch {
        fbx = sampled.fbx;
      }
    }
    const summary = { action: sampled.action, otherActions: (sampled.actions ?? []).filter((a: string) => a !== sampled.action), seconds: sampled.length, keyframes: sampled.frames, bones: sampled.bones?.length, warnings: sampled.warnings };
    if (!this.host.isStudioConnected()) {
      return text({ ok: false, ...summary, fbx, problem: 'Studio is not connected: the animation was sampled but not created.', next: 'Connect Studio and call blender_animation again.' });
    }
    const built = await runLuauJson(this.host, keyframeLuau({
      name,
      bones: sampled.bones ?? [],
      samples: sampled.samples ?? [],
      loop: args.loop !== false,
      priority: String(args.priority ?? 'Action'),
      rig: args.rig ? String(args.rig) : undefined,
    }), 'Build animation');
    return text({
      ok: !!built?.ok,
      ...summary,
      keyframeSequence: built?.path,
      rootPose: built?.rootPose,
      testId: built?.tempId,
      fbx,
      warnings: [...(summary.warnings ?? []), ...(built?.warnings ?? [])],
      play: `local animator = rig:FindFirstChildWhichIsA("Animator", true); local track = animator:LoadAnimation(animation); track:Play()`,
      next: [
        `Test now in Studio (Play): an Animation with AnimationId = testId (temporary, works in Studio only) is inside ${built?.path ?? 'the KeyframeSequence'}.`,
        'For the live game, publish it: right-click the KeyframeSequence > Save to Roblox (or Animation Editor > ... > Publish to Roblox), then put the new rbxassetid in your script and run check_assets {ids: [id]}.',
        fbx ? `If the pose looks wrong: Animation Editor > select the rig > ... > Import > From FBX Animation > ${fbx}.` : undefined,
      ].filter(Boolean),
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
