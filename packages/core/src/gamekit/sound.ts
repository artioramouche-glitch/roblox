/**
 * Sound effects made to order with Mirelo AI (mirelo.ai), two ways:
 *   - generate: the Mirelo API (MIRELO_API_KEY) turns a text prompt into audio, the file is
 *     uploaded to Roblox with upload_asset (Open Cloud key) and a Sound is placed in Studio.
 *   - plugin + collect: no key, the free "Mirelo AI SFX Generation" Studio plugin does the
 *     generation and upload. This tool selects what the plugin should "hear" (it reads the
 *     selected objects: material, size, physics), then finds the new Sounds it left in
 *     SoundService and moves them where they belong.
 * API reference: https://mirelo.ai/api-docs.md (text-to-sfx v3).
 */

import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import type { GameKitHost, ToolDef } from './tools.js';
import { runLuauJson, splitPath } from './installer.js';
import { luauJson, resultJson, sleep, text, type ToolResult } from './result.js';

export const MIRELO_API = 'https://api.mirelo.ai/v3';
const FINAL = new Set(['succeeded', 'partially_succeeded', 'failed', 'canceled', 'expired']);

export const SOUND_TOOLS: ToolDef[] = [
  {
    name: 'make_sound',
    category: 'write',
    tier: 'starter',
    description: 'Custom sound effects (Mirelo AI) from a text prompt. "generate" (MIRELO_API_KEY): prompt -> audio -> uploaded to Roblox (Open Cloud key) -> Sound on a part or in SoundService. "plugin" (no key, free Mirelo Studio plugin): selects the objects the plugin reads and gives the steps; then "collect" moves the new Sounds where they belong. Uploads go to the user\'s Roblox account: ask first. See roblox_guide sound.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['generate', 'plugin', 'collect'], description: 'default generate' },
        prompt: { type: 'string', description: 'What it sounds like: source, material, action, space. "Wooden crate breaking on stone, short and punchy"' },
        seconds: { type: 'number', description: 'Length, default 2 (0.1 to 60)' },
        loop: { type: 'boolean', description: 'Seamless loop for ambience or music beds (1 s minimum)' },
        name: { type: 'string', description: 'Sound name, e.g. "CoinPickup"' },
        parent: { type: 'string', description: 'Where the Sound goes: a part or attachment for a 3D sound, default SoundService' },
        volume: { type: 'number', description: 'default 0.5' },
        select: { type: 'array', items: { type: 'string' }, description: 'plugin: objects the Mirelo plugin should read (default: parent)' },
        upload: { type: 'boolean', description: 'generate: false = only make the audio file (default true)' },
      },
      required: [],
    },
  },
];

type Fetch = typeof fetch;

export interface MireloJob {
  id?: string;
  status?: string;
  credits?: number;
  errors?: Array<{ code?: string; message?: string }>;
  urls?: { self?: string };
  result?: { output?: { variants?: Array<{ status?: string; files?: { audio?: { url?: string; format?: string; duration_ms?: number } } }> } };
}

/** The create body: sfx-2.0 by default, sfx-1.6 for loops (only it has controls.loop). */
export function mireloRequest(prompt: string, seconds: number, loop: boolean) {
  const ms = Math.round(Math.min(60, Math.max(loop ? 1 : 0.1, seconds)) * 1000);
  return {
    model: loop ? 'sfx-1.6' : 'sfx-2.0',
    duration_ms: ms,
    num_variants: 1,
    input: { prompt: prompt.slice(0, 2000) },
    ...(loop ? { controls: { loop: true } } : {}),
    output: { format: 'mp3_192' },
  };
}

/** First audio file of a finished job, or why there is none. */
export function mireloAudio(job: MireloJob): { url?: string; problem?: string } {
  const variant = job.result?.output?.variants?.find((v) => v.status === 'succeeded' && v.files?.audio?.url);
  if (variant) return { url: variant.files!.audio!.url };
  const why = job.errors?.map((e) => `${e.code}: ${e.message}`).join('; ');
  return { problem: `Mirelo job ${job.status ?? 'unknown'}${why ? ` (${why})` : ''}` };
}

async function mireloError(res: Response): Promise<string> {
  const body: any = await res.json().catch(() => ({}));
  const code = body?.error?.code ?? `HTTP ${res.status}`;
  const hint = res.status === 401 ? ' (check MIRELO_API_KEY)' : res.status === 402 ? ' (no Mirelo credits left)' : res.status === 429 ? ' (too many jobs at once, retry in a minute)' : '';
  return `Mirelo ${code}: ${body?.error?.message ?? res.statusText}${hint}`;
}

/** Text -> audio file on disk. Polls the job until it is final (about a minute at most). */
export async function generateMirelo(
  key: string,
  prompt: string,
  seconds: number,
  loop: boolean,
  outFile: string,
  fetchImpl: Fetch = fetch,
  pollMs = 2000,
): Promise<{ file: string; jobId?: string; credits?: number }> {
  const headers = { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
  const res = await fetchImpl(`${MIRELO_API}/text-to-sfx/generations?wait=25`, {
    method: 'POST',
    headers: { ...headers, 'Idempotency-Key': randomUUID() },
    body: JSON.stringify(mireloRequest(prompt, seconds, loop)),
  });
  if (!res.ok) throw new Error(await mireloError(res));
  let job = (await res.json()) as MireloJob;
  const deadline = Date.now() + 180_000;
  while (!FINAL.has(job.status ?? '') && Date.now() < deadline) {
    await sleep(pollMs);
    const poll = await fetchImpl(job.urls?.self ?? `${MIRELO_API}/text-to-sfx/generations/${job.id}`, { headers });
    if (!poll.ok) throw new Error(await mireloError(poll));
    job = (await poll.json()) as MireloJob;
  }
  if (!FINAL.has(job.status ?? '')) throw new Error(`Mirelo job ${job.id} still ${job.status} after 3 minutes`);
  const audio = mireloAudio(job);
  if (!audio.url) throw new Error(audio.problem);
  // The download link may redirect to storage: no API key on this request.
  const file = await fetchImpl(audio.url);
  if (!file.ok) throw new Error(`Download of the Mirelo audio failed: HTTP ${file.status}`);
  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  fs.writeFileSync(outFile, Buffer.from(await file.arrayBuffer()));
  return { file: outFile, jobId: job.id, credits: job.credits };
}

/** Luau: resolves a path (service first, then children); nil when a segment is missing. */
export const FIND_PATH = `
local function findPath(segs)
	local node = game
	for _, seg in segs do
		local ok, service = pcall(function() return if node == game then game:GetService(seg) else nil end)
		node = if ok and service then service else node:FindFirstChild(seg)
		if not node then return nil end
	end
	return node
end`;

/** Puts a Sound under `parent` (SoundService by default); 3D settings when the parent is in the world. */
export function placeSoundLuau(o: { name: string; soundId?: string; parent?: string; volume: number; loop: boolean; prompt?: string }): string {
  return `
local HttpService = game:GetService("HttpService")
${FIND_PATH}
local P = HttpService:JSONDecode(${luauJson({ ...o, parent: o.parent ? splitPath(o.parent) : null })})
local node = if P.parent then findPath(P.parent) else game:GetService("SoundService")
if not node then return HttpService:JSONEncode({ ok = false, error = "Parent not found: " .. table.concat(P.parent, "/") }) end
local old = node:FindFirstChild(P.name)
if old and old:IsA("Sound") then old:Destroy() end
local sound = Instance.new("Sound")
sound.Name = P.name
sound.SoundId = "rbxassetid://" .. P.soundId
sound.Volume = P.volume
sound.Looped = P.loop
if node:IsA("BasePart") or node:IsA("Attachment") then
	sound.RollOffMaxDistance = 80
end
if P.prompt then sound:SetAttribute("GK_Prompt", string.sub(P.prompt, 1, 200)) end
sound.Parent = node
return HttpService:JSONEncode({ ok = true, path = sound:GetFullName(), positional = node:IsA("BasePart") or node:IsA("Attachment") })`;
}

/** Every Sound in SoundService, with a stable per-session id to tell new ones apart. */
export function listSoundsLuau(select?: string[][]): string {
  return `
local HttpService = game:GetService("HttpService")
${FIND_PATH}
local SELECT = HttpService:JSONDecode(${luauJson(select ?? null)})
if SELECT then
	local picked = {}
	for _, segs in SELECT do
		local node = findPath(segs)
		if node and node ~= game then table.insert(picked, node) end
	end
	game:GetService("Selection"):Set(picked)
end
local sounds = {}
for _, s in game:GetService("SoundService"):GetDescendants() do
	if s:IsA("Sound") then
		table.insert(sounds, { id = s:GetDebugId(), path = s:GetFullName(), name = s.Name, soundId = s.SoundId, seconds = s.TimeLength })
	end
end
return HttpService:JSONEncode({ ok = true, sounds = sounds, selected = if SELECT then #game:GetService("Selection"):Get() else nil })`;
}

/** Moves the Sounds with these debug ids under `parent` (and renames a lone one). */
export function moveSoundsLuau(ids: string[], parent: string, name?: string): string {
  return `
local HttpService = game:GetService("HttpService")
${FIND_PATH}
local P = HttpService:JSONDecode(${luauJson({ ids, parent: splitPath(parent), name: name ?? null })})
local node = findPath(P.parent)
if not node then return HttpService:JSONEncode({ ok = false, error = "Parent not found: " .. table.concat(P.parent, "/") }) end
local want = {}
for _, id in P.ids do want[id] = true end
local moved = {}
for _, s in game:GetService("SoundService"):GetDescendants() do
	if s:IsA("Sound") and want[s:GetDebugId()] then
		if P.name and #P.ids == 1 then s.Name = P.name end
		if node:IsA("BasePart") or node:IsA("Attachment") then s.RollOffMaxDistance = 80 end
		s.Parent = node
		table.insert(moved, s:GetFullName())
	end
end
return HttpService:JSONEncode({ ok = true, moved = moved })`;
}

const PLUGIN_STEPS = [
  'Plugins tab > Mirelo AI SFX Generation (install it from the Creator Store once, it is free).',
  'First time only: sign in with a Mirelo account in the browser and allow audio uploads to your Roblox account.',
  'Keep the selected objects selected: the plugin reads them (material, size, physics) to fit the sound to the scene.',
  'Paste the prompt below, pick Cartoonish or Realistic, click Generate. The sound is uploaded to your account and appears in SoundService.',
];

export class SoundTools {
  /** Debug ids of the SoundService Sounds seen by the last "plugin" call. */
  private known: Set<string> | undefined;

  constructor(private host: GameKitHost, private fetchImpl: Fetch = fetch, private pollMs = 2000) {}

  async call(args: Record<string, any>): Promise<ToolResult> {
    const action = String(args.action ?? 'generate');
    if (action === 'plugin') return this.plugin(args);
    if (action === 'collect') return this.collect(args);
    if (action === 'generate') return this.generate(args);
    throw new Error(`Unknown make_sound action "${action}". Use generate, plugin or collect.`);
  }

  private name(args: Record<string, any>): string {
    const raw = String(args.name ?? args.prompt ?? 'Sound');
    return raw.replace(/[^A-Za-z0-9]+/g, ' ').trim().split(' ').slice(0, 4).map((w) => w[0].toUpperCase() + w.slice(1)).join('') || 'Sound';
  }

  private async generate(args: Record<string, any>): Promise<ToolResult> {
    const prompt = String(args.prompt ?? '').trim();
    if (!prompt) throw new Error('make_sound needs a prompt, e.g. "short bright coin pickup chime, cartoon".');
    const key = process.env.MIRELO_API_KEY;
    if (!key) {
      return text({
        ok: false,
        problem: 'MIRELO_API_KEY is not set.',
        options: [
          'Free, no key: make_sound {action: "plugin", prompt, parent} uses the Mirelo Studio plugin.',
          'Automatic: create a key at mirelo.ai (Studio > Developer > API Keys), set MIRELO_API_KEY in the MCP config, restart the AI app.',
        ],
      });
    }
    const name = this.name(args);
    const loop = args.loop === true;
    const seconds = Number(args.seconds) || (loop ? 10 : 2);
    const out = path.join(os.tmpdir(), 'roblox-ultimate-mcp', 'sounds', `${name}-${Date.now()}.mp3`);
    const made = await generateMirelo(key, prompt, seconds, loop, out, this.fetchImpl, this.pollMs);
    const base = { file: made.file, mireloJob: made.jobId, credits: made.credits };
    if (args.upload === false) return text({ ok: true, uploaded: false, ...base, next: 'Listen to the file; call again without upload: false to put it in the game.' });
    if (!this.host.hasOpenCloudKey?.() || !this.host.callTool) {
      return text({
        ok: true,
        uploaded: false,
        ...base,
        why: 'No Open Cloud API key, so the audio could not be uploaded to Roblox.',
        manualImport: 'Studio: Window > Asset Manager > Bulk Import > choose the file, copy its id, then sound_load_from_assetid {assetId, parentPath} (via call_tool).',
        automatic: 'Set ROBLOX_OPEN_CLOUD_API_KEY (asset:read + asset:write) and ROBLOX_CREATOR_USER_ID in the MCP config.',
      });
    }
    const upload = resultJson(await this.host.callTool('upload_asset', {
      filePath: made.file, assetType: 'Audio', displayName: name.slice(0, 50), description: prompt.slice(0, 1000),
    }));
    const soundId = String(upload?.response?.assetId ?? upload?.assetId ?? '');
    if (!/^\d+$/.test(soundId)) {
      return text({ ok: false, ...base, upload, problem: 'Upload did not return an asset id.', fix: 'Audio uploads need an ID-verified account (100 per month) and a key with asset:write.' });
    }
    if (!this.host.isStudioConnected()) {
      return text({ ok: true, ...base, soundId, problem: 'Studio is not connected, the Sound was not placed.', next: `sound_load_from_assetid {"assetId": "${soundId}"} once Studio is connected.` });
    }
    const placed = await runLuauJson(this.host, placeSoundLuau({
      name, soundId, parent: args.parent, volume: Number(args.volume ?? 0.5), loop, prompt,
    }), 'Place sound');
    return text({
      ok: placed?.ok !== false,
      ...base,
      soundId: `rbxassetid://${soundId}`,
      sound: placed,
      note: 'New audio can take a few minutes to pass moderation before it plays. check_assets {ids: [...]} tells when it loads.',
      play: placed?.positional ? 'Play it from a server script (sound:Play()) when the event happens.' : 'UI or global sound: play it from a LocalScript.',
    });
  }

  private requireStudio() {
    if (!this.host.isStudioConnected()) throw new Error('Roblox Studio is not connected (Plugins > MCP Server > Connect).');
  }

  private async plugin(args: Record<string, any>): Promise<ToolResult> {
    this.requireStudio();
    const select = (Array.isArray(args.select) ? args.select : args.parent ? [args.parent] : []).map((p: string) => splitPath(String(p)));
    const state = await runLuauJson(this.host, listSoundsLuau(select.length ? select : undefined), 'List sounds');
    this.known = new Set((state.sounds ?? []).map((s: any) => s.id));
    return text({
      ok: true,
      selected: state.selected,
      prompt: args.prompt ? String(args.prompt) : 'Write a prompt: source + material + action + space, e.g. "metal door slamming in a small concrete room"',
      steps: PLUGIN_STEPS,
      then: `make_sound {action: "collect"${args.parent ? `, parent: "${args.parent}"` : ''}${args.name ? `, name: "${args.name}"` : ''}} once the user says it is generated.`,
      soundsAlreadyThere: this.known.size,
    });
  }

  private async collect(args: Record<string, any>): Promise<ToolResult> {
    this.requireStudio();
    const state = await runLuauJson(this.host, listSoundsLuau(), 'List sounds');
    const sounds: any[] = state.sounds ?? [];
    const fresh = this.known ? sounds.filter((s) => !this.known!.has(s.id)) : sounds;
    if (!fresh.length) {
      return text({ ok: false, problem: 'No new Sound in SoundService yet.', fix: 'Generate it in the Mirelo panel (Plugins tab), then call collect again.' });
    }
    const listed = fresh.map(({ path: p, soundId, seconds }) => ({ path: p, soundId, seconds }));
    if (!args.parent) {
      return text({ ok: true, newSounds: listed, guessed: !this.known, next: 'Pass parent (a part for a 3D sound) to move them, or play them from SoundService.' });
    }
    const moved = await runLuauJson(this.host, moveSoundsLuau(fresh.map((s) => s.id), String(args.parent), args.name ? String(args.name) : undefined), 'Move sounds');
    if (moved?.ok) for (const s of fresh) this.known?.add(s.id);
    return text({ ...moved, newSounds: listed });
  }
}

