/**
 * Encoded Roblox values for install specs (decoded by gamekit/runtime/Applier.luau).
 * JSON cannot express Vector3/Color3/CFrame, so they travel as tagged objects.
 */

export type Encoded =
  | string
  | number
  | boolean
  | { $v3: [number, number, number] }
  | { $v2: [number, number] }
  | { $c3: [number, number, number] }
  | { $hex: string }
  | { $cf: [number, number, number, number?, number?, number?] }
  | { $ud2: [number, number, number, number] }
  | { $ud: [number, number] }
  | { $nr: [number, number] }
  | { $ns: number | Array<[number, number]> }
  | { $cs: [number, number, number] | Array<[number, [number, number, number]]> }
  | { $enum: string }
  | { $brick: string }
  | { $ref: string };

const round = (n: number) => Math.round(n * 1000) / 1000;

export const v3 = (x: number, y: number, z: number): Encoded => ({ $v3: [round(x), round(y), round(z)] });
export const v2 = (x: number, y: number): Encoded => ({ $v2: [round(x), round(y)] });
export const c3 = (r: number, g: number, b: number): Encoded => ({ $c3: [Math.round(r), Math.round(g), Math.round(b)] });
/** Position + rotation in degrees. */
export const cf = (x: number, y: number, z: number, rx = 0, ry = 0, rz = 0): Encoded => ({
  $cf: [round(x), round(y), round(z), round(rx), round(ry), round(rz)],
});
export const ud2 = (xs: number, xo: number, ys: number, yo: number): Encoded => ({ $ud2: [xs, xo, ys, yo] });
export const ud = (s: number, o: number): Encoded => ({ $ud: [s, o] });
export const nr = (min: number, max = min): Encoded => ({ $nr: [min, max] });
export const enumValue = (path: string): Encoded => ({ $enum: path });
export const ref = (path: string): Encoded => ({ $ref: path });

/** "#RRGGBB" -> [r, g, b]; also accepts "RRGGBB". Returns null for anything else. */
export function parseHex(hex: string): [number, number, number] | null {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex.trim());
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/** Accepts "#RRGGBB", a CSS-like color name, or [r,g,b]; returns an encoded Color3. */
export function color(value: unknown, fallback: [number, number, number] = [200, 200, 200]): Encoded {
  if (Array.isArray(value) && value.length >= 3) return c3(Number(value[0]), Number(value[1]), Number(value[2]));
  if (typeof value === 'string') {
    const hex = parseHex(value) ?? parseHex(NAMED_COLORS[value.toLowerCase()] ?? '');
    if (hex) return c3(...hex);
  }
  return c3(...fallback);
}

/** Lightens (amount > 0) or darkens (amount < 0) an [r,g,b] color. */
export function shade(rgb: [number, number, number], amount: number): [number, number, number] {
  return rgb.map((v) => Math.max(0, Math.min(255, Math.round(amount >= 0 ? v + (255 - v) * amount : v * (1 + amount))))) as [number, number, number];
}

export function rgbOf(value: unknown, fallback: [number, number, number]): [number, number, number] {
  if (Array.isArray(value) && value.length >= 3) return [Number(value[0]), Number(value[1]), Number(value[2])];
  if (typeof value === 'string') return parseHex(value) ?? parseHex(NAMED_COLORS[value.toLowerCase()] ?? '') ?? fallback;
  return fallback;
}

export const NAMED_COLORS: Record<string, string> = {
  red: '#E53935', orange: '#FB8C00', yellow: '#FDD835', gold: '#FFC940', green: '#43A047',
  lime: '#7CDB3A', teal: '#00897B', cyan: '#00BCD4', blue: '#1E88E5', navy: '#1A237E',
  purple: '#8E24AA', pink: '#EC407A', magenta: '#D81B60', white: '#F5F5F5', black: '#1B1B1B',
  gray: '#8A8A8A', grey: '#8A8A8A', brown: '#6D4C41', sand: '#E0C98F', stone: '#7B7B80',
  grass: '#4CAF50', wood: '#8D6E63', lava: '#FF5722', ice: '#B3E5FC', neon: '#39FF14',
};
