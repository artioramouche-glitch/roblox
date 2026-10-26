/**
 * What the AI is doing, shown in the Studio plugin's AI panel.
 *
 * Every GameKit tool call runs inside an async context carrying a short label
 * ("create_game obby"). The Luau it sends to Studio gets that label as a trailing comment
 * (a trailing line keeps error line numbers unchanged); the plugin lists it in its
 * activity feed and records "write" calls as one undo step named "MCP: AI <label>", which
 * the panel's "Undo last AI action" button reverts.
 */

import { AsyncLocalStorage } from 'node:async_hooks';

export interface Activity {
  label: string;
  write: boolean;
}

export const activityContext = new AsyncLocalStorage<Activity>();

const DETAIL_KEYS = ['template', 'system', 'kind', 'path', 'recipe', 'action', 'preset', 'theme', 'name', 'tool', 'section'];

/** "create_game obby", "write_script ServerScriptService/Shop"... */
export function activityLabel(name: string, args: Record<string, any> = {}): string {
  const detail = DETAIL_KEYS.map((key) => args[key]).find((v) => typeof v === 'string' && v.trim());
  const label = detail ? `${name} ${detail}` : name;
  return label.replace(/[\r\n\]]/g, ' ').slice(0, 80);
}

/** Adds the current activity as a trailing comment the plugin reads. */
export function tagLuau(code: string, activity: Activity | undefined = activityContext.getStore()): string {
  if (!activity) return code;
  return `${code}\n--@ai ${activity.write ? 'write' : 'read'} ${activity.label}`;
}
