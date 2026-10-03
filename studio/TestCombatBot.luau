--!nonstrict
--[[ TestCombatBot
     Rôle    : vérifier les bots de l'arène : Elo, équipe miroir, réflexes, jeu, et leurs taux de victoire mesurés
               sur des matchs complets du moteur (E11.4 : 45 % au plus ; tutoriel et garde-fou : jamais).
     Doc     : GAME_MASTER_V2 G5.5, E1, E6, E11.1, E11.4, B4 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot D ; décisions 113,
               123 et 124
     Étape   : 13, lot D
     Dépend  : ServerScriptService.Combat.CombatBot, CombatEngine ; ReplicatedStorage.Config.CreatureConfig,
               ArenaConfig
     Exposé  : exécution manuelle ; aucune écriture de données ; environ 25 s (3 000 matchs simulés)
     Limite  : le « joueur » des mesures est le bot normal sans temps de réflexe (capacité et ultime dès qu'ils sont
               prêts), ou un joueur AFK ; un humain joue autrement. Tirages fixés pour rejouer à l'identique.
]]
local combat = assert(game:GetService("ServerScriptService"):FindFirstChild("Combat"), "Combat absent")
local Bot = require(assert(combat:FindFirstChild("CombatBot"), "CombatBot absent"))
local Engine = require(assert(combat:FindFirstChild("CombatEngine"), "CombatEngine absent"))
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
local function rng(seed) -- tirage dans [0, 1), reproductible
    local state = seed
    return function()
        state = (state * 1103515245 + 12345) % 2147483648
        return state / 2147483648
    end
end
local function entry(id, tier, ranked)
    local s = C:GetCombatStats(id, tier or 1, ranked ~= false)
    return {Id = id, HP = s.HP, ATK = s.ATK, Type = s.Type}
end

-- G5.5 / E6 : Elo − 100 (décision 113).
check("Elo du bot = Elo du joueur − 100", Bot.Elo(1000) == 900 and Bot.Elo(1450) == 1350)

-- Q1 (A) : miroir aux stats B4 intactes ; Q2 (A) : ×0,5 pour les bots faciles.
local mine = {{Id = "noobini", Tier = 1}, {Id = "trippi", Tier = 2}, {Id = "bombardiro", Tier = 5}}
local mirrorOk, easyOk = true, true
local r = rng(7)
for _ = 1, 200 do
    local team = Bot.Team(mine, "Normal", true, r)
    local easy = Bot.Team(mine, "Guard", true, r)
    for slot, creature in ipairs(mine) do
        local src, got, soft = C:Get(creature.Id), C:Get(team[slot].Id), C:Get(easy[slot].Id)
        local stats = C:GetCombatStats(team[slot].Id, creature.Tier, true)
        local softStats = C:GetCombatStats(easy[slot].Id, creature.Tier, true)
        mirrorOk = mirrorOk and got.rarity == src.rarity and got.world == src.world and team[slot].HP == stats.HP
            and team[slot].ATK == stats.ATK and team[slot].Type == stats.Type
        easyOk = easyOk and soft.rarity == src.rarity and easy[slot].HP == math.floor(softStats.HP * 0.5)
            and easy[slot].ATK == math.floor(softStats.ATK * 0.5)
    end
end
check("Miroir : même rareté, même monde, même tier, stats classées B4 intactes (bot normal)", mirrorOk)
check("Bots faciles (tutoriel, garde-fou) : même miroir, stats ×0,5", easyOk and A.Bots.EasyStatMult == 0.5)
local free = Bot.Team({{Id = "noobini", Tier = 3}}, "Normal", false, rng(1))
check("Arène Libre : stats brutes (tier ×10)", free[1].HP == C:GetCombatStats(free[1].Id, 3, false).HP
    and free[1].HP == 3000)
local legendaries = {}
for _, c in ipairs(C.Creatures) do if c.rarity == "Legendary" and c.world == 1 then legendaries[c.id] = 0 end end
for i = 0, 399 do
    local pick = Bot.Team({{Id = "burbaloni", Tier = 1}}, "Normal", true, function() return i / 400 end)[1].Id
    legendaries[pick] += 1
end
local spread = true
for _, n in pairs(legendaries) do spread = spread and n == 100 end
check("Tirage du miroir équitable : chaque Légendaire du monde 1 sort 100 fois sur 400", spread)
local okNil, whyKind = Bot.Team(mine, "Boss", true, rng(1))
local _, whyId = Bot.Team({{Id = "inconnu"}}, "Normal", true, rng(1))
local _, whySize = Bot.Team({mine[1], mine[2], mine[3], mine[1]}, "Normal", true, rng(1))
check("Refus : genre de bot inconnu (BAD_KIND), brainrot inconnu ou 4 brainrots (BAD_TEAM)", okNil == nil
    and whyKind == "BAD_KIND" and whyId == "BAD_TEAM" and whySize == "BAD_TEAM")

-- Jeu du bot.
local function run(match, brains, n)
    local log = {}
    for _ = 1, n do
        for side, brain in pairs(brains) do Bot.Decide(brain, match, side) end
        Engine.Step(match)
        for _, e in ipairs(Engine.Snapshot(match).events) do
            e.at = match.Clock
            table.insert(log, e)
        end
    end
    return log
end
local function firstAbility(reflex)
    local match = Engine.New({entry("noobini")}, {entry("noobini")}, 1)
    for _, e in ipairs(run(match, {B = Bot.NewBrain("Normal", reflex)}, 200)) do
        if e.k == "Ability" and e.s == "B" then return e.at end
    end
end
local instant, slow = firstAbility(0), firstAbility(nil)
check(("Q1 (A) : le bot normal lance sa capacité 2 s après qu'elle est prête (%s s contre %s s)"):format(
    tostring(slow and slow / 10), tostring(instant and instant / 10)), instant ~= nil and slow == instant + 20)
local function firstUltimate(reflex)
    local match = Engine.New({entry("noobini")}, {entry("noobini")}, 1)
    match.Sides.B.Crowd = 1
    for _, e in ipairs(run(match, {B = Bot.NewBrain("Normal", reflex)}, 40)) do
        if e.k == "UltStart" and e.s == "B" then return e.at end
    end
end
local ultNow, ultSlow = firstUltimate(0), firstUltimate(nil)
check("Q1 (A) : et son ultime 2 s après que la foule est pleine (horloge figée dès le lancement)", ultNow == 0
    and ultSlow == 20)
local m = Engine.New({entry("noobini")}, {entry("noobini"), entry("tim_cheese")}, 1)
local passive = run(m, {B = Bot.NewBrain("Tutorial")}, 600)
local quiet = true
for _, e in ipairs(passive) do
    if e.s == "B" and (e.k == "Ability" or e.k == "Switch" or e.k == "UltStart") then quiet = false end
end
check("Q2 (A) : le bot facile ne lance rien (ni capacité, ni switch, ni ultime)", quiet and Bot.NewBrain("Guard").Passive)
m = Engine.New({entry("noobini")}, {entry("tim_cheese")}, 1)
m.Sides.A.Team[1].Stun = 1e9 -- personne ne touche le bot : il reste à 100 % de PV
local held = run(m, {B = Bot.NewBrain("Normal", 0)}, 120)
local healedEarly = false
for _, e in ipairs(held) do if e.k == "Ability" and e.s == "B" then healedEarly = true end end
m.Sides.B.Team[1].HP = 0.5 * m.Sides.B.Team[1].MaxHP
local healLog = run(m, {B = Bot.NewBrain("Normal", 0)}, 1)
check("SOIN gardé au-dessus de 60 % de PV, lancé dessous", not healedEarly and #healLog > 0
    and healLog[1].k == "Ability")
m = Engine.New({entry("noobini")}, {entry("noobini"), entry("tim_cheese"), entry("talpa")}, 1)
m.Sides.B.Team[1].HP = 50
m.Sides.B.Team[2].HP = 200
local sw = run(m, {B = Bot.NewBrain("Normal", 0)}, 1)
local switched
for _, e in ipairs(sw) do if e.k == "Switch" then switched = e end end
check("Switch sous 25 % de PV vers le remplaçant le plus en forme", switched ~= nil and switched.to == 3)

-- E11.4 : taux de victoire mesurés sur des matchs complets.
local world1 = {}
for _, c in ipairs(C.Creatures) do if c.world == 1 then table.insert(world1, c.id) end end
local BEATS = {Salty = "Fruity", Sweet = "Salty", Fruity = "Sweet"} -- type qui bat chaque type
math.randomseed(20261003)
local function measure(kind, player, worstTypes)
    local botScore = 0
    for i = 1, MATCHES do
        if i % 50 == 0 then yield() end
        local creatures, playerTeam = {}, {}
        for slot = 1, 3 do
            creatures[slot] = {Id = world1[math.random(1, #world1)], Tier = 1}
            playerTeam[slot] = entry(creatures[slot].Id)
        end
        local botTeam = Bot.Team(creatures, kind, true, math.random)
        if worstTypes then
            for slot = 1, 3 do botTeam[slot].Type = BEATS[playerTeam[slot].Type] end
        end
        local match = Engine.New(playerTeam, botTeam, math.random(0, 2 ^ 31 - 1))
        local brains = {B = Bot.NewBrain(kind)}
        if player == "auto" then brains.A = Bot.NewBrain("Normal", 0) end
        local steps = 0
        while not match.Over and steps < 5000 do
            if brains.A then Bot.Decide(brains.A, match, "A") end
            Bot.Decide(brains.B, match, "B")
            Engine.Step(match)
            Engine.Snapshot(match)
            steps += 1
        end
        if match.Winner == "B" then botScore += 1 elseif match.Winner == "Draw" then botScore += 0.5 end
    end
    return botScore / MATCHES
end
local normal = measure("Normal", "auto")
check(("E11.4 : bot normal contre le joueur automatique : %.1f %% de victoires (entre 30 et 45 %%)"):format(normal * 100),
    normal >= 0.30 and normal <= 0.45)
info(("Elo − 100 prédit 36,0 %% (FIDE) ; écart mesuré %+.1f points"):format((normal - 0.36) * 100))
local afk = measure("Guard", "afk", true)
check(("E11.4 : garde-fou contre un joueur AFK, pire type sur chaque brainrot : %d victoire(s) du bot sur %d"):format(
    math.round(afk * MATCHES), MATCHES), afk == 0)
local tuto = measure("Tutorial", "auto")
check(("E1 : bot du tutoriel contre le joueur automatique : %d victoire(s) sur %d"):format(math.round(tuto * MATCHES),
    MATCHES), tuto == 0)

local summary = ("[COMBAT BOT TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
