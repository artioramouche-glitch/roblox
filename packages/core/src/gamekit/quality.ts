/**
 * Quality before publishing.
 *   check_assets  -- every sound / animation / image the game uses really loads, and
 *                    animations belong to the game's owner (private assets are silent in
 *                    live games, a very common mistake).
 *   optimize_game -- a budget for entry-level phones (parts, physics, shadows, lights,
 *                    particles, streaming, per-frame scripts) with safe one-call fixes.
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { runLuauJson } from './installer.js';
import { luauJson, text, type ToolResult } from './result.js';

export const QUALITY_TOOLS: ToolDef[] = [
  {
    name: 'check_assets',
    category: 'read',
    tier: 'builder',
    description: 'Checks that sounds, animations and images really load (and that animations belong to the game owner) before players hear silence. Scans the whole game, or tests the ids you give.',
    inputSchema: {
      type: 'object',
      properties: {
        ids: { type: 'array', items: { type: ['number', 'string'] }, description: 'Asset ids to test (e.g. a sound before using it). Omit to scan the game.' },
        scan: { type: 'boolean', description: 'Scan the game too (default: only when no ids)' },
        max: { type: 'number', description: 'Max assets checked (default 40)' },
      },
    },
  },
  {
    name: 'optimize_game',
    category: 'write',
    tier: 'builder',
    description: 'Performance report for entry-level phones (parts, physics, shadows, lights, particles, streaming, heavy scripts) with safe fixes: apply ["shadows","lights","particles","streaming","technology"].',
    inputSchema: {
      type: 'object',
      properties: {
        apply: { type: 'array', items: { type: 'string', enum: ['shadows', 'lights', 'particles', 'streaming', 'technology', 'all'] }, description: 'Fixes to apply (default: report only)' },
      },
    },
  },
];

// --- check_assets ----------------------------------------------------------------------------

const ASSETS_LUAU = `
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local MarketplaceService = game:GetService("MarketplaceService")
local opts = HttpService:JSONDecode(__REQ__)
local MAX = opts.max or 40

local found, order = {}, {}
local function add(rawId, where, hint)
	local id = tonumber(rawId)
	if not id or id <= 0 then
		return
	end
	local key = tostring(id)
	local entry = found[key]
	if not entry then
		if #order >= MAX then
			return
		end
		entry = { id = id, uses = {}, hint = hint }
		found[key] = entry
		table.insert(order, key)
	end
	if hint and not entry.hint then
		entry.hint = hint
	end
	if where and #entry.uses < 3 and not table.find(entry.uses, where) then
		table.insert(entry.uses, where)
	end
end

local function idsIn(value)
	local out = {}
	if type(value) ~= "string" then
		return out
	end
	for id in string.gmatch(value, "rbxassetid://(%d+)") do
		table.insert(out, id)
	end
	for id in string.gmatch(value, "[?&]id=(%d+)") do
		table.insert(out, id)
	end
	return out
end

for _, id in opts.ids or {} do
	add(id, nil, nil)
end

if opts.scan then
	local roots = { workspace, game:GetService("ReplicatedStorage"), game:GetService("ServerStorage"), game:GetService("ServerScriptService"),
		game:GetService("StarterGui"), game:GetService("StarterPlayer"), game:GetService("StarterPack"), game:GetService("SoundService"), game:GetService("Lighting") }
	for _, root in roots do
		for _, inst in root:GetDescendants() do
			if inst.Name == "GameKitBackups" then
				continue
			end
			local where = inst:GetFullName()
			if string.find(where, "GameKitBackups", 1, true) then
				continue
			end
			if inst:IsA("Sound") then
				for _, id in idsIn(inst.SoundId) do add(id, where, "Audio") end
			elseif inst:IsA("Animation") then
				for _, id in idsIn(inst.AnimationId) do add(id, where, "Animation") end
			elseif inst:IsA("Decal") or inst:IsA("Texture") then
				for _, id in idsIn(inst.Texture) do add(id, where, "Image") end
			elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
				for _, id in idsIn(inst.Image) do add(id, where, "Image") end
			elseif inst:IsA("LuaSourceContainer") then
				local ok, source = pcall(function()
					return (inst :: any).Source
				end)
				if ok then
					for _, id in idsIn(source) do add(id, where, nil) end
				end
			end
		end
	end
end

local TYPES = { [1] = "Image", [3] = "Audio", [4] = "Mesh", [10] = "Model", [13] = "Decal", [24] = "Animation", [40] = "MeshPart", [62] = "Video" }

local ownerId, ownerType = game.CreatorId, game.CreatorType.Name
if ownerId == 0 then
	local ok, userId = pcall(function()
		return game:GetService("StudioService"):GetUserId()
	end)
	if ok and type(userId) == "number" and userId > 0 then
		ownerId, ownerType = userId, "User"
	end
end

local function loadStatus(kind, id)
	local inst
	if kind == "Audio" then
		inst = Instance.new("Sound")
		inst.SoundId = "rbxassetid://" .. id
	elseif kind == "Animation" then
		inst = Instance.new("Animation")
		inst.AnimationId = "rbxassetid://" .. id
	elseif kind == "Image" or kind == "Decal" then
		inst = Instance.new("Decal")
		inst.Texture = "rbxassetid://" .. id
	else
		return nil, nil
	end
	local status = nil
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync({ inst }, function(_, fetchStatus)
			status = fetchStatus
		end)
	end)
	local seconds = nil
	if inst:IsA("Sound") then
		seconds = math.floor(inst.TimeLength * 10) / 10
	end
	inst:Destroy()
	if not ok then
		return "Error: " .. tostring(err), seconds
	end
	return (if status then status.Name else "Unknown"), seconds
end

local results = {}
for _, key in order do
	local entry = found[key]
	local row = { id = entry.id, uses = entry.uses }
	local ok, info = pcall(function()
		return (MarketplaceService :: any):GetProductInfoAsync(entry.id, Enum.InfoType.Asset)
	end)
	if not ok then
		-- Older Studio builds only have the deprecated name.
		ok, info = pcall(function()
			return (MarketplaceService :: any):GetProductInfo(entry.id, Enum.InfoType.Asset)
		end)
	end
	if ok and type(info) == "table" then
		row.name = info.Name
		row.kind = TYPES[info.AssetTypeId] or ("Type" .. tostring(info.AssetTypeId))
		local creator = info.Creator or {}
		row.creator = creator.Name
		row.creatorId = creator.CreatorTargetId or creator.Id
		row.creatorType = creator.CreatorType
		row.byRoblox = row.creatorId == 1
		row.byOwner = ownerId > 0 and row.creatorId == ownerId and tostring(row.creatorType) == ownerType
	else
		row.kind = entry.hint
		row.infoError = tostring(info)
	end
	row.status, row.seconds = loadStatus(row.kind or entry.hint, entry.id)
	table.insert(results, row)
end

return HttpService:JSONEncode({ owner = { id = ownerId, type = ownerType }, checked = #results, results = results })
`;

export function assetsLuau(req: { ids?: Array<number | string>; scan?: boolean; max?: number }): string {
  return ASSETS_LUAU.replace('__REQ__', () => luauJson(req));
}

export interface AssetRow {
  id: number;
  name?: string;
  kind?: string;
  creator?: string;
  creatorId?: number;
  byRoblox?: boolean;
  byOwner?: boolean;
  status?: string;
  seconds?: number;
  infoError?: string;
  uses?: string[];
}

/** Classifies one checked asset: ok, broken (will not load) or risky (may not load for players). */
export function assetVerdict(row: AssetRow): { verdict: 'ok' | 'broken' | 'risky'; why?: string } {
  const failed = row.status === 'Failure' || row.status === 'TimedOut' || String(row.status ?? '').startsWith('Error');
  if (row.infoError && failed) return { verdict: 'broken', why: 'Unknown asset (wrong id, deleted or moderated).' };
  if (failed) return { verdict: 'broken', why: `Does not load (${row.status}): private, deleted or moderated.` };
  if (row.kind === 'Audio' && row.status === 'Success' && row.seconds === 0) return { verdict: 'broken', why: 'Loads but has no length (moderated or empty audio).' };
  if (row.kind === 'Animation' && !row.byRoblox && !row.byOwner) {
    return { verdict: 'risky', why: `Animation made by ${row.creator ?? 'someone else'}: animations only play in games owned by their creator. Re-upload it from your account/group (Animation Editor, or blender_animation) or use a Roblox animation.` };
  }
  if (row.kind === 'Audio' && !row.byRoblox && !row.byOwner && row.status !== 'Success') {
    return { verdict: 'risky', why: `Audio by ${row.creator ?? 'someone else'} could not be confirmed: make sure it is public on the Creator Store.` };
  }
  if (row.kind && !['Audio', 'Animation', 'Image', 'Decal', 'Mesh', 'MeshPart', 'Model', 'Video'].includes(row.kind)) {
    return { verdict: 'risky', why: `This id is a ${row.kind}, check it is used in the right place.` };
  }
  return { verdict: 'ok' };
}

export async function checkAssets(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  const ids = Array.isArray(args.ids) ? args.ids.filter((v: unknown) => /^\d+$/.test(String(v).replace(/^rbxassetid:\/\//, ''))).map((v: unknown) => String(v).replace(/^rbxassetid:\/\//, '')) : [];
  const scan = args.scan ?? ids.length === 0;
  const max = Math.max(1, Math.min(120, Number(args.max) || 40));
  const report = await runLuauJson<{ checked: number; results: AssetRow[]; owner: { id: number; type: string } }>(host, assetsLuau({ ids, scan, max }), 'check_assets');
  const rows = Array.isArray(report.results) ? report.results : [];
  const broken: any[] = [];
  const risky: any[] = [];
  const ok: string[] = [];
  for (const row of rows) {
    const { verdict, why } = assetVerdict(row);
    const label = `${row.kind ?? '?'} ${row.id}${row.name ? ` "${row.name}"` : ''}`;
    if (verdict === 'ok') ok.push(row.kind === 'Audio' && row.seconds ? `${label} (${row.seconds}s)` : label);
    else (verdict === 'broken' ? broken : risky).push({ asset: label, why, usedIn: row.uses });
  }
  return text({
    verdict: broken.length ? 'FIX' : risky.length ? 'CHECK' : 'OK',
    checked: rows.length,
    broken,
    risky,
    ok: ok.length <= 12 ? ok : `${ok.length} assets load fine`,
    owner: report.owner?.id ? `${report.owner.type} ${report.owner.id}` : 'unpublished place (animations are checked against your Studio account)',
    next: broken.length || risky.length
      ? 'Replace broken ids: search_assets {assetType: "Audio", query: "..."} (or Animation), then check_assets {ids: [...]} before using one. Use Roblox-made or your own animations.'
      : 'All assets load.',
  });
}

// --- optimize_game ----------------------------------------------------------------------------

const OPTIMIZE_LUAU = `
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local req = HttpService:JSONDecode(__REQ__)
local apply = {}
for _, name in req.apply or {} do
	apply[name] = true
end
local all = apply.all == true

local stats = {
	parts = 0, meshParts = 0, unions = 0, unanchored = 0, shadowCasters = 0, smallShadowCasters = 0,
	lights = 0, shadowLights = 0, particles = 0, particleRate = 0, beams = 0, trails = 0,
	textures = 0, surfaceGuis = 0, billboards = 0, sounds = 0, humanoids = 0,
	scripts = 0, localScripts = 0, modules = 0,
}
local biggestModels = {}
local perFrame = {}
local longScripts = {}
local deprecated = {}

local function isDecor(part)
	local s = part.Size
	return s.X * s.Y * s.Z < 8 or part.Transparency > 0.6 or part:FindFirstAncestor("Decor") ~= nil
end

local fixed = { shadows = 0, lights = 0, particles = 0 }
local recording = nil
if next(apply) then
	local ok, id = pcall(function()
		return ChangeHistoryService:TryBeginRecording("GameKit optimize_game")
	end)
	recording = if ok then id else nil
end

for _, inst in workspace:GetDescendants() do
	if inst:IsA("BasePart") and not inst:IsA("Terrain") then
		stats.parts += 1
		if inst:IsA("MeshPart") then stats.meshParts += 1 end
		if inst:IsA("UnionOperation") then stats.unions += 1 end
		if not inst.Anchored then stats.unanchored += 1 end
		if inst.CastShadow then
			stats.shadowCasters += 1
			if isDecor(inst) then
				stats.smallShadowCasters += 1
				if apply.shadows or all then
					inst.CastShadow = false
					fixed.shadows += 1
				end
			end
		end
	elseif inst:IsA("Light") then
		stats.lights += 1
		if inst.Shadows then
			stats.shadowLights += 1
			if (apply.lights or all) and not inst:IsA("SurfaceLight") then
				inst.Shadows = false
				fixed.lights += 1
			end
		end
	elseif inst:IsA("ParticleEmitter") then
		stats.particles += 1
		stats.particleRate += inst.Rate
		if (apply.particles or all) and inst.Rate > 40 then
			inst.Rate = 40
			fixed.particles += 1
		end
	elseif inst:IsA("Beam") then stats.beams += 1
	elseif inst:IsA("Trail") then stats.trails += 1
	elseif inst:IsA("Texture") or inst:IsA("Decal") then stats.textures += 1
	elseif inst:IsA("SurfaceGui") then stats.surfaceGuis += 1
	elseif inst:IsA("BillboardGui") then stats.billboards += 1
	elseif inst:IsA("Sound") then stats.sounds += 1
	elseif inst:IsA("Humanoid") then stats.humanoids += 1
	end
end

for _, model in workspace:GetChildren() do
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then count += 1 end
	end
	if count > 0 then
		table.insert(biggestModels, { name = model:GetFullName(), parts = count })
	end
end
table.sort(biggestModels, function(a, b) return a.parts > b.parts end)
while #biggestModels > 5 do table.remove(biggestModels) end

local roots = { game:GetService("ServerScriptService"), game:GetService("StarterPlayer"), game:GetService("StarterGui"), game:GetService("ReplicatedStorage"), workspace, game:GetService("StarterPack") }
for _, root in roots do
	for _, inst in root:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			if inst:IsA("ModuleScript") then stats.modules += 1
			elseif inst:IsA("LocalScript") or (inst:IsA("Script") and inst.RunContext == Enum.RunContext.Client) then stats.localScripts += 1
			else stats.scripts += 1 end
			local ok, source = pcall(function() return (inst :: any).Source end)
			if ok and type(source) == "string" and not string.find(inst:GetFullName(), "GameKitBackups", 1, true) then
				local path = inst:GetFullName()
				local _, lines = string.gsub(source, "\\n", "")
				if lines > 700 and #longScripts < 6 then
					table.insert(longScripts, { script = path, lines = lines })
				end
				local frameHooks = 0
				for _ in string.gmatch(source, "RenderStepped") do frameHooks += 1 end
				for _ in string.gmatch(source, "Heartbeat:Connect") do frameHooks += 1 end
				for _ in string.gmatch(source, "Stepped:Connect") do frameHooks += 1 end
				local heavy = string.find(source, "GetDescendants%(") ~= nil or string.find(source, "FindPartsInRegion3") ~= nil
				if frameHooks > 0 and heavy and #perFrame < 8 then
					table.insert(perFrame, path)
				end
				if (string.find(source, "[^%w_%.:]wait%(") or string.find(source, "[^%w_%.:]spawn%(") or string.find(source, "[^%w_%.:]delay%(")) and #deprecated < 8 then
					table.insert(deprecated, path)
				end
			end
		end
	end
end

local lighting = {
	technology = Lighting.Technology.Name,
	globalShadows = Lighting.GlobalShadows,
}
local streaming = workspace.StreamingEnabled
if (apply.technology or all) and Lighting.Technology == Enum.Technology.Future then
	Lighting.Technology = Enum.Technology.ShadowMap
	fixed.technology = true
end
if (apply.streaming or all) and not streaming then
	workspace.StreamingEnabled = true
	fixed.streaming = true
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

return HttpService:JSONEncode({
	stats = stats, lighting = lighting, streaming = streaming, biggestModels = biggestModels,
	perFrame = perFrame, longScripts = longScripts, deprecated = deprecated, fixed = fixed,
	enemiesTagged = #CollectionService:GetTagged("Enemy"),
})
`;

export function optimizeLuau(apply: string[]): string {
  return OPTIMIZE_LUAU.replace('__REQ__', () => luauJson({ apply }));
}

export interface OptimizeReport {
  stats: Record<string, number>;
  lighting: { technology: string; globalShadows: boolean };
  streaming: boolean;
  biggestModels?: Array<{ name: string; parts: number }>;
  perFrame?: string[];
  longScripts?: Array<{ script: string; lines: number }>;
  deprecated?: string[];
  fixed?: Record<string, number | boolean>;
}

type Finding = { level: 'red' | 'orange'; topic: string; problem: string; fix: string; apply?: string };

/** Budgets for entry-level phones (2-3 GB RAM): the majority of Roblox players. */
export function optimizeFindings(r: OptimizeReport): Finding[] {
  const s = r.stats ?? {};
  const out: Finding[] = [];
  const n = (key: string) => Number(s[key] ?? 0);
  if (n('parts') > 25000) out.push({ level: 'red', topic: 'parts', problem: `${n('parts')} parts: too many for low-end phones.`, fix: 'Remove hidden/duplicate parts, merge decoration into meshes (Blender), or split the map into places.', apply: r.streaming ? undefined : 'streaming' });
  else if (n('parts') > 10000) out.push({ level: 'orange', topic: 'parts', problem: `${n('parts')} parts: heavy for low-end phones.`, fix: 'Turn on StreamingEnabled and simplify decoration.', apply: r.streaming ? undefined : 'streaming' });
  if (!r.streaming && n('parts') > 4000) out.push({ level: 'orange', topic: 'streaming', problem: 'StreamingEnabled is off: phones load the whole map.', fix: 'Turn it on (client scripts must WaitForChild parts that may not be loaded yet).', apply: 'streaming' });
  if (n('unanchored') > 400) out.push({ level: n('unanchored') > 1500 ? 'red' : 'orange', topic: 'physics', problem: `${n('unanchored')} unanchored parts simulate physics.`, fix: 'Anchor everything that should not move (decor, buildings).' });
  if (n('smallShadowCasters') > 300) out.push({ level: 'orange', topic: 'shadows', problem: `${n('smallShadowCasters')} small or decorative parts cast shadows.`, fix: 'Disable CastShadow on small/decor parts (no visible change).', apply: 'shadows' });
  if (n('shadowLights') > 8) out.push({ level: n('shadowLights') > 25 ? 'red' : 'orange', topic: 'lights', problem: `${n('shadowLights')} lights cast shadows.`, fix: 'Keep light shadows off except for 1-2 key lights.', apply: 'lights' });
  if (n('particles') > 60 || n('particleRate') > 1500) out.push({ level: 'orange', topic: 'particles', problem: `${n('particles')} particle emitters, ${Math.round(n('particleRate'))} particles/s in total.`, fix: 'Cap emitter Rate at 40 and remove emitters nobody sees.', apply: 'particles' });
  if (r.lighting?.technology === 'Future') out.push({ level: 'orange', topic: 'technology', problem: 'Lighting.Technology is Future (the most expensive).', fix: 'ShadowMap looks close and runs much better on phones.', apply: 'technology' });
  if (n('humanoids') > 60) out.push({ level: 'orange', topic: 'npcs', problem: `${n('humanoids')} Humanoids in the workspace.`, fix: 'Lower Enemies MaxTotal / MaxAlive, or use simple models without Humanoid for crowds.' });
  if (n('surfaceGuis') + n('billboards') > 150) out.push({ level: 'orange', topic: 'gui', problem: `${n('surfaceGuis') + n('billboards')} SurfaceGuis/BillboardGuis in the world.`, fix: 'Set MaxDistance on billboards and remove unused signs.' });
  if (r.perFrame?.length) out.push({ level: 'orange', topic: 'scripts', problem: `Scripts doing heavy searches every frame: ${r.perFrame.join(', ')}.`, fix: 'Do not call GetDescendants/region searches in RenderStepped/Heartbeat: cache the list (CollectionService tags) or run it every 0.2 s.' });
  if (r.longScripts?.length) out.push({ level: 'orange', topic: 'scripts', problem: `Very long scripts: ${r.longScripts.map((l) => `${l.script} (${l.lines} lines)`).join(', ')}.`, fix: 'Split them into ModuleScripts: easier to fix and to read with read_script.' });
  if (r.deprecated?.length) out.push({ level: 'orange', topic: 'scripts', problem: `Deprecated wait()/spawn()/delay() in: ${r.deprecated.join(', ')}.`, fix: 'Use task.wait / task.spawn / task.delay (lint_luau fixes it).' });
  return out;
}

export async function optimizeGame(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  const apply = Array.isArray(args.apply) ? args.apply.map(String).filter((a: string) => ['shadows', 'lights', 'particles', 'streaming', 'technology', 'all'].includes(a)) : [];
  const report = await runLuauJson<OptimizeReport>(host, optimizeLuau(apply), 'optimize_game');
  const findings = optimizeFindings(report);
  const red = findings.filter((f) => f.level === 'red').length;
  const s = report.stats ?? {};
  const fixed = Object.entries(report.fixed ?? {}).filter(([, v]) => v === true || (typeof v === 'number' && v > 0)).map(([k, v]) => (v === true ? k : `${k}: ${v}`));
  const applicable = [...new Set(findings.map((f) => f.apply).filter(Boolean))] as string[];
  return text({
    phone: red ? 'RED: will lag or crash on low-end phones' : findings.length ? 'ORANGE: playable, can be lighter' : 'GREEN: light enough for low-end phones',
    numbers: {
      parts: s.parts, unanchored: s.unanchored, shadowLights: s.shadowLights, particles: s.particles, humanoids: s.humanoids,
      scripts: `${s.scripts} server, ${s.localScripts} client, ${s.modules} modules`, streaming: report.streaming, technology: report.lighting?.technology,
    },
    biggest: report.biggestModels,
    findings: findings.map(({ level, problem, fix, apply: a }) => ({ level, problem, fix, apply: a })),
    fixed: fixed.length ? fixed : undefined,
    next: fixed.length
      ? 'Fixes applied (one Ctrl+Z in Studio undoes them). Run test_game to check everything still works.'
      : applicable.length
        ? `Safe fixes: optimize_game {apply: ${JSON.stringify(applicable)}}. Then test_game {device: "phone"}.`
        : 'Nothing to fix automatically. Check the phone view: test_game {device: "phone"}.',
  });
}
