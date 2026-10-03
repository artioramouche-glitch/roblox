--!nonstrict
--[[ TestCombatSim
     Rôle    : faire jouer des matchs complets au moteur de combat entre deux joueurs automatiques identiques, pour
               prouver qu'ils finissent tous et qu'aucun côté n'est avantagé, et mesurer leur durée (E1 : 60-90 s).
     Doc     : GAME_MASTER_V2 E1, E3, E5, B4, G5.6 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot C, H5.4 ; décision 122
     Étape   : 13, lot C
     Dépend  : ServerScriptService.Combat.CombatEngine ; ReplicatedStorage.Config.CreatureConfig
     Exposé  : exécution manuelle ; aucune écriture de données. Lignes [OK]/[FAIL] pour les invariants, lignes
               [INFO] pour les mesures (durées, ultimes) : une mesure hors de E1 se signale, elle ne se corrige pas
               ici (étape 17, un curseur à la fois).
     Limite  : le joueur automatique est volontairement simple (ultime et capacité dès que possible, soin sous 60 %
               de PV, switch sous 25 %) : il ne remplace ni un humain ni les bots du lot D. Stats classées du
               tier Normal (B4 × CreatureConfig), monde 1 ; tirages fixés par math.randomseed pour rejouer à
               l'identique.
]]
local SSS = game:GetService("ServerScriptService")
local Engine = require(assert(assert(SSS:FindFirstChild("Combat"), "Combat absent"):FindFirstChild("CombatEngine"),
    "CombatEngine absent"))
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
local MATCHES = 1000
-- Studio coupe un script qui calcule plus de 10 s sans rendre la main ; la CLI Luau n'a pas `task`.
local yield = if type(task) == "table" then task.wait else function() end
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function info(text) table.insert(T.lines, "[INFO] " .. text) end

-- Brainrots du monde 1 par rareté.
local byRarity, world1 = {}, {}
for _, c in ipairs(C.Creatures) do
    if c.world == 1 then
        byRarity[c.rarity] = byRarity[c.rarity] or {}
        table.insert(byRarity[c.rarity], c.id)
        table.insert(world1, c.id)
    end
end
local function entry(id)
    local s = C:GetCombatStats(id, 1, true)
    return {Id = id, HP = s.HP, ATK = s.ATK, Type = s.Type}
end
local function team(pool)
    local out = {}
    for i = 1, 3 do out[i] = entry(pool[math.random(1, #pool)]) end
    return out
end

-- Joueur automatique : lit l'état du moteur (outil de test, pas un client).
local function decide(match, name)
    local side = match.Sides[name]
    local fighter = side.Team[side.Active]
    if side.Crowd >= 1 then Engine.Ultimate(match, name) end
    if side.Charge >= 1 and (fighter.Ability.kind ~= "Heal" or fighter.HP < 0.6 * fighter.MaxHP) then
        Engine.Activate(match, name)
    end
    if side.SwitchCd == 0 and fighter.Alive and fighter.HP < 0.25 * fighter.MaxHP then
        local best, bestShare = nil, 0.5
        for slot, other in ipairs(side.Team) do
            if slot ~= side.Active and other.Alive and other.HP / other.MaxHP > bestShare then
                best, bestShare = slot, other.HP / other.MaxHP
            end
        end
        if best then Engine.Switch(match, name, best) end
    end
end

-- Un match jusqu'au bout ; l'ordre des décisions alterne à chaque tick pour n'avantager aucun côté.
local function play(teamA, teamB, seed)
    local match = assert(Engine.New(teamA, teamB, seed))
    local steps = 0
    while not match.Over and steps < 5000 do
        if steps % 2 == 0 then decide(match, "A"); decide(match, "B") else decide(match, "B"); decide(match, "A") end
        Engine.Step(match)
        Engine.Snapshot(match)
        steps += 1
    end
    return match, Engine.Result(match)
end

local function percentile(sorted, p) return sorted[math.max(1, math.ceil(#sorted * p))] end

local scenarios = {
    {Name = "3 Communs contre 3 Communs", Pools = function() return byRarity.Common, byRarity.Common end},
    {Name = "même rareté des deux côtés", Pools = function()
        local rarity = C.Rarities[math.random(1, #C.Rarities)].Id
        return byRarity[rarity], byRarity[rarity]
    end},
    {Name = "monde 1 au hasard", Pools = function() return world1, world1 end},
}
math.randomseed(20261003)
local allOver, allInTime, allConsistent, replayOk = true, true, true, true
for index, scenario in ipairs(scenarios) do
    local durations, winsA, winsB, draws, timeouts, ultimates, abilities = {}, 0, 0, 0, 0, 0, 0
    local within, short = 0, 0
    for i = 1, MATCHES do
        if i % 50 == 0 then yield() end
        local poolA, poolB = scenario.Pools()
        local teamA, teamB = team(poolA), team(poolB)
        local seed = math.random(0, 2 ^ 31 - 1)
        local match, result = play(teamA, teamB, seed)
        allOver = allOver and match.Over
        allInTime = allInTime and match.Clock <= 900
        if result.Reason == "Timeout" then
            timeouts += 1
            local a, b = result.A.Share, result.B.Share
            allConsistent = allConsistent and (result.Winner == "Draw" or (result.Winner == "A") == (a > b))
        else
            local loser = if result.Winner == "A" then result.B else result.A
            local dead = true
            for _, hp in ipairs(loser.HP) do dead = dead and hp == 0 end
            allConsistent = allConsistent and result.Reason == "KO" and (result.Winner == "Draw" or dead)
        end
        if result.Winner == "A" then winsA += 1 elseif result.Winner == "B" then winsB += 1 else draws += 1 end
        table.insert(durations, result.Seconds)
        if result.Seconds < 60 then short += 1 elseif result.Seconds <= 90 then within += 1 end
        ultimates += result.A.Ultimates + result.B.Ultimates
        abilities += result.A.Abilities + result.B.Abilities
        if index == 1 and i == 1 then
            local _, again = play(teamA, teamB, seed)
            replayOk = again.Winner == result.Winner and again.Seconds == result.Seconds
                and again.A.Damage == result.A.Damage and again.B.Damage == result.B.Damage
        end
    end
    table.sort(durations)
    local shareA = winsA / math.max(1, winsA + winsB)
    check(("%s : aucun côté avantagé (A gagne %.1f %% des matchs décidés)"):format(scenario.Name, shareA * 100),
        shareA >= 0.45 and shareA <= 0.55)
    info(("%s : durée médiane %.1f s (10 %% sous %.1f s, 90 %% sous %.1f s) ; %d %% sous 60 s, %d %% de 60 à 90 s, "
        .. "%d %% au temps limite ; %d nuls"):format(scenario.Name, percentile(durations, 0.5),
        percentile(durations, 0.1), percentile(durations, 0.9), math.round(short / MATCHES * 100),
        math.round(within / MATCHES * 100), math.round(timeouts / MATCHES * 100), draws))
    info(("%s : %.2f ultimes et %.1f capacités par match (2 joueurs)"):format(scenario.Name, ultimates / MATCHES,
        abilities / MATCHES))
end
check(("Les %d matchs finissent tous, aucun au-delà de 90 s de jeu"):format(MATCHES * #scenarios), allOver and allInTime)
check("Chaque vainqueur est cohérent (équipe adverse KO, ou plus forte part de PV au temps limite)", allConsistent)
check("Même graine et mêmes actions → même match (rejeu)", replayOk)

local summary = ("[COMBAT SIM TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
