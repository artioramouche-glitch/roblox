/**
 * Declarative UI builder: the AI describes a screen as JSON and gets a responsive,
 * good-looking ScreenGui in StarterGui. Behaviour (live stat text, toggling windows,
 * firing remotes) comes from attributes read by the UIBinder LocalScript -- no Luau.
 */

import type { InstanceNode } from './installer.js';
import { color, rgbOf, ud, ud2, v2, type Encoded } from './values.js';

export interface UiNode {
  type: 'frame' | 'label' | 'button' | 'image' | 'imagebutton' | 'textbox' | 'scroll' | 'bar';
  name?: string;
  text?: string;
  position?: string | number[];
  size?: number[];
  anchor?: number[];
  color?: string;
  textColor?: string;
  transparency?: number;
  corner?: number;
  stroke?: string | boolean;
  padding?: number;
  layout?: 'vertical' | 'horizontal' | 'grid';
  gap?: number;
  cell?: number[];
  align?: 'start' | 'center' | 'end';
  font?: string;
  textAlign?: 'left' | 'center' | 'right';
  maxTextSize?: number;
  image?: string;
  visible?: boolean;
  aspect?: number;
  gradient?: string[];
  zIndex?: number;
  order?: number;
  bind?: string;
  format?: string;
  bar?: string;
  showIf?: string;
  action?: string;
  placeholder?: string;
  children?: UiNode[];
}

export interface UiSpec {
  name: string;
  children: UiNode[];
  resetOnSpawn?: boolean;
  displayOrder?: number;
  ignoreInset?: boolean;
}

const THEME = {
  panel: '#16161F',
  accent: '#FFC940',
  text: '#FFFFFF',
  buttonText: '#1E1E1E',
};

const PRESETS: Record<string, { anchor: [number, number]; pos: [number, number, number, number] }> = {
  center: { anchor: [0.5, 0.5], pos: [0.5, 0, 0.5, 0] },
  top: { anchor: [0.5, 0], pos: [0.5, 0, 0, 12] },
  bottom: { anchor: [0.5, 1], pos: [0.5, 0, 1, -12] },
  left: { anchor: [0, 0.5], pos: [0, 12, 0.5, 0] },
  right: { anchor: [1, 0.5], pos: [1, -12, 0.5, 0] },
  'top-left': { anchor: [0, 0], pos: [0, 12, 0, 12] },
  'top-right': { anchor: [1, 0], pos: [1, -12, 0, 12] },
  'bottom-left': { anchor: [0, 1], pos: [0, 12, 1, -12] },
  'bottom-right': { anchor: [1, 1], pos: [1, -12, 1, -12] },
};

/** [w, h] <= 1 are screen fractions, bigger numbers are pixels; 4 numbers are a full UDim2. */
function sizeOf(size: number[] | undefined, fallback: Encoded): Encoded {
  if (!size) return fallback;
  if (size.length >= 4) return ud2(size[0], size[1], size[2], size[3]);
  const [w, h] = size;
  const wx = w <= 1 ? [w, 0] : [0, w];
  const hy = h <= 1 ? [h, 0] : [0, h];
  return ud2(wx[0], wx[1], hy[0], hy[1]);
}

const CLASS: Record<UiNode['type'], string> = {
  frame: 'Frame', label: 'TextLabel', button: 'TextButton', image: 'ImageLabel',
  imagebutton: 'ImageButton', textbox: 'TextBox', scroll: 'ScrollingFrame', bar: 'Frame',
};

let counter = 0;

function build(node: UiNode, inLayout: boolean): InstanceNode {
  const type = CLASS[node.type] ? node.type : 'frame';
  const className = CLASS[type];
  const name = node.name ?? `${type[0].toUpperCase()}${type.slice(1)}${++counter}`;
  const props: Record<string, Encoded> = {};
  const attrs: Record<string, Encoded> = {};
  const children: InstanceNode[] = [];
  const isText = type === 'label' || type === 'button' || type === 'textbox';

  const defaultSize = type === 'button' ? ud2(0, 160, 0, 48) : type === 'label' ? ud2(0, 200, 0, 36) : ud2(0.3, 0, 0.3, 0);
  props.Size = sizeOf(node.size, defaultSize);
  if (!inLayout) {
    if (typeof node.position === 'string' && PRESETS[node.position]) {
      const p = PRESETS[node.position];
      props.AnchorPoint = v2(...p.anchor);
      props.Position = ud2(...p.pos);
    } else if (Array.isArray(node.position) && node.position.length >= 2) {
      const pos = node.position.length >= 4 ? node.position : [node.position[0], 0, node.position[1], 0];
      props.Position = ud2(pos[0], pos[1], pos[2], pos[3]);
    }
  }
  if (node.anchor) props.AnchorPoint = v2(node.anchor[0], node.anchor[1]);
  if (node.order !== undefined) props.LayoutOrder = node.order;
  if (node.zIndex !== undefined) props.ZIndex = node.zIndex;
  if (node.visible === false) props.Visible = false;

  // Background
  const bgDefault = type === 'button' ? THEME.accent : THEME.panel;
  const transparent = type === 'label' || type === 'image';
  props.BackgroundColor3 = color(node.color ?? bgDefault);
  props.BackgroundTransparency = node.transparency ?? (transparent && !node.color ? 1 : type === 'frame' || type === 'scroll' ? 0.15 : 0);
  props.BorderSizePixel = 0;

  if (isText) {
    props.Text = node.text ?? '';
    props.TextScaled = true;
    props.Font = node.font ?? 'FredokaOne';
    props.TextColor3 = color(node.textColor ?? (type === 'button' && !node.color ? THEME.buttonText : THEME.text));
    props.TextWrapped = true;
    if (node.textAlign === 'left' || node.textAlign === 'right') props.TextXAlignment = node.textAlign === 'left' ? 'Left' : 'Right';
    children.push({ name: 'TextLimit', className: 'UITextSizeConstraint', props: { MaxTextSize: node.maxTextSize ?? (type === 'button' ? 28 : 32), MinTextSize: 8 } });
    if (type === 'textbox') {
      props.PlaceholderText = node.placeholder ?? '';
      props.ClearTextOnFocus = false;
    }
  }
  if (type === 'image' || type === 'imagebutton') {
    props.Image = node.image ?? '';
    props.ScaleType = 'Fit';
  }
  if (type === 'scroll') {
    props.ScrollBarThickness = 6;
    props.AutomaticCanvasSize = 'Y';
    props.CanvasSize = ud2(0, 0, 0, 0);
  }
  if (type === 'button' || type === 'imagebutton') props.AutoButtonColor = true;

  const cornerDefault = type === 'label' || type === 'image' ? 0 : type === 'button' ? 10 : 12;
  const corner = node.corner ?? cornerDefault;
  if (corner > 0) children.push({ name: 'Corner', className: 'UICorner', props: { CornerRadius: ud(0, corner) } });
  if (node.stroke) {
    children.push({
      name: 'Stroke', className: 'UIStroke',
      props: { Color: color(typeof node.stroke === 'string' ? node.stroke : '#FFFFFF'), Transparency: typeof node.stroke === 'string' ? 0 : 0.8, Thickness: 1.5, ApplyStrokeMode: 'Border' },
    });
  }
  if (node.padding) {
    const p = ud(0, node.padding);
    children.push({ name: 'Padding', className: 'UIPadding', props: { PaddingTop: p, PaddingBottom: p, PaddingLeft: p, PaddingRight: p } });
  }
  if (node.aspect) children.push({ name: 'Aspect', className: 'UIAspectRatioConstraint', props: { AspectRatio: node.aspect } });
  if (node.gradient && node.gradient.length >= 2) {
    const [a, b] = [rgbOf(node.gradient[0], [255, 255, 255]), rgbOf(node.gradient[1], [0, 0, 0])];
    children.push({ name: 'Gradient', className: 'UIGradient', props: { Color: { $cs: [[0, a], [1, b]] }, Rotation: 90 } });
  }
  if (node.layout) {
    const align = node.align === 'start' ? 'Left' : node.align === 'end' ? 'Right' : 'Center';
    const valign = node.align === 'start' ? 'Top' : node.align === 'end' ? 'Bottom' : 'Center';
    if (node.layout === 'grid') {
      const cell = node.cell ?? [120, 120];
      children.push({
        name: 'Grid', className: 'UIGridLayout',
        props: { CellSize: ud2(0, cell[0], 0, cell[1]), CellPadding: ud2(0, node.gap ?? 8, 0, node.gap ?? 8), SortOrder: 'LayoutOrder', HorizontalAlignment: align },
      });
    } else {
      children.push({
        name: 'List', className: 'UIListLayout',
        props: {
          FillDirection: node.layout === 'horizontal' ? 'Horizontal' : 'Vertical',
          Padding: ud(0, node.gap ?? 8), SortOrder: 'LayoutOrder',
          HorizontalAlignment: align, VerticalAlignment: valign,
        },
      });
    }
  }

  if (node.bind) attrs.GK_Bind = node.bind;
  if (node.format) attrs.GK_Format = node.format;
  if (node.showIf) attrs.GK_ShowIf = node.showIf;
  if (node.action) attrs.GK_Action = node.action;

  if (type === 'bar') {
    // A track with a "Fill" child whose width follows GK_Bar.
    props.BackgroundColor3 = color(node.color ?? '#2A2A38');
    children.push({
      name: 'Fill', className: 'Frame',
      props: { Size: ud2(0, 0, 1, 0), BackgroundColor3: color(node.textColor ?? THEME.accent), BorderSizePixel: 0 },
      attrs: node.bar ? { GK_Bar: node.bar } : undefined,
      children: [{ name: 'Corner', className: 'UICorner', props: { CornerRadius: ud(0, corner || 8) } }],
    });
    if (node.text !== undefined || node.bind) {
      children.push(build({ type: 'label', name: 'Text', text: node.text, bind: node.bind, format: node.format, size: [1, 1], zIndex: (node.zIndex ?? 1) + 1 }, true));
      delete attrs.GK_Bind;
      delete attrs.GK_Format;
    }
  }

  const hasLayout = !!node.layout;
  for (const child of node.children ?? []) children.push(build(child, hasLayout));

  return {
    name,
    className,
    props,
    attrs: Object.keys(attrs).length ? attrs : undefined,
    children,
  };
}

export function buildScreenGui(spec: UiSpec): InstanceNode {
  counter = 0;
  return {
    name: spec.name,
    className: 'ScreenGui',
    props: {
      ResetOnSpawn: spec.resetOnSpawn ?? false,
      ZIndexBehavior: 'Sibling',
      DisplayOrder: spec.displayOrder ?? 1,
      IgnoreGuiInset: spec.ignoreInset ?? false,
    },
    children: (spec.children ?? []).map((c) => build(c, false)),
  };
}

/** A ready-made example the AI can copy: a HUD panel + a toggleable window. */
export const UI_EXAMPLE: UiSpec = {
  name: 'MyGameUI',
  children: [
    {
      type: 'frame', name: 'CoinsPanel', position: 'top-right', size: [220, 56], stroke: true, padding: 8,
      children: [{ type: 'label', name: 'Coins', size: [1, 1], bind: 'stat:Coins', format: '💰 {value}', textColor: '#FFC940' }],
    },
    { type: 'button', name: 'MenuButton', position: 'bottom-right', size: [150, 50], text: 'Menu', action: 'toggle:MenuWindow' },
    {
      type: 'frame', name: 'MenuWindow', position: 'center', size: [0.4, 0.5], visible: false, stroke: '#FFC940', padding: 16, layout: 'vertical', gap: 12,
      children: [
        { type: 'label', text: 'Menu', size: [1, 0.2] },
        { type: 'button', text: 'Close', size: [0.6, 0.2], action: 'close:MenuWindow', color: '#FF5A5A', textColor: '#FFFFFF' },
      ],
    },
  ],
};

export function describeUiSpecForTool(): string {
  return JSON.stringify(UI_EXAMPLE);
}

/** For tests/doctor: every GK_Action "toggle:/open:/close:X" should name a GUI in the spec. */
export function missingActionTargets(spec: UiSpec): string[] {
  const names = new Set<string>();
  const actions: string[] = [];
  const walk = (n: UiNode) => {
    if (n.name) names.add(n.name);
    if (n.action) actions.push(n.action);
    (n.children ?? []).forEach(walk);
  };
  spec.children.forEach(walk);
  return actions
    .map((a) => /^(toggle|open|close):(.+)$/.exec(a)?.[2])
    .filter((t): t is string => !!t && !names.has(t));
}

