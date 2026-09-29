/**
 * Turns JSON config values into a readable Luau ModuleScript, so the AI (or a human)
 * can open ReplicatedStorage.GameKit.Config.<System> in Studio and tweak numbers.
 */

const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
const RESERVED = new Set([
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in',
  'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while', 'continue',
]);

function luauString(s: string): string {
  return JSON.stringify(s).replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) => `\\u{${hex}}`);
}

function key(k: string): string {
  if (/^-?\d+$/.test(k)) return `[${k}]`;
  return IDENT.test(k) && !RESERVED.has(k) ? k : `[${luauString(k)}]`;
}

function isTagged(value: any): string | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const keys = Object.keys(value);
  return keys.length === 1 && keys[0].startsWith('$') ? keys[0] : null;
}

export function toLuau(value: unknown, indent = 0): string {
  const pad = '\t'.repeat(indent);
  const inner = '\t'.repeat(indent + 1);
  if (value === null || value === undefined) return 'nil';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : '0';
  if (typeof value === 'string') return luauString(value);
  const tag = isTagged(value);
  if (tag) {
    const v = (value as any)[tag];
    switch (tag) {
      case '$c3': return `Color3.fromRGB(${v.join(', ')})`;
      case '$hex': return `Color3.fromHex(${luauString(v)})`;
      case '$v3': return `Vector3.new(${v.join(', ')})`;
      case '$v2': return `Vector2.new(${v.join(', ')})`;
      case '$ud2': return `UDim2.new(${v.join(', ')})`;
      case '$enum': return v.startsWith('Enum.') ? v : `Enum.${v}`;
    }
  }
  if (Array.isArray(value)) {
    if (value.length === 0) return '{}';
    const simple = value.every((v) => typeof v !== 'object' || v === null);
    if (simple && value.length <= 8) return `{ ${value.map((v) => toLuau(v)).join(', ')} }`;
    return `{\n${value.map((v) => `${inner}${toLuau(v, indent + 1)},`).join('\n')}\n${pad}}`;
  }
  const entries = Object.entries(value as Record<string, unknown>);
  if (entries.length === 0) return '{}';
  const simple = entries.every(([, v]) => typeof v !== 'object' || v === null) && entries.length <= 4;
  if (simple && indent > 0) return `{ ${entries.map(([k, v]) => `${key(k)} = ${toLuau(v)}`).join(', ')} }`;
  return `{\n${entries.map(([k, v]) => `${inner}${key(k)} = ${toLuau(v, indent + 1)},`).join('\n')}\n${pad}}`;
}

/** A full ModuleScript: header comment, one commented line per documented top-level key. */
export function configModule(title: string, values: Record<string, unknown>, docs: Record<string, string> = {}, intro = ''): string {
  const lines = [
    `-- GameKit config: ${title}`,
    `-- Edit the values below, then press Play. Scripts read this table when the game starts.`,
  ];
  if (intro) for (const l of intro.split('\n')) lines.push(`-- ${l}`);
  lines.push('return {');
  for (const [k, v] of Object.entries(values)) {
    if (docs[k]) lines.push(`\t-- ${docs[k]}`);
    lines.push(`\t${key(k)} = ${toLuau(v, 1)},`);
  }
  lines.push('}');
  return lines.join('\n') + '\n';
}

/** Wraps text in a Luau long string that cannot be terminated by its content. */
export function longString(text: string): string {
  let level = 1;
  while (text.includes(`]${'='.repeat(level)}]`)) level++;
  const eq = '='.repeat(level);
  // A newline right after the opening bracket is dropped by Luau, so add one on purpose
  // when the text itself starts with a newline.
  return `[${eq}[${text.startsWith('\n') ? '\n' : ''}${text}]${eq}]`;
}
