/**
 * design_refs: searches a local visual reference library (the "roblox-ai" collection: ~6,000
 * pictures of Roblox UI styles, VFX, animations, thumbnails by genre, Studio docs) so the AI
 * starts a design from real references instead of a vague description. The pictures stay
 * on disk; the tool returns their paths (and, with show, the first few as images).
 */

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import type { ToolDef } from './tools.js';
import { text, withImages, type ToolResult } from './result.js';

export const REFS_TOOLS: ToolDef[] = [
  {
    name: 'design_refs',
    category: 'read',
    tier: 'starter',
    description: 'Find reference pictures BEFORE designing UI, VFX, thumbnails, logos, animations or a game look: searches the local roblox-ai library (UI styles, VFX, game thumbnails by genre...). Returns image paths for Figma, Gemini prompts, look_at_game {reference} or blender_assets {images}. No query = what the library holds.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'What you design, in English: "simulator shop", "neon hud", "fireball explosion", "horror thumbnail", "codes redeem box"' },
        limit: { type: 'number', description: 'Folders to return (default 6, max 12)' },
        show: { type: 'boolean', description: 'Also attach the first 3 pictures (for models that can see images)' },
      },
      required: [],
    },
  },
];

const IMAGE = /\.(png|jpe?g|gif|webp)$/i;
const MIME: Record<string, string> = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp' };

/** Which folders to start from for a kind of work (from the library's own README). */
const WORKFLOWS: Record<string, string[]> = {
  'game HUD and menus': ['ui-styles', 'visual-refs', 'previews/*-user-interface', 'style-refs'],
  'game identity (icon, thumbnail, logo)': ['logos', 'thumbnails', 'game-refs'],
  'character movement': ['animations', 'visual-refs/animation-refs'],
  'combat and ability effects': ['vfx', 'previews/vfx-*', 'previews/effects-*'],
  'cinematic intro and dialogue': ['cutscenes', 'previews/cinematic', 'previews/cutscene'],
  'how to do it in Studio': ['roblox-docs'],
  'consistent art direction': ['style-refs', 'game-refs'],
};

interface Folder {
  rel: string;
  words: string[];
  title?: string;
  about?: string;
  images: string[];
}

/** Where the library is: ROBLOX_REFS_DIR, else the usual download places. */
export function findLibrary(env: NodeJS.ProcessEnv = process.env, home: string = os.homedir()): string | undefined {
  // shortcut: fixed list of guesses, set ROBLOX_REFS_DIR when the library lives elsewhere.
  const candidates = [
    env.ROBLOX_REFS_DIR,
    path.join(home, 'Downloads', 'roblox-ai-main', 'roblox-ai-main'),
    path.join(home, 'Downloads', 'roblox-ai-main'),
    path.join(home, 'Downloads', 'roblox-ai'),
    path.join(home, 'Documents', 'roblox-ai'),
    path.join(home, 'roblox-ai'),
  ];
  return candidates.find((dir) => !!dir && fs.existsSync(path.join(dir, 'ui-styles')) && fs.existsSync(path.join(dir, 'vfx')));
}

const words = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim().split(' ').filter((w) => w && !/^\d+$/.test(w));

/** Title and first real sentence of a folder README (skips "N images in this folder."). */
function readme(dir: string): { title?: string; about?: string } {
  const file = path.join(dir, 'README.md');
  if (!fs.existsSync(file)) return {};
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/).map((l) => l.trim());
  const title = lines.find((l) => l.startsWith('# '))?.slice(2);
  const about = lines.find((l) => l && !/^[#!|[]/.test(l) && !/^\d+ (images?|thumbnails?)\b/i.test(l) && !/^Pictures belong/.test(l));
  return { title, about };
}

let cache: { root: string; folders: Folder[] } | undefined;

export function indexLibrary(root: string): Folder[] {
  if (cache?.root === root) return cache.folders;
  const folders: Folder[] = [];
  const walk = (dir: string) => {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    // Original mockups first: they show a whole screen in one style.
    const images = entries.filter((e) => e.isFile() && IMAGE.test(e.name)).map((e) => path.join(dir, e.name))
      .sort((a, b) => Number(/mockup/i.test(path.basename(b))) - Number(/mockup/i.test(path.basename(a))));
    if (images.length) {
      const rel = path.relative(root, dir).split(path.sep).join('/');
      folders.push({ rel, words: words(rel), ...readme(dir), images });
    }
    for (const e of entries) if (e.isDirectory() && !e.name.startsWith('.')) walk(path.join(dir, e.name));
  };
  walk(root);
  cache = { root, folders };
  return folders;
}

/** Folders ranked by how many query words their path, title, description and file names hold. */
export function searchLibrary(folders: Folder[], query: string, limit = 6): Array<Folder & { score: number }> {
  const q = words(query).map((w) => w.replace(/s$/, ''));
  if (!q.length) return [];
  const scored = folders.map((f) => {
    const own = new Set([...f.words, ...words(f.title ?? '')].map((w) => w.replace(/s$/, '')));
    const about = new Set(words(f.about ?? '').map((w) => w.replace(/s$/, '')));
    const files = new Set(f.images.flatMap((i) => words(path.basename(i))).map((w) => w.replace(/s$/, '')));
    let score = 0;
    for (const w of q) score += own.has(w) ? 3 : about.has(w) ? 2 : files.has(w) ? 1 : 0;
    // Studio docs are thousands of tutorial screenshots: only when nothing else matches as well.
    if (f.rel.startsWith('roblox-docs')) score -= 1;
    return { ...f, score };
  });
  return scored.filter((f) => f.score > 0).sort((a, b) => b.score - a.score || a.rel.localeCompare(b.rel)).slice(0, limit);
}

export function designRefs(args: Record<string, any>, locate: () => string | undefined = findLibrary): ToolResult {
  const root = locate();
  if (!root) {
    return text({
      ok: false,
      problem: 'The reference library was not found.',
      fix: 'Download the "roblox-ai" visual reference library (zip from GitHub), unzip it, then set ROBLOX_REFS_DIR=<its folder> in this MCP server\'s config and restart the AI app. Default places checked: Downloads/roblox-ai-main.',
      meanwhile: 'Give the user a Gemini or Claude Design prompt instead (roblox_guide design).',
    });
  }
  const folders = indexLibrary(root);
  const query = String(args.query ?? '').trim();
  if (!query) {
    const top = new Map<string, number>();
    for (const f of folders) top.set(f.rel.split('/')[0], (top.get(f.rel.split('/')[0]) ?? 0) + f.images.length);
    return text({
      ok: true,
      library: root,
      collections: Object.fromEntries([...top].sort((a, b) => b[1] - a[1])),
      startFrom: WORKFLOWS,
      next: 'design_refs { query: "<what you design>" }, e.g. "simulator shop", "neon hud", "fireball", "horror thumbnail".',
    });
  }
  const limit = Math.min(12, Math.max(1, Number(args.limit) || 6));
  const found = searchLibrary(folders, query, limit);
  if (!found.length) {
    return text({ ok: false, library: root, problem: `Nothing matches "${query}".`, try: 'Shorter English words (hud, shop, button, fire, slash, thumbnail, horror, simulator), or design_refs {} for the collections.' });
  }
  const results = found.map((f) => ({ folder: f.rel, title: f.title, about: f.about, images: f.images.slice(0, 4), more: Math.max(0, f.images.length - 4) || undefined }));
  const summary = {
    ok: true,
    query,
    results,
    use: [
      'Pick 1-3 pictures and tell the user which details to follow (layout, colors, shapes) and which to change.',
      'UI: figma { action: "draw" } a first version in that style, or build_ui directly; game look or 3D: Gemini prompt with the picture attached, blender_assets { images }, look_at_game { reference }.',
      'References are inspiration: never copy another game\'s logo, characters or artwork.',
    ],
  };
  if (!args.show) return text(summary);
  const images = found.flatMap((f) => f.images.slice(0, 1).map((file) => ({ file, folder: f.rel })))
    .filter(({ file }) => fs.statSync(file).size <= 2_000_000)
    .slice(0, 3)
    .map(({ file, folder }) => ({ label: `${folder}: ${path.basename(file)}`, data: fs.readFileSync(file).toString('base64'), mimeType: MIME[path.extname(file).toLowerCase()] }));
  return withImages(summary, images);
}
