/**
 * `npx roblox-ultimate-mcp setup`: everything in one command, without cloning the repo.
 *   1. installs the Roblox Studio plugin (bundled with this package),
 *   2. registers the MCP server in the AI apps found on this computer
 *      (Claude Desktop, Cursor, Windsurf, OpenCode; prints the command for Claude Code),
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
  /** Config shape: { mcpServers: {...} } (most apps) or OpenCode's { mcp: {...} }. */
  format?: 'mcpServers' | 'opencode';
  command?: string;
}

export function clientConfigs(home: string = homedir(), platform: string = process.platform, env: NodeJS.ProcessEnv = process.env): ClientConfig[] {
  const appData = env.APPDATA || join(home, 'AppData', 'Roaming');
  const claudeDir = platform === 'darwin'
    ? join(home, 'Library', 'Application Support', 'Claude')
    : platform === 'win32' ? join(appData, 'Claude') : join(home, '.config', 'Claude');
  return [
    { name: 'Claude Desktop', folder: claudeDir, file: join(claudeDir, 'claude_desktop_config.json') },
    { name: 'Cursor', folder: join(home, '.cursor'), file: join(home, '.cursor', 'mcp.json') },
    { name: 'Windsurf', folder: join(home, '.codeium', 'windsurf'), file: join(home, '.codeium', 'windsurf', 'mcp_config.json') },
    // OpenCode keeps its global config in ~/.config/opencode on every system (Windows too).
    { name: 'OpenCode', folder: join(home, '.config', 'opencode'), file: join(home, '.config', 'opencode', 'opencode.json'), format: 'opencode', command: 'opencode' },
  ];
}

/**
 * Adds (or keeps) our server in an mcpServers config. Returns the new JSON text, or null
 * when nothing changes. Never drops other servers; refuses to touch invalid JSON.
 */
export function mergeServerConfig(existing: string | undefined, entry: Entry, force = false): { text: string | null; status: 'added' | 'updated' | 'present' } {
  let config: any = {};
  if (existing && existing.trim()) {
    config = JSON.parse(existing);
    if (!config || typeof config !== 'object' || Array.isArray(config)) throw new Error('not a JSON object');
  }
  config.mcpServers = config.mcpServers && typeof config.mcpServers === 'object' ? config.mcpServers : {};
  const current = config.mcpServers[SERVER_NAME];
  if (current && !force) return { text: null, status: 'present' };
  const { env, ...launch } = entry;
  config.mcpServers[SERVER_NAME] = { ...(current ?? {}), ...launch, ...(env ? { env: { ...(current?.env ?? {}), ...env } } : {}) };
  return { text: `${JSON.stringify(config, null, 2)}\n`, status: current ? 'updated' : 'added' };
}

/** OpenCode: { "mcp": { name: { type: "local", command: [...], enabled: true } } }. */
export function mergeOpenCodeConfig(existing: string | undefined, entry: Entry, force = false): { text: string | null; status: 'added' | 'updated' | 'present' } {
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
      const merge = client.format === 'opencode' ? mergeOpenCodeConfig : mergeServerConfig;
      const { text, status } = merge(before, entry, force);
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
  out.push(...(clientLines.length ? clientLines : ['  • Aucune application détectée (Claude Desktop, Cursor, Windsurf, OpenCode).']));
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

  out.push('', 'C\'est prêt. Demandez à votre IA : "Appelle roblox_start_here puis crée-moi un obby."', '');
  console.log(out.join('\n'));
}

export const HELP = `Roblox Ultimate MCP : permet à n'importe quelle IA de créer des jeux Roblox complets dans Studio.

Utilisation :
  npx roblox-ultimate-mcp setup             installe le plugin Studio et configure vos applications d'IA
  npx roblox-ultimate-mcp setup --blender   ... et l'addon Blender (modèles 3D, personnages, animations)
  npx roblox-ultimate-mcp --install-plugin  installe seulement le plugin Studio
  npx roblox-ultimate-mcp                   démarre le serveur MCP (c'est ce que lance votre application d'IA)

Options du serveur : --port <n>, --open-cloud-key <clé>, --creator-id <id>, --creator-group-id <id>
Variables : ROBLOX_MCP_PROFILE=starter|builder|full, ROBLOX_MCP_PRETTY=1, ROBLOX_MCP_HISTORY=0
`;
