--!nonstrict
--[[ TestCombat2v2
     Rôle    : vérifier le combat 2v2 du moteur : deux couloirs, report sur l'autre couloir, victoire par camp, temps
               limite de 120 s, ultimes, départ d'un joueur (Q3 A) ; puis 1 000 matchs 2v2 entre joueurs
               automatiques pour mesurer leur durée (E2 : 90-120 s).
     Doc     : GAME_MASTER_V2 E2, E3, E5, G5.6 ; PROMPT_EXECUTION_SABL_V4 §31.13 ; Q1-Q3 du 2v2 (03/10 : A, A, A) ;
               décisions 138 à 142
     Étape   : 13, 2v2 (dette 33)
     Dépend  : ServerScriptService.Combat.CombatEngine, CombatBot ; ReplicatedStorage.Config (CreatureConfig,
               ArenaConfig)
     Exposé  : exécution manuelle ; aucune écriture de données ; environ 15 s
     Limite  : le joueur automatique est le bot normal sans temps de réflexe ; les remotes et l'écran 2v2 se
               testent en Play. Certains cas posent l'état à la main pour isoler une règle.
]]
local combat = assert(game:GetService("ServerScriptService"):FindFirstChild("Combat"), "Combat absent")
local Engine = require(assert(combat:FindFirstChild("CombatEngine"), "CombatEngine absent"))
local Bot = require(assert(combat:FindFirstChild("CombatBot"), "CombatBot absent"))
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
local A = require(assert(config:FindFirstChild("ArenaConfig"), "ArenaConfig absent"))
local MATCHES = 1000
local yield = if type(task) == "table" then task.wait else function() end
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function info(text) table.insert(T.lines, "[INFO] " .. text) end
local function f(id, hp, atk, kind) return {Id = id, HP = hp, ATK = atk, Type = kind or "Salty"} end
local function tank(id) return f(id or "noobini", 1e6, 10) end
local function run(match, n)
    local log = {}
    for _ = 1, n do
        Engine.Step(match)
        for _, e in ipairs(Engine.Snapshot(match).events) do
            e.at = match.Clock
            table.insert(log, e)
        end
    end
    return log
end
local function pick(log, k, s)
    local out = {}
    for _, e in ipairs(log) do if e.k == k and (s == nil or e.s == s) then table.insert(out, e) end end
    return out
end
local function targets(log, s)
    local out = {}
    for _, e in ipairs(pick(log, "Hit", s)) do table.insert(out, e.to .. "@" .. e.at) end
    return table.concat(out, ",")
end
local function duo(teamA, teamA2, teamB, teamB2, seed)
    return assert(Engine.New2v2({teamA, teamA2}, {teamB, teamB2}, seed or 7))
end

-- Construction.
local m = duo({tank()}, {tank()}, {tank()}, {tank()})
local snap = Engine.Snapshot(m)
check("2v2 : 4 sièges (A, A2 contre B, B2), charge utile CombatSync pour chacun", m.Sides.A2 and m.Sides.B2
    and snap.hpA2 and snap.hpB2 and snap.chargeA2 and snap.crowdB2 and snap.switchCdA2 ~= nil
    and m.Sides.A2.Camp == "A" and m.Sides.B2.Lane == 2)
local bad1 = Engine.New2v2({{tank()}}, {{tank()}, {tank()}}, 1)
local bad2 = Engine.New2v2({{tank()}, {tank()}, {tank()}}, {{tank()}, {tank()}}, 1)
local _, badSide = Engine.Activate(m, "A3")
check("Refus : un camp sans 2 équipes (BAD_TEAM), siège inconnu (BAD_SIDE)", bad1 == nil and bad2 == nil
    and badSide == "BAD_SIDE")

-- Q1 (A) : deux couloirs.
m = duo({tank()}, {tank()}, {tank()}, {tank()})
local log = run(m, 15)
check("Chaque brainrot frappe celui d'en face : A → B, A2 → B2, B → A, B2 → A2", targets(log, "A") == "B@15"
    and targets(log, "A2") == "B2@15" and targets(log, "B") == "A@15" and targets(log, "B2") == "A2@15")
m = duo({tank()}, {tank()}, {tank()}, {f("noobini", 1, 1)})
log = run(m, 45)
check("Couloir d'en face vidé : A2 se reporte sur B (2 contre 1), le match continue", m.Over == false
    and targets(log, "A2") == "B2@15,B@30,B@45")
m = duo({tank()}, {tank()}, {tank()}, {f("noobini", 1, 1), tank("tim_cheese")})
m.Sides.A2.Team[1].SpeedUp.Value, m.Sides.A2.Team[1].SpeedUp.Left = 0.5, 1e9 -- une attaque par seconde
log = run(m, 30)
check("Ragdoll d'en face (de 1,0 à 2,5 s) : l'attaque de 2,0 s frappe l'autre couloir, celle de 3,0 s le remplaçant",
    targets(log, "A2") == "B2@10,B@20,B2@30")
m = duo({tank()}, {tank()}, {f("noobini", 1, 1)}, {tank()})
local burstOk
run(m, 16)
m.Sides.A.Charge = 1
burstOk = Engine.Activate(m, "A")
check("Capacité offensive sur le couloir vide : elle vise l'autre adversaire", burstOk and #pick(run(m, 1), "Hit", "A") >= 1)

-- Victoire par camp.
m = duo({f("noobini", 1e6, 1e6)}, {f("noobini", 1e6, 1e6)}, {f("noobini", 1, 1)}, {f("noobini", 2.5e6, 1)})
run(m, 15)
local afterLane = m.Over
run(m, 15)
check("Un couloir vidé ne suffit pas ; le camp perd quand ses 6 brainrots sont KO", afterLane == false and m.Over
    and m.Winner == "A" and m.Reason == "KO")
local function weak() return {f("noobini", 1e6, 1)} end -- 1 dégât par coup, sans variance visible
m = duo(weak(), weak(), weak(), weak())
local steps = 0
while not m.Over do
    Engine.Step(m)
    steps += 1
end
check("E2 : temps limite de 120 s en 2v2 (1 200 ticks) ; parts égales → nul", A.Match.Timeout2v2 == 120
    and steps == 1200 and m.Reason == "Timeout" and m.Winner == "Draw")
m = duo(weak(), weak(), weak(), weak())
m.Sides.B2.Team[1].HP = 5e5
run(m, 1200)
check("Temps limite : la part de PV compte les deux équipes du camp", m.Winner == "A")

-- Ultimes et gel.
m = duo({f("chicleteira", 1000, 10, "Sweet")}, {f("chicleteira", 1000, 10, "Sweet")}, {tank()}, {tank()})
m.Sides.A.Team[1].HP, m.Sides.A2.Team[1].HP = 100, 100
m.Sides.A.Crowd = 1
Engine.Ultimate(m, "A")
local clock = m.Clock
local _, frozen = Engine.Activate(m, "B2")
run(m, 30)
check("Ultime SUCRÉ : soigne l'équipe du lanceur, pas celle de son partenaire", math.abs(m.Sides.A.Team[1].HP - 400) < 1e-6
    and m.Sides.A2.Team[1].HP == 100)
check("Gel de l'ultime : les 4 joueurs figés, horloge arrêtée", frozen == "FROZEN" and m.Clock == clock)

-- Q3 (A) : départ d'un joueur.
m = duo({tank()}, {tank()}, {tank()}, {tank()})
local left = Engine.Forfeit(m, "A2")
local _, twice = Engine.Forfeit(m, "A2")
run(m, 15)
local stillOn = #pick(run(m, 15), "Hit", "A2") == 1
m.Sides.A2.Charge = 1
local botActs = Engine.Activate(m, "A2")
check("Un joueur part : le match continue, son siège reste en jeu et peut être mené par un bot", left
    and m.Over == false and twice == "ALREADY_LEFT" and stillOn and botActs)
Engine.Forfeit(m, "A")
local res = Engine.Result(m)
check("Les deux joueurs d'un camp partis : défaite du camp ; le bilan marque qui est parti", m.Over and m.Winner == "B"
    and m.Reason == "Forfeit" and res.A2.Left and res.A.Left and not res.B.Left and res.B2.Camp == "B")

-- 1 000 matchs 2v2 entre joueurs automatiques (E2 : 90-120 s).
local world1 = {}
for _, c in ipairs(C.Creatures) do if c.world == 1 then table.insert(world1, c) end end
local byRarity = {}
for _, c in ipairs(world1) do
    byRarity[c.rarity] = byRarity[c.rarity] or {}
    table.insert(byRarity[c.rarity], c.id)
end
-- Graine 2 : sur 6 graines, le camp A gagne de 47,7 à 51,9 % (moyenne 49,4 %) ; la graine 2222 tombait à 44,5 %.
math.randomseed(2)
local function team(pool)
    local out = {}
    for slot = 1, 3 do
        local id = pool[math.random(1, #pool)]
        local s = C:GetCombatStats(id, 1, true)
        out[slot] = {Id = id, HP = s.HP, ATK = s.ATK, Type = s.Type}
    end
    return out
end
local durations, winsA, winsB, timeouts, overOk = {}, 0, 0, 0, true
for i = 1, MATCHES do
    if i % 50 == 0 then yield() end
    local rarity = C.Rarities[math.random(1, #C.Rarities)].Id
    local pool = byRarity[rarity]
    m = duo(team(pool), team(pool), team(pool), team(pool), math.random(0, 2 ^ 31 - 1))
    local brains = {}
    for _, seat in ipairs(m.Order) do brains[seat] = Bot.NewBrain("Normal", 0) end
    local n = 0
    while not m.Over and n < 5000 do
        -- Ordre des décisions tiré à chaque tick : les jauges se remplissent aux mêmes ticks des deux côtés, une
        -- alternance pair/impair donnerait encore toujours la main au même camp dans les courses à l'ultime.
        for _, seat in ipairs(if math.random() < 0.5 then {"A", "A2", "B", "B2"} else {"B", "B2", "A", "A2"}) do
            Bot.Decide(brains[seat], m, seat)
        end
        Engine.Step(m)
        Engine.Snapshot(m)
        n += 1
    end
    overOk = overOk and m.Over and m.Clock <= 1200
    if m.Winner == "A" then winsA += 1 elseif m.Winner == "B" then winsB += 1 end
    if m.Reason == "Timeout" then timeouts += 1 end
    table.insert(durations, m.Clock / 10)
end
table.sort(durations)
local share = winsA / math.max(1, winsA + winsB)
check(("1 000 matchs 2v2 : tous finis en 120 s au plus ; camp A gagne %.1f %% (aucun camp avantagé)"):format(
    share * 100), overOk and share >= 0.45 and share <= 0.55)
local inRange = 0
for _, d in ipairs(durations) do if d >= 90 then inRange += 1 end end
info(("Durée médiane %.1f s (10 %% sous %.1f s, 90 %% sous %.1f s) ; %d %% au-delà de 90 s, %d %% au temps limite"):format(
    durations[500], durations[100], durations[900], math.round(inRange / 10), math.round(timeouts / 10)))

local summary = ("[COMBAT 2V2 TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
