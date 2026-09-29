/**
 * The GameKit catalog: plug-and-play systems (scripts + a config module each) and
 * complete game templates built from them. Everything here is data, so an AI can list
 * it, read it and install it without writing code.
 */

import { configModule } from './luau-table.js';
import { scriptPlacement, type Placement } from './installer.js';

export interface ConfigDef {
  /** ModuleScript name in ReplicatedStorage.GameKit.Config */
  name: string;
  defaults: Record<string, unknown>;
  docs: Record<string, string>;
  intro?: string;
}

export interface SystemDef {
  id: string;
  title: string;
  category: 'core' | 'gameplay' | 'economy' | 'ui' | 'world' | 'genre';
  summary: string;
  files: string[];
  requires: string[];
  configs: ConfigDef[];
  /** Tags/attributes the system reacts to (what build_world pieces to add). */
  tags?: Record<string, string>;
  usage: string;
}

const REWARDS_DOC = 'Stats given, e.g. { Wins = 1, Coins = 50 }. New stats appear on the leaderboard automatically.';

export const SYSTEMS: SystemDef[] = [
  {
    id: 'core',
    title: 'Core (always installed)',
    category: 'core',
    summary: 'Saving/loading player data with DataStores, leaderstats, remotes (Net), shared helpers (Util), UI kit (UIKit) and the no-code UI binder.',
    files: ['shared/Util.luau', 'shared/Net.luau', 'shared/UIKit.luau', 'core/PlayerData.luau', 'core/Core.server.luau', 'core/UIBinder.client.luau'],
    requires: [],
    configs: [
      {
        name: 'PlayerData',
        defaults: { DataStoreName: 'GameKit_PlayerData_v1', AutoSaveSeconds: 90, Stats: [], KickOnLoadFailure: true },
        docs: {
          DataStoreName: 'Change this name to start everyone from zero (old saves are ignored).',
          AutoSaveSeconds: 'How often everyone is saved (also saved on leave and shutdown).',
          Stats: 'Extra stats: { { Name = "Gems", Default = 0, Leaderstat = true } }. Systems add their own stats automatically.',
          KickOnLoadFailure: 'Kick players whose data failed to load (protects their save). Never kicks in Studio.',
        },
      },
      {
        name: 'Core',
        defaults: { WelcomeMessage: 'Welcome!', StartingStatus: '' },
        docs: { WelcomeMessage: 'Toast shown to each player after joining ("" to disable).', StartingStatus: 'Text in the top status bar at start ("" hides it).' },
      },
      {
        name: 'Theme',
        defaults: {
          Background: '#16161F', Panel: '#23232F', Accent: '#FFC940', Text: '#FFFFFF', SubText: '#B8B8C8',
          Success: '#4CD964', Error: '#FF5A5A', Reward: '#FFC940', Info: '#5AB4FF', Font: 'FredokaOne', Corner: 12,
        },
        docs: { Accent: 'Main button color of every GameKit window.', Font: 'Any Enum.Font name, e.g. "GothamBold", "Arcade", "Cartoon".' },
        intro: 'Colors used by every GameKit UI (HUD, shop, windows, toasts).',
      },
    ],
    usage: 'Server scripts: local PlayerData = require(game.ServerScriptService.GameKit.PlayerData) then PlayerData.defineStat({Name="Coins", Default=0, Leaderstat=true}), PlayerData.reward(player, "Coins", 10), PlayerData.spend(player, "Coins", 50). Client scripts read any stat with player:GetAttribute("Coins"). Remotes: Net.on("Name", fn) on the server, Net.send("Name", ...) on the client.',
  },
  {
    id: 'hud',
    title: 'HUD',
    category: 'ui',
    summary: 'Stats panel with +N pop-ups, status/timer bar, toast notifications, and the left column of HUD buttons used by other systems.',
    files: ['systems/hud/HUD.client.luau'],
    requires: ['core'],
    configs: [{
      name: 'Hud',
      defaults: {
        ShowLeaderstats: true, ExtraStats: [], HiddenStats: [], ShowStatus: true,
        Icons: { Coins: '💰', Cash: '💵', Gems: '💎', Wins: '🏆', Stage: '🚩', Kills: '⚔️', Level: '⭐', Power: '⚡', Rebirths: '🔁', Keys: '🔑', Wave: '🌊' },
      },
      docs: {
        ExtraStats: 'Stats not on the leaderboard to show anyway, e.g. { "Power" }.',
        HiddenStats: 'Leaderboard stats NOT to show in the HUD.',
        Icons: 'Emoji shown next to each stat.',
      },
    }],
    usage: 'Server: Net.notify(player, "text", "success") shows a toast. Set ReplicatedStorage.GameKit attributes "Status" (text) and "Timer" (seconds) to drive the top bar.',
  },
  {
    id: 'checkpoints',
    title: 'Obby checkpoints',
    category: 'gameplay',
    summary: 'Saved stage progress, respawn on the last checkpoint, finish line rewards.',
    files: ['systems/checkpoints/Checkpoints.server.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Checkpoints',
      defaults: { StageStat: 'Stage', RequireOrder: true, FinishRewards: { Wins: 1, Coins: 50 }, ResetOnFinish: true, AnnounceFinish: true },
      docs: {
        RequireOrder: 'Players must touch checkpoints in order (no skipping).',
        FinishRewards: REWARDS_DOC,
        ResetOnFinish: 'Send players back to stage 1 after finishing (to replay).',
      },
    }],
    tags: { Checkpoint: 'part with number attribute Stage (1, 2, 3...)', FinishLine: 'end of the obby' },
    usage: 'Add checkpoints with build_world piece "checkpoint" (options: stage) or a whole course with "obby_course".',
  },
  {
    id: 'hazards',
    title: 'Hazards',
    category: 'gameplay',
    summary: 'Kill bricks, damage parts and heal pads.',
    files: ['systems/hazards/Hazards.server.luau'],
    requires: ['core'],
    configs: [{
      name: 'Hazards',
      defaults: { KillPartNames: ['KillPart', 'KillBrick', 'Lava'], DefaultDamage: 20, DefaultHeal: 25, TouchCooldown: 0.5 },
      docs: { KillPartNames: 'Parts with these names kill on touch even without a tag.' },
    }],
    tags: { KillPart: 'kills on touch', DamagePart: 'attribute Damage', HealPart: 'attribute Heal' },
    usage: 'Tag a part "KillPart", or name it "Lava".',
  },
  {
    id: 'movers',
    title: 'Moving obstacles & pads',
    category: 'gameplay',
    summary: 'Moving platforms, spinners, disappearing and falling platforms, conveyors, teleporters, jump/speed/boost pads.',
    files: ['systems/movers/Movers.server.luau', 'systems/movers/Pads.client.luau'],
    requires: ['core'],
    configs: [],
    tags: {
      MovingPlatform: 'Offset (Vector3), Duration, Pause', Spinner: 'Speed (deg/s), Axis', Disappearing: 'OnTime, OffTime, Offset',
      FallingPlatform: 'Delay, RespawnTime', Conveyor: 'Speed (along LookVector)', Teleporter: 'Target (part name)',
      JumpPad: 'Power', SpeedPad: 'Speed, Duration', BoostPad: 'Power',
    },
    usage: 'Place pieces with build_world (moving_platform, spinner, jump_pad...). Attributes can be edited in Studio at any time.',
  },
  {
    id: 'collectibles',
    title: 'Collectibles',
    category: 'economy',
    summary: 'Spinning coins/orbs that give a stat and respawn.',
    files: ['systems/collectibles/Collectibles.server.luau', 'systems/collectibles/Collectibles.client.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Collectibles',
      defaults: { DefaultStat: 'Coins', DefaultAmount: 1, DefaultRespawnTime: 10 },
      docs: { DefaultStat: 'Stat given by coins that have no "Stat" attribute.' },
    }],
    tags: { Coin: 'attributes Stat, Amount, RespawnTime', Collectible: 'same as Coin' },
    usage: 'build_world piece "coin" (options: stat, amount).',
  },
  {
    id: 'rounds',
    title: 'Round system',
    category: 'gameplay',
    summary: 'Intermission -> round -> winners loop with timer, map rotation, rewards.',
    files: ['systems/rounds/Rounds.server.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Rounds',
      defaults: { Mode: 'LastStanding', MinPlayers: 1, IntermissionSeconds: 15, RoundSeconds: 90, ResultsSeconds: 5, WinnerRewards: { Wins: 1, Coins: 25 }, ParticipationRewards: { Coins: 5 } },
      docs: {
        Mode: '"LastStanding" (last alive wins) or "Survive" (everyone alive at the end wins).',
        MinPlayers: 'Players needed to start a round (1 = you can test alone).',
        WinnerRewards: REWARDS_DOC,
      },
    }],
    tags: { RoundSpawn: 'arena spawn points', LobbySpawn: 'where players return after a round' },
    usage: 'Maps: put Models in ServerStorage.GameKit.Maps (each with RoundSpawn parts) for rotation; otherwise the Workspace arena is used.',
  },
  {
    id: 'combat',
    title: 'Sword combat',
    category: 'gameplay',
    summary: 'Ready sword tool, server-side hit detection with anti-cheat range check, kill rewards.',
    files: ['systems/combat/Combat.server.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Combat',
      defaults: { GiveSword: 'Always', Damage: 25, Cooldown: 0.6, SwingWindow: 0.35, Range: 6, FriendlyFire: false, KillRewards: { Kills: 1, Coins: 10 }, BladeColor: '#D7DCE6', HiltColor: '#6B4226' },
      docs: {
        GiveSword: '"Always", "InRound" (only during rounds) or "Never" (e.g. sold in the shop).',
        KillRewards: REWARDS_DOC,
      },
    }],
    tags: { GKMelee: 'any Tool with this tag is a melee weapon (attributes Damage, Cooldown, Range)' },
    usage: 'The sword template lives in ServerStorage.GameKit.Tools.Sword; the shop can sell it with Kind="Tool", Value="Sword".',
  },
  {
    id: 'enemies',
    title: 'Enemies / NPCs',
    category: 'gameplay',
    summary: 'Chasing NPCs with pathfinding, attacks, rewards; optional wave survival mode.',
    files: ['systems/enemies/Enemies.server.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Enemies',
      defaults: {
        Types: {
          Zombie: { Health: 100, WalkSpeed: 11, Damage: 15, AttackCooldown: 1, AttackRange: 5, DetectRange: 90, Rewards: { Coins: 5 }, SkinColor: '#6E9E4C', ShirtColor: '#4B3B2A', Scale: 1 },
        },
        WalkAnimation: 'rbxassetid://507777826',
        MaxTotal: 30,
        Waves: { Enabled: false, FirstWaveSize: 3, GrowthPerWave: 2, BreakSeconds: 10, SurviveRewards: { Coins: 20 } },
      },
      docs: {
        Types: 'Enemy types by name. Spawners pick one with their "Enemy" attribute.',
        WalkAnimation: 'Walk animation id (Roblox default R15 walk).',
        Waves: 'Enabled = true turns spawners into a wave survival game.',
      },
    }],
    tags: { EnemySpawner: 'attributes Enemy, MaxAlive, RespawnSeconds' },
    usage: 'build_world piece "enemy_spawner" (options: enemy, maxAlive). Custom models: ServerStorage.GameKit.Enemies.<TypeName>.',
  },
  {
    id: 'shop',
    title: 'Shop',
    category: 'economy',
    summary: 'Server-validated shop window: speed/jump boosts, tools, trails, multipliers, pets, repeatable upgrades.',
    files: ['systems/shop/Shop.server.luau', 'systems/shop/Shop.client.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Shop',
      defaults: {
        Currency: 'Coins', MaxPets: 3, ShowButton: true, Title: 'Shop',
        Items: [
          { Id: 'SpeedBoost', Name: 'Speed Boost', Description: 'Run faster forever', Price: 100, Kind: 'WalkSpeed', Value: 22, Icon: '⚡' },
          { Id: 'JumpBoost', Name: 'Super Jump', Description: 'Jump higher', Price: 150, Kind: 'JumpPower', Value: 65, Icon: '🦘' },
          { Id: 'RedTrail', Name: 'Fire Trail', Description: 'A trail behind you', Price: 75, Kind: 'Trail', Value: '#FF5A3C', Icon: '🔥' },
          { Id: 'BlueTrail', Name: 'Ice Trail', Description: 'A cool blue trail', Price: 75, Kind: 'Trail', Value: '#5AC8FF', Icon: '❄️' },
          { Id: 'DoubleCoins', Name: '2x Coins', Description: 'Double every coin reward', Price: 1000, Kind: 'Multiplier', Stat: 'Coins', Value: 2, Icon: '💰' },
        ],
      },
      docs: {
        Currency: 'Default stat used to pay.',
        Items: 'Kind: WalkSpeed | JumpPower | Tool | Trail | Multiplier | Pet | Upgrade | Stat (see the Shop script header).',
      },
    }],
    tags: { ShopStand: 'part that opens the shop with a prompt' },
    usage: 'Edit Items in Config.Shop. Add a stand with build_world piece "shop_stand".',
  },
  {
    id: 'daily',
    title: 'Daily reward',
    category: 'economy',
    summary: 'Claim a reward every day with a growing streak (great for retention).',
    files: ['systems/daily/DailyReward.server.luau', 'systems/daily/DailyReward.client.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'DailyReward',
      defaults: { Stat: 'Coins', BaseAmount: 50, StreakBonus: 25, MaxStreak: 7, CooldownHours: 20, StreakResetHours: 48, OpenOnJoin: true },
      docs: { StreakBonus: 'Extra amount per consecutive day, up to MaxStreak days.' },
    }],
    usage: 'Works out of the box; a 🎁 button appears in the HUD.',
  },
  {
    id: 'leaderboard',
    title: 'Global leaderboard',
    category: 'ui',
    summary: 'In-world board with the all-time top 10 of any stat across all servers.',
    files: ['systems/leaderboard/Leaderboard.server.luau'],
    requires: ['core'],
    configs: [{
      name: 'Leaderboard',
      defaults: { RefreshSeconds: 60, Entries: 10, StorePrefix: 'GameKit_Top_' },
      docs: { StorePrefix: 'OrderedDataStore name prefix (change to reset the board).' },
    }],
    tags: { LeaderboardBoard: 'attributes Stat, Title' },
    usage: 'build_world piece "leaderboard" (options: stat, title, yaw).',
  },
  {
    id: 'movement',
    title: 'Sprint & double jump',
    category: 'gameplay',
    summary: 'Shift to sprint (button on mobile) and a double jump.',
    files: ['systems/movement/Movement.client.luau'],
    requires: ['core'],
    configs: [{
      name: 'Movement',
      defaults: { Sprint: true, SprintMultiplier: 1.6, DoubleJump: true, DoubleJumpPower: 55 },
      docs: {},
    }],
    usage: 'Works out of the box.',
  },
  {
    id: 'atmosphere',
    title: 'Atmosphere',
    category: 'world',
    summary: 'Day/night cycle, background music playlist, flickering lights.',
    files: ['systems/atmosphere/Atmosphere.server.luau', 'systems/atmosphere/Atmosphere.client.luau'],
    requires: ['core'],
    configs: [{
      name: 'Atmosphere',
      defaults: { DayNightCycle: true, DayLengthMinutes: 12, StartTime: 14, Music: [], MusicVolume: 0.3 },
      docs: {
        Music: 'Sound ids played in order, e.g. { "rbxassetid://1234567" } (must be public or yours).',
        DayNightCycle: 'false keeps the time fixed (StartTime).',
      },
    }],
    tags: { FlickerLight: 'part with a light inside that flickers' },
    usage: 'Use set_environment for the lighting style; this system only animates time and plays music.',
  },
  {
    id: 'admin',
    title: 'Admin commands',
    category: 'gameplay',
    summary: 'Chat commands for the owner: /give, /set, /reset, /kick, /tp, /bring, /speed, /heal.',
    files: ['systems/admin/Admin.server.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Admin',
      defaults: { Admins: [], GroupRank: 254 },
      docs: { Admins: 'Extra admin UserIds, e.g. { 12345678 }. The game owner is always admin.' },
    }],
    usage: 'In Studio every tester is admin: type /give me Coins 1000 in chat to test the economy.',
  },
  {
    id: 'monetization',
    title: 'Monetization',
    category: 'economy',
    summary: 'Developer products and game passes with safe receipt handling (no double grants).',
    files: ['systems/monetization/Monetization.server.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Monetization',
      defaults: { Products: {}, GamePasses: {} },
      docs: {
        Products: '{ [ProductId] = { Kind = "Stat", Stat = "Coins", Amount = 500 } } or { Kind = "SkipStage" }',
        GamePasses: '{ [PassId] = { Kind = "Multiplier", Stat = "Coins", Value = 2 } } or Kind = "WalkSpeed" | "JumpPower" | "Tool"',
      },
      intro: 'Create products/passes on create.roblox.com (Monetization tab), then paste their IDs here.',
    }],
    tags: { PurchasePrompt: 'part with attribute ProductId or GamePassId sells it in-world' },
    usage: 'Only works in a published game with real product IDs.',
  },
  {
    id: 'tycoon',
    title: 'Tycoon',
    category: 'genre',
    summary: 'Claimable plots, droppers -> conveyor -> collector, purchase buttons in order, saved progress.',
    files: ['systems/tycoon/Tycoon.server.luau'],
    requires: ['core', 'hud', 'movers'],
    configs: [{
      name: 'Tycoon',
      defaults: { Currency: 'Cash', StartingCash: 0, MaxOrePerPlot: 60, OreLifetime: 30, PassiveIncome: 0 },
      docs: { PassiveIncome: 'Cash per second given to every plot owner (0 = off).' },
    }],
    tags: { TycoonPlot: 'Model with Claim, Buttons (Item/Price/Requires attrs) and Items folders', Dropper: 'DropValue, DropInterval', Collector: 'turns ore into cash', Upgrader: 'Multiplier' },
    usage: 'build_world "tycoon_plots" creates complete plots. Add items: put a Model in a plot\'s Items folder and a button part in Buttons with attributes Item, Price, Requires.',
  },
  {
    id: 'simulator',
    title: 'Simulator',
    category: 'genre',
    summary: 'Train -> backpack -> sell -> upgrades -> zones -> rebirth loop.',
    files: ['systems/simulator/Simulator.server.luau', 'systems/simulator/Simulator.client.luau'],
    requires: ['core', 'hud', 'collectibles'],
    configs: [{
      name: 'Simulator',
      defaults: { PowerStat: 'Power', CoinStat: 'Coins', StartCapacity: 50, StartClickPower: 1, SellRate: 1, RebirthBaseCost: 1000, RebirthBonus: 0.5, TrainsPerSecond: 8, TrainButtonText: '💪 Train' },
      docs: { RebirthBonus: 'Power multiplier added per rebirth (0.5 = +50%).', SellRate: 'Coins per point of Power sold.' },
    }],
    tags: { SellPad: 'sells all Power', ZoneGate: 'attributes Zone, Price' },
    usage: 'build_world "simulator_world". Upgrades: Shop items with Kind="Upgrade", Stat="Capacity" or "ClickPower".',
  },
  {
    id: 'objectives',
    title: 'Keys & escape',
    category: 'genre',
    summary: 'Find keys, open the exit door, escape; the run resets automatically.',
    files: ['systems/objectives/Objectives.server.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Objectives',
      defaults: { EscapeRewards: { Wins: 1, Coins: 30 }, RunSeconds: 300, ResetDelay: 8, ItemName: 'key' },
      docs: { RunSeconds: 'Time limit of a run.', EscapeRewards: REWARDS_DOC },
    }],
    tags: { Key: 'collect all', ExitDoor: 'attribute KeysRequired', ExitZone: 'escape point' },
    usage: 'build_world "maze" builds a full escape maze with keys, exit and a monster spawner.',
  },
];

export function getSystem(id: string): SystemDef {
  const system = SYSTEMS.find((s) => s.id === id);
  if (!system) throw new Error(`Unknown system "${id}". Available: ${SYSTEMS.map((s) => s.id).join(', ')}`);
  return system;
}

/** The system plus everything it requires, dependencies first. */
export function resolveSystems(ids: string[]): SystemDef[] {
  const out: SystemDef[] = [];
  const seen = new Set<string>();
  const visit = (id: string) => {
    if (seen.has(id)) return;
    seen.add(id);
    const system = getSystem(id);
    system.requires.forEach(visit);
    out.push(system);
  };
  ['core', ...ids].forEach(visit);
  return out;
}

function deepMerge(base: unknown, override: unknown): unknown {
  if (override === undefined) return base;
  if (Array.isArray(override) || typeof override !== 'object' || override === null) return override;
  if (typeof base !== 'object' || base === null || Array.isArray(base)) return override;
  const out: Record<string, unknown> = { ...(base as Record<string, unknown>) };
  for (const [k, v] of Object.entries(override as Record<string, unknown>)) out[k] = deepMerge(out[k], v);
  return out;
}

export interface SystemInstallOptions {
  /** Per-config overrides: { Shop: { Currency: "Gems" } } */
  config?: Record<string, Record<string, unknown>>;
  /** Replace existing config modules even when no override is given. */
  resetConfig?: boolean;
}

/** Placements that install the given systems (scripts replaced, configs kept unless overridden). */
export function systemPlacements(ids: string[], options: SystemInstallOptions = {}): { placements: Placement[]; systems: string[] } {
  const systems = resolveSystems(ids);
  const placements: Placement[] = [];
  const seenFiles = new Set<string>();
  for (const system of systems) {
    for (const file of system.files) {
      if (seenFiles.has(file)) continue;
      seenFiles.add(file);
      placements.push(scriptPlacement(file, 'replace'));
    }
    for (const cfg of system.configs) {
      const override = options.config?.[cfg.name];
      const values = deepMerge(cfg.defaults, override) as Record<string, unknown>;
      placements.push({
        parent: ['ReplicatedStorage', 'GameKit', 'Config'],
        mode: override || options.resetConfig ? 'replace' : 'keep',
        node: { name: cfg.name, className: 'ModuleScript', source: configModule(`${system.title} (${cfg.name})`, values, cfg.docs, cfg.intro) },
      });
    }
  }
  return { placements, systems: systems.map((s) => s.id) };
}

export function configNamesFor(ids: string[]): string[] {
  return resolveSystems(ids).flatMap((s) => s.configs.map((c) => c.name));
}
