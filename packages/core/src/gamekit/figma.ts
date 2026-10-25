/**
 * Figma bridge: UI screens designed in Figma become Roblox ScreenGuis, and the AI can draw
 * a build_ui spec in Figma for the user to adjust. It works from ANY MCP client (OpenCode,
 * Qoder, Cursor, local models) and on the free Figma plan: no Figma API key and no Figma
 * MCP server, just the small "Roblox MCP Bridge" development plugin (figma-plugin/) that
 * polls this server on localhost like the Studio plugin does.
 *
 *   plugin  --GET /figma/poll-->   server   (commands: read the selection, draw ops)
 *   plugin  --POST /figma/result-> server   (the selection as a node tree, or what it drew)
 *   tool    --POST /figma/command-> server  (any MCP process, primary or proxy)
 *
 * The conversions (Figma tree -> build_ui spec, spec -> drawing ops) live here so they are
 * tested in TypeScript; the plugin only serializes and draws.
 */

import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import type { Express, Request as HttpRequest, Response as HttpResponse } from 'express';
import type { ToolDef } from './tools.js';
import type { UiNode, UiSpec } from './ui.js';
import { text, type ToolResult } from './result.js';

export const FIGMA_TOOLS: ToolDef[] = [
  {
    name: 'figma',
    category: 'write',
    tier: 'starter',
    description: 'Design game UI in Figma (any AI, free plan, through the "Roblox MCP Bridge" Figma plugin). "draw" { spec }: puts a build_ui spec in Figma as a mockup the user can adjust. "read": the selected Figma frame as a build_ui spec. "import": read + build it in Studio in one call. "status": is the plugin running. See roblox_guide figma.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['status', 'read', 'import', 'draw'], description: 'default status' },
        spec: { type: 'object', description: 'draw: a build_ui spec { name, children: [...] }' },
        canvas: { type: 'array', items: { type: 'number' }, description: 'draw: screen size in Figma, default [1280, 720] (phone: [844, 390])' },
        name: { type: 'string', description: 'read/import: name of the ScreenGui (default: the Figma frame name)' },
        as: { type: 'string', enum: ['screen', 'panel'], description: 'read/import: the frame is a whole screen (children placed in screen fractions) or one panel (centered, pixel size). Default: screen when >= 800x450' },
      },
      required: [],
    },
  },
];

// ---------------------------------------------------------------- Figma -> build_ui

/** What the plugin sends for each layer (positions relative to the parent it is nested in). */
export interface FigmaNode {
  type: string;
  name: string;
  x: number;
  y: number;
  width: number;
  height: number;
  visible?: boolean;
  opacity?: number;
  fills?: FigmaPaint[];
  strokes?: FigmaPaint[];
  strokeWeight?: number;
  cornerRadius?: number;
  characters?: string;
  fontSize?: number;
  fontFamily?: string;
  fontStyle?: string;
  textAlign?: string;
  layoutMode?: string;
  itemSpacing?: number;
  padding?: number;
  primaryAlign?: string;
  /** PNG export (base64) for pictures, icons and vectors. */
  png?: string;
  children?: FigmaNode[];
}

export interface FigmaPaint {
  type: string;
  visible?: boolean;
  opacity?: number;
  color?: { r: number; g: number; b: number };
  stops?: Array<{ color: { r: number; g: number; b: number } }>;
}

export interface FigmaImport {
  spec: UiSpec;
  /** Pictures to put on ImageLabels: where in the ScreenGui, and the PNG (base64). */
  images: Array<{ path: string; png: string }>;
  warnings: string[];
}

const hex = (c: { r: number; g: number; b: number }) =>
  `#${[c.r, c.g, c.b].map((v) => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, '0')).join('').toUpperCase()}`;

const visiblePaint = (paints: FigmaPaint[] | undefined, type?: RegExp) =>
  (paints ?? []).find((p) => p.visible !== false && (p.opacity ?? 1) > 0 && (!type || type.test(p.type)));

/** Roblox Enum.Font for a Figma family (+ bold), or undefined when Roblox has nothing close. */
export function robloxFont(family: string | undefined, style = ''): string | undefined {
  if (!family) return undefined;
  const key = family.toLowerCase().replace(/[^a-z0-9]/g, '');
  const bold = /bold|black|heavy|extra/i.test(style);
  const black = /black|heavy/i.test(style);
  const same: Record<string, string> = {
    fredokaone: 'FredokaOne', fredoka: 'FredokaOne', luckiestguy: 'LuckiestGuy', bangers: 'Bangers', nunito: 'Nunito',
    oswald: 'Oswald', ubuntu: 'Ubuntu', titilliumweb: 'TitilliumWeb', permanentmarker: 'PermanentMarker', creepster: 'Creepster',
    denkone: 'DenkOne', michroma: 'Michroma', kalam: 'Kalam', jura: 'Jura', sarpanch: 'Sarpanch', merriweather: 'Merriweather',
    josefinsans: 'JosefinSans', indieflower: 'IndieFlower', amaticsc: 'AmaticSC', specialelite: 'SpecialElite',
    grenzegotisch: 'GrenzeGotisch', fondamento: 'Fondamento', patrickhand: 'PatrickHand', roboto: 'Roboto',
    robotomono: 'RobotoMono', robotocondensed: 'RobotoCondensed', pressstart2p: 'Arcade', silkscreen: 'Arcade',
  };
  if (same[key]) return same[key];
  if (key === 'gotham' || key === 'montserrat') return black ? 'GothamBlack' : bold ? 'GothamBold' : 'Gotham';
  if (key.startsWith('sourcesans')) return bold ? 'SourceSansBold' : 'SourceSans';
  if (key === 'arimo') return bold ? 'ArimoBold' : 'Arimo';
  if (['inter', 'sfpro', 'sfprodisplay', 'sfprotext', 'helvetica', 'helveticaneue', 'arial', 'opensans', 'lato', 'poppins', 'builder', 'buildersans'].includes(key)) {
    return bold ? 'BuilderSansBold' : 'BuilderSans';
  }
  return undefined;
}

/** "Shop Button [toggle:ShopWindow] [showIf:state:RoundActive]" -> name + behaviour. */
export function parseLayerName(raw: string): { name: string; extra: Partial<UiNode> } {
  const extra: Partial<UiNode> = {};
  const name = raw.replace(/\[([a-zA-Z]+):([^\]]+)\]/g, (_, key: string, value: string) => {
    const k = key.toLowerCase();
    // Windows are named like layers ("Shop Window" -> ShopWindow): their targets must match.
    if (['toggle', 'open', 'close'].includes(k)) extra.action = `${k}:${instanceName(value)}`;
    else if (k === 'remote') extra.action = `remote:${value.trim()}`;
    else if (k === 'action') extra.action = value.trim();
    else if (k === 'bind') extra.bind = value.trim();
    else if (k === 'bar') extra.bar = value.trim();
    else if (k === 'showif') extra.showIf = value.trim();
    return '';
  }).replace(/\[[a-zA-Z]+\]/g, '');
  return { name: instanceName(name), extra };
}

/** "shop window" -> "ShopWindow" (a valid, readable instance name). */
function instanceName(raw: string): string {
  const clean = raw.trim().split(/[^A-Za-z0-9_]+/).filter(Boolean).map((w) => w[0].toUpperCase() + w.slice(1)).join('');
  return (/^[0-9]/.test(clean) ? `N${clean}` : clean) || 'Layer';
}

const BUTTON = /button|bouton|\bbtn\b/i;
const SHAPES = new Set(['FRAME', 'GROUP', 'COMPONENT', 'COMPONENT_SET', 'INSTANCE', 'RECTANGLE', 'ELLIPSE', 'SECTION']);
const round = (n: number) => Math.round(n * 10000) / 10000;

export function figmaToSpec(root: FigmaNode, options: { name?: string; as?: 'screen' | 'panel' } = {}): FigmaImport {
  const images: FigmaImport['images'] = [];
  const warnings: string[] = [];
  const fonts = new Set<string>();

  const convert = (node: FigmaNode, parent: { width: number; height: number }, inLayout: boolean, index: number, at: string[]): UiNode | undefined => {
    const { name, extra } = parseLayerName(node.name);
    const hasPicture = !!node.png;
    if (!hasPicture && node.type !== 'TEXT' && !SHAPES.has(node.type)) {
      warnings.push(`"${node.name}" (${node.type}) skipped: export it as an image in Figma (or name it "... [image]").`);
      return undefined;
    }
    const pw = parent.width || 1;
    const ph = parent.height || 1;
    const out: UiNode = { type: 'frame', name, size: [round(node.width / pw), 0, round(node.height / ph), 0], ...extra };
    if (!inLayout) out.position = [round(node.x / pw), 0, round(node.y / ph), 0];
    else out.order = index;
    out.zIndex = index + 1;
    if (node.visible === false) out.visible = false;
    const alpha = node.opacity ?? 1;

    const fill = visiblePaint(node.fills, /^SOLID$/);
    const gradient = visiblePaint(node.fills, /^GRADIENT_LINEAR$/);

    if (node.type === 'TEXT') {
      out.type = 'label';
      out.text = node.characters ?? '';
      const stat = /\{(stat|state):([A-Za-z0-9_]+)\}/.exec(out.text);
      if (stat && !out.bind) {
        out.bind = `${stat[1]}:${stat[2]}`;
        out.format = out.text.replace(stat[0], '{value}');
        if (out.format === '{value}') delete out.format;
      }
      if (fill?.color) out.textColor = hex(fill.color);
      if (node.fontSize) out.maxTextSize = Math.round(node.fontSize);
      const font = robloxFont(node.fontFamily, node.fontStyle);
      if (font) out.font = font;
      else if (node.fontFamily) fonts.add(node.fontFamily);
      const align = (node.textAlign ?? '').toUpperCase();
      if (align === 'LEFT' || align === 'RIGHT') out.textAlign = align === 'LEFT' ? 'left' : 'right';
      return out;
    }

    const isButton = BUTTON.test(node.name) || /^(toggle|open|close|remote):/.test(out.action ?? '');
    if (hasPicture) {
      out.type = isButton ? 'imagebutton' : 'image';
      out.image = '';
      out.aspect = round(node.width / (node.height || 1));
      images.push({ path: [...at, name].join('/'), png: node.png! });
      return out;
    }

    if (fill?.color) {
      out.color = hex(fill.color);
      out.transparency = round(1 - (fill.opacity ?? 1) * alpha);
    } else if (gradient?.stops && gradient.stops.length >= 2) {
      out.gradient = [hex(gradient.stops[0].color), hex(gradient.stops[gradient.stops.length - 1].color)];
      out.color = '#FFFFFF';
      out.transparency = round(1 - (gradient.opacity ?? 1) * alpha);
    } else {
      out.transparency = 1;
    }
    const half = Math.ceil(Math.min(node.width, node.height) / 2);
    out.corner = node.type === 'ELLIPSE' ? half : Math.min(half, Math.round(node.cornerRadius ?? 0));
    if (node.type === 'ELLIPSE') out.aspect = round(node.width / (node.height || 1));
    const stroke = visiblePaint(node.strokes, /^SOLID$/);
    if (stroke?.color && (node.strokeWeight ?? 1) > 0) out.stroke = hex(stroke.color);
    if (node.layoutMode === 'HORIZONTAL' || node.layoutMode === 'VERTICAL') {
      out.layout = node.layoutMode === 'HORIZONTAL' ? 'horizontal' : 'vertical';
      out.gap = Math.round(node.itemSpacing ?? 0);
      if (node.padding) out.padding = Math.round(node.padding);
      const a = (node.primaryAlign ?? '').toUpperCase();
      out.align = a === 'MIN' ? 'start' : a === 'MAX' ? 'end' : 'center';
    }

    // build_ui draws the fill and the text of a bar itself.
    if (out.bar) return { ...out, type: 'bar' };

    let kids = node.children ?? [];
    if (isButton) {
      out.type = 'button';
      // A Figma button is a shape with its label inside: the label becomes the button text.
      const labels = kids.filter((k) => k.type === 'TEXT');
      if (labels.length === 1) {
        const label = labels[0];
        out.text = label.characters ?? '';
        const color = visiblePaint(label.fills, /^SOLID$/)?.color;
        if (color) out.textColor = hex(color);
        if (label.fontSize) out.maxTextSize = Math.round(label.fontSize);
        const font = robloxFont(label.fontFamily, label.fontStyle);
        if (font) out.font = font;
        kids = kids.filter((k) => k !== label);
      } else {
        out.text = '';
      }
    }
    const children = kids
      .map((k, i) => convert(k, node, !!out.layout, i, [...at, name]))
      .filter((c): c is UiNode => !!c);
    if (children.length) out.children = children;
    return out;
  };

  const screen = options.as ? options.as === 'screen' : root.width >= 800 && root.height >= 450;
  const guiName = parseLayerName(options.name ?? root.name).name;
  let children: UiNode[];
  if (screen) {
    // The frame is the screen: its own background is usually a game screenshot, not UI.
    if (visiblePaint(root.fills)) warnings.push(`The background of "${root.name}" is not imported (it is the screen). Put panels in their own frames.`);
    children = (root.children ?? [])
      .map((k, i) => convert(k, root, false, i, ['StarterGui', guiName]))
      .filter((c): c is UiNode => !!c);
  } else {
    const panel = convert({ ...root, x: 0, y: 0 }, root, false, 0, ['StarterGui', guiName]);
    if (panel) {
      panel.size = [0, Math.round(root.width), 0, Math.round(root.height)];
      panel.position = 'center';
      children = [panel];
    } else {
      children = [];
    }
  }
  if (fonts.size) warnings.push(`No Roblox font close to ${[...fonts].join(', ')}: FredokaOne is used. Roblox fonts: Gotham, BuilderSans, FredokaOne, LuckiestGuy, Bangers, Roboto, Oswald...`);
  return { spec: { name: guiName, children }, images, warnings };
}

// ---------------------------------------------------------------- build_ui -> Figma

export interface DrawOp {
  parent: number;
  kind: 'frame' | 'text' | 'image';
  name: string;
  x: number;
  y: number;
  w: number;
  h: number;
  fill?: string;
  fillOpacity?: number;
  gradient?: string[];
  corner?: number;
  stroke?: string;
  text?: string;
  textColor?: string;
  fontSize?: number;
  bold?: boolean;
  align?: string;
  layout?: 'HORIZONTAL' | 'VERTICAL';
  gap?: number;
  padding?: number;
  visible?: boolean;
}

const PRESET_ANCHORS: Record<string, [number, number, number, number, number, number]> = {
  // anchorX, anchorY, scaleX, offsetX, scaleY, offsetY (same as build_ui)
  center: [0.5, 0.5, 0.5, 0, 0.5, 0], top: [0.5, 0, 0.5, 0, 0, 12], bottom: [0.5, 1, 0.5, 0, 1, -12],
  left: [0, 0.5, 0, 12, 0.5, 0], right: [1, 0.5, 1, -12, 0.5, 0], 'top-left': [0, 0, 0, 12, 0, 12],
  'top-right': [1, 0, 1, -12, 0, 12], 'bottom-left': [0, 1, 0, 12, 1, -12], 'bottom-right': [1, 1, 1, -12, 1, -12],
};

/** build_ui size rules: [w, h] <= 1 = fraction, bigger = pixels; 4 numbers = UDim2. */
function measure(size: number[] | undefined, fallback: number[], pw: number, ph: number): [number, number] {
  const s = size && size.length >= 4 ? size : size && size.length >= 2
    ? [size[0] <= 1 ? size[0] : 0, size[0] <= 1 ? 0 : size[0], size[1] <= 1 ? size[1] : 0, size[1] <= 1 ? 0 : size[1]]
    : fallback;
  return [s[0] * pw + s[1], s[2] * ph + s[3]];
}

/** Flattens a build_ui spec into absolute rectangles Figma can draw (index 0 = the screen). */
export function specToFigma(spec: UiSpec, canvas: number[] = [1280, 720]): DrawOp[] {
  const [cw, ch] = [Number(canvas[0]) || 1280, Number(canvas[1]) || 720];
  const ops: DrawOp[] = [{ parent: -1, kind: 'frame', name: spec.name || 'Screen', x: 0, y: 0, w: cw, h: ch, fill: '#2B2D31', fillOpacity: 1 }];

  const place = (node: UiNode, parentIndex: number, pw: number, ph: number, rect?: { x: number; y: number }) => {
    const type = node.type ?? 'frame';
    const fallback = type === 'button' ? [0, 160, 0, 48] : type === 'label' ? [0, 200, 0, 36] : [0.3, 0, 0.3, 0];
    const [w, h] = measure(node.size, fallback, pw, ph);
    let x = rect?.x ?? 0;
    let y = rect?.y ?? 0;
    if (!rect) {
      if (typeof node.position === 'string' && PRESET_ANCHORS[node.position]) {
        const [ax, ay, sx, ox, sy, oy] = PRESET_ANCHORS[node.position];
        x = sx * pw + ox - ax * w;
        y = sy * ph + oy - ay * h;
      } else if (Array.isArray(node.position) && node.position.length >= 2) {
        const p = node.position.length >= 4 ? node.position : [node.position[0], 0, node.position[1], 0];
        const [ax, ay] = node.anchor ?? [0, 0];
        x = p[0] * pw + p[1] - ax * w;
        y = p[2] * ph + p[3] - ay * h;
      }
    }
    const tags = [
      node.action && /^(toggle|open|close|remote):/.test(node.action) ? `[${node.action}]` : node.action ? `[action:${node.action}]` : '',
      node.showIf ? `[showIf:${node.showIf}]` : '',
      node.bar ? `[bar:${node.bar}]` : '',
    ].filter(Boolean).join(' ');
    const base = node.name ?? type;
    const label = (): Partial<DrawOp> => ({
      // A bound text shows its binding, so reading it back restores bind + format.
      text: node.bind ? (node.format ?? '{value}').replace('{value}', `{${node.bind}}`) : node.text ?? '',
      fontSize: Math.max(8, Math.round(Math.min(node.maxTextSize ?? (type === 'button' ? 28 : 32), h * 0.7))),
      bold: type === 'button',
      align: node.textAlign?.toUpperCase() ?? 'CENTER',
      textColor: node.textColor ?? (type === 'button' && !node.color ? '#1E1E1E' : '#FFFFFF'),
    });
    const kind: DrawOp['kind'] = type === 'label' ? 'text' : type === 'image' || type === 'imagebutton' ? 'image' : 'frame';
    // Buttons keep "Button" in their name: that is how read-back recognises them.
    const op: DrawOp = { parent: parentIndex, kind, name: `${type === 'button' && !BUTTON.test(base) ? `${base} Button` : base}${tags ? ` ${tags}` : ''}`, x, y, w, h };
    if (node.visible === false) op.visible = false;
    if (kind === 'text') Object.assign(op, label());
    const transparent = type === 'label' || type === 'image';
    const opacity = 1 - (node.transparency ?? (transparent && !node.color ? 1 : type === 'frame' || type === 'scroll' ? 0.15 : 0));
    if (opacity > 0 && kind !== 'text') {
      op.fill = node.color ?? (type === 'button' ? '#FFC940' : '#16161F');
      op.fillOpacity = Math.round(opacity * 100) / 100;
    }
    if (node.gradient?.length) op.gradient = node.gradient.slice(0, 2);
    if (kind !== 'text') op.corner = node.corner ?? (type === 'image' ? 0 : type === 'button' ? 10 : 12);
    if (node.stroke) op.stroke = typeof node.stroke === 'string' ? node.stroke : '#FFFFFF';
    if (node.layout === 'horizontal' || node.layout === 'vertical') {
      op.layout = node.layout === 'horizontal' ? 'HORIZONTAL' : 'VERTICAL';
      op.gap = node.gap ?? 8;
    }
    if (node.padding) op.padding = node.padding;
    const index = ops.push(op) - 1;
    // Buttons and text boxes: the text is a child layer, read back as the button's label.
    if (type === 'button' || type === 'textbox') ops.push({ parent: index, kind: 'text', name: 'Label', x: 0, y: 0, w, h, ...label() });

    const pad = node.padding ?? 0;
    const kids = node.children ?? [];
    if (node.layout === 'grid') {
      const [cw2, ch2] = node.cell ?? [120, 120];
      const gap = node.gap ?? 8;
      const perRow = Math.max(1, Math.floor((w - 2 * pad + gap) / (cw2 + gap)));
      kids.forEach((k, i) => place({ ...k, size: [0, cw2, 0, ch2] }, index, cw2, ch2, { x: pad + (i % perRow) * (cw2 + gap), y: pad + Math.floor(i / perRow) * (ch2 + gap) }));
    } else if (node.layout) {
      // Figma auto layout places these; the rect only matters for their size.
      kids.forEach((k) => place(k, index, w - 2 * pad, h - 2 * pad, { x: pad, y: pad }));
    } else {
      kids.forEach((k) => place(k, index, w - 2 * pad, h - 2 * pad));
    }
  };

  for (const child of spec.children ?? []) place(child, 0, cw, ch);
  return ops.map((op) => ({ ...op, x: Math.round(op.x), y: Math.round(op.y), w: Math.max(1, Math.round(op.w)), h: Math.max(1, Math.round(op.h)) }));
}

// ---------------------------------------------------------------- bridge

interface Pending {
  resolve: (value: any) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
}

/** Commands waiting for the Figma plugin, and what it last told us. */
export class FigmaBridge {
  private queue: Array<{ id: string; command: Record<string, unknown> }> = [];
  private pending = new Map<string, Pending>();
  lastSeen = 0;
  file?: string;
  page?: string;
  selection?: number;

  connected(now = Date.now()) {
    return now - this.lastSeen < 6000;
  }

  status() {
    return { connected: this.connected(), file: this.file, page: this.page, selected: this.selection };
  }

  /** The plugin polls about once a second; returns the next command, if any. */
  poll(info: { file?: string; page?: string; selection?: number }) {
    this.lastSeen = Date.now();
    Object.assign(this, info);
    return this.queue.shift();
  }

  answer(id: string, ok: boolean, result: unknown, error?: string) {
    const waiting = this.pending.get(id);
    if (!waiting) return false;
    clearTimeout(waiting.timer);
    this.pending.delete(id);
    if (ok) waiting.resolve(result);
    else waiting.reject(new Error(error || 'The Figma plugin failed'));
    return true;
  }

  send(command: Record<string, unknown>, timeoutMs = 60000): Promise<any> {
    if (!this.connected()) return Promise.reject(new Error(NOT_RUNNING));
    const id = randomUUID();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        this.queue = this.queue.filter((c) => c.id !== id);
        reject(new Error('The Figma plugin did not answer in time (is the file still open?).'));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      this.queue.push({ id, command });
    });
  }
}

export const figmaBridge = new FigmaBridge();

const NOT_RUNNING = 'The Figma plugin "Roblox MCP Bridge" is not running.';
const PLUGIN_STEPS = [
  'Open the Figma DESKTOP app and a design file (the free plan works).',
  `First time only: Plugins > Development > Import plugin from manifest... > ${'<MCP folder>'}/figma-plugin/manifest.json.`,
  'Plugins > Development > Roblox MCP Bridge: keep its small window open while the AI works.',
];

/** The manifest to import: next to dist/ in the npm package, at the root of a clone. */
export function findPluginManifest(entry: string | undefined = process.argv[1]): string | undefined {
  const here = entry ? path.dirname(entry) : process.cwd();
  return [path.join(here, '..', 'figma-plugin'), path.join(here, '..', '..', '..', 'figma-plugin'), path.join(process.cwd(), 'figma-plugin')]
    .map((dir) => path.resolve(dir, 'manifest.json'))
    .find((file) => fs.existsSync(file));
}

function pluginSteps(): string[] {
  const manifest = findPluginManifest();
  return PLUGIN_STEPS.map((s) => (manifest ? s.replace('<MCP folder>/figma-plugin/manifest.json', manifest) : s));
}

/** Routes the Figma plugin calls. Its window has origin "null", so they answer CORS. */
export function mountFigmaPluginRoutes(app: Express, bridge: FigmaBridge = figmaBridge) {
  const cors = (_req: HttpRequest, res: HttpResponse, next: () => void) => {
    // shortcut: any page may call these two routes (the plugin iframe has no origin); they only
    // exchange design data, never run code in Studio. Add a pairing code if that ever changes.
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    res.setHeader('Access-Control-Allow-Private-Network', 'true');
    next();
  };
  app.options(['/figma/poll', '/figma/result'], cors, (_req, res) => { res.status(204).end(); });
  app.get('/figma/poll', cors, (req, res) => {
    const q = req.query as Record<string, string | undefined>;
    const next = bridge.poll({ file: q.file, page: q.page, selection: q.selection !== undefined ? Number(q.selection) : undefined });
    res.json(next ?? {});
  });
  app.post('/figma/result', cors, (req, res) => {
    const { id, ok, result, error } = req.body ?? {};
    res.json({ accepted: bridge.answer(String(id), ok !== false, result, error) });
  });
}

/** Routes the MCP processes call (after the loopback-only check). */
export function mountFigmaToolRoutes(app: Express, bridge: FigmaBridge = figmaBridge) {
  app.get('/figma/status', (_req, res) => { res.json(bridge.status()); });
  app.post('/figma/command', async (req, res) => {
    try {
      res.json({ ok: true, result: await bridge.send(req.body ?? {}) });
    } catch (error) {
      res.json({ ok: false, error: error instanceof Error ? error.message : String(error), status: bridge.status() });
    }
  });
}

// ---------------------------------------------------------------- tool

type Fetch = typeof fetch;

/** The server that owns the Studio port also owns the Figma plugin (proxies reach it over HTTP). */
function bridgeUrl(): string {
  // shortcut: assumes the primary is on the base port; it only climbs when a non-MCP program holds it.
  return `http://127.0.0.1:${process.env.ROBLOX_STUDIO_PORT || 58741}`;
}

export class FigmaTools {
  constructor(private buildUi: (spec: UiSpec) => Promise<ToolResult>, private fetchImpl: Fetch = fetch, private outDir = path.join(os.tmpdir(), 'roblox-ultimate-mcp', 'figma')) {}

  private async command(body: Record<string, unknown>): Promise<any> {
    let res: Response;
    try {
      res = await this.fetchImpl(`${bridgeUrl()}/figma/command`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    } catch {
      throw new Error('The MCP server is not reachable on its local port (is another program using port 58741?).');
    }
    const reply: any = await res.json();
    if (!reply.ok) throw new Error(reply.error);
    return reply.result;
  }

  async call(args: Record<string, any>): Promise<ToolResult> {
    const action = String(args.action ?? 'status');
    if (action === 'status') return this.status();
    try {
      if (action === 'draw') return await this.draw(args);
      if (action === 'read' || action === 'import') return await this.read(args, action === 'import');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (message === NOT_RUNNING) return text({ ok: false, problem: message, steps: pluginSteps(), then: `figma { action: "${action}" } again.` });
      throw error;
    }
    throw new Error(`Unknown figma action "${action}". Use status, draw, read or import.`);
  }

  private async status(): Promise<ToolResult> {
    let status: any;
    try {
      const res = await this.fetchImpl(`${bridgeUrl()}/figma/status`);
      status = await res.json();
    } catch {
      status = { connected: false };
    }
    return text(status.connected
      ? { ...status, next: 'figma { action: "draw", spec } to sketch a screen, or select a frame in Figma and figma { action: "import" }.' }
      : { ...status, steps: pluginSteps() });
  }

  private async draw(args: Record<string, any>): Promise<ToolResult> {
    const spec = args.spec as UiSpec;
    if (!spec?.name || !Array.isArray(spec.children)) throw new Error('draw needs spec: { name, children: [...] } (the build_ui format, roblox_guide ui)');
    const ops = specToFigma(spec, Array.isArray(args.canvas) ? args.canvas : undefined);
    const drawn = await this.command({ action: 'draw', ops });
    return text({
      ok: true,
      drawn,
      layers: ops.length,
      next: 'Ask the user to adjust it in Figma (colors, sizes, texts, icons). When they are happy: select the frame and figma { action: "import" }.',
      tip: 'Behaviour is kept in layer names: "Shop [toggle:ShopWindow]", texts like "💰 {stat:Coins}". Hidden layers start hidden.',
    });
  }

  private async read(args: Record<string, any>, build: boolean): Promise<ToolResult> {
    const picked = await this.command({ action: 'read' });
    const root = picked?.root as FigmaNode | undefined;
    if (!root) return text({ ok: false, problem: 'Nothing is selected in Figma.', fix: 'Select ONE frame (the screen or the panel) in Figma, then call again.' });
    const result = figmaToSpec(root, { name: args.name, as: args.as });
    const dir = path.join(this.outDir, result.spec.name);
    const pictures = result.images.map((image) => {
      fs.mkdirSync(dir, { recursive: true });
      const file = path.join(dir, `${image.path.split('/').pop()}.png`);
      fs.writeFileSync(file, Buffer.from(image.png, 'base64'));
      return { instance: image.path, file };
    });
    const howToPictures = pictures.length
      ? 'Pictures are not uploaded automatically (ask the user first). In Studio: select each ImageLabel listed, Properties > Image > "Add Image..." and pick its file (or Asset Manager > Bulk Import, then paste the ids).'
      : undefined;
    if (!build) {
      return text({
        ok: true,
        file: picked.file,
        spec: result.spec,
        pictures,
        warnings: result.warnings,
        next: 'Check the spec (add bind/action where needed), then build_ui { spec }. Or figma { action: "import" } to do both.',
        pictureSteps: howToPictures,
      });
    }
    const built = await this.buildUi(result.spec);
    const report = JSON.parse(built.content[0]?.text ?? '{}');
    return text({ ...report, from: `Figma "${root.name}"`, pictures, warnings: [...(report.warnings ?? []), ...result.warnings], pictureSteps: howToPictures });
  }
}
