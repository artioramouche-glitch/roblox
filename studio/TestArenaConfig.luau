--!nonstrict
--[[ TestArenaConfig
     Rôle    : vérifier EloUtil (G5.4, recopié tel quel) et ArenaConfig : durées du match, tokens, rangs, saisons,
               boutique, tournoi et heure de Paris.
     Doc     : GAME_MASTER_V2 G5.4, G5.5, G5.6, E1, E3, E5, E6, E7, E8, E9, C7, E2 ; PROMPT_EXECUTION_SABL_V4 §25.2
               (lot ELO), §31.13, §31.14 ; Q1-Q3 de l'étape 14
     Étape   : 14 (configuration) ; durées du match à l'étape 13, lot C ; file et bots au lot D
     Dépend  : ReplicatedStorage.Shared.EloUtil ; ReplicatedStorage.Config.ArenaConfig, EggConfig
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : Q1 (option A) : le résultat d'un match se passe en nombre (1, 0, 0,5) comme le veut G5.4 ; l'appel
               booléen du §25.2 est vérifié comme refusé. Les instants de référence viennent du fuseau
               Europe/Paris de Python (zoneinfo), pas d'ArenaConfig.
]]
local RS = game:GetService("ReplicatedStorage")
local config = assert(RS:FindFirstChild("Config"), "Config absent")
local shared = assert(RS:FindFirstChild("Shared"), "Shared absent")
local Elo = require(assert(shared:FindFirstChild("EloUtil"), "EloUtil absent"))
local A = require(assert(config:FindFirstChild("ArenaConfig"), "ArenaConfig absent"))
local E = require(assert(config:FindFirstChild("EggConfig"), "EggConfig absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- G5.4 / E6 : K = 32, formule FIDE.
local a, b = Elo.Calculate(1000, 1000, 1)
check("Elo 1000 contre 1000, victoire : 1016 / 984", a == 1016 and b == 984)
a, b = Elo.Calculate(1000, 1000, 0)
check("Elo 1000 contre 1000, défaite : 984 / 1016", a == 984 and b == 1016)
a, b = Elo.Calculate(1000, 1000, 0.5)
check("Elo nul à égalité : inchangé", a == 1000 and b == 1000)
local bounded = true
for _, case in ipairs({{1000, 1000}, {1200, 1000}, {1000, 1400}, {1800, 1810}}) do
    for _, score in ipairs({1, 0}) do
        local ra, rb = Elo.Calculate(case[1], case[2], score)
        bounded = bounded and math.abs(ra - case[1]) <= 32 and math.abs(rb - case[2]) <= 32
            and math.abs((ra + rb) - (case[1] + case[2])) < 1e-9
    end
end
check("§25.2 : variation ≤ 32 et somme conservée (4 cas × victoire/défaite)", bounded)
check("Q1 : l'appel booléen du §25.2 est refusé par G5.4", not pcall(Elo.Calculate, 1000, 1000, true))
local ranks = {{999, "Bois", 2}, {1000, "Bronze", 3}, {1199, "Bronze", 3}, {1200, "Argent", 4}, {1399, "Argent", 4},
    {1400, "Or", 5}, {1600, "Platine", 6}, {1800, "Diamant", 7}, {1999, "Diamant", 7}, {2000, "BrainrotMaster", 8}}
local rankOk = true
for _, r in ipairs(ranks) do
    local id, index = Elo.GetRank(r[1])
    rankOk = rankOk and id == r[2] and index == r[3] and A.RankLabels[id] ~= nil
end
check("E7 : paliers des rangs (999 Bois … 2000 Brainrot Master) et libellés", rankOk
    and A.RankLabels.BrainrotGod == "Brainrot God")
check("E7 / §31.14 : reset souple 1600 → 1500, 1200 → 1200, 800 → 900", Elo.SoftReset(1600) == 1500
    and Elo.SoftReset(1200) == 1200 and Elo.SoftReset(800) == 900)

-- C7 / E2 : tokens.
local tk = A.Tokens
check("E2 : 1v1 25 / 8, 2v2 35 / 12, +2 par minute", tk.Ranked1v1.Win == 25 and tk.Ranked1v1.Loss == 8
    and tk.Ranked2v2.Win == 35 and tk.Ranked2v2.Loss == 12 and tk.PerMinutePlayed == 2)
check("E2 : Arène Libre, 5 tokens max par 15 min", tk.FreeArenaMax == 5 and tk.FreeArenaWindow == 900)

-- E7 : récompenses de saison.
local sr = A.SeasonRewards
check("E7 : Or 1, Platine 2, Diamant 3 œufs Mythiques", sr.Or.Eggs.egg_mythic == 1 and sr.Platine.Eggs.egg_mythic == 2
    and sr.Diamant.Eggs.egg_mythic == 3 and E:Get("egg_mythic") ~= nil)
check("E7 : Master = 1 God garanti ; top 1 = skin doré, titre, statue", sr.BrainrotMaster.Rarity == "God"
    and sr.BrainrotGod.Skin == "SkinChampion" and sr.BrainrotGod.Title == "Brainrot God" and sr.BrainrotGod.Statue
    and A.GetShopItem(sr.BrainrotGod.Skin) ~= nil and sr.Bronze == nil and sr.Argent == nil)

-- E8 : boutique du Colisée.
local prices = {EggColisee = 500, SkinChampion = 1200, TrailFire = 400, TrailLightning = 400, TrailGalaxy = 400,
    PoseDance1 = 250, PoseDance2 = 250, PoseDance3 = 250, LoadoutB = 800, IncomeBoost = 100, TrainingRing = 600}
local shopOk, n = true, 0
for key, price in pairs(prices) do
    n += 1
    local item = A.GetShopItem(key)
    shopOk = shopOk and item ~= nil and item.Price == price
end
check("E8 : 7 articles (3 trails et 3 poses), prix exacts", shopOk and n == 11 and #A.Shop == 11)
check("Q2 : Œuf Colisée = pool et odds d'egg_golden", A.GetShopItem("EggColisee").Egg == "egg_golden"
    and E:Get("egg_golden") ~= nil)
local boost, ring = A.GetShopItem("IncomeBoost"), A.GetShopItem("TrainingRing")
check("E8 : boost +20 % pendant 30 min ; anneau +1, niveau 3 au plus par la boutique", boost.IncomeMult == 1.2
    and boost.Seconds == 1800 and ring.TrainingRing == 1 and ring.MaxLevel == 3)
check("E8 : cosmétiques et 2e loadout achetés une seule fois", A.GetShopItem("TrailGalaxy").Once
    and A.GetShopItem("PoseDance2").Once and A.GetShopItem("LoadoutB").Once and not A.GetShopItem("EggColisee").Once)

-- E9 : tournoi.
local t = A.Tournament
check("E9 : samedi 17:30 / 17:45 / 18:30", t.Weekday == 6 and t.RegistrationAt == 63000 and t.BracketAt == 63900
    and t.EndAt == 66600)
check("E9 : Elo ≥ 1100, 8 ou 16 joueurs, pari de 50 double ou rien", t.MinElo == 1100 and t.Sizes[1] == 8
    and t.Sizes[2] == 16 and t.Bet == 50 and t.BetPayout == 2)
local rw = t.Rewards
check("E9 : top 8 300 ; top 4 800 + 1 œuf ; finaliste 1500 + 2 ; champion 3000 + God + titre 7 j",
    rw.Top8.ArenaTokens == 300 and rw.Top4.ArenaTokens == 800 and rw.Top4.Eggs.egg_mythic == 1
    and rw.Finalist.ArenaTokens == 1500 and rw.Finalist.Eggs.egg_mythic == 2 and rw.Champion.ArenaTokens == 3000
    and rw.Champion.Rarity == "God" and rw.Champion.Title == "Champion de la Semaine" and rw.Champion.TitleDays == 7)

-- Heure de Paris : instants de référence calculés par zoneinfo (Europe/Paris).
local offsets = {{1774745999, 3600}, {1774746000, 7200}, {1792889999, 7200}, {1792890000, 3600},
    {1806195600, 7200}, {1824944400, 3600}, {1782907200, 7200}, {1798200000, 3600}}
local offOk = true
for _, o in ipairs(offsets) do offOk = offOk and A.ParisOffset(o[1]) == o[2] end
check("Paris : passages à l'heure d'été et d'hiver 2026-2027 (01:00 UTC pile)", offOk)

local function tour(now, phase, reg)
    local p, r, b, f = A.TournamentAt(now)
    return p == phase and r == reg and b == reg + 900 and f == reg + 3600
end
local SAT1 = 1791041400 -- samedi 3 octobre 2026, 17:30 à Paris (UTC+2)
check("Tournoi : vendredi midi → prochain samedi 17:30 Paris (15:30 UTC)", tour(1790899200 + 43200, "None", SAT1))
check("Tournoi : 17:29:59 → pas encore", tour(SAT1 - 1, "None", SAT1))
check("Tournoi : 17:30 → inscription", tour(SAT1, "Registration", SAT1))
check("Tournoi : 17:45 → bracket", tour(SAT1 + 900, "Bracket", SAT1))
check("Tournoi : 18:30 → samedi suivant", tour(SAT1 + 3600, "None", 1791646200))
check("Tournoi : dimanche → samedi suivant", tour(SAT1 + 86400, "None", 1791646200))
check("Tournoi : 31 octobre 2026, heure d'hiver → 16:30 UTC", tour(1793464200, "Registration", 1793464200))
check("Tournoi : 27 mars 2027, encore l'hiver (le passage a lieu le dimanche)", tour(1806165000 - 3600, "None", 1806165000))
check("Tournoi : 3 avril 2027, heure d'été", tour(1806165000 + 3600, "None", 1806766200))

local function season(now, id, start, finish)
    local i, s, f = A.SeasonAt(now)
    return i == id and s == start and f == finish
end
check("Saison d'octobre 2026 : 1er à 00:00 Paris → 1er novembre 00:00", season(SAT1, 2026 * 12 + 9, 1790805600, 1793487600))
check("30 septembre 23:59:59 Paris : saison de septembre", season(1790805600 - 1, 2026 * 12 + 8, 1788213600, 1790805600))
check("Décembre 2026 → janvier 2027", season(1796079600, 2026 * 12 + 11, 1796079600, 1798758000))
check("Janvier 2027", season(1798758000, 2027 * 12, 1798758000, 1801436400))

-- G5.6 10 Hz ; E1 / G5.5 3 brainrots ; E3 ragdoll 1,5 s ; E5 cinématique 3 s.
local m = A.Match
check("Match : tick 0,1 s, équipes de 3, ragdoll 1,5 s, ultime figé 3 s, gelé", m.TickSeconds == 0.1
    and m.TeamSize == 3 and m.RagdollSeconds == 1.5 and m.UltimateFreezeSeconds == 3 and table.isfrozen(m))
-- G5.5 / E1 / E6 : file ; E6 / E11.4 / décisions 113, 123-125 : bots et abandon.
local mm, bots = A.Matchmaking, A.Bots
check("File : niveau 5, passage toutes les 5 s, ±150 +50/20 s jusqu'à ±400, bot proposé à 30 s", mm.MinLevel == 5
    and mm.TickSeconds == 5 and mm.BaseRange == 150 and mm.RangeStep == 50 and mm.RangeStepSeconds == 20
    and mm.MaxRange == 400 and mm.BotOfferSeconds == 30 and table.isfrozen(mm))
check("Bots : Elo −100, réflexes 2 s, faciles ×0,5, 3 matchs de tutoriel, garde-fou après 3 défaites",
    bots.EloOffset == -100 and bots.ReflexSeconds == 2 and bots.EasyStatMult == 0.5 and bots.TutorialMatches == 3
    and bots.GuardLossStreak == 3 and table.isfrozen(bots))
check("Q3 du lot D : abandon = 0 token en 1v1 et 2v2", A.Tokens.Ranked1v1.Forfeit == 0 and A.Tokens.Ranked2v2.Forfeit == 0)
check("Étape 14 : tournoi annulé sous 4 inscrits (Q1 A) ; God offerts tirés du monde 1", A.Tournament.MinPlayers == 4
    and A.RewardWorld == 1)

local summary = ("[ARENA CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
