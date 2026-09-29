/**
 * game_notes: the project's memory, stored IN the place (ServerStorage/GameKitNotes) so a new
 * conversation, or another AI, picks up where the last one stopped with one call instead of
 * re-reading scripts. Sections: idea, decisions, todo, done, notes, and an automatic history
 * of code changes (written by the server after write_script, edit_script, code_recipe...).
 * roblox_start_here shows a short summary automatically.
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { runLuauJson } from './installer.js';
import { luauJson, text, type ToolResult } from './result.js';

export const NOTE_SECTIONS = ['idea', 'decisions', 'todo', 'done', 'notes', 'history'] as const;
export type NoteSection = (typeof NOTE_SECTIONS)[number];

const MAX_LINES: Record<NoteSection, number> = { idea: 20, decisions: 40, todo: 60, done: 80, notes: 60, history: 40 };

export const NOTES_TOOLS: ToolDef[] = [
  {
    name: 'game_notes',
    category: 'write',
    tier: 'starter',
    description: 'Project memory saved in the place: idea, decisions, todo, done, notes (+ automatic history of code changes). Read it when you start; add to it as you go so the next session resumes in one call.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['read', 'add', 'set', 'done', 'remove', 'clear'], description: 'read (default), add a line, set a section, done (move a todo to done), remove a line, clear a section' },
        section: { type: 'string', enum: [...NOTE_SECTIONS] },
        text: { type: 'string' },
      },
    },
  },
];

/** Luau that reads/updates the notes and returns them all. `op` is null to only read. */
function notesLuau(op: Record<string, unknown> | null): string {
  return `
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local op = HttpService:JSONDecode(${luauJson(op)})
local MAX = HttpService:JSONDecode(${luauJson(MAX_LINES)})
local root = ServerStorage:FindFirstChild("GameKitNotes")
local function lines(name)
	local value = root and root:FindFirstChild(name)
	local out = {}
	if value and value:IsA("StringValue") and value.Value ~= "" then
		for line in string.gmatch(value.Value, "[^\\n]+") do table.insert(out, line) end
	end
	return out
end
local function save(name, list)
	if not root then
		root = Instance.new("Folder")
		root.Name = "GameKitNotes"
		root.Parent = ServerStorage
	end
	local value = root:FindFirstChild(name)
	if not value then
		value = Instance.new("StringValue")
		value.Name = name
		value.Parent = root
	end
	while #list > (MAX[name] or 60) do table.remove(list, 1) end
	value.Value = table.concat(list, "\\n")
end
local result = { ok = true }
if op then
	local name = op.section
	local list = lines(name)
	local text = op.text or ""
	if op.action == "add" then
		for line in string.gmatch(text, "[^\\n]+") do table.insert(list, line) end
		save(name, list)
	elseif op.action == "set" then
		list = {}
		for line in string.gmatch(text, "[^\\n]+") do table.insert(list, line) end
		save(name, list)
	elseif op.action == "clear" then
		save(name, {})
	elseif op.action == "remove" or op.action == "done" then
		local needle = string.lower(text)
		local found = nil
		for i, line in list do
			if string.find(string.lower(line), needle, 1, true) then found = i; break end
		end
		if found then
			local line = table.remove(list, found)
			save(name, list)
			if op.action == "done" then
				local done = lines("done")
				table.insert(done, line)
				save("done", done)
			end
			result.moved = line
		elseif op.action == "done" then
			local done = lines("done")
			table.insert(done, text)
			save("done", done)
		else
			result.ok = false
			result.error = "No line containing \\"" .. text .. "\\" in " .. name
		end
	end
end
result.notes = {}
for name in MAX do result.notes[name] = lines(name) end
return HttpService:JSONEncode(result)`;
}

const asList = (v: unknown): string[] => (Array.isArray(v) ? v.map(String) : []);

export interface NotesState {
  idea: string[];
  decisions: string[];
  todo: string[];
  done: string[];
  notes: string[];
  history: string[];
}

function normalise(raw: any): NotesState {
  const n = raw?.notes ?? {};
  return { idea: asList(n.idea), decisions: asList(n.decisions), todo: asList(n.todo), done: asList(n.done), notes: asList(n.notes), history: asList(n.history) };
}

/** Compact text: what a new session needs, nothing more. */
export function formatNotes(notes: NotesState, full = false): string {
  const section = (title: string, list: string[], keep: number) => {
    if (!list.length) return '';
    const shown = list.slice(-keep);
    return `${title} (${list.length}):\n${shown.map((l) => `- ${l}`).join('\n')}${list.length > shown.length ? `\n  (+${list.length - shown.length} older)` : ''}`;
  };
  const parts = [
    notes.idea.length ? `IDEA: ${notes.idea.join(' ')}` : 'IDEA: (not written yet: game_notes {action: "set", section: "idea", text})',
    section('TODO', notes.todo, full ? 60 : 12),
    section('DECISIONS', notes.decisions, full ? 40 : 8),
    section('DONE', notes.done, full ? 80 : 8),
    section('NOTES', notes.notes, full ? 60 : 6),
    section('HISTORY', notes.history, full ? 40 : 6),
  ].filter(Boolean);
  return parts.join('\n');
}

export async function readNotes(host: GameKitHost): Promise<NotesState> {
  return normalise(await runLuauJson(host, notesLuau(null), 'Notes'));
}

/** Appends a history line (best effort: never fails the tool that triggered it). */
export async function recordHistory(host: GameKitHost, line: string): Promise<void> {
  if (/^(0|false|no|off)$/i.test(process.env.ROBLOX_MCP_HISTORY ?? '')) return;
  const stamp = new Date().toISOString().slice(0, 16).replace('T', ' ');
  try {
    await runLuauJson(host, notesLuau({ action: 'add', section: 'history', text: `${stamp} ${line}` }), 'Notes');
  } catch {
    // history is a convenience
  }
}

export async function handleNotes(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  const action = String(args.action ?? 'read');
  if (action === 'read') return text(formatNotes(await readNotes(host), true));
  const section = String(args.section ?? (action === 'done' ? 'todo' : 'notes')) as NoteSection;
  if (!(NOTE_SECTIONS as readonly string[]).includes(section)) throw new Error(`section must be one of: ${NOTE_SECTIONS.join(', ')}`);
  if (action !== 'clear' && !String(args.text ?? '').trim()) throw new Error(`game_notes ${action} needs "text"`);
  const raw = await runLuauJson<any>(host, notesLuau({ action, section, text: String(args.text ?? '').slice(0, 2000) }), 'Notes');
  if (raw?.ok === false) return text({ ok: false, error: raw.error });
  const notes = normalise(raw);
  return text({ ok: true, moved: raw?.moved, [section]: notes[section].slice(-10), todoLeft: notes.todo.length });
}
