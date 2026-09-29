/**
 * World generators: gameplay-ready geometry (with the tags/attributes the GameKit
 * systems react to) produced as install specs. Deterministic for a given seed.
 */

import type { InstanceNode, Placement } from './installer.js';
import { c3, cf, color, rgbOf, shade, ud2, v2, v3, type Encoded } from './values.js';

type RGB = [number, number, number];
type Vec = [number, number, number];

export interface PartOpts {
  className?: string;
  color?: RGB | string;
  material?: string;
  shape?: 'Block' | 'Ball' | 'Cylinder' | 'Wedge' | 'CornerWedge';
  transparency?: number;
  canCollide?: boolean;
  rot?: Vec;
  tags?: string[];
  attrs?: Record<string, Encoded>;
  children?: InstanceNode[];
  props?: Record<string, Encoded>;
  reflectance?: number;
  castShadow?: boolean;
}

export function rng(seed: number): () => number {
  let a = seed >>> 0 || 1;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const lerp = (a: number, b: number, t: number) => a + (b - a) * Math.max(0, Math.min(1, t));

export function part(name: string, pos: Vec, size: Vec, o: PartOpts = {}): InstanceNode {
  const props: Record<string, Encoded> = {
    Anchored: true,
    Size: v3(...size),
    CFrame: cf(pos[0], pos[1], pos[2], ...(o.rot ?? [0, 0, 0])),
    Color: color(o.color ?? [200, 200, 200]),
    Material: o.material ?? 'SmoothPlastic',
    TopSurface: 'Smooth',
    BottomSurface: 'Smooth',
    ...(o.props ?? {}),
  };
  if (o.shape) props.Shape = o.shape;
  if (o.transparency !== undefined) props.Transparency = o.transparency;
  if (o.canCollide !== undefined) props.CanCollide = o.canCollide;
  if (o.reflectance !== undefined) props.Reflectance = o.reflectance;
  if (o.castShadow === false) props.CastShadow = false;
  return { name, className: o.className ?? 'Part', props, attrs: o.attrs, tags: o.tags, children: o.children };
}

export function model(name: string, children: InstanceNode[], opts: { tags?: string[]; attrs?: Record<string, Encoded>; className?: string } = {}): InstanceNode {
  return { name, className: opts.className ?? 'Model', children, tags: opts.tags, attrs: opts.attrs };
}

export function folder(name: string, children: InstanceNode[]): InstanceNode {
  return { name, className: 'Folder', children };
}

/** Floating text above a part. */
export function billboard(text: string, textColor: RGB = [255, 255, 255], height = 4, size: [number, number] = [8, 2.5]): InstanceNode {
  return {
    name: 'Label',
    className: 'BillboardGui',
    props: { Size: ud2(size[0], 0, size[1], 0), StudsOffsetWorldSpace: v3(0, height, 0), MaxDistance: 120, LightInfluence: 0 },
    children: [{
      name: 'Text',
      className: 'TextLabel',
      props: {
        Size: ud2(1, 0, 1, 0), BackgroundTransparency: 1, Text: text, TextScaled: true,
        Font: 'FredokaOne', TextColor3: c3(...textColor), TextStrokeTransparency: 0.2,
      },
    }],
  };
}

/** Text painted on the front face of a part. */
export function surfaceText(text: string, textColor: RGB = [255, 255, 255], face = 'Front', background?: RGB): InstanceNode {
  return {
    name: 'Sign',
    className: 'SurfaceGui',
    props: { Face: face, SizingMode: 'PixelsPerStud', PixelsPerStud: 30, LightInfluence: 0 },
    children: [{
      name: 'Text',
      className: 'TextLabel',
      props: {
        Size: ud2(1, 0, 1, 0), BackgroundTransparency: background ? 0 : 1, BackgroundColor3: c3(...(background ?? [0, 0, 0])),
        Text: text, TextScaled: true, Font: 'FredokaOne', TextColor3: c3(...textColor),
      },
    }],
  };
}

function light(range: number, brightness: number, rgb: RGB, className = 'PointLight'): InstanceNode {
  return { name: 'Light', className, props: { Range: range, Brightness: brightness, Color: c3(...rgb) } };
}

function sparkles(rgb: RGB, rate = 8): InstanceNode {
  return {
    name: 'Sparkles',
    className: 'ParticleEmitter',
    props: {
      Rate: rate, Lifetime: { $nr: [0.8, 1.5] }, Speed: { $nr: [1, 3] }, SpreadAngle: v2(180, 180),
      Color: { $cs: rgb }, LightEmission: 1, Size: { $ns: [[0, 0.4], [1, 0]] }, Transparency: { $ns: [[0, 0], [1, 1]] },
    },
  };
}

// --- Themes -------------------------------------------------------------------------------

export const THEMES: Record<string, { stages: RGB[]; accent: RGB; material: string; floor: RGB }> = {
  rainbow: { stages: [[239, 83, 80], [255, 167, 38], [255, 238, 88], [102, 187, 106], [66, 165, 245], [171, 71, 188]], accent: [255, 255, 255], material: 'SmoothPlastic', floor: [60, 60, 70] },
  candy: { stages: [[255, 138, 190], [255, 205, 227], [178, 235, 242], [255, 245, 157], [206, 147, 216]], accent: [255, 255, 255], material: 'SmoothPlastic', floor: [255, 205, 227] },
  neon: { stages: [[0, 255, 200], [255, 0, 170], [120, 80, 255], [0, 200, 255], [255, 230, 0]], accent: [255, 255, 255], material: 'Neon', floor: [20, 20, 30] },
  nature: { stages: [[124, 179, 66], [141, 110, 99], [104, 159, 56], [161, 136, 127], [85, 139, 47]], accent: [255, 241, 118], material: 'Grass', floor: [76, 175, 80] },
  space: { stages: [[92, 107, 192], [126, 87, 194], [38, 50, 56], [0, 172, 193], [171, 71, 188]], accent: [255, 255, 255], material: 'Glass', floor: [25, 25, 40] },
  lava: { stages: [[66, 66, 66], [97, 97, 97], [121, 85, 72], [78, 52, 46], [55, 71, 79]], accent: [255, 112, 67], material: 'Slate', floor: [40, 40, 40] },
  ice: { stages: [[179, 229, 252], [129, 212, 250], [224, 247, 250], [144, 202, 249], [187, 222, 251]], accent: [255, 255, 255], material: 'Ice', floor: [225, 245, 254] },
};

function themeOf(name: unknown) {
  return THEMES[String(name ?? 'rainbow').toLowerCase()] ?? THEMES.rainbow;
}

// --- Obby ---------------------------------------------------------------------------------

export const OBSTACLES = [
  'jumps', 'killbricks', 'zigzag', 'moving', 'disappearing', 'spinner', 'truss',
  'lava_floor', 'falling', 'conveyor', 'jumppad', 'tightrope',
] as const;
export type ObstacleType = (typeof OBSTACLES)[number];

interface Segment { nodes: InstanceNode[]; length: number; dy: number }
interface SegmentCtx { z: number; y: number; d: number; rgb: RGB; material: string; r: () => number; i: number }

const KILL: PartOpts = { color: [255, 60, 40], material: 'Neon', tags: ['KillPart'] };

function segment(type: ObstacleType, c: SegmentCtx): Segment {
  const { z, y, d, rgb, material, r } = c;
  const nodes: InstanceNode[] = [];
  const plat = (name: string, pos: Vec, size: Vec, o: PartOpts = {}) =>
    nodes.push(part(name, pos, size, { color: rgb, material, ...o }));
  switch (type) {
    case 'jumps': {
      const count = Math.round(lerp(4, 6, d));
      const size = lerp(7, 4, d);
      const gap = lerp(4, 8, d);
      let cz = z;
      for (let k = 0; k < count; k++) {
        cz += gap + size / 2;
        plat(`Jump${k + 1}`, [(r() - 0.5) * 8 * d, y + (r() - 0.3) * 1.5, cz], [size, 1, size]);
        cz += size / 2;
      }
      return { nodes, length: cz - z + gap, dy: 0 };
    }
    case 'zigzag': {
      const count = 6;
      const size = lerp(6, 4.5, d);
      let cz = z;
      for (let k = 0; k < count; k++) {
        cz += 3 + size / 2;
        plat(`Zig${k + 1}`, [(k % 2 === 0 ? -1 : 1) * lerp(4, 6, d), y + k * 0.6, cz], [size, 1, size]);
        cz += size / 2;
      }
      return { nodes, length: cz - z + 3, dy: count * 0.6 };
    }
    case 'killbricks': {
      const length = 44;
      plat('Walkway', [0, y, z + length / 2], [8, 1, length]);
      const depth = lerp(1.2, 2.6, d);
      for (let k = 1; k * 7 < length - 3; k++) {
        nodes.push(part(`KillStrip${k}`, [0, y + 1, z + k * 7], [8, 1, depth], KILL));
      }
      return { nodes, length, dy: 0 };
    }
    case 'lava_floor': {
      const length = 40;
      nodes.push(part('Lava', [0, y - 0.4, z + length / 2], [14, 1, length], { ...KILL, material: 'CrackedLava', color: [255, 90, 20] }));
      const stones = Math.round(lerp(6, 8, d));
      for (let k = 0; k < stones; k++) {
        const sz = z + (k + 0.5) * (length / stones);
        nodes.push(part(`Stone${k + 1}`, [(r() - 0.5) * 8, y + 0.4, sz], [1, lerp(4, 2.6, d), lerp(4, 2.6, d)], {
          shape: 'Cylinder', rot: [0, 0, 90], color: shade(rgb, -0.3), material: 'Slate',
        }));
      }
      return { nodes, length, dy: 0 };
    }
    case 'moving': {
      const count = 2;
      for (let k = 0; k < count; k++) {
        plat(`Mover${k + 1}`, [-10, y, z + 8 + k * 14], [7, 1, 7], {
          tags: ['MovingPlatform'], material: 'Neon',
          attrs: { Offset: v3(20, 0, 0), Duration: lerp(3, 1.8, d), Pause: 0.6 },
        });
      }
      return { nodes, length: 30, dy: 0 };
    }
    case 'disappearing': {
      const count = 5;
      let cz = z;
      for (let k = 0; k < count; k++) {
        cz += 3 + 3.5;
        plat(`Blink${k + 1}`, [0, y, cz], [7, 1, 7], {
          tags: ['Disappearing'], material: 'Glass', transparency: 0.1,
          attrs: { OnTime: lerp(2.5, 1.5, d), OffTime: lerp(1.2, 1.8, d), Offset: k * 0.6 },
        });
        cz += 3.5;
      }
      return { nodes, length: cz - z + 3, dy: 0 };
    }
    case 'spinner': {
      const length = 36;
      plat('Walkway', [0, y, z + length / 2], [12, 1, length]);
      nodes.push(part('SpinnerBar', [0, y + 2, z + length / 2], [22, 1, 1.2], {
        ...KILL, tags: ['KillPart', 'Spinner'], attrs: { Speed: lerp(60, 150, d), Axis: 'Y' },
      }));
      nodes.push(part('SpinnerHub', [0, y + 1.5, z + length / 2], [2, 3, 2], { color: [40, 40, 40], material: 'Metal' }));
      return { nodes, length, dy: 0 };
    }
    case 'truss': {
      const height = 14;
      plat('Base', [0, y, z + 5], [8, 1, 6]);
      nodes.push(part('Truss', [0, y + height / 2 + 0.5, z + 9], [2, height, 2], { className: 'TrussPart', color: [180, 180, 190], material: 'Metal' }));
      plat('Top', [0, y + height, z + 13], [8, 1, 6]);
      return { nodes, length: 18, dy: height };
    }
    case 'falling': {
      const count = 6;
      let cz = z;
      for (let k = 0; k < count; k++) {
        cz += 2 + 3;
        plat(`Fall${k + 1}`, [(r() - 0.5) * 4, y, cz], [6, 1, 6], {
          tags: ['FallingPlatform'], material: 'WoodPlanks', color: [161, 110, 70],
          attrs: { Delay: lerp(0.8, 0.4, d), RespawnTime: 3 },
        });
        cz += 3;
      }
      return { nodes, length: cz - z + 2, dy: 0 };
    }
    case 'conveyor': {
      const length = 40;
      nodes.push(part('Conveyor', [0, y, z + length / 2], [8, 1, length], {
        tags: ['Conveyor'], color: [45, 45, 50], material: 'DiamondPlate', // pushes backwards (-Z)
        attrs: { Speed: lerp(8, 16, d) },
      }));
      nodes.push(part('KillBlock', [(r() > 0.5 ? 2 : -2), y + 1.5, z + length / 2], [4, 2, 2], KILL));
      return { nodes, length, dy: 0 };
    }
    case 'jumppad': {
      const rise = 16;
      plat('PadBase', [0, y, z + 5], [8, 1, 8]);
      nodes.push(part('JumpPad', [0, y + 0.6, z + 5], [4, 0.4, 4], {
        tags: ['JumpPad'], material: 'Neon', color: [0, 230, 118], attrs: { Power: 115 },
        children: [billboard('⬆ JUMP', [0, 255, 150], 2, [5, 1.5])],
      }));
      plat('HighLanding', [0, y + rise, z + 14], [10, 1, 8]);
      return { nodes, length: 19, dy: rise };
    }
    case 'tightrope': {
      const length = 30;
      const width = lerp(1.6, 0.9, d);
      plat('Rope', [0, y, z + length / 2], [width, 1, length], { color: shade(rgb, -0.2) });
      return { nodes, length, dy: 0 };
    }
  }
}

function checkpointNode(stage: number, pos: Vec, rgb: RGB, spawn: boolean): InstanceNode {
  const common: PartOpts = {
    color: [60, 220, 120], material: 'Neon', tags: ['Checkpoint'], attrs: { Stage: stage },
    children: [billboard(`${stage}`, [255, 255, 255], 3, [3, 2])],
  };
  if (spawn) {
    return part(`Checkpoint${stage}`, pos, [12, 1, 12], {
      ...common, className: 'SpawnLocation', color: rgb, material: 'SmoothPlastic', rot: [0, 180, 0],
      props: { Neutral: true, Duration: 0 },
      children: [billboard('START', [255, 255, 255], 4, [8, 2.5])],
    });
  }
  return part(`Checkpoint${stage}`, pos, [12, 1, 12], common);
}

export interface ObbyOptions {
  stages?: number;
  difficulty?: 'easy' | 'medium' | 'hard';
  theme?: string;
  coins?: boolean;
  position?: Vec;
  obstacles?: ObstacleType[];
  seed?: number;
  title?: string;
}

export function obbyCourse(o: ObbyOptions = {}): InstanceNode {
  const stages = Math.max(2, Math.min(60, Math.round(o.stages ?? 12)));
  const base = o.position ?? [0, 50, 0];
  const theme = themeOf(o.theme);
  const r = rng(o.seed ?? 42);
  const diffOffset = o.difficulty === 'hard' ? 0.45 : o.difficulty === 'easy' ? -0.2 : 0.1;
  const children: InstanceNode[] = [];
  let z = base[2];
  let y = base[1];

  // Start area.
  children.push(part('StartPlatform', [base[0], y - 0.5, z - 10], [30, 1, 30], { color: theme.floor, material: 'SmoothPlastic' }));
  children.push(checkpointNode(1, [base[0], y + 0.5, z - 10], theme.stages[0], true));
  children.push(part('TitleSign', [base[0], y + 16, z + 4], [24, 8, 1], {
    color: [30, 30, 40], children: [surfaceText(o.title ?? 'OBBY', theme.accent)],
  }));
  z += -4;

  const sequence = o.obstacles && o.obstacles.length > 0 ? o.obstacles : [...OBSTACLES];
  for (let stage = 1; stage < stages; stage++) {
    const d = Math.max(0, Math.min(1, stage / stages + diffOffset));
    const rgb = theme.stages[stage % theme.stages.length];
    const type = sequence[(stage - 1) % sequence.length];
    const seg = segment(type, { z, y, d, rgb, material: theme.material, r, i: stage });
    const offsetNodes = seg.nodes.map((n) => shift(n, base[0], 0, 0));
    children.push(model(`Stage${stage}_${type}`, offsetNodes));
    z += seg.length;
    y += seg.dy + 1;
    if (o.coins !== false) {
      children.push(part(`Coin${stage}`, [base[0] + 3, y + 3, z + 6], [0.4, 2.2, 2.2], coinOpts(stage)));
    }
    children.push(checkpointNode(stage + 1, [base[0], y, z + 6], rgb, false));
    z += 12;
  }

  // Finish.
  children.push(part('FinishPlatform', [base[0], y, z + 14], [24, 1, 24], { color: [255, 215, 64], material: 'SmoothPlastic' }));
  children.push(part('FinishLine', [base[0], y + 0.7, z + 14], [14, 0.4, 14], {
    color: [255, 235, 59], material: 'Neon', tags: ['FinishLine'],
    children: [billboard('🏆 FINISH', [255, 235, 59], 5, [10, 3]), confetti()],
  }));

  // Lava sea under the whole course: falling = quick respawn instead of a long fall.
  const length = z - base[2] + 60;
  children.push(part('LavaSea', [base[0], base[1] - 30, base[2] + length / 2 - 30], [220, 1, length + 120], {
    ...KILL, material: 'CrackedLava', color: [255, 85, 0], castShadow: false,
  }));

  return model('ObbyCourse', children, { attrs: { Stages: stages } });
}

function coinOpts(i: number): PartOpts {
  return {
    shape: 'Cylinder', color: [255, 201, 64], material: 'Neon', canCollide: false,
    tags: ['Coin'], attrs: { Amount: 1 + Math.floor(i / 4), RespawnTime: 15 },
    children: [sparkles([255, 220, 90], 4)],
  };
}

function confetti(): InstanceNode {
  return {
    name: 'Confetti',
    className: 'ParticleEmitter',
    props: {
      Rate: 25, Lifetime: { $nr: [2, 3] }, Speed: { $nr: [12, 20] }, SpreadAngle: v2(35, 35),
      Color: { $cs: [[0, [255, 80, 80]], [0.33, [255, 235, 59]], [0.66, [80, 200, 255]], [1, [180, 90, 255]]] },
      Acceleration: v3(0, -12, 0), Size: { $ns: 0.5 }, Rotation: { $nr: [0, 360] }, RotSpeed: { $nr: [-180, 180] },
    },
  };
}

/** Moves a node (and nested models) by (dx, dy, dz). */
function shift(node: InstanceNode, dx: number, dy: number, dz: number): InstanceNode {
  if (!dx && !dy && !dz) return node;
  const copy: InstanceNode = { ...node };
  const frame = node.props?.CFrame as { $cf: number[] } | undefined;
  if (frame && '$cf' in frame) {
    const [x, y, z, ...rot] = frame.$cf;
    copy.props = { ...node.props, CFrame: { $cf: [x + dx, y + dy, z + dz, ...rot] } as Encoded };
  }
  if (node.children) copy.children = node.children.map((c) => (c.props?.CFrame ? shift(c, dx, dy, dz) : c));
  return copy;
}

// --- Single gameplay pieces -----------------------------------------------------------------

export function piece(kind: string, pos: Vec, o: Record<string, any> = {}): InstanceNode {
  const rgb = rgbOf(o.color, [120, 120, 130]);
  const name = o.name ?? kind;
  switch (kind) {
    case 'platform':
      return part(name, pos, o.size ?? [12, 1, 12], { color: rgb, material: o.material ?? 'SmoothPlastic' });
    case 'spawn':
      return part(name, pos, [12, 1, 12], { className: 'SpawnLocation', color: rgbOf(o.color, [90, 200, 255]), props: { Neutral: true, Duration: o.forcefield ?? 0 }, tags: o.lobby ? ['LobbySpawn'] : undefined });
    case 'checkpoint':
      return checkpointNode(o.stage ?? 2, pos, rgb, false);
    case 'finish_line':
      return part(name, pos, [14, 0.4, 14], { color: [255, 235, 59], material: 'Neon', tags: ['FinishLine'], children: [billboard('🏆 FINISH', [255, 235, 59], 5, [10, 3]), confetti()] });
    case 'kill_brick':
      return part(name, pos, o.size ?? [8, 1, 2], KILL);
    case 'lava_floor':
      return part(name, pos, o.size ?? [20, 1, 20], { ...KILL, material: 'CrackedLava', color: [255, 90, 20] });
    case 'damage_part':
      return part(name, pos, o.size ?? [6, 1, 6], { color: [156, 39, 176], material: 'Neon', tags: ['DamagePart'], attrs: { Damage: o.damage ?? 20 } });
    case 'heal_pad':
      return part(name, pos, o.size ?? [6, 0.4, 6], { color: [76, 217, 100], material: 'Neon', tags: ['HealPart'], attrs: { Heal: o.heal ?? 25 }, children: [billboard('❤ HEAL', [120, 255, 150], 2.5, [5, 1.5])] });
    case 'jump_pad':
      return part(name, pos, [4, 0.4, 4], { color: [0, 230, 118], material: 'Neon', tags: ['JumpPad'], attrs: { Power: o.power ?? 110 }, children: [billboard('⬆ JUMP', [0, 255, 150], 2, [5, 1.5])] });
    case 'speed_pad':
      return part(name, pos, [6, 0.4, 6], { color: [41, 182, 246], material: 'Neon', tags: ['SpeedPad'], attrs: { Speed: o.speed ?? 40, Duration: o.duration ?? 3 }, children: [billboard('⚡ SPEED', [120, 220, 255], 2, [5, 1.5])] });
    case 'boost_pad':
      return part(name, pos, [6, 0.4, 6], { color: [255, 167, 38], material: 'Neon', tags: ['BoostPad'], rot: [0, o.yaw ?? 0, 0], attrs: { Power: o.power ?? 80 } });
    case 'moving_platform':
      return part(name, pos, o.size ?? [8, 1, 8], { color: rgb, material: 'Neon', tags: ['MovingPlatform'], attrs: { Offset: v3(...((o.offset ?? [20, 0, 0]) as Vec)), Duration: o.duration ?? 3, Pause: o.pause ?? 0.5 } });
    case 'spinner':
      return part(name, pos, [o.length ?? 20, 1, 1.2], { ...KILL, tags: ['KillPart', 'Spinner'], attrs: { Speed: o.speed ?? 90, Axis: o.axis ?? 'Y' } });
    case 'disappearing_platform':
      return part(name, pos, o.size ?? [7, 1, 7], { color: rgb, material: 'Glass', tags: ['Disappearing'], attrs: { OnTime: o.onTime ?? 2, OffTime: o.offTime ?? 1.5, Offset: o.offset ?? 0 } });
    case 'falling_platform':
      return part(name, pos, o.size ?? [6, 1, 6], { color: [161, 110, 70], material: 'WoodPlanks', tags: ['FallingPlatform'], attrs: { Delay: o.delay ?? 0.6, RespawnTime: o.respawn ?? 3 } });
    case 'conveyor':
      return part(name, pos, o.size ?? [8, 1, 30], { color: [45, 45, 50], material: 'DiamondPlate', rot: [0, o.yaw ?? 0, 0], tags: ['Conveyor'], attrs: { Speed: o.speed ?? 16 } });
    case 'coin':
      return part(name, pos, [0.4, 2.2, 2.2], { ...coinOpts(0), attrs: { Amount: o.amount ?? 1, Stat: o.stat ?? 'Coins', RespawnTime: o.respawn ?? 10 } });
    case 'shop_stand':
      return model(name, [
        part('Counter', [pos[0], pos[1] + 1.5, pos[2]], [10, 3, 4], { color: [141, 110, 99], material: 'WoodPlanks', tags: ['ShopStand'] }),
        part('Roof', [pos[0], pos[1] + 7, pos[2]], [12, 1, 6], { color: [239, 83, 80], children: [billboard('🛒 SHOP', [255, 255, 255], 2, [8, 2.5])] }),
        part('PoleL', [pos[0] - 5, pos[1] + 4, pos[2]], [0.6, 5, 0.6], { color: [240, 240, 240] }),
        part('PoleR', [pos[0] + 5, pos[1] + 4, pos[2]], [0.6, 5, 0.6], { color: [240, 240, 240] }),
      ]);
    case 'leaderboard':
      return part(name, [pos[0], pos[1] + 7, pos[2]], [14, 14, 1], { color: [22, 22, 32], rot: [0, o.yaw ?? 180, 0], tags: ['LeaderboardBoard'], attrs: { Stat: o.stat ?? 'Wins', Title: o.title ?? `Top ${o.stat ?? 'Wins'}` } });
    case 'enemy_spawner':
      return part(name, pos, [4, 1, 4], { color: [120, 0, 0], transparency: 0.5, canCollide: false, tags: ['EnemySpawner'], attrs: { Enemy: o.enemy ?? 'Zombie', MaxAlive: o.maxAlive ?? 3, RespawnSeconds: o.respawn ?? 8 } });
    case 'sell_pad':
      return part(name, pos, [10, 0.6, 10], { color: [255, 201, 64], material: 'Neon', tags: ['SellPad'], children: [billboard('💰 SELL', [255, 230, 120], 3, [8, 2.5])] });
    case 'zone_gate':
      return part(name, pos, [16, 14, 2], { color: [100, 181, 246], material: 'ForceField', tags: ['ZoneGate'], rot: [0, o.yaw ?? 0, 0], attrs: { Zone: o.zone ?? 'Zone 2', Price: o.price ?? 250 }, children: [billboard(`🔒 ${o.zone ?? 'Zone 2'}`, [180, 220, 255], 9, [10, 3])] });
    case 'teleporter':
      return part(name, pos, [6, 0.6, 6], { color: [171, 71, 188], material: 'Neon', tags: ['Teleporter'], attrs: { Target: o.target ?? 'TeleportTarget' }, children: [sparkles([200, 120, 255], 10)] });
    case 'teleport_target':
      return part(name, pos, [6, 0.6, 6], { color: [206, 147, 216], material: 'Neon' });
    case 'key':
      return part(name, pos, [1.2, 1.2, 2.4], { color: [255, 215, 0], material: 'Neon', canCollide: false, tags: ['Key'], children: [light(10, 1.5, [255, 215, 0]), sparkles([255, 230, 120], 5)] });
    case 'tree':
      return tree(name, pos, rng(o.seed ?? Math.round(pos[0] * 7 + pos[2] * 13)));
    case 'rock':
      return part(name, [pos[0], pos[1] + 1.5, pos[2]], [5, 3, 4], { color: [120, 120, 125], material: 'Rock', rot: [10, (pos[0] * 37) % 360, 5] });
    case 'lamp':
      return lamp(name, pos, !!o.flicker);
    case 'crate':
      return part(name, [pos[0], pos[1] + 2, pos[2]], [4, 4, 4], { color: [161, 120, 80], material: 'WoodPlanks' });
    case 'pine_tree':
      return pineTree(name, pos, rng(o.seed ?? Math.round(pos[0] * 11 + pos[2] * 5)), !!o.snow);
    case 'palm_tree':
      return palmTree(name, pos, rng(o.seed ?? Math.round(pos[0] * 3 + pos[2] * 17)));
    case 'bush':
      return model(name, [
        part('Bush', [pos[0], pos[1] + 1.6, pos[2]], [5, 3.6, 5], { shape: 'Ball', color: rgbOf(o.color, [76, 140, 60]), material: 'Grass' }),
        part('Bush2', [pos[0] + 1.6, pos[1] + 1.2, pos[2] + 0.8], [3.6, 2.8, 3.6], { shape: 'Ball', color: shade(rgbOf(o.color, [76, 140, 60]), 0.12), material: 'Grass' }),
      ]);
    case 'flowers': {
      const r = rng(o.seed ?? Math.round(pos[0] * 13 + pos[2] * 7));
      const petals: RGB[] = [[244, 67, 54], [255, 235, 59], [233, 30, 99], [156, 39, 176], [255, 255, 255], [3, 169, 244]];
      const kids: InstanceNode[] = [];
      for (let k = 0; k < 6; k++) {
        const fx = pos[0] + (r() - 0.5) * 5;
        const fz = pos[2] + (r() - 0.5) * 5;
        kids.push(part(`Stem${k}`, [fx, pos[1] + 0.6, fz], [0.2, 1.2, 0.2], { color: [67, 160, 71], canCollide: false, castShadow: false }));
        kids.push(part(`Flower${k}`, [fx, pos[1] + 1.3, fz], [0.8, 0.8, 0.8], { shape: 'Ball', color: petals[Math.floor(r() * petals.length)], material: 'SmoothPlastic', canCollide: false, castShadow: false }));
      }
      return model(name, kids);
    }
    case 'fence': {
      const length = o.length ?? 16;
      const yaw = o.yaw ?? 0;
      const rad = (yaw * Math.PI) / 180;
      const dx = Math.cos(rad);
      const dz = -Math.sin(rad);
      const kids: InstanceNode[] = [];
      const posts = Math.max(2, Math.round(length / 4) + 1);
      for (let k = 0; k < posts; k++) {
        const t = k / (posts - 1) - 0.5;
        kids.push(part(`Post${k}`, [pos[0] + dx * t * length, pos[1] + 2, pos[2] + dz * t * length], [0.6, 4, 0.6], { color: [141, 110, 99], material: 'Wood' }));
      }
      kids.push(part('RailTop', [pos[0], pos[1] + 3.2, pos[2]], [length, 0.4, 0.3], { color: [161, 128, 110], material: 'Wood', rot: [0, yaw, 0] }));
      kids.push(part('RailLow', [pos[0], pos[1] + 1.6, pos[2]], [length, 0.4, 0.3], { color: [161, 128, 110], material: 'Wood', rot: [0, yaw, 0] }));
      return model(name, kids);
    }
    case 'bench':
      return model(name, [
        part('Seat', [pos[0], pos[1] + 1.6, pos[2]], [6, 0.4, 2], { color: [161, 110, 70], material: 'WoodPlanks' }),
        part('Back', [pos[0], pos[1] + 2.8, pos[2] - 0.85], [6, 2, 0.3], { color: [161, 110, 70], material: 'WoodPlanks' }),
        part('LegL', [pos[0] - 2.4, pos[1] + 0.7, pos[2]], [0.4, 1.4, 1.8], { color: [60, 60, 65], material: 'Metal' }),
        part('LegR', [pos[0] + 2.4, pos[1] + 0.7, pos[2]], [0.4, 1.4, 1.8], { color: [60, 60, 65], material: 'Metal' }),
      ]);
    case 'barrel':
      return part(name, [pos[0], pos[1] + 2, pos[2]], [4, 3, 3], { shape: 'Cylinder', rot: [0, 0, 90], color: rgbOf(o.color, [121, 85, 72]), material: 'Wood' });
    case 'crystal': {
      const rgb2 = rgbOf(o.color, [124, 77, 255]);
      return model(name, [
        part('Crystal', [pos[0], pos[1] + 3, pos[2]], [2, 6, 2], { color: rgb2, material: 'Glass', transparency: 0.2, rot: [8, 20, 5], children: [light(12, 1, rgb2)] }),
        part('Crystal2', [pos[0] + 1.4, pos[1] + 1.8, pos[2] + 0.6], [1.4, 3.6, 1.4], { color: shade(rgb2, 0.2), material: 'Glass', transparency: 0.2, rot: [-15, 40, 20] }),
        part('Crystal3', [pos[0] - 1.2, pos[1] + 1.5, pos[2] - 0.8], [1.2, 3, 1.2], { color: shade(rgb2, -0.15), material: 'Glass', transparency: 0.2, rot: [18, -30, -12] }),
      ]);
    }
    case 'mushroom': {
      const cap = rgbOf(o.color, [229, 57, 53]);
      return model(name, [
        part('Stem', [pos[0], pos[1] + 1.5, pos[2]], [3, 1.2, 1.2], { shape: 'Cylinder', rot: [0, 0, 90], color: [245, 240, 225], material: 'SmoothPlastic' }),
        part('Cap', [pos[0], pos[1] + 3.2, pos[2]], [4, 2, 4], { shape: 'Ball', color: cap, material: 'SmoothPlastic' }),
      ]);
    }
    case 'cactus':
      return model(name, [
        part('Trunk', [pos[0], pos[1] + 3.5, pos[2]], [1.6, 7, 1.6], { color: [67, 160, 71], material: 'Grass' }),
        part('ArmL', [pos[0] - 1.4, pos[1] + 4, pos[2]], [1.2, 1, 1], { color: [67, 160, 71], material: 'Grass' }),
        part('ArmLUp', [pos[0] - 1.9, pos[1] + 5, pos[2]], [1, 2.4, 1], { color: [67, 160, 71], material: 'Grass' }),
        part('ArmR', [pos[0] + 1.4, pos[1] + 3, pos[2]], [1.2, 1, 1], { color: [67, 160, 71], material: 'Grass' }),
        part('ArmRUp', [pos[0] + 1.9, pos[1] + 3.8, pos[2]], [1, 2, 1], { color: [67, 160, 71], material: 'Grass' }),
      ]);
    case 'tower_pad':
      return part(name, pos, [8, 1, 8], { color: [96, 125, 139], material: 'Slate', tags: ['TowerPad'], attrs: { Tower: o.tower ?? 'Archer' }, children: [billboard(`🛠 ${o.tower ?? 'Archer'}`, [255, 255, 255], 3, [6, 1.6])] });
    case 'farm_plot':
      return part(name, pos, o.size ?? [8, 1, 8], { color: [109, 76, 65], material: 'Ground', tags: ['FarmPlot'] });
    case 'seed_stand':
      return model(name, [
        part('Table', [pos[0], pos[1] + 1.5, pos[2]], [6, 3, 3], { color: [161, 110, 70], material: 'WoodPlanks', tags: ['SeedStand'], attrs: { Crop: o.crop ?? 'Wheat' } }),
        part('Sign', [pos[0], pos[1] + 5, pos[2]], [6, 2, 0.4], { color: [255, 248, 225], children: [surfaceText(`🌱 ${o.crop ?? 'Wheat'}`, [60, 40, 20], 'Front')] }),
        part('Crate', [pos[0], pos[1] + 3.5, pos[2]], [2, 1, 2], { color: rgbOf(o.color, [244, 208, 63]), material: 'SmoothPlastic' }),
      ]);
    case 'market':
      return model(name, [
        part('Counter', [pos[0], pos[1] + 1.5, pos[2]], [12, 3, 4], { color: [141, 110, 99], material: 'WoodPlanks', tags: ['CropSell'] }),
        part('Roof', [pos[0], pos[1] + 7, pos[2]], [14, 1, 7], { color: [67, 160, 71], children: [billboard('🧺 MARKET', [255, 255, 255], 2, [9, 2.5])] }),
        part('PoleL', [pos[0] - 6, pos[1] + 4, pos[2]], [0.6, 5, 0.6], { color: [240, 240, 240] }),
        part('PoleR', [pos[0] + 6, pos[1] + 4, pos[2]], [0.6, 5, 0.6], { color: [240, 240, 240] }),
      ]);
    case 'egg_stand': {
      const eggColor = rgbOf(o.color, [245, 245, 245]);
      return model(name, [
        part('Pedestal', [pos[0], pos[1] + 1, pos[2]], [6, 2, 6], { shape: 'Cylinder', rot: [0, 0, 90], color: [120, 144, 156], material: 'Marble', tags: ['EggStand'], attrs: { Egg: o.egg ?? 'Basic' } }),
        part('Egg', [pos[0], pos[1] + 4.2, pos[2]], [3.2, 4.2, 3.2], { shape: 'Ball', color: eggColor, material: 'SmoothPlastic', canCollide: false, children: [billboard(`🥚 ${o.egg ?? 'Basic'} egg`, [255, 255, 255], 3.5, [8, 2])] }),
      ]);
    }
    case 'item_sell':
      return model(name, [
        part('Counter', [pos[0], pos[1] + 1.5, pos[2]], [12, 3, 4], { color: [141, 110, 99], material: 'WoodPlanks', tags: ['ItemSell'] }),
        part('Roof', [pos[0], pos[1] + 7, pos[2]], [14, 1, 7], { color: [255, 179, 0], children: [billboard(o.text ?? '💰 SELL', [255, 255, 255], 2, [9, 2.5])] }),
        part('PoleL', [pos[0] - 6, pos[1] + 4, pos[2]], [0.6, 5, 0.6], { color: [240, 240, 240] }),
        part('PoleR', [pos[0] + 6, pos[1] + 4, pos[2]], [0.6, 5, 0.6], { color: [240, 240, 240] }),
      ]);
    case 'quest_target':
      return part(name, pos, o.size ?? [10, 8, 10], { transparency: o.visible ? 0.6 : 1, canCollide: false, color: [255, 235, 59], material: 'ForceField', tags: ['QuestTarget'], attrs: { Quest: o.quest ?? 'SecretSpot' } });
    case 'race_checkpoint':
      return part(name, pos, o.size ?? [4, 16, 34], { transparency: 1, canCollide: false, rot: [0, o.yaw ?? 0, 0], tags: ['RaceCheckpoint'], attrs: { Order: o.order ?? 1 } });
    case 'race_finish': {
      const w = o.width ?? 34;
      const yaw = o.yaw ?? 0;
      const ax = Math.sin((yaw * Math.PI) / 180) * (w / 2 + 2);
      const az = Math.cos((yaw * Math.PI) / 180) * (w / 2 + 2);
      return model(name, [
        part('Line', pos, [4, 16, w], { transparency: 1, canCollide: false, rot: [0, yaw, 0], tags: ['RaceFinish'] }),
        part('Paint', [pos[0], pos[1] - 7.85, pos[2]], [4, 0.2, w], { color: [245, 245, 245], material: 'SmoothPlastic', canCollide: false, rot: [0, yaw, 0] }),
        part('Arch', [pos[0], pos[1] + 9, pos[2]], [2, 2, w + 6], { color: [30, 30, 30], material: 'Metal', rot: [0, yaw, 0], children: [billboard('🏁 START / FINISH', [255, 255, 255], 3, [14, 3])] }),
        part('PostA', [pos[0] + ax, pos[1] + 0.5, pos[2] + az], [1.6, 18, 1.6], { color: [30, 30, 30], material: 'Metal' }),
        part('PostB', [pos[0] - ax, pos[1] + 0.5, pos[2] - az], [1.6, 18, 1.6], { color: [30, 30, 30], material: 'Metal' }),
      ]);
    }
    case 'race_grid':
      return part(name, pos, [6, 0.2, 9], { color: [255, 255, 255], material: 'SmoothPlastic', transparency: 0.4, canCollide: false, rot: [0, o.yaw ?? -90, 0], tags: ['RaceGrid'], attrs: { Order: o.order ?? 1 } });
    case 'fishing_spot':
      return part(name, pos, o.size ?? [10, 1, 10], { color: [128, 222, 234], material: 'Neon', transparency: 0.75, canCollide: false, tags: ['FishingSpot'], attrs: { Zone: o.zone ?? 'Pond' }, children: [billboard(`🎣 ${o.zone ?? 'Pond'}`, [255, 255, 255], 3, [6, 1.6])] });
    case 'resource_node': {
      const node = String(o.node ?? 'Tree');
      const attrs = { Node: node };
      if (node === 'Rock') {
        return model(name, [
          part('Rock', [pos[0], pos[1] + 2, pos[2]], [7, 4, 6], { color: [125, 125, 130], material: 'Rock', rot: [8, (pos[0] * 37) % 360, 4] }),
          part('Ore', [pos[0] + 1.5, pos[1] + 3.2, pos[2] + 0.5], [2, 1.6, 1.6], { color: [96, 125, 139], material: 'Slate' }),
        ], { tags: ['ResourceNode'], attrs });
      }
      if (node === 'Bush') {
        return model(name, [
          part('Bush', [pos[0], pos[1] + 1.6, pos[2]], [5, 3.4, 5], { shape: 'Ball', color: [67, 130, 57], material: 'Grass' }),
          part('Berry1', [pos[0] + 1.6, pos[1] + 2.4, pos[2] + 1.4], [0.8, 0.8, 0.8], { shape: 'Ball', color: [63, 81, 181], material: 'SmoothPlastic', canCollide: false }),
          part('Berry2', [pos[0] - 1.4, pos[1] + 2.8, pos[2] + 1.2], [0.8, 0.8, 0.8], { shape: 'Ball', color: [63, 81, 181], material: 'SmoothPlastic', canCollide: false }),
          part('Berry3', [pos[0], pos[1] + 3.2, pos[2] - 1.6], [0.8, 0.8, 0.8], { shape: 'Ball', color: [63, 81, 181], material: 'SmoothPlastic', canCollide: false }),
        ], { tags: ['ResourceNode'], attrs });
      }
      const t = tree(name, pos, rng(o.seed ?? Math.round(pos[0] * 7 + pos[2] * 13)));
      return { ...t, tags: ['ResourceNode'], attrs: { ...attrs, Node: node } };
    }
    case 'crafting_table':
      return model(name, [
        part('Table', [pos[0], pos[1] + 1.5, pos[2]], [7, 3, 4], { color: [141, 110, 99], material: 'WoodPlanks', tags: ['CraftingTable'], children: [billboard('🔨 CRAFT', [255, 255, 255], 3, [6, 1.8])] }),
        part('Saw', [pos[0] + 2, pos[1] + 3.2, pos[2]], [2, 0.4, 1], { color: [176, 190, 197], material: 'Metal' }),
        part('Logs', [pos[0] - 2, pos[1] + 3.5, pos[2]], [3, 1, 1], { shape: 'Cylinder', color: [109, 76, 65], material: 'Wood' }),
      ]);
    case 'campfire':
      return model(name, [
        part('Stones', [pos[0], pos[1] + 0.4, pos[2]], [0.8, 6, 6], { shape: 'Cylinder', rot: [0, 0, 90], color: [110, 110, 115], material: 'Slate' }),
        part('Logs', [pos[0], pos[1] + 1.2, pos[2]], [3.4, 1, 1], { color: [101, 67, 33], material: 'Wood', canCollide: false, children: [{ name: 'Fire', className: 'Fire', props: {} }, light(26, 2, [255, 170, 80])] }),
      ], { tags: ['GKCampfire'] });
    default:
      throw new Error(`Unknown piece "${kind}". Available: ${PIECES.join(', ')}`);
  }
}

export const PIECES = [
  'platform', 'spawn', 'checkpoint', 'finish_line', 'kill_brick', 'lava_floor', 'damage_part', 'heal_pad',
  'jump_pad', 'speed_pad', 'boost_pad', 'moving_platform', 'spinner', 'disappearing_platform',
  'falling_platform', 'conveyor', 'coin', 'shop_stand', 'leaderboard', 'enemy_spawner', 'sell_pad',
  'zone_gate', 'teleporter', 'teleport_target', 'key', 'tree', 'rock', 'lamp', 'crate',
  'tower_pad', 'farm_plot', 'seed_stand', 'market', 'egg_stand', 'item_sell', 'quest_target',
  'race_checkpoint', 'race_finish', 'race_grid', 'fishing_spot', 'resource_node', 'crafting_table', 'campfire',
  // decoration (also used by populate_world)
  'pine_tree', 'palm_tree', 'bush', 'flowers', 'fence', 'bench', 'barrel', 'crystal', 'mushroom', 'cactus',
];

/** Decoration pieces: no gameplay tags, safe to scatter anywhere. */
export const DECOR_PIECES = ['tree', 'rock', 'lamp', 'crate', 'pine_tree', 'palm_tree', 'bush', 'flowers', 'fence', 'bench', 'barrel', 'crystal', 'mushroom', 'cactus'] as const;

function pineTree(name: string, pos: Vec, r: () => number, snow: boolean): InstanceNode {
  const h = 10 + r() * 6;
  const green: RGB = snow ? [200, 225, 230] : [46, 125, 50];
  return model(name, [
    part('Trunk', [pos[0], pos[1] + h / 4, pos[2]], [h / 2, 1.4, 1.4], { shape: 'Cylinder', rot: [0, 0, 90], color: [93, 64, 55], material: 'Wood' }),
    part('Cone1', [pos[0], pos[1] + h * 0.45, pos[2]], [7, h * 0.35, 7], { color: green, material: snow ? 'Snow' : 'Grass', rot: [0, 45, 0] }),
    part('Cone2', [pos[0], pos[1] + h * 0.7, pos[2]], [5, h * 0.3, 5], { color: shade(green, 0.08), material: snow ? 'Snow' : 'Grass', rot: [0, 20, 0] }),
    part('Cone3', [pos[0], pos[1] + h * 0.92, pos[2]], [3, h * 0.25, 3], { color: shade(green, 0.16), material: snow ? 'Snow' : 'Grass', rot: [0, 65, 0] }),
  ]);
}

function palmTree(name: string, pos: Vec, r: () => number): InstanceNode {
  const h = 12 + r() * 5;
  const kids: InstanceNode[] = [
    part('Trunk', [pos[0], pos[1] + h / 2, pos[2]], [h, 1.3, 1.3], { shape: 'Cylinder', rot: [0, 0, 90], color: [161, 136, 127], material: 'Wood' }),
  ];
  for (let k = 0; k < 5; k++) {
    const yaw = k * 72 + r() * 20;
    const rad = (yaw * Math.PI) / 180;
    kids.push(part(`Leaf${k}`, [pos[0] + Math.cos(rad) * 3, pos[1] + h - 0.5, pos[2] - Math.sin(rad) * 3], [7, 0.3, 2], { color: [56, 142, 60], material: 'Grass', rot: [0, yaw, -18] }));
  }
  kids.push(part('Coconuts', [pos[0], pos[1] + h - 1, pos[2]], [1.6, 1.6, 1.6], { shape: 'Ball', color: [109, 76, 65], material: 'Wood' }));
  return model(name, kids);
}

function tree(name: string, pos: Vec, r: () => number): InstanceNode {
  const h = 8 + r() * 6;
  const leaves: RGB = r() > 0.5 ? [67, 160, 71] : [104, 159, 56];
  return model(name, [
    part('Trunk', [pos[0], pos[1] + h / 2, pos[2]], [h, 1.6, 1.6], { shape: 'Cylinder', rot: [0, 0, 90], color: [109, 76, 65], material: 'Wood' }),
    part('Leaves', [pos[0], pos[1] + h + 2, pos[2]], [8, 8, 8], { shape: 'Ball', color: leaves, material: 'Grass' }),
    part('Leaves2', [pos[0] + 2, pos[1] + h, pos[2] - 1], [6, 6, 6], { shape: 'Ball', color: shade(leaves, -0.15), material: 'Grass' }),
  ]);
}

function lamp(name: string, pos: Vec, flicker: boolean): InstanceNode {
  return model(name, [
    part('Pole', [pos[0], pos[1] + 5, pos[2]], [0.6, 10, 0.6], { color: [40, 40, 45], material: 'Metal' }),
    part('Bulb', [pos[0], pos[1] + 10.5, pos[2]], [1.4, 1.4, 1.4], {
      shape: 'Ball', color: [255, 236, 179], material: 'Neon', tags: flicker ? ['FlickerLight'] : undefined,
      children: [light(24, 1.2, [255, 214, 150])],
    }),
  ]);
}

// --- Lobby & arena -------------------------------------------------------------------------

export function lobby(o: { position?: Vec; size?: number; title?: string; shop?: boolean; leaderboardStat?: string | false; theme?: string } = {}): InstanceNode {
  const [x, y, z] = o.position ?? [0, 0, 0];
  const s = o.size ?? 70;
  const theme = themeOf(o.theme);
  const children: InstanceNode[] = [
    part('Floor', [x, y - 1, z], [s, 2, s], { color: theme.floor, material: 'SmoothPlastic' }),
    part('Spawn', [x, y + 0.5, z], [12, 1, 12], { className: 'SpawnLocation', color: theme.stages[4 % theme.stages.length], tags: ['LobbySpawn'], props: { Neutral: true, Duration: 3 } }),
    part('TitleSign', [x, y + 12, z - s / 2 + 1], [30, 8, 1], { color: [30, 30, 40], children: [surfaceText(o.title ?? 'MY GAME', theme.accent, 'Back')] }),
  ];
  for (const [i, [wx, wz, sx, sz]] of ([[0, -s / 2, s, 1], [0, s / 2, s, 1], [-s / 2, 0, 1, s], [s / 2, 0, 1, s]] as const).entries()) {
    children.push(part(`Wall${i + 1}`, [x + wx, y + 2, z + wz], [sx, 4, sz], { color: shade(theme.floor, 0.25) }));
  }
  for (const [i, [lx, lz]] of [[-1, -1], [1, -1], [-1, 1], [1, 1]].entries()) {
    children.push(lamp(`Lamp${i + 1}`, [x + lx * (s / 2 - 6), y, z + lz * (s / 2 - 6)], false));
  }
  if (o.shop !== false) children.push(piece('shop_stand', [x - s / 4, y, z + s / 4], { name: 'ShopStand' }));
  if (o.leaderboardStat !== false) children.push(piece('leaderboard', [x + s / 4, y, z - s / 2 + 3], { name: 'Leaderboard', stat: o.leaderboardStat ?? 'Wins' }));
  return model('Lobby', children);
}

export function arena(o: { position?: Vec; size?: number; seed?: number; theme?: string; spawns?: number } = {}): InstanceNode {
  const [x, y, z] = o.position ?? [0, 0, 220];
  const s = o.size ?? 120;
  const r = rng(o.seed ?? 7);
  const theme = themeOf(o.theme ?? 'nature');
  const children: InstanceNode[] = [
    part('Floor', [x, y - 1, z], [s, 2, s], { color: theme.floor, material: theme.material === 'Neon' ? 'SmoothPlastic' : theme.material }),
  ];
  for (const [i, [wx, wz, sx, sz]] of ([[0, -s / 2, s, 2], [0, s / 2, s, 2], [-s / 2, 0, 2, s], [s / 2, 0, 2, s]] as const).entries()) {
    children.push(part(`Wall${i + 1}`, [x + wx, y + 8, z + wz], [sx, 18, sz], { color: [90, 90, 100], material: 'Brick' }));
  }
  const cover = Math.round(s / 10);
  for (let i = 0; i < cover; i++) {
    const cx = x + (r() - 0.5) * (s - 24);
    const cz = z + (r() - 0.5) * (s - 24);
    if (Math.hypot(cx - x, cz - z) < 10) continue;
    const kind = r();
    if (kind < 0.5) children.push(part(`Crate${i}`, [cx, y + 2.5, cz], [5, 5, 5], { color: [161, 120, 80], material: 'WoodPlanks', rot: [0, r() * 90, 0] }));
    else if (kind < 0.8) children.push(part(`Wall${i}`, [cx, y + 3, cz], [12, 6, 2], { color: [120, 120, 130], material: 'Concrete', rot: [0, r() * 180, 0] }));
    else children.push(part(`Ramp${i}`, [cx, y + 2, cz], [8, 4, 10], { className: 'WedgePart', color: [120, 120, 130], material: 'Concrete', rot: [0, r() * 360, 0] }));
  }
  children.push(part('CenterPillar', [x, y + 6, z], [12, 6, 6], { color: theme.accent, material: 'Neon', shape: 'Cylinder', rot: [0, 0, 90] }));
  const spawns = o.spawns ?? 8;
  for (let i = 0; i < spawns; i++) {
    const a = (i / spawns) * Math.PI * 2;
    children.push(part(`RoundSpawn${i + 1}`, [x + Math.cos(a) * s * 0.38, y + 0.5, z + Math.sin(a) * s * 0.38], [4, 1, 4], {
      transparency: 1, canCollide: false, tags: ['RoundSpawn'],
    }));
  }
  return model('Arena', children);
}

// --- Maze (horror/escape) --------------------------------------------------------------------

export function maze(o: { position?: Vec; width?: number; height?: number; cell?: number; seed?: number; keys?: number; ceiling?: boolean; monster?: boolean } = {}): InstanceNode {
  const [ox, oy, oz] = o.position ?? [0, 0, 0];
  const W = Math.max(4, Math.min(25, o.width ?? 10));
  const H = Math.max(4, Math.min(25, o.height ?? 10));
  const C = o.cell ?? 12;
  const wallH = 12;
  const r = rng(o.seed ?? 1337);
  // Recursive backtracker: open[x][y] = { n, e, s, w } passages.
  const visited = Array.from({ length: W }, () => Array(H).fill(false));
  const eastOpen = Array.from({ length: W }, () => Array(H).fill(false));
  const northOpen = Array.from({ length: W }, () => Array(H).fill(false));
  const stack: Array<[number, number]> = [[0, 0]];
  visited[0][0] = true;
  while (stack.length) {
    const [cx, cy] = stack[stack.length - 1];
    const options: Array<[number, number, string]> = [];
    if (cx > 0 && !visited[cx - 1][cy]) options.push([cx - 1, cy, 'w']);
    if (cx < W - 1 && !visited[cx + 1][cy]) options.push([cx + 1, cy, 'e']);
    if (cy > 0 && !visited[cx][cy - 1]) options.push([cx, cy - 1, 's']);
    if (cy < H - 1 && !visited[cx][cy + 1]) options.push([cx, cy + 1, 'n']);
    if (!options.length) { stack.pop(); continue; }
    const [nx, ny, dir] = options[Math.floor(r() * options.length)];
    if (dir === 'e') eastOpen[cx][cy] = true;
    if (dir === 'w') eastOpen[nx][ny] = true;
    if (dir === 'n') northOpen[cx][cy] = true;
    if (dir === 's') northOpen[nx][ny] = true;
    visited[nx][ny] = true;
    stack.push([nx, ny]);
  }
  const wx = (cx: number) => ox + (cx - (W - 1) / 2) * C;
  const wz = (cy: number) => oz + cy * C + C / 2;
  const wallColor: RGB = [70, 64, 60];
  const children: InstanceNode[] = [
    part('Floor', [ox, oy - 1, oz + (H * C) / 2], [W * C + 2, 2, H * C + 2], { color: [45, 40, 38], material: 'Slate' }),
  ];
  let n = 0;
  const wall = (x: number, z: number, sx: number, sz: number) =>
    children.push(part(`Wall${++n}`, [x, oy + wallH / 2, z], [sx, wallH, sz], { color: wallColor, material: 'Brick' }));
  // Outer walls (south wall has the entrance at cell 0, north wall the exit at cell W-1).
  for (let cx = 0; cx < W; cx++) {
    if (cx !== 0) wall(wx(cx), oz, C + 1, 1);
    if (cx !== W - 1) wall(wx(cx), oz + H * C, C + 1, 1);
  }
  wall(ox - (W * C) / 2, oz + (H * C) / 2, 1, H * C + 1);
  wall(ox + (W * C) / 2, oz + (H * C) / 2, 1, H * C + 1);
  // Inner walls.
  for (let cx = 0; cx < W; cx++) {
    for (let cy = 0; cy < H; cy++) {
      if (cx < W - 1 && !eastOpen[cx][cy]) wall(wx(cx) + C / 2, wz(cy), 1, C + 1);
      if (cy < H - 1 && !northOpen[cx][cy]) wall(wx(cx), wz(cy) + C / 2, C + 1, 1);
    }
  }
  if (o.ceiling !== false) {
    children.push(part('Ceiling', [ox, oy + wallH + 0.5, oz + (H * C) / 2], [W * C + 2, 1, H * C + 2], { color: [30, 28, 26], material: 'Slate', castShadow: true }));
  }
  // Dead ends far from the start hold the keys.
  const deadEnds: Array<[number, number, number]> = [];
  for (let cx = 0; cx < W; cx++) {
    for (let cy = 0; cy < H; cy++) {
      const exits = (eastOpen[cx][cy] ? 1 : 0) + (cx > 0 && eastOpen[cx - 1][cy] ? 1 : 0)
        + (northOpen[cx][cy] ? 1 : 0) + (cy > 0 && northOpen[cx][cy - 1] ? 1 : 0);
      if (exits === 1 && cx + cy > 2) deadEnds.push([cx, cy, cx + cy + r()]);
    }
  }
  deadEnds.sort((a, b) => b[2] - a[2]);
  const keyCount = Math.max(1, Math.min(o.keys ?? 3, deadEnds.length));
  const step = Math.max(1, Math.floor(deadEnds.length / keyCount));
  for (let k = 0; k < keyCount; k++) {
    const [cx, cy] = deadEnds[Math.min(deadEnds.length - 1, k * step)];
    children.push(piece('key', [wx(cx), oy + 2.5, wz(cy)], { name: `Key${k + 1}` }));
  }
  // Flickering lights in some cells.
  for (let cx = 0; cx < W; cx++) {
    for (let cy = 0; cy < H; cy++) {
      if (r() < 0.12) {
        children.push(part(`Light_${cx}_${cy}`, [wx(cx), oy + wallH - 0.6, wz(cy)], [1.2, 0.4, 1.2], {
          color: [255, 214, 150], material: 'Neon', tags: ['FlickerLight'], children: [light(18, 0.9, [255, 200, 140])],
        }));
      }
    }
  }
  if (o.monster !== false) {
    const mx = Math.floor(W / 2);
    const my = Math.floor(H / 2);
    children.push(piece('enemy_spawner', [wx(mx), oy + 1, wz(my)], { name: 'MonsterSpawner', enemy: 'Monster', maxAlive: 1, respawn: 12 }));
  }
  // Start room (south) and exit (north).
  const sz = oz - 14;
  children.push(part('StartRoomFloor', [wx(0), oy - 1, sz], [24, 2, 26], { color: [60, 55, 50], material: 'WoodPlanks' }));
  children.push(part('StartSpawn', [wx(0), oy + 0.5, sz - 4], [10, 1, 10], { className: 'SpawnLocation', color: [80, 80, 80], rot: [0, 180, 0], tags: ['LobbySpawn'], props: { Neutral: true, Duration: 3 } }));
  children.push(lamp('StartLamp', [wx(0) + 8, oy, sz], false));
  children.push(part('StartWallW', [wx(0) - 12, oy + wallH / 2, sz], [1, wallH, 26], { color: wallColor, material: 'Brick' }));
  children.push(part('StartWallE', [wx(0) + 12, oy + wallH / 2, sz], [1, wallH, 26], { color: wallColor, material: 'Brick' }));
  children.push(part('StartWallS', [wx(0), oy + wallH / 2, sz - 13], [24, wallH, 1], { color: wallColor, material: 'Brick' }));
  children.push(part('StartWallN_W', [wx(0) - 9, oy + wallH / 2, oz - 0.5], [6, wallH, 1], { color: wallColor, material: 'Brick' }));
  children.push(part('StartWallN_E', [wx(0) + 9, oy + wallH / 2, oz - 0.5], [6, wallH, 1], { color: wallColor, material: 'Brick' }));
  const ex = wx(W - 1);
  const ez = oz + H * C;
  children.push(part('ExitDoor', [ex, oy + wallH / 2, ez], [C - 1, wallH, 1.5], { color: [120, 40, 40], material: 'Metal', tags: ['ExitDoor'], attrs: { KeysRequired: keyCount } }));
  children.push(part('ExitRoom', [ex, oy - 1, ez + 10], [C + 8, 2, 20], { color: [40, 90, 50], material: 'Grass' }));
  children.push(part('ExitWallW', [ex - C / 2 - 4, oy + wallH / 2, ez + 10], [1, wallH, 20], { color: wallColor, material: 'Brick' }));
  children.push(part('ExitWallE', [ex + C / 2 + 4, oy + wallH / 2, ez + 10], [1, wallH, 20], { color: wallColor, material: 'Brick' }));
  children.push(part('ExitWallN', [ex, oy + wallH / 2, ez + 20], [C + 8, wallH, 1], { color: wallColor, material: 'Brick' }));
  children.push(part('ExitZone', [ex, oy + 3, ez + 14], [C, 6, 8], {
    transparency: 0.7, canCollide: false, color: [80, 255, 120], material: 'Neon', tags: ['ExitZone'],
    children: [billboard('EXIT', [120, 255, 150], 4, [6, 2])],
  }));
  return model('Maze', children);
}

// --- Tycoon ----------------------------------------------------------------------------------

interface TycoonItem { name: string; price: number; requires?: string; build: (px: number, py: number, pz: number) => InstanceNode }

function dropper(name: string, x: number, y: number, z: number, value: number, rgb: RGB, big = false): InstanceNode {
  const s = big ? 5 : 3;
  return model(name, [
    part('Dropper', [x, y + 8, z], [s, s, s], { color: rgb, material: 'Metal', tags: ['Dropper'], attrs: { DropValue: value, DropInterval: big ? 1.5 : 2, OreColor: `#${rgb.map((c) => c.toString(16).padStart(2, '0')).join('')}` } }),
    part('Support', [x, y + 5, z - 4], [1, 10, 1], { color: [80, 80, 85], material: 'Metal' }),
    part('Arm', [x, y + 9.5, z - 2], [1, 1, 4], { color: [80, 80, 85], material: 'Metal' }),
  ]);
}

export function tycoonPlots(o: { count?: number; position?: Vec; theme?: string } = {}): InstanceNode {
  const count = Math.max(1, Math.min(8, o.count ?? 4));
  const [bx, by, bz] = o.position ?? [0, 0, 0];
  const spacing = 80;
  const plots: InstanceNode[] = [];
  for (let i = 0; i < count; i++) {
    const px = bx + (i - (count - 1) / 2) * spacing;
    const py = by;
    const pz = bz;
    const convZ = pz - 18;
    const items: TycoonItem[] = [
      { name: 'Dropper1', price: 0, build: () => dropper('Dropper1', px - 16, py, convZ, 5, [158, 158, 158]) },
      { name: 'Dropper2', price: 50, requires: 'Dropper1', build: () => dropper('Dropper2', px - 8, py, convZ, 10, [141, 110, 99]) },
      { name: 'Walls', price: 150, requires: 'Dropper2', build: () => model('Walls', [
        part('BackWall', [px, py + 6, pz - 31.5], [64, 12, 1], { color: [236, 239, 241], material: 'Brick' }),
        part('LeftWall', [px - 31.5, py + 6, pz - 8], [1, 12, 48], { color: [236, 239, 241], material: 'Brick' }),
        part('RightWall', [px + 31.5, py + 6, pz - 8], [1, 12, 48], { color: [236, 239, 241], material: 'Brick' }),
      ]) },
      { name: 'Dropper3', price: 250, requires: 'Dropper2', build: () => dropper('Dropper3', px, py, convZ, 20, [255, 193, 7]) },
      { name: 'Upgrader', price: 500, requires: 'Dropper3', build: () => part('Upgrader', [px + 12, py + 3, convZ], [1, 4, 5], { color: [0, 229, 255], material: 'Neon', transparency: 0.4, canCollide: false, tags: ['Upgrader'], attrs: { Multiplier: 2 }, children: [billboard('x2', [120, 240, 255], 3, [3, 1.5])] }) },
      { name: 'Dropper4', price: 900, requires: 'Upgrader', build: () => dropper('Dropper4', px + 4, py, convZ, 40, [76, 175, 80]) },
      { name: 'Garden', price: 1200, requires: 'Walls', build: () => model('Garden', [
        tree('Tree1', [px - 24, py, pz + 20], rng(i * 3 + 1)), tree('Tree2', [px + 24, py, pz + 20], rng(i * 3 + 2)),
        part('Grass', [px, py + 0.05, pz + 14], [60, 0.2, 16], { color: [102, 187, 106], material: 'Grass' }),
      ]) },
      { name: 'Dropper5', price: 2000, requires: 'Dropper4', build: () => dropper('Dropper5', px + 18, py, convZ, 80, [156, 39, 176]) },
      { name: 'SuperDropper', price: 6000, requires: 'Dropper5', build: () => dropper('SuperDropper', px - 2, py + 6, convZ - 1, 300, [255, 87, 34], true) },
      { name: 'Tower', price: 15000, requires: 'SuperDropper', build: () => model('Tower', [
        part('TowerBase', [px - 24, py + 15, pz - 24], [8, 30, 8], { color: [255, 213, 79], material: 'Marble' }),
        part('TowerTop', [px - 24, py + 30.5, pz - 24], [12, 1, 12], { color: [255, 193, 7], material: 'Neon' }),
        part('TowerLadder', [px - 19.5, py + 15, pz - 24], [1, 30, 2], { className: 'TrussPart', color: [120, 120, 120] }),
      ]) },
    ];
    const buttons: InstanceNode[] = items.map((item, k) => part(`Buy_${item.name}`, [px - 20 + (k % 5) * 10, py + 0.6, pz + 6 + Math.floor(k / 5) * 10], [4, 0.6, 4], {
      color: [0, 230, 118], material: 'Neon',
      attrs: { Item: item.name, Price: item.price, ...(item.requires ? { Requires: item.requires } : {}) },
    }));
    plots.push(model(`Plot${i + 1}`, [
      part('Base', [px, py - 0.5, pz], [64, 1, 64], { color: [120, 144, 156], material: 'Concrete' }),
      part('Claim', [px, py + 0.6, pz + 28], [10, 0.6, 5], { color: [255, 235, 59], material: 'Neon' }),
      part('Conveyor', [px, py + 1, convZ], [44, 1, 5], { color: [40, 40, 45], material: 'DiamondPlate', rot: [0, -90, 0], tags: ['Conveyor'], attrs: { Speed: 10 } }),
      part('RailFront', [px, py + 2, convZ + 2.75], [44, 1, 0.5], { color: [90, 90, 95], material: 'Metal' }),
      part('RailBack', [px, py + 2, convZ - 2.75], [44, 1, 0.5], { color: [90, 90, 95], material: 'Metal' }),
      part('Collector', [px + 24.5, py + 2, convZ], [5, 4, 6], { color: [0, 200, 83], material: 'Neon', tags: ['Collector'], children: [billboard('💵 COLLECT', [150, 255, 170], 4, [8, 2])] }),
      folder('Buttons', buttons),
      folder('Items', items.map((item) => item.build(px, py, pz))),
    ], { tags: ['TycoonPlot'] }));
  }
  plots.push(part('Road', [bx, by - 0.45, bz + 50], [count * spacing, 1, 20], { color: [55, 71, 79], material: 'Asphalt' }));
  plots.push(part('Spawn', [bx, by + 0.5, bz + 50], [12, 1, 12], { className: 'SpawnLocation', color: [255, 213, 79], tags: ['LobbySpawn'], props: { Neutral: true, Duration: 3 } }));
  return model('Tycoon', plots);
}

// --- Simulator -------------------------------------------------------------------------------

export function simulatorWorld(o: { zones?: number; position?: Vec; basePrice?: number } = {}): InstanceNode {
  const zones = Math.max(1, Math.min(6, o.zones ?? 3));
  const [x, y, z] = o.position ?? [0, 0, 0];
  const r = rng(99);
  const zoneColors: RGB[] = [[129, 199, 132], [255, 213, 79], [100, 181, 246], [186, 104, 200], [239, 83, 80], [77, 208, 225]];
  const children: InstanceNode[] = [
    part('HubFloor', [x, y - 1, z], [80, 2, 80], { color: [120, 180, 110], material: 'Grass' }),
    part('Spawn', [x, y + 0.5, z - 20], [12, 1, 12], { className: 'SpawnLocation', color: [255, 255, 255], tags: ['LobbySpawn'], props: { Neutral: true, Duration: 3 } }),
    piece('sell_pad', [x + 22, y + 0.3, z], { name: 'SellPad' }),
    piece('shop_stand', [x - 22, y, z], { name: 'ShopStand' }),
    piece('leaderboard', [x, y, z - 38], { name: 'Leaderboard', stat: 'Rebirths', title: 'Top Rebirths' }),
  ];
  for (const [i, [wx, wz, sx, sz]] of ([[-40, 0, 1, 80], [40, 0, 1, 80], [0, -40, 80, 1]] as const).entries()) {
    children.push(part(`HubWall${i + 1}`, [x + wx, y + 10, z + wz], [sx, 20, sz], { color: [200, 200, 200], transparency: 0.6, material: 'Glass' }));
  }
  for (let k = 0; k < 8; k++) {
    children.push(piece('coin', [x + (r() - 0.5) * 60, y + 2, z + (r() - 0.5) * 60], { name: `Orb${k}`, stat: 'Power', amount: 1, respawn: 6 }));
  }
  let price = o.basePrice ?? 250;
  for (let k = 1; k <= zones; k++) {
    const zz = z + 40 + (k - 0.5) * 80;
    const rgb = zoneColors[k % zoneColors.length];
    const zoneName = `Zone ${k + 1}`;
    const kids: InstanceNode[] = [
      part('Floor', [x, y - 1, zz], [80, 2, 80], { color: rgb, material: 'Grass' }),
      part('WallL', [x - 40, y + 10, zz], [1, 20, 80], { color: shade(rgb, -0.3), material: 'Glass', transparency: 0.5 }),
      part('WallR', [x + 40, y + 10, zz], [1, 20, 80], { color: shade(rgb, -0.3), material: 'Glass', transparency: 0.5 }),
      part('EntryWallL', [x - 24, y + 10, zz - 40], [32, 20, 1], { color: shade(rgb, -0.3), material: 'Glass', transparency: 0.5 }),
      part('EntryWallR', [x + 24, y + 10, zz - 40], [32, 20, 1], { color: shade(rgb, -0.3), material: 'Glass', transparency: 0.5 }),
      piece('zone_gate', [x, y + 7, zz - 40], { name: 'Gate', zone: zoneName, price }),
      part('ZoneSign', [x, y + 18, zz - 40.5], [16, 4, 0.5], { color: [30, 30, 40], children: [surfaceText(zoneName, [255, 255, 255], 'Front')] }),
    ];
    if (k === zones) kids.push(part('EndWall', [x, y + 10, zz + 40], [80, 20, 1], { color: shade(rgb, -0.3), material: 'Glass', transparency: 0.5 }));
    for (let o2 = 0; o2 < 12; o2++) {
      kids.push(piece('coin', [x + (r() - 0.5) * 64, y + 2, zz + (r() - 0.5) * 64], { name: `Orb${o2}`, stat: 'Power', amount: 5 * 4 ** (k - 1), respawn: 6 }));
    }
    children.push(model(zoneName.replace(' ', ''), kids));
    price *= 10;
  }
  return model('SimulatorWorld', children);
}

/** Scatters trees and rocks around an area (keeps a clear radius in the middle). */
export function decorScatter(o: { position?: Vec; radius?: number; count?: number; clear?: number; seed?: number } = {}): InstanceNode {
  const [x, y, z] = o.position ?? [0, 0, 0];
  const radius = o.radius ?? 150;
  const clear = o.clear ?? 60;
  const r = rng(o.seed ?? 5);
  const kids: InstanceNode[] = [];
  for (let i = 0; i < (o.count ?? 30); i++) {
    const a = r() * Math.PI * 2;
    const d = clear + r() * (radius - clear);
    const pos: Vec = [x + Math.cos(a) * d, y, z + Math.sin(a) * d];
    kids.push(r() < 0.7 ? tree(`Tree${i}`, pos, r) : piece('rock', pos, { name: `Rock${i}` }));
  }
  return model('Decor', kids);
}

// --- Tower defense ----------------------------------------------------------------------------

/** A grass field with a winding enemy path, tower pads along it, the base and a portal. */
export function tdMap(o: { position?: Vec; theme?: string } = {}): InstanceNode {
  const [x, y, z] = o.position ?? [0, 0, 0];
  const route: Array<[number, number]> = [[-75, -55], [50, -55], [50, -15], [-50, -15], [-50, 25], [50, 25], [50, 62], [-62, 62]];
  const kids: InstanceNode[] = [
    part('Field', [x, y - 1, z], [180, 2, 180], { color: [106, 168, 79], material: 'Grass' }),
    part('Spawn', [x, y + 0.5, z + 5], [10, 1, 10], { className: 'SpawnLocation', color: [255, 255, 255], tags: ['LobbySpawn'], props: { Neutral: true, Duration: 3 } }),
  ];
  const waypoints: InstanceNode[] = route.map(([wx, wz], i) => part(`WP${i + 1}`, [x + wx, y + 0.2, z + wz], [1, 1, 1], { transparency: 1, canCollide: false, attrs: { Order: i + 1 } }));
  kids.push({ name: 'Path', className: 'Folder', tags: ['TDPath'], children: waypoints });
  for (let i = 0; i < route.length - 1; i++) {
    const [ax, az] = route[i];
    const [bx, bz] = route[i + 1];
    const length = Math.hypot(bx - ax, bz - az) + 10;
    const horizontal = az === bz;
    kids.push(part(`Road${i + 1}`, [x + (ax + bx) / 2, y + 0.05, z + (az + bz) / 2], horizontal ? [length, 0.2, 10] : [10, 0.2, length], { color: [215, 190, 140], material: 'Sand', canCollide: true }));
  }
  const pads: Array<[number, number, string]> = [
    [-40, -35, 'Archer'], [-10, -35, 'Frost'], [20, -35, 'Archer'], [65, -35, 'Cannon'],
    [-35, 5, 'Cannon'], [-20, 5, 'Archer'], [20, 5, 'Archer'], [35, 5, 'Frost'],
    [-65, 5, 'Archer'], [65, 5, 'Cannon'],
    [-30, 44, 'Frost'], [0, 44, 'Cannon'], [30, 44, 'Archer'], [-5, 78, 'Archer'], [25, 78, 'Frost'],
  ];
  pads.forEach(([px, pz, tower], i) => kids.push(piece('tower_pad', [x + px, y + 0.5, z + pz], { name: `Pad${i + 1}`, tower })));
  const [sx, sz] = route[0];
  kids.push(model('Portal', [
    part('Ring', [x + sx, y + 6, z + sz], [1, 12, 12], { shape: 'Cylinder', color: [171, 71, 188], material: 'Neon', transparency: 0.3, canCollide: false, children: [sparkles([200, 120, 255], 20)] }),
    part('Stone', [x + sx, y + 0.5, z + sz], [4, 1, 14], { color: [80, 80, 90], material: 'Slate' }),
  ]));
  const [ex, ez] = route[route.length - 1];
  kids.push(model('Base', [
    part('Keep', [x + ex - 6, y + 8, z + ez], [12, 16, 14], { color: [189, 189, 189], material: 'Brick', tags: ['TDBase'], children: [{ ...billboard('🏰 100 / 100', [255, 255, 255], 11, [12, 3]), name: 'GK_BaseLabel' }] }),
    part('TowerL', [x + ex - 6, y + 11, z + ez - 8], [5, 22, 5], { color: [158, 158, 158], material: 'Brick' }),
    part('TowerR', [x + ex - 6, y + 11, z + ez + 8], [5, 22, 5], { color: [158, 158, 158], material: 'Brick' }),
    part('Flag', [x + ex - 6, y + 20, z + ez], [0.4, 4, 3], { color: [229, 57, 53], material: 'Fabric' }),
  ]));
  return model('TowerDefenseMap', kids);
}

// --- Farm --------------------------------------------------------------------------------------

/** Fields of plots, seed stands for every crop, a market and a small barn. */
export function farm(o: { position?: Vec; plots?: number; crops?: string[] } = {}): InstanceNode {
  const [x, y, z] = o.position ?? [0, 0, 0];
  const count = Math.max(4, Math.min(64, o.plots ?? 24));
  const crops = o.crops ?? ['Wheat', 'Carrot', 'Tomato', 'Pumpkin', 'Crystal'];
  const cropColors: RGB[] = [[244, 208, 63], [230, 126, 34], [231, 76, 60], [211, 84, 0], [142, 68, 173]];
  const kids: InstanceNode[] = [
    part('Ground', [x, y - 1, z], [200, 2, 160], { color: [124, 179, 66], material: 'Grass' }),
    part('Spawn', [x, y + 0.5, z - 55], [10, 1, 10], { className: 'SpawnLocation', color: [255, 236, 179], tags: ['LobbySpawn'], props: { Neutral: true, Duration: 3 } }),
    part('Lane', [x, y + 0.05, z - 30], [160, 0.2, 10], { color: [188, 170, 164], material: 'Pebble' }),
  ];
  const perRow = 8;
  const plots: InstanceNode[] = [];
  for (let i = 0; i < count; i++) {
    const row = Math.floor(i / perRow);
    const col = i % perRow;
    plots.push(piece('farm_plot', [x - 49 + col * 14, y + 0.3, z - 12 + row * 14], { name: `Plot${i + 1}` }));
  }
  kids.push(folder('Plots', plots));
  crops.forEach((crop, i) => kids.push(piece('seed_stand', [x - 60 + i * 16, y, z - 42], { name: `Seeds_${crop}`, crop, color: cropColors[i % cropColors.length] })));
  kids.push(piece('market', [x + 60, y, z - 42], { name: 'Market' }));
  kids.push(model('Barn', [
    part('Walls', [x + 80, y + 7, z + 30], [22, 14, 30], { color: [183, 28, 28], material: 'WoodPlanks' }),
    part('Roof', [x + 80, y + 16, z + 30], [24, 4, 32], { color: [66, 66, 66], material: 'Slate' }),
    part('Door', [x + 68.9, y + 5, z + 30], [0.4, 10, 8], { color: [255, 255, 255], material: 'WoodPlanks' }),
  ]));
  for (let i = 0; i < 12; i++) {
    const side = i < 6 ? -1 : 1;
    kids.push(piece('fence', [x + side * 98, y, z - 60 + (i % 6) * 24], { name: `Fence${i + 1}`, yaw: 90, length: 24 }));
  }
  return model('Farm', kids);
}

// --- Race track ----------------------------------------------------------------------------

/** Yaw (degrees) that points a part's X axis along (dx, dz). */
const yawAlong = (dx: number, dz: number) => (Math.atan2(-dz, dx) * 180) / Math.PI;

/**
 * Oval kart track (two straights + two bends) with barriers, 3 checkpoints, a start/finish
 * arch, a starting grid for `grid` racers, grandstands and a leaderboard. Race direction: +X
 * on the near straight (z + radius).
 */
export function raceTrack(o: { position?: Vec; length?: number; radius?: number; width?: number; grid?: number; theme?: string } = {}): InstanceNode {
  const [x, y, z] = o.position ?? [0, 0, 0];
  const L = Math.max(60, Math.min(400, o.length ?? 180));
  const R = Math.max(30, Math.min(150, o.radius ?? 60));
  const W = Math.max(16, Math.min(60, o.width ?? 30));
  const road: RGB = [55, 55, 60];
  const kids: InstanceNode[] = [
    part('Ground', [x, y - 1, z], [L + 2 * R + 120, 2, 2 * R + 140], { color: [106, 168, 79], material: 'Grass' }),
  ];
  const segments: InstanceNode[] = [];
  const barriers: InstanceNode[] = [];
  const addSegment = (ax: number, az: number, bx: number, bz: number, i: number, stripe: boolean) => {
    const len = Math.hypot(bx - ax, bz - az) + 1.5;
    const yaw = yawAlong(bx - ax, bz - az);
    segments.push(part(`Road${i}`, [(ax + bx) / 2, y + 0.1, (az + bz) / 2], [len, 0.2, W], { color: road, material: 'Asphalt', rot: [0, yaw, 0] }));
    // Barriers on both edges (offset along the segment normal).
    const nx = -(bz - az) / (len - 1.5);
    const nz = (bx - ax) / (len - 1.5);
    for (const side of [-1, 1]) {
      const off = side * (W / 2 + 1);
      barriers.push(part(`Barrier${i}_${side > 0 ? 'A' : 'B'}`, [(ax + bx) / 2 + nx * off, y + 1.5, (az + bz) / 2 + nz * off], [len, 3, 1.2], {
        color: stripe ? [229, 57, 53] : [245, 245, 245], material: 'SmoothPlastic', rot: [0, yaw, 0],
      }));
    }
  };
  // Near straight (+X), right bend, far straight (-X), left bend.
  addSegment(x - L / 2, z + R, x + L / 2, z + R, 1, false);
  const steps = 12;
  let index = 2;
  for (let k = 0; k < steps; k++) {
    const a0 = Math.PI / 2 - (Math.PI * k) / steps;
    const a1 = Math.PI / 2 - (Math.PI * (k + 1)) / steps;
    addSegment(x + L / 2 + R * Math.cos(a0), z + R * Math.sin(a0), x + L / 2 + R * Math.cos(a1), z + R * Math.sin(a1), index++, k % 2 === 0);
  }
  addSegment(x + L / 2, z - R, x - L / 2, z - R, index++, false);
  for (let k = 0; k < steps; k++) {
    const a0 = -Math.PI / 2 - (Math.PI * k) / steps;
    const a1 = -Math.PI / 2 - (Math.PI * (k + 1)) / steps;
    addSegment(x - L / 2 + R * Math.cos(a0), z + R * Math.sin(a0), x - L / 2 + R * Math.cos(a1), z + R * Math.sin(a1), index++, k % 2 === 0);
  }
  kids.push(folder('Road', segments), folder('Barriers', barriers));
  // Checkpoints in race order, then the finish line in the middle of the near straight.
  kids.push(folder('Checkpoints', [
    piece('race_checkpoint', [x + L / 2 + R, y + 8, z], { name: 'Checkpoint1', order: 1, yaw: 90, size: [4, 16, W + 4] }),
    piece('race_checkpoint', [x, y + 8, z - R], { name: 'Checkpoint2', order: 2, yaw: 0, size: [4, 16, W + 4] }),
    piece('race_checkpoint', [x - L / 2 - R, y + 8, z], { name: 'Checkpoint3', order: 3, yaw: 90, size: [4, 16, W + 4] }),
  ]));
  kids.push(piece('race_finish', [x, y + 8, z + R], { name: 'Finish', width: W + 4 }));
  const grid: InstanceNode[] = [];
  const racers = Math.max(2, Math.min(16, o.grid ?? 8));
  for (let i = 0; i < racers; i++) {
    const row = Math.floor(i / 2);
    const lane = i % 2 === 0 ? -1 : 1;
    grid.push(piece('race_grid', [x - 14 - row * 12, y + 0.3, z + R + lane * (W / 4)], { name: `Grid${i + 1}`, order: i + 1 }));
  }
  kids.push(folder('Grid', grid));
  kids.push(part('Spawn', [x, y + 0.5, z + R + W / 2 + 22], [12, 1, 12], { className: 'SpawnLocation', color: [255, 255, 255], tags: ['LobbySpawn'], props: { Neutral: true, Duration: 3 } }));
  // Grandstand along the near straight + boost pads on the straights.
  for (let k = 0; k < 4; k++) {
    kids.push(part(`Stand${k + 1}`, [x, y + (k + 1) * 0.75, z + R + W / 2 + 32 + k * 4], [80, (k + 1) * 1.5, 4], { color: k % 2 ? [158, 158, 158] : [120, 144, 156], material: 'Concrete' }));
  }
  kids.push(piece('boost_pad', [x + L / 4, y + 0.3, z + R], { name: 'Boost1', yaw: -90 }));
  kids.push(piece('boost_pad', [x - L / 4, y + 0.3, z - R], { name: 'Boost2', yaw: 90 }));
  kids.push(piece('leaderboard', [x + 56, y, z + R + W / 2 + 30], { name: 'WinsBoard', stat: 'Wins', title: 'Top Racers', yaw: 180 }));
  return model('RaceTrack', kids);
}

// --- Fishing lake --------------------------------------------------------------------------

function pond(name: string, cx: number, y: number, cz: number, diameter: number, rgb: RGB, zone: string, spots: number): InstanceNode {
  const r = diameter / 2;
  const kids: InstanceNode[] = [
    part('Water', [cx, y + 0.35, cz], [0.7, diameter, diameter], { shape: 'Cylinder', rot: [0, 0, 90], color: rgb, material: 'Glass', transparency: 0.35, canCollide: false, reflectance: 0.1 }),
    part('Bed', [cx, y + 0.02, cz], [0.1, diameter + 4, diameter + 4], { shape: 'Cylinder', rot: [0, 0, 90], color: [194, 178, 128], material: 'Sand', canCollide: false }),
  ];
  for (let i = 0; i < spots; i++) {
    const a = (i / spots) * Math.PI * 2 + 0.4;
    const dx = Math.cos(a);
    const dz = Math.sin(a);
    kids.push(piece('fishing_spot', [cx + dx * (r - 9), y + 0.4, cz + dz * (r - 9)], { name: `Spot${i + 1}`, zone }));
    kids.push(part(`Dock${i + 1}`, [cx + dx * (r - 1), y + 1.2, cz + dz * (r - 1)], [14, 0.6, 5], { color: [141, 110, 99], material: 'WoodPlanks', rot: [0, yawAlong(dx, dz), 0] }));
  }
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2;
    kids.push(part(`Stone${i + 1}`, [cx + Math.cos(a) * (r + 2), y + 0.6, cz + Math.sin(a) * (r + 2)], [3, 1.4, 2.5], { color: [150, 150, 150], material: 'Rock', rot: [0, (i * 47) % 360, 0] }));
  }
  kids.push(part('Sign', [cx, y + 9, cz - r - 6], [14, 3, 0.6], { color: [93, 64, 55], material: 'Wood', children: [surfaceText(`🎣 ${zone}`, [255, 255, 255], 'Back', [93, 64, 55])] }));
  return model(name, kids);
}

/** A pond (Zone Pond) and an ocean bay (Zone Ocean) with docks and fishing spots, a fish market, a shop and a leaderboard. */
export function fishingLake(o: { position?: Vec; spots?: number } = {}): InstanceNode {
  const [x, y, z] = o.position ?? [0, 0, 0];
  const spots = Math.max(2, Math.min(10, o.spots ?? 5));
  const kids: InstanceNode[] = [
    part('Ground', [x, y - 1, z], [260, 2, 240], { color: [124, 179, 66], material: 'Grass' }),
    part('Spawn', [x, y + 0.5, z - 80], [12, 1, 12], { className: 'SpawnLocation', color: [255, 236, 179], tags: ['LobbySpawn'], props: { Neutral: true, Duration: 3 } }),
    part('Path', [x, y + 0.05, z - 50], [180, 0.2, 10], { color: [188, 170, 164], material: 'Pebble' }),
    pond('Pond', x - 55, y, z + 10, 70, [79, 195, 247], 'Pond', spots),
    pond('Ocean', x + 60, y, z + 30, 100, [21, 101, 192], 'Ocean', spots + 1),
    piece('item_sell', [x - 20, y, z - 70], { name: 'FishMarket', text: '🐟 FISH MARKET' }),
    piece('shop_stand', [x + 20, y, z - 70], { name: 'ShopStand' }),
    piece('leaderboard', [x, y, z - 105], { name: 'FishBoard', stat: 'Fish', title: 'Best Anglers', yaw: 0 }),
    piece('quest_target', [x + 60, y + 4, z + 90], { name: 'SecretCove', quest: 'SecretCove' }),
  ];
  kids.push(decorScatter({ position: [x, y, z], radius: 125, clear: 100, count: 30, seed: 11 }));
  return model('FishingLake', kids);
}

// --- Survival camp ---------------------------------------------------------------------------

/** Camp (spawn, crafting table, campfire) in a clearing, a forest of trees/rocks/berry bushes to gather, and enemy spawners at the edges. */
export function survivalCamp(o: { position?: Vec; size?: number; nodes?: number; seed?: number } = {}): InstanceNode {
  const [x, y, z] = o.position ?? [0, 0, 0];
  const s = Math.max(120, Math.min(400, o.size ?? 220));
  const r = rng(o.seed ?? 21);
  const count = Math.max(10, Math.min(120, o.nodes ?? 45));
  const kids: InstanceNode[] = [
    part('Ground', [x, y - 1, z], [s, 2, s], { color: [96, 139, 60], material: 'Grass' }),
    part('Clearing', [x, y + 0.03, z], [0.1, 44, 44], { shape: 'Cylinder', rot: [0, 0, 90], color: [150, 125, 90], material: 'Ground', canCollide: false }),
    part('Spawn', [x, y + 0.5, z + 10], [10, 1, 10], { className: 'SpawnLocation', color: [255, 236, 179], tags: ['LobbySpawn'], props: { Neutral: true, Duration: 5 } }),
    piece('campfire', [x, y, z], { name: 'CampFire' }),
    piece('crafting_table', [x - 12, y, z - 4], { name: 'CraftingTable' }),
    piece('shop_stand', [x + 14, y, z - 4], { name: 'ShopStand' }),
    piece('leaderboard', [x, y, z - 22], { name: 'KillsBoard', stat: 'Kills', title: 'Top Survivors', yaw: 0 }),
  ];
  const nodes: InstanceNode[] = [];
  const kinds = ['Tree', 'Tree', 'Rock', 'Bush'];
  for (let i = 0; i < count; i++) {
    const a = r() * Math.PI * 2;
    const d = 30 + r() * (s / 2 - 42);
    const node = kinds[i % kinds.length];
    nodes.push(piece('resource_node', [x + Math.cos(a) * d, y, z + Math.sin(a) * d], { name: `${node}${i + 1}`, node, seed: i + 3 }));
  }
  kids.push(folder('Resources', nodes));
  const edge = s / 2 - 8;
  kids.push(folder('Spawners', [
    piece('enemy_spawner', [x + edge, y + 1.5, z], { name: 'SpawnerEast' }),
    piece('enemy_spawner', [x - edge, y + 1.5, z], { name: 'SpawnerWest' }),
    piece('enemy_spawner', [x, y + 1.5, z + edge], { name: 'SpawnerSouth' }),
    piece('enemy_spawner', [x, y + 1.5, z - edge], { name: 'SpawnerNorth' }),
  ]));
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
    kids.push(lamp(`Torch${i + 1}`, [x + Math.cos(a) * 20, y, z + Math.sin(a) * 20], true));
  }
  return model('SurvivalCamp', kids);
}

export const WORLDS = ['obby_course', 'lobby', 'arena', 'maze', 'tycoon_plots', 'simulator_world', 'decor_scatter', 'td_map', 'farm', 'race_track', 'fishing_lake', 'survival_camp'] as const;

export function buildWorld(kind: string, options: Record<string, any> = {}): InstanceNode {
  switch (kind) {
    case 'obby_course': return obbyCourse(options);
    case 'lobby': return lobby(options);
    case 'arena': return arena(options);
    case 'maze': return maze(options);
    case 'tycoon_plots': return tycoonPlots(options);
    case 'simulator_world': return simulatorWorld(options);
    case 'decor_scatter': return decorScatter(options);
    case 'td_map': return tdMap(options);
    case 'farm': return farm(options);
    case 'race_track': return raceTrack(options);
    case 'fishing_lake': return fishingLake(options);
    case 'survival_camp': return survivalCamp(options);
    default: {
      const pos = (options.position as Vec) ?? [0, 5, 0];
      return piece(kind, pos, options);
    }
  }
}

export function worldPlacement(node: InstanceNode, name?: string): Placement {
  return { parent: ['Workspace', 'GameKit'], mode: 'replace', node: name ? { ...node, name } : node };
}

export function countParts(node: InstanceNode): number {
  let n = /Part$|SpawnLocation/.test(node.className) ? 1 : 0;
  for (const child of node.children ?? []) n += countParts(child);
  return n;
}
