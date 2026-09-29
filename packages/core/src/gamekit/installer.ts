/**
 * Install specs: a JSON description of instances to create in Studio, applied by
 * gamekit/runtime/Applier.luau in ONE undoable step (Ctrl+Z reverts a whole install).
 */

import { LUAU_SOURCES } from './generated/luau-sources.js';
import { longString } from './luau-table.js';
import type { Encoded } from './values.js';

export interface InstanceNode {
  name: string;
  className: string;
  props?: Record<string, Encoded>;
  attrs?: Record<string, Encoded>;
  tags?: string[];
  source?: string;
  children?: InstanceNode[];
}

export type PlaceMode = 'replace' | 'keep' | 'merge';

export interface Placement {
  /** "Workspace/GameKit", "game.ServerScriptService" or ["StarterPlayer","StarterPlayerScripts"]. */
  parent: string | string[];
  mode?: PlaceMode;
  node: InstanceNode;
}

export interface InstallSpec {
  label: string;
  items: Placement[];
  /** Paths destroyed before installing (e.g. an older version of the same world piece). */
  deletes?: string[];
}

export interface InstallReport {
  ok: boolean;
  error?: string;
  created: number;
  replaced: number;
  kept: number;
  merged: number;
  deleted: number;
  warnings: string[];
  roots: string[];
}

/** Anything that can run Luau in Studio's edit DataModel and hand back the result. */
export interface LuauRunner {
  runLuau(code: string): Promise<{ success: boolean; returnValue?: string; output?: string[]; error?: string }>;
}

/** Luau encodes an empty table as {} or [] -- treat anything that is not an array as empty. */
export function asArray<T = any>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

export function splitPath(path: string | string[]): string[] {
  if (Array.isArray(path)) return path;
  return path.replace(/^game[./]/, '').split(/[./\\]/).filter(Boolean);
}

export function buildInstallerLuau(spec: InstallSpec): string {
  const applier = LUAU_SOURCES['runtime/Applier.luau'];
  const payload = JSON.stringify({
    label: spec.label,
    deletes: (spec.deletes ?? []).map(splitPath),
    items: spec.items.map((item) => ({ ...item, parent: splitPath(item.parent) })),
  });
  const marker = 'local PAYLOAD = "{}" -- @payload';
  if (!applier.includes(marker)) throw new Error('Applier runtime is missing its payload marker');
  return applier.replace(marker, () => `local PAYLOAD = ${longString(payload)}`);
}

/** Runs Luau that returns a JSON string and parses it. Throws with the Luau error on failure. */
export async function runLuauJson<T = any>(runner: LuauRunner, code: string, what: string): Promise<T> {
  const reply = await runner.runLuau(code);
  if (!reply.success) throw new Error(`${what} failed in Studio: ${reply.error ?? 'unknown error'}`);
  if (!reply.returnValue) throw new Error(`${what} returned nothing. Output: ${(reply.output ?? []).join(' | ') || '(none)'}`);
  try {
    return JSON.parse(reply.returnValue) as T;
  } catch {
    throw new Error(`${what} returned something that is not JSON: ${reply.returnValue.slice(0, 300)}`);
  }
}

export async function install(runner: LuauRunner, spec: InstallSpec): Promise<InstallReport> {
  const report = await runLuauJson<InstallReport>(runner, buildInstallerLuau(spec), spec.label);
  report.warnings = asArray<string>(report.warnings);
  report.roots = asArray<string>(report.roots);
  return report;
}

/** Maps a gamekit/ file to the Studio location it is installed to. */
export function scriptTarget(file: string): { parent: string[]; name: string; className: string } | null {
  const parts = file.split('/');
  const base = parts[parts.length - 1].replace(/\.luau$/, '');
  if (parts[0] === 'runtime') return null;
  if (base.endsWith('.server')) return { parent: ['ServerScriptService', 'GameKit'], name: base.slice(0, -7), className: 'Script' };
  if (base.endsWith('.client')) {
    const name = base.slice(0, -7);
    return {
      parent: ['StarterPlayer', 'StarterPlayerScripts', 'GameKit'],
      // Client scripts get a "Client" suffix so they never look like the server one.
      name: name.endsWith('Client') || ['UIBinder', 'HUD', 'Pads', 'Movement'].includes(name) ? name : `${name}Client`,
      className: 'LocalScript',
    };
  }
  if (parts[0] === 'shared' || base.endsWith('.shared')) {
    return { parent: ['ReplicatedStorage', 'GameKit'], name: base.replace(/\.shared$/, ''), className: 'ModuleScript' };
  }
  return { parent: ['ServerScriptService', 'GameKit'], name: base, className: 'ModuleScript' };
}

/** Placement for one library file, with its source embedded. */
export function scriptPlacement(file: string, mode: PlaceMode = 'replace'): Placement {
  const target = scriptTarget(file);
  const source = LUAU_SOURCES[file];
  if (!target || source === undefined) throw new Error(`Unknown GameKit file: ${file}`);
  return { parent: target.parent, mode, node: { name: target.name, className: target.className, source } };
}
