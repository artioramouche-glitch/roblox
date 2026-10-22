/**
 * Offline Luau syntax checking.
 *
 * Uses luau-web (the real Luau compiler built to WebAssembly) so a script can be
 * rejected with a precise line number BEFORE it reaches Studio. Loading is lazy and
 * failure-tolerant: if the WASM module cannot load, callers get `available: false`
 * instead of an exception, and the write path simply skips the check.
 */

export interface SyntaxIssue {
  line: number;
  message: string;
  hint?: string;
}

export interface SyntaxResult {
  available: boolean;
  ok: boolean;
  errors: SyntaxIssue[];
}

type LuauStateLike = { loadstring(source: string, chunkname?: string, throwOnCompilationError?: boolean): unknown };

let statePromise: Promise<LuauStateLike | null> | null = null;

function loadState(): Promise<LuauStateLike | null> {
  if (!statePromise) {
    statePromise = (async () => {
      try {
        // Indirect import so TypeScript/ts-jest leave the specifier alone: luau-web is
        // an ES module with top-level await and must be loaded natively.
        const dynamicImport = new Function('s', 'return import(s)') as (s: string) => Promise<any>;
        const mod = await dynamicImport('luau-web');
        return (await mod.LuauState.createAsync()) as LuauStateLike;
      } catch (err) {
        console.error(`[gamekit] Luau syntax checker unavailable: ${err instanceof Error ? err.message : String(err)}`);
        return null;
      }
    })();
  }
  return statePromise;
}

/** Friendly explanations for the mistakes that code written by weaker models makes most. */
const SOURCE_HINTS: Array<{ re: RegExp; hint: string }> = [
  { re: /!=/, hint: 'Luau uses ~= for "not equal", not !=.' },
  { re: /&&|\|\|/, hint: 'Luau uses the words `and` / `or`, not && / ||.' },
  { re: /^\s*\/\//, hint: 'Comments in Luau start with -- (two dashes), not //.' },
  { re: /\/\*/, hint: 'Block comments in Luau are --[[ ... ]], not /* ... */.' },
  { re: /\+\+|--\s*;?\s*$/, hint: 'Luau has no ++ or -- operators. Use x += 1.' },
  { re: /\b(null|undefined)\b/, hint: 'Luau uses nil, not null/undefined.' },
  { re: /\bconsole\.log\b/, hint: 'Use print(...) instead of console.log.' },
  { re: /\b(const|let|var)\s+\w+\s*=/, hint: 'Declare variables with `local`, not const/let/var.' },
  { re: /\bfunction\s+\w*\s*\([^)]*\)\s*\{/, hint: 'Luau functions end with `end`, not { }.' },
  { re: /\}\s*else\s*\{|\)\s*\{\s*$/, hint: 'Luau blocks use then/do ... end, not { }.' },
  { re: /\belse\s+if\b/, hint: 'Use `elseif` (one word). `else if` opens a new block that needs its own `end`.' },
  { re: /===/, hint: 'Luau uses == for equality (there is no ===).' },
  { re: /\bthis\./, hint: 'Luau has no `this`. Use `self` inside methods declared with `:`.' },
  { re: /\bnew\s+[A-Z]\w*\(/, hint: 'Create instances with Instance.new("ClassName"), not `new`.' },
];

const MESSAGE_HINTS: Array<{ re: RegExp; hint: string }> = [
  { re: /Expected 'end'/, hint: 'A block (if/for/while/function/do) is missing its closing `end`. Count your `end`s.' },
  { re: /Expected 'then'/, hint: 'An `if` or `elseif` condition must be followed by `then`.' },
  { re: /Expected 'do'/, hint: '`for` and `while` loops need `do` after the header.' },
  { re: /Expected identifier when parsing expression, got '\)'/, hint: 'Trailing comma or missing value before `)`.' },
  { re: /Expected '\)'/, hint: 'A parenthesis is not closed. Check the function call or condition.' },
  { re: /Expected '}'/, hint: 'A table constructor { ... } is not closed, or entries are missing commas.' },
  { re: /Incomplete statement/, hint: 'A line is not a full statement. Did you forget `=` or `()`?' },
  { re: /Malformed string/, hint: 'A string is not closed. Check quotes on this line.' },
  { re: /Unfinished long/, hint: 'A [[ long string ]] or --[[ comment ]] is not closed.' },
];

function hintFor(message: string, lineText: string | undefined): string | undefined {
  if (lineText) {
    for (const { re, hint } of SOURCE_HINTS) if (re.test(lineText)) return hint;
  }
  for (const { re, hint } of MESSAGE_HINTS) if (re.test(message)) return hint;
  return undefined;
}

/** Parses the `chunk:LINE: message` format luau produces. */
function parseError(raw: string, source: string): SyntaxIssue {
  const m = /^[^:]*:(\d+):\s*(.*)$/s.exec(raw.trim());
  const line = m ? parseInt(m[1], 10) : 1;
  const message = m ? m[2] : raw.trim();
  const lines = source.split(/\r?\n/);
  // The reported line is where the parser gave up; the real mistake is often a line or
  // two above, so look for a known pattern nearby.
  let hint: string | undefined;
  for (let l = line; l >= Math.max(1, line - 3) && !hint; l--) {
    hint = hintFor(message, lines[l - 1]);
  }
  return { line, message, hint: hint ?? hintFor(message, undefined) };
}

export async function checkLuauSyntax(source: string, chunkName = 'script'): Promise<SyntaxResult> {
  const state = await loadState();
  if (!state) return { available: false, ok: true, errors: [] };
  try {
    const result = state.loadstring(source, '=' + chunkName, false);
    if (typeof result === 'string') {
      return { available: true, ok: false, errors: [parseError(result, source)] };
    }
    return { available: true, ok: true, errors: [] };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { available: true, ok: false, errors: [parseError(message, source)] };
  }
}
