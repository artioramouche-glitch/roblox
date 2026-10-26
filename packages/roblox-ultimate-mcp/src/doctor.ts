/**
 * `roblox-ultimate-mcp doctor` (npm run doctor): checks every link a person can get wrong,
 * in plain French, without any AI app: Node version, the MCP server really starting and
 * listing its tools over stdio (exactly like an AI app starts it), Roblox Studio's plugin,
 * and the Blender addon (it must answer a real command, not just accept a connection).
 */

import net from 'node:net';
import { fileURLToPath } from 'node:url';

const ok = (text: string) => `  ✔ ${text}`;
const bad = (text: string) => `  ✖ ${text}`;
const tip = (text: string) => `    → ${text}`;

/** Sends one command to the Blender addon and waits for its JSON reply. */
export function askBlender(port = Number(process.env.BLENDER_PORT || 9876), host = process.env.BLENDER_HOST || '127.0.0.1', timeoutMs = 5000): Promise<{ ok: boolean; detail: string }> {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port });
    let buffer = '';
    let settled = false;
    const done = (result: { ok: boolean; detail: string }) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(result);
    };
    socket.setTimeout(timeoutMs, () => done({ ok: false, detail: 'connexion acceptée mais Blender ne répond pas (occupé, ou un autre programme utilise ce port)' }));
    socket.once('connect', () => socket.write(JSON.stringify({ type: 'get_scene_info', params: {} })));
    socket.on('data', (chunk) => {
      buffer += chunk.toString('utf8');
      try {
        const reply = JSON.parse(buffer);
        const objects = reply?.result?.object_count ?? reply?.result?.objects?.length;
        done({ ok: reply?.status === 'success', detail: reply?.status === 'success' ? `${objects ?? '?'} objet(s) dans la scène` : String(reply?.message ?? 'error') });
      } catch {
        // wait for the rest of the reply
      }
    });
    socket.once('error', (error: NodeJS.ErrnoException) => done({ ok: false, detail: error.code === 'ECONNREFUSED' ? 'rien n\'écoute sur ce port' : error.message }));
  });
}

export async function runDoctor(): Promise<void> {
  const out: string[] = ['', 'Roblox Ultimate MCP : diagnostic', ''];
  const print = () => console.log(out.splice(0).join('\n'));

  const major = Number(process.versions.node.split('.')[0]);
  out.push('1. Node.js');
  out.push(major >= 18 ? ok(`version ${process.version}`) : bad(`version ${process.version} : il faut la version 18 ou plus (nodejs.org, LTS)`));
  out.push(tip(`Chemin à mettre dans ton appli d'IA : ${process.execPath}`));
  print();

  out.push('', '2. Serveur MCP (démarré comme le fait ton appli d\'IA)');
  const server = fileURLToPath(new URL('./index.js', import.meta.url));
  out.push(tip(`Fichier du serveur : ${server}`));
  let studioConnected = false;
  try {
    const { Client } = await import('@modelcontextprotocol/sdk/client/index.js');
    const { StdioClientTransport } = await import('@modelcontextprotocol/sdk/client/stdio.js');
    const env: Record<string, string> = {};
    for (const [key, value] of Object.entries(process.env)) if (typeof value === 'string') env[key] = value;
    const transport = new StdioClientTransport({ command: process.execPath, args: [server], env, stderr: 'ignore' });
    const client = new Client({ name: 'doctor', version: '1' });
    const started = Date.now();
    await client.connect(transport);
    const { tools } = await client.listTools();
    const seconds = (Date.now() - started) / 1000;
    out.push(ok(`il démarre en ${seconds.toFixed(1)} s et propose ${tools.length} outils`));
    if (seconds > 4) out.push(tip('Démarrage lent : dans OpenCode, ajoute "timeout": 60000 à ce serveur.'));
    const blenderTools = tools.filter((t) => t.name.startsWith('blender_')).length;
    out.push(blenderTools > 2 ? ok(`${blenderTools} outils Blender listés`) : tip('Outils Blender cachés tant que Blender ne répond pas : ajoute ROBLOX_MCP_BLENDER=1 (OpenCode : "environment").'));
    print();

    out.push('', '3. Roblox Studio');
    // The plugin polls with a back-off: give it a few seconds to find this server.
    for (let attempt = 0; attempt < 8 && !studioConnected; attempt++) {
      const result: any = await client.callTool({ name: 'roblox_start_here', arguments: {} });
      try {
        studioConnected = JSON.parse(result?.content?.[0]?.text ?? '{}')?.studio?.connected === true;
      } catch {
        studioConnected = false;
      }
      if (!studioConnected) await new Promise((r) => setTimeout(r, 1500));
    }
    out.push(studioConnected
      ? ok('le plugin Studio est connecté')
      : bad('le plugin Studio n\'est pas connecté'));
    if (!studioConnected) {
      out.push(tip('Studio ouvert avec un jeu ? Paramètres du jeu > Sécurité > Autoriser les requêtes HTTP.'));
      out.push(tip('Onglet Plugins > MCP Server > Connect. Pas de bouton ? Relance : npm run setup'));
    }
    await client.close();
  } catch (error) {
    out.push(bad(`le serveur ne démarre pas : ${error instanceof Error ? error.message : String(error)}`));
    out.push(tip('Refais « npm install » dans ce dossier (il compile le serveur), puis relance ce diagnostic.'));
  }
  print();

  out.push('', '4. Blender (port 9876)');
  const blender = await askBlender();
  if (blender.ok) {
    out.push(ok(`l'addon répond : ${blender.detail}`));
  } else {
    out.push(bad(`pas de réponse : ${blender.detail}`));
    out.push(tip('Blender ouvert ? Edit > Preferences > Add-ons : UN SEUL addon « MCP » coché.'));
    out.push(tip('Vue 3D : touche N > onglet « MCP for Blender » > « Connect to MCP server ».'));
  }
  out.push('', 'Copie ce résultat à ton assistant si quelque chose est en ✖.', '');
  print();
}
