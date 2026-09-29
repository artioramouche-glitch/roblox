/**
 * Code recipes: ready-made, verified scripts for the things games need all the time and that
 * small models get wrong (touch rewards, prompts, doors, spawners, UI button -> server,
 * NPC dialog, badges, chat commands...). The model picks a recipe and fills a few params;
 * the generated code is readable, commented, built on the tested GameKit modules, and passes
 * the compiler, the linter, the Roblox API check and luau-lsp (scripts/verify-gamekit-luau.mjs).
 * Settings live in a SETTINGS table at the top, so later tweaks are one edit_script away.
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { systemPlacements } from './catalog.js';
import { API_ENUMS } from './generated/roblox-api.js';
import { install, splitPath, type Placement } from './installer.js';
import { prepareLuau } from './code.js';
import { toLuau } from './luau-table.js';
import { text, vec3, type ToolResult } from './result.js';

export interface RecipeFile {
  side: 'server' | 'client';
  source: string;
}

export interface RecipeDef {
  id: string;
  title: string;
  summary: string;
  /** param -> short description; "*" = required. */
  params: Record<string, string>;
  example: Record<string, unknown>;
  /** Other params exercising other branches (verified in CI like the example). */
  variants?: Array<Record<string, unknown>>;
  build: (p: Params) => { files: RecipeFile[]; notes?: string[] };
}

type Params = Record<string, any>;

// --- Small helpers --------------------------------------------------------------------------

const str = (v: unknown, d = '') => (v === undefined || v === null ? d : String(v));
const num = (v: unknown, d: number) => (Number.isFinite(Number(v)) && v !== '' && v !== null && v !== undefined ? Number(v) : d);
const bool = (v: unknown, d = false) => (v === undefined || v === null ? d : v === true || v === 'true');
const lstr = (s: string) => toLuau(s);

function need(p: Params, key: string, what: string): string {
  const v = str(p[key]).trim();
  if (!v) throw new Error(`Recipe needs "${key}": ${what}`);
  return v;
}

/** A target is "tag:Name" (every tagged instance, now and later) or a path "Workspace/Map/Door". */
function targetCode(target: string, fn = 'setup'): string {
  if (/^tag:/i.test(target)) return `Util.onTag(${lstr(target.slice(4).trim())}, ${fn})`;
  const segments = splitPath(target);
  if (segments.length < 2) throw new Error(`"${target}" is not a path like "Workspace/Map/Door" (or use "tag:Name")`);
  return `${fn}(waitForPath({ ${segments.map(lstr).join(', ')} }))`;
}

/** waitForPath is only emitted when a path (not a tag) is used, so no unused function is left. */
const pathHelper = (...targets: string[]) => (targets.some((t) => t && !/^tag:/i.test(t)) ? WAIT_FOR_PATH : '');

function pathList(target: string): string {
  return `{ ${splitPath(target).map(lstr).join(', ')} }`;
}

const WAIT_FOR_PATH = `
-- Finds an instance from its path ({ "Workspace", "Map", "Door" }), waiting for it to load.
local function waitForPath(path: { string }): Instance
	local node: Instance = game:GetService(path[1])
	for i = 2, #path do
		node = node:WaitForChild(path[i])
	end
	return node
end`;

const EACH_PART = `
-- Runs fn for a part, or for every part inside a model.
local function eachPart(instance: Instance, fn: (BasePart) -> ())
	if instance:IsA("BasePart") then
		fn(instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			fn(descendant)
		end
	end
end`;

const MAIN_PART = `
-- The part to attach things to: the part itself, or the model's PrimaryPart / first part.
local function mainPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end`;

interface HeaderNeeds {
  services?: string[];
  util?: boolean;
  net?: boolean;
  playerData?: boolean;
  uikit?: boolean;
}

function header(title: string, summary: string, needs: HeaderNeeds): string {
  const services = new Set(needs.services ?? []);
  if (needs.util || needs.net || needs.uikit) services.add('ReplicatedStorage');
  if (needs.playerData) services.add('ServerScriptService');
  const lines = [
    `-- ${title} (code_recipe). ${summary}`,
    '-- Change the SETTINGS below; the rest works as is.',
    '',
    ...[...services].sort().map((s) => `local ${s} = game:GetService(${lstr(s)})`),
  ];
  if (needs.util || needs.net || needs.uikit) {
    lines.push('', 'local kit = ReplicatedStorage:WaitForChild("GameKit")');
    if (needs.util) lines.push('local Util = require(kit:WaitForChild("Util"))');
    if (needs.net) lines.push('local Net = require(kit:WaitForChild("Net"))');
    if (needs.uikit) lines.push('local UIKit = require(kit:WaitForChild("UIKit"))');
  }
  if (needs.playerData) lines.push('local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))');
  return lines.join('\n');
}

function settings(values: Record<string, unknown>, docs: Record<string, string> = {}): string {
  const lines = ['', 'local SETTINGS = {'];
  for (const [k, v] of Object.entries(values)) {
    lines.push(`\t${k} = ${toLuau(v, 1)},${docs[k] ? ` -- ${docs[k]}` : ''}`);
  }
  lines.push('}');
  return lines.join('\n');
}

const v3 = (v: [number, number, number]) => ({ $v3: v });

// --- Recipes ------------------------------------------------------------------------------------

export const RECIPES: RecipeDef[] = [
  {
    id: 'touch_reward',
    title: 'Touch reward',
    summary: 'Touching a part gives a stat (coins, gems...), with a cooldown or once per player (saved).',
    params: { 'target*': 'part/model path or "tag:Name"', stat: 'default Coins', amount: 'default 10', cooldown: 'seconds, default 2', once: 'once per player, saved', message: 'toast text' },
    example: { target: 'Workspace/GameKit/GiftBox', stat: 'Coins', amount: 25, once: true },
    build: (p) => {
      const target = need(p, 'target', 'the part or model to touch');
      const stat = str(p.stat, 'Coins');
      const amount = num(p.amount, 10);
      return {
        files: [{
          side: 'server',
          source: `${header('Touch reward', 'Touching the target gives a reward.', { util: true, net: true, playerData: true })}
${settings({
  Stat: stat,
  Amount: amount,
  Cooldown: num(p.cooldown, 2),
  OncePerPlayer: bool(p.once),
  Message: str(p.message, `+${amount} ${stat}!`),
  SaveKey: `Touch_${splitPath(target).pop()?.replace(/\W/g, '') ?? 'Reward'}`,
}, { Cooldown: 'seconds before the same player can get it again', OncePerPlayer: 'true = each player only once (saved)', SaveKey: 'unique id used to remember who got it' })}
${pathHelper(target)}
${EACH_PART}

PlayerData.defineStat({ Name = SETTINGS.Stat, Default = 0, Leaderstat = true })
local ready = Util.cooldown(SETTINGS.Cooldown)

local function onTouched(hit: BasePart)
	local player = Util.playerFromHit(hit)
	if not player or not PlayerData.isLoaded(player) then
		return
	end
	if SETTINGS.OncePerPlayer and PlayerData.owns(player, SETTINGS.SaveKey) then
		return
	end
	if not ready(player) then
		return
	end
	if SETTINGS.OncePerPlayer then
		PlayerData.grant(player, SETTINGS.SaveKey)
	end
	PlayerData.reward(player, SETTINGS.Stat, SETTINGS.Amount)
	if SETTINGS.Message ~= "" then
		Net.notify(player, SETTINGS.Message, "reward")
	end
end

local function setup(instance: Instance)
	eachPart(instance, function(part)
		part.Touched:Connect(onTouched)
	end)
end

${targetCode(target)}
`,
        }],
      };
    },
  },
  {
    id: 'prompt_action',
    title: 'Prompt action',
    summary: 'A "press E" prompt on a part: can cost a stat, give a stat, heal, give a Tool from ServerStorage, teleport, show a message.',
    params: { 'target*': 'part/model path or "tag:Name"', actionText: 'default "Use"', objectText: 'label', costStat: '', cost: 'amount', rewardStat: '', reward: 'amount', heal: 'health', giveTool: 'Tool name in ServerStorage', teleportTo: 'part path', message: '', cooldown: 'default 1', once: 'saved' },
    example: { target: 'Workspace/GameKit/Chest', actionText: 'Open', cost: 50, costStat: 'Coins', giveTool: 'Sword', once: true },
    variants: [{ target: 'tag:Healer', heal: 50, teleportTo: 'Workspace/GameKit/Spawn', reward: 5, rewardStat: 'Gems' }],
    build: (p) => {
      const target = need(p, 'target', 'the part or model that shows the prompt');
      const teleport = str(p.teleportTo);
      const giveTool = str(p.giveTool);
      return {
        files: [{
          side: 'server',
          source: `${header('Prompt action', 'A proximity prompt that does something when used.', { util: true, net: true, playerData: true, services: giveTool ? ['ServerStorage'] : [] })}
${settings({
  ActionText: str(p.actionText, 'Use'),
  ObjectText: str(p.objectText),
  HoldSeconds: num(p.holdSeconds, 0),
  CostStat: str(p.costStat, 'Coins'),
  Cost: num(p.cost, 0),
  RewardStat: str(p.rewardStat, 'Coins'),
  Reward: num(p.reward, 0),
  Heal: num(p.heal, 0),
  GiveTool: giveTool,
  Message: str(p.message, 'Done!'),
  Cooldown: num(p.cooldown, 1),
  OncePerPlayer: bool(p.once),
  SaveKey: `Prompt_${splitPath(target).pop()?.replace(/\W/g, '') ?? 'Action'}`,
}, { Cost: '0 = free', Reward: '0 = no reward', GiveTool: 'name of a Tool in ServerStorage ("" = none)', OncePerPlayer: 'true = each player only once (saved)' })}
${pathHelper(target, teleport)}
${MAIN_PART}

PlayerData.defineStat({ Name = SETTINGS.CostStat, Default = 0, Leaderstat = true })
PlayerData.defineStat({ Name = SETTINGS.RewardStat, Default = 0, Leaderstat = true })
local ready = Util.cooldown(SETTINGS.Cooldown)
${teleport ? `local teleportTarget: BasePart? = nil
task.spawn(function()
	teleportTarget = mainPart(waitForPath(${pathList(teleport)}))
end)
` : ''}
local function onTriggered(player: Player)
	if not PlayerData.isLoaded(player) or not ready(player) then
		return
	end
	if SETTINGS.OncePerPlayer and PlayerData.owns(player, SETTINGS.SaveKey) then
		Net.notify(player, "You already did this.", "info")
		return
	end
	if SETTINGS.Cost > 0 and not PlayerData.spend(player, SETTINGS.CostStat, SETTINGS.Cost, SETTINGS.SaveKey, "Shop") then
		Net.notify(player, \`You need {SETTINGS.Cost} {SETTINGS.CostStat}.\`, "error")
		return
	end
	if SETTINGS.OncePerPlayer then
		PlayerData.grant(player, SETTINGS.SaveKey)
	end
	if SETTINGS.Reward ~= 0 then
		PlayerData.reward(player, SETTINGS.RewardStat, SETTINGS.Reward)
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and SETTINGS.Heal > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + SETTINGS.Heal)
	end
${giveTool ? `	local tool = ServerStorage:FindFirstChild(SETTINGS.GiveTool)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if tool and tool:IsA("Tool") and backpack then
		tool:Clone().Parent = backpack
	end
` : ''}${teleport ? `	if character and teleportTarget then
		Util.teleportOnto(character, teleportTarget)
	end
` : ''}	if SETTINGS.Message ~= "" then
		Net.notify(player, SETTINGS.Message, "success")
	end
end

local function setup(instance: Instance)
	local part = mainPart(instance)
	if not part then
		warn("[Prompt action] no part in " .. instance:GetFullName())
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = SETTINGS.ActionText
	prompt.ObjectText = SETTINGS.ObjectText
	prompt.HoldDuration = SETTINGS.HoldSeconds
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = part
	prompt.Triggered:Connect(onTriggered)
end

${targetCode(target)}
`,
        }],
        notes: giveTool ? [`Put a Tool named "${giveTool}" in ServerStorage.`] : undefined,
      };
    },
  },
  {
    id: 'door',
    title: 'Door with a requirement',
    summary: 'A door that opens (fades, lets players through, closes again) for players who meet a requirement: a stat level, an owned item, or paying once (saved).',
    params: { 'target*': 'door part/model path or "tag:Name"', requireStat: 'stat name', requireMin: 'minimum value', requireItem: 'owned item id', payStat: 'stat', pay: 'price to unlock once', openSeconds: 'default 3', useTouch: 'open by touching instead of a prompt' },
    example: { target: 'Workspace/GameKit/VipDoor', payStat: 'Coins', pay: 500 },
    variants: [{ target: 'tag:LevelDoor', requireStat: 'Level', requireMin: 5, useTouch: true }],
    build: (p) => {
      const target = need(p, 'target', 'the door part or model');
      return {
        files: [{
          side: 'server',
          source: `${header('Door', 'Opens for players who meet the requirement.', { util: true, net: true, playerData: true })}
${settings({
  RequireStat: str(p.requireStat),
  RequireMin: num(p.requireMin, 0),
  RequireItem: str(p.requireItem),
  PayStat: str(p.payStat, 'Coins'),
  Pay: num(p.pay, 0),
  OpenSeconds: num(p.openSeconds, 3),
  UseTouch: bool(p.useTouch),
  SaveKey: `Door_${splitPath(target).pop()?.replace(/\W/g, '') ?? 'Door'}`,
}, { RequireStat: '"" = no stat needed', RequireItem: 'an owned item id, e.g. a Shop item Id ("" = none)', Pay: 'price to unlock the door forever (0 = free)', UseTouch: 'false = press E on the door' })}
${pathHelper(target)}
${EACH_PART}
${MAIN_PART}

local ready = Util.cooldown(1)

local function allowed(player: Player): (boolean, string?)
	if SETTINGS.RequireStat ~= "" and PlayerData.get(player, SETTINGS.RequireStat) < SETTINGS.RequireMin then
		return false, \`You need {SETTINGS.RequireMin} {SETTINGS.RequireStat}.\`
	end
	if SETTINGS.RequireItem ~= "" and not PlayerData.owns(player, SETTINGS.RequireItem) then
		return false, \`You need {SETTINGS.RequireItem}.\`
	end
	if SETTINGS.Pay > 0 and not PlayerData.owns(player, SETTINGS.SaveKey) then
		if not PlayerData.spend(player, SETTINGS.PayStat, SETTINGS.Pay, SETTINGS.SaveKey, "Shop") then
			return false, \`Unlock for {SETTINGS.Pay} {SETTINGS.PayStat}.\`
		end
		PlayerData.grant(player, SETTINGS.SaveKey)
	end
	return true, nil
end

local function setup(door: Instance)
	local opened = false
	local function open()
		if opened then
			return
		end
		opened = true
		local saved: { [BasePart]: number } = {}
		eachPart(door, function(part)
			saved[part] = part.Transparency
			part.Transparency = math.max(part.Transparency, 0.7)
			part.CanCollide = false
		end)
		task.wait(SETTINGS.OpenSeconds)
		for part, transparency in saved do
			part.Transparency = transparency
			part.CanCollide = true
		end
		opened = false
	end
	local function try(player: Player)
		if not PlayerData.isLoaded(player) or not ready(player) then
			return
		end
		local ok, why = allowed(player)
		if ok then
			task.spawn(open)
		elseif why then
			Net.notify(player, why, "error")
		end
	end
	if SETTINGS.UseTouch then
		eachPart(door, function(part)
			part.Touched:Connect(function(hit)
				local player = Util.playerFromHit(hit)
				if player then
					try(player)
				end
			end)
		end)
	else
		local part = mainPart(door)
		if not part then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = if SETTINGS.Pay > 0 then \`Unlock ({SETTINGS.Pay} {SETTINGS.PayStat})\` else "Open"
		prompt.ObjectText = "Door"
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(try)
	end
end

${targetCode(target)}
`,
        }],
      };
    },
  },
  {
    id: 'timed_spawner',
    title: 'Timed spawner',
    summary: 'Every few seconds, places a copy of a template (from ServerStorage) at a random spot of an area, up to a maximum; copies can expire.',
    params: { 'template*': 'path, e.g. "ServerStorage/Coin"', every: 'seconds, default 5', max: 'max alive, default 10', center: '[x,y,z]', size: '[width, depth]', lifetime: 'seconds, 0 = forever', folder: 'folder name in Workspace' },
    example: { template: 'ServerStorage/GoldCoin', every: 4, max: 15, center: [0, 3, 0], size: [80, 80] },
    build: (p) => {
      const template = need(p, 'template', 'the model/part to copy, e.g. "ServerStorage/Coin"');
      const center = vec3(p.center, [0, 5, 0]);
      const size = Array.isArray(p.size) ? p.size.map(Number) : [60, 60];
      return {
        files: [{
          side: 'server',
          source: `${header('Timed spawner', 'Spawns copies of a template over time.', { services: ['Debris'] })}
${settings({
  EverySeconds: num(p.every, 5),
  MaxAlive: num(p.max, 10),
  Center: v3(center),
  Size: v3([num(size[0], 60), 0, num(size[1], 60)]),
  LifetimeSeconds: num(p.lifetime, 0),
  FolderName: str(p.folder, `${splitPath(template).pop() ?? 'Item'}Spawns`),
}, { Center: 'middle of the spawn area', Size: 'width (X) and depth (Z) of the area', LifetimeSeconds: '0 = copies stay until collected/destroyed' })}
${WAIT_FOR_PATH}

local template = waitForPath(${pathList(template)})
local folder = Instance.new("Folder")
folder.Name = SETTINGS.FolderName
folder.Parent = workspace
local random = Random.new()

while true do
	task.wait(SETTINGS.EverySeconds)
	if #folder:GetChildren() < SETTINGS.MaxAlive then
		local position = SETTINGS.Center + Vector3.new(
			random:NextNumber(-0.5, 0.5) * SETTINGS.Size.X,
			0,
			random:NextNumber(-0.5, 0.5) * SETTINGS.Size.Z
		)
		local copy = template:Clone()
		if copy:IsA("Model") then
			copy:PivotTo(CFrame.new(position))
		elseif copy:IsA("BasePart") then
			copy.Position = position
		end
		copy.Parent = folder
		if SETTINGS.LifetimeSeconds > 0 then
			Debris:AddItem(copy, SETTINGS.LifetimeSeconds)
		end
	end
end
`,
        }],
        notes: ['Tip: tag the template "Coin" (attributes Stat, Amount) and the collectibles system handles pickups.'],
      };
    },
  },
  {
    id: 'playtime_reward',
    title: 'Playtime reward',
    summary: 'Gives every player a reward every N seconds they stay in the game.',
    params: { stat: 'default Coins', amount: 'default 10', every: 'seconds, default 60', message: '' },
    example: { stat: 'Gems', amount: 1, every: 300 },
    build: (p) => {
      const stat = str(p.stat, 'Coins');
      const amount = num(p.amount, 10);
      return {
        files: [{
          side: 'server',
          source: `${header('Playtime reward', 'Rewards players for staying.', { services: ['Players'], net: true, playerData: true })}
${settings({ Stat: stat, Amount: amount, EverySeconds: num(p.every, 60), Message: str(p.message, `+${amount} ${stat} for playing!`) })}

PlayerData.defineStat({ Name = SETTINGS.Stat, Default = 0, Leaderstat = true })

while true do
	task.wait(SETTINGS.EverySeconds)
	for _, player in Players:GetPlayers() do
		if PlayerData.isLoaded(player) then
			PlayerData.reward(player, SETTINGS.Stat, SETTINGS.Amount, "TimedReward")
			if SETTINGS.Message ~= "" then
				Net.notify(player, SETTINGS.Message, "reward")
			end
		end
	end
end
`,
        }],
      };
    },
  },
  {
    id: 'ui_button_remote',
    title: 'UI button -> server action',
    summary: 'A screen button (client) that asks the server to do something; the server checks cooldown and price, then rewards. The safe client/server pattern.',
    params: { text: 'button text', position: 'bottom-right | bottom-left | top-right | top-left | bottom', rewardStat: '', reward: 'amount', costStat: '', cost: 'amount', cooldown: 'seconds, default 10', message: '' },
    example: { text: '🎁 Free gift', rewardStat: 'Coins', reward: 50, cooldown: 600 },
    variants: [{ text: 'Buy boost', position: 'top-left', cost: 100, costStat: 'Coins', reward: 1, rewardStat: 'Boosts' }],
    build: (p) => {
      const event = `Recipe_${str(p.text, 'Action').replace(/[^A-Za-z0-9]/g, '').slice(0, 20) || 'Action'}`;
      const position: Record<string, [number, number, number, number, number, number]> = {
        'bottom-right': [1, 1, 1, -16, 1, -16], 'bottom-left': [0, 1, 0, 16, 1, -16], 'top-right': [1, 0, 1, -16, 0, 16],
        'top-left': [0, 0, 0, 16, 0, 16], bottom: [0.5, 1, 0.5, 0, 1, -16],
      };
      const [ax, ay, sx, ox, sy, oy] = position[str(p.position, 'bottom-right')] ?? position['bottom-right'];
      return {
        files: [
          {
            side: 'client',
            source: `${header('UI button', 'Sends a request to the server when clicked.', { net: true, uikit: true })}
${settings({ Text: str(p.text, 'Action'), Event: event })}

local button = UIKit.button(UIKit.hud(), SETTINGS.Text, UDim2.fromOffset(190, 56), function()
	Net.send(SETTINGS.Event)
end)
button.AnchorPoint = Vector2.new(${ax}, ${ay})
button.Position = UDim2.new(${sx}, ${ox}, ${sy}, ${oy})
`,
          },
          {
            side: 'server',
            source: `${header('UI button (server)', 'Checks and performs the button action. Never trust the client.', { util: true, net: true, playerData: true })}
${settings({
  Event: event,
  RewardStat: str(p.rewardStat, 'Coins'),
  Reward: num(p.reward, 0),
  CostStat: str(p.costStat, 'Coins'),
  Cost: num(p.cost, 0),
  CooldownSeconds: num(p.cooldown, 10),
  Message: str(p.message, 'Done!'),
}, { CooldownSeconds: 'per player, checked on the server' })}

PlayerData.defineStat({ Name = SETTINGS.RewardStat, Default = 0, Leaderstat = true })
local ready = Util.cooldown(SETTINGS.CooldownSeconds)

Net.on(SETTINGS.Event, function(player: Player)
	if not PlayerData.isLoaded(player) then
		return
	end
	if not ready(player) then
		Net.notify(player, "Not yet! Try again later.", "info")
		return
	end
	if SETTINGS.Cost > 0 and not PlayerData.spend(player, SETTINGS.CostStat, SETTINGS.Cost, SETTINGS.Event, "Shop") then
		Net.notify(player, \`You need {SETTINGS.Cost} {SETTINGS.CostStat}.\`, "error")
		return
	end
	if SETTINGS.Reward ~= 0 then
		PlayerData.reward(player, SETTINGS.RewardStat, SETTINGS.Reward)
	end
	Net.notify(player, SETTINGS.Message, "success")
end, 2)
`,
          },
        ],
      };
    },
  },
  {
    id: 'npc_dialog',
    title: 'NPC dialog',
    summary: 'Press E on an NPC (or any part) to read dialog lines in a window, one after the other.',
    params: { 'npc*': 'NPC model/part path', name: 'speaker name', lines: 'array of sentences', actionText: 'default "Talk"' },
    example: { npc: 'Workspace/GameKit/Guide', name: 'Old Sam', lines: ['Welcome!', 'The key is behind the waterfall.'] },
    build: (p) => {
      const npc = need(p, 'npc', 'the NPC model or part');
      const lines = Array.isArray(p.lines) && p.lines.length ? p.lines.map(String) : ['Hello there!', 'Have fun!'];
      return {
        files: [{
          side: 'client',
          source: `${header('NPC dialog', 'Shows dialog lines when the player talks to the NPC.', { uikit: true })}
${settings({ Name: str(p.name, 'Guide'), ActionText: str(p.actionText, 'Talk'), Lines: lines })}
${WAIT_FOR_PATH}
${MAIN_PART}

local npc = waitForPath(${pathList(npc)})
local part = mainPart(npc)
if not part then
	warn("[NPC dialog] no part in " .. npc:GetFullName())
	return
end

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = SETTINGS.ActionText
prompt.ObjectText = SETTINGS.Name
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = 12
prompt.Parent = part

local window, body = UIKit.window(SETTINGS.Name, UDim2.fromScale(0.45, 0.35))
local label = UIKit.label(body, "", UDim2.new(1, 0, 1, -60), {
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local nextButton = UIKit.button(body, "Next", UDim2.new(0.35, 0, 0, 48), function() end)
nextButton.AnchorPoint = Vector2.new(1, 1)
nextButton.Position = UDim2.fromScale(1, 1)

local index = 1
local function show()
	label.Text = SETTINGS.Lines[index] or ""
	nextButton.Text = if index < #SETTINGS.Lines then "Next ▶" else "Bye!"
end

nextButton.Activated:Connect(function()
	if index < #SETTINGS.Lines then
		index += 1
		show()
	else
		window.Visible = false
	end
end)

prompt.Triggered:Connect(function()
	index = 1
	show()
	window.Visible = true
end)
`,
        }],
      };
    },
  },
  {
    id: 'badge_award',
    title: 'Badge award',
    summary: 'Awards a Roblox badge when a stat reaches a value, or when a part is touched.',
    params: { 'badgeId*': 'badge id (Creator Dashboard > Badges)', stat: 'stat to watch', atLeast: 'value', target: 'or: part path / "tag:Name" to touch' },
    example: { badgeId: 123456789, stat: 'Wins', atLeast: 1 },
    variants: [{ badgeId: 42, target: 'Workspace/GameKit/SecretRoom', stat: '' }, { badgeId: 43, target: 'tag:Trophy', stat: 'Coins', atLeast: 1000 }],
    build: (p) => {
      const badgeId = num(p.badgeId, 0);
      if (!badgeId) throw new Error('Recipe needs "badgeId": create a badge in Creator Dashboard > your experience > Engagement > Badges');
      const target = str(p.target);
      const stat = str(p.stat, target ? '' : 'Wins');
      return {
        files: [{
          side: 'server',
          source: `${header('Badge award', 'Gives a badge once the condition is met.', { services: ['BadgeService'], util: !!target, playerData: !!stat })}
${settings({ BadgeId: badgeId, Stat: stat, AtLeast: num(p.atLeast, 1) })}
${target ? `${pathHelper(target)}\n${EACH_PART}\n` : ''}
local awarded: { [Player]: boolean } = {}

local function award(player: Player)
	if awarded[player] then
		return
	end
	awarded[player] = true
	task.spawn(function()
		local okHas, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, SETTINGS.BadgeId)
		end)
		if okHas and has then
			return
		end
		local ok, err = pcall(function()
			BadgeService:AwardBadgeAsync(player.UserId, SETTINGS.BadgeId)
		end)
		if not ok then
			awarded[player] = nil
			warn("[Badge] " .. tostring(err))
		end
	end)
end
${stat ? `
PlayerData.onChanged(SETTINGS.Stat, function(player, value)
	if value >= SETTINGS.AtLeast then
		award(player)
	end
end)
PlayerData.onLoaded(function(player)
	if PlayerData.get(player, SETTINGS.Stat) >= SETTINGS.AtLeast then
		award(player)
	end
end)
` : ''}${target ? `
local function setup(instance: Instance)
	eachPart(instance, function(part)
		part.Touched:Connect(function(hit)
			local player = Util.playerFromHit(hit)
			if player then
				award(player)
			end
		end)
	end)
end

${targetCode(target)}
` : ''}`,
        }],
        notes: ['Badges only award in a published game (not in Studio tests).'],
      };
    },
  },
  {
    id: 'character_stats',
    title: 'Character stats',
    summary: 'Sets walk speed, jump power and max health on every spawn; speed can grow with a stat (e.g. Level).',
    params: { walkSpeed: 'default 16', jumpPower: 'default 50', maxHealth: 'default 100', speedStat: 'stat that adds speed', speedPerPoint: 'speed per point' },
    example: { walkSpeed: 20, speedStat: 'Level', speedPerPoint: 0.5 },
    variants: [{ jumpPower: 70, maxHealth: 150 }],
    build: (p) => ({
      files: [{
        side: 'server',
        source: `${header('Character stats', 'Applies movement and health settings to every character.', { util: true, playerData: true })}
${settings({
  WalkSpeed: num(p.walkSpeed, 16),
  JumpPower: num(p.jumpPower, 50),
  MaxHealth: num(p.maxHealth, 100),
  SpeedStat: str(p.speedStat),
  SpeedPerPoint: num(p.speedPerPoint, 0),
}, { SpeedStat: '"" = fixed speed', SpeedPerPoint: 'extra speed per point of SpeedStat' })}

local function apply(character: Model, player: Player)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local bonus = 0
	if SETTINGS.SpeedStat ~= "" then
		bonus = PlayerData.get(player, SETTINGS.SpeedStat) * SETTINGS.SpeedPerPoint
	end
	humanoid.WalkSpeed = SETTINGS.WalkSpeed + bonus
	humanoid.UseJumpPower = true
	humanoid.JumpPower = SETTINGS.JumpPower
	humanoid.MaxHealth = SETTINGS.MaxHealth
	humanoid.Health = SETTINGS.MaxHealth
end

Util.onCharacter(apply)
if SETTINGS.SpeedStat ~= "" then
	PlayerData.onChanged(SETTINGS.SpeedStat, function(player)
		if player.Character then
			apply(player.Character, player)
		end
	end)
end
`,
      }],
      notes: ['The movement system (sprint) and Shop WalkSpeed items also change speed: keep only one owner of WalkSpeed.'],
    }),
  },
  {
    id: 'chat_command',
    title: 'Chat command',
    summary: 'A custom chat command ("/gift 50") for admins (the game owner by default) that gives a stat.',
    params: { command: 'default "/gift"', rewardStat: 'default Coins', amount: 'default 100 (or the number typed after the command)', adminUserIds: 'array of user ids', anyone: 'everyone may use it' },
    example: { command: '/coins', rewardStat: 'Coins', amount: 1000 },
    build: (p) => {
      const command = str(p.command, '/gift').startsWith('/') ? str(p.command, '/gift') : `/${str(p.command)}`;
      const ids = Array.isArray(p.adminUserIds) ? p.adminUserIds.map(Number).filter(Number.isFinite) : [];
      return {
        files: [{
          side: 'server',
          source: `${header('Chat command', 'A chat command handled on the server.', { services: ['Players', 'TextChatService'], net: true, playerData: true })}
${settings({ Command: command, RewardStat: str(p.rewardStat, 'Coins'), Amount: num(p.amount, 100), AdminUserIds: ids, AnyoneCanUse: bool(p.anyone) }, { AdminUserIds: 'extra admins; the game owner is always allowed' })}

PlayerData.defineStat({ Name = SETTINGS.RewardStat, Default = 0, Leaderstat = true })

local function isAllowed(player: Player): boolean
	if SETTINGS.AnyoneCanUse or table.find(SETTINGS.AdminUserIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local command = Instance.new("TextChatCommand")
command.Name = "Recipe" .. string.gsub(SETTINGS.Command, "%W", "")
command.PrimaryAlias = SETTINGS.Command
command.Parent = TextChatService

command.Triggered:Connect(function(source: TextSource, message: string)
	local player = Players:GetPlayerByUserId(source.UserId)
	if not player or not isAllowed(player) or not PlayerData.isLoaded(player) then
		return
	end
	-- "/gift 50" -> amount 50
	local words = string.split(message, " ")
	local amount = tonumber(words[2]) or SETTINGS.Amount
	PlayerData.reward(player, SETTINGS.RewardStat, amount)
	Net.notify(player, \`+{amount} {SETTINGS.RewardStat}\`, "success")
end)
`,
        }],
      };
    },
  },
  {
    id: 'area_music',
    title: 'Area music',
    summary: 'Plays a looping sound (music, ambience) while the player stands inside a zone part, with fades.',
    params: { 'area*': 'zone part path (invisible box)', 'soundId*': 'rbxassetid://...', volume: 'default 0.5' },
    example: { area: 'Workspace/GameKit/CaveZone', soundId: 'rbxassetid://1843463175', volume: 0.4 },
    build: (p) => {
      const area = need(p, 'area', 'an invisible part covering the zone');
      const id = need(p, 'soundId', 'a public audio id');
      return {
        files: [{
          side: 'client',
          source: `${header('Area music', 'Music inside a zone, only for this player.', { services: ['Players', 'SoundService', 'TweenService'] })}
${settings({ SoundId: /^\d+$/.test(id) ? `rbxassetid://${id}` : id, Volume: num(p.volume, 0.5), FadeSeconds: 1 })}
${WAIT_FOR_PATH}
${MAIN_PART}

local zone = mainPart(waitForPath(${pathList(area)}))
local sound = Instance.new("Sound")
sound.SoundId = SETTINGS.SoundId
sound.Looped = true
sound.Volume = 0
sound.Parent = SoundService
local player = Players.LocalPlayer
local inside = false

while true do
	task.wait(0.5)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local nowInside = false
	if zone and root and root:IsA("BasePart") then
		local offset = zone.CFrame:PointToObjectSpace(root.Position)
		local half = zone.Size / 2
		nowInside = math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y + 10 and math.abs(offset.Z) <= half.Z
	end
	if nowInside ~= inside then
		inside = nowInside
		if inside and not sound.IsPlaying then
			sound:Play()
		end
		TweenService:Create(sound, TweenInfo.new(SETTINGS.FadeSeconds), { Volume = if inside then SETTINGS.Volume else 0 }):Play()
	end
end
`,
        }],
        notes: ['Make the zone part Transparency 1, CanCollide false, Anchored. Private audio does not play: use a public sound.'],
      };
    },
  },
  {
    id: 'tween_loop',
    title: 'Moving / rotating loop',
    summary: 'Moves and/or rotates a part or model back and forth forever, smoothly (TweenService).',
    params: { 'target*': 'part/model path or "tag:Name"', offset: '[x,y,z] studs', rotation: '[x,y,z] degrees', seconds: 'default 2', pingPong: 'go back, default true', easing: 'Sine | Linear | Quad | Back | Bounce | Elastic' },
    example: { target: 'Workspace/GameKit/Elevator', offset: [0, 20, 0], seconds: 3 },
    variants: [{ target: 'tag:Spinner', offset: [0, 0, 0], rotation: [0, 180, 0], easing: 'Linear', pingPong: false }],
    build: (p) => {
      const target = need(p, 'target', 'the part or model to move');
      const easings = new Set((API_ENUMS.EasingStyle ?? '').split(','));
      const easing = easings.has(str(p.easing)) ? str(p.easing) : 'Sine';
      return {
        files: [{
          side: 'server',
          source: `${header('Tween loop', 'Smooth endless movement.', { services: ['TweenService'], util: target.startsWith('tag:') })}
${settings({ Offset: v3(vec3(p.offset, [0, 10, 0])), Rotation: v3(vec3(p.rotation, [0, 0, 0])), Seconds: num(p.seconds, 2), PingPong: bool(p.pingPong, true) }, { Rotation: 'degrees around X, Y, Z' })}
${pathHelper(target)}

local goal = CFrame.new(SETTINGS.Offset)
	* CFrame.Angles(math.rad(SETTINGS.Rotation.X), math.rad(SETTINGS.Rotation.Y), math.rad(SETTINGS.Rotation.Z))
local info = TweenInfo.new(SETTINGS.Seconds, Enum.EasingStyle.${easing}, Enum.EasingDirection.InOut, -1, SETTINGS.PingPong)

local function setup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		TweenService:Create(instance, info, { CFrame = instance.CFrame * goal }):Play()
	elseif instance:IsA("Model") then
		for _, part in instance:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		local start = instance:GetPivot()
		local value = Instance.new("CFrameValue")
		value.Value = start
		value:GetPropertyChangedSignal("Value"):Connect(function()
			instance:PivotTo(value.Value)
		end)
		TweenService:Create(value, info, { Value = start * goal }):Play()
	end
end

${targetCode(target)}
`,
        }],
      };
    },
  },
];

export function getRecipe(id: string): RecipeDef {
  const recipe = RECIPES.find((r) => r.id === id);
  if (!recipe) throw new Error(`Unknown recipe "${id}". Recipes: ${RECIPES.map((r) => r.id).join(', ')}`);
  return recipe;
}

export const RECIPE_TOOLS: ToolDef[] = [
  {
    name: 'code_recipe',
    category: 'write',
    tier: 'starter',
    description: 'Ready-made, verified scripts from a few params: prefer them to writing code. Without recipe: lists recipes and params. Installs by default; preview returns the code.',
    inputSchema: {
      type: 'object',
      properties: {
        recipe: { type: 'string', enum: RECIPES.map((r) => r.id) },
        params: { type: 'object' },
        name: { type: 'string', description: 'Script name (default from the recipe)' },
        preview: { type: 'boolean', description: 'Return the code without installing' },
      },
    },
  },
];

function scriptName(recipe: RecipeDef, p: Params, override?: string): string {
  if (override) return override.replace(/[^\w]/g, '') || recipe.id;
  const base = recipe.id.split('_').map((w) => w[0].toUpperCase() + w.slice(1)).join('');
  const target = str(p.target ?? p.npc ?? p.template ?? p.area);
  const suffix = target ? (target.startsWith('tag:') ? target.slice(4) : splitPath(target).pop() ?? '') : '';
  return `${base}${suffix ? `_${suffix.replace(/[^\w]/g, '')}` : ''}`;
}

export async function handleRecipe(host: GameKitHost, args: Record<string, any>, requireStudio: () => void): Promise<ToolResult> {
  if (!args.recipe) {
    return text(`Code recipes (code_recipe { recipe, params }; * = required):\n${RECIPES.map((r) => `- ${r.id}: ${r.summary} | params: ${Object.entries(r.params).map(([k, v]) => `${k}${v ? ` (${v})` : ''}`).join(', ')} | e.g. ${JSON.stringify(r.example)}`).join('\n')}`);
  }
  const recipe = getRecipe(String(args.recipe));
  const params = (args.params ?? {}) as Params;
  const built = recipe.build(params);
  const name = scriptName(recipe, params, args.name);
  const files = built.files.map((f) => ({
    ...f,
    parent: f.side === 'server' ? ['ServerScriptService', 'Recipes'] : ['StarterPlayer', 'StarterPlayerScripts', 'Recipes'],
    name: f.side === 'client' && built.files.length > 1 ? `${name}Client` : name,
    className: f.side === 'server' ? 'Script' : 'LocalScript',
  }));
  // Recipes are verified in CI; this re-check guards against unusual params.
  for (const f of files) {
    const prepared = await prepareLuau(f.source, f.side === 'server' ? 'server' : 'client', false);
    if (prepared.validation.errors.length) {
      return text({ ok: false, problem: `The generated ${f.side} script has errors (check the params).`, errors: prepared.validation.errors.slice(0, 5) });
    }
  }
  if (args.preview) {
    return text(files.map((f) => `-- ${[...f.parent, f.name].join('/')} (${f.className})\n${f.source}`).join('\n\n'));
  }
  requireStudio();
  // Recipes build on GameKit core (PlayerData, Net, Util, UIKit): install it if missing, never overwrite it.
  const core: Placement[] = systemPlacements([]).placements.map((pl) => ({ ...pl, mode: 'keep' as const }));
  const report = await install(host, {
    label: `GameKit: recipe ${recipe.id}`,
    items: [...core, ...files.map((f) => ({ parent: f.parent, mode: 'replace' as const, node: { name: f.name, className: f.className, source: f.source } }))],
  });
  return text({
    ok: report.ok,
    error: report.error,
    installed: files.map((f) => `${[...f.parent, f.name].join('/')} (${f.className})`),
    notes: built.notes,
    next: 'test_game to try it. Tweak values in its SETTINGS table with edit_script (read_script first).',
  });
}
