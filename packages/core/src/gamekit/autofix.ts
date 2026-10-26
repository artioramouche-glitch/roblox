/**
 * Auto-fixes the mechanical mistakes small models make when they write Luau like JavaScript
 * or Python. Only code is touched (never strings or comments), every change is reported so
 * the model learns, and fixes that could change a valid program are applied only when the
 * original does not compile.
 */

import { checkLuauSyntax } from './luau-syntax.js';
import { stripCommentsAndStrings } from './luau-lint.js';

export interface AutofixResult {
  source: string;
  fixes: string[];
}

interface Rule {
  name: string;
  re: RegExp;
  /** Replacement for the whole match (may use $1...). */
  to: string | ((match: RegExpExecArray) => string);
  /** Only when the code does not compile as written. */
  ifBroken?: boolean;
  /** Skip the rule for this source (e.g. the script defines its own wait function). */
  skipIf?: RegExp;
}

const RULES: Rule[] = [
  { name: '!== / != -> ~=', re: /!==?/g, to: '~=' },
  { name: '=== -> ==', re: /===/g, to: '==' },
  { name: '&& -> and', re: /\s*&&\s*/g, to: ' and ' },
  { name: '|| -> or', re: /\s*\|\|\s*/g, to: ' or ' },
  { name: '!x -> not x', re: /!(?=[\w(])/g, to: 'not ' },
  { name: 'null/undefined/None -> nil', re: /\b(null|undefined|None)\b/g, to: 'nil' },
  { name: 'True/False -> true/false', re: /\b(True|False)\b/g, to: (m) => m[1].toLowerCase() },
  { name: 'let/const/var -> local', re: /^(\s*)(let|const|var)\s+(?=[A-Za-z_])/gm, to: '$1local ' },
  // Not in "function wait(" (a user function with that name).
  { name: 'wait() -> task.wait()', re: /(?<!function\s*)(^|[^.:\w])wait\s*\(/g, to: '$1task.wait(', skipIf: /\b(function|local)\s+wait\b/ },
  { name: 'spawn() -> task.spawn()', re: /(?<!function\s*)(^|[^.:\w])spawn\s*\(/g, to: '$1task.spawn(', skipIf: /\b(function|local)\s+spawn\b/ },
  { name: 'delay() -> task.delay()', re: /(?<!function\s*)(^|[^.:\w])delay\s*\(/g, to: '$1task.delay(', skipIf: /\b(function|local)\s+delay\b/ },
  { name: 'console.log -> print', re: /\bconsole\.log\s*\(/g, to: 'print(' },
  { name: 'Math. -> math.', re: /\bMath\.(floor|ceil|random|abs|max|min|sqrt|round|pow|sin|cos|pi|PI)\b/g, to: (m) => (m[1] === 'PI' ? 'math.pi' : m[1] === 'round' ? 'math.round' : `math.${m[1]}`) },
  // Not when the script has its own "length" field (then x.length is legitimate).
  { name: 'x.length -> #x', re: /\b([A-Za-z_][\w.]*)\.length\b/g, to: '#$1', skipIf: /\blength\s*=/ },
  { name: 'i++ -> i += 1', re: /^(\s*)([A-Za-z_][\w.]*)\s*\+\+\s*;?\s*$/gm, to: '$1$2 += 1' },
  { name: 'elif -> elseif', re: /\belif\b/g, to: 'elseif' },
  { name: 'else if -> elseif', re: /\belse\s+if\b/g, to: 'elseif', ifBroken: true },
];

/** Positions that are code (not inside a string or comment). */
function codeMask(source: string): string {
  return stripCommentsAndStrings(source);
}

function applyRule(source: string, rule: Rule, fixes: string[]): string {
  if (rule.skipIf && rule.skipIf.test(source)) return source;
  const mask = codeMask(source);
  const re = new RegExp(rule.re.source, rule.re.flags);
  let out = '';
  let last = 0;
  let count = 0;
  let firstLine = 0;
  let m: RegExpExecArray | null;
  // Match on the masked text (same offsets), so strings/comments never match.
  while ((m = re.exec(mask))) {
    if (m[0].length === 0) {
      re.lastIndex++;
      continue;
    }
    const original = source.slice(m.index, m.index + m[0].length);
    if (original !== m[0]) continue; // overlaps a string or a comment
    const replacement = typeof rule.to === 'function'
      ? rule.to(m)
      : rule.to.replace(/\$(\d)/g, (_, i) => m![Number(i)] ?? '');
    if (replacement === original) continue;
    out += source.slice(last, m.index) + replacement;
    last = m.index + m[0].length;
    if (!count) firstLine = source.slice(0, m.index).split('\n').length;
    count++;
  }
  if (!count) return source;
  fixes.push(`${rule.name} (${count}x, first on line ${firstLine})`);
  return out + source.slice(last);
}

/** Converts `${x}` inside backtick strings to Luau interpolation `{x}`, and "a" + b to "a" .. b. */
function fixStrings(source: string, fixes: string[]): string {
  let out = source;
  const mask = codeMask(out);
  // `text ${x}` -> `text {x}` (in Luau `${x}` would print a literal "$").
  let interpolations = 0;
  out = out.replace(/`[^`\n]*`/g, (str, index: number) => {
    if (mask[index] !== '`') return str;
    return str.replace(/\$\{/g, () => {
      interpolations++;
      return '{';
    });
  });
  if (interpolations) fixes.push(`\`\${x}\` -> \`{x}\` (Luau string interpolation, ${interpolations}x)`);

  // "text" + x  /  x + "text"  -> ..  (+ never joins strings in Luau).
  const masked = codeMask(out);
  let joins = 0;
  const chars = out.split('');
  const re = /(["'`])\s*\+|\+\s*(["'`])/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(masked))) {
    const plus = m.index + m[0].indexOf('+');
    if (masked[plus] !== '+' || out[plus] !== '+') continue;
    if (out[plus + 1] === '=' || out[plus - 1] === '+') continue;
    chars[plus] = '..';
    joins++;
  }
  if (joins) {
    out = chars.join('');
    fixes.push(`"text" + x -> "text" .. x (${joins}x): Luau joins strings with ..`);
  }
  return out;
}

/** Converts // and /* *\/ comments that start a line (a // in the middle of code is floor division). */
function fixComments(source: string, fixes: string[]): string {
  let count = 0;
  let mask = codeMask(source);
  let out = source.replace(/^(\s*)\/\/(.*)$/gm, (all: string, indent: string, rest: string, offset: number) => {
    if (mask[offset + indent.length] !== '/') return all; // inside a long string
    count++;
    return `${indent}--${rest}`;
  });
  mask = codeMask(out);
  out = out.replace(/^(\s*)\/\*([\s\S]*?)\*\//gm, (all: string, indent: string, body: string, offset: number) => {
    if (mask[offset + indent.length] !== '/') return all;
    count++;
    return `${indent}--[[${body}]]`;
  });
  if (count) fixes.push(`// comments -> -- (${count}x)`);
  return out;
}

export async function autofixLuau(source: string): Promise<AutofixResult> {
  const fixes: string[] = [];
  const brokenAtStart = !(await checkLuauSyntax(source, 'autofix')).ok;
  let out = fixComments(source, fixes);
  out = fixStrings(out, fixes);
  for (const rule of RULES) {
    if (rule.ifBroken) continue;
    out = applyRule(out, rule, fixes);
  }
  if (brokenAtStart) {
    const syntax = await checkLuauSyntax(out, 'autofix');
    if (!syntax.ok) {
      for (const rule of RULES.filter((r) => r.ifBroken)) {
        const attempt: string[] = [];
        const candidate = applyRule(out, rule, attempt);
        if (candidate !== out && (await checkLuauSyntax(candidate, 'autofix')).ok) {
          out = candidate;
          fixes.push(...attempt);
        }
      }
    }
  }
  return { source: out, fixes };
}
