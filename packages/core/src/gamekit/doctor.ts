/**
 * check_game: a static audit of the open place. Collects every script from Studio
 * (runtime/Audit.luau), then checks syntax (real Luau compiler), beginner mistakes
 * and where each script lives, plus place-level problems.
 */

import { LUAU_SOURCES } from './generated/luau-sources.js';
import { asArray, runLuauJson, type LuauRunner } from './installer.js';
import { contextFor, lintLuau, type LintIssue } from './luau-lint.js';
import { checkRobloxApi } from './api-check.js';
import { checkLuauSyntax } from './luau-syntax.js';

export interface AuditScript {
  path: string;
  className: string;
  enabled: boolean;
  runContext?: string;
  length: number;
  source?: string;
}

export interface Audit {
  scripts: AuditScript[];
  facts: Record<string, any>;
  tags: Record<string, number>;
  loose: string[];
  checkpointStages: number[];
  truncatedScripts: number;
}

export interface Finding {
  severity: 'error' | 'warning' | 'info';
  where: string;
  line?: number;
  problem: string;
  fix?: string;
  /** The lines around the problem, e.g. "11| local x = nil\n12| x.Value = 1". */
  code?: string;
}

const CLIENT_CONTAINERS = /^(StarterPlayer\.StarterPlayerScripts|StarterPlayer\.StarterCharacterScripts|StarterGui|StarterPack|ReplicatedFirst)\b/;
const SERVER_CONTAINERS = /^(ServerScriptService|Workspace)\b/;

/** Where a script lives vs what it is. */
function placementFinding(s: AuditScript): Finding | null {
  const path = s.path.replace(/^game\./, '');
  if (s.className === 'LocalScript' && !CLIENT_CONTAINERS.test(path)) {
    if (/^Workspace\b/.test(path) && /\bTool\b|Character/i.test(path)) return null;
    return {
      severity: 'error', where: s.path,
      problem: 'This LocalScript will never run here.',
      fix: 'Move it to StarterPlayer.StarterPlayerScripts (or StarterGui for UI scripts), or change it to a Script if it is server logic.',
    };
  }
  if (s.className === 'Script' && s.runContext !== 'Client' && s.runContext !== 'Server' && !SERVER_CONTAINERS.test(path)) {
    if (/^ServerStorage|^ReplicatedStorage/.test(path)) {
      return { severity: 'info', where: s.path, problem: 'Scripts in storage do not run until cloned into Workspace/ServerScriptService (fine for templates).' };
    }
    return {
      severity: 'error', where: s.path,
      problem: 'This server Script will never run here (Scripts only run in ServerScriptService or Workspace).',
      fix: 'Move it to ServerScriptService, or turn it into a LocalScript if it controls the player/UI.',
    };
  }
  return null;
}

/** The offending line (and one before) so the fix can be made without reading the script. */
export function codeAt(source: string | undefined, line: number | undefined): string | undefined {
  if (!source || !line) return undefined;
  const lines = source.split('\n');
  const from = Math.max(1, line - 1);
  const to = Math.min(lines.length, line + 1);
  const out: string[] = [];
  for (let i = from; i <= to; i++) out.push(`${i}| ${lines[i - 1].trim().slice(0, 120)}`);
  return out.join('\n');
}

function lintFindings(s: AuditScript, issues: LintIssue[]): Finding[] {
  return issues.map((i) => ({
    severity: i.severity, where: s.path, line: i.line, problem: i.message, fix: i.fix,
    code: i.severity === 'error' ? codeAt(s.source, i.line) : undefined,
  }));
}

export async function collectAudit(runner: LuauRunner): Promise<Audit> {
  const audit = await runLuauJson<Audit>(runner, LUAU_SOURCES['runtime/Audit.luau'], 'Game audit');
  audit.scripts = asArray(audit.scripts);
  audit.loose = asArray(audit.loose);
  audit.checkpointStages = asArray(audit.checkpointStages);
  audit.tags = audit.tags && !Array.isArray(audit.tags) ? audit.tags : {};
  audit.facts = audit.facts && !Array.isArray(audit.facts) ? audit.facts : {};
  audit.facts.gameKitServerScripts = asArray(audit.facts.gameKitServerScripts);
  audit.facts.gameKitConfigs = asArray(audit.facts.gameKitConfigs);
  return audit;
}

export async function analyseAudit(audit: Audit, options: { includeGameKit?: boolean } = {}): Promise<{ findings: Finding[]; summary: Record<string, any> }> {
  const findings: Finding[] = [];
  let syntaxErrors = 0;
  for (const s of audit.scripts) {
    const isKit = /\.GameKit\./.test(s.path) && !/\.GameKit\.Config\./.test(s.path);
    const place = placementFinding(s);
    if (place) findings.push(place);
    if (!s.enabled && !isKit) findings.push({ severity: 'info', where: s.path, problem: 'Script is disabled (Enabled = false).' });
    if (s.source === undefined) continue;
    const syntax = await checkLuauSyntax(s.source, s.path);
    if (!syntax.ok) {
      syntaxErrors++;
      for (const e of syntax.errors) {
        findings.push({ severity: 'error', where: s.path, line: e.line, problem: `Syntax error: ${e.message}`, fix: e.hint });
      }
      continue;
    }
    if (isKit && !options.includeGameKit) continue;
    const ctx = contextFor(s.className, s.path.replace(/^game\./, ''), s.runContext);
    findings.push(...lintFindings(s, [...lintLuau(s.source, ctx), ...checkRobloxApi(s.source)]));
  }

  const f = audit.facts ?? {};
  const tags = audit.tags ?? {};
  if (!f.spawnLocations) {
    findings.push({ severity: 'warning', where: 'Workspace', problem: 'No SpawnLocation: players spawn at the world center, maybe inside something.', fix: 'build_world piece "spawn" (or use a template).' });
  }
  if (f.unanchoredLooseParts > 0) {
    findings.push({
      severity: f.unanchoredLooseParts > 20 ? 'warning' : 'info', where: 'Workspace',
      problem: `${f.unanchoredLooseParts} unanchored part(s) will fall or be pushed when the game starts${audit.loose?.length ? ` (e.g. ${audit.loose.slice(0, 5).join(', ')})` : ''}.`,
      fix: 'Set Anchored = true on parts that should stay in place (mass_set_property Anchored true).',
    });
  }
  if (f.parts > 20000) findings.push({ severity: 'warning', where: 'Workspace', problem: `${f.parts} parts: heavy for mobile.`, fix: 'Remove hidden/unused parts, merge details, or enable StreamingEnabled.' });
  if (f.leftoverTestRunner) findings.push({ severity: 'warning', where: 'ServerScriptService.__GameKitTestRunner', problem: 'Leftover test runner from an interrupted test_game.', fix: 'Delete it (delete_object) or run test_game again (it cleans up).' });
  if (f.characterAutoLoads === false) findings.push({ severity: 'info', where: 'Players', problem: 'CharacterAutoLoads is off: players only spawn if a script calls LoadCharacter.' });

  const stages = audit.checkpointStages ?? [];
  if (stages.length) {
    const missing: number[] = [];
    for (let s = 1; s <= stages[stages.length - 1]; s++) if (!stages.includes(s)) missing.push(s);
    if (missing.length) findings.push({ severity: 'warning', where: 'Checkpoints', problem: `Checkpoint stages missing: ${missing.join(', ')}. Players cannot progress past a gap when RequireOrder is on.`, fix: 'Renumber the "Stage" attributes 1, 2, 3... without gaps.' });
    const dupes = stages.filter((s, i) => stages.indexOf(s) !== i);
    if (dupes.length) findings.push({ severity: 'warning', where: 'Checkpoints', problem: `Duplicate checkpoint stages: ${[...new Set(dupes)].join(', ')}.` });
  }
  const installed: string[] = f.gameKitServerScripts ?? [];
  const has = (name: string) => installed.includes(name);
  if (tags.Checkpoint && !has('Checkpoints')) findings.push({ severity: 'warning', where: 'GameKit', problem: 'Checkpoint parts exist but the checkpoints system is not installed.', fix: 'add_system checkpoints' });
  if ((tags.Coin || tags.Collectible) && !has('Collectibles')) findings.push({ severity: 'warning', where: 'GameKit', problem: 'Coins exist but the collectibles system is not installed.', fix: 'add_system collectibles' });
  if ((tags.KillPart || tags.DamagePart) && !has('Hazards')) findings.push({ severity: 'warning', where: 'GameKit', problem: 'Kill/damage parts exist but the hazards system is not installed.', fix: 'add_system hazards' });
  if ((tags.MovingPlatform || tags.Spinner || tags.Conveyor || tags.Disappearing) && !has('Movers')) findings.push({ severity: 'warning', where: 'GameKit', problem: 'Moving obstacles exist but the movers system is not installed.', fix: 'add_system movers' });
  if (tags.EnemySpawner && !has('Enemies')) findings.push({ severity: 'warning', where: 'GameKit', problem: 'Enemy spawners exist but the enemies system is not installed.', fix: 'add_system enemies' });
  if (tags.RoundSpawn && !has('Rounds')) findings.push({ severity: 'info', where: 'GameKit', problem: 'RoundSpawn parts exist but the rounds system is not installed.', fix: 'add_system rounds' });
  if (has('Rounds') && !tags.RoundSpawn) findings.push({ severity: 'warning', where: 'GameKit', problem: 'Rounds is installed but no part is tagged "RoundSpawn".', fix: 'build_world arena (or tag spawn parts "RoundSpawn").' });
  if (has('Checkpoints') && !tags.Checkpoint) findings.push({ severity: 'warning', where: 'GameKit', problem: 'Checkpoints is installed but no part is tagged "Checkpoint".', fix: 'build_world obby_course.' });
  if (has('Tycoon') && !tags.TycoonPlot) findings.push({ severity: 'warning', where: 'GameKit', problem: 'Tycoon is installed but there is no plot.', fix: 'build_world tycoon_plots.' });
  if (has('Objectives') && !tags.Key) findings.push({ severity: 'warning', where: 'GameKit', problem: 'Objectives is installed but there are no keys.', fix: 'build_world maze (or piece "key").' });

  const order = { error: 0, warning: 1, info: 2 };
  findings.sort((a, b) => order[a.severity] - order[b.severity]);
  const count = (s: string) => findings.filter((x) => x.severity === s).length;
  return {
    findings,
    summary: {
      verdict: count('error') ? 'FIX ERRORS' : count('warning') ? 'OK WITH WARNINGS' : 'CLEAN',
      errors: count('error'),
      warnings: count('warning'),
      infos: count('info'),
      scripts: audit.scripts.length,
      syntaxErrors,
      truncatedScripts: audit.truncatedScripts,
      place: f,
      tags,
    },
  };
}
