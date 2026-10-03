--!nonstrict
--[[ TestCombatEngine
     Rôle    : vérifier le moteur de combat contre la batterie COMBAT §25.2, E3-E5, B0bis, B5 et les réponses Q1-Q3
               du lot C (étourdissement, vitesse d'attaque, foule de TRALALERO !).
     Doc     : GAME_MASTER_V2 G5.3, G5.6, E3, E4, E5, E12, B0bis, B5 ; PROMPT_EXECUTION_SABL_V4 §25.2 (lot COMBAT),
               §31.13 lot C ; décisions 118 à 122
     Étape   : 13, lot C
     Dépend  : ServerScriptService.Combat.CombatEngine ; ReplicatedStorage.Config.CombatConfig, ArenaConfig
     Exposé  : exécution manuelle (Studio : ServerStorage.Tests par le TestRunner ; hors Studio :
               tools/run_config_tests.py) ; aucune écriture de données
     Limite  : prouve le moteur, pas CombatService : la boucle réelle à 10 Hz, le push unique de CombatSync, la
               déconnexion et le nettoyage de l'arène se testent en Play. Certains cas posent l'état à la main
               (étourdissement permanent, jauge pleine) pour isoler une règle.
]]
local SSS = game:GetService("ServerScriptService")
local combat = assert(SSS:FindFirstChild("Combat"), "ServerScriptService.Combat absent")
local Engine = require(assert(combat:FindFirstChild("CombatEngine"), "CombatEngine absent"))
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local Cb = require(assert(config:FindFirstChild("CombatConfig"), "CombatConfig absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function near(a, b, tol) return type(a) == "number" and math.abs(a - b) <= (tol or 1e-9) end

local function f(id, hp, atk, kind) return {Id = id, HP = hp, ATK = atk, Type = kind} end
local function tank(id, kind) return f(id or "noobini", 1e6, 10, kind or "Salty") end
local function new(teamA, teamB, seed)
    local match, why = Engine.New(teamA, teamB, seed or 12345)
    return assert(match, why)
end
-- n ticks ; chaque événement reçoit l'horloge (en ticks) du Snapshot qui l'a livré.
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
local function pick(log, k, s, src)
    local out = {}
    for _, e in ipairs(log) do
        if e.k == k and (s == nil or e.s == s) and (src == nil or e.src == src) then table.insert(out, e) end
    end
    return out
end
local function times(events)
    local out = {}
    for i, e in ipairs(events) do out[i] = e.at end
    return table.concat(out, ",")
end
local function hold(match, side) match.Sides[side].Team[match.Sides[side].Active].Stun = 1e9 end
local function deepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, v in pairs(a) do if not deepEqual(v, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for key, v in pairs(t) do out[key] = copy(v) end
    return out
end

-- §25.2 : boucle 10 Hz.
local m = new({tank()}, {tank()})
run(m, 100)
check("Boucle 10 Hz : tick 0,1 s, 100 ticks = 10 s", Engine.TickSeconds == 0.1 and Engine.Snapshot(m).t == 10)

-- §25.2 / E3 : auto-attaque toutes les 1,5 s, les deux côtés en même temps.
m = new({f("noobini", 300, 25, "Salty")}, {f("noobini", 300, 25, "Salty")})
local log = run(m, 31)
check("Auto-attaque toutes les 1,5 s : coups à 1,5 et 3,0 s des deux côtés",
    times(pick(log, "Hit", "A")) == "15,30" and times(pick(log, "Hit", "B")) == "15,30")

-- E3 / E12 : variance ±10 % tirée par le serveur, reproductible par la graine.
local lo, hi, sum, n = math.huge, -math.huge, 0, 0
for seed = 1, 40 do
    m = new({f("noobini", 1e9, 10000, "Salty")}, {f("noobini", 1e9, 0, "Salty")}, 1000 + seed)
    hold(m, "B")
    for _, e in ipairs(pick(run(m, 900), "Hit", "A")) do
        local r = e.dmg / 10000
        lo, hi, sum, n = math.min(lo, r), math.max(hi, r), sum + r, n + 1
    end
end
check(("Variance ±10 %% sur %d coups : de %.4f à %.4f, moyenne %.4f"):format(n, lo, hi, sum / n), n == 2400
    and lo >= 0.9 and hi <= 1.1 and lo < 0.905 and hi > 1.095 and near(sum / n, 1, 0.01))
local function damages(seed)
    local match = new({f("noobini", 1e9, 10000, "Salty")}, {f("noobini", 1e9, 10000, "Salty")}, seed)
    local out = {}
    for _, e in ipairs(pick(run(match, 300), "Hit")) do table.insert(out, e.dmg) end
    return table.concat(out, ",")
end
check("Même graine → mêmes dégâts ; autre graine → autres dégâts", damages(777) == damages(777)
    and damages(777) ~= damages(778))

-- B0bis : triangle des types.
local tm = Engine.TypeMultiplier
check("B0bis : SALÉ > SUCRÉ > FRUITÉ > SALÉ, +20 % / −20 %, ×1 entre pareils", near(tm("Salty", "Sweet"), 1.2)
    and near(tm("Sweet", "Salty"), 0.8) and near(tm("Sweet", "Fruity"), 1.2) and near(tm("Fruity", "Sweet"), 0.8)
    and near(tm("Fruity", "Salty"), 1.2) and near(tm("Salty", "Fruity"), 0.8) and tm("Salty", "Salty") == 1
    and tm("Sweet", "Sweet") == 1 and tm("Fruity", "Fruity") == 1)

-- §25.2 / E3 : jauge de capacité 8 s (+ cdPlus de G5.3).
m = new({tank()}, {tank()})
run(m, 79)
local ok1, why1 = Engine.Activate(m, "A")
run(m, 1)
local ok2 = Engine.Activate(m, "A")
check("Jauge de capacité : refusée à 7,9 s (CHARGE_NOT_FULL), prête à 8,0 s, vidée", ok1 == false
    and why1 == "CHARGE_NOT_FULL" and ok2 == true and m.Sides.A.Charge == 0)
m = new({tank("bombombini")}, {tank()})
run(m, 99)
ok1 = Engine.Activate(m, "A")
run(m, 1)
ok2 = Engine.Activate(m, "A")
check("Bomb Barrage (cdPlus 2) : jauge en 10 s", ok1 == false and ok2 == true)

-- §25.2 / E4 : switch, recharge de 5 s.
m = new({tank(), tank("tim_cheese"), tank("talpa")}, {tank()})
ok1 = Engine.Switch(m, "A", 2)
local ok3, why3 = Engine.Switch(m, "A", 1)
run(m, 49)
local ok4, why4 = Engine.Switch(m, "A", 1)
run(m, 1)
local ok5 = Engine.Switch(m, "A", 3)
check("Switch : permis, puis refusé 4,9 s (SWITCH_COOLDOWN), permis à 5,0 s", ok1 and not ok3
    and why3 == "SWITCH_COOLDOWN" and not ok4 and why4 == "SWITCH_COOLDOWN" and ok5 and m.Sides.A.Active == 3)
local _, whyActive = Engine.Switch(m, "A", 3)
local badSlots = true
for _, slot in ipairs({0, 4, 1.5, "2", 0 / 0, math.huge}) do
    local ok, why = Engine.Switch(m, "A", slot)
    badSlots = badSlots and ok == false and why == "BAD_SLOT"
end
local okNil, whyNil = Engine.Switch(m, "A", nil)
check("Switch : ALREADY_ACTIVE, et BAD_SLOT pour 0, 4, 1,5, « 2 », NaN, ∞, nil", whyActive == "ALREADY_ACTIVE"
    and badSlots and okNil == false and whyNil == "BAD_SLOT")
m = new({tank(), f("tim_cheese", 1, 10, "Salty"), tank("talpa")}, {f("noobini", 1e6, 100, "Salty")})
Engine.Switch(m, "A", 2)
run(m, 50)
local _, whyDead = Engine.Switch(m, "A", 2)
check("Switch vers un brainrot KO : DEAD", whyDead == "DEAD" and m.Sides.A.Active == 3)

-- §25.2 / E3 : soin du banc +2 %/s, jamais sur l'actif.
m = new({f("noobini", 300, 10, "Salty"), f("tim_cheese", 300, 10, "Salty")}, {tank()})
hold(m, "B")
m.Sides.A.Team[1].HP, m.Sides.A.Team[2].HP = 200, 100
run(m, 10)
local benchHP = m.Sides.A.Team[2].HP
m.Sides.A.Team[2].HP = 299
run(m, 10)
check("Banc : +2 %/s (100 → 106 en 1 s), plafonné aux PV max ; l'actif ne se soigne pas", near(benchHP, 106, 1e-6)
    and m.Sides.A.Team[2].HP == 300 and m.Sides.A.Team[1].HP == 200)

-- §25.2 / E3 : jauge de foule.
m = new({tank()}, {tank()})
hold(m, "B")
run(m, 15)
check("Foule : +4 % au coup porté, +2 % au coup encaissé", near(m.Sides.A.Crowd, 0.04) and near(m.Sides.B.Crowd, 0.02))
m.Sides.A.Crowd = 0.99
run(m, 15)
check("Foule plafonnée à 100 %", m.Sides.A.Crowd == 1)
m = new({f("noobini", 1e6, 0, "Salty")}, {tank()})
local zero = pick(run(m, 15), "Hit", "A")[1]
check("Un coup porte toujours au moins 1 dégât (ATK 0)", zero ~= nil and zero.dmg == 1)

-- §25.2 / E5 : ultime.
m = new({f("noobini", 1e6, 100, "Salty")}, {f("chicleteira", 1e6, 100, "Sweet")})
m.Sides.A.Crowd = 0.99
local okNo, whyNo = Engine.Ultimate(m, "A")
m.Sides.A.Crowd = 1
local okUlt = Engine.Ultimate(m, "A")
Engine.Snapshot(m)
local clock = m.Clock
log = run(m, 29)
local _, whyFrozenA = Engine.Activate(m, "B")
local _, whyFrozenS = Engine.Switch(m, "B", 1)
local frozenOk = #pick(log, "Hit") == 0 and m.Clock == clock and whyFrozenA == "FROZEN" and whyFrozenS == "FROZEN"
log = run(m, 1)
local ult = pick(log, "Hit", "A", "Ultimate")[1]
check("Ultime refusé à 99 % de foule (CROWD_NOT_FULL), accepté à 100 %, foule remise à 0", okNo == false
    and whyNo == "CROWD_NOT_FULL" and okUlt == true and m.Sides.A.Crowd == 0)
check("Ultime : match figé 3 s (horloge des 90 s comprise), actions refusées (FROZEN)", frozenOk and ult ~= nil
    and ult.at == clock and m.Clock == clock)
check("Ultime : 3 × ATK puis type, sans variance (SALÉ 100 sur SUCRÉ = 360)", ult ~= nil and ult.dmg == 360
    and near(ult.tm, 1.2))
check("Ultime SALÉ : −25 % ATK adverse 5 s ; l'ultime ne rapporte pas de foule",
    m.Sides.B.Team[1].AtkDown.Value == 0.25 and m.Sides.B.Team[1].AtkDown.Left == 50 and m.Sides.A.Crowd == 0
    and m.Sides.B.Crowd == 0)
local nextB = pick(run(m, 15), "Hit", "B", "Auto")[1]
check("ATK réduite : le coup suivant de l'adversaire vaut 75 % (100 × 0,75 × 0,8 ± 10 %)", nextB ~= nil
    and nextB.dmg >= 54 and nextB.dmg <= 66)
m = new({f("chicleteira", 1000, 10, "Sweet"), f("chicleteira", 1000, 10, "Sweet"), f("chicleteira", 1000, 10, "Sweet")},
    {tank()})
m.Sides.A.Team[1].HP, m.Sides.A.Team[2].HP = 100, 500
m.Sides.A.Team[3].HP, m.Sides.A.Team[3].Alive = 0, false
m.Sides.A.Crowd = 1
Engine.Ultimate(m, "A")
run(m, 30)
check("Ultime SUCRÉ : +30 % des PV max à chaque brainrot vivant, aucun KO relevé", near(m.Sides.A.Team[1].HP, 400, 1e-6)
    and near(m.Sides.A.Team[2].HP, 800, 1e-6) and m.Sides.A.Team[3].HP == 0 and not m.Sides.A.Team[3].Alive)
m = new({f("fluriflura", 1e6, 10, "Fruity")}, {tank()})
m.Sides.A.Crowd = 1
Engine.Ultimate(m, "A")
run(m, 30)
check("Ultime FRUITÉ : étourdit 2,5 s", m.Sides.B.Team[1].Stun == 25)
m = new({f("noobini", 1e6, 100, "Salty")}, {tank("boneca")})
m.Sides.B.Team[1].Shield = 1
m.Sides.A.Crowd = 1
Engine.Ultimate(m, "A")
ult = pick(run(m, 30), "Hit", "A", "Ultimate")[1]
check("Le bouclier encaisse aussi l'ultime", ult ~= nil and ult.abs == true and m.Sides.B.Team[1].HP == 1e6
    and m.Sides.B.Team[1].Shield == 0)

-- §25.2 / E3 : temps limite à 90 s, part de PV de toute l'équipe.
local function tanks() return {f("noobini", 1e6, 1, "Salty"), f("tim_cheese", 1e6, 1, "Salty"),
    f("talpa", 1e6, 1, "Salty")} end
m = new(tanks(), tanks())
run(m, 899)
local before = m.Over
run(m, 1)
check("Temps limite : rien à 89,9 s, fin à 90 s ; parts égales → match nul", before == false and m.Over
    and m.Reason == "Timeout" and m.Winner == "Draw" and m.Clock == 900)
m = new(tanks(), tanks())
m.Sides.B.Team[1].HP = 5e5
run(m, 900)
check("Temps limite : la plus forte part de PV gagne", m.Over and m.Reason == "Timeout" and m.Winner == "A")
m = new(tanks(), tanks())
run(m, 100)
m.Sides.A.Crowd = 1
Engine.Ultimate(m, "A")
local steps = 100
while not m.Over and steps < 2000 do
    Engine.Step(m)
    steps += 1
end
check("Le gel de l'ultime ne compte pas dans les 90 s (930 ticks au total)", steps == 930 and m.Clock == 900)

-- E3 : KO, ragdoll 1,5 s, remplaçant suivant, 0,5 s d'invulnérabilité.
m = new({f("noobini", 1e6, 1e6, "Salty")}, {f("noobini", 100, 1, "Salty"), f("tim_cheese", 100, 1, "Salty"),
    f("talpa", 100, 1, "Salty")})
log = run(m, 200)
local enters = pick(log, "Enter", "B")
check("KO à 1,5 s, remplaçant à 3,0 s (ragdoll 1,5 s), dans l'ordre 2 puis 3", times(pick(log, "KO", "B")) == "15,45,75"
    and times(enters) == "30,60" and enters[1].slot == 2 and enters[2].slot == 3)
check("Coup sur un remplaçant qui entre : esquivé (0,5 s d'invulnérabilité)", times(pick(log, "Dodge", "A")) == "30,60")
check("Équipe vide : victoire par KO, le match s'arrête", m.Over and m.Winner == "A" and m.Reason == "KO"
    and m.Clock == 75)
local function firstBlowAfterSwitchAt(tick)
    local match = new({tank()}, {tank(), tank("tim_cheese")})
    run(match, tick)
    Engine.Switch(match, "B", 2)
    for _, e in ipairs(run(match, 15 - tick)) do
        if e.s == "A" and (e.k == "Dodge" or e.k == "Hit") then return e.k .. "@" .. e.at end
    end
    return "rien"
end
check("Switch à 1,0 s : le coup de 1,5 s est esquivé (0,5 s pile) ; switch à 0,9 s : il porte",
    firstBlowAfterSwitchAt(10) == "Dodge@15" and firstBlowAfterSwitchAt(9) == "Hit@15")
m = new({f("noobini", 1e6, 1e6, "Salty")}, {f("noobini", 1, 1, "Salty"), f("tim_cheese", 1, 1, "Salty")})
m.Sides.A.Team[1].SpeedUp.Value, m.Sides.A.Team[1].SpeedUp.Left = 0.5, 1e9
log = run(m, 40)
check("Attaque prête pendant le ragdoll adverse : elle attend le remplaçant (esquivée à 2,5 s, KO à 3,4 s)",
    times(pick(log, "KO", "B")) == "10,34" and times(pick(log, "Dodge", "A")) == "25")
m = new({f("noobini", 10, 1000, "Salty")}, {f("noobini", 10, 1000, "Salty")})
run(m, 15)
check("KO simultanés des deux derniers brainrots : match nul", m.Over and m.Winner == "Draw" and m.Reason == "KO")

-- Q1 (A) : l'étourdi n'attaque plus, ne lance ni capacité ni ultime, mais peut switcher.
m = new({f("fluriflura", 1e6, 10, "Fruity")}, {tank()})
run(m, 80)
local okStun = Engine.Activate(m, "A")
log = run(m, 40)
check("Pollen Dodo : étourdit 2 s ; l'attaque attendue à 9,0 s tombe à 11,0 s", okStun
    and times(pick(log, "Hit", "B", "Auto")) == "110")
m = new({f("fluriflura", 1e6, 10, "Fruity")}, {tank(), tank("tim_cheese")})
run(m, 80)
Engine.Activate(m, "A")
m.Sides.B.Crowd = 1
local okA, whyA = Engine.Activate(m, "B")
local okU, whyU = Engine.Ultimate(m, "B")
local okS = Engine.Switch(m, "B", 2)
check("Q1 (A) : étourdi → capacité et ultime refusés (STUNNED), switch permis, remplaçant libre", okA == false
    and whyA == "STUNNED" and okU == false and whyU == "STUNNED" and okS and m.Sides.B.Team[2].Stun == 0)

-- Q2 (A) : vitesse +30 % = 30 % d'attaques en plus (1,5 s / 1,3).
m = new({tank()}, {tank()})
hold(m, "B")
m.Sides.A.Team[1].SpeedUp.Value, m.Sides.A.Team[1].SpeedUp.Left = 0.3, 1e9
check("Q2 (A) : +30 % de vitesse → 26 attaques en 30 s au lieu de 20 (1,05 s : 28 ; 1,2 s : 25)",
    #pick(run(m, 300), "Hit", "A") == 26)
m = new({tank("cappuccino")}, {tank()})
run(m, 80)
Engine.Activate(m, "A")
check("Espresso Rush : vitesse +30 % pendant 5 s", m.Sides.A.Team[1].SpeedUp.Value == 0.3
    and m.Sides.A.Team[1].SpeedUp.Left == 50)

-- Q3 (A) : TRALALERO ! ajoute 25 points de foule tout de suite.
m = new({tank("tralalero")}, {tank()})
hold(m, "B")
run(m, 80)
local crowdBefore = m.Sides.A.Crowd
Engine.Activate(m, "A")
local burst = pick(run(m, 1), "Hit", "A", "Ability")[1]
check("Q3 (A) : TRALALERO ! → foule 0,20 + 0,04 (coup) + 0,25 = 0,49", near(crowdBefore, 0.2)
    and near(m.Sides.A.Crowd, 0.49))
check("BURST ×4 : dégâts de 36 à 44 pour 10 d'ATK", burst ~= nil and burst.dmg >= 36 and burst.dmg <= 44)

-- B5 : bouclier, renvoi, soins, précision, ATK.
m = new({tank("boneca")}, {f("noobini", 1e6, 100, "Salty")})
run(m, 80)
Engine.Activate(m, "A")
local hp0 = m.Sides.A.Team[1].HP
log = pick(run(m, 40), "Hit", "B", "Auto")
check("Tire Bounce : absorbe 2 coups, le 3e porte", #log == 3 and log[1].abs and log[2].abs and not log[3].abs
    and m.Sides.A.Team[1].HP == hp0 - log[3].dmg)
m = new({tank("lirili")}, {f("noobini", 1e6, 100, "Salty")})
run(m, 80)
Engine.Activate(m, "A")
hold(m, "A") -- seuls les renvois touchent B
local hpB = m.Sides.B.Team[1].HP
log = pick(run(m, 60), "Hit", "B", "Auto")
check("Cactus Spikes : renvoie 25 % du coup pendant 5 s, même absorbé", #log == 4 and log[1].abs and log[2].abs
    and log[1].ref == math.round(log[1].dmg * 0.25) and log[3].ref == math.round(log[3].dmg * 0.25)
    and log[4].ref == 0 and m.Sides.B.Team[1].HP == hpB - log[1].ref - log[2].ref - log[3].ref)
m = new({f("tim_cheese", 300, 10, "Salty")}, {tank()})
hold(m, "B")
run(m, 80)
m.Sides.A.Team[1].HP = 100
Engine.Activate(m, "A")
local healed = m.Sides.A.Team[1].HP
m.Sides.A.Charge, m.Sides.A.Team[1].HP = 1, 290
Engine.Activate(m, "A")
check("Cheese Melt : +40 % des PV max (100 → 220), plafonné (290 → 300)", near(healed, 220, 1e-6)
    and m.Sides.A.Team[1].HP == 300)
m = new({tank("glorbo")}, {tank()})
hold(m, "B")
run(m, 80)
local g = m.Sides.A.Team[1]
g.AtkDown.Value, g.AtkDown.Left, g.Blind.Value, g.Blind.Left = 0.25, 30, 0.15, 30
Engine.Activate(m, "A")
check("Juice Flood : soigne et purge −ATK et précision", g.AtkDown.Left == 0 and g.Blind.Left == 0)
m = new({tank("la_grande")}, {tank()})
run(m, 80)
Engine.Activate(m, "A")
check("La Combinazione : +20 % ATK pendant 5 s", m.Sides.A.Team[1].AtkUp.Value == 0.2
    and m.Sides.A.Team[1].AtkUp.Left == 50)
m = new({tank("pipi_kiwi")}, {tank()})
run(m, 80)
Engine.Activate(m, "A")
check("Kiwi Splash : −10 % ATK adverse pendant 3 s", m.Sides.B.Team[1].AtkDown.Value == 0.1
    and m.Sides.B.Team[1].AtkDown.Left == 30)
m = new({f("pipi_kiwi", 1e6, 10, "Salty")}, {tank()})
run(m, 80)
Engine.Activate(m, "A")
m.Sides.A.Crowd = 1
Engine.Ultimate(m, "A")
run(m, 30)
local down = m.Sides.B.Team[1].AtkDown
local stacked = down.Value == 0.25 and down.Left == 50
m.Sides.A.Charge = 1
Engine.Activate(m, "A")
check("Un même effet ne se cumule pas : −10 % puis −25 % → −25 % pendant 5 s, puis −10 % ne l'efface pas",
    stacked and down.Value == 0.25 and down.Left == 50)
m = new({tank("blueberrini")}, {tank()})
run(m, 80)
Engine.Activate(m, "A")
check("Ink Blast : précision adverse −15 % pendant 3 s", m.Sides.B.Team[1].Blind.Value == 0.15
    and m.Sides.B.Team[1].Blind.Left == 30)
local misses, swings = 0, 0
for seed = 1, 40 do
    m = new({tank()}, {tank()}, 5000 + seed)
    hold(m, "B")
    m.Sides.A.Team[1].Blind.Value, m.Sides.A.Team[1].Blind.Left = 0.15, 1e9
    log = run(m, 900)
    misses += #pick(log, "Miss", "A")
    swings += #pick(log, "Miss", "A") + #pick(log, "Hit", "A")
end
check(("Précision −15 %% : %d ratés sur %d attaques (%.1f %%)"):format(misses, swings, misses / swings * 100),
    swings == 2400 and near(misses / swings, 0.15, 0.03))
m = new({tank()}, {tank()})
m.Sides.A.Team[1].Blind.Value, m.Sides.A.Team[1].Blind.Left = 1, 1e9
m.Sides.A.Crowd = 1
Engine.Ultimate(m, "A")
check("L'ultime ne rate jamais, même aveuglé", #pick(run(m, 30), "Hit", "A", "Ultimate") == 1)

-- Sans cible : capacité offensive et ultime refusés, jauges gardées ; soin permis.
m = new({f("noobini", 1e6, 1e6, "Salty")}, {f("noobini", 1, 1, "Salty"), f("tim_cheese", 1, 1, "Salty")})
run(m, 16)
m.Sides.A.Charge, m.Sides.A.Crowd = 1, 1
local _, whyNT = Engine.Activate(m, "A")
local _, whyNU = Engine.Ultimate(m, "A")
check("Adversaire en ragdoll : BURST et ultime refusés (NO_TARGET), jauges gardées", whyNT == "NO_TARGET"
    and whyNU == "NO_TARGET" and m.Sides.A.Charge == 1 and m.Sides.A.Crowd == 1)
local _, whyOwn = Engine.Activate(m, "B")
local _, whyOwnS = Engine.Switch(m, "B", 2)
check("Son propre brainrot en ragdoll : NO_ACTIVE", whyOwn == "NO_ACTIVE" and whyOwnS == "NO_ACTIVE")
run(m, 14)
local _, whyInv = Engine.Activate(m, "A")
m = new({f("tim_cheese", 300, 1e6, "Salty")}, {f("noobini", 1, 1, "Salty"), tank()})
run(m, 16)
m.Sides.A.Charge, m.Sides.A.Team[1].HP = 1, 100
local okHeal = Engine.Activate(m, "A")
check("Remplaçant invulnérable : BURST refusé (NO_TARGET) ; soin permis sans cible", whyInv == "NO_TARGET" and okHeal)

-- E1 / E12 : abandon = défaite ; le moteur ne touche à aucune créature.
local teamA, teamB = {tank(), tank("tim_cheese"), tank("talpa")}, {tank(), tank("trippi"), tank("boneca")}
local savedA, savedB = copy(teamA), copy(teamB)
m = new(teamA, teamB)
run(m, 200)
local okF = Engine.Forfeit(m, "A")
local clockF = m.Clock
run(m, 10)
local _, whyOver = Engine.Activate(m, "B")
local _, whyF2 = Engine.Forfeit(m, "B")
check("Abandon : défaite immédiate, plus rien ne bouge, actions refusées (MATCH_OVER)", okF and m.Over
    and m.Winner == "B" and m.Reason == "Forfeit" and m.Clock == clockF and whyOver == "MATCH_OVER"
    and whyF2 == "MATCH_OVER")
check("Aucune créature touchée : les équipes reçues sont intactes après le match", deepEqual(teamA, savedA)
    and deepEqual(teamB, savedB))
m = new({tank()}, {tank()})
m.Sides.A.Crowd = 1
Engine.Ultimate(m, "A")
Engine.Forfeit(m, "B")
local resultF = Engine.Result(m)
check("Abandon pendant le gel d'un ultime : le gel s'arrête, bilan rendu", m.Freeze == 0 and resultF.Winner == "A"
    and resultF.Reason == "Forfeit" and resultF.A.Ultimates == 1)

-- G5.6 / E12 : une charge utile CombatSync par tick, sans graine.
m = new({tank()}, {tank()}, 2718281)
run(m, 15)
Engine.Activate(m, "A")
local snap = Engine.Snapshot(m)
local fields = true
for _, key in ipairs({"hpA", "hpB", "activeA", "activeB", "chargeA", "chargeB", "crowdA", "crowdB", "switchCdA",
    "switchCdB", "events"}) do
    fields = fields and snap[key] ~= nil
end
local leak = false
local function scan(t)
    for key, v in pairs(t) do
        if tostring(key):lower():find("seed") or v == 2718281 then leak = true end
        if type(v) == "table" then scan(v) end
    end
end
for _ = 1, 300 do Engine.Step(m); scan(Engine.Snapshot(m)) end
check("CombatSync : champs de G5.6 (+ recharge du switch des 2 côtés), événements vidés à chaque envoi",
    fields and #Engine.Snapshot(m).events == 0)
check("E12 : ni la graine ni aucun tirage à venir dans CombatSync", not leak)

-- Entrées refusées.
local badTeams = {{}, {tank(), tank(), tank(), tank()}, {f("noobini", 0, 10, "Salty")}, {f("noobini", 0 / 0, 10, "Salty")},
    {f("noobini", 100, -1, "Salty")}, {f("noobini", 100, 10, "Spicy")}, {f(12, 100, 10, "Salty")}, {"noobini"}}
local teamsOk = true
for _, team in ipairs(badTeams) do
    local match, why = Engine.New(team, {tank()}, 1)
    teamsOk = teamsOk and match == nil and why == "BAD_TEAM"
end
local seedsOk = true
for _, seed in ipairs({-1, 2 ^ 32, 0.5, 0 / 0, "1", math.huge}) do
    local match, why = Engine.New({tank()}, {tank()}, seed)
    seedsOk = seedsOk and match == nil and why == "BAD_SEED"
end
m = new({tank()}, {tank()})
local _, whySide = Engine.Activate(m, "C")
local _, whySideNil = Engine.Ultimate(m, nil)
check("Équipes refusées (vide, 4 brainrots, PV 0 ou NaN, ATK < 0, type inconnu, mauvais identifiant)", teamsOk)
check("Graines refusées (< 0, ≥ 2^32, décimale, NaN, texte, ∞) ; côté inconnu : BAD_SIDE", seedsOk
    and whySide == "BAD_SIDE" and whySideNil == "BAD_SIDE")

-- G5.3 : chaque option de capacité a un effet dans le moteur, et chacune des 54 capacités se lance.
local allowed = {
    Burst = {atkDown = true, blind = true, speedUp = true, crowdBoost = true, shake = true, duration = true},
    Heal = {atkUp = true, speedUp = true, cleanse = true, duration = true},
    Shield = {reflect = true, duration = true},
    Control = {},
}
local timed = {atkDown = true, blind = true, speedUp = true, atkUp = true, reflect = true}
local optionsOk, count, launched = true, 0, 0
for id, ability in pairs(Cb.Abilities) do
    count += 1
    for key, value in pairs(ability) do
        local base = key == "name" or key == "kind" or key == "power" or key == "cdPlus"
        optionsOk = optionsOk and (base or (allowed[ability.kind] and allowed[ability.kind][key]) == true)
        if timed[key] then optionsOk = optionsOk and type(value) == "number" and type(ability.duration) == "number" end
    end
    local match = new({tank(id)}, {tank()})
    match.Sides.A.Charge = 1
    local ok, okLaunch = pcall(Engine.Activate, match, "A")
    if ok and okLaunch and match.Sides.A.Abilities == 1 then launched += 1 end
end
check(("G5.3 : %d capacités, toutes leurs options traitées par le moteur"):format(count), count == 54 and optionsOk)
check(("Les %d capacités se lancent sans erreur"):format(launched), launched == 54)

local summary = ("[COMBAT ENGINE TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
