/**
 * balance_economy: simulates a player's progression (earn -> buy -> earn faster) and tells
 * whether prices feel right: first purchase in seconds, then steadily longer waits, no
 * wall where the player waits 20 minutes for the next thing. Suggests smooth prices.
 *
 * Works from explicit numbers, or reads the installed game (tycoon plots, Shop config)
 * with fromGame: true. Pure math, runs in the server; Studio only to read the game.
 */

import type { GameKitHost, ToolDef } from './tools.js';
import { runLuauJson } from './installer.js';
import { text, type ToolResult } from './result.js';

export interface EconomyItem {
  name: string;
  price: number;
  /** Income per second added once bought (droppers, auto-farmers). */
  addIncome?: number;
  /** Income multiplier once bought (2 = double). */
  multiplier?: number;
  /** Must be bought after this item (tycoon buttons). */
  requires?: string;
}

export interface EconomyInput {
  /** Passive income per second at the start. */
  incomePerSecond?: number;
  /** Active income: value of one click/action and actions per second. */
  perClick?: number;
  clicksPerSecond?: number;
  items: EconomyItem[];
  /** Minutes a player should need to buy everything (default 60). */
  targetMinutes?: number;
  /** Seconds before the first purchase (default 30). */
  firstPurchaseSeconds?: number;
  order?: 'listed' | 'cheapest';
}

export interface TimelineRow {
  item: string;
  price: number;
  atMinute: number;
  waitSeconds: number;
  incomePerSecondAfter: number;
}

export interface EconomyReport {
  timeline: TimelineRow[];
  totalMinutes: number;
  stuck?: string;
  warnings: string[];
  verdict: 'good' | 'too fast' | 'too slow' | 'uneven' | 'broken';
  suggested: Array<{ item: string; price: number; waitSeconds: number }>;
}

/** Rounds to a price players find natural: 1, 2, 2.5, 5 x 10^n (and 15, 75... avoided). */
export function nicePrice(value: number): number {
  if (value <= 0) return 0;
  if (value < 10) return Math.max(1, Math.round(value));
  const exp = Math.floor(Math.log10(value));
  const base = 10 ** exp;
  const steps = [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 7.5, 8, 10];
  let best = steps[0] * base;
  for (const s of steps) {
    if (Math.abs(s * base - value) < Math.abs(best - value)) best = s * base;
  }
  return Math.round(best);
}

function ordered(input: EconomyInput): EconomyItem[] {
  const items = input.items.filter((i) => Number.isFinite(i.price) && i.price >= 0);
  if (input.order !== 'cheapest') return items;
  return [...items].sort((a, b) => a.price - b.price);
}

/** Buys items in order (respecting requires), spending everything as soon as possible. */
export function simulate(input: EconomyInput): { timeline: TimelineRow[]; stuck?: string } {
  const clicks = (input.perClick ?? 0) * (input.clicksPerSecond ?? 4);
  let base = (input.incomePerSecond ?? 0) + clicks;
  let multiplier = 1;
  let money = 0;
  let t = 0;
  const owned = new Set<string>();
  const timeline: TimelineRow[] = [];
  const queue = ordered(input);
  const maxSeconds = 60 * 60 * 24 * 30;
  while (queue.length) {
    const index = queue.findIndex((i) => !i.requires || owned.has(i.requires));
    if (index < 0) return { timeline, stuck: `Nothing can be bought: "${queue[0].name}" requires "${queue[0].requires}" which does not exist.` };
    const item = queue.splice(index, 1)[0];
    const rate = base * multiplier;
    const need = Math.max(0, item.price - money);
    if (need > 0 && rate <= 0) return { timeline, stuck: `No income at all before "${item.name}" (${item.price}): the player can never buy it.` };
    const wait = need > 0 ? need / rate : 0;
    if (t + wait > maxSeconds) return { timeline, stuck: `"${item.name}" would take more than 30 days to afford.` };
    t += wait;
    money += wait * rate - item.price;
    base += item.addIncome ?? 0;
    multiplier *= item.multiplier ?? 1;
    owned.add(item.name);
    timeline.push({ item: item.name, price: item.price, atMinute: Math.round((t / 60) * 10) / 10, waitSeconds: Math.round(wait), incomePerSecondAfter: Math.round(base * multiplier * 100) / 100 });
  }
  return { timeline };
}

/** Prices giving waits that grow geometrically from `first` seconds, summing to the target. */
export function suggestPrices(input: EconomyInput): Array<{ item: string; price: number; waitSeconds: number }> {
  const items = ordered(input);
  const n = items.length;
  if (!n) return [];
  const total = Math.max(60, (input.targetMinutes ?? 60) * 60);
  const first = Math.max(3, Math.min(total / n, input.firstPurchaseSeconds ?? 30));
  // Solve first * (r^n - 1) / (r - 1) = total for the growth ratio r.
  let lo = 1.0001;
  let hi = 10;
  for (let k = 0; k < 80; k++) {
    const r = (lo + hi) / 2;
    const sum = (first * (r ** n - 1)) / (r - 1);
    if (sum > total) hi = r;
    else lo = r;
  }
  const ratio = n === 1 ? 1 : (lo + hi) / 2;
  const clicks = (input.perClick ?? 0) * (input.clicksPerSecond ?? 4);
  let base = (input.incomePerSecond ?? 0) + clicks;
  let multiplier = 1;
  const out: Array<{ item: string; price: number; waitSeconds: number }> = [];
  items.forEach((item, i) => {
    const wait = n === 1 ? total : first * ratio ** i;
    const rate = Math.max(base * multiplier, 0.01);
    const price = item.price === 0 && i === 0 ? 0 : nicePrice(rate * wait);
    out.push({ item: item.name, price, waitSeconds: Math.round(wait) });
    base += item.addIncome ?? 0;
    multiplier *= item.multiplier ?? 1;
  });
  return out;
}

export function analyse(input: EconomyInput): EconomyReport {
  const { timeline, stuck } = simulate(input);
  const warnings: string[] = [];
  const target = (input.targetMinutes ?? 60) * 60;
  const totalSeconds = timeline.reduce((s, r) => s + r.waitSeconds, 0);
  const firstPaid = timeline.find((r) => r.price > 0);
  if (firstPaid && firstPaid.waitSeconds > 120) warnings.push(`First purchase "${firstPaid.item}" takes ${Math.round(firstPaid.waitSeconds / 60)} min: new players quit before buying anything (aim for < 60 s).`);
  for (let i = 1; i < timeline.length; i++) {
    const prev = timeline[i - 1];
    const row = timeline[i];
    if (row.waitSeconds > 20 * 60) warnings.push(`Wall: "${row.item}" needs ${Math.round(row.waitSeconds / 60)} min of waiting. Add a cheaper step before it or lower its price.`);
    if (prev.waitSeconds > 30 && row.waitSeconds > prev.waitSeconds * 4) warnings.push(`Jump: "${row.item}" takes ${Math.round(row.waitSeconds / Math.max(1, prev.waitSeconds))}x longer than "${prev.item}".`);
  }
  const instant = timeline.filter((r) => r.waitSeconds < 3 && r.price > 0).length;
  if (instant > 2) warnings.push(`${instant} items are affordable instantly: they give no sense of progress (raise their price).`);
  let verdict: EconomyReport['verdict'] = 'good';
  if (stuck) verdict = 'broken';
  else if (totalSeconds < target * 0.4) verdict = 'too fast';
  else if (totalSeconds > target * 2.5) verdict = 'too slow';
  else if (warnings.length) verdict = 'uneven';
  if (verdict === 'too fast') warnings.push(`Everything is bought in ${Math.round(totalSeconds / 60)} min (target ${Math.round(target / 60)} min): players run out of goals.`);
  if (verdict === 'too slow') warnings.push(`Buying everything takes ${Math.round(totalSeconds / 60)} min (target ${Math.round(target / 60)} min).`);
  return {
    timeline,
    totalMinutes: Math.round((totalSeconds / 60) * 10) / 10,
    stuck,
    warnings,
    verdict,
    suggested: suggestPrices(input),
  };
}

// --- Reading the installed game -------------------------------------------------------------

const READ_GAME_LUAU = `
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local out = { tycoon = nil, shop = nil, simulator = nil, farming = nil, towerDefense = nil }
local function readConfig(name)
	local kit = ReplicatedStorage:FindFirstChild("GameKit")
	local module = kit and kit:FindFirstChild("Config") and kit.Config:FindFirstChild(name)
	if not module then return nil end
	-- Require a copy: require() caches, and the config may have been edited since.
	local copy = module:Clone()
	copy.Parent = module.Parent
	local ok, value = pcall(require, copy)
	copy:Destroy()
	return if ok then value else nil
end
local world = workspace:FindFirstChild("GameKit")
local tycoon = world and world:FindFirstChild("Tycoon")
local plot = tycoon and tycoon:FindFirstChild("Plot1")
if plot and plot:FindFirstChild("Buttons") then
	local items = {}
	for _, button in plot.Buttons:GetChildren() do
		local name = button:GetAttribute("Item")
		if name then
			local item = { name = name, price = button:GetAttribute("Price") or 0, requires = button:GetAttribute("Requires") }
			local model = plot:FindFirstChild("Items") and plot.Items:FindFirstChild(name)
			if model then
				for _, d in model:GetDescendants() do
					if d:GetAttribute("DropValue") then
						item.addIncome = (item.addIncome or 0) + d:GetAttribute("DropValue") / math.max(0.1, d:GetAttribute("DropInterval") or 2)
					end
					if d:GetAttribute("Multiplier") then item.multiplier = d:GetAttribute("Multiplier") end
				end
				if model:GetAttribute("DropValue") then
					item.addIncome = (item.addIncome or 0) + model:GetAttribute("DropValue") / math.max(0.1, model:GetAttribute("DropInterval") or 2)
				end
				if model:GetAttribute("Multiplier") then item.multiplier = model:GetAttribute("Multiplier") end
			end
			table.insert(items, item)
		end
	end
	local cfg = readConfig("Tycoon") or {}
	out.tycoon = { items = items, passive = cfg.PassiveIncome or 0, currency = cfg.Currency or "Cash" }
end
out.shop = readConfig("Shop")
out.simulator = readConfig("Simulator")
out.farming = readConfig("Farming")
out.towerDefense = readConfig("TowerDefense")
return HttpService:JSONEncode(out)
`;

function shopItems(shop: any): EconomyItem[] {
  const items = Array.isArray(shop?.Items) ? shop.Items : [];
  return items.map((i: any) => ({
    name: String(i.Name ?? i.Id),
    price: Number(i.Price ?? 0),
    multiplier: i.Kind === 'Multiplier' ? Number(i.Value ?? 1) : undefined,
  }));
}

export const ECONOMY_TOOLS: ToolDef[] = [
  {
    name: 'balance_economy',
    category: 'read',
    tier: 'builder',
    description: 'Simulate player progression and check prices (first purchase, walls, total time) with suggested prices. fromGame reads the installed economy; or pass items and income.',
    inputSchema: {
      type: 'object',
      properties: {
        fromGame: { type: 'boolean' },
        incomePerSecond: { type: 'number' },
        perClick: { type: 'number' },
        clicksPerSecond: { type: 'number' },
        items: { type: 'array', items: { type: 'object' }, description: '[{name, price, addIncome, multiplier, requires}]' },
        targetMinutes: { type: 'number', description: 'Time to buy everything (default 60)' },
        firstPurchaseSeconds: { type: 'number' },
        order: { type: 'string', enum: ['listed', 'cheapest'] },
      },
    },
  },
];

export async function handleEconomy(host: GameKitHost | null, args: Record<string, any>): Promise<ToolResult> {
  const reports: Record<string, unknown> = {};
  const common = {
    targetMinutes: args.targetMinutes !== undefined ? Number(args.targetMinutes) : undefined,
    firstPurchaseSeconds: args.firstPurchaseSeconds !== undefined ? Number(args.firstPurchaseSeconds) : undefined,
    clicksPerSecond: args.clicksPerSecond !== undefined ? Number(args.clicksPerSecond) : undefined,
    order: args.order,
  };
  if (Array.isArray(args.items) && args.items.length) {
    reports.custom = analyse({
      ...common,
      incomePerSecond: Number(args.incomePerSecond ?? 0),
      perClick: Number(args.perClick ?? 0),
      items: args.items.map((i: any) => ({ name: String(i.name), price: Number(i.price), addIncome: i.addIncome !== undefined ? Number(i.addIncome) : undefined, multiplier: i.multiplier !== undefined ? Number(i.multiplier) : undefined, requires: i.requires ? String(i.requires) : undefined })),
    });
  }
  if (args.fromGame) {
    if (!host) throw new Error('fromGame needs Studio');
    const game = await runLuauJson<any>(host, READ_GAME_LUAU, 'Read economy');
    if (game?.tycoon?.items?.length) {
      reports.tycoon = {
        currency: game.tycoon.currency,
        ...analyse({ ...common, incomePerSecond: Number(game.tycoon.passive ?? 0), items: game.tycoon.items, order: 'listed' }),
        howToApply: 'Change the Price attribute of each Buy_<Item> button in Workspace/GameKit/Tycoon/Plot*/Buttons (all plots), e.g. with mass_set_property or execute_luau.',
      };
    }
    if (game?.simulator) {
      const sim = game.simulator;
      const perClick = Number(sim.StartClickPower ?? 1) * Number(sim.SellRate ?? 1);
      const items = shopItems(game.shop);
      if (items.length) {
        reports.simulator = {
          ...analyse({ ...common, perClick, clicksPerSecond: Math.min(Number(sim.TrainsPerSecond ?? 8), Number(args.clicksPerSecond ?? 5)), items, order: 'cheapest' }),
          note: 'Approximation: selling trips and backpack capacity slow players down ~30%. Upgrades that raise ClickPower are not modelled.',
          howToApply: 'add_system {"system": "shop", "config": {"Items": [...same items with new Price...]}}',
        };
      }
    } else if (game?.shop && !game?.tycoon) {
      const items = shopItems(game.shop);
      if (items.length && (args.incomePerSecond !== undefined || args.perClick !== undefined)) {
        reports.shop = analyse({ ...common, incomePerSecond: Number(args.incomePerSecond ?? 0), perClick: Number(args.perClick ?? 0), items, order: 'cheapest' });
      } else if (items.length) {
        reports.shop = { needsIncome: 'The shop sells items but the income depends on your game: pass incomePerSecond (e.g. coins per second from coins/rewards) and call again.', items };
      }
    }
    if (game?.farming?.Crops) {
      reports.farming = farmingReport(game.farming);
    }
    if (game?.towerDefense?.Towers) {
      reports.towerDefense = towerDefenseReport(game.towerDefense);
    }
    if (!Object.keys(reports).length) reports.note = 'No economy found in the game (tycoon plots, Shop, Simulator, Farming or TowerDefense config). Pass items and income yourself.';
  }
  if (!Object.keys(reports).length) throw new Error('Pass items (+ incomePerSecond / perClick) or fromGame: true');
  return text({
    ...reports,
    guide: 'Good curve: first purchase < 60 s, each next item a bit longer (x1.2-x1.8), no wait over ~15 min, everything in 30-120 min, rebirth/prestige after that.',
  });
}

/** Profit per minute of each crop for one plot, and whether better crops really pay more. */
export function farmingReport(cfg: any) {
  const crops = Object.entries(cfg.Crops ?? {}).map(([name, c]: [string, any]) => {
    const grow = Math.max(1, Number(c.GrowSeconds ?? 30));
    const profit = Number(c.SellPrice ?? 0) - Number(c.SeedPrice ?? 0);
    return { crop: name, seedPrice: Number(c.SeedPrice ?? 0), sellPrice: Number(c.SellPrice ?? 0), growSeconds: grow, unlockPrice: Number(c.UnlockPrice ?? 0), profitPerMinutePerPlot: Math.round((profit / grow) * 60 * 10) / 10 };
  });
  const warnings: string[] = [];
  crops.forEach((c, i) => {
    if (c.profitPerMinutePerPlot <= 0) warnings.push(`${c.crop} loses money (sell ${c.sellPrice} <= seed ${c.seedPrice}).`);
    const prev = crops[i - 1];
    if (prev && c.profitPerMinutePerPlot <= prev.profitPerMinutePerPlot) warnings.push(`${c.crop} earns less per minute than ${prev.crop}: nobody will unlock it.`);
    if (prev && c.unlockPrice > 0 && prev.profitPerMinutePerPlot > 0) {
      const minutes = c.unlockPrice / (prev.profitPerMinutePerPlot * Math.max(1, Number(cfg.MaxPlotsPerPlayer ?? 4)));
      if (minutes > 20) warnings.push(`Unlocking ${c.crop} takes ~${Math.round(minutes)} min of ${prev.crop} farming (aim for 3-15 min).`);
    }
  });
  return { crops, warnings, verdict: warnings.length ? 'uneven' : 'good' };
}

/** Damage per coin of each tower, and whether early waves can be beaten with the start cash. */
export function towerDefenseReport(cfg: any) {
  const towers = Object.entries(cfg.Towers ?? {}).map(([name, t]: [string, any]) => {
    const dps = (Number(t.Damage ?? 1) / Math.max(0.05, Number(t.FireRate ?? 1))) * (t.Splash ? 2 : 1);
    return { tower: name, price: Number(t.Price ?? 0), dps: Math.round(dps * 10) / 10, dpsPerCoin: Math.round((dps / Math.max(1, Number(t.Price ?? 1))) * 1000) / 1000, support: t.Slow !== undefined };
  });
  const warnings: string[] = [];
  const cheapest = towers.reduce((m, t) => Math.min(m, t.price), Infinity);
  if (Number(cfg.StartCash ?? 0) < cheapest) warnings.push(`StartCash (${cfg.StartCash ?? 0}) cannot buy the cheapest tower (${cheapest}).`);
  const best = Math.max(...towers.map((t) => t.dpsPerCoin));
  towers.forEach((t) => {
    // Slowing towers are support: their value is making the others hit more often.
    if (!t.support && t.dpsPerCoin < best * 0.3) warnings.push(`${t.tower} gives much less damage per coin than the best tower: make it cheaper or special (splash/slow).`);
  });
  return { towers, warnings, verdict: warnings.length ? 'uneven' : 'good' };
}
