/**
 * test_game: automated playtest. Inserts a server test runner + client probe, starts
 * Play, lets the runner play through the game a little, collects server AND client
 * errors, then cleans up and explains every problem.
 */

import { LUAU_SOURCES } from './generated/luau-sources.js';
import { asArray, install, type LuauRunner } from './installer.js';
import { hintForRuntimeError, parseRuntimeError } from './hints.js';

export interface PlaytestBridge extends LuauRunner {
  startPlaytest(mode: 'play' | 'run'): Promise<any>;
  stopPlaytest(): Promise<any>;
  getPlaytestOutput(): Promise<any>;
}

export interface TestOptions {
  seconds?: number;
  autoplay?: boolean;
  timeoutSeconds?: number;
}

const RUNNER = '__GameKitTestRunner';
const PROBE = '__GameKitTestProbe';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

interface Problem {
  side: 'server' | 'client' | 'output';
  script?: string;
  line?: number;
  message: string;
  hint?: string;
  count: number;
}

function addProblem(list: Problem[], side: Problem['side'], raw: string, script?: string) {
  const parsed = parseRuntimeError(raw);
  const message = parsed.message || raw;
  const key = `${side}|${script ?? parsed.script}|${message}`;
  const existing = list.find((p) => `${p.side}|${p.script}|${p.message}` === key);
  if (existing) {
    existing.count++;
    return;
  }
  list.push({ side, script: script ?? parsed.script, line: parsed.line, message, hint: hintForRuntimeError(raw), count: 1 });
}

async function cleanup(runner: LuauRunner) {
  await install(runner, {
    label: 'GameKit test cleanup',
    items: [],
    deletes: [`ServerScriptService/${RUNNER}`, `StarterPlayer/StarterPlayerScripts/${PROBE}`, `ReplicatedStorage/${PROBE}`],
  });
}

export async function runPlaytest(bridge: PlaytestBridge, options: TestOptions = {}): Promise<Record<string, any>> {
  const seconds = Math.max(8, Math.min(120, options.seconds ?? 20));
  const timeout = (options.timeoutSeconds ?? seconds + 45) * 1000;

  // A playtest cannot start while another one runs.
  try {
    const state = await bridge.getPlaytestOutput();
    if (state?.isRunning) {
      return { verdict: 'BLOCKED', reason: 'A playtest is already running in Studio. Stop it (Stop button) and call test_game again.' };
    }
  } catch {
    // Older plugins may not answer; carry on.
  }

  await install(bridge, {
    label: 'GameKit test setup',
    items: [
      {
        parent: ['ServerScriptService'], mode: 'replace',
        node: { name: RUNNER, className: 'Script', source: LUAU_SOURCES['runtime/TestRunner.server.luau'], attrs: { Duration: seconds, Autoplay: options.autoplay !== false } },
      },
      {
        parent: ['StarterPlayer', 'StarterPlayerScripts'], mode: 'replace',
        node: { name: PROBE, className: 'LocalScript', source: LUAU_SOURCES['runtime/TestProbe.client.luau'] },
      },
    ],
  });

  let final: any = null;
  let timedOut = false;
  try {
    await bridge.startPlaytest('play');
    const started = Date.now();
    await sleep(3000);
    while (true) {
      let state: any;
      try {
        state = await bridge.getPlaytestOutput();
      } catch {
        state = null;
      }
      if (state && state.isRunning === false) {
        final = state;
        break;
      }
      if (Date.now() - started > timeout) {
        timedOut = true;
        try {
          await bridge.stopPlaytest();
        } catch {
          // ignored: reported below
        }
        await sleep(3000);
        try {
          final = await bridge.getPlaytestOutput();
        } catch {
          final = state;
        }
        break;
      }
      await sleep(1500);
    }
  } finally {
    try {
      await cleanup(bridge);
    } catch {
      // The cleanup failing must not hide the test result; check_game reports leftovers.
    }
  }

  let report: any = null;
  if (final?.testResult) {
    try {
      report = JSON.parse(final.testResult);
    } catch {
      report = null;
    }
  }

  const problems: Problem[] = [];
  for (const e of asArray(report?.serverErrors)) addProblem(problems, 'server', e.message ?? String(e), e.script);
  for (const e of asArray(report?.clientErrors)) addProblem(problems, 'client', e.message ?? String(e), e.script);
  // Output captured by the plugin (covers errors the runner could not see).
  for (const entry of asArray(final?.output)) {
    const type = String(entry.messageType ?? '');
    const msg = String(entry.message ?? '');
    if (/Error/i.test(type) && !/__GameKit|Stack Begin|Stack End|^Script '/.test(msg)) {
      if (!problems.some((p) => msg.includes(p.message))) addProblem(problems, 'output', msg);
    }
  }
  const warnings: string[] = [...new Set<string>(asArray(report?.serverWarnings).map(String))]
    .filter((w) => !/Saving is OFF|DataStore/.test(w))
    .slice(0, 15);
  const probes: Array<{ name: string; ok: boolean; detail: string }> = asArray(report?.probes);
  const failedProbes = probes.filter((p) => !p.ok);
  const facts = report?.facts && !Array.isArray(report.facts) ? report.facts : {};

  const issues: string[] = [];
  if (!report) issues.push(timedOut
    ? 'The playtest did not end by itself (the plugin could not stop it). Press Stop in Studio, then run test_game again.'
    : 'No report came back from the test runner (it may have failed to start: check that the Studio plugin is up to date).');
  if (report && !facts.characterSpawned) issues.push('The player character never spawned.');
  if (report && facts.fellIntoVoid) issues.push('The player fell into the void right after spawning: add a SpawnLocation on solid ground (build_world piece "spawn").');
  if (report && facts.aliveAfter3s === false) issues.push('The player died within 3 seconds of spawning (kill part or fall at the spawn?).');
  if (report?.clientFacts && report.clientFacts.hudPresent === false && facts.dataLoaded) issues.push('GameKit HUD did not appear on the client (HUD system not installed?).');

  const verdict = problems.length || failedProbes.length || issues.length ? 'FAIL' : 'PASS';
  return {
    verdict,
    summary: verdict === 'PASS'
      ? `Played ${seconds}s: no errors, ${probes.length} automatic checks passed.`
      : `${problems.length} error(s), ${failedProbes.length} failed check(s), ${issues.length} other issue(s). Fix them, then run test_game again.`,
    errors: problems.slice(0, 25),
    failedChecks: failedProbes,
    passedChecks: probes.filter((p) => p.ok).map((p) => `${p.name}: ${p.detail}`),
    issues,
    warnings,
    facts: { ...facts, client: report?.clientFacts },
    timedOut,
  };
}
