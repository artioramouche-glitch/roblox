/**
 * `npx roblox-ultimate-mcp setup`: everything in one command, without cloning the repo.
 *   1. installs the Roblox Studio plugin (bundled with this package),
 *   2. registers the MCP server in the AI apps found on this computer (Claude Desktop, Cursor,
 *      Windsurf, OpenCode, Qoder, Gemini CLI, Antigravity, VS Code, Cline, Roo Code, Kiro,
 *      LM Studio, Codex; prints the command for Claude Code),
 *   3. with --blender, installs the "MCP for Blender" addon into the newest Blender.
 * Messages are in French: the people running it are the game creators, not the AI.
 */

import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { homedir } from 'os';
import { spawnSync } from 'child_process';

export const SERVER_NAME = 'roblox-ultimate';
const PACKAGE = 'roblox-ultimate-mcp';

type Entry = { command: string; args: string[]; env?: Record<string, string> };

/** How an AI app should start this server (npx needs "cmd /c" on Windows). */
export function serverEntry(platform: string = process.platform): Entry {
  return platform === 'win32'
    ? { command: 'cmd', args: ['/c', 'npx', '-y', `${PACKAGE}@latest`] }
    : { command: 'npx', args: ['-y', `${PACKAGE}@latest`] };
}

/**
 * Run from a downloaded zip or a git clone (not from npx/npm): the apps must start THIS copy.
 * The absolute node path matters: desktop apps (Claude Desktop on macOS) often lack node in PATH.
 */
export function localEntry(file: string = fileURLToPath(import.meta.url), node: string = process.execPath): Entry | undefined {
  if (/[\\/](node_modules|_npx)[\\/]/.test(file)) return undefined;
  return { command: node, args: [file] };
}

export interface ClientConfig {
  name: string;
  file: string;
  /** The app is installed when this folder exists (or `command` is on the PATH). */
  folder: string;
  /**
   * Config shape: { mcpServers: {...} } (most apps), OpenCode's { mcp: {...} },
   * VS Code's { servers: {...} } or Codex's TOML [mcp_servers.<name>].
   */
  format?: 'mcpServers' | 'opencode' | 'vscode' | 'codex';
  command?: string;
}

export function clientConfigs(home: string = homedir(), platform: string = process.platform, env: NodeJS.ProcessEnv = process.env): ClientConfig[] {
  const appData = env.APPDATA || join(home, 'AppData', 'Roaming');
  const claudeDir = platform === 'darwin'
    ? join(home, 'Library', 'Application Support', 'Claude')
    : platform === 'win32' ? join(appData, 'Claude') : join(home, '.config', 'Claude');
  const vscodeUser = platform === 'darwin'
    ? join(home, 'Library', 'Application Support', 'Code', 'User')
    : platform === 'win32' ? join(appData, 'Code', 'User') : join(home, '.config', 'Code', 'User');
  const extension = (id: string, file: string) => join(vscodeUser, 'globalStorage', id, 'settings', file);
  return [
    { name: 'Claude Desktop', folder: claudeDir, file: join(claudeDir, 'claude_desktop_config.json') },
    { name: 'Cursor', folder: join(home, '.cursor'), file: join(home, '.cursor', 'mcp.json') },
    { name: 'Windsurf', folder: join(home, '.codeium', 'windsurf'), file: join(home, '.codeium', 'windsurf', 'mcp_config.json') },
    // OpenCode keeps its global config in ~/.config/opencode on every system (Windows too).
    { name: 'OpenCode', folder: join(home, '.config', 'opencode'), file: join(home, '.config', 'opencode', 'opencode.json'), format: 'opencode', command: 'opencode' },
    // The Qoder app and qodercli read the user-level ~/.qoder/settings.json.
    { name: 'Qoder', folder: join(home, '.qoder'), file: join(home, '.qoder', 'settings.json'), command: 'qodercli' },
    { name: 'Gemini CLI', folder: join(home, '.gemini'), file: join(home, '.gemini', 'settings.json'), command: 'gemini' },
    { name: 'Antigravity', folder: join(home, '.gemini', 'config'), file: join(home, '.gemini', 'config', 'mcp_config.json') },
    { name: 'VS Code (Copilot)', folder: vscodeUser, file: join(vscodeUser, 'mcp.json'), format: 'vscode' },
    { name: 'Cline', folder: join(vscodeUser, 'globalStorage', 'saoudrizwan.claude-dev'), file: extension('saoudrizwan.claude-dev', 'cline_mcp_settings.json') },
    { name: 'Roo Code', folder: join(vscodeUser, 'globalStorage', 'rooveterinaryinc.roo-cline'), file: extension('rooveterinaryinc.roo-cline', 'mcp_settings.json') },
    { name: 'Kiro', folder: join(home, '.kiro'), file: join(home, '.kiro', 'settings', 'mcp.json') },
    { name: 'LM Studio', folder: join(home, '.lmstudio'), file: join(home, '.lmstudio', 'mcp.json') },
    { name: 'Codex', folder: join(home, '.codex'), file: join(home, '.codex', 'config.toml'), format: 'codex', command: 'codex' },
  ];
}

type Merged = { text: string | null; status: 'added' | 'updated' | 'present' };

/**
 * Adds (or keeps) our server in an mcpServers config (`key`: "servers" for VS Code, whose
 * entries also need a type). Returns the new JSON text, or null when nothing changes.
 * Never drops other servers; refuses to touch invalid JSON.
 */
export function mergeServerConfig(existing: string | undefined, entry: Entry, force = false, key = 'mcpServers', extra: Record<string, string> = {}): Merged {
  let config: any = {};
  if (existing && existing.trim()) {
    config = JSON.parse(existing);
    if (!config || typeof config !== 'object' || Array.isArray(config)) throw new Error('not a JSON object');
  }
  config[key] = config[key] && typeof config[key] === 'object' ? config[key] : {};
  const current = config[key][SERVER_NAME];
  if (current && !force) return { text: null, status: 'present' };
  const { env, ...launch } = entry;
  config[key][SERVER_NAME] = { ...(current ?? {}), ...extra, ...launch, ...(env ? { env: { ...(current?.env ?? {}), ...env } } : {}) };
  return { text: `${JSON.stringify(config, null, 2)}\n`, status: current ? 'updated' : 'added' };
}

/** Codex: appends a [mcp_servers.roblox-ultimate] table (TOML) unless one is already there. */
export function mergeCodexConfig(existing: string | undefined, entry: Entry): Merged {
  const before = existing ?? '';
  if (new RegExp(`^\\[mcp_servers\\.("?)${SERVER_NAME}\\1\\]`, 'm').test(before)) return { text: null, status: 'present' };
  // JSON strings are valid TOML basic strings (same escapes for \\ and \").
  const lines = [
    `[mcp_servers.${SERVER_NAME}]`,
    `command = ${JSON.stringify(entry.command)}`,
    `args = [${entry.args.map((a) => JSON.stringify(a)).join(', ')}]`,
    // Cold starts on Windows (antivirus scans) can pass the 10 s default.
    'startup_timeout_sec = 60',
  ];
  if (entry.env) lines.push('', `[mcp_servers.${SERVER_NAME}.env]`, ...Object.entries(entry.env).map(([k, v]) => `${k} = ${JSON.stringify(v)}`));
  const sep = !before ? '' : before.endsWith('\n') ? '\n' : '\n\n';
  return { text: `${before}${sep}${lines.join('\n')}\n`, status: 'added' };
}

/** OpenCode: { "mcp": { name: { type: "local", command: [...], enabled: true } } }. */
export function mergeOpenCodeConfig(existing: string | undefined, entry: Entry, force = false): Merged {
  let config: any = { $schema: 'https://opencode.ai/config.json' };
  if (existing && existing.trim()) {
    config = JSON.parse(existing);
    if (!config || typeof config !== 'object' || Array.isArray(config)) throw new Error('not a JSON object');
  }
  config.mcp = config.mcp && typeof config.mcp === 'object' ? config.mcp : {};
  const current = config.mcp[SERVER_NAME];
  if (current && !force) return { text: null, status: 'present' };
  config.mcp[SERVER_NAME] = {
    ...(current ?? {}),
    type: 'local',
    command: [entry.command, ...entry.args],
    enabled: true,
    // Cold starts on Windows (antivirus scans) can pass OpenCode's 5 s default.
    timeout: current?.timeout ?? 60000,
    ...(entry.env ? { environment: { ...(current?.environment ?? {}), ...entry.env } } : {}),
  };
  return { text: `${JSON.stringify(config, null, 2)}\n`, status: current ? 'updated' : 'added' };
}

function onPath(command: string): boolean {
  const found = spawnSync(process.platform === 'win32' ? 'where' : 'which', [command], { encoding: 'utf8' });
  return !found.error && found.status === 0;
}

function configureClients(entry: Entry, force: boolean): string[] {
  const lines: string[] = [];
  for (const client of clientConfigs()) {
    if (!existsSync(client.folder) && !(client.command && onPath(client.command))) continue;
    try {
      const before = existsSync(client.file) ? readFileSync(client.file, 'utf8') : undefined;
      if (before === undefined && client.format === 'opencode' && existsSync(`${client.file}c`)) {
        lines.push(`  ✖ ${client.name} : ta config est un fichier .jsonc (avec commentaires) : ajoute le serveur à la main (voir plus bas).`);
        continue;
      }
      const { text, status } = client.format === 'opencode' ? mergeOpenCodeConfig(before, entry, force)
        : client.format === 'codex' ? mergeCodexConfig(before, entry)
          : client.format === 'vscode' ? mergeServerConfig(before, entry, force, 'servers', { type: 'stdio' })
            : mergeServerConfig(before, entry, force);
      if (text) {
        if (before !== undefined) writeFileSync(`${client.file}.bak`, before);
        mkdirSync(dirname(client.file), { recursive: true });
        writeFileSync(client.file, text);
      }
      lines.push(`  ✔ ${client.name} : ${status === 'present' ? 'déjà configuré' : status === 'added' ? 'ajouté' : 'mis à jour'} (${client.file})${status === 'present' ? '' : ' -> redémarrez l\'application'}`);
    } catch (error) {
      lines.push(`  ✖ ${client.name} : ${client.file} n'est pas un JSON valide (${error instanceof Error ? error.message : String(error)}). Ajoutez le serveur à la main (voir plus bas).`);
    }
  }
  return lines;
}

/** Files shipped next to dist/ (package) or in the repository (git clone). */
function bundled(...parts: string[]): string | undefined {
  const here = dirname(fileURLToPath(import.meta.url));
  for (const base of [join(here, '..'), join(here, '..', '..', '..')]) {
    const candidate = join(base, ...parts);
    if (existsSync(candidate)) return candidate;
  }
  return undefined;
}

export function blenderAddonDirs(home: string = homedir(), platform: string = process.platform, env: NodeJS.ProcessEnv = process.env): string[] {
  const explicit = env.BLENDER_USER_ADDONS || env.BLENDERMCP_ADDONS_DIR;
  if (explicit) return [explicit];
  const base = platform === 'darwin'
    ? join(home, 'Library', 'Application Support', 'Blender')
    : platform === 'win32'
      ? join(env.APPDATA || join(home, 'AppData', 'Roaming'), 'Blender Foundation', 'Blender')
      : join(home, '.config', 'blender');
  if (!existsSync(base)) return [];
  return readdirSync(base)
    .filter((name) => /^\d+\.\d+/.test(name) && statSync(join(base, name)).isDirectory())
    .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
    .map((version) => join(base, version, 'scripts', 'addons'));
}

export function installBlenderAddon(): string[] {
  const source = bundled('blender', 'addon.py') ?? bundled('integrations', 'blender-mcp', 'addon.py');
  if (!source) return ['  ✖ Addon Blender introuvable dans ce paquet.'];
  const dirs = blenderAddonDirs();
  if (!dirs.length) {
    return [
      `  ✖ Aucun dossier Blender trouvé. Lancez Blender une fois puis relancez : ${localEntry() ? 'npm run setup -- --blender' : 'npx roblox-ultimate-mcp setup --blender'}`,
      `    (ou Blender > Edit > Preferences > Add-ons > Install from disk > ${source})`,
    ];
  }
  mkdirSync(dirs[0], { recursive: true });
  const target = join(dirs[0], 'blender_mcp.py');
  copyFileSync(source, target);
  const lines = [`  ✔ Addon installé : ${target}`];
  const enable = spawnSync(process.env.BLENDER_EXE || 'blender', ['--background', '--python-expr',
    "import bpy, addon_utils; addon_utils.enable('blender_mcp', default_set=True, persistent=True); bpy.ops.wm.save_userpref()"], { encoding: 'utf8', timeout: 120000 });
  lines.push(!enable.error && enable.status === 0
    ? '  ✔ Addon activé dans Blender.'
    : '  • Activez-le une fois : Blender > Edit > Preferences > Add-ons > cherchez "MCP" > cochez "Interface: MCP for Blender".');
  lines.push('  • Puis dans la vue 3D : touche N > onglet "MCP for Blender" > "Connect to MCP server".');
  return lines;
}

/** Figma desktop keeps its imported development plugins in settings.json ("localFileExtensions"). */
export function figmaSettingsFile(home: string = homedir(), platform: string = process.platform, env: NodeJS.ProcessEnv = process.env): string | undefined {
  if (platform === 'darwin') return join(home, 'Library', 'Application Support', 'Figma', 'settings.json');
  if (platform === 'win32') return join(env.APPDATA || join(home, 'AppData', 'Roaming'), 'Figma', 'settings.json');
  return undefined; // no official Figma desktop app on Linux
}

/**
 * Adds our plugin to Figma's settings, like Plugins > Development > Import plugin from manifest.
 * Figma fills in the code and UI file entries itself when it loads a manifest entry without them,
 * and gives new imports the smallest unused id (so do we).
 */
export function addFigmaPlugin(existing: string, manifest: string): { text: string | null; status: 'added' | 'present' } {
  const settings = JSON.parse(existing);
  if (!settings || typeof settings !== 'object' || Array.isArray(settings)) throw new Error('not a JSON object');
  const list: any[] = Array.isArray(settings.localFileExtensions) ? settings.localFileExtensions : [];
  const same = (p: unknown) => typeof p === 'string' && p.replace(/\\/g, '/').toLowerCase() === manifest.replace(/\\/g, '/').toLowerCase();
  if (list.some((e) => same(e?.manifestPath))) return { text: null, status: 'present' };
  const used = new Set(list.map((e) => e?.id));
  let id = 1;
  while (used.has(id)) id++;
  settings.localFileExtensions = [...list, { id, manifestPath: manifest, lastKnownName: 'Roblox MCP Bridge', lastKnownPluginId: 'roblox-ultimate-mcp-bridge' }];
  return { text: JSON.stringify(settings), status: 'added' };
}

function figmaRunning(): boolean {
  const check = process.platform === 'win32'
    ? spawnSync('tasklist', ['/FI', 'IMAGENAME eq Figma.exe', '/NH'], { encoding: 'utf8' })
    : spawnSync('pgrep', ['-x', 'Figma'], { encoding: 'utf8' });
  return !check.error && /figma/i.test(check.stdout ?? '');
}

export function installFigmaPlugin(): string[] {
  const manifest = bundled('figma-plugin', 'manifest.json');
  const settings = figmaSettingsFile();
  const manual = `Figma (bureau) > Plugins > Development > Import plugin from manifest > ${manifest ?? 'figma-plugin/manifest.json'}`;
  if (!manifest) return ['  ✖ Plugin Figma introuvable dans ce paquet.'];
  if (!settings || !existsSync(settings)) return ['  • Figma bureau introuvable : installez-le et lancez-le une fois, puis relancez cette commande.', `    (ou à la main : ${manual})`];
  const before = readFileSync(settings, 'utf8');
  let merged: ReturnType<typeof addFigmaPlugin>;
  try {
    merged = addFigmaPlugin(before, manifest);
  } catch (error) {
    return [`  ✖ ${settings} illisible (${error instanceof Error ? error.message : String(error)}). À la main : ${manual}`];
  }
  if (!merged.text) return ['  ✔ Plugin "Roblox MCP Bridge" déjà dans Figma.'];
  // Figma rewrites settings.json from memory while it runs: our line would be lost.
  if (figmaRunning()) return [`  • Fermez Figma (complètement), puis relancez : ${localEntry() ? 'npm run install-figma-plugin' : 'npx roblox-ultimate-mcp --install-figma-plugin'}`];
  writeFileSync(`${settings}.bak`, before);
  writeFileSync(settings, merged.text);
  return ['  ✔ Plugin "Roblox MCP Bridge" ajouté à Figma (rien à importer à la main).'];
}

export async function runSetup(argv: string[] = process.argv): Promise<void> {
  const force = argv.includes('--force');
  const out: string[] = ['', 'Roblox Ultimate MCP : installation', ''];

  out.push('1. Plugin Roblox Studio');
  try {
    const { installPlugin } = await import('./install-plugin.js');
    const logs: string[] = [];
    const original = console.log;
    console.log = (...args: unknown[]) => logs.push(args.join(' '));
    try {
      await installPlugin();
    } finally {
      console.log = original;
    }
    out.push(...logs.map((l) => `  ✔ ${l}`));
    out.push('  • Redémarrez Roblox Studio, ouvrez un jeu : l\'onglet Plugins affiche "MCP".');
    out.push('  • Game Settings > Security > "Allow HTTP Requests" doit être activé.');
  } catch (error) {
    out.push(`  ✖ ${error instanceof Error ? error.message : String(error)}`);
  }

  out.push('', '2. Applications d\'IA');
  // --blender: always list the blender_* tools (some apps never refresh their tool list).
  const base = localEntry() ?? serverEntry();
  const entry: Entry = argv.includes('--blender') ? { ...base, env: { ROBLOX_MCP_BLENDER: '1' } } : base;
  const clientLines = configureClients(entry, force);
  out.push(...(clientLines.length ? clientLines : [`  • Aucune application détectée (${clientConfigs().map((c) => c.name).join(', ')}).`]));
  const quote = (part: string) => (/\s/.test(part) ? `"${part}"` : part);
  const envFlags = Object.entries(entry.env ?? {}).map(([k, v]) => `-e ${k}=${v} `).join('');
  out.push(`  • Claude Code : claude mcp add ${SERVER_NAME} ${envFlags}-- ${[entry.command, ...entry.args].map(quote).join(' ')}`);
  out.push('  • Autre application : ajoutez ce serveur MCP :');
  const { env, ...launch } = entry;
  out.push(`    ${JSON.stringify({ mcpServers: { [SERVER_NAME]: { ...launch, ...(env ? { env } : {}) } } })}`);
  out.push('  • OpenCode (opencode.json) :');
  out.push(`    ${JSON.stringify({ mcp: { [SERVER_NAME]: { type: 'local', command: [entry.command, ...entry.args], enabled: true, timeout: 60000, ...(env ? { environment: env } : {}) } } })}`);

  if (argv.includes('--blender')) {
    out.push('', '3. Blender');
    out.push(...installBlenderAddon());
  } else {
    out.push('', `3. Blender (facultatif) : ${localEntry() ? 'npm run setup -- --blender' : 'npx roblox-ultimate-mcp setup --blender'}`);
  }

  // Figma's own MCP server refuses most apps (OpenCode, Qoder...): the plugin works in all of them.
  out.push('', '4. Figma (interfaces de jeu, facultatif)');
  out.push(...installFigmaPlugin());
  out.push('  • Une fois par fichier Figma : Plugins > Development > "Roblox MCP Bridge". Ensuite (Windows) il se relance tout seul à l\'ouverture du fichier.');
  out.push('  • En plus, pour Claude Code (MCP officiel de Figma) : claude mcp add --transport http figma https://mcp.figma.com/mcp');

  out.push('', 'C\'est prêt. Demandez à votre IA : "Appelle roblox_start_here puis crée-moi un obby."', '');
  console.log(out.join('\n'));
}

export const HELP = `Roblox Ultimate MCP : permet à n'importe quelle IA de créer des jeux Roblox complets dans Studio.

Utilisation :
  npx roblox-ultimate-mcp setup             installe le plugin Studio et configure vos applications d'IA
  npx roblox-ultimate-mcp setup --blender   ... et l'addon Blender (modèles 3D, personnages, animations)
  npx roblox-ultimate-mcp doctor            vérifie tout (Node, serveur, Studio, Blender) et dit quoi corriger
  npx roblox-ultimate-mcp --install-plugin  installe seulement le plugin Studio
  npx roblox-ultimate-mcp --install-figma-plugin  ajoute seulement le plugin "Roblox MCP Bridge" à Figma (Figma fermé)
  npx roblox-ultimate-mcp                   démarre le serveur MCP (c'est ce que lance votre application d'IA)

Options du serveur : --port <n>, --open-cloud-key <clé>, --creator-id <id>, --creator-group-id <id>
Variables : ROBLOX_MCP_PROFILE=starter|builder|full, ROBLOX_MCP_PRETTY=1, ROBLOX_MCP_HISTORY=0
`;
