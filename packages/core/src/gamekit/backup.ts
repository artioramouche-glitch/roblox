/**
 * backup_game: snapshots of the place stored inside the place
 * (ServerStorage/GameKitBackups), restorable in one call. Taken automatically before
 * create_game rebuilds a game, so a weak model can always go back.
 *
 * Backups are made inert: scripts are disabled and CollectionService tags are moved to an
 * attribute, so GameKit systems never pick up the copies (they look up tagged parts).
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { runLuauJson } from './installer.js';
import { luauJson, text, type ToolResult } from './result.js';

export const BACKUP_TOOLS: ToolDef[] = [
  {
    name: 'backup_game',
    category: 'write',
    tier: 'starter',
    description: 'Save / restore a full snapshot of the game (world, scripts, UI, lighting, terrain) inside the place. Save before a risky change; restore if it went wrong (restore itself can be undone with Ctrl+Z). Actions: save (label), list, restore (id), delete (id). create_game saves one automatically.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['save', 'list', 'restore', 'delete'] },
        label: { type: 'string', description: 'save: what this snapshot is, e.g. "before new shop"' },
        id: { type: 'string', description: 'restore/delete: backup id from list (default for restore: the newest)' },
        keep: { type: 'number', description: 'save: how many backups to keep (default 5, oldest deleted)' },
        terrain: { type: 'boolean', description: 'save: include terrain (default true)' },
      },
      required: ['action'],
    },
  },
];

const BACKUP_LUAU = `
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local req = HttpService:JSONDecode(__REQ__)

local TARGETS = {
	{ key = "Workspace", path = { "Workspace" } },
	{ key = "ReplicatedStorage", path = { "ReplicatedStorage" } },
	{ key = "ReplicatedFirst", path = { "ReplicatedFirst" } },
	{ key = "ServerScriptService", path = { "ServerScriptService" } },
	{ key = "ServerStorage", path = { "ServerStorage" } },
	{ key = "StarterGui", path = { "StarterGui" } },
	{ key = "StarterPack", path = { "StarterPack" } },
	{ key = "StarterPlayer", path = { "StarterPlayer" } },
	{ key = "StarterPlayerScripts", path = { "StarterPlayer", "StarterPlayerScripts" } },
	{ key = "StarterCharacterScripts", path = { "StarterPlayer", "StarterCharacterScripts" } },
	{ key = "Lighting", path = { "Lighting" } },
	{ key = "SoundService", path = { "SoundService" } },
	{ key = "Teams", path = { "Teams" } },
}
local SKIP = { Terrain = true, Camera = true, GameKitBackups = true, GameKitTeam = true, StarterPlayerScripts = true, StarterCharacterScripts = true }
local LIGHTING_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogEnd", "FogStart", "FogColor", "GeographicLatitude", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows", "ColorShift_Top", "ColorShift_Bottom", "ShadowSoftness" }

local root = ServerStorage:FindFirstChild("GameKitBackups")
if not root then
	root = Instance.new("Folder")
	root.Name = "GameKitBackups"
	root.Parent = ServerStorage
end

local function resolve(path)
	local node = game:GetService(path[1])
	for i = 2, #path do
		node = node and node:FindFirstChild(path[i])
	end
	return node
end

local function each(instance, fn)
	fn(instance)
	for _, d in instance:GetDescendants() do fn(d) end
end

local function neutralize(instance)
	each(instance, function(d)
		local tags = d:GetTags()
		if #tags > 0 then
			d:SetAttribute("GKBackupTags", table.concat(tags, "\\n"))
			for _, tag in tags do d:RemoveTag(tag) end
		end
		if d:IsA("BaseScript") then
			local ok, enabled = pcall(function() return (d :: any).Enabled end)
			if not ok then
				ok, enabled = pcall(function() return not (d :: any).Disabled end)
			end
			if ok and enabled then
				d:SetAttribute("GKBackupEnabled", true)
				if not pcall(function() (d :: any).Enabled = false end) then
					pcall(function() (d :: any).Disabled = true end)
				end
			end
		end
	end)
end

local function revive(instance)
	each(instance, function(d)
		local tags = d:GetAttribute("GKBackupTags")
		if type(tags) == "string" then
			for tag in string.gmatch(tags, "[^\\n]+") do d:AddTag(tag) end
			d:SetAttribute("GKBackupTags", nil)
		end
		if d:GetAttribute("GKBackupEnabled") then
			d:SetAttribute("GKBackupEnabled", nil)
			if d:IsA("BaseScript") and not pcall(function() (d :: any).Enabled = true end) then
				pcall(function() (d :: any).Disabled = false end)
			end
		end
	end)
end

local function sorted()
	local list = root:GetChildren()
	-- Newest first. Seq breaks ties between backups taken in the same second.
	table.sort(list, function(a, b)
		local ta, tb = a:GetAttribute("Time") or 0, b:GetAttribute("Time") or 0
		if ta ~= tb then return ta > tb end
		return (a:GetAttribute("Seq") or 0) > (b:GetAttribute("Seq") or 0)
	end)
	return list
end

local function info(backup)
	local count = 0
	for _ in backup:GetDescendants() do count += 1 end
	return { id = backup.Name, label = backup:GetAttribute("Label"), time = backup:GetAttribute("Time"),
		date = os.date("!%Y-%m-%d %H:%M UTC", backup:GetAttribute("Time") or 0), instances = count, terrain = backup:FindFirstChild("__Terrain") ~= nil }
end

local action = req.action
if action == "list" then
	local out = {}
	for _, b in sorted() do table.insert(out, info(b)) end
	return HttpService:JSONEncode({ ok = true, backups = out })
elseif action == "save" then
	local id = "B" .. os.time()
	local n = 1
	while root:FindFirstChild(id) do n += 1; id = "B" .. os.time() .. "_" .. n end
	local backup = Instance.new("Folder")
	backup.Name = id
	backup:SetAttribute("Label", tostring(req.label or "backup"))
	backup:SetAttribute("Time", os.time())
	local seq = (root:GetAttribute("Seq") or 0) + 1
	root:SetAttribute("Seq", seq)
	backup:SetAttribute("Seq", seq)
	local skipped = {}
	for _, target in TARGETS do
		local container = resolve(target.path)
		if container then
			local holder = Instance.new("Folder")
			holder.Name = target.key
			for _, child in container:GetChildren() do
				if not SKIP[child.Name] and not child:IsA("Player") then
					if child.Archivable then
						local ok, copy = pcall(function() return child:Clone() end)
						if ok and copy then
							neutralize(copy)
							copy.Parent = holder
						else
							table.insert(skipped, child:GetFullName())
						end
					end
				end
			end
			holder.Parent = backup
		end
	end
	local lighting = game:GetService("Lighting")
	local props = backup:FindFirstChild("Lighting")
	for _, name in LIGHTING_PROPS do
		pcall(function() props:SetAttribute("Prop_" .. name, (lighting :: any)[name]) end)
	end
	if req.terrain ~= false then
		pcall(function()
			local terrain = workspace.Terrain
			if terrain:CountCells() > 0 then
				local region = terrain:CopyRegion(terrain.MaxExtents)
				region.Name = "__Terrain"
				region.Parent = backup
			end
		end)
	end
	backup.Parent = root
	local keep = math.max(1, req.keep or 5)
	local list = sorted()
	for i = keep + 1, #list do list[i]:Destroy() end
	return HttpService:JSONEncode({ ok = true, backup = info(backup), skipped = skipped })
elseif action == "delete" then
	local backup = req.id and root:FindFirstChild(req.id)
	if not backup then return HttpService:JSONEncode({ ok = false, error = "No backup " .. tostring(req.id) }) end
	backup:Destroy()
	return HttpService:JSONEncode({ ok = true })
elseif action == "restore" then
	local backup = if req.id then root:FindFirstChild(req.id) else sorted()[1]
	if not backup then return HttpService:JSONEncode({ ok = false, error = "No backup to restore" }) end
	local recording = ChangeHistoryService:TryBeginRecording("GameKit: restore " .. backup.Name)
	local ok, err = pcall(function()
		for _, target in TARGETS do
			local container = resolve(target.path)
			local holder = backup:FindFirstChild(target.key)
			if container and holder then
				for _, child in container:GetChildren() do
					if not SKIP[child.Name] and not child:IsA("Player") and child.Archivable then child:Destroy() end
				end
				for _, saved in holder:GetChildren() do
					local copy = saved:Clone()
					revive(copy)
					copy.Parent = container
				end
			end
		end
		local lighting = game:GetService("Lighting")
		local props = backup:FindFirstChild("Lighting")
		if props then
			for name, value in props:GetAttributes() do
				local prop = string.match(name, "^Prop_(.+)$")
				if prop then pcall(function() (lighting :: any)[prop] = value end) end
			end
		end
		local region = backup:FindFirstChild("__Terrain")
		if region then
			workspace.Terrain:Clear()
			workspace.Terrain:PasteRegion(region, region.ExtentsMin, true)
		end
	end)
	if recording then
		ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end
	if not ok then return HttpService:JSONEncode({ ok = false, error = tostring(err) }) end
	return HttpService:JSONEncode({ ok = true, restored = info(backup) })
end
return HttpService:JSONEncode({ ok = false, error = "Unknown action " .. tostring(action) })
`;

export function backupLuau(req: Record<string, unknown>): string {
  return BACKUP_LUAU.replace('__REQ__', () => luauJson(req));
}

export async function saveBackup(host: GameKitHost, label: string): Promise<any> {
  return runLuauJson(host, backupLuau({ action: 'save', label }), 'Backup');
}

/** True when the place has real content worth saving (not a fresh Baseplate). */
export async function placeHasContent(host: GameKitHost): Promise<boolean> {
  const reply = await host.runLuau(`
local n = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") and d.Name ~= "Baseplate" then n += 1 end
	if n > 3 then break end
end
for _, s in { game:GetService("ServerScriptService"), game:GetService("StarterGui"), game:GetService("ReplicatedStorage") } do
	if #s:GetChildren() > 0 then n += 10 end
end
return tostring(n)`);
  return reply?.success === true && Number(reply.returnValue) > 3;
}

export async function handleBackup(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  const action = String(args.action ?? 'list');
  const result = await runLuauJson<any>(host, backupLuau({
    action,
    label: args.label,
    id: args.id,
    keep: args.keep !== undefined ? Number(args.keep) : undefined,
    terrain: args.terrain,
  }), 'Backup');
  const next: Record<string, string> = {
    save: 'Do the risky change now. If it goes wrong: backup_game {"action": "restore", "id": "<id>"}.',
    restore: 'Restored. Run test_game. (Ctrl+Z in Studio undoes the restore.)',
    list: 'Restore one with backup_game {"action": "restore", "id": "..."}.',
  };
  return text({ ...result, next: result?.ok ? next[action] : undefined });
}
