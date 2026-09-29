/** Small helpers shared by the GameKit tool modules. */

export interface ToolContent {
  type: string;
  text?: string;
  data?: string;
  mimeType?: string;
}

export interface ToolResult {
  content: ToolContent[];
  isError?: boolean;
}

export function text(value: unknown): ToolResult {
  return { content: [{ type: 'text', text: typeof value === 'string' ? value : JSON.stringify(value, null, 2) }] };
}

/** A JSON summary followed by images (screenshots). */
export function withImages(value: unknown, images: Array<{ label?: string; data: string; mimeType?: string }>): ToolResult {
  const content: ToolContent[] = [text(value).content[0]];
  for (const image of images) {
    if (image.label) content.push({ type: 'text', text: image.label });
    content.push({ type: 'image', data: image.data, mimeType: image.mimeType ?? 'image/png' });
  }
  return { content };
}

/** The first text block of a tool result, parsed as JSON when possible. */
export function resultJson(result: any): any {
  const block = Array.isArray(result?.content) ? result.content.find((c: any) => c?.type === 'text') : undefined;
  if (!block?.text) return result;
  try {
    return JSON.parse(block.text);
  } catch {
    return block.text;
  }
}

export function resultImages(result: any): Array<{ data: string; mimeType: string }> {
  if (!Array.isArray(result?.content)) return [];
  return result.content
    .filter((c: any) => c?.type === 'image' && typeof c.data === 'string')
    .map((c: any) => ({ data: c.data, mimeType: c.mimeType ?? 'image/png' }));
}

export const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

export function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** Encodes a JS value for a Luau long string literal ([==[ ... ]==]). */
export function luauJson(value: unknown): string {
  const json = JSON.stringify(value ?? null);
  let eq = '=';
  while (json.includes(`]${eq}]`)) eq += '=';
  return `[${eq}[${json}]${eq}]`;
}

export type Vec3 = [number, number, number];

export function vec3(value: unknown, fallback: Vec3): Vec3 {
  if (Array.isArray(value) && value.length >= 3 && value.slice(0, 3).every((n) => typeof n === 'number' && Number.isFinite(n))) {
    return [value[0], value[1], value[2]];
  }
  if (value && typeof value === 'object') {
    const v = value as Record<string, unknown>;
    if ([v.x, v.y, v.z].every((n) => typeof n === 'number')) return [v.x as number, v.y as number, v.z as number];
  }
  return fallback;
}
