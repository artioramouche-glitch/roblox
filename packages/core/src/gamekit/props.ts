/**
 * Props: put models in the world the way a level designer would.
 *   - placeModelLuau: load a Roblox asset (or take a model already in Studio), resize it to
 *     a size in studs, rotate it and stand it on a point (bottom center), anchored.
 *   - populate_world: fill an area (or a claimed zone) with decoration in one call:
 *     procedural pieces by theme, Creator Store / Blender assets, or clones of an existing
 *     model; everything snapped to the ground and removed if it would block gameplay.
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { install, runLuauJson, splitPath, type InstanceNode } from './installer.js';
import { luauJson, text, vec3, type ToolResult, type Vec3 } from './result.js';
import { DECOR_PIECES, piece, rng } from './world.js';
import { findZone } from './team.js';

// Shared Luau helpers (plugin context, edit mode).
const PRELUDE = `
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function findPath(segments)
	local node = game
	for _, name in segments do
		local child = nil
		if node == game then
			local ok, service = pcall(function() return game:GetService(name) end)
			child = if ok and service then service else game:FindFirstChild(name)
		else
			child = node:FindFirstChild(name)
		end
		if not child then return nil end
		node = child
	end
	return node
end

local function ensurePath(segments)
	local node = game
	for _, name in segments do
		if node == game then
			node = game:GetService(name)
		else
			local child = node:FindFirstChild(name)
			if not child then
				child = Instance.new("Folder")
				child.Name = name
				child.Parent = node
			end
			node = child
		end
	end
	return node
end

local function loadAsset(id)
	local ok, wrapper = pcall(function() return game:GetService("AssetService"):LoadAssetAsync(id) end)
	if ok and wrapper then return wrapper, nil end
	local ok2, wrapper2 = pcall(function() return game:GetService("InsertService"):LoadAsset(id) end)
	if ok2 and wrapper2 then return wrapper2, nil end
	return nil, tostring(wrapper) .. " | " .. tostring(wrapper2)
end

local function asModel(instances, name)
	if #instances == 1 and instances[1]:IsA("Model") then
		instances[1].Name = name
		return instances[1]
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, instance in instances do instance.Parent = model end
	return model
end

local function bounds(model)
	local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
	if ok then return cf, size end
	return nil, nil
end

local function fit(model, size, yaw)
	if size and size > 0 then
		local _, s = bounds(model)
		if s then
			local maxDim = math.max(s.X, s.Y, s.Z)
			if maxDim > 0 and math.abs(size / maxDim - 1) > 0.001 then
				model:ScaleTo(model:GetScale() * size / maxDim)
			end
		end
	end
	if yaw and yaw ~= 0 then
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(yaw), 0))
	end
end

local function placeBottom(model, pos)
	local cf, s = bounds(model)
	if not cf then
		model:PivotTo(CFrame.new(pos))
		return
	end
	local bottom = Vector3.new(cf.Position.X, cf.Position.Y - s.Y / 2, cf.Position.Z)
	model:PivotTo(model:GetPivot() + (pos - bottom))
end

local function setPhysics(model, anchored, collide)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
			if collide == false then d.CanCollide = false end
		end
	end
	if model:IsA("BasePart") then model.Anchored = anchored end
end

local function groundY(x, z, fromY, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -2000, 0), params)
	if hit then return hit.Position.Y, hit.Instance end
	return nil, nil
end

-- Decoration may only stand on terrain or on a big floor, never on a road, pad or platform.
local function isGround(instance)
	if instance == workspace.Terrain then return true end
	return instance:IsA("BasePart") and instance.Size.X >= 40 and instance.Size.Z >= 40
end

local function overlaps(model, ignore)
	local cf, s = bounds(model)
	if not cf then return false end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local box = Vector3.new(math.max(0.2, s.X * 0.8), math.max(0.2, s.Y * 0.8), math.max(0.2, s.Z * 0.8))
	local ok, parts = pcall(function() return workspace:GetPartBoundsInBox(cf * CFrame.new(0, s.Y * 0.1, 0), box, params) end)
	if not ok then return false end
	for _, p in parts do
		if p ~= workspace.Terrain and p.Transparency < 1 then
			return true
		end
	end
	return false
end

local function pathOf(instance)
	local names = {}
	local node = instance
	while node and node ~= game do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	return table.concat(names, "/")
end
`;

export interface PlaceModelRequest {
  name: string;
  assetId?: number;
  existing?: string;
  parent: string;
  position: Vec3;
  size?: number;
  yaw?: number;
  anchored?: boolean;
  collide?: boolean;
  replace?: boolean;
}

/** Luau that inserts one model and returns {ok, path, size, parts} as JSON. */
export function placeModelLuau(req: PlaceModelRequest): string {
  const payload = { ...req, parent: splitPath(req.parent), existing: req.existing ? splitPath(req.existing) : undefined };
  return `${PRELUDE}
local req = HttpService:JSONDecode(${luauJson(payload)})
local recording = ChangeHistoryService:TryBeginRecording("GameKit: place " .. req.name)
local ok, result = pcall(function()
	local parent = ensurePath(req.parent)
	local model
	if req.existing then
		local found = findPath(req.existing)
		if not found then error("Not found in Studio: " .. table.concat(req.existing, "/")) end
		model = asModel({ found }, req.name)
	else
		local wrapper, err = loadAsset(req.assetId)
		if not wrapper then error("Could not load asset " .. tostring(req.assetId) .. " (still processing, not owned by you, or not a model): " .. tostring(err)) end
		model = asModel(wrapper:GetChildren(), req.name)
		wrapper:Destroy()
	end
	if req.replace then
		local old = parent:FindFirstChild(req.name)
		if old and old ~= model then old:Destroy() end
	end
	model.Parent = parent
	fit(model, req.size, req.yaw)
	placeBottom(model, Vector3.new(req.position[1], req.position[2], req.position[3]))
	setPhysics(model, req.anchored ~= false, req.collide)
	local _, s = bounds(model)
	local parts = 0
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
	return { ok = true, path = pathOf(model), size = if s then { math.floor(s.X * 10) / 10, math.floor(s.Y * 10) / 10, math.floor(s.Z * 10) / 10 } else nil, parts = parts }
end)
if recording then
	ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then return HttpService:JSONEncode({ ok = false, error = tostring(result) }) end
return HttpService:JSONEncode(result)`;
}

// --- populate_world ----------------------------------------------------------------------------

export const POPULATE_THEMES: Record<string, Array<[string, number, Record<string, unknown>?]>> = {
  forest: [['tree', 45], ['pine_tree', 25], ['bush', 15], ['rock', 10], ['mushroom', 5]],
  desert: [['cactus', 45], ['rock', 35], ['palm_tree', 10], ['barrel', 10]],
  snow: [['pine_tree', 60, { snow: true }], ['rock', 25], ['crystal', 15, { color: '#80deea' }]],
  beach: [['palm_tree', 50], ['rock', 20], ['bush', 15], ['barrel', 15]],
  fantasy: [['crystal', 35], ['mushroom', 30], ['tree', 20], ['flowers', 15]],
  city: [['lamp', 35], ['bench', 30], ['bush', 20], ['barrel', 15]],
  farm: [['tree', 30], ['bush', 30], ['flowers', 20], ['barrel', 10], ['crate', 10]],
  spooky: [['pine_tree', 40, { color: '#4e342e' }], ['rock', 30], ['lamp', 20, { flicker: true }], ['crate', 10]],
  garden: [['flowers', 40], ['bush', 30], ['tree', 20], ['bench', 10]],
};

interface PopulateItem {
  kind?: string;
  assetId?: number;
  from?: string;
  count?: number;
  size?: number | [number, number];
  options?: Record<string, unknown>;
}

export interface Area {
  center: Vec3;
  /** Rectangle [width, depth] or circle radius. */
  size?: [number, number];
  radius?: number;
  clear?: number;
}

export const POPULATE_TOOLS: ToolDef[] = [
  {
    name: 'populate_world',
    category: 'write',
    tier: 'starter',
    description: 'Fill an area with scenery in one call, on terrain/big floors, never blocking gameplay: a theme and/or items [{kind|assetId|from, count, size}]. Same name = replaced.',
    inputSchema: {
      type: 'object',
      properties: {
        theme: { type: 'string', enum: Object.keys(POPULATE_THEMES) },
        count: { type: 'number', description: 'Props for a theme (default 30)' },
        items: { type: 'array', items: { type: 'object' }, description: `kind: ${DECOR_PIECES.join('|')}; assetId: Roblox model; from: "Workspace/..." to clone; size: [min,max] studs` },
        center: { type: 'array', items: { type: 'number' } },
        radius: { type: 'number', description: 'default 150 (more: roblox_guide building)' },
        zone: { type: 'string' },
        name: { type: 'string', description: 'default Decor' },
      },
    },
  },
];

export function scatter(area: Area, count: number, spacing: number, seed: number): Array<[number, number]> {
  const r = rng(seed);
  const points: Array<[number, number]> = [];
  const [cx, , cz] = area.center;
  const attempts = count * 30;
  for (let i = 0; i < attempts && points.length < count; i++) {
    let x: number;
    let z: number;
    if (area.size) {
      x = cx + (r() - 0.5) * area.size[0];
      z = cz + (r() - 0.5) * area.size[1];
      if (area.clear && Math.hypot(x - cx, z - cz) < area.clear) continue;
    } else {
      const radius = area.radius ?? 150;
      const clear = Math.min(area.clear ?? 40, radius * 0.9);
      const a = r() * Math.PI * 2;
      const d = Math.sqrt(clear * clear + r() * (radius * radius - clear * clear));
      x = cx + Math.cos(a) * d;
      z = cz + Math.sin(a) * d;
    }
    if (points.some(([px, pz]) => Math.hypot(px - x, pz - z) < spacing)) continue;
    points.push([x, z]);
  }
  return points;
}

function pickWeighted<T>(entries: Array<[T, number]>, r: () => number): T {
  const total = entries.reduce((n, [, w]) => n + w, 0);
  let roll = r() * total;
  for (const [value, weight] of entries) {
    roll -= weight;
    if (roll <= 0) return value;
  }
  return entries[entries.length - 1][0];
}

function sizeFor(size: PopulateItem['size'], r: () => number): number | undefined {
  if (typeof size === 'number' && size > 0) return size;
  if (Array.isArray(size) && size.length === 2) return size[0] + r() * (size[1] - size[0]);
  return undefined;
}

export async function populateWorld(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  const name = String(args.name ?? 'Decor').replace(/[^\w -]/g, '') || 'Decor';
  const seed = Number(args.seed ?? 7);
  const r = rng(seed * 31 + 1);
  let area: Area = {
    center: vec3(args.center, [0, 0, 0]),
    radius: Number(args.radius ?? 150),
    clear: Number(args.clear ?? 40),
  };
  if (Array.isArray(args.size) && args.size.length >= 2) area = { center: area.center, size: [Number(args.size[0]), Number(args.size[1])], clear: Number(args.clear ?? 0) };
  if (args.zone) {
    const zone = await findZone(host, String(args.zone));
    if (!zone) throw new Error(`Zone "${args.zone}" does not exist. List zones with team {"action": "zones"}.`);
    area = { center: [zone.center[0], zone.center[1] - zone.size[1] / 2, zone.center[2]], size: [zone.size[0] - 4, zone.size[2] - 4], clear: Number(args.clear ?? 0) };
  }

  // What to place: a theme mix and/or explicit items.
  const wanted: PopulateItem[] = [];
  if (args.theme) {
    const theme = POPULATE_THEMES[String(args.theme)];
    if (!theme) throw new Error(`Unknown theme "${args.theme}". Themes: ${Object.keys(POPULATE_THEMES).join(', ')}`);
    const total = Math.max(1, Math.min(300, Number(args.count ?? 30)));
    const counts = new Map<number, number>();
    for (let i = 0; i < total; i++) {
      const index = pickWeighted(theme.map((entry, k) => [k, entry[1]] as [number, number]), r);
      counts.set(index, (counts.get(index) ?? 0) + 1);
    }
    for (const [index, count] of counts) wanted.push({ kind: theme[index][0], count, options: theme[index][2] });
  }
  for (const item of (Array.isArray(args.items) ? args.items : []) as PopulateItem[]) {
    if (!item || (!item.kind && !item.assetId && !item.from)) throw new Error('Each item needs kind, assetId or from');
    if (item.kind && !(DECOR_PIECES as readonly string[]).includes(item.kind)) {
      throw new Error(`"${item.kind}" is not a decoration piece. Use: ${DECOR_PIECES.join(', ')} (gameplay pieces go through build_world).`);
    }
    wanted.push({ ...item, count: Math.max(1, Math.min(200, Number(item.count ?? 5))) });
  }
  if (!wanted.length) wanted.push({ kind: 'tree', count: 20 }, { kind: 'rock', count: 8 }, { kind: 'bush', count: 8 });

  const total = wanted.reduce((n, w) => n + (w.count ?? 0), 0);
  const points = scatter(area, total, Math.max(2, Number(args.spacing ?? 8)), seed);
  const baseY = area.center[1];
  let cursor = 0;
  const nodes: InstanceNode[] = [];
  const assetItems: Array<{ assetId?: number; from?: string[]; name: string; placements: number[][] }> = [];
  for (const item of wanted) {
    const slice = points.slice(cursor, cursor + (item.count ?? 0));
    cursor += slice.length;
    if (item.kind) {
      slice.forEach(([x, z], k) => nodes.push(piece(item.kind!, [x, baseY, z], { ...(item.options ?? {}), name: `${item.kind}${k + 1}`, seed: seed + k * 13, yaw: Math.round(r() * 360) })));
    } else {
      const label = item.assetId ? `Asset${item.assetId}` : String(item.from).split(/[./]/).pop() ?? 'Prop';
      assetItems.push({
        assetId: item.assetId ? Number(item.assetId) : undefined,
        from: item.from ? splitPath(String(item.from)) : undefined,
        name: label,
        placements: slice.map(([x, z]) => [x, baseY, z, Math.round(r() * 360), sizeFor(item.size, r) ?? 0]),
      });
    }
  }

  const report = await install(host, {
    label: `GameKit: populate ${name}`,
    items: [{ parent: ['Workspace', 'GameKit'], mode: 'replace', node: { name, className: 'Folder', children: nodes } }],
  });
  if (!report.ok) return text({ ok: false, error: report.error, install: report });

  const pass = {
    folder: ['Workspace', 'GameKit', name],
    items: assetItems,
    snap: args.snap !== false,
    avoid: args.avoidGameplay !== false,
    lift: 30,
  };
  const placed = await runLuauJson<any>(host, `${PRELUDE}
local req = HttpService:JSONDecode(${luauJson(pass)})
local folder = findPath(req.folder)
local recording = ChangeHistoryService:TryBeginRecording("GameKit: place decor")
local stats = { placed = 0, snapped = 0, removed = 0, errors = {} }
local ok, err = pcall(function()
	for _, item in req.items do
		local template, owned = nil, false
		if item.assetId then
			local wrapper, e = loadAsset(item.assetId)
			if wrapper then
				template = asModel(wrapper:GetChildren(), item.name)
				wrapper:Destroy()
				owned = true
			else
				table.insert(stats.errors, "asset " .. tostring(item.assetId) .. ": " .. tostring(e))
			end
		elseif item.from then
			local found = findPath(item.from)
			if found then template = found else table.insert(stats.errors, "not found: " .. table.concat(item.from, "/")) end
		end
		if template then
			for i, p in item.placements do
				local clone = template:Clone()
				if not clone:IsA("Model") then clone = asModel({ clone }, item.name) end
				clone.Name = item.name .. i
				clone.Parent = folder
				fit(clone, if p[5] > 0 then p[5] else nil, p[4])
				placeBottom(clone, Vector3.new(p[1], p[2], p[3]))
				setPhysics(clone, true, nil)
			end
			if owned then template:Destroy() end
		end
	end
	local ignore = { folder }
	for _, child in folder:GetChildren() do
		local cf, s = bounds(child)
		if cf then
			local blocked = false
			if req.snap then
				local bottom = cf.Position.Y - s.Y / 2
				local y, ground = groundY(cf.Position.X, cf.Position.Z, bottom + req.lift, ignore)
				if y and ground and req.avoid and not isGround(ground) then
					blocked = true
				elseif y then
					child:PivotTo(child:GetPivot() + Vector3.new(0, y - bottom, 0))
					stats.snapped += 1
				end
			end
			if blocked or (req.avoid and overlaps(child, ignore)) then
				child:Destroy()
				stats.removed += 1
			else
				stats.placed += 1
			end
		else
			stats.placed += 1
		end
	end
end)
if recording then
	ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then table.insert(stats.errors, tostring(err)) end
stats.ok = ok
return HttpService:JSONEncode(stats)`, 'Populate world');

  return text({
    ok: !!placed?.ok,
    summary: `${placed?.placed ?? 0} props in Workspace/GameKit/${name} (${placed?.removed ?? 0} dropped because they blocked something, ${placed?.snapped ?? 0} snapped to the ground).`,
    requested: total,
    positionsFound: points.length,
    errors: Array.isArray(placed?.errors) && placed.errors.length ? placed.errors : undefined,
    next: 'Check the result with look_at_game. Call again with the same name to regenerate (change seed for another layout).',
  });
}
