/**
 * Complete game templates: systems + configs + generated world + lighting, installed in
 * one call. Each template is a playable game the AI then customises.
 */

import type { EnvironmentOptions } from './environment.js';
import type { Placement } from './installer.js';
import { arena, decorScatter, farm, fishingLake, lobby, maze, obbyCourse, piece, raceTrack, simulatorWorld, survivalCamp, tdMap, tycoonPlots, worldPlacement, type ObstacleType } from './world.js';

export interface TemplateOptions {
  title?: string;
  theme?: string;
  difficulty?: 'easy' | 'medium' | 'hard';
  stages?: number;
  plots?: number;
  zones?: number;
  mazeSize?: number;
  keys?: number;
  waves?: number;
  laps?: number;
  karts?: boolean;
  seed?: number;
  lighting?: string;
  obstacles?: ObstacleType[];
}

export interface TemplatePlan {
  systems: string[];
  config: Record<string, Record<string, unknown>>;
  world: Placement[];
  environment: EnvironmentOptions;
  nextSteps: string[];
}

export interface TemplateDef {
  id: string;
  title: string;
  genre: string;
  summary: string;
  options: Record<string, string>;
  plan: (o: TemplateOptions) => TemplatePlan;
}

const THEME_LIGHTING: Record<string, string> = { neon: 'neon', space: 'space', lava: 'sunset', candy: 'fantasy', ice: 'winter', nature: 'day', rainbow: 'day' };

const COMMON_NEXT = [
  'Run test_game to play-test automatically and fix any error it reports.',
  'Open ReplicatedStorage > GameKit > Config to tune numbers (rewards, prices, speeds) -- no code needed.',
  'Use build_ui for extra screens and set_environment to change the mood.',
];

export const TEMPLATES: TemplateDef[] = [
  {
    id: 'obby',
    title: 'Obby (parkour)',
    genre: 'Obby',
    summary: 'A floating parkour course over a lava sea: saved checkpoints, 12 obstacle types with rising difficulty, coins, finish rewards, shop with trails, global Wins board, daily reward.',
    options: { title: 'sign text', stages: '2-60 (default 12)', difficulty: 'easy | medium | hard', theme: 'rainbow | candy | neon | nature | space | lava | ice', obstacles: 'optional list of obstacle types to cycle' },
    plan: (o) => {
      const base: [number, number, number] = [0, 50, 0];
      const theme = o.theme ?? 'rainbow';
      return {
        systems: ['hud', 'checkpoints', 'hazards', 'movers', 'collectibles', 'shop', 'daily', 'leaderboard', 'movement', 'atmosphere', 'admin'],
        config: {
          Core: { WelcomeMessage: 'Reach the end of the obby! 🏁' },
          Movement: { DoubleJump: false },
          Atmosphere: { DayNightCycle: false },
        },
        world: [
          worldPlacement(obbyCourse({ stages: o.stages ?? 12, difficulty: o.difficulty ?? 'medium', theme, title: o.title ?? 'OBBY', seed: o.seed, position: base, obstacles: o.obstacles })),
          worldPlacement(piece('leaderboard', [base[0] - 22, base[1] - 0.5, base[2] - 10], { name: 'WinsBoard', stat: 'Wins', title: 'Most Wins', yaw: -90 })),
          worldPlacement(piece('shop_stand', [base[0] + 9, base[1], base[2] - 20], { name: 'ShopStand' })),
        ],
        environment: { preset: o.lighting ?? THEME_LIGHTING[theme] ?? 'day', removeBaseplate: true },
        nextSteps: [
          'Add or reorder stages: build_world obby_course again with stages/difficulty/obstacles options (it replaces the course).',
          'Sell "Skip Stage": create a Developer Product, then add_system monetization with config { Monetization: { Products: { [id]: { Kind: "SkipStage" } } } }.',
          ...COMMON_NEXT,
        ],
      };
    },
  },
  {
    id: 'tycoon',
    title: 'Tycoon',
    genre: 'Tycoon',
    summary: 'Claimable plots with droppers, conveyor, upgrader and collector; 10 purchases in order (walls, garden, super dropper, tower); progress is saved.',
    options: { title: 'welcome text', plots: '1-8 (default 4)' },
    plan: (o) => ({
      systems: ['hud', 'tycoon', 'movers', 'daily', 'leaderboard', 'movement', 'atmosphere', 'admin'],
      config: {
        Core: { WelcomeMessage: o.title ? `Welcome to ${o.title}! Claim a plot to start.` : 'Claim a plot to start your tycoon! 🏭' },
        DailyReward: { Stat: 'Cash', BaseAmount: 100 },
        Movement: { DoubleJump: false },
      },
      world: [
        worldPlacement(tycoonPlots({ count: o.plots ?? 4, position: [0, 0.5, 0] })),
        worldPlacement(piece('leaderboard', [0, 0.5, 70], { name: 'CashBoard', stat: 'Cash', title: 'Richest Tycoons', yaw: 0 })),
        worldPlacement(decorScatter({ position: [0, 0, 0], radius: 220, clear: 190, count: 40, seed: o.seed })),
      ],
      environment: { preset: o.lighting ?? 'day' },
      nextSteps: [
        'Add purchases: put a Model in a plot\'s Items folder and a button part (attributes Item, Price, Requires) in Buttons; do it for every plot (the plots are identical).',
        'Balance: change DropValue/DropInterval attributes on Dropper parts and Price attributes on buttons.',
        ...COMMON_NEXT,
      ],
    }),
  },
  {
    id: 'simulator',
    title: 'Simulator',
    genre: 'Simulator',
    summary: 'Train to fill your backpack with Power, sell for Coins, buy upgrades and pets, unlock zones with bigger orbs, rebirth for a permanent multiplier.',
    options: { zones: '1-6 (default 3)' },
    plan: (o) => ({
      systems: ['hud', 'simulator', 'collectibles', 'shop', 'daily', 'leaderboard', 'movement', 'atmosphere', 'admin'],
      config: {
        Core: { WelcomeMessage: 'Train 💪, sell 💰, rebirth 🔁!' },
        Hud: { ExtraStats: ['Power'] },
        Collectibles: { DefaultStat: 'Power' },
        Shop: {
          Title: 'Upgrades & Pets',
          Items: [
            { Id: 'Backpack', Name: 'Bigger Backpack', Description: '+50 capacity per level', Price: 50, Kind: 'Upgrade', Stat: 'Capacity', Value: 50, PriceGrowth: 1.6, Icon: '🎒' },
            { Id: 'Strength', Name: 'Stronger Training', Description: '+1 Power per train', Price: 40, Kind: 'Upgrade', Stat: 'ClickPower', Value: 1, PriceGrowth: 1.7, Icon: '💪' },
            { Id: 'PetDog', Name: 'Doggo', Description: 'x1.5 Power', Price: 200, Kind: 'Pet', Stat: 'Power', Value: 1.5, Color: '#C8A165', Icon: '🐶' },
            { Id: 'PetCat', Name: 'Kitty', Description: 'x2 Power', Price: 1500, Kind: 'Pet', Stat: 'Power', Value: 2, Color: '#F5A623', Icon: '🐱' },
            { Id: 'PetDragon', Name: 'Dragon', Description: 'x4 Power', Price: 25000, Kind: 'Pet', Stat: 'Power', Value: 4, Color: '#E53935', Icon: '🐲' },
            { Id: 'SpeedBoost', Name: 'Speed Boost', Description: 'Run faster', Price: 300, Kind: 'WalkSpeed', Value: 24, Icon: '⚡' },
            { Id: 'GoldTrail', Name: 'Gold Trail', Description: 'Show off', Price: 150, Kind: 'Trail', Value: '#FFD700', Icon: '✨' },
          ],
        },
      },
      world: [worldPlacement(simulatorWorld({ zones: o.zones ?? 3, position: [0, 0.5, 0] }))],
      environment: { preset: o.lighting ?? 'day' },
      nextSteps: [
        'Balance the economy in Config.Simulator and Config.Shop (prices, PriceGrowth, pet multipliers).',
        'Add zones: build_world simulator_world with more zones (replaces the world).',
        ...COMMON_NEXT,
      ],
    }),
  },
  {
    id: 'arena',
    title: 'Sword arena (PvP rounds)',
    genre: 'Fighting',
    summary: 'Lobby + arena with cover, round loop (intermission, last one standing wins), swords given during rounds, kill and win rewards, shop with trails and boosts.',
    options: { title: 'lobby sign text', theme: 'arena theme' },
    plan: (o) => ({
      systems: ['hud', 'rounds', 'combat', 'shop', 'daily', 'leaderboard', 'movement', 'atmosphere', 'admin'],
      config: {
        Core: { WelcomeMessage: 'Last one standing wins! ⚔️' },
        Combat: { GiveSword: 'InRound' },
        Atmosphere: { DayNightCycle: false },
      },
      world: [
        worldPlacement(lobby({ position: [0, 0.5, 0], title: o.title ?? 'SWORD ARENA', leaderboardStat: 'Wins', theme: 'rainbow' })),
        worldPlacement(arena({ position: [0, 0.5, 220], theme: o.theme ?? 'nature', seed: o.seed })),
      ],
      environment: { preset: o.lighting ?? 'sunset' },
      nextSteps: [
        'Add maps: put arena Models (with RoundSpawn parts) in ServerStorage.GameKit.Maps for rotation.',
        'Test PvP with 2 players: Studio Test tab > Clients and Servers > 2 players.',
        ...COMMON_NEXT,
      ],
    }),
  },
  {
    id: 'survival',
    title: 'Zombie survival (waves)',
    genre: 'Survival',
    summary: 'Survive growing waves of zombies (normal, fast, brute) with a sword; earn coins per kill and per wave; spend them in the shop.',
    options: { title: 'unused', seed: 'layout seed' },
    plan: (o) => {
      const center: [number, number, number] = [0, 0.5, 0];
      const s = 120;
      const corner = s / 2 - 10;
      return {
        systems: ['hud', 'enemies', 'combat', 'shop', 'daily', 'leaderboard', 'movement', 'atmosphere', 'admin'],
        config: {
          Core: { WelcomeMessage: 'Survive the zombie waves! 🧟' },
          Combat: { GiveSword: 'Always' },
          Atmosphere: { DayNightCycle: false, StartTime: 20 },
          Enemies: {
            Types: {
              Zombie: { Health: 100, WalkSpeed: 11, Damage: 15, AttackCooldown: 1, AttackRange: 5, DetectRange: 150, Rewards: { Coins: 5 }, SkinColor: '#6E9E4C', ShirtColor: '#4B3B2A', Scale: 1 },
              FastZombie: { Health: 60, WalkSpeed: 16, Damage: 10, AttackCooldown: 0.8, AttackRange: 5, DetectRange: 150, Rewards: { Coins: 8 }, SkinColor: '#8FBC5A', ShirtColor: '#7A2E2E', Scale: 0.9 },
              BruteZombie: { Health: 300, WalkSpeed: 8, Damage: 35, AttackCooldown: 1.5, AttackRange: 6, DetectRange: 150, Rewards: { Coins: 25 }, SkinColor: '#4E6B3A', ShirtColor: '#2E2E4B', Scale: 1.4 },
            },
            Waves: { Enabled: true, FirstWaveSize: 4, GrowthPerWave: 3, BreakSeconds: 12, SurviveRewards: { Coins: 20 } },
          },
        },
        world: [
          worldPlacement(arena({ position: center, size: s, theme: 'lava', seed: o.seed, spawns: 0 }), 'Town'),
          worldPlacement(piece('spawn', [0, 1, 20], { name: 'Spawn', lobby: true, forcefield: 5 })),
          worldPlacement(piece('enemy_spawner', [corner, 1.5, 0], { name: 'SpawnerEast', enemy: 'Zombie' })),
          worldPlacement(piece('enemy_spawner', [-corner, 1.5, 0], { name: 'SpawnerWest', enemy: 'FastZombie' })),
          worldPlacement(piece('enemy_spawner', [0, 1.5, corner], { name: 'SpawnerNorth', enemy: 'Zombie' })),
          worldPlacement(piece('enemy_spawner', [0, 1.5, -corner], { name: 'SpawnerSouth', enemy: 'BruteZombie' })),
          worldPlacement(piece('leaderboard', [0, 0.5, -s / 2 + 3], { name: 'CoinsBoard', stat: 'Coins', title: 'Top Survivors' })),
          worldPlacement(piece('shop_stand', [20, 0.5, 20], { name: 'ShopStand' })),
        ],
        environment: { preset: o.lighting ?? 'night' },
        nextSteps: [
          'Tune difficulty in Config.Enemies (Types health/speed/damage, Waves growth).',
          'Custom zombie look: put a rig Model named "Zombie" in ServerStorage.GameKit.Enemies.',
          ...COMMON_NEXT,
        ],
      };
    },
  },
  {
    id: 'horror_escape',
    title: 'Horror escape (maze + monster)',
    genre: 'Horror',
    summary: 'Dark generated maze with flickering lights: find the keys, open the exit and escape before the monster catches you. Runs reset automatically.',
    options: { mazeSize: '6-20 cells (default 10)', keys: 'keys to find (default 3)', seed: 'maze layout seed' },
    plan: (o) => {
      const size = Math.max(6, Math.min(20, o.mazeSize ?? 10));
      return {
        systems: ['hud', 'objectives', 'enemies', 'movement', 'atmosphere', 'admin', 'daily'],
        config: {
          Core: { WelcomeMessage: 'Find the keys... and don\'t get caught 👀' },
          Movement: { DoubleJump: false, SprintMultiplier: 1.4 },
          Atmosphere: { DayNightCycle: false, StartTime: 0 },
          Enemies: {
            Types: {
              Monster: { Health: 5000, WalkSpeed: 14, Damage: 100, AttackCooldown: 1.2, AttackRange: 5, DetectRange: 70, Rewards: {}, SkinColor: '#141414', ShirtColor: '#0A0A0A', Scale: 1.35 },
            },
          },
        },
        world: [worldPlacement(maze({ position: [0, 0.5, 0], width: size, height: size, keys: o.keys ?? 3, seed: o.seed, ceiling: true }))],
        environment: { preset: o.lighting ?? 'horror', removeBaseplate: true },
        nextSteps: [
          'Add jump scares/sounds: put Sound objects (public ids) in the maze and play them from a script.',
          'Make it harder: more keys, bigger maze, faster Monster (Config.Enemies.Types.Monster.WalkSpeed).',
          ...COMMON_NEXT,
        ],
      };
    },
  },
  {
    id: 'tower_defense',
    title: 'Tower defense (co-op)',
    genre: 'Tower defense',
    summary: 'Enemies walk a winding path in waves (Basic, Fast, Tank, Boss); players build and upgrade Archer, Cannon (splash) and Frost (slow) towers on 15 pads with match cash and defend the castle together. Victory rewards Wins and Coins.',
    options: { waves: '5-50 waves to win (default 15)', title: 'welcome text' },
    plan: (o) => ({
      systems: ['hud', 'towerdefense', 'shop', 'daily', 'leaderboard', 'movement', 'atmosphere', 'admin'],
      config: {
        Core: { WelcomeMessage: o.title ? `Welcome to ${o.title}! Build towers on the pads 🏹` : 'Build towers on the pads and protect the castle! 🏰' },
        TowerDefense: { MaxWaves: Math.max(5, Math.min(50, o.waves ?? 15)) },
        Movement: { DoubleJump: false },
        Atmosphere: { DayNightCycle: false },
        Shop: {
          Title: 'Shop',
          Currency: 'Coins',
          Items: [
            { Id: 'SpeedBoost', Name: 'Speed Boost', Description: 'Run between pads faster', Price: 150, Kind: 'WalkSpeed', Value: 24, Icon: '⚡' },
            { Id: 'GoldTrail', Name: 'Gold Trail', Description: 'Show off your victories', Price: 300, Kind: 'Trail', Value: '#FFD700', Icon: '✨' },
            { Id: 'DoubleCoins', Name: '2x Coins', Description: 'Double victory coins', Price: 2000, Kind: 'Multiplier', Stat: 'Coins', Value: 2, Icon: '💰' },
          ],
        },
      },
      world: [
        worldPlacement(tdMap({ position: [0, 0.5, 0] })),
        worldPlacement(piece('leaderboard', [-20, 0.5, -80], { name: 'WinsBoard', stat: 'Wins', title: 'Most Victories', yaw: 0 })),
        worldPlacement(piece('shop_stand', [10, 0.5, -80], { name: 'ShopStand' })),
        worldPlacement(decorScatter({ position: [0, 0, 0], radius: 190, clear: 135, count: 45, seed: o.seed })),
      ],
      environment: { preset: o.lighting ?? 'day' },
      nextSteps: [
        'Balance: balance_economy {fromGame: true} checks damage per coin; tune Config.TowerDefense (Towers, Enemies, Waves).',
        'New tower type: add it to Config.TowerDefense.Towers, then build_world piece "tower_pad" {tower: "Laser"} next to the path.',
        'Test with 2 players (Studio Test > Clients and Servers) - it is a co-op game.',
        ...COMMON_NEXT,
      ],
    }),
  },
  {
    id: 'farming',
    title: 'Farming (idle)',
    genre: 'Farming / Idle',
    summary: 'Plant seeds on 24 plots, watch them grow, harvest, sell at the market and unlock better crops (Wheat -> Carrot -> Tomato -> Pumpkin -> Crystal). Calm, saved progression with a shop and daily rewards.',
    options: { plots: '4-64 plots (default 24)', title: 'welcome text' },
    plan: (o) => ({
      systems: ['hud', 'farming', 'shop', 'daily', 'leaderboard', 'movement', 'atmosphere', 'admin'],
      config: {
        Core: { WelcomeMessage: o.title ? `Welcome to ${o.title}! 🌾` : 'Plant 🌱, harvest 🧺, sell 💰, unlock better crops!' },
        Hud: { ExtraStats: ['Basket'] },
        Movement: { DoubleJump: false },
        DailyReward: { Stat: 'Coins', BaseAmount: 40 },
        Shop: {
          Title: 'Farm shop',
          Items: [
            { Id: 'SpeedBoost', Name: 'Running Boots', Description: 'Run between fields faster', Price: 120, Kind: 'WalkSpeed', Value: 24, Icon: '👢' },
            { Id: 'DoubleCoins', Name: 'Golden Basket', Description: '2x coins when selling', Price: 5000, Kind: 'Multiplier', Stat: 'Coins', Value: 2, Icon: '🧺' },
            { Id: 'PetChick', Name: 'Chick', Description: 'x1.25 coins', Price: 800, Kind: 'Pet', Stat: 'Coins', Value: 1.25, Color: '#FFEB3B', Icon: '🐤' },
            { Id: 'GreenTrail', Name: 'Leaf Trail', Description: 'A trail of leaves', Price: 200, Kind: 'Trail', Value: '#7CB342', Icon: '🍃' },
          ],
        },
      },
      world: [
        worldPlacement(farm({ position: [0, 0.5, 0], plots: o.plots ?? 24 })),
        worldPlacement(piece('leaderboard', [-30, 0.5, -75], { name: 'CoinsBoard', stat: 'Coins', title: 'Richest Farmers', yaw: 0 })),
        worldPlacement(piece('shop_stand', [30, 0.5, -60], { name: 'ShopStand' })),
        worldPlacement(decorScatter({ position: [0, 0, 0], radius: 200, clear: 130, count: 40, seed: o.seed })),
      ],
      environment: { preset: o.lighting ?? 'day' },
      nextSteps: [
        'Balance: balance_economy {fromGame: true} shows coins per minute of each crop and unlock times; tune Config.Farming.Crops.',
        'More plots: build_world farm {plots: 40} (replaces the farm) or add farm_plot pieces.',
        ...COMMON_NEXT,
      ],
    }),
  },
  {
    id: 'racing',
    title: 'Kart racing',
    genre: 'Racing',
    summary: 'Kart races on an oval track: starting grid, 3-2-1-GO, laps through checkpoints, live positions, best lap saved, podium rewards, quests and levels. Works on keyboard, gamepad and mobile.',
    options: { laps: 'laps per race (default 3)', karts: 'false = running race instead of karts', title: 'welcome text' },
    plan: (o) => ({
      systems: ['hud', 'racing', 'levels', 'quests', 'shop', 'daily', 'leaderboard', 'atmosphere', 'admin'],
      config: {
        Core: { WelcomeMessage: o.title ? `Welcome to ${o.title}! 🏎` : 'Race 🏎, win 🏆, beat your best lap ⏱!' },
        Racing: { Laps: o.laps ?? 3, UseKarts: o.karts ?? true },
        Atmosphere: { DayNightCycle: false, StartTime: 14 },
        Quests: {
          Mode: 'Chain',
          List: [
            { Id: 'FirstRace', Title: 'Finish a race', Type: 'Earn', Stat: 'Coins', Amount: 15, Rewards: { XP: 50 } },
            { Id: 'FirstWin', Title: 'Win a race', Type: 'Reach', Stat: 'Wins', Amount: 1, Rewards: { XP: 150, Coins: 100 } },
            { Id: 'Level5', Title: 'Reach level 5', Type: 'Reach', Stat: 'Level', Amount: 5, Rewards: { Coins: 250 } },
            { Id: 'FiveWins', Title: 'Win 5 races', Type: 'Reach', Stat: 'Wins', Amount: 5, Rewards: { XP: 500, Coins: 500 } },
          ],
        },
        Shop: {
          Title: 'Garage',
          Items: [
            { Id: 'FireTrail', Name: 'Fire Trail', Description: 'Leave flames behind', Price: 150, Kind: 'Trail', Value: '#FF5722', Icon: '🔥' },
            { Id: 'NeonTrail', Name: 'Neon Trail', Description: 'Glow on the track', Price: 400, Kind: 'Trail', Value: '#00E5FF', Icon: '💠' },
            { Id: 'DoubleCoins', Name: 'Sponsor Deal', Description: '2x coins', Price: 3000, Kind: 'Multiplier', Stat: 'Coins', Value: 2, Icon: '💰' },
          ],
        },
      },
      world: [worldPlacement(raceTrack({ position: [0, 0.5, 0] }))],
      environment: { preset: o.lighting ?? 'day' },
      nextSteps: [
        'Tune Config.Racing (Laps, KartSpeed, KartTurnSpeed, PlaceRewards). Test with 2 players: test_game {players: 2}.',
        'Longer track: build_world race_track {length: 260, radius: 70} (replaces it), or add RaceCheckpoint parts (Order) for a custom layout.',
        ...COMMON_NEXT,
      ],
    }),
  },
  {
    id: 'fishing',
    title: 'Fishing',
    genre: 'Fishing / Collection',
    summary: 'Cast, wait for the bite, reel in time: 6 fish in 2 zones (pond, ocean) with rarities, sell at the fish market, upgrade your rod to fish faster, catch rarer fish and unlock the ocean. Quests, levels, eggs and pets.',
    options: { title: 'welcome text' },
    plan: (o) => ({
      systems: ['hud', 'inventory', 'fishing', 'levels', 'quests', 'pets', 'shop', 'daily', 'leaderboard', 'movement', 'atmosphere', 'admin'],
      config: {
        Core: { WelcomeMessage: o.title ? `Welcome to ${o.title}! 🎣` : 'Fish 🎣, sell 💰, upgrade your rod, catch the legendary Golden Koi ✨!' },
        Movement: { DoubleJump: false },
        Inventory: { Items: {}, SellCurrency: 'Coins' },
        Shop: {
          Title: 'Tackle shop',
          Items: [
            { Id: 'Rod', Name: 'Better Rod', Description: '+1 rod level: faster bites, rarer fish, level 2 opens the ocean', Price: 120, Kind: 'Upgrade', Stat: 'RodLevel', Value: 1, PriceGrowth: 2.4, MaxLevel: 6, Icon: '🎣' },
            { Id: 'Boots', Name: 'Running Boots', Description: 'Run faster', Price: 150, Kind: 'WalkSpeed', Value: 24, Icon: '👢' },
            { Id: 'DoubleCoins', Name: 'Golden Net', Description: '2x coins when selling', Price: 4000, Kind: 'Multiplier', Stat: 'Coins', Value: 2, Icon: '🥅' },
          ],
        },
        Quests: {
          Mode: 'Chain',
          List: [
            { Id: 'FirstFish', Title: 'Catch a fish', Type: 'Earn', Stat: 'Fish', Amount: 1, Rewards: { XP: 20, Coins: 10 } },
            { Id: 'FirstSale', Title: 'Sell fish for 30 coins', Type: 'Earn', Stat: 'Coins', Amount: 30, Rewards: { XP: 40 } },
            { Id: 'BetterRod', Title: 'Buy a better rod', Type: 'Reach', Stat: 'RodLevel', Amount: 1, Rewards: { XP: 60 } },
            { Id: 'Salmon', Title: 'Catch a salmon', Type: 'Have', Item: 'Salmon', Amount: 1, Rewards: { Coins: 50 } },
            { Id: 'Ocean', Title: 'Unlock the ocean (rod level 2)', Type: 'Reach', Stat: 'RodLevel', Amount: 2, Rewards: { XP: 150 } },
            { Id: 'SecretCove', Title: 'Find the secret cove', Type: 'Touch', Amount: 1, Rewards: { Coins: 150 } },
            { Id: 'Shark', Title: 'Catch a shark', Type: 'Have', Item: 'Shark', Amount: 1, Rewards: { Coins: 500, XP: 300 } },
            { Id: 'HundredFish', Title: 'Catch 100 fish', Type: 'Earn', Stat: 'Fish', Amount: 100, Rewards: { Coins: 1000, XP: 800 } },
          ],
        },
        Pets: {
          Stat: 'Coins',
          Eggs: {
            Sea: {
              Price: 300, Currency: 'Coins', Color: '#4FC3F7',
              Pets: [
                { Id: 'Crab', Name: 'Crab', Chance: 55, Multiplier: 1.2, Rarity: 'Common', Color: '#EF5350' },
                { Id: 'Turtle', Name: 'Turtle', Chance: 35, Multiplier: 1.5, Rarity: 'Rare', Color: '#66BB6A' },
                { Id: 'Kraken', Name: 'Kraken', Chance: 10, Multiplier: 3, Rarity: 'Legendary', Color: '#7E57C2' },
              ],
            },
          },
        },
      },
      world: [
        worldPlacement(fishingLake({ position: [0, 0.5, 0] })),
        worldPlacement(piece('egg_stand', [45, 0.5, -70], { name: 'SeaEgg', egg: 'Sea', color: [79, 195, 247] })),
      ],
      environment: { preset: o.lighting ?? 'day' },
      nextSteps: [
        'Add fish and zones in Config.Fishing.Zones (each FishingSpot part has a Zone attribute).',
        'Balance: sell prices vs rod prices (Config.Shop Rod PriceGrowth). Players should afford rod level 2 in ~10 minutes.',
        ...COMMON_NEXT,
      ],
    }),
  },
  {
    id: 'craft_survival',
    title: 'Co-op survival with crafting',
    genre: 'Survival / Crafting',
    summary: 'Gather wood, stone and berries by day, craft axes, swords, walls, spikes and campfires, keep your hunger up, and defend the camp together against zombie waves every night.',
    options: { title: 'welcome text', seed: 'forest layout seed' },
    plan: (o) => ({
      systems: ['hud', 'inventory', 'crafting', 'enemies', 'combat', 'levels', 'quests', 'shop', 'daily', 'leaderboard', 'movement', 'atmosphere', 'admin'],
      config: {
        Core: { WelcomeMessage: o.title ? `Welcome to ${o.title}! 🔥` : 'Gather 🪵, craft 🔨, survive the night together 🧟!' },
        Combat: { GiveSword: 'Never', KillRewards: { Kills: 1, Coins: 5 } },
        Atmosphere: { DayNightCycle: false, StartTime: 14 },
        Crafting: { Hunger: { Enabled: true, Max: 100, DrainPerMinute: 6, StarveDamage: 4, Food: { Berry: 12 } } },
        Enemies: {
          Types: {
            Zombie: { Health: 80, WalkSpeed: 10, Damage: 12, AttackCooldown: 1, AttackRange: 5, DetectRange: 200, Rewards: { Coins: 5 }, SkinColor: '#6E9E4C', ShirtColor: '#4B3B2A', Scale: 1 },
          },
          Waves: { Enabled: true, FirstWaveSize: 3, GrowthPerWave: 2, BreakSeconds: 120, SurviveRewards: { Coins: 25, XP: 50 }, DayNight: true },
        },
        Quests: {
          Mode: 'Chain',
          List: [
            { Id: 'Wood', Title: 'Chop 6 wood', Type: 'Have', Item: 'Wood', Amount: 6, Rewards: { XP: 20 } },
            { Id: 'Stone', Title: 'Mine 4 stone', Type: 'Have', Item: 'Stone', Amount: 4, Rewards: { XP: 20 } },
            { Id: 'Planks', Title: 'Craft planks', Type: 'Have', Item: 'Planks', Amount: 3, Rewards: { XP: 30 } },
            { Id: 'Survive', Title: 'Defeat 5 zombies', Type: 'Earn', Stat: 'Kills', Amount: 5, Rewards: { Coins: 50, XP: 100 } },
            { Id: 'Level3', Title: 'Reach level 3', Type: 'Reach', Stat: 'Level', Amount: 3, Rewards: { Coins: 100 } },
            { Id: 'Hunter', Title: 'Defeat 50 zombies', Type: 'Earn', Stat: 'Kills', Amount: 50, Rewards: { Coins: 500, XP: 800 } },
          ],
        },
        Shop: {
          Title: 'Trader',
          Items: [
            { Id: 'Sword', Name: 'Iron Sword', Description: 'A real weapon', Price: 150, Kind: 'Tool', Value: 'Sword', Icon: '⚔️' },
            { Id: 'Boots', Name: 'Running Boots', Description: 'Run faster', Price: 100, Kind: 'WalkSpeed', Value: 22, Icon: '👢' },
          ],
        },
      },
      world: [worldPlacement(survivalCamp({ position: [0, 0.5, 0], seed: o.seed }))],
      environment: { preset: o.lighting ?? 'day' },
      nextSteps: [
        'Tune Config.Crafting (Recipes, Nodes Hits/Respawn, Hunger) and Config.Enemies.Waves (BreakSeconds = daytime).',
        'Test co-op: test_game {players: 2}. Add recipes: { Id = "Torch", Needs = { Wood = 1 } }.',
        ...COMMON_NEXT,
      ],
    }),
  },
];

export function getTemplate(id: string): TemplateDef {
  const template = TEMPLATES.find((t) => t.id === id);
  if (!template) throw new Error(`Unknown template "${id}". Available: ${TEMPLATES.map((t) => t.id).join(', ')}`);
  return template;
}
