/**
 * Team board: several AIs (Claude, Gemini, a local model...) build the same game at the
 * same time without stepping on each other. The board lives IN the place
 * (ServerStorage/GameKitTeam), so every MCP client connected to this Studio (proxy mode)
 * sees the same tasks and zones, and it is saved with the place.
 *
 *   tasks: plan -> claim -> done (with notes), one owner per task
 *   zones: named 3D boxes of the map; a zone owned by another agent cannot be overlapped
 *
 * Each action is one Luau call, and the plugin runs calls one after the other, so claims
 * are atomic: two agents can never own the same task or overlapping zones.
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { runLuauJson } from './installer.js';
import { luauJson, text, vec3, type ToolResult, type Vec3 } from './result.js';

export interface TeamTask {
  title: string;
  details?: string;
  role?: string;
  zone?: string;
}

export const ROLES = ['lead', 'builder', 'artist', 'scripter', 'ui', 'designer', 'qa'] as const;

/** A sensible split of a whole game between 2-6 AIs. */
export function defaultPlan(template?: string, goal?: string): TeamTask[] {
  const what = template ? `the ${template} template` : 'the template closest to the idea';
  return [
    { title: 'Core game', role: 'lead', details: `create_game with ${what}${goal ? ` for: ${goal}` : ''}, then test_game until PASS. Everyone else waits for this task to be done before building.` },
    { title: 'Main area polish', role: 'builder', zone: 'main', details: 'Claim the "main" zone, improve the playable area with build_world pieces and set_environment. Never move gameplay pieces other tasks own.' },
    { title: 'Scenery around the map', role: 'builder', zone: 'outskirts', details: 'Claim the "outskirts" zone, then populate_world with a theme matching the game (and props from Blender if available).' },
    { title: 'Signature 3D props', role: 'artist', details: 'Model 2-5 hero props in Blender (blender_python / blender_assets), send them with blender_to_roblox (through start_job), place them in your zone.' },
    { title: 'UI and shop', role: 'ui', details: 'build_ui for menus (shop, settings), check them with look_at_game devices.' },
    { title: 'Economy balance', role: 'designer', details: 'balance_economy on the current config, apply the suggested prices with add_system config.' },
    { title: 'QA pass', role: 'qa', details: 'Every ~10 minutes: check_game + test_game + look_at_game. Add a task (team add) for each bug found, with the script and line.' },
    { title: 'Publish checklist', role: 'lead', details: 'When all tasks are done: publish_checklist, fix what it lists, final test_game.' },
  ];
}

export const TEAM_TOOLS: ToolDef[] = [
  {
    name: 'team',
    category: 'write',
    tier: 'starter',
    description: 'Shared task board + map zones for several AIs on one Studio (roblox_guide team). Pass your unique agent name. Actions: plan, list, claim, done, release, block, note, add, claim_zone, release_zone, zones.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['plan', 'list', 'claim', 'done', 'release', 'block', 'note', 'add', 'claim_zone', 'release_zone', 'zones'] },
        agent: { type: 'string' },
        task: { type: 'string', description: 'e.g. "T3"' },
        role: { type: 'string', description: ROLES.join('|') },
        title: { type: 'string' },
        note: { type: 'string' },
        goal: { type: 'string', description: 'plan: the game idea' },
        tasks: { type: 'array', items: { type: 'object' }, description: 'plan: [{title, details, role, zone}]' },
        zone: { type: 'string' },
        center: { type: 'array', items: { type: 'number' } },
        size: { type: 'array', items: { type: 'number' }, description: '[x,y,z]' },
      },
      required: ['action'],
    },
  },
];

const TEAM_LUAU = `
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local req = HttpService:JSONDecode(__REQ__)

local root = ServerStorage:FindFirstChild("GameKitTeam")
if not root then
	root = Instance.new("Folder")
	root.Name = "GameKitTeam"
	root.Parent = ServerStorage
end
local function folder(name)
	local f = root:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
	end
	return f
end
local tasksFolder, zonesFolder = folder("Tasks"), folder("Zones")
local now = os.time()

local function taskOf(item)
	return {
		id = item.Name, title = item:GetAttribute("Title"), details = item:GetAttribute("Details"),
		status = item:GetAttribute("Status"), owner = item:GetAttribute("Owner"), role = item:GetAttribute("Role"),
		zone = item:GetAttribute("Zone"), notes = item:GetAttribute("Notes"), updated = item:GetAttribute("Updated"),
	}
end
local function sortedTasks()
	local list = tasksFolder:GetChildren()
	table.sort(list, function(a, b)
		return (tonumber(string.sub(a.Name, 2)) or 0) < (tonumber(string.sub(b.Name, 2)) or 0)
	end)
	return list
end
local function zoneOf(item)
	local c, s = item:GetAttribute("Center"), item:GetAttribute("Size")
	return { name = item.Name, owner = item:GetAttribute("Owner"), purpose = item:GetAttribute("Purpose"),
		center = { c.X, c.Y, c.Z }, size = { s.X, s.Y, s.Z } }
end
local function addTask(t)
	local id = (tasksFolder:GetAttribute("NextId") or 1)
	tasksFolder:SetAttribute("NextId", id + 1)
	local item = Instance.new("Configuration")
	item.Name = "T" .. id
	item:SetAttribute("Title", tostring(t.title or ("Task " .. id)))
	item:SetAttribute("Details", tostring(t.details or ""))
	item:SetAttribute("Role", tostring(t.role or ""))
	item:SetAttribute("Zone", tostring(t.zone or ""))
	item:SetAttribute("Status", "todo")
	item:SetAttribute("Owner", "")
	item:SetAttribute("Notes", "")
	item:SetAttribute("Updated", now)
	item.Parent = tasksFolder
	return item
end
local function appendNote(item, text)
	if text and text ~= "" then
		local notes = item:GetAttribute("Notes") or ""
		notes = notes .. (if notes ~= "" then "\\n" else "") .. "[" .. tostring(req.agent or "?") .. "] " .. tostring(text)
		if #notes > 3000 then notes = string.sub(notes, -3000) end
		item:SetAttribute("Notes", notes)
	end
end
local function state(extra)
	local out = { tasks = {}, zones = {} }
	for _, item in sortedTasks() do table.insert(out.tasks, taskOf(item)) end
	for _, item in zonesFolder:GetChildren() do table.insert(out.zones, zoneOf(item)) end
	for k, v in extra or {} do out[k] = v end
	return HttpService:JSONEncode(out)
end
local function fail(message, extra)
	local out = { ok = false, error = message }
	for k, v in extra or {} do out[k] = v end
	return HttpService:JSONEncode(out)
end

local action = req.action
if action == "plan" then
	if req.replace then tasksFolder:ClearAllChildren(); tasksFolder:SetAttribute("NextId", 1) end
	for _, t in req.tasks do addTask(t) end
	return state({ ok = true })
elseif action == "add" then
	local item = addTask(req)
	return state({ ok = true, added = item.Name })
elseif action == "list" or action == "zones" then
	return state({ ok = true })
elseif action == "claim" then
	local target = nil
	if req.task then
		target = tasksFolder:FindFirstChild(req.task)
		if not target then return fail("No task " .. req.task) end
		local owner = target:GetAttribute("Owner")
		if target:GetAttribute("Status") == "done" then return fail(req.task .. " is already done") end
		if owner ~= "" and owner ~= req.agent then return fail(req.task .. " is owned by " .. owner, { owner = owner }) end
	else
		for pass = 1, 2 do
			for _, item in sortedTasks() do
				if item:GetAttribute("Status") == "todo" and (pass == 2 or not req.role or item:GetAttribute("Role") == req.role) then
					target = item
					break
				end
			end
			if target then break end
		end
		if not target then return state({ ok = false, error = "No free task left. Add one (action add) or help QA." }) end
	end
	target:SetAttribute("Status", "doing")
	target:SetAttribute("Owner", req.agent)
	target:SetAttribute("Updated", now)
	return state({ ok = true, claimed = taskOf(target) })
elseif action == "done" or action == "release" or action == "block" or action == "note" then
	local item = req.task and tasksFolder:FindFirstChild(req.task)
	if not item then return fail("No task " .. tostring(req.task)) end
	local owner = item:GetAttribute("Owner")
	if action ~= "note" and owner ~= "" and owner ~= req.agent and not req.force then
		return fail(req.task .. " is owned by " .. owner .. " (pass force only if that agent is gone)", { owner = owner })
	end
	appendNote(item, req.note)
	if action == "done" then item:SetAttribute("Status", "done")
	elseif action == "release" then item:SetAttribute("Status", "todo"); item:SetAttribute("Owner", "")
	elseif action == "block" then item:SetAttribute("Status", "blocked") end
	item:SetAttribute("Updated", now)
	return state({ ok = true, task = taskOf(item) })
elseif action == "claim_zone" then
	local c = Vector3.new(req.center[1], req.center[2], req.center[3])
	local s = Vector3.new(req.size[1], req.size[2], req.size[3])
	local conflicts = {}
	for _, item in zonesFolder:GetChildren() do
		if item.Name ~= req.zone and item:GetAttribute("Owner") ~= req.agent then
			local oc, os2 = item:GetAttribute("Center"), item:GetAttribute("Size")
			local d = (c - oc)
			if math.abs(d.X) * 2 < s.X + os2.X and math.abs(d.Y) * 2 < s.Y + os2.Y and math.abs(d.Z) * 2 < s.Z + os2.Z then
				table.insert(conflicts, zoneOf(item))
			end
		end
	end
	local existing = zonesFolder:FindFirstChild(req.zone)
	if existing and existing:GetAttribute("Owner") ~= req.agent and existing:GetAttribute("Owner") ~= "" and not req.force then
		return fail("Zone " .. req.zone .. " is owned by " .. existing:GetAttribute("Owner"), { owner = existing:GetAttribute("Owner") })
	end
	if #conflicts > 0 then return fail("This box overlaps zones of other agents", { conflicts = conflicts }) end
	local item = existing or Instance.new("Configuration")
	item.Name = req.zone
	item:SetAttribute("Owner", req.agent)
	item:SetAttribute("Center", c)
	item:SetAttribute("Size", s)
	item:SetAttribute("Purpose", tostring(req.purpose or ""))
	item.Parent = zonesFolder
	return state({ ok = true, zone = zoneOf(item) })
elseif action == "release_zone" then
	local item = zonesFolder:FindFirstChild(req.zone)
	if not item then return fail("No zone " .. tostring(req.zone)) end
	if item:GetAttribute("Owner") ~= req.agent and not req.force then
		return fail("Zone owned by " .. tostring(item:GetAttribute("Owner")))
	end
	item:Destroy()
	return state({ ok = true })
end
return fail("Unknown action " .. tostring(action))
`;

function teamLuau(req: Record<string, unknown>): string {
  return TEAM_LUAU.replace('__REQ__', () => luauJson(req));
}

export interface ZoneInfo {
  name: string;
  owner: string;
  purpose?: string;
  center: Vec3;
  size: Vec3;
}

export async function findZone(host: GameKitHost, name: string): Promise<ZoneInfo | undefined> {
  const state = await runLuauJson<any>(host, teamLuau({ action: 'zones' }), 'Team board');
  const zones = Array.isArray(state?.zones) ? (state.zones as ZoneInfo[]) : [];
  return zones.find((z) => z.name === name);
}

const NEEDS_AGENT = new Set(['claim', 'done', 'release', 'block', 'claim_zone', 'release_zone']);

export async function handleTeam(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  const action = String(args.action ?? 'list');
  const agent = args.agent ? String(args.agent).trim().slice(0, 40) : undefined;
  if (NEEDS_AGENT.has(action) && !agent) throw new Error(`team ${action} needs "agent" (your short unique name, e.g. "claude-1")`);
  const req: Record<string, unknown> = { action, agent, task: args.task, role: args.role, note: args.note, force: !!args.force };
  if (action === 'plan') {
    const tasks = Array.isArray(args.tasks) && args.tasks.length ? (args.tasks as TeamTask[]) : defaultPlan(args.template, args.goal);
    req.tasks = tasks.map((t) => ({ title: t.title, details: t.details, role: t.role, zone: t.zone }));
    req.replace = !!args.replace;
  } else if (action === 'add') {
    if (!args.title) throw new Error('team add needs "title"');
    Object.assign(req, { title: args.title, details: args.details, role: args.role, zone: args.zone });
  } else if (action === 'claim_zone' || action === 'release_zone') {
    if (!args.zone) throw new Error(`team ${action} needs "zone" (a name, e.g. "north-forest")`);
    req.zone = String(args.zone).replace(/[^\w -]/g, '').slice(0, 50);
    req.center = vec3(args.center, [0, 0, 0]);
    req.size = vec3(args.size, [120, 80, 120]).map((n) => Math.max(4, Math.abs(n)));
    req.purpose = args.purpose;
  }
  const state = await runLuauJson<any>(host, teamLuau(req), 'Team board');
  const tasks = Array.isArray(state?.tasks) ? state.tasks : [];
  const zones = Array.isArray(state?.zones) ? state.zones : [];
  const counts = tasks.reduce((acc: Record<string, number>, t: any) => ({ ...acc, [t.status]: (acc[t.status] ?? 0) + 1 }), {});
  const mine = agent ? tasks.filter((t: any) => t.owner === agent && t.status !== 'done') : undefined;
  let next: string | undefined;
  if (state?.ok === false) next = state.conflicts ? 'Choose another center/size (see conflicts) or ask the owner to release it.' : undefined;
  else if (action === 'plan') next = 'Each AI: team {action:"claim", agent, role} to take a task, then team {action:"done", agent, task, note} when finished.';
  else if (action === 'claim' && state.claimed) next = state.claimed.zone ? `First reserve your area: team {action:"claim_zone", agent, zone:"${state.claimed.zone}", center, size}. Then do the task and mark it done.` : 'Do the task, then team {action:"done", agent, task, note}.';
  else if (action === 'done') next = 'Claim the next task: team {action:"claim", agent}.';
  else if (action === 'claim_zone') next = 'Build only inside your zone (build_world / populate_world {zone}).';
  // Only what this action needs: the whole board costs tokens on every call.
  const brief = (t: any) => ({ id: t.id, title: t.title, status: t.status, owner: t.owner || undefined, role: t.role || undefined, zone: t.zone || undefined });
  const showTasks = action === 'list' || action === 'plan';
  return text({
    ...(state?.ok === false ? { ok: false, error: state.error, owner: state.owner, conflicts: state.conflicts } : { ok: true }),
    claimed: state?.claimed,
    task: state?.task ? brief(state.task) : undefined,
    zone: state?.zone,
    counts,
    yourTasks: mine?.map(brief),
    tasks: showTasks ? tasks.map((t: any) => (args.full ? { ...t, notes: t.notes ? String(t.notes).slice(-600) : undefined } : brief(t))) : undefined,
    zones: action === 'zones' || action === 'list' || action === 'claim_zone' || state?.conflicts ? zones : undefined,
    next,
  });
}
