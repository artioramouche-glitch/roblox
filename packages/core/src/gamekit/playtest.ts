/**
 * test_game: automated playtest. Inserts a server test runner + client probe, starts
 * Play, lets the runner play through the game a little, collects server AND client
 * errors, then cleans up and explains every problem.
 */

import { LUAU_SOURCES } from './generated/luau-sources.js';
import { asArray, install, type LuauRunner } from './installer.js';
import { hintForRuntimeError, parseRuntimeError } from './hints.js';
import { buildDeviceSimulatorLuau } from '../simulation-luau.js';

export interface PlaytestBridge extends LuauRunner {
  startPlaytest(mode: 'play' | 'run'): Promise<any>;
  stopPlaytest(): Promise<any>;
  getPlaytestOutput(): Promise<any>;
  /** Multi-client Studio test (StudioTestService.ExecuteMultiplayerTestAsync, edit peer). */
  startMultiplayerTest?(numPlayers: number): Promise<any>;
  /** { session: { phase: idle|starting|running|completed|failed, result, error } } */
  multiplayerTestState?(): Promise<any>;
  /** Ends a stuck multi-client test from its server peer. */
  endMultiplayerTest?(): Promise<any>;
}

export interface TestOptions {
  seconds?: number;
  autoplay?: boolean;
  timeoutSeconds?: number;
  /** 2-4 = server + that many clients (multiplayer test). Default 1 (solo Play). */
  players?: number;
  /** "phone" | "tablet" | a Studio device id: plays inside the device simulator and checks the UI. */
  device?: string;
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

/** Picks a built-in simulator device: the smallest phone (or tablet), landscape. */
export function pickDevice(devices: any[], wanted: string): string | undefined {
  const ids = devices.map((d) => String(d?.DeviceId ?? d?.deviceId ?? d?.Id ?? d?.id ?? d?.Name ?? '')).filter(Boolean);
  if (ids.includes(wanted)) return wanted;
  const tablet = /ipad|tab|tablet/i;
  const phone = /phone|galaxy|pixel|android|xperia|note|moto/i;
  const pool = wanted === 'tablet' ? ids.filter((id) => tablet.test(id)) : ids.filter((id) => phone.test(id) && !tablet.test(id));
  if (!pool.length) return undefined;
  // Older / smaller phones first (iPhone SE, 7, 8...) -- the hardest screens to fit.
  const rank = (id: string) => (/se\b|4s|5s|\b7\b|\b8\b|mini|small/i.test(id) ? 0 : 1);
  return [...pool].sort((a, b) => rank(a) - rank(b) || a.localeCompare(b))[0];
}

async function luauJson(runner: LuauRunner, code: string): Promise<any> {
  const reply = await runner.runLuau(code);
  if (!reply?.success) throw new Error(reply?.error ?? 'Luau failed');
  try {
    return JSON.parse(reply.returnValue ?? 'null');
  } catch {
    return null;
  }
}

/** Switches the Studio device simulator; returns a restore function (or a reason it could not). */
async function useDevice(runner: LuauRunner, wanted: string): Promise<{ deviceId?: string; restore?: () => Promise<void>; note?: string }> {
  try {
    const before = await luauJson(runner, buildDeviceSimulatorLuau('get', {}));
    const deviceId = pickDevice(asArray(before?.devices), wanted);
    if (!deviceId) return { note: `No "${wanted}" device found in the Studio device simulator.` };
    await luauJson(runner, buildDeviceSimulatorLuau('set', { settings: { deviceId, orientation: 'LandscapeRight' } }));
    const restore = async () => {
      const back = before?.isSimulating && typeof before.activeDeviceId === 'string' && before.activeDeviceId !== 'default'
        ? { settings: { deviceId: before.activeDeviceId } }
        : { stopSimulation: true };
      await luauJson(runner, buildDeviceSimulatorLuau('set', back)).catch(() => undefined);
    };
    return { deviceId, restore };
  } catch (e) {
    return { note: `Device simulator unavailable (${e instanceof Error ? e.message : String(e)}); tested on the normal screen.` };
  }
}

/** Solo Play: waits until the test runner ends the test (or stops it after the timeout). */
async function runSolo(bridge: PlaytestBridge, timeout: number): Promise<{ final: any; timedOut: boolean }> {
  await bridge.startPlaytest('play');
  const started = Date.now();
  await sleep(3000);
  for (;;) {
    let state: any;
    try {
      state = await bridge.getPlaytestOutput();
    } catch {
      state = null;
    }
    if (state && state.isRunning === false) return { final: state, timedOut: false };
    if (Date.now() - started > timeout) {
      try {
        await bridge.stopPlaytest();
      } catch {
        // ignored: reported below
      }
      await sleep(3000);
      try {
        return { final: await bridge.getPlaytestOutput(), timedOut: true };
      } catch {
        return { final: state, timedOut: true };
      }
    }
    await sleep(1500);
  }
}

/** Server + N clients: runs until the test runner ends the test, returns its report string. */
async function runMultiplayer(bridge: PlaytestBridge, players: number, timeout: number): Promise<{ result?: string; error?: string; timedOut: boolean }> {
  const start = await bridge.startMultiplayerTest!(players);
  if (start?.error) return { error: String(start.error), timedOut: false };
  const started = Date.now();
  let ended = false;
  await sleep(4000);
  for (;;) {
    let session: any = null;
    try {
      session = (await bridge.multiplayerTestState!())?.session;
    } catch {
      session = null;
    }
    if (session?.phase === 'completed') return { result: typeof session.result === 'string' ? session.result : JSON.stringify(session.result ?? null), timedOut: ended };
    if (session?.phase === 'failed') return { error: String(session.error ?? 'multiplayer test failed'), timedOut: ended };
    if (Date.now() - started > timeout) {
      if (ended) return { timedOut: true };
      ended = true;
      await bridge.endMultiplayerTest?.().catch(() => undefined);
    }
    await sleep(1500);
  }
}

export async function runPlaytest(bridge: PlaytestBridge, options: TestOptions = {}): Promise<Record<string, any>> {
  const seconds = Math.max(8, Math.min(120, options.seconds ?? 20));
  const players = Math.max(1, Math.min(4, Math.round(options.players ?? 1)));
  const multiplayer = players > 1 && !!bridge.startMultiplayerTest && !!bridge.multiplayerTestState;
  const timeout = (options.timeoutSeconds ?? seconds + (multiplayer ? 75 : 45)) * 1000;
  const notes: string[] = [];
  if (players > 1 && !multiplayer) notes.push('This server cannot start multi-client tests: tested solo instead.');

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
        node: { name: RUNNER, className: 'Script', source: LUAU_SOURCES['runtime/TestRunner.server.luau'], attrs: { Duration: seconds, Autoplay: options.autoplay !== false, Players: multiplayer ? players : 1 } },
      },
      {
        parent: ['StarterPlayer', 'StarterPlayerScripts'], mode: 'replace',
        node: { name: PROBE, className: 'LocalScript', source: LUAU_SOURCES['runtime/TestProbe.client.luau'] },
      },
    ],
  });

  let final: any = null;
  let timedOut = false;
  let restoreDevice: (() => Promise<void>) | undefined;
  let deviceId: string | undefined;
  if (options.device) {
    const used = await useDevice(bridge, options.device);
    restoreDevice = used.restore;
    deviceId = used.deviceId;
    if (used.note) notes.push(used.note);
  }
  try {
    if (multiplayer) {
      const mp = await runMultiplayer(bridge, players, timeout);
      timedOut = mp.timedOut;
      if (mp.error) notes.push(`Multiplayer test: ${mp.error}`);
      final = { testResult: mp.result, output: [] };
    } else {
      ({ final, timedOut } = await runSolo(bridge, timeout));
    }
  } finally {
    try {
      await cleanup(bridge);
    } catch {
      // The cleanup failing must not hide the test result; check_game reports leftovers.
    }
    await restoreDevice?.();
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

  // UI on small screens: every client reports buttons too small to tap and UI off the screen.
  const clients: Record<string, any> = report?.clients && !Array.isArray(report.clients) ? report.clients : {};
  const ui = { tooSmall: new Set<string>(), offscreen: new Set<string>(), tinyText: new Set<string>() };
  for (const c of [report?.clientFacts, ...Object.values(clients)]) {
    for (const key of ['tooSmall', 'offscreen', 'tinyText'] as const) for (const item of asArray(c?.ui?.[key])) ui[key].add(String(item));
  }
  const uiProblems: string[] = [];
  if (ui.offscreen.size) uiProblems.push(`UI partly off the screen: ${[...ui.offscreen].slice(0, 6).join(', ')}. Use scale sizes (UDim2.fromScale) and AnchorPoint, or a UISizeConstraint.`);
  if (ui.tooSmall.size) uiProblems.push(`Buttons too small to tap on a phone (< 32 px): ${[...ui.tooSmall].slice(0, 6).join(', ')}. Make them at least 44 px.`);
  if (ui.tinyText.size) uiProblems.push(`Text too small to read on a phone: ${[...ui.tinyText].slice(0, 6).join(', ')}. Use TextScaled or TextSize >= 14.`);
  const warningsOut = [...warnings];
  if (options.device) issues.push(...uiProblems);
  else warningsOut.push(...uiProblems);

  const verdict = problems.length || failedProbes.length || issues.length ? 'FAIL' : 'PASS';
  const how = [multiplayer ? `${players} players` : 'solo', deviceId ? `on ${deviceId}` : ''].filter(Boolean).join(' ');
  return {
    verdict,
    summary: verdict === 'PASS'
      ? `Played ${seconds}s (${how}): no errors, ${probes.length} automatic checks passed.`
      : `${problems.length} error(s), ${failedProbes.length} failed check(s), ${issues.length} other issue(s) (${how}). Fix them, then run test_game again.`,
    errors: problems.slice(0, 25),
    failedChecks: failedProbes,
    passedChecks: probes.filter((p) => p.ok).map((p) => `${p.name}: ${p.detail}`),
    issues,
    warnings: warningsOut,
    notes,
    facts: { ...facts, client: report?.clientFacts, clients: Object.keys(clients).length > 1 ? clients : undefined },
    timedOut,
  };
}
