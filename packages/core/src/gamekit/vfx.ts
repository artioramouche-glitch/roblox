/**
 * Visual effects saved as templates in ReplicatedStorage/GameKit/Effects/<Name>, played in
 * game with one line: Util.vfx("Name", part) (bursts emit once, looping effects run a while).
 *   - preset: ready-made effects built from textures that ship with Roblox (no upload).
 *   - plugin + collect: the user builds a polished effect with the free VFX Studio plugin
 *     (texture/mesh library, emitter tools); collect saves the selected result as a template.
 * Burst emitters carry the community "EmitCount" / "EmitDelay" attributes.
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { runLuauJson, splitPath } from './installer.js';
import { FIND_PATH } from './sound.js';
import { luauJson, text, type ToolResult } from './result.js';

interface Emitter {
  name: string;
  texture: string;
  color: string[];
  size: [number, number];
  transparency?: [number, number];
  lifetime: [number, number];
  speed: [number, number];
  spread?: [number, number];
  rate?: number;
  emit?: number;
  light?: number;
  drag?: number;
  acceleration?: [number, number, number];
  rotSpeed?: [number, number];
  locked?: boolean;
  /** The color option replaces this emitter's colors. */
  tint?: boolean;
}

const T = (file: string) => `rbxasset://textures/particles/${file}.dds`;

export const VFX_PRESETS: Record<string, { about: string; loop?: boolean; emitters: Emitter[] }> = {
  hit_spark: {
    about: 'Short bright sparks on a hit (combat, breaking blocks).',
    emitters: [{ name: 'Sparks', texture: T('sparkles_main'), color: ['#FFFFFF', '#FFC940'], size: [0.6, 0], lifetime: [0.15, 0.3], speed: [20, 35], spread: [180, 180], emit: 18, light: 1, drag: 5, tint: true }],
  },
  sparkle: {
    about: 'Pickup / reward twinkle (coins, gems, items).',
    emitters: [{ name: 'Twinkle', texture: T('sparkles_main'), color: ['#FFE066', '#FFC940'], size: [0.5, 0], lifetime: [0.4, 0.8], speed: [4, 8], spread: [180, 180], emit: 25, light: 1, tint: true }],
  },
  explosion: {
    about: 'Fireball blast with smoke and flying sparks.',
    emitters: [
      { name: 'Core', texture: T('explosion01_core_main'), color: ['#FFB347', '#FF5722'], size: [4, 10], transparency: [0, 1], lifetime: [0.3, 0.5], speed: [0, 2], emit: 3, light: 1, tint: true },
      { name: 'Smoke', texture: T('smoke_main'), color: ['#5A5A5A', '#2B2B2B'], size: [3, 8], transparency: [0.3, 1], lifetime: [1, 1.6], speed: [6, 12], spread: [180, 180], emit: 12, drag: 3 },
      { name: 'Sparks', texture: T('fire_sparks_main'), color: ['#FFD180', '#FF6D00'], size: [0.4, 0], lifetime: [0.4, 0.8], speed: [30, 50], spread: [180, 180], emit: 25, light: 1, drag: 2 },
    ],
  },
  fire: {
    about: 'Looping flames (torches, campfires, burning objects).',
    loop: true,
    emitters: [
      { name: 'Flames', texture: T('fire_main'), color: ['#FFB300', '#E53935'], size: [1.5, 0.3], transparency: [0.2, 1], lifetime: [0.6, 1], speed: [3, 5], spread: [10, 10], rate: 40, light: 1, acceleration: [0, 4, 0], rotSpeed: [-40, 40], tint: true },
      { name: 'Embers', texture: T('fire_sparks_main'), color: ['#FFD180', '#FF6D00'], size: [0.2, 0], lifetime: [1, 1.6], speed: [3, 6], spread: [25, 25], rate: 8, light: 1 },
    ],
  },
  smoke_puff: {
    about: 'Soft puff of smoke (landing, poof, disappearing).',
    emitters: [{ name: 'Puff', texture: T('smoke_main'), color: ['#E0E0E0', '#9E9E9E'], size: [1, 4], transparency: [0.4, 1], lifetime: [0.8, 1.2], speed: [2, 5], spread: [180, 180], emit: 10, drag: 2, tint: true }],
  },
  heal_aura: {
    about: 'Looping rising green sparkles around a player or a zone.',
    loop: true,
    emitters: [{ name: 'Aura', texture: T('sparkles_main'), color: ['#B9F6CA', '#00C853'], size: [0.4, 0], lifetime: [1, 1.5], speed: [2, 4], spread: [30, 30], rate: 20, light: 1, acceleration: [0, 2, 0], tint: true }],
  },
  level_up: {
    about: 'Big golden burst with a glow (level up, rebirth, unlock).',
    emitters: [
      { name: 'Burst', texture: T('sparkles_main'), color: ['#FFF59D', '#FFC940'], size: [0.8, 0], lifetime: [0.8, 1.4], speed: [10, 16], spread: [180, 180], emit: 40, light: 1, drag: 2, tint: true },
      { name: 'Glow', texture: T('forcefield_glow_main'), color: ['#FFE082', '#FFC940'], size: [4, 9], transparency: [0.2, 1], lifetime: [0.5, 0.5], speed: [0, 0], emit: 1, light: 1, tint: true },
    ],
  },
  magic: {
    about: 'Looping swirling magic (spell charge, enchanted item, magic circle).',
    loop: true,
    emitters: [
      { name: 'Swirl', texture: T('forcefield_vortex_main'), color: ['#B388FF', '#651FFF'], size: [2, 4], transparency: [0.3, 1], lifetime: [1, 1], speed: [0, 0], rate: 6, light: 1, rotSpeed: [90, 180], locked: true, tint: true },
      { name: 'Motes', texture: T('sparkles_main'), color: ['#E1BEE7', '#AA00FF'], size: [0.3, 0], lifetime: [0.8, 1.2], speed: [1, 3], spread: [180, 180], rate: 15, light: 1, tint: true },
    ],
  },
  portal: {
    about: 'Looping vortex for teleporters and portals.',
    loop: true,
    emitters: [
      { name: 'Vortex', texture: T('forcefield_vortex_main'), color: ['#80DEEA', '#00B8D4'], size: [6, 6], transparency: [0.2, 1], lifetime: [1.5, 1.5], speed: [0, 0], rate: 5, light: 1, rotSpeed: [120, 160], locked: true, tint: true },
      { name: 'Sparks', texture: T('sparkles_main'), color: ['#E0F7FA', '#00E5FF'], size: [0.3, 0], lifetime: [0.6, 1], speed: [2, 4], spread: [180, 180], rate: 20, light: 1, tint: true },
    ],
  },
  dust: {
    about: 'Dust kicked up by a dash, a landing or a stomp.',
    emitters: [{ name: 'Dust', texture: T('smoke_main'), color: ['#D7CCC8', '#A1887F'], size: [0.6, 2.4], transparency: [0.5, 1], lifetime: [0.4, 0.7], speed: [4, 8], spread: [180, 15], emit: 12, drag: 4, tint: true }],
  },
  celebration: {
    about: 'Colorful burst for wins, purchases and rewards.',
    emitters: ['#FF5252', '#FFD740', '#69F0AE', '#40C4FF', '#E040FB'].map((c, i) => ({
      name: `Color${i + 1}`, texture: T('sparkles_main'), color: [c, c], size: [0.6, 0.2] as [number, number], lifetime: [1, 1.6] as [number, number],
      speed: [12, 20] as [number, number], spread: [60, 60] as [number, number], emit: 10, light: 0.6, drag: 1, acceleration: [0, -12, 0] as [number, number, number],
    })),
  },
};

export const VFX_TOOLS: ToolDef[] = [
  {
    name: 'make_vfx',
    category: 'write',
    tier: 'starter',
    description: `Visual effects saved as templates (ReplicatedStorage/GameKit/Effects/<name>), played in scripts with Util.vfx("<name>", part). "preset" (default): ${Object.keys(VFX_PRESETS).join(', ')}. "plugin": steps for the free VFX Studio plugin (polished effects), then "collect" saves the effect the user selected. "list": saved effects. See roblox_guide vfx.`,
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['preset', 'plugin', 'collect', 'list'], description: 'default preset' },
        preset: { type: 'string', enum: Object.keys(VFX_PRESETS) },
        name: { type: 'string', description: 'Template name, e.g. "SwordHit" (default: from the preset)' },
        color: { type: 'string', description: 'preset: main color "#RRGGBB"' },
        parent: { type: 'string', description: 'preset: also put a running copy on this part (torch, portal, zone). plugin: part to select' },
      },
      required: [],
    },
  },
];

const pascal = (s: string) => s.replace(/[^A-Za-z0-9]+/g, ' ').trim().split(' ').filter(Boolean).map((w) => w[0].toUpperCase() + w.slice(1)).join('') || 'Effect';

/** The shared Effects folder (created when missing), in Luau. */
const EFFECTS = `
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local kit = ReplicatedStorage:FindFirstChild("GameKit")
local hasUtil = kit ~= nil and kit:FindFirstChild("Util") ~= nil
if not kit then
	kit = Instance.new("Folder")
	kit.Name = "GameKit"
	kit.Parent = ReplicatedStorage
end
local effects = kit:FindFirstChild("Effects")
if not effects then
	effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = kit
end`;

export function presetLuau(preset: string, name: string, emitters: Emitter[], parent?: string): string {
  return `
local HttpService = game:GetService("HttpService")
${FIND_PATH}
${EFFECTS}
local P = HttpService:JSONDecode(${luauJson({ preset, name, emitters, parent: parent ? splitPath(parent) : null })})
local old = effects:FindFirstChild(P.name)
if old then old:Destroy() end
local holder = Instance.new("Attachment")
holder.Name = P.name
holder:SetAttribute("GK_Preset", P.preset)
for _, e in P.emitters do
	local pe = Instance.new("ParticleEmitter")
	pe.Name = e.name
	pe.Texture = e.texture
	pe.Color = ColorSequence.new(Color3.fromHex(e.color[1]), Color3.fromHex(e.color[2] or e.color[1]))
	pe.Size = NumberSequence.new(e.size[1], e.size[2])
	local t = e.transparency or { 0, 1 }
	pe.Transparency = NumberSequence.new(t[1], t[2])
	pe.Lifetime = NumberRange.new(e.lifetime[1], e.lifetime[2])
	pe.Speed = NumberRange.new(e.speed[1], e.speed[2])
	local spread = e.spread or { 0, 0 }
	pe.SpreadAngle = Vector2.new(spread[1], spread[2])
	pe.Rate = e.rate or 0
	pe.LightEmission = e.light or 0
	pe.Drag = e.drag or 0
	local a = e.acceleration or { 0, 0, 0 }
	pe.Acceleration = Vector3.new(a[1], a[2], a[3])
	local rot = e.rotSpeed or { 0, 0 }
	pe.RotSpeed = NumberRange.new(rot[1], rot[2])
	pe.Rotation = NumberRange.new(0, 360)
	pe.LockedToPart = e.locked == true
	if e.emit then
		pe:SetAttribute("EmitCount", e.emit)
	end
	pe.Enabled = (e.rate or 0) > 0
	pe.Parent = holder
end
holder.Parent = effects
local placed = nil
if P.parent then
	local node = findPath(P.parent)
	if not node or not node:IsA("BasePart") then
		return HttpService:JSONEncode({ ok = false, template = holder:GetFullName(), error = "parent must be a part: " .. table.concat(P.parent, "/") })
	end
	local live = node:FindFirstChild(P.name)
	if live then live:Destroy() end
	holder:Clone().Parent = node
	placed = node:GetFullName() .. "." .. P.name
end
return HttpService:JSONEncode({ ok = true, template = holder:GetFullName(), placed = placed, utilInstalled = hasUtil })`;
}

/** Saves the first selected object (the effect the user made) as a template. */
export function collectLuau(name: string): string {
  return `
local HttpService = game:GetService("HttpService")
${EFFECTS}
local NAME = ${luauJson(name)}
local picked = game:GetService("Selection"):Get()[1]
if not picked then
	return HttpService:JSONEncode({ ok = false, error = "Nothing is selected in Studio" })
end
local copy = picked:Clone()
if not copy then
	return HttpService:JSONEncode({ ok = false, error = picked:GetFullName() .. " cannot be copied (Archivable is off)" })
end
if copy:IsA("ParticleEmitter") or copy:IsA("Beam") or copy:IsA("Trail") then
	local holder = Instance.new("Attachment")
	copy.Parent = holder
	copy = holder
end
copy.Name = NAME
local emitters, bursts = 0, 0
local all = copy:GetDescendants()
table.insert(all, copy)
for _, d in all do
	if d:IsA("ParticleEmitter") then
		emitters += 1
		-- A disabled emitter is a burst: give it a count when the effect has none.
		if not d.Enabled and d:GetAttribute("EmitCount") == nil then
			d:SetAttribute("EmitCount", 20)
		end
		if d:GetAttribute("EmitCount") then bursts += 1 end
	end
end
local old = effects:FindFirstChild(NAME)
if old then old:Destroy() end
copy.Parent = effects
return HttpService:JSONEncode({ ok = true, from = picked:GetFullName(), template = copy:GetFullName(), className = copy.ClassName, emitters = emitters, bursts = bursts, utilInstalled = hasUtil })`;
}

export const LIST_LUAU = `
local HttpService = game:GetService("HttpService")
local kit = game:GetService("ReplicatedStorage"):FindFirstChild("GameKit")
local effects = kit and kit:FindFirstChild("Effects")
local list = {}
if effects then
	for _, e in effects:GetChildren() do
		table.insert(list, { name = e.Name, className = e.ClassName, preset = e:GetAttribute("GK_Preset") })
	end
end
return HttpService:JSONEncode({ ok = true, effects = list })`;

const PLUGIN_STEPS = [
  'Plugins tab > VFX Studio (free; install it once from its Creator Store page).',
  'Build the effect there from its texture/mesh library and emitter tools. Show the user reference pictures first: design_refs { query: "<effect>" }.',
  'Insert the finished effect into the game, then SELECT it in the Explorer (the Attachment, emitter or part holding the effect).',
];

const play = (name: string) => `local Util = require(game:GetService("ReplicatedStorage").GameKit.Util)\nUtil.vfx("${name}", part) -- or a Vector3, or Util.vfx("${name}", part, 3) to run a looping effect 3 s`;

export async function handleVfx(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  if (!host.isStudioConnected()) throw new Error('Roblox Studio is not connected (Plugins > MCP Server > Connect).');
  const action = String(args.action ?? 'preset');
  const noUtil = 'GameKit Util is missing: run create_game or add_system (any system) so scripts can call Util.vfx.';
  if (action === 'list') return text(await runLuauJson(host, LIST_LUAU, 'List effects'));
  if (action === 'plugin') {
    if (args.parent) await runLuauJson(host, `${FIND_PATH}\nlocal node = findPath(${luauJson(splitPath(String(args.parent)))})\nif node then game:GetService("Selection"):Set({ node }) end\nreturn game:GetService("HttpService"):JSONEncode({ ok = node ~= nil })`, 'Select part');
    return text({ ok: true, steps: PLUGIN_STEPS, then: `make_vfx { action: "collect", name: "${pascal(String(args.name ?? 'MyEffect'))}" } once the user says the effect is selected.` });
  }
  if (action === 'collect') {
    const name = pascal(String(args.name ?? 'MyEffect'));
    const saved = await runLuauJson(host, collectLuau(name), 'Collect effect');
    if (!saved.ok) return text({ ...saved, fix: 'Ask the user to select the finished effect in the Explorer, then collect again.' });
    return text({ ...saved, play: play(name), warning: saved.utilInstalled ? undefined : noUtil });
  }
  if (action !== 'preset') throw new Error(`Unknown make_vfx action "${action}". Use preset, plugin, collect or list.`);
  const id = String(args.preset ?? '');
  const preset = VFX_PRESETS[id];
  if (!preset) throw new Error(`make_vfx needs a preset: ${Object.keys(VFX_PRESETS).join(', ')}`);
  const name = pascal(String(args.name ?? id));
  const tint = typeof args.color === 'string' && /^#?[0-9a-f]{6}$/i.test(args.color) ? `#${args.color.replace('#', '')}` : undefined;
  const emitters = preset.emitters.map((e) => (tint && e.tint ? { ...e, color: [tint, tint] } : e));
  const made = await runLuauJson(host, presetLuau(id, name, emitters, args.parent ? String(args.parent) : undefined), 'Make effect');
  return text({
    ...made,
    effect: preset.about,
    play: preset.loop && made.placed ? `Already running on ${made.placed}. Elsewhere: ${play(name)}` : play(name),
    warning: made.utilInstalled ? undefined : noUtil,
    next: 'Trigger it where the action happens (hit, pickup, level up), then test_game. Polished custom effect: make_vfx { action: "plugin" } (VFX Studio).',
  });
}
