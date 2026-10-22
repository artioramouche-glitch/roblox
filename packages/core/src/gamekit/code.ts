/**
 * Coding tools tuned for small models and for tokens:
 *   - validateLuau / prepareLuau: auto-fix + compiler + beginner linter + Roblox API check,
 *     shared by write_script, edit_script and check_luau.
 *   - read_script: numbered lines, a range or only the lines around a word (not the whole
 *     script twice, like get_script_source).
 *   - edit_script: find/replace on the current source (no need to resend the whole script),
 *     tolerant to indentation, validated BEFORE writing; refuses edits that break the script.
 *   - code_outline: a one-line-per-script map of the game's code (purpose, functions,
 *     remotes, tags, requires) to understand a project without reading every script.
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { checkRobloxApi } from './api-check.js';
import { autofixLuau } from './autofix.js';
import { collectAudit } from './doctor.js';
import { install, runLuauJson, splitPath } from './installer.js';
import { contextFor, lintLuau, type LintIssue, type ScriptContext } from './luau-lint.js';
import { checkLuauSyntax } from './luau-syntax.js';
import { luauJson, text, type ToolResult } from './result.js';

export interface Problem {
  line?: number;
  problem: string;
  fix?: string;
  rule?: string;
}

export interface Validation {
  syntaxOk: boolean;
  available: boolean;
  errors: Problem[];
  warnings: Problem[];
}

const toProblem = (l: LintIssue): Problem => ({ line: l.line, problem: l.message, fix: l.fix, rule: l.rule });

export async function validateLuau(source: string, context: ScriptContext): Promise<Validation> {
  const syntax = await checkLuauSyntax(source, 'script');
  const lint = syntax.ok ? [...lintLuau(source, context), ...checkRobloxApi(source)] : [];
  return {
    syntaxOk: syntax.ok,
    available: syntax.available,
    errors: [
      ...syntax.errors.map((e) => ({ line: e.line, problem: `Syntax: ${e.message}`, fix: e.hint })),
      ...lint.filter((l) => l.severity === 'error').map(toProblem),
    ],
    warnings: lint.filter((l) => l.severity !== 'error').map(toProblem),
  };
}

/** Auto-fixes, then validates the fixed code. */
export async function prepareLuau(source: string, context: ScriptContext, autofix = true) {
  const fixed = autofix ? await autofixLuau(source) : { source, fixes: [] };
  const validation = await validateLuau(fixed.source, context);
  return { source: fixed.source, fixes: fixed.fixes, validation };
}

// --- Studio access ------------------------------------------------------------------------------

export interface ScriptInfo {
  ok: boolean;
  error?: string;
  className?: string;
  source?: string;
  path?: string;
  runContext?: string;
}

export async function readScript(host: GameKitHost, path: string): Promise<ScriptInfo> {
  return runLuauJson<ScriptInfo>(host, `
local HttpService = game:GetService("HttpService")
local segments = HttpService:JSONDecode(${luauJson(splitPath(path))})
local node = game
for i, name in segments do
	local child = node:FindFirstChild(name)
	if not child and i == 1 then
		local ok, service = pcall(function() return game:GetService(name) end)
		if ok then child = service end
	end
	if not child then
		local names = {}
		for _, c in node:GetChildren() do
			if #names < 30 then table.insert(names, c.Name) end
		end
		return HttpService:JSONEncode({ ok = false, error = "No \\"" .. name .. "\\" in " .. node:GetFullName() .. ". Children: " .. table.concat(names, ", ") })
	end
	node = child
end
if not node:IsA("LuaSourceContainer") then
	return HttpService:JSONEncode({ ok = false, error = node:GetFullName() .. " is a " .. node.ClassName .. ", not a script" })
end
local runContext = nil
pcall(function() runContext = (node :: any).RunContext.Name end)
return HttpService:JSONEncode({ ok = true, className = node.ClassName, source = (node :: any).Source, path = node:GetFullName(), runContext = runContext })`, 'Read script');
}

function numbered(lines: string[], from: number, to: number): string {
  const width = String(to).length;
  const out: string[] = [];
  for (let i = from; i <= to; i++) out.push(`${String(i).padStart(width)}| ${lines[i - 1] ?? ''}`);
  return out.join('\n');
}

// --- Tools -------------------------------------------------------------------------------------

export const CODE_TOOLS: ToolDef[] = [
  {
    name: 'read_script',
    category: 'read',
    tier: 'starter',
    description: 'Read a script with line numbers: whole (up to 200 lines), a range (from/to), or only the lines around a word (find). Cheaper than get_script_source.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'e.g. "ServerScriptService/GameKit/Shop"' },
        from: { type: 'number' },
        to: { type: 'number' },
        find: { type: 'string', description: 'Show only lines containing this text (+2 lines around)' },
      },
      required: ['path'],
    },
  },
  {
    name: 'edit_script',
    category: 'write',
    tier: 'starter',
    description: 'Change part of a script by find/replace (old lines copied from read_script; indentation may differ). Auto-fixed and checked before writing: never leaves a broken script.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        find: { type: 'string' },
        replace: { type: 'string', description: '"" deletes' },
        all: { type: 'boolean', description: 'Every occurrence' },
        edits: { type: 'array', items: { type: 'object' }, description: 'Several [{find, replace}]' },
        force: { type: 'boolean' },
      },
      required: ['path'],
    },
  },
  {
    name: 'code_outline',
    category: 'read',
    tier: 'starter',
    description: 'Map of the game\'s code in a few lines: every script with its purpose, functions, remotes, tags and requires. Read it before changing code you did not write.',
    inputSchema: {
      type: 'object',
      properties: {
        includeGameKit: { type: 'boolean', description: 'Also list GameKit scripts' },
        filter: { type: 'string', description: 'Only scripts whose path contains this' },
      },
    },
  },
];

export async function handleReadScript(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  const info = await readScript(host, String(args.path ?? ''));
  if (!info.ok) throw new Error(info.error ?? 'Script not found');
  const lines = (info.source ?? '').split('\n');
  const total = lines.length;
  const head = `${info.path} (${info.className}, ${total} lines)`;
  if (args.find) {
    const needle = String(args.find).toLowerCase();
    const hits = lines.map((l, i) => (l.toLowerCase().includes(needle) ? i + 1 : 0)).filter(Boolean);
    if (!hits.length) return text(`${head}: "${args.find}" not found.`);
    const ranges: Array<[number, number]> = [];
    for (const h of hits) {
      const from = Math.max(1, h - 2);
      const to = Math.min(total, h + 2);
      const last = ranges[ranges.length - 1];
      if (last && from <= last[1] + 1) last[1] = Math.max(last[1], to);
      else ranges.push([from, to]);
    }
    const shown = ranges.slice(0, 12).map(([a, b]) => numbered(lines, a, b)).join('\n...\n');
    return text(`${head}, ${hits.length} match(es):\n${shown}${ranges.length > 12 ? '\n... more matches: narrow the search' : ''}`);
  }
  const from = Math.max(1, Number(args.from) || 1);
  const limit = 200;
  const to = Math.min(total, Number(args.to) || Math.min(total, from + limit - 1));
  const more = to < total ? `\n... ${total - to} more lines: read_script { path, from: ${to + 1} }` : '';
  return text(`${head}${from > 1 || to < total ? `, lines ${from}-${to}` : ''}:\n${numbered(lines, from, to)}${more}`);
}

interface EditSpec {
  find: string;
  replace: string;
  all?: boolean;
}

/** Applies one find/replace; falls back to matching lines while ignoring indentation. */
export function applyEdit(source: string, edit: EditSpec): { source: string; line: number; count: number; loose?: boolean } | { error: string } {
  const find = edit.find.replace(/\r\n/g, '\n');
  const replace = (edit.replace ?? '').replace(/\r\n/g, '\n');
  if (!find) return { error: 'find is empty' };
  const lineAt = (index: number) => source.slice(0, index).split('\n').length;
  const positions: number[] = [];
  for (let i = source.indexOf(find); i >= 0; i = source.indexOf(find, i + find.length)) positions.push(i);
  if (positions.length > 1 && !edit.all) {
    return { error: `"${find.split('\n')[0].trim().slice(0, 60)}" appears ${positions.length} times (lines ${positions.map(lineAt).join(', ')}). Include more lines in find, or pass all: true.` };
  }
  if (positions.length) {
    // Multi-line replacements take the indentation of the line they land on.
    let out = '';
    let last = 0;
    for (const at of positions) {
      const lineStart = source.lastIndexOf('\n', at - 1) + 1;
      const prefix = source.slice(lineStart, at);
      const indent = /^\s*$/.test(prefix) ? prefix : '';
      const indented = indent
        ? replace.split('\n').map((l, i) => (i === 0 || !l.trim() || l.startsWith(indent) ? l : indent + l)).join('\n')
        : replace;
      out += source.slice(last, at) + indented;
      last = at + find.length;
    }
    return { source: out + source.slice(last), line: lineAt(positions[0]), count: positions.length };
  }
  // Same lines with different indentation/trailing spaces (models often re-indent).
  const srcLines = source.split('\n');
  const findLines = find.split('\n').map((l) => l.trim()).filter((l, i, arr) => l !== '' || (i > 0 && i < arr.length - 1));
  if (!findLines.length) return { error: 'find is empty' };
  const matches: number[] = [];
  for (let i = 0; i + findLines.length <= srcLines.length; i++) {
    let ok = true;
    for (let k = 0; k < findLines.length && ok; k++) ok = srcLines[i + k].trim() === findLines[k];
    if (ok) matches.push(i);
  }
  if (matches.length === 1 || (matches.length > 1 && edit.all)) {
    const findIndent = /^\s*/.exec(find.split('\n').find((l) => l.trim()) ?? '')?.[0] ?? '';
    let out = srcLines;
    for (const start of [...matches].reverse()) {
      const srcIndent = /^\s*/.exec(out[start])?.[0] ?? '';
      const newLines = replace === '' ? [] : replace.split('\n').map((l) => {
        if (!l.trim()) return l;
        return l.startsWith(findIndent) ? srcIndent + l.slice(findIndent.length) : srcIndent + l.trimStart();
      });
      out = [...out.slice(0, start), ...newLines, ...out.slice(start + findLines.length)];
    }
    return { source: out.join('\n'), line: matches[0] + 1, count: matches.length, loose: true };
  }
  if (matches.length > 1) return { error: `Those lines appear ${matches.length} times (lines ${matches.map((m) => m + 1).join(', ')}). Include more lines, or pass all: true.` };
  // Not found: point at the most similar lines.
  const first = findLines[0].toLowerCase();
  const words = first.split(/\W+/).filter((w) => w.length > 2);
  const scored = srcLines
    .map((l, i) => ({ i, score: words.filter((w) => l.toLowerCase().includes(w)).length }))
    .filter((s) => s.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, 3);
  const near = scored.length ? ` Closest lines: ${scored.map((s) => `${s.i + 1}| ${srcLines[s.i].trim().slice(0, 80)}`).join(' / ')}` : '';
  return { error: `find text not found in the script.${near} Copy it exactly from read_script.` };
}

export async function handleEditScript(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  const path = String(args.path ?? '');
  const edits: EditSpec[] = Array.isArray(args.edits) && args.edits.length
    ? args.edits.map((e: any) => ({ find: String(e.find ?? ''), replace: String(e.replace ?? ''), all: !!e.all }))
    : [{ find: String(args.find ?? ''), replace: String(args.replace ?? ''), all: !!args.all }];
  const info = await readScript(host, path);
  if (!info.ok) throw new Error(info.error ?? 'Script not found');
  const original = info.source ?? '';
  let source = original;
  const applied: string[] = [];
  const touched: number[] = [];
  for (const [n, edit] of edits.entries()) {
    const result = applyEdit(source, edit);
    if ('error' in result) {
      return text({ written: false, edit: edits.length > 1 ? n + 1 : undefined, problem: result.error, next: `read_script { path: "${path}", find: "<a word from the line>" } to copy the exact text.` });
    }
    source = result.source;
    touched.push(result.line);
    applied.push(`line ${result.line}${result.count > 1 ? ` (${result.count}x)` : ''}${result.loose ? ' (matched ignoring indentation)' : ''}`);
  }
  const segments = splitPath(path);
  const context = contextFor(info.className ?? 'Script', segments.join('.'), info.runContext);
  const prepared = await prepareLuau(source, context);
  // Only NEW problems block the edit: an old warning elsewhere in the script must not.
  const before = await validateLuau(original, context);
  const known = new Set([...before.errors, ...before.warnings].map((p) => `${p.rule}|${p.problem}`));
  const newErrors = prepared.validation.errors.filter((e) => !known.has(`${e.rule}|${e.problem}`));
  const newWarnings = prepared.validation.warnings.filter((w) => !known.has(`${w.rule}|${w.problem}`));
  if (!prepared.validation.syntaxOk || (newErrors.length && !args.force)) {
    return text({
      written: false,
      reason: prepared.validation.syntaxOk ? 'The edit introduces mistakes (fix them, or force: true if sure).' : 'The script would not compile after this edit. Nothing was changed.',
      errors: newErrors.slice(0, 8),
      autofixed: prepared.fixes,
    });
  }
  const name = segments[segments.length - 1];
  const report = await install(host, {
    label: `GameKit: edit ${segments.join('/')}`,
    items: [{ parent: segments.slice(0, -1), mode: 'merge', node: { name, className: info.className ?? 'Script', source: prepared.source } }],
  });
  const lines = prepared.source.split('\n');
  const at = Math.min(...touched);
  const preview = numbered(lines, Math.max(1, at - 1), Math.min(lines.length, at + 4));
  return text({
    written: report.ok,
    error: report.error,
    path: segments.join('/'),
    applied,
    autofixed: prepared.fixes,
    warnings: newWarnings.slice(0, 5),
    preview,
    next: 'test_game to try it.',
  });
}

// --- code_outline --------------------------------------------------------------------------------

const uniq = (list: string[], max = 8) => [...new Set(list)].slice(0, max);

function matchAll(source: string, re: RegExp, group = 1): string[] {
  const out: string[] = [];
  for (const m of source.matchAll(re)) if (m[group]) out.push(m[group]);
  return out;
}

export function outlineScript(path: string, className: string, source: string): string {
  const lines = source.split('\n');
  const purpose = lines.slice(0, 6).filter((l) => /^\s*--/.test(l) && !/^\s*--!/.test(l)).map((l) => l.replace(/^\s*--+\s?/, '').trim()).filter(Boolean)[0];
  const functions = uniq(matchAll(source, /^\s*(?:local\s+)?function\s+([\w.:]+)/gm), 10);
  const remotes = uniq([
    ...matchAll(source, /Net\.(?:on|send|fire|fireAll|event|listen)\(\s*["'](\w+)["']/g),
    ...matchAll(source, /:WaitForChild\(\s*["'](\w*(?:Event|Remote|Function)\w*)["']/g),
  ]);
  const services = uniq(matchAll(source, /GetService\(\s*["'](\w+)["']/g), 6);
  const requires = uniq(matchAll(source, /require\(([^)]+)\)/g).map((r) => r.split(/[.:"'()]+/).filter(Boolean).pop() ?? r), 6);
  const tags = uniq([...matchAll(source, /GetTagged\(\s*["'](\w+)["']/g), ...matchAll(source, /onTag\(\s*["'](\w+)["']/g)]);
  const attrs = uniq(matchAll(source, /[GS]etAttribute\(\s*["'](\w+)["']/g), 6);
  const parts = [
    `${path} (${className}, ${lines.length} lines)`,
    purpose ? `"${purpose.slice(0, 90)}"` : '',
    functions.length ? `fn: ${functions.join(', ')}` : '',
    remotes.length ? `remotes: ${remotes.join(', ')}` : '',
    tags.length ? `tags: ${tags.join(', ')}` : '',
    attrs.length ? `attrs: ${attrs.join(', ')}` : '',
    requires.length ? `requires: ${requires.join(', ')}` : '',
    services.length ? `services: ${services.join(', ')}` : '',
  ].filter(Boolean);
  return parts.join(' | ');
}

export async function handleCodeOutline(host: GameKitHost, args: Record<string, any>): Promise<ToolResult> {
  const audit = await collectAudit(host);
  const filter = args.filter ? String(args.filter).toLowerCase() : '';
  const out: string[] = [];
  let kit = 0;
  for (const script of audit.scripts ?? []) {
    const path = String(script.path).replace(/^game\./, '').replace(/\./g, '/');
    const isKit = /\/GameKit(\/|$)|__GameKit/.test(path);
    if (isKit) kit++;
    if (isKit && !args.includeGameKit) continue;
    if (filter && !path.toLowerCase().includes(filter)) continue;
    out.push(outlineScript(path, script.className, script.source ?? ''));
  }
  const header = `${out.length} script(s)${kit && !args.includeGameKit ? ` + ${kit} GameKit scripts (documented: roblox_guide gamekit-api; includeGameKit to list)` : ''}.`;
  return text(`${header}\n${out.join('\n') || '(no custom scripts yet)'}\nRead one: read_script { path, find }. Change it: edit_script.`);
}
