/**
 * publish_checklist: everything to check before making the game public, verified where
 * Studio can tell (spawn, errors, monetization ids, test result...) and explained where
 * only a human can do it (icon, age questionnaire, API access...).
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { analyseAudit, collectAudit } from './doctor.js';
import { runLuauJson } from './installer.js';
import { errorMessage, text, type ToolResult } from './result.js';

export const PUBLISH_TOOLS: ToolDef[] = [
  {
    name: 'publish_checklist',
    category: 'read',
    tier: 'builder',
    description: 'Before publishing: checks what Studio can verify (published place, spawn, script errors, last test result, monetization ids, open team tasks, mobile-friendly UI, max players...) and lists the manual steps (icon, thumbnails, description, age questionnaire, API access, public visibility) with where to click.',
    inputSchema: { type: 'object', properties: {} },
  },
];

type Status = 'ok' | 'todo' | 'warn' | 'manual';

interface Check {
  item: string;
  status: Status;
  detail?: string;
  how?: string;
}

const FACTS_LUAU = `
local HttpService = game:GetService("HttpService")
local facts = { placeId = game.PlaceId, gameId = game.GameId, maxPlayers = game:GetService("Players").MaxPlayers }
local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
if ok and type(info) == "table" then
	facts.name = info.Name
	facts.description = info.Description
	facts.iconId = info.IconImageAssetId
end
local spawns = 0
for _, d in workspace:GetDescendants() do if d:IsA("SpawnLocation") then spawns += 1 end end
facts.spawns = spawns
local offsetGuis, guis = 0, 0
for _, gui in game:GetService("StarterGui"):GetDescendants() do
	if gui:IsA("GuiObject") and gui.Visible then
		guis += 1
		if gui.Size.X.Scale == 0 and gui.Size.X.Offset > 500 then offsetGuis += 1 end
	end
end
facts.guis, facts.wideOffsetGuis = guis, offsetGuis
local kit = game:GetService("ReplicatedStorage"):FindFirstChild("GameKit")
local config = kit and kit:FindFirstChild("Config")
local function read(name)
	local module = config and config:FindFirstChild(name)
	if not module then return nil end
	local copy = module:Clone()
	copy.Parent = module.Parent
	local okRequire, value = pcall(require, copy)
	copy:Destroy()
	return if okRequire then value else nil
end
local monetization = read("Monetization")
if monetization then
	local zero = 0
	for _, list in { monetization.Products or {}, monetization.GamePasses or {} } do
		for _, item in list do
			if type(item) == "table" and (tonumber(item.Id) or 0) == 0 then zero += 1 end
		end
	end
	facts.monetizationPlaceholders = zero
end
local team = game:GetService("ServerStorage"):FindFirstChild("GameKitTeam")
if team and team:FindFirstChild("Tasks") then
	local open = 0
	for _, t in team.Tasks:GetChildren() do if t:GetAttribute("Status") ~= "done" then open += 1 end end
	facts.openTasks = open
end
local backups = game:GetService("ServerStorage"):FindFirstChild("GameKitBackups")
facts.backups = if backups then #backups:GetChildren() else 0
facts.lighting = game:GetService("Lighting"):FindFirstChildWhichIsA("Sky") ~= nil or game:GetService("Lighting"):FindFirstChildWhichIsA("Atmosphere") ~= nil
return HttpService:JSONEncode(facts)
`;

export async function publishChecklist(host: GameKitHost, lastTest?: { verdict: string; at: number }): Promise<ToolResult> {
  const checks: Check[] = [];
  const facts = await runLuauJson<any>(host, FACTS_LUAU, 'Publish facts');
  checks.push(facts.placeId > 0
    ? { item: 'Place published to Roblox', status: 'ok', detail: `PlaceId ${facts.placeId}` }
    : { item: 'Place published to Roblox', status: 'todo', how: 'File > Publish to Roblox (Alt+P), create a new experience.' });
  checks.push(facts.spawns > 0
    ? { item: 'Spawn location', status: 'ok' }
    : { item: 'Spawn location', status: 'todo', how: 'build_world {"kind": "spawn"} or create_game.' });
  try {
    const { summary } = await analyseAudit(await collectAudit(host));
    checks.push(summary.errors
      ? { item: 'No script errors (check_game)', status: 'todo', detail: `${summary.errors} errors, ${summary.warnings} warnings`, how: 'Run check_game and fix the errors.' }
      : { item: 'No script errors (check_game)', status: 'ok', detail: `${summary.warnings ?? 0} warnings` });
  } catch (error) {
    checks.push({ item: 'No script errors (check_game)', status: 'warn', detail: errorMessage(error) });
  }
  if (!lastTest) checks.push({ item: 'Playtest passes (test_game)', status: 'todo', how: 'Run test_game until PASS.' });
  else checks.push({ item: 'Playtest passes (test_game)', status: lastTest.verdict === 'PASS' ? 'ok' : 'todo', detail: `last result ${lastTest.verdict}, ${Math.round((Date.now() - lastTest.at) / 60000)} min ago`, how: lastTest.verdict === 'PASS' ? undefined : 'Fix the reported errors and run test_game again.' });
  if (facts.monetizationPlaceholders > 0) checks.push({ item: 'Monetization ids', status: 'todo', detail: `${facts.monetizationPlaceholders} products/passes still have Id 0`, how: 'Create them in Creator Dashboard > your experience > Monetization, then put the ids in ReplicatedStorage/GameKit/Config/Monetization.' });
  if (facts.openTasks > 0) checks.push({ item: 'Team board', status: 'warn', detail: `${facts.openTasks} tasks not done`, how: 'team {"action": "list"}' });
  checks.push(facts.wideOffsetGuis > 0
    ? { item: 'UI fits phones', status: 'warn', detail: `${facts.wideOffsetGuis} UI elements are wider than 500 px in pixels (cut off on phones)`, how: 'Use scale sizes (build_ui size <= 1) and check with look_at_game / capture_device_matrix.' }
    : { item: 'UI fits phones', status: 'ok', detail: `${facts.guis} visible UI elements` });
  checks.push({ item: 'Mood lighting', status: facts.lighting ? 'ok' : 'warn', how: facts.lighting ? undefined : 'set_environment {"preset": ...} for a sky and atmosphere.' });
  checks.push({ item: 'Backup before publishing', status: facts.backups > 0 ? 'ok' : 'warn', how: facts.backups > 0 ? undefined : 'backup_game {"action": "save", "label": "release 1"}' });
  checks.push({ item: `Max players (${facts.maxPlayers})`, status: 'manual', how: 'Game Settings > Places > (your place) > Server Fill / Max players: 8-20 for most games, 1-4 for co-op horror.' });

  const manual: Check[] = [
    { item: 'Name and description', status: facts.description ? 'ok' : 'manual', detail: facts.name, how: 'Creator Dashboard > Configure > Basic settings. Say what you do in the first line, with 2-3 keywords (e.g. "Obby", "Tycoon").' },
    { item: 'Icon (512x512) and 3 thumbnails (1920x1080)', status: facts.iconId ? 'ok' : 'manual', how: 'Creator Dashboard > Places > Thumbnails / Icon. Take thumbnails with look_at_game; bright, readable, one clear subject.' },
    { item: 'Maturity & compliance questionnaire', status: 'manual', how: 'Creator Dashboard > Audience > Maturity & Compliance (required before the game can be public).' },
    { item: 'Enable Studio access to API services (DataStores)', status: 'manual', how: 'Game Settings > Security > Enable Studio Access to API Services (saves work in Studio tests).' },
    { item: 'Devices: Computer, Phone, Tablet, Console', status: 'manual', how: 'Creator Dashboard > Configure > Audience > Devices. Most players are on phones.' },
    { item: 'Automatic translation', status: 'manual', how: 'Creator Dashboard > Localization > turn on automatic text capture and translation (reaches players in their language).' },
    { item: 'Make it public', status: 'manual', how: 'Creator Dashboard > Configure > Audience/Privacy > Public. Then share the link and watch Analytics (retention D1, session length).' },
  ];
  const todo = checks.filter((c) => c.status === 'todo').length;
  return text({
    readyToPublish: todo === 0,
    summary: todo ? `${todo} things to fix before publishing.` : 'Studio checks pass. Finish the manual steps below and publish.',
    checks,
    manualSteps: manual,
  });
}
