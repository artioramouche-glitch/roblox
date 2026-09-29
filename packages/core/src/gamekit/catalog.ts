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
    summary: 'Saving/loading player data with DataStores, leaderstats, remotes (Net), shared helpers (Util), UI kit (UIKit) with automatic translation (Lang: fr/es/pt/de), the no-code UI binder and Creator Dashboard analytics (economy, funnels, progression).',
    files: ['shared/Util.luau', 'shared/Net.luau', 'shared/Lang.luau', 'shared/UIKit.luau', 'core/Analytics.luau', 'core/PlayerData.luau', 'core/Core.server.luau', 'core/UIBinder.client.luau'],
    requires: [],
    configs: [
      {
        name: 'PlayerData',
        defaults: { DataStoreName: 'GameKit_PlayerData_v1', AutoSaveSeconds: 90, Stats: [], KickOnLoadFailure: true, AnalyticsCurrencies: ['Coins', 'Cash', 'Gems'] },
        docs: {
          DataStoreName: 'Change this name to start everyone from zero (old saves are ignored).',
          AutoSaveSeconds: 'How often everyone is saved (also saved on leave and shutdown).',
          Stats: 'Extra stats: { { Name = "Gems", Default = 0, Leaderstat = true } }. Systems add their own stats automatically.',
          KickOnLoadFailure: 'Kick players whose data failed to load (protects their save). Never kicks in Studio.',
          AnalyticsCurrencies: 'Stats reported as currencies to Creator Dashboard > Analytics > Economy (earned / spent, per item).',
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
      {
        name: 'Lang',
        defaults: { Enabled: true, Language: 'auto', Translations: {} },
        docs: {
          Language: '"auto" = the player\'s language; or force one: "fr", "es", "pt", "de"...',
          Translations: 'Your own texts: { fr = { ["Buy sword"] = "Acheter l\'épée", ["Level {1}"] = "Niveau {1}" } }. {1} = first number of the text.',
        },
        intro: 'GameKit translates its UI into French, Spanish, Portuguese and German automatically. Add translations for your own texts here.',
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
        Icons: { Coins: '💰', Cash: '💵', Gems: '💎', Wins: '🏆', Stage: '🚩', Kills: '⚔️', Level: '⭐', Power: '⚡', Rebirths: '🔁', Keys: '🔑', Wave: '🌊', Basket: '🧺', XP: '✨', Fish: '🐟' },
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
        Waves: { Enabled: false, FirstWaveSize: 3, GrowthPerWave: 2, BreakSeconds: 10, SurviveRewards: { Coins: 20 }, DayNight: false },
      },
      docs: {
        Types: 'Enemy types by name. Spawners pick one with their "Enemy" attribute.',
        WalkAnimation: 'Walk animation id (Roblox default R15 walk).',
        Waves: 'Enabled = true turns spawners into a wave survival game. DayNight = true: day during breaks, night during waves.',
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

SYSTEMS.push(
  {
    id: 'towerdefense',
    title: 'Tower defense',
    category: 'genre',
    summary: 'Co-op tower defense: enemies walk a path in waves (Basic, Fast, Tank, Boss), players build/upgrade/sell towers (Archer, Cannon splash, Frost slow) on pads with match cash, defend the base, win after the last wave.',
    files: ['systems/towerdefense/TowerDefense.server.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'TowerDefense',
      defaults: {
        CashStat: 'Cash', StartCash: 250, BaseHealth: 100, MinPlayers: 1, IntermissionSeconds: 12, TimeBetweenWaves: 6, MaxWaves: 15,
        HealthScalePerWave: 0.18, WaveCashReward: 60, WinRewards: { Wins: 1, Coins: 150 }, SellRefund: 0.6, UpgradeDamage: 1.5, UpgradeRange: 1.12,
        Waves: [
          { Enemy: 'Basic', Count: 6, Interval: 1.4 }, { Enemy: 'Basic', Count: 10, Interval: 1.1 }, { Enemy: 'Fast', Count: 8, Interval: 0.9 },
          { Enemy: 'Tank', Count: 3, Interval: 2.5 }, { Enemy: 'Basic', Count: 14, Interval: 0.8 }, { Enemy: 'Fast', Count: 14, Interval: 0.6 },
          { Enemy: 'Tank', Count: 6, Interval: 1.8 }, { Enemy: 'Boss', Count: 1, Interval: 1 },
        ],
        Enemies: {
          Basic: { Health: 12, Speed: 8, Reward: 6, Damage: 5, Color: '#8BC34A', Size: 2.6 },
          Fast: { Health: 8, Speed: 15, Reward: 6, Damage: 4, Color: '#FFEB3B', Size: 2 },
          Tank: { Health: 70, Speed: 5, Reward: 20, Damage: 15, Color: '#795548', Size: 4 },
          Boss: { Health: 450, Speed: 4, Reward: 150, Damage: 60, Color: '#9C27B0', Size: 6.5 },
        },
        Towers: {
          Archer: { Price: 100, Damage: 3, Range: 24, FireRate: 0.6, Color: '#4CAF50', UpgradePrice: 120, MaxLevel: 3, Icon: '🏹' },
          Cannon: { Price: 200, Damage: 8, Range: 20, FireRate: 1.6, Splash: 9, Color: '#607D8B', UpgradePrice: 220, MaxLevel: 3, Icon: '💣' },
          Frost: { Price: 150, Damage: 1, Range: 18, FireRate: 1, Slow: 0.5, SlowSeconds: 2, Color: '#4FC3F7', UpgradePrice: 160, MaxLevel: 3, Icon: '❄️' },
        },
      },
      docs: {
        CashStat: 'Match currency (reset every game, not saved).',
        Waves: 'One entry per wave: Enemy type, Count, Interval (seconds between spawns). After the list, the last wave repeats with more enemies.',
        HealthScalePerWave: 'Enemy health grows by this fraction every wave (0.18 = +18%).',
        Towers: 'Price, Damage, Range (studs), FireRate (seconds between shots), Splash (radius), Slow (speed factor) + SlowSeconds, UpgradePrice (x current level), MaxLevel.',
        WinRewards: REWARDS_DOC,
      },
    }],
    tags: { TDPath: 'Folder of waypoint parts (Order attribute or WP1, WP2...)', TDBase: 'the base at the end of the path', TowerPad: 'attribute Tower = Archer | Cannon | Frost' },
    usage: 'build_world "td_map" builds a full map (path, pads, base, spawn). Add pads with build_world piece "tower_pad" {tower: "Cannon"}; add tower types in Config.TowerDefense.Towers.',
  },
  {
    id: 'farming',
    title: 'Farming',
    category: 'genre',
    summary: 'Plant seeds on plots, wait for them to grow (3 visible stages), harvest, sell at the market, unlock better crops (Wheat -> Carrot -> Tomato -> Pumpkin -> Crystal). Relaxing idle-style progression, saved.',
    files: ['systems/farming/Farming.server.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Farming',
      defaults: {
        Currency: 'Coins', MaxPlotsPerPlayer: 8, Yield: 1, RipeGraceSeconds: 90,
        Crops: {
          Wheat: { Order: 1, SeedPrice: 0, GrowSeconds: 15, SellPrice: 3, UnlockPrice: 0, Color: '#F4D03F', Icon: '🌾' },
          Carrot: { Order: 2, SeedPrice: 5, GrowSeconds: 30, SellPrice: 15, UnlockPrice: 100, Color: '#E67E22', Icon: '🥕' },
          Tomato: { Order: 3, SeedPrice: 15, GrowSeconds: 45, SellPrice: 45, UnlockPrice: 500, Color: '#E74C3C', Icon: '🍅' },
          Pumpkin: { Order: 4, SeedPrice: 40, GrowSeconds: 75, SellPrice: 140, UnlockPrice: 2500, Color: '#D35400', Icon: '🎃' },
          Crystal: { Order: 5, SeedPrice: 150, GrowSeconds: 120, SellPrice: 600, UnlockPrice: 9000, Color: '#8E44AD', Icon: '💎' },
        },
      },
      docs: {
        Crops: 'Each crop: Order, SeedPrice, GrowSeconds, SellPrice, UnlockPrice (0 = free), Color, Icon. Better crops must earn more per minute (balance_economy checks it).',
        MaxPlotsPerPlayer: 'How many plots one player can farm at the same time.',
        RipeGraceSeconds: 'After this long ripe, anyone can harvest a plot (so plots never stay blocked).',
      },
    }],
    tags: { FarmPlot: 'soil part to plant on', SeedStand: 'attribute Crop: unlock/choose seeds', CropSell: 'market: sells the basket' },
    usage: 'build_world "farm" builds fields, seed stands and the market. The HUD shows "Basket" when Config.Hud ExtraStats includes it.',
  },
  {
    id: 'inventory',
    title: 'Inventory',
    category: 'economy',
    summary: 'Saved item counts (wood, fish, potions...) with a 🎒 window, selling (buttons or "ItemSell" parts) and a server API used by fishing, crafting and quests.',
    files: ['systems/inventory/Inventory.luau', 'systems/inventory/InventoryServer.server.luau', 'systems/inventory/Inventory.client.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Inventory',
      defaults: {
        Items: { Wood: { Name: 'Wood', Icon: '🪵', SellPrice: 1 }, Stone: { Name: 'Stone', Icon: '🪨', SellPrice: 2 } },
        MaxStack: 999, SellCurrency: 'Coins', ShowButton: true,
      },
      docs: {
        Items: 'Item definitions: Id = { Name, Icon, SellPrice, Rarity, Description }. Other systems add their own (fish, crafted items).',
        SellCurrency: 'Stat paid when selling.',
      },
    }],
    tags: { ItemSell: 'market part: sells every item that has a SellPrice' },
    usage: 'Server scripts: local Inventory = require(game.ServerScriptService.GameKit.Inventory); Inventory.give(player, "Wood", 3); Inventory.take(player, "Wood", 2); Inventory.count(player, "Wood"). Clients read player:GetAttribute("Inv_Wood").',
  },
  {
    id: 'levels',
    title: 'Levels & XP',
    category: 'gameplay',
    summary: 'XP and levels with a growing curve, an XP bar, level-up toast + sparkles and rewards. XP comes from any reward ({ XP = 25 }) or automatically from other stats.',
    files: ['systems/levels/Levels.server.luau', 'systems/levels/Levels.client.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Levels',
      defaults: { XPStat: 'XP', LevelStat: 'Level', BaseXP: 100, Growth: 1.25, MaxLevel: 100, XPFrom: { Coins: 0.2 }, LevelRewards: { Coins: 25 }, Effect: true },
      docs: {
        BaseXP: 'XP needed for level 2; each next level needs Growth times more.',
        XPFrom: 'Automatic XP from other stats: { Coins = 0.2 } gives 1 XP per 5 coins earned. {} to turn off.',
        LevelRewards: 'Given at each level-up, multiplied by the new level.',
      },
    }],
    usage: 'Give XP with any reward table ({ XP = 50 }) or PlayerData.reward(player, "XP", 50). Gate content with the Level stat (e.g. code_recipe door requireStat "Level").',
  },
  {
    id: 'quests',
    title: 'Quests',
    category: 'gameplay',
    summary: 'Missions with rewards and a tracker panel: earn a stat, reach a value, own items, or touch a secret place. Chain mode guides new players step by step.',
    files: ['systems/quests/Quests.server.luau', 'systems/quests/Quests.client.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Quests',
      defaults: {
        Mode: 'Chain',
        List: [
          { Id: 'FirstCoins', Title: 'Collect 25 coins', Type: 'Earn', Stat: 'Coins', Amount: 25, Rewards: { XP: 50 } },
          { Id: 'MoreCoins', Title: 'Collect 200 coins', Type: 'Earn', Stat: 'Coins', Amount: 200, Rewards: { XP: 150, Coins: 50 } },
        ],
        ShowTracker: true,
      },
      docs: {
        Mode: '"Chain" = one quest at a time in order, "All" = all at once.',
        List: 'Each quest: Id, Title, Type (Earn | Reach | Have | Touch), Stat or Item, Amount, Rewards. Touch quests: tag a part "QuestTarget" with attribute Quest = Id.',
      },
    }],
    tags: { QuestTarget: 'attribute Quest = quest Id (Touch quests)' },
    usage: 'Write quests that teach the game in order (Chain): first action, first purchase, first zone... Rewards can include XP (levels system).',
  },
  {
    id: 'pets',
    title: 'Eggs & pets',
    category: 'economy',
    summary: 'Hatch eggs for random pets (chances, rarities), equip the best ones to multiply rewards, pets follow you, 🐾 window, hatch animation. Saved.',
    files: ['systems/pets/Pets.server.luau', 'systems/pets/Pets.client.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Pets',
      defaults: {
        Stat: 'Coins', MaxEquipped: 3, MaxOwned: 60,
        Eggs: {
          Basic: {
            Price: 100, Currency: 'Coins', Color: '#F5F5F5',
            Pets: [
              { Id: 'Dog', Name: 'Dog', Chance: 55, Multiplier: 1.2, Rarity: 'Common', Color: '#C8A165' },
              { Id: 'Cat', Name: 'Cat', Chance: 35, Multiplier: 1.5, Rarity: 'Rare', Color: '#F5A623' },
              { Id: 'Dragon', Name: 'Dragon', Chance: 10, Multiplier: 3, Rarity: 'Legendary', Color: '#E53935' },
            ],
          },
        },
        RarityColors: { Common: '#B0BEC5', Rare: '#42A5F5', Epic: '#AB47BC', Legendary: '#FFCA28' },
      },
      docs: {
        Stat: 'Stat multiplied by equipped pets (a pet can override it with its own Stat).',
        Eggs: 'Egg name = { Price, Currency, Color, Pets = { { Id, Name, Chance, Multiplier, Rarity, Color } } }. Chances are relative weights.',
      },
    }],
    tags: { EggStand: 'attribute Egg = an egg name from Config.Pets.Eggs' },
    usage: 'build_world piece "egg_stand" {egg: "Basic"}. Put better eggs in later zones with higher prices.',
  },
  {
    id: 'racing',
    title: 'Racing',
    category: 'gameplay',
    summary: 'Race rounds on a track: grid, 3-2-1-GO, laps through checkpoints in order, positions, best lap saved, place rewards. Arcade karts (keyboard, gamepad, mobile) or running races.',
    files: ['systems/racing/Racing.server.luau', 'systems/racing/Racing.client.luau'],
    requires: ['core', 'hud'],
    configs: [{
      name: 'Racing',
      defaults: {
        Laps: 3, MinPlayers: 1, IntermissionSeconds: 15, TimeLimit: 240,
        UseKarts: true, KartSpeed: 70, KartTurnSpeed: 2.4, KartColor: '#E53935',
        PlaceRewards: [{ Wins: 1, Coins: 100 }, { Coins: 60 }, { Coins: 40 }],
        FinishRewards: { Coins: 15 },
      },
      docs: {
        UseKarts: 'true = everyone drives a kart (VehicleSeat: WASD, thumbstick). false = running race.',
        PlaceRewards: 'Rewards for 1st, 2nd, 3rd... finishers (list order).',
        FinishRewards: 'Given to everyone who finishes.',
        TimeLimit: 'Seconds before the race ends for those still racing.',
      },
    }],
    tags: {
      RaceCheckpoint: 'attribute Order (1, 2, 3...): pass them in order each lap',
      RaceFinish: 'start/finish line (a lap counts after all checkpoints)',
      RaceGrid: 'attribute Order: starting slots (the part faces the race direction)',
    },
    usage: 'build_world race_track {length, radius, width, grid} makes a complete oval. Player attributes RaceLap, RacePosition, BestLap for UIs.',
  },
  {
    id: 'fishing',
    title: 'Fishing',
    category: 'gameplay',
    summary: 'Cast at fishing spots, wait for the bite, press REEL in time. Fish by zone with rarities go to the inventory to sell. Rod level (shop upgrade) bites faster, finds rarer fish and unlocks zones.',
    files: ['systems/fishing/Fishing.server.luau', 'systems/fishing/Fishing.client.luau'],
    requires: ['core', 'hud', 'inventory'],
    configs: [{
      name: 'Fishing',
      defaults: {
        Zones: {
          Pond: {
            MinRod: 0,
            Fish: [
              { Id: 'Minnow', Name: 'Minnow', Icon: '🐟', Chance: 60, SellPrice: 3, Rarity: 'Common' },
              { Id: 'Salmon', Name: 'Salmon', Icon: '🐠', Chance: 30, SellPrice: 12, Rarity: 'Rare' },
              { Id: 'GoldenKoi', Name: 'Golden Koi', Icon: '✨', Chance: 10, SellPrice: 60, Rarity: 'Legendary' },
            ],
          },
          Ocean: {
            MinRod: 2,
            Fish: [
              { Id: 'Pufferfish', Name: 'Pufferfish', Icon: '🐡', Chance: 50, SellPrice: 15, Rarity: 'Common' },
              { Id: 'Tuna', Name: 'Tuna', Icon: '🐟', Chance: 38, SellPrice: 30, Rarity: 'Rare' },
              { Id: 'Shark', Name: 'Shark', Icon: '🦈', Chance: 12, SellPrice: 150, Rarity: 'Epic' },
            ],
          },
        },
        RodStat: 'RodLevel', BiteSeconds: [2, 6], ReelWindow: 1.6, FasterPerRod: 0.15, LuckPerRod: 0.1,
        CatchStat: 'Fish', CatchRewards: { XP: 5 },
      },
      docs: {
        Zones: 'Zone name = { MinRod, Fish = { { Id, Name, Icon, Chance, SellPrice, Rarity } } }. FishingSpot parts pick a zone with their Zone attribute.',
        RodStat: 'Rod level stat. Sell rods with a Shop item { Kind = "Upgrade", Stat = "RodLevel", Value = 1 }.',
        BiteSeconds: '{ min, max } seconds before a bite (divided by 1 + FasterPerRod x rod level).',
        ReelWindow: 'Seconds to press REEL after the bite.',
        LuckPerRod: 'Non-common fish weight bonus per rod level (0.1 = +10%).',
      },
    }],
    tags: { FishingSpot: 'attribute Zone = a zone of Config.Fishing.Zones (the bobber lands on this part)' },
    usage: 'build_world fishing_lake makes a pond + ocean with docks. Quests: { Type = "Earn", Stat = "Fish", Amount = 10 } or { Type = "Have", Item = "Salmon" }.',
  },
  {
    id: 'crafting',
    title: 'Gathering & crafting (survival)',
    category: 'gameplay',
    summary: 'Gather wood, stone and berries from resource nodes, craft items, tools (weapons, better axes), builds (campfire heals, walls, spikes vs enemies) and bandages in a 🔨 window. Optional hunger.',
    files: ['systems/crafting/Crafting.server.luau', 'systems/crafting/Crafting.client.luau'],
    requires: ['core', 'hud', 'inventory'],
    configs: [{
      name: 'Crafting',
      defaults: {
        Items: { Berry: { Name: 'Berry', Icon: '🫐', SellPrice: 1 }, Planks: { Name: 'Planks', Icon: '🟫', SellPrice: 3 } },
        Nodes: {
          Tree: { Item: 'Wood', Amount: 2, Hits: 3, Respawn: 20, Action: 'Chop' },
          Rock: { Item: 'Stone', Amount: 2, Hits: 4, Respawn: 25, Action: 'Mine' },
          Bush: { Item: 'Berry', Amount: 3, Hits: 1, Respawn: 15, Action: 'Pick' },
        },
        Recipes: [
          { Id: 'Planks', Needs: { Wood: 2 }, Gives: 3 },
          { Id: 'StoneAxe', Name: 'Stone Axe', Icon: '🪓', Kind: 'Tool', Needs: { Wood: 3, Stone: 2 }, Damage: 20, Gather: 2 },
          { Id: 'StoneSword', Name: 'Stone Sword', Icon: '🗡', Kind: 'Tool', Needs: { Planks: 2, Stone: 4 }, Damage: 35, Gather: 1 },
          { Id: 'Campfire', Name: 'Campfire', Icon: '🔥', Kind: 'Build', Needs: { Wood: 5, Stone: 3 } },
          { Id: 'Wall', Name: 'Wooden Wall', Icon: '🧱', Kind: 'Build', Needs: { Planks: 4 } },
          { Id: 'Spikes', Name: 'Spikes', Icon: '📌', Kind: 'Build', Needs: { Planks: 2, Stone: 2 } },
          { Id: 'Bandage', Name: 'Bandage', Icon: '🩹', Kind: 'Heal', Needs: { Berry: 4 }, Heal: 40 },
        ],
        RequireTable: false, MaxBuilds: 25, CraftRewards: { XP: 5 },
        Hunger: { Enabled: false, Max: 100, DrainPerMinute: 6, StarveDamage: 4, Food: { Berry: 12 } },
      },
      docs: {
        Items: 'Extra inventory items (Id = { Name, Icon, SellPrice }). Wood and Stone come from Config.Inventory.',
        Nodes: 'Resource types: Item given, Amount, Hits needed (tools with a Gather attribute hit harder), Respawn seconds, Action (prompt text).',
        Recipes: 'Kind: "Item" (default, Gives = amount), "Tool" (Damage, Gather: melee weapon/axe), "Build" (Campfire, Wall or Spikes placed in front of you), "Heal" (Heal = health).',
        RequireTable: 'true = craft only near a "CraftingTable" part.',
        Hunger: 'Enabled = true: hunger drains (DrainPerMinute), hurts at 0 (StarveDamage every 5 s); Food = { Item = food value } eaten from the 🔨 window.',
      },
    }],
    tags: {
      ResourceNode: 'part or model, attribute Node = a node type (Tree, Rock, Bush)',
      CraftingTable: 'opens the crafting window (required when RequireTable)',
      GKCampfire: 'model that heals players within 16 studs',
    },
    usage: 'build_world survival_camp makes a camp + forest of resources + enemy spawners. Combine with enemies (Waves.DayNight) and combat for co-op survival.',
  },
);

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
