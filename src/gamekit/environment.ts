/**
 * Lighting presets and terrain generation, produced as a Luau chunk that the plugin runs
 * in edit mode (one undo step). Good lighting is the cheapest way to make a game look
 * professional, so templates always apply a preset.
 */

type RGB = [number, number, number];

interface Preset {
  description: string;
  lighting: Record<string, number | RGB | boolean>;
  atmosphere?: { Density: number; Offset?: number; Color: RGB; Decay: RGB; Glare?: number; Haze?: number };
  bloom?: { Intensity: number; Size: number; Threshold: number };
  colorCorrection?: { Brightness?: number; Contrast?: number; Saturation?: number; TintColor?: RGB };
  sunRays?: { Intensity: number; Spread: number };
  blur?: number;
  stars?: number;
}

export const LIGHTING_PRESETS: Record<string, Preset> = {
  day: {
    description: 'Bright, friendly daylight. Good default for obbies, simulators and tycoons.',
    lighting: { ClockTime: 14, Brightness: 2.5, Ambient: [70, 70, 80], OutdoorAmbient: [128, 128, 140], EnvironmentDiffuseScale: 1, EnvironmentSpecularScale: 1, GlobalShadows: true, ExposureCompensation: 0 },
    atmosphere: { Density: 0.3, Offset: 0.25, Color: [199, 199, 210], Decay: [106, 112, 125], Glare: 0, Haze: 1 },
    bloom: { Intensity: 0.6, Size: 24, Threshold: 1.5 },
    colorCorrection: { Saturation: 0.1, Contrast: 0.05 },
    sunRays: { Intensity: 0.05, Spread: 0.8 },
  },
  sunset: {
    description: 'Warm orange evening light, cinematic.',
    lighting: { ClockTime: 17.8, Brightness: 2, Ambient: [90, 60, 60], OutdoorAmbient: [140, 100, 90], EnvironmentDiffuseScale: 1, EnvironmentSpecularScale: 1, GlobalShadows: true },
    atmosphere: { Density: 0.4, Offset: 0.2, Color: [255, 170, 120], Decay: [180, 90, 90], Glare: 0.6, Haze: 2 },
    bloom: { Intensity: 0.8, Size: 30, Threshold: 1.2 },
    colorCorrection: { Saturation: 0.2, TintColor: [255, 230, 210] },
    sunRays: { Intensity: 0.15, Spread: 1 },
  },
  night: {
    description: 'Calm starry night with blue moonlight.',
    lighting: { ClockTime: 0, Brightness: 1, Ambient: [40, 40, 70], OutdoorAmbient: [60, 60, 110], GlobalShadows: true },
    atmosphere: { Density: 0.35, Offset: 0.1, Color: [70, 80, 120], Decay: [30, 30, 60], Haze: 1 },
    bloom: { Intensity: 0.8, Size: 24, Threshold: 1 },
    colorCorrection: { TintColor: [200, 210, 255], Brightness: -0.03 },
    stars: 5000,
  },
  horror: {
    description: 'Very dark, dense fog, desaturated. For horror/escape games (add FlickerLight lamps).',
    lighting: { ClockTime: 0, Brightness: 0, Ambient: [15, 15, 18], OutdoorAmbient: [25, 25, 30], GlobalShadows: true, ExposureCompensation: -0.3 },
    atmosphere: { Density: 0.6, Offset: 0, Color: [20, 20, 25], Decay: [10, 10, 12], Haze: 3 },
    bloom: { Intensity: 0.3, Size: 20, Threshold: 1.5 },
    colorCorrection: { Saturation: -0.6, Contrast: 0.2, TintColor: [200, 210, 200], Brightness: -0.08 },
    stars: 0,
  },
  fantasy: {
    description: 'Dreamy purple-pink magical light with strong glow.',
    lighting: { ClockTime: 15.5, Brightness: 2.5, Ambient: [100, 80, 120], OutdoorAmbient: [150, 120, 170], GlobalShadows: true },
    atmosphere: { Density: 0.35, Offset: 0.2, Color: [220, 190, 255], Decay: [160, 120, 200], Glare: 0.4, Haze: 2 },
    bloom: { Intensity: 1.2, Size: 40, Threshold: 1 },
    colorCorrection: { Saturation: 0.35, TintColor: [255, 240, 255] },
    sunRays: { Intensity: 0.15, Spread: 1 },
  },
  neon: {
    description: 'Cyberpunk night: purple haze and heavy glow on Neon parts.',
    lighting: { ClockTime: 21, Brightness: 1, Ambient: [60, 30, 80], OutdoorAmbient: [80, 40, 120], GlobalShadows: true },
    atmosphere: { Density: 0.45, Offset: 0.1, Color: [120, 60, 200], Decay: [40, 20, 90], Haze: 2.5 },
    bloom: { Intensity: 1.5, Size: 30, Threshold: 0.8 },
    colorCorrection: { Saturation: 0.5, Contrast: 0.15 },
    stars: 3000,
  },
  winter: {
    description: 'Cold bright snowy day.',
    lighting: { ClockTime: 13, Brightness: 2.2, Ambient: [150, 160, 180], OutdoorAmbient: [170, 180, 200], GlobalShadows: true },
    atmosphere: { Density: 0.45, Offset: 0.2, Color: [220, 230, 255], Decay: [180, 190, 220], Haze: 2 },
    bloom: { Intensity: 0.7, Size: 24, Threshold: 1.3 },
    colorCorrection: { TintColor: [230, 240, 255], Saturation: -0.1 },
  },
  desert: {
    description: 'Hot hazy desert sun.',
    lighting: { ClockTime: 13, Brightness: 3, Ambient: [120, 100, 80], OutdoorAmbient: [160, 140, 110], GlobalShadows: true },
    atmosphere: { Density: 0.4, Offset: 0.3, Color: [255, 220, 170], Decay: [200, 150, 100], Glare: 0.3, Haze: 2.5 },
    bloom: { Intensity: 0.6, Size: 24, Threshold: 1.4 },
    colorCorrection: { TintColor: [255, 240, 220], Saturation: 0.15 },
    sunRays: { Intensity: 0.1, Spread: 1 },
  },
  space: {
    description: 'Black sky full of stars, no atmosphere.',
    lighting: { ClockTime: 0, Brightness: 0.5, Ambient: [30, 30, 50], OutdoorAmbient: [40, 40, 70], GlobalShadows: true },
    bloom: { Intensity: 1, Size: 24, Threshold: 1 },
    colorCorrection: { Saturation: 0.2 },
    stars: 10000,
  },
  underwater: {
    description: 'Blue-green murky underwater look.',
    lighting: { ClockTime: 12, Brightness: 1, Ambient: [40, 90, 120], OutdoorAmbient: [50, 110, 140], GlobalShadows: true },
    atmosphere: { Density: 0.6, Offset: 0, Color: [40, 120, 160], Decay: [20, 60, 90], Haze: 2 },
    colorCorrection: { TintColor: [170, 220, 255], Saturation: -0.1 },
    blur: 3,
  },
};

export const TERRAIN_MODES = ['none', 'clear', 'flat', 'hills', 'island', 'water'] as const;

export interface EnvironmentOptions {
  preset?: string;
  clockTime?: number;
  terrain?: (typeof TERRAIN_MODES)[number];
  terrainSize?: number;
  terrainCenter?: [number, number, number];
  hillHeight?: number;
  water?: boolean;
  seed?: number;
  removeBaseplate?: boolean;
}

const rgb = (c: RGB) => `Color3.fromRGB(${c.join(', ')})`;

function value(v: number | RGB | boolean): string {
  if (Array.isArray(v)) return rgb(v);
  return String(v);
}

export function buildEnvironmentLuau(o: EnvironmentOptions): string {
  const lines: string[] = [
    'local Lighting = game:GetService("Lighting")',
    'local HttpService = game:GetService("HttpService")',
    'local ChangeHistoryService = game:GetService("ChangeHistoryService")',
    'local terrain = workspace.Terrain',
    'local applied = {}',
    'local recording',
    'pcall(function() recording = ChangeHistoryService:TryBeginRecording("GameKit environment") end)',
    'local ok, err = pcall(function()',
  ];
  const preset = o.preset ? LIGHTING_PRESETS[o.preset] : undefined;
  if (o.preset && !preset) throw new Error(`Unknown lighting preset "${o.preset}". Available: ${Object.keys(LIGHTING_PRESETS).join(', ')}`);
  if (preset) {
    lines.push(
      '\tfor _, child in Lighting:GetChildren() do',
      '\t\tif child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then child:Destroy() end',
      '\tend',
    );
    for (const [k, v] of Object.entries(preset.lighting)) lines.push(`\tpcall(function() Lighting.${k} = ${value(v)} end)`);
    lines.push('\tpcall(function() Lighting.Technology = Enum.Technology.Future end)');
    if (preset.atmosphere) {
      const a = preset.atmosphere;
      lines.push(
        '\tlocal atmosphere = Instance.new("Atmosphere")',
        `\tatmosphere.Density = ${a.Density}`,
        `\tatmosphere.Offset = ${a.Offset ?? 0}`,
        `\tatmosphere.Color = ${rgb(a.Color)}`,
        `\tatmosphere.Decay = ${rgb(a.Decay)}`,
        `\tatmosphere.Glare = ${a.Glare ?? 0}`,
        `\tatmosphere.Haze = ${a.Haze ?? 0}`,
        '\tatmosphere.Parent = Lighting',
      );
    }
    const sky = ['\tlocal sky = Instance.new("Sky")', `\tsky.StarCount = ${preset.stars ?? 3000}`, '\tsky.CelestialBodiesShown = true', '\tsky.Parent = Lighting'];
    lines.push(...sky);
    if (preset.bloom) {
      lines.push('\tlocal bloom = Instance.new("BloomEffect")', `\tbloom.Intensity = ${preset.bloom.Intensity}`, `\tbloom.Size = ${preset.bloom.Size}`, `\tbloom.Threshold = ${preset.bloom.Threshold}`, '\tbloom.Parent = Lighting');
    }
    if (preset.colorCorrection) {
      const c = preset.colorCorrection;
      lines.push('\tlocal cc = Instance.new("ColorCorrectionEffect")');
      if (c.Brightness !== undefined) lines.push(`\tcc.Brightness = ${c.Brightness}`);
      if (c.Contrast !== undefined) lines.push(`\tcc.Contrast = ${c.Contrast}`);
      if (c.Saturation !== undefined) lines.push(`\tcc.Saturation = ${c.Saturation}`);
      if (c.TintColor) lines.push(`\tcc.TintColor = ${rgb(c.TintColor)}`);
      lines.push('\tcc.Parent = Lighting');
    }
    if (preset.sunRays) lines.push('\tlocal rays = Instance.new("SunRaysEffect")', `\trays.Intensity = ${preset.sunRays.Intensity}`, `\trays.Spread = ${preset.sunRays.Spread}`, '\trays.Parent = Lighting');
    if (preset.blur) lines.push('\tlocal blur = Instance.new("BlurEffect")', `\tblur.Size = ${preset.blur}`, '\tblur.Parent = Lighting');
    lines.push(`\ttable.insert(applied, "lighting:${o.preset}")`);
  }
  if (o.clockTime !== undefined) lines.push(`\tLighting.ClockTime = ${Number(o.clockTime)}`, '\ttable.insert(applied, "clockTime")');
  if (o.removeBaseplate) {
    lines.push(
      '\tlocal baseplate = workspace:FindFirstChild("Baseplate")',
      '\tif baseplate then baseplate:Destroy() table.insert(applied, "removed Baseplate") end',
    );
  }
  const mode = o.terrain ?? 'none';
  if (mode !== 'none') {
    const size = Math.max(64, Math.min(2048, o.terrainSize ?? 512));
    const [cx, cy, cz] = o.terrainCenter ?? [0, 0, 0];
    const step = Math.max(8, Math.ceil(size / 64 / 4) * 4);
    const amp = o.hillHeight ?? 24;
    const seed = (o.seed ?? 7) * 17.13;
    lines.push(
      `\tlocal SIZE, STEP, CX, CY, CZ, AMP, SEED = ${size}, ${step}, ${cx}, ${cy}, ${cz}, ${amp}, ${seed}`,
    );
    if (mode === 'clear') {
      lines.push('\tterrain:Clear()', '\ttable.insert(applied, "terrain cleared")');
    } else if (mode === 'flat') {
      lines.push(
        '\tterrain:FillBlock(CFrame.new(CX, CY - 4, CZ), Vector3.new(SIZE, 8, SIZE), Enum.Material.Grass)',
        '\ttable.insert(applied, "flat grass terrain")',
      );
    } else if (mode === 'water') {
      lines.push(
        '\tterrain:FillBlock(CFrame.new(CX, CY - 10, CZ), Vector3.new(SIZE, 20, SIZE), Enum.Material.Water)',
        '\tterrain:FillBlock(CFrame.new(CX, CY - 24, CZ), Vector3.new(SIZE, 8, SIZE), Enum.Material.Sand)',
        '\ttable.insert(applied, "water terrain")',
      );
    } else {
      // Heightmap from layered noise. "island" fades to the sea toward the edges.
      const island = mode === 'island';
      lines.push(
        '\tlocal half = SIZE / 2',
        '\tfor x = -half, half - STEP, STEP do',
        '\t\tfor z = -half, half - STEP, STEP do',
        '\t\t\tlocal n = math.noise((x + SEED) / 90, (z - SEED) / 90) * 0.7 + math.noise((x - SEED) / 30, (z + SEED) / 30) * 0.3',
        '\t\t\tlocal h = (n + 0.5) * AMP',
        island
          ? '\t\t\tlocal falloff = 1 - math.clamp((math.sqrt(x * x + z * z) / half - 0.45) / 0.5, 0, 1)\n\t\t\th = h * falloff + (falloff - 1) * 16'
          : '\t\t\th = math.max(h, 1)',
        '\t\t\tlocal top = CY + h',
        '\t\t\tlocal bottom = CY - 20',
        '\t\t\tlocal material = if top < CY + 2 then Enum.Material.Sand elseif h > AMP * 0.85 then Enum.Material.Rock else Enum.Material.Grass',
        '\t\t\tif top > bottom then',
        '\t\t\t\tterrain:FillBlock(CFrame.new(CX + x + STEP / 2, (top + bottom) / 2, CZ + z + STEP / 2), Vector3.new(STEP, top - bottom, STEP), material)',
        '\t\t\tend',
        '\t\tend',
        '\t\ttask.wait()',
        '\tend',
      );
      if (island || o.water) {
        // Only empty (air) cells below sea level become water, so the land is kept.
        lines.push(
          '\tlocal sea = Region3.new(Vector3.new(CX - SIZE * 0.75, CY - 20, CZ - SIZE * 0.75), Vector3.new(CX + SIZE * 0.75, CY, CZ + SIZE * 0.75)):ExpandToGrid(4)',
          '\tterrain:FillBlock(CFrame.new(CX, CY - 22, CZ), Vector3.new(SIZE * 1.5, 4, SIZE * 1.5), Enum.Material.Sand)',
          '\tterrain:ReplaceMaterial(sea, 4, Enum.Material.Air, Enum.Material.Water)',
        );
      }
      lines.push(`\ttable.insert(applied, "${mode} terrain")`);
    }
  }
  lines.push(
    'end)',
    'if recording then ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel) end',
    'return HttpService:JSONEncode({ ok = ok, error = if ok then nil else tostring(err), applied = applied })',
  );
  return lines.join('\n');
}
