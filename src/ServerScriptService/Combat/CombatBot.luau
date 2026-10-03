--!strict
--[[ CombatBot
     Rôle    : adversaire bot de l'arène : son équipe (miroir de celle du joueur), son Elo et ses décisions de
               match, prises tick après tick avec ce qu'un joueur voit à l'écran.
     Doc     : GAME_MASTER_V2 G5.5, E1, E6, E11.1, E11.4, B4 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot D ; décisions
               113, 123 et 124
     Étape   : 13, lot D
     Dépend  : Combat.CombatEngine (View et les 3 actions) ; Config.CreatureConfig, Config.ArenaConfig (Bots)
     Exposé  : Elo(eloJoueur) ; Team(créatures, kind, ranked, roll) -> entrées du moteur | (nil, raison) ;
               NewBrain(kind, reflexSeconds?) -> cerveau ; Decide(cerveau, match, side)
     Limite  : le bot ne lit que CombatEngine.View (jauges prêtes, PV, capacité de chaque brainrot), jamais la
               graine. Normal (Q1 A) : stats B4 intactes, capacité et ultime 2 s après qu'ils sont prêts. Tutorial
               et Guard (Q2 A) : stats ×0,5, ne lance rien, perd toujours (TestCombatBot). `roll` est un tirage
               dans [0, 1) fourni par l'appelant (Random côté serveur), pour rejouer les tests.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = ReplicatedStorage:WaitForChild("Config")
local CreatureConfig = require(config:WaitForChild("CreatureConfig")) :: any
local ArenaConfig = require(config:WaitForChild("ArenaConfig"))
local combat = game:GetService("ServerScriptService"):WaitForChild("Combat")
local CombatEngine: any = require(combat:WaitForChild("CombatEngine"))

local BOTS = ArenaConfig.Bots
local PER_SECOND = math.round(1 / ArenaConfig.Match.TickSeconds)

export type Brain = {Kind: string, Passive: boolean, Reflex: number, AbilityTicks: number, UltimateTicks: number}

local CombatBot = {}

-- G5.5 / E6 : Elo du bot = Elo du joueur − 100 (décision 113).
function CombatBot.Elo(playerElo: number): number
    return playerElo + BOTS.EloOffset
end

-- Miroir (Q1 A) : pour chaque brainrot du joueur, un brainrot de même rareté, même monde et même tier, tiré au
-- hasard ; stats B4 (classées ou brutes selon le format), ×0,5 pour les bots faciles (Q2 A).
function CombatBot.Team(creatures: any, kind: string, ranked: boolean, roll: () -> number): (any, string?)
    if type(creatures) ~= "table" or #creatures < 1 or #creatures > ArenaConfig.Match.TeamSize then
        return nil, "BAD_TEAM"
    end
    if kind ~= "Normal" and kind ~= "Tutorial" and kind ~= "Guard" then return nil, "BAD_KIND" end
    local mult = if kind == "Normal" then 1 else BOTS.EasyStatMult
    local team = {}
    for slot, creature: any in ipairs(creatures) do
        local source = if type(creature) == "table" then CreatureConfig:Get(creature.Id) else nil
        if not source then return nil, "BAD_TEAM" end
        local pool = {}
        for _, candidate in ipairs(CreatureConfig.Creatures) do
            if candidate.rarity == source.rarity and candidate.world == source.world then
                table.insert(pool, candidate.id)
            end
        end
        local id = pool[math.min(#pool, math.floor(roll() * #pool) + 1)]
        local stats = CreatureConfig:GetCombatStats(id, creature.Tier or 1, ranked)
        team[slot] = {
            Id = id, Type = stats.Type,
            HP = math.max(1, math.floor(stats.HP * mult)), ATK = math.floor(stats.ATK * mult),
        }
    end
    return team, nil
end

-- `reflexSeconds` remplace les 2 s du bot normal (0 : le joueur automatique des tests).
function CombatBot.NewBrain(kind: string, reflexSeconds: number?): Brain
    local reflex = if reflexSeconds ~= nil then reflexSeconds else BOTS.ReflexSeconds
    return {
        Kind = kind, Passive = kind ~= "Normal", Reflex = math.round(reflex * PER_SECOND),
        AbilityTicks = 0, UltimateTicks = 0,
    }
end

-- Une décision par tick, avant CombatEngine.Step : ultime puis capacité une fois prêts depuis le temps de
-- réflexe ; SOIN gardé tant que le brainrot a 60 % de ses PV ; switch sous 25 % vers le remplaçant le plus en
-- forme s'il dépasse 50 %.
function CombatBot.Decide(brain: Brain, match: any, side: string)
    if brain.Passive then return end
    local view: any = CombatEngine.View(match, side)
    if view.Over then return end
    brain.UltimateTicks = if view.UltimateReady then brain.UltimateTicks + 1 else 0
    brain.AbilityTicks = if view.AbilityReady then brain.AbilityTicks + 1 else 0
    if not view.OnField or view.Frozen then return end
    if brain.UltimateTicks > brain.Reflex then CombatEngine.Ultimate(match, side) end
    local fighter = view.Team[view.Active]
    local holdHeal = fighter.Kind == "Heal" and fighter.HP >= BOTS.HealBelow * fighter.MaxHP
    if brain.AbilityTicks > brain.Reflex and not holdHeal then CombatEngine.Activate(match, side) end
    if view.SwitchReady and fighter.HP < BOTS.SwitchBelow * fighter.MaxHP then
        local best, bestShare = nil, BOTS.SwitchToAbove
        for slot, other: any in ipairs(view.Team) do
            if slot ~= view.Active and other.Alive and other.HP / other.MaxHP > bestShare then
                best, bestShare = slot, other.HP / other.MaxHP
            end
        end
        if best then CombatEngine.Switch(match, side, best) end
    end
end

return table.freeze(CombatBot)
