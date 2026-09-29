/**
 * A beginner-mistake linter for Roblox Luau.
 *
 * Not a type checker: it looks for the handful of patterns that break most games
 * written by people (or models) who are new to Roblox -- client APIs in server
 * scripts, infinite loops without a yield, trusting values sent by the client,
 * deprecated globals -- and explains the fix in one sentence.
 */

export type ScriptContext = 'server' | 'client' | 'module' | 'unknown';
export type Severity = 'error' | 'warning' | 'info';

export interface LintIssue {
  line: number;
  severity: Severity;
  rule: string;
  message: string;
  fix?: string;
}

/**
 * Blanks out comments and string contents (keeping line structure) so rules do not
 * fire on text such as `print("use wait() here")`.
 */
export function stripCommentsAndStrings(source: string): string {
  let out = '';
  let i = 0;
  const n = source.length;
  const blank = (s: string) => s.replace(/[^\n]/g, ' ');
  while (i < n) {
    const c = source[i];
    const next = source[i + 1];
    if (c === '-' && next === '-') {
      const long = /^--\[(=*)\[/.exec(source.slice(i, i + 20));
      if (long) {
        const close = `]${long[1]}]`;
        const end = source.indexOf(close, i + long[0].length);
        const stop = end === -1 ? n : end + close.length;
        out += blank(source.slice(i, stop));
        i = stop;
      } else {
        const end = source.indexOf('\n', i);
        const stop = end === -1 ? n : end;
        out += blank(source.slice(i, stop));
        i = stop;
      }
      continue;
    }
    if (c === '[') {
      const long = /^\[(=*)\[/.exec(source.slice(i, i + 20));
      if (long) {
        const close = `]${long[1]}]`;
        const end = source.indexOf(close, i + long[0].length);
        const stop = end === -1 ? n : end + close.length;
        out += '""' + blank(source.slice(i + 2, stop));
        i = stop;
        continue;
      }
    }
    if (c === '"' || c === "'" || c === '`') {
      let j = i + 1;
      while (j < n && source[j] !== c && source[j] !== '\n') {
        if (source[j] === '\\') j++;
        j++;
      }
      out += c + ' '.repeat(Math.max(0, Math.min(j, n) - i - 1)) + (j < n && source[j] === c ? c : '');
      i = j < n && source[j] === c ? j + 1 : j;
      continue;
    }
    out += c;
    i++;
  }
  return out;
}

interface LineRule {
  rule: string;
  severity: Severity;
  contexts?: ScriptContext[];
  re: RegExp;
  /** Services that also match when fetched with GetService("Name") (inside a string). */
  services?: string[];
  message: string;
  fix?: string;
}

const SERVER_ONLY = 'This only works on the server. A LocalScript cannot use it.';
const CLIENT_ONLY = 'This only works on the client (LocalScript). It is nil or useless in a server Script.';

const LINE_RULES: LineRule[] = [
  // --- Client/server boundary -------------------------------------------------------
  { rule: 'client-api-in-server', severity: 'error', contexts: ['server'], re: /\bLocalPlayer\b/,
    message: `Players.LocalPlayer is nil in a server Script. ${CLIENT_ONLY}`,
    fix: 'On the server, get the player from an event: Players.PlayerAdded, a Touched hit (Players:GetPlayerFromCharacter), or the first argument of OnServerEvent.' },
  { rule: 'client-api-in-server', severity: 'error', contexts: ['server'], re: /:\s*FireServer\s*\(/,
    message: 'FireServer can only be called from a LocalScript.',
    fix: 'On the server use remote:FireClient(player, ...) or remote:FireAllClients(...).' },
  { rule: 'client-api-in-server', severity: 'error', contexts: ['server'], re: /\.OnClientEvent\b/,
    message: 'OnClientEvent only fires in LocalScripts.',
    fix: 'On the server listen to remote.OnServerEvent:Connect(function(player, ...) end).' },
  { rule: 'client-api-in-server', severity: 'error', contexts: ['server'], re: /:\s*InvokeServer\s*\(/,
    message: 'InvokeServer can only be called from a LocalScript.' },
  { rule: 'client-api-in-server', severity: 'warning', contexts: ['server'], re: /\bUserInputService\b|\bContextActionService\b|:\s*GetMouse\s*\(|\bCurrentCamera\b/,
    services: ['UserInputService', 'ContextActionService'],
    message: `Input and camera APIs belong in LocalScripts. ${CLIENT_ONLY}`,
    fix: 'Read input in a LocalScript and send the intent to the server with a RemoteEvent.' },
  { rule: 'server-api-in-client', severity: 'error', contexts: ['client'], re: /\bDataStoreService\b|\bMemoryStoreService\b|\bMessagingService\b/,
    services: ['DataStoreService', 'MemoryStoreService', 'MessagingService'],
    message: `Data stores and cross-server services cannot be used from the client. ${SERVER_ONLY}`,
    fix: 'Keep saving/loading in a server Script; send results to the client with a RemoteEvent or leaderstats values.' },
  { rule: 'server-api-in-client', severity: 'error', contexts: ['client'], re: /\bServerStorage\b|\bServerScriptService\b/,
    services: ['ServerStorage', 'ServerScriptService'],
    message: 'ServerStorage and ServerScriptService are invisible to clients (always empty).',
    fix: 'Put things the client needs in ReplicatedStorage.' },
  { rule: 'server-api-in-client', severity: 'error', contexts: ['client'], re: /:\s*(FireClient|FireAllClients)\s*\(/,
    message: 'FireClient/FireAllClients can only be called from the server.',
    fix: 'From a LocalScript use remote:FireServer(...).' },
  { rule: 'server-api-in-client', severity: 'error', contexts: ['client'], re: /\.OnServerEvent\b|\.OnServerInvoke\b/,
    message: 'OnServerEvent/OnServerInvoke only work in server Scripts.',
    fix: 'In a LocalScript listen to remote.OnClientEvent instead.' },
  { rule: 'server-api-in-client', severity: 'error', contexts: ['client'], re: /:\s*(AwardBadge|TeleportAsync|RequestAsync|PostAsync)\s*\(|\.ProcessReceipt\b/,
    message: `This API is server-only. ${SERVER_ONLY}` },
  { rule: 'client-writes-leaderstats', severity: 'error', contexts: ['client'], re: /leaderstats[\w.:()"'\s]*\.Value\s*(=[^=]|\+=|-=)/,
    message: 'Changing leaderstats from a LocalScript only changes it on this screen; the server (and saving) never sees it.',
    fix: 'Fire a RemoteEvent and change the value in a server Script, after checking the request is allowed.' },

  // --- Deprecated / legacy ------------------------------------------------------------
  { rule: 'deprecated-wait', severity: 'warning', re: /(^|[^.:\w])wait\s*\(/,
    message: 'wait() is deprecated and throttled.', fix: 'Use task.wait(seconds).' },
  { rule: 'deprecated-spawn', severity: 'warning', re: /(^|[^.:\w])spawn\s*\(/,
    message: 'spawn() is deprecated.', fix: 'Use task.spawn(fn).' },
  { rule: 'deprecated-delay', severity: 'warning', re: /(^|[^.:\w])delay\s*\(/,
    message: 'delay() is deprecated.', fix: 'Use task.delay(seconds, fn).' },
  { rule: 'deprecated-tick', severity: 'info', re: /(^|[^.:\w])tick\s*\(\s*\)/,
    message: 'tick() is deprecated.', fix: 'Use os.clock() for timing or os.time() for timestamps.' },
  { rule: 'lowercase-connect', severity: 'warning', re: /:\s*connect\s*\(/,
    message: ':connect() is the deprecated lowercase form.', fix: 'Use :Connect().' },
  { rule: 'deprecated-remove', severity: 'warning', re: /:\s*Remove\s*\(\s*\)/,
    message: ':Remove() is deprecated.', fix: 'Use :Destroy().' },
  { rule: 'instance-new-parent', severity: 'info', re: /Instance\.new\s*\(\s*["'][A-Za-z]+["']\s*,/,
    message: 'Passing the parent to Instance.new is slower and can cause replication glitches.',
    fix: 'Create the instance, set its properties, and set .Parent last.' },
  { rule: 'legacy-body-movers', severity: 'warning', re: /\b(BodyVelocity|BodyPosition|BodyGyro|BodyForce|BodyAngularVelocity|BodyThrust|RocketPropulsion)\b/,
    message: 'Body movers are deprecated.', fix: 'Use LinearVelocity, AlignPosition, AlignOrientation, VectorForce or AngularVelocity constraints.' },
  { rule: 'humanoid-loadanimation', severity: 'warning', re: /Humanoid\w*\s*:\s*LoadAnimation\s*\(/,
    message: 'Humanoid:LoadAnimation is deprecated.', fix: 'Use humanoid:WaitForChild("Animator"):LoadAnimation(animation).' },
  { rule: 'deprecated-raycast', severity: 'warning', re: /:\s*FindPartOnRay(WithIgnoreList|WithWhitelist)?\s*\(/,
    message: 'FindPartOnRay is deprecated.', fix: 'Use workspace:Raycast(origin, direction, RaycastParams.new()).' },
  { rule: 'deprecated-primarypart', severity: 'warning', re: /:\s*(SetPrimaryPartCFrame|GetPrimaryPartCFrame)\s*\(/,
    message: 'SetPrimaryPartCFrame/GetPrimaryPartCFrame are deprecated.', fix: 'Use model:PivotTo(cframe) and model:GetPivot().' },
  { rule: 'deprecated-message', severity: 'warning', re: /Instance\.new\s*\(\s*["'](Hint|Message)["']/,
    message: 'Hint/Message instances are deprecated.', fix: 'Show text with a ScreenGui TextLabel (see build_ui).' },
  { rule: 'table-getn', severity: 'warning', re: /\btable\.getn\s*\(/, message: 'table.getn does not exist in Luau.', fix: 'Use #tbl.' },
  { rule: 'numeric-require', severity: 'warning', re: /\brequire\s*\(\s*\d+\s*\)/,
    message: 'require(assetId) only works for modules you own or that are public and allowed; it silently fails in many games.',
    fix: 'Insert the module into ReplicatedStorage/ServerScriptService and require it by path.' },
  { rule: 'loadstring', severity: 'warning', contexts: ['server', 'client'], re: /\bloadstring\s*\(/,
    message: 'loadstring is disabled by default (ServerScriptService.LoadStringEnabled) and never works on the client.' },
  { rule: 'while-wait', severity: 'info', re: /\bwhile\s+wait\s*\(/,
    message: '`while wait() do` hides the loop condition and uses deprecated wait().', fix: 'Write `while true do ... task.wait(1) end`.' },
];

const RAW_LINE_RULES: LineRule[] = [
  { rule: 'string-interpolation-quotes', severity: 'warning', re: /(^|[^\\])"[^"`]*\{[A-Za-z_][\w.:()]*\}[^"`]*"/,
    message: 'Text inside "double quotes" is not interpolated: "{x}" prints literally.',
    fix: 'Use backticks for interpolation: `Coins: {coins}` (or "Coins: " .. coins).' },
  { rule: 'color3-range', severity: 'warning', re: /Color3\.new\s*\([^)]*\b([2-9]\d|1\d\d|2[0-4]\d|25[0-5]|[2-9])(\.\d+)?\b/,
    message: 'Color3.new takes values from 0 to 1; values above 1 produce wrong colors.',
    fix: 'Use Color3.fromRGB(r, g, b) for 0-255 values.' },
];

const DATASTORE_CALL = /:\s*(GetAsync|SetAsync|UpdateAsync|IncrementAsync|RemoveAsync|GetSortedAsync)\s*\(/;
const YIELD = /\btask\.wait\s*\(|(^|[^.:\w])wait\s*\(|:\s*Wait\s*\(|\bcoroutine\.yield\b|\bbreak\b|\breturn\b|\bRenderStepped\b|\bHeartbeat\b|\bStepped\b/;
// `while/for ... do` counts once, through `do`.
const BLOCK_OPEN = /\b(function|then|do|repeat)\b/g;
const BLOCK_CLOSE = /\b(end|until)\b/g;

function countMatches(line: string, re: RegExp): number {
  re.lastIndex = 0;
  let count = 0;
  while (re.exec(line)) count++;
  return count;
}

/** Net block depth change of one (comment/string-stripped) line. */
function depthDelta(line: string): number {
  // `elseif ... then` continues an if-block instead of opening a new one.
  const opens = countMatches(line.replace(/\belseif\b.*?\bthen\b/g, ''), BLOCK_OPEN);
  return opens - countMatches(line, BLOCK_CLOSE);
}

/** Finds `while true do` loops whose body never yields: the classic "game freezes" bug. */
function findUnyieldingLoops(lines: string[], issues: LintIssue[]) {
  for (let i = 0; i < lines.length; i++) {
    const header = /\bwhile\s+(true|1)\s+do\b/.exec(lines[i]);
    if (!header) continue;
    const restOfHeader = lines[i].slice(header.index + header[0].length);
    let yields = YIELD.test(restOfHeader);
    let depth = 1 + depthDelta(restOfHeader);
    for (let j = i + 1; j < lines.length && depth > 0 && !yields; j++) {
      if (YIELD.test(lines[j])) yields = true;
      depth += depthDelta(lines[j]);
    }
    if (!yields) {
      issues.push({
        line: i + 1, severity: 'warning', rule: 'loop-without-yield',
        message: 'This infinite loop never waits, so it will freeze the game ("Script timeout: exhausted allowed execution time") unless a function it calls waits.',
        fix: 'Add task.wait() inside the loop (for example task.wait(1)).',
      });
    }
  }
}

function findUnprotectedDataStoreCalls(lines: string[], issues: LintIssue[]) {
  for (let i = 0; i < lines.length; i++) {
    if (!DATASTORE_CALL.test(lines[i])) continue;
    const window = lines.slice(Math.max(0, i - 4), i + 1).join('\n');
    if (/\bpcall\b|\bxpcall\b/.test(window)) continue;
    issues.push({
      line: i + 1, severity: 'warning', rule: 'datastore-no-pcall',
      message: 'DataStore calls can fail (network, limits, Studio without API access) and will crash the script.',
      fix: 'Wrap it: local ok, result = pcall(function() return store:GetAsync(key) end)',
    });
  }
}

/** Server handlers that write a client-supplied argument straight into a stat. */
function findTrustedClientValues(lines: string[], issues: LintIssue[]) {
  for (let i = 0; i < lines.length; i++) {
    const m = /OnServerEvent\s*:\s*Connect\s*\(\s*function\s*\(\s*\w+\s*,\s*([\w\s,]+)\)/.exec(lines[i]);
    if (!m) continue;
    const params = m[1].split(',').map(p => p.trim()).filter(Boolean);
    for (let j = i + 1; j < Math.min(lines.length, i + 25); j++) {
      const l = lines[j];
      if (/^\s*end\s*\)\s*$/.test(l)) break;
      for (const p of params) {
        const re = new RegExp(`\\.Value\\s*(=|\\+=|-=)[^\\n]*\\b${p}\\b|\\b(Coins|Cash|Money|Gems|Points|Wins|Level)\\b[^\\n]*[+=][^\\n]*\\b${p}\\b`);
        if (re.test(l)) {
          issues.push({
            line: j + 1, severity: 'warning', rule: 'trusts-client-value',
            message: `The server uses "${p}", a value sent by the client, to change a stat. Exploiters can send any number.`,
            fix: 'Decide amounts on the server (from config/prices) and only accept what to do from the client, never how much.',
          });
          return;
        }
      }
    }
  }
}

function findUnsafeCharacterAccess(lines: string[], issues: LintIssue[]) {
  for (let i = 0; i < lines.length; i++) {
    if (/LocalPlayer\s*\.\s*Character\s*(\.\s*\w+|:\s*FindFirstChild)/.test(lines[i])) {
      if (/CharacterAdded|WaitForChild|\bor\b/.test(lines[i])) continue;
      issues.push({
        line: i + 1, severity: 'warning', rule: 'character-not-loaded',
        message: 'LocalPlayer.Character can be nil when the script starts or after respawn.',
        fix: 'local character = player.Character or player.CharacterAdded:Wait(); local humanoid = character:WaitForChild("Humanoid")',
      });
    }
  }
}

export function lintLuau(source: string, context: ScriptContext = 'unknown'): LintIssue[] {
  const issues: LintIssue[] = [];
  const stripped = stripCommentsAndStrings(source);
  const lines = stripped.split(/\r?\n/);
  const rawLines = source.split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const raw = rawLines[i] ?? '';
    const isComment = /^\s*--/.test(raw);
    for (const r of LINE_RULES) {
      if (r.contexts && !r.contexts.includes(context)) continue;
      const viaService = !isComment && r.services?.some((name) => new RegExp(`GetService\\(\\s*["']${name}["']\\s*\\)`).test(raw));
      if (r.re.test(line) || viaService) {
        issues.push({ line: i + 1, severity: r.severity, rule: r.rule, message: r.message, fix: r.fix });
      }
    }
    // Skip comment-only lines for the raw rules.
    if (isComment) continue;
    for (const r of RAW_LINE_RULES) {
      if (r.re.test(raw) && !/`/.test(raw)) {
        issues.push({ line: i + 1, severity: r.severity, rule: r.rule, message: r.message, fix: r.fix });
      }
    }
  }

  findUnyieldingLoops(lines, issues);
  findUnprotectedDataStoreCalls(lines, issues);
  if (context === 'server') findTrustedClientValues(lines, issues);
  if (context === 'client') findUnsafeCharacterAccess(lines, issues);

  // One report per rule per line is enough.
  const seen = new Set<string>();
  return issues
    .filter(i => {
      const key = `${i.line}:${i.rule}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => a.line - b.line);
}

/** Maps a Roblox script class (and location) to the context its code runs in. */
export function contextFor(className: string, path = '', runContext?: string): ScriptContext {
  if (className === 'ModuleScript') return 'module';
  if (className === 'LocalScript') return 'client';
  if (className === 'Script') {
    if (runContext === 'Client') return 'client';
    return 'server';
  }
  if (/StarterPlayerScripts|StarterCharacterScripts|StarterGui|PlayerGui/.test(path)) return 'client';
  return 'unknown';
}
