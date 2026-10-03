--!nonstrict
--[[ TestMatchmaker
     Rôle    : vérifier la file d'attente de l'arène : accès, choix du bot, marge d'Elo, appariement, offres de bot.
     Doc     : GAME_MASTER_V2 G5.5, E1, E6, E11.4 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot D ; décisions 113, 123 à 126
     Étape   : 13, lot D
     Dépend  : ServerScriptService.Combat.Matchmaker ; ReplicatedStorage.Config.DefaultProfile
     Exposé  : exécution manuelle (Studio : ServerStorage.Tests par le TestRunner ; hors Studio :
               tools/run_config_tests.py) ; aucune écriture de données
     Limite  : l'horloge est passée à la main ; ArenaService (session locale) appellera Tick toutes les 5 s.
]]
local combat = assert(game:GetService("ServerScriptService"):FindFirstChild("Combat"), "Combat absent")
local MM = require(assert(combat:FindFirstChild("Matchmaker"), "Matchmaker absent"))
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local Default = require(assert(config:FindFirstChild("DefaultProfile"), "DefaultProfile absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function profile(level, uids, owned, wins, losses, streak)
    return {
        Level = level, Creatures = owned,
        PvP = {Loadouts = {A = uids}, LossStreak = streak},
        Stats = {ArenaWins = wins or 0, ArenaLosses = losses or 0},
    }
end
local owned = {{Uid = "u1", Id = "noobini"}, {Uid = "u2", Id = "trippi"}, {Uid = "u3", Id = "talpa"}}
local function list(t) return table.concat(t, ",") end
local function describe(matches)
    local out = {}
    for _, m in ipairs(matches) do
        table.insert(out, if m.Kind == "Human" then m.A .. "-" .. m.B else m.A .. ":" .. m.Bot)
    end
    table.sort(out)
    return list(out)
end

-- G5.5 : accès.
local function why(p, inMatch) local ok, reason = MM.CanJoin(p, inMatch); return ok and "OK" or reason end
check("G5.5 : niveau 5, équipe A de 3 brainrots possédés → accepté", why(profile(5, {"u1", "u2", "u3"}, owned)) == "OK")
check("Niveau 4 → LEVEL_TOO_LOW ; match en cours → IN_MATCH", why(profile(4, {"u1", "u2", "u3"}, owned)) == "LEVEL_TOO_LOW"
    and why(profile(5, {"u1", "u2", "u3"}, owned), true) == "IN_MATCH")
check("Équipe A incomplète, brainrot non possédé ou en double → LOADOUT_INCOMPLETE",
    why(profile(5, {"u1", "u2", nil}, owned)) == "LOADOUT_INCOMPLETE"
    and why(profile(5, {"u1", "u2", "u9"}, owned)) == "LOADOUT_INCOMPLETE"
    and why(profile(5, {"u1", "u1", "u2"}, owned)) == "LOADOUT_INCOMPLETE"
    and why(profile(5, nil, owned)) == "LOADOUT_INCOMPLETE")
check("Profil absent ou sans PvP → NO_PROFILE ; profil neuf (G2) : niveau 1 refusé", why(nil) == "NO_PROFILE"
    and why({Level = 9}) == "NO_PROFILE" and why(Default) == "LEVEL_TOO_LOW")

-- E1 / E6 / E11.4 : bot imposé.
check("E1 : 0 à 2 matchs joués → bot du tutoriel ; profil neuf aussi", MM.BotKind(profile(5, {}, {}, 0, 0))
    == "Tutorial" and MM.BotKind(profile(5, {}, {}, 1, 1)) == "Tutorial" and MM.BotKind(Default) == "Tutorial")
check("E6 : 3 défaites classées de suite → garde-fou ; sinon normal (série absente = 0)",
    MM.BotKind(profile(5, {}, {}, 2, 1, 3)) == "Guard" and MM.BotKind(profile(5, {}, {}, 2, 1, 2)) == "Normal"
    and MM.BotKind(profile(5, {}, {}, 5, 0, nil)) == "Normal")

-- E6 : marge d'Elo.
check("E6 : ±150, +50 par tranche pleine de 20 s, plafond ±400", MM.Range(0) == 150 and MM.Range(19.9) == 150
    and MM.Range(20) == 200 and MM.Range(99) == 350 and MM.Range(100) == 400 and MM.Range(1000) == 400
    and MM.Range(-5) == 150)

-- Entrée dans la file.
local q = MM.New()
local okJoin = MM.Join(q, 1, 1000, "Normal", 0)
local _, whyDup = MM.Join(q, 1, 1000, "Normal", 0)
local bad = true
for _, args in ipairs({{"1", 1000, "Normal"}, {2, 0 / 0, "Normal"}, {2, 1000, "Boss"}, {2, nil, "Normal"}}) do
    local ok, reason = MM.Join(q, args[1], args[2], args[3], 0)
    bad = bad and ok == false and reason == "BAD_INPUT"
end
check("Entrée : acceptée, puis ALREADY_QUEUED ; entrées invalides → BAD_INPUT", okJoin and whyDup == "ALREADY_QUEUED"
    and bad and MM.Size(q) == 1)
check("Sortie de file", MM.Leave(q, 1) == true and MM.Leave(q, 1) == false and MM.Size(q) == 0)

-- Appariement.
q = MM.New()
MM.Join(q, 1, 1000, "Normal", 0)
MM.Join(q, 2, 1150, "Normal", 0)
check("Écart de 150 : apparié au premier passage", describe(MM.Tick(q, 5).Matches) == "1-2" and MM.Size(q) == 0)
q = MM.New()
MM.Join(q, 1, 1000, "Normal", 0)
MM.Join(q, 2, 1160, "Normal", 0)
local at19 = describe(MM.Tick(q, 19).Matches)
check("Écart de 160 : attend 20 s (marge 200)", at19 == "" and describe(MM.Tick(q, 20).Matches) == "1-2")
q = MM.New()
MM.Join(q, 1, 1000, "Normal", 0)
MM.Join(q, 2, 1260, "Normal", 40)
local at55 = describe(MM.Tick(q, 55).Matches)
check("La marge suit l'attente la plus longue (55 s → 250 : non ; 60 s → 300 : oui)", at55 == ""
    and describe(MM.Tick(q, 60).Matches) == "1-2")
q = MM.New()
for i, elo in ipairs({1300, 1000, 1200, 1100}) do MM.Join(q, i, elo, "Normal", 0) end
check("Tri par Elo, voisins appariés : 1000-1100 et 1200-1300", describe(MM.Tick(q, 5).Matches) == "2-4,3-1")
q = MM.New()
for i, elo in ipairs({1000, 1100, 1500}) do MM.Join(q, i, elo, "Normal", 0) end
local res = MM.Tick(q, 5)
check("Joueur sans voisin assez proche : reste en file", describe(res.Matches) == "1-2" and MM.Size(q) == 1
    and q.Entries[1].UserId == 3)
q = MM.New()
MM.Join(q, 1, 1000, "Tutorial", 0)
MM.Join(q, 2, 1000, "Guard", 0)
MM.Join(q, 3, 1000, "Normal", 0)
check("Bots imposés (tutoriel, garde-fou) : match immédiat, jamais contre un humain",
    describe(MM.Tick(q, 5).Matches) == "1:Tutorial,2:Guard" and MM.Size(q) == 1)

-- E1 / G5.5 : bot proposé après 30 s, refusable, renouvelé.
q = MM.New()
MM.Join(q, 1, 1000, "Normal", 0)
local o25 = list(MM.Tick(q, 25).Offers)
local o30 = list(MM.Tick(q, 30).Offers)
local o35 = list(MM.Tick(q, 35).Offers)
local declined = MM.DeclineBot(q, 1)
local _, whyNoOffer = MM.DeclineBot(q, 1)
local o55 = list(MM.Tick(q, 55).Offers)
local o60 = list(MM.Tick(q, 60).Offers)
check("Offre de bot à 30 s, une seule tant qu'elle attend une réponse", o25 == "" and o30 == "1" and o35 == "")
local qp = MM.New()
MM.Join(qp, 9, 1000, "Normal", 0)
local _, whyEarly = MM.AcceptBot(qp, 9)
MM.Tick(qp, 30)
check("Pas d'acceptation sans offre (NO_OFFER) ; offre sans réponse jamais doublée, même 60 s plus tard",
    whyEarly == "NO_OFFER" and list(MM.Tick(qp, 60).Offers) == "" and list(MM.Tick(qp, 95).Offers) == "")
check("Refusée : le joueur reste en file, nouvelle offre 30 s après la précédente", declined and whyNoOffer == "NO_OFFER"
    and MM.Size(q) == 1 and o55 == "" and o60 == "1")
local match = MM.AcceptBot(q, 1)
local _, whyGone = MM.AcceptBot(q, 1)
check("Acceptée : match contre un bot normal, file vide ; 2e réponse → NO_OFFER", match and match.Kind == "Bot"
    and match.Bot == "Normal" and match.A == 1 and MM.Size(q) == 0 and whyGone == "NO_OFFER")
q = MM.New()
MM.Join(q, 1, 1000, "Normal", 0)
MM.Tick(q, 30)
MM.DeclineBot(q, 1)
MM.Join(q, 2, 1390, "Normal", 90)
local at95 = describe(MM.Tick(q, 95).Matches)
check("Après un refus, l'attente continue : 1390 contre 1000 apparié à 100 s (marge 400)", at95 == ""
    and describe(MM.Tick(q, 100).Matches) == "1-2")
q = MM.New()
MM.Join(q, 1, 1000, "Normal", 0)
MM.Tick(q, 30)
MM.Join(q, 2, 1010, "Normal", 31)
local paired = describe(MM.Tick(q, 35).Matches)
local _, whyPaired = MM.AcceptBot(q, 1)
check("Offre en attente puis adversaire humain : le match humain l'emporte, l'offre tombe", paired == "1-2"
    and whyPaired == "NO_OFFER")

-- File chargée : personne dans deux matchs, chaque paire dans sa marge.
q = MM.New()
math.randomseed(42)
for i = 1, 200 do MM.Join(q, i, math.random(600, 2200), "Normal", math.random(0, 60)) end
local elo = {}
for _, e in ipairs(q.Entries) do elo[e.UserId] = e end
res = MM.Tick(q, 60)
local seen, inRange, count = {}, true, 0
for _, m in ipairs(res.Matches) do
    for _, id in ipairs({m.A, m.B}) do
        if seen[id] then inRange = false end
        seen[id] = true
        count += 1
    end
    local a, b = elo[m.A], elo[m.B]
    inRange = inRange and math.abs(a.Elo - b.Elo) <= MM.Range(60 - math.min(a.JoinedAt, b.JoinedAt))
end
check(("200 joueurs : %d appariés, %d en file, aucun en double, toutes les paires dans leur marge"):format(count,
    MM.Size(q)), inRange and count + MM.Size(q) == 200 and count > 150)

local summary = ("[MATCHMAKER TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
