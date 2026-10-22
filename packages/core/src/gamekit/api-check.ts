/**
 * Roblox API checker: catches invented or misspelled APIs before the code runs, the most
 * common failure of small models. Uses the index generated from the official type
 * definitions (generated/roblox-api.ts):
 *   - game:GetService("Player")            -> unknown service, did you mean "Players"?
 *   - Instance.new("Brick") / IsA("Parts") -> unknown class
 *   - Enum.Material.Wooden                  -> unknown enum item, did you mean Wood?
 *   - Vector3.New(...) / Color3.fromRgb     -> unknown constructor
 *   - humanoid.Walkspeed = 30               -> unknown property on a variable whose class is known
 *   - Players:GetPlayerByName()             -> unknown method on a service
 *   - part:remove() / signal:connect()      -> deprecated, use Destroy / Connect
 */

import { API_CLASSES, API_CREATABLE, API_ENUMS, API_GLOBALS, API_SERVICES } from './generated/roblox-api.js';
import { stripCommentsAndStrings, type LintIssue } from './luau-lint.js';

const split = (list: string) => (list ? list.split(',') : []);
const SERVICES = new Set(split(API_SERVICES));
const CREATABLE = new Set(split(API_CREATABLE));
const ENUMS = new Map(Object.entries(API_ENUMS).map(([name, items]) => [name, new Set(split(items))]));
const GLOBALS = new Map(Object.entries(API_GLOBALS).map(([name, members]) => [name, new Set(split(members))]));

interface ClassInfo {
  members: Set<string>;
  deprecated: Map<string, string>;
}
const classCache = new Map<string, ClassInfo | null>();

/** Members of a class and all its ancestors (null when the class is unknown). */
export function classInfo(name: string): ClassInfo | null {
  if (classCache.has(name)) return classCache.get(name)!;
  const entry = API_CLASSES[name];
  if (!entry) {
    classCache.set(name, null);
    return null;
  }
  const info: ClassInfo = { members: new Set(split(entry[1])), deprecated: new Map() };
  for (const dep of split(entry[2] ?? '')) {
    const [old, replacement] = dep.split('>');
    info.deprecated.set(old, replacement ?? '');
  }
  if (entry[0]) {
    const parent = classInfo(entry[0]);
    if (parent) {
      parent.members.forEach((m) => info.members.add(m));
      parent.deprecated.forEach((v, k) => { if (!info.members.has(k)) info.deprecated.set(k, v); });
    }
  }
  classCache.set(name, info);
  return info;
}

export function isClass(name: string): boolean {
  return !!API_CLASSES[name];
}

function distance(a: string, b: string): number {
  const m = a.length;
  const n = b.length;
  const dp = Array.from({ length: m + 1 }, (_, i) => [i, ...Array(n).fill(0)]);
  for (let j = 1; j <= n; j++) dp[0][j] = j;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
  }
  return dp[m][n];
}

/** The closest known name (case-insensitive match first), or undefined when nothing is close. */
export function suggest(name: string, candidates: Iterable<string>): string | undefined {
  const lower = name.toLowerCase();
  let best: string | undefined;
  let bestScore = Infinity;
  for (const c of candidates) {
    if (c.toLowerCase() === lower) return c;
    if (Math.abs(c.length - name.length) > 3) continue;
    const d = distance(lower, c.toLowerCase());
    if (d < bestScore) {
      bestScore = d;
      best = c;
    }
  }
  const limit = name.length <= 4 ? 1 : name.length <= 8 ? 2 : 3;
  if (best && bestScore <= limit) return best;
  // Abbreviations and plural slips ("TakeDmg" -> "TakeDamage", "Player" -> "Players").
  let prefixBest: string | undefined;
  let prefixScore = Infinity;
  for (const c of candidates) {
    const cl = c.toLowerCase();
    let common = 0;
    while (common < Math.min(cl.length, lower.length) && cl[common] === lower[common]) common++;
    if (common >= 4 || (common >= 3 && Math.abs(cl.length - lower.length) <= 1)) {
      const d = distance(lower, cl);
      if (d <= Math.max(3, Math.ceil(name.length / 2)) && d < prefixScore) {
        prefixScore = d;
        prefixBest = c;
      }
    }
  }
  return prefixBest;
}

/** Up to 4 members starting like `name` ("GetPlayerByName" -> GetPlayerFromCharacter, GetPlayerByUserId...). */
function similarMembers(name: string, members: Set<string>): string[] {
  const head = /^[A-Z]?[a-z]+(?:[A-Z][a-z]+)?/.exec(name)?.[0] ?? name.slice(0, 5);
  return [...members].filter((m) => m.startsWith(head) && !m.startsWith('__')).slice(0, 4);
}

// What small models write when they mean a real class.
const CLASS_ALIASES: Record<string, string> = {
  Brick: 'Part', Block: 'Part', Cube: 'Part', Sphere: 'Part', Ball: 'Part', Cylinder: 'Part', BasePart: 'Part',
  Text: 'TextLabel', Label: 'TextLabel', Button: 'TextButton', Image: 'ImageLabel', Gui: 'ScreenGui', GUI: 'ScreenGui',
  Light: 'PointLight', Lamp: 'PointLight', Prompt: 'ProximityPrompt', Remote: 'RemoteEvent', Event: 'RemoteEvent',
  Group: 'Model', Container: 'Folder', Weld: 'WeldConstraint', Particles: 'ParticleEmitter', Particle: 'ParticleEmitter',
  Billboard: 'BillboardGui', Tween: 'TweenService', Character: 'Model', Npc: 'Model', NPC: 'Model',
};

/** Follows deprecation chains: remove -> Remove -> Destroy. */
const KNOWN_REPLACEMENTS: Record<string, string> = { Remove: 'Destroy', remove: 'Destroy' };

function finalReplacement(cls: ClassInfo, member: string): string {
  let current = KNOWN_REPLACEMENTS[member] ?? cls.deprecated.get(member) ?? '';
  for (let hops = 0; hops < 3 && current && cls.deprecated.has(current) && !cls.members.has(current); hops++) {
    const next = KNOWN_REPLACEMENTS[current] ?? cls.deprecated.get(current) ?? '';
    if (!next) break;
    current = next;
  }
  return current;
}

const didYouMean = (s: string | undefined) => (s ? ` Did you mean "${s}"?` : '');

// Names often guessed for a child/instance that really are a class of a different name.
// (Body parts are BasePart: R15 limbs and heads are MeshParts.)
const CHILD_CLASS_HINTS: Record<string, string> = { Humanoid: 'Humanoid', HumanoidRootPart: 'BasePart', Head: 'BasePart', leaderstats: 'Folder', Animator: 'Animator' };

/**
 * Infers the class of local variables with a reliable origin:
 *   local x = Instance.new("Part")            -> Part
 *   local x = game:GetService("Players")      -> Players (also game.Players, workspace)
 *   local x = y:FindFirstChildOfClass("Humanoid") / WhichIsA / WaitForChild("Humanoid")
 * Variables assigned again later are skipped (their class may change).
 */
function inferVariables(code: string, raw: string): Map<string, string> {
  const types = new Map<string, string>();
  const declared = new Map<string, number>();
  const declRe = /\blocal\s+([A-Za-z_]\w*)\s*(?::\s*[\w?]+\s*)?=\s*([^\n]+)/g;
  let m: RegExpExecArray | null;
  while ((m = declRe.exec(code))) {
    const name = m[1];
    declared.set(name, (declared.get(name) ?? 0) + 1);
    // Read the literal from the raw text at the same offset (strings are blanked in `code`).
    const rhs = raw.slice(m.index + m[0].length - m[2].length, m.index + m[0].length);
    let cls: string | undefined;
    let r: RegExpExecArray | null;
    if ((r = /^Instance\.new\(\s*["'](\w+)["']/.exec(rhs))) cls = r[1];
    else if ((r = /^game\s*:\s*GetService\(\s*["'](\w+)["']\s*\)\s*$/.exec(rhs.trim()))) cls = r[1];
    else if ((r = /^game\.(\w+)\s*$/.exec(rhs.trim())) && SERVICES.has(r[1])) cls = r[1];
    else if (/^workspace\s*$/.test(rhs.trim())) cls = 'Workspace';
    else if ((r = /:(?:FindFirstChildOfClass|FindFirstChildWhichIsA|FindFirstAncestorOfClass|FindFirstAncestorWhichIsA)\(\s*["'](\w+)["']\s*\)\s*$/.exec(rhs.trim()))) cls = r[1];
    else if ((r = /:(?:WaitForChild|FindFirstChild)\(\s*["'](\w+)["'][^)]*\)\s*$/.exec(rhs.trim())) && CHILD_CLASS_HINTS[r[1]]) cls = CHILD_CLASS_HINTS[r[1]];
    if (cls && isClass(cls)) types.set(name, cls);
    else types.delete(name);
  }
  for (const [name, count] of declared) {
    const withoutDecl = code.replace(new RegExp(`\\blocal\\s+${name}\\b`, 'g'), '');
    const reassigned = new RegExp(`(^|[^.\\w])${name}\\s*=[^=]`, 'm').test(withoutDecl);
    // A loop variable or parameter with the same name is another variable: don't guess its class.
    const shadowed = new RegExp(`\\bfor\\b[^\\n]*\\b${name}\\b[^\\n]*\\bin\\b|function\\s*[\\w.:]*\\s*\\([^)]*\\b${name}\\b`).test(code);
    if (count > 1 || reassigned || shadowed) types.delete(name);
  }
  return types;
}

/** Deprecated lowercase/old methods that are never valid under another class. */
const DEPRECATED_METHODS: Map<string, string> = (() => {
  const everywhere = new Map<string, string>();
  const valid = new Set<string>();
  for (const [, entry] of Object.entries(API_CLASSES)) {
    split(entry[1]).forEach((m) => valid.add(m));
    for (const dep of split(entry[2] ?? '')) {
      const [old, replacement] = dep.split('>');
      if (replacement && /^[a-z]/.test(old)) everywhere.set(old, replacement);
    }
  }
  for (const name of valid) everywhere.delete(name);
  return everywhere;
})();

export function checkRobloxApi(source: string): LintIssue[] {
  const issues: LintIssue[] = [];
  const code = stripCommentsAndStrings(source);
  const lineOf = (index: number) => code.slice(0, index).split('\n').length;
  const push = (index: number, severity: LintIssue['severity'], rule: string, message: string, fix?: string) => {
    const line = lineOf(index);
    if (!issues.some((i) => i.line === line && i.rule === rule && i.message === message)) issues.push({ line, severity, rule, message, fix });
  };

  // A string argument right after "(" at `index` (read from the raw source: strings are blank in `code`).
  const stringArg = (index: number): string | undefined => {
    const r = /^\(\s*(["'])([^"'\n]*)\1/.exec(source.slice(index, index + 120));
    return r ? r[2] : undefined;
  };

  // 1. Services.
  const serviceRe = /:\s*GetService\s*(?=\()/g;
  let m: RegExpExecArray | null;
  while ((m = serviceRe.exec(code))) {
    const name = stringArg(m.index + m[0].length);
    if (!name || /[^\w]/.test(name)) continue;
    if (!SERVICES.has(name)) {
      const s = suggest(name, SERVICES);
      push(m.index, 'error', 'api-unknown-service', `"${name}" is not a Roblox service.${didYouMean(s)}`, s ? `game:GetService("${s}")` : 'Check the name in the Roblox docs (get_roblox_docs).');
    }
  }

  // 2. Instance.new / IsA / FindFirstChildOfClass... class names.
  const classRe = /(Instance\.new|:\s*IsA|:\s*FindFirstChildOfClass|:\s*FindFirstChildWhichIsA|:\s*FindFirstAncestorOfClass|:\s*FindFirstAncestorWhichIsA)\s*(?=\()/g;
  while ((m = classRe.exec(code))) {
    const name = stringArg(m.index + m[0].length);
    if (!name || /[^\w]/.test(name)) continue;
    const isNew = m[1] === 'Instance.new';
    if (!isClass(name)) {
      const s = CLASS_ALIASES[name] ?? suggest(name, isNew ? CREATABLE : Object.keys(API_CLASSES));
      push(m.index, isNew ? 'error' : 'warning', 'api-unknown-class', `"${name}" is not a Roblox class.${didYouMean(s)}`, s ? `Use "${s}".` : undefined);
    } else if (isNew && !CREATABLE.has(name)) {
      push(m.index, 'error', 'api-not-creatable', `Instance.new("${name}") is not allowed: ${name} cannot be created by scripts.`, 'Use a creatable class (e.g. "Part", "Model", "Folder") or get the existing one with game:GetService / FindFirstChild.');
    }
  }

  // 3. Enums.
  const enumRe = /\bEnum\.(\w+)(?:\.(\w+))?/g;
  while ((m = enumRe.exec(code))) {
    const [, type, item] = m;
    const items = ENUMS.get(type);
    if (!items) {
      const s = suggest(type, ENUMS.keys());
      push(m.index, 'error', 'api-unknown-enum', `Enum.${type} does not exist.${didYouMean(s ? `Enum.${s}` : undefined)}`);
    } else if (item && !items.has(item)) {
      const s = suggest(item, items);
      push(m.index, 'error', 'api-unknown-enum-item', `Enum.${type}.${item} does not exist.${didYouMean(s ? `Enum.${type}.${s}` : undefined)}`, s ? undefined : `Valid: ${[...items].filter((i) => !/^(FromName|FromValue|GetEnumItems)$/.test(i)).slice(0, 25).join(', ')}`);
    }
  }

  // 4. Datatype constructors (Vector3.new, CFrame.lookAt, Color3.fromRGB...).
  const globalRe = /(^|[^.:\w])(Vector3|Vector2|CFrame|Color3|UDim2|UDim|BrickColor|TweenInfo|NumberRange|NumberSequence|ColorSequence|Ray|Region3|RaycastParams|OverlapParams|Random|DateTime|Instance|PhysicalProperties|task)\.(\w+)/g;
  while ((m = globalRe.exec(code))) {
    const [, , type, member] = m;
    const members = GLOBALS.get(type);
    if (members && members.size > 0 && !members.has(member)) {
      const s = suggest(member, members);
      push(m.index + m[1].length, 'error', 'api-unknown-constructor', `${type}.${member} does not exist.${didYouMean(s ? `${type}.${s}` : undefined)}`);
    }
  }

  // 5. Members of variables whose class is known.
  const types = inferVariables(code, source);
  if (types.size) {
    const memberRe = /(^|[^.:\w])([A-Za-z_]\w*)\s*([.:])\s*([A-Za-z_]\w*)(\s*=(?!=))?/g;
    while ((m = memberRe.exec(code))) {
      const [, , variable, sep, member, assign] = m;
      const cls = types.get(variable);
      if (!cls) continue;
      const info = classInfo(cls);
      if (!info) continue;
      const index = m.index + m[1].length;
      if (info.deprecated.has(member) && !info.members.has(member)) {
        const replacement = finalReplacement(info, member);
        push(index, 'warning', 'api-deprecated', `${cls}.${member} is deprecated.${replacement ? ` Use ${replacement}.` : ''}`, replacement ? `${variable}${sep}${replacement}` : undefined);
        continue;
      }
      if (info.members.has(member)) continue;
      // Reading x.Name may be a child ("workspace.Map"); calls and assignments must be real members.
      if (sep === '.' && !assign) continue;
      const s = suggest(member, info.members);
      const what = sep === ':' ? 'method' : 'property';
      const similar = s ? [] : similarMembers(member, info.members);
      push(index, 'error', 'api-unknown-member', `${cls} has no ${what} "${member}" (${variable}${sep}${member}).${didYouMean(s)}`,
        s ? `${variable}${sep}${s}` : similar.length ? `Similar: ${similar.join(', ')}` : `Check get_roblox_docs for ${cls}.`);
    }
  }

  // 6. Old lowercase methods (part:remove(), signal:connect()).
  const methodRe = /:\s*([a-z]\w*)\s*\(/g;
  while ((m = methodRe.exec(code))) {
    const found = DEPRECATED_METHODS.get(m[1]);
    if (!found) continue;
    const replacement = KNOWN_REPLACEMENTS[m[1]] ?? KNOWN_REPLACEMENTS[found] ?? found;
    const line = lineOf(m.index);
    if (issues.some((i) => i.line === line && i.rule === 'api-deprecated')) continue;
    push(m.index, 'warning', 'api-deprecated', `:${m[1]}() is deprecated in Roblox.`, `Use :${replacement}().`);
  }
  return issues;
}
