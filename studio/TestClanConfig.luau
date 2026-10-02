--!nonstrict
--[[ TestClanConfig
     Rôle    : vérifier ClanConfig (F1-F4) et Shared/ParisTime pour le calendrier de la guerre.
     Doc     : GAME_MASTER_V2 F1, F2, F3, F4, C4 ; PROMPT_EXECUTION_SABL_V4 §31.15 ; Q1-Q3 de l'étape 15
     Étape   : 15 (configuration)
     Dépend  : ReplicatedStorage.Config.ClanConfig, EggConfig ; ReplicatedStorage.Shared.ParisTime
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : ne prouve que la configuration ; le filtre TextService, le coffre réel et la guerre se testent en
               Play. Les instants attendus viennent du fuseau Europe/Paris de Python (zoneinfo).
]]
local RS = game:GetService("ReplicatedStorage")
local config = assert(RS:FindFirstChild("Config"), "Config absent")
local shared = assert(RS:FindFirstChild("Shared"), "Shared absent")
local Cl = require(assert(config:FindFirstChild("ClanConfig"), "ClanConfig absent"))
local E = require(assert(config:FindFirstChild("EggConfig"), "EggConfig absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- F1.
local c = Cl.Creation
check("F1 : création 500 000, nom 3-16, tag 2-4, 20 emblèmes, 20 membres", c.Cost == 500000 and c.NameMin == 3
    and c.NameMax == 16 and c.TagMin == 2 and c.TagMax == 4 and c.Emblems == 20 and Cl.MaxMembers == 20)
check("F1 : Chef unique transférable, 3 officiers qui déclarent et acceptent", Cl.Roles.Leader.Max == 1
    and Cl.Roles.Leader.Transferable and Cl.Roles.Officer.Max == 3 and Cl.Roles.Officer.CanDeclareWar
    and Cl.Roles.Officer.CanAccept and not Cl.Roles.Member.CanDeclareWar)
check("Nom : 3 et 16 caractères acceptés, 2 et 17 refusés, accents comptés une fois", Cl.ValidName("Abc")
    and Cl.ValidName(string.rep("x", 16)) and not Cl.ValidName("ab") and not Cl.ValidName(string.rep("x", 17))
    and Cl.ValidName("Éclé") and Cl.ValidName("ééééééééééééééé") and not Cl.ValidName(nil))
check("Tag : 2 à 4 lettres", Cl.ValidTag("TT") and Cl.ValidTag("brNr") and not Cl.ValidTag("T")
    and not Cl.ValidTag("ABCDE") and not Cl.ValidTag("A1") and not Cl.ValidTag("ÉÉ") and not Cl.ValidTag(12))

-- F2 (Q1, option A).
local want = {{500e3, 0.03, "Gris"}, {5e6, 0.06, "Bleu"}, {50e6, 0.10, "Doré"}, {500e6, 0.15, "Violet"},
    {5e9, 0.18, "ArcEnCiel"}}
local chestOk = #Cl.ChestLevels == 5
for level, w in ipairs(want) do
    local entry = Cl.ChestLevels[level]
    chestOk = chestOk and entry.Level == level and entry.Donated == w[1] and entry.IncomeBonus == w[2]
        and entry.TagColor == w[3]
end
check("F2 : 5 niveaux (500K → 5B), +3 / +6 / +10 / +15 / +18 %, couleurs", chestOk)
check("F2 : aura (3), emote (4), bannière au Colisée (5)", Cl.ChestLevels[3].Aura and Cl.ChestLevels[4].Emote
    and Cl.ChestLevels[5].ColiseumBanner)
check("Coffre : 499 999 → 0, 500 000 → 1, 5 milliards → 5", Cl.ChestLevel(499999) == 0 and Cl.ChestLevel(500000) == 1
    and Cl.ChestLevel(4999999) == 1 and Cl.ChestLevel(5e9) == 5 and Cl.ChestLevel(1e12) == 5)
check("Perk : 0 sans niveau, +18 % au niveau 5 (Q1)", Cl.ChestBonus(0) == 0 and Cl.ChestBonus(50e6) == 0.10
    and Cl.ChestBonus(5e9) == 0.18 and Cl.ChestBonus(nil) == 0 and Cl.ChestBonus(0 / 0) == 0)

-- F3.
local w = Cl.War
check("F3 : 5 duels, 75 / 15, sessions mardi et jeudi 18:00", w.Arena.Duels == 5 and w.Arena.Win == 75
    and w.Arena.Loss == 15 and w.Arena.Sessions[1].Weekday == 2 and w.Arena.Sessions[2].Weekday == 4
    and w.Arena.Sessions[1].At == 64800 and w.Arena.Sessions[2].At == 64800)
check("Q2 : front Arène à 375 au plus", Cl.ArenaFrontPoints(5, 0) == 375 and Cl.ArenaFrontPoints(3, 2) == 255
    and Cl.ArenaFrontPoints(0, 5) == 75 and Cl.ArenaFrontPoints(4, 2) == nil and Cl.ArenaFrontPoints(-1, 0) == nil
    and Cl.ArenaFrontPoints(1.5, 0) == nil)
check("F3 : drapeau 50 points, front Vol à 500 au plus", Cl.StealFrontPoints(1) == 50 and Cl.StealFrontPoints(10) == 500
    and Cl.StealFrontPoints(14) == 500 and Cl.StealFrontPoints(0) == 0 and Cl.StealFrontPoints(-3) == 0)
local a, b = Cl.BossFrontPoints(3000, 1000)
local c1, c2 = Cl.BossFrontPoints(1, 2)
local z1, z2 = Cl.BossFrontPoints(0, 0)
check("Q3 : 500 points partagés selon les dégâts (375 / 125 ; 167 / 333 ; 0 / 0)", a == 375 and b == 125
    and c1 == 167 and c2 == 333 and z1 == 0 and z2 == 0)
check("Q3 : boss de guerre sans PV, 50 min le mardi à 20:00", w.Boss.Weekday == 2 and w.Boss.StartAt == 72000
    and w.Boss.Duration == 3000 and w.Boss.Points == 500 and w.Boss.HP == nil)
local r = w.Rewards
check("F3 : gagnant 400 tokens + 250K + egg_mythic aux marqueurs ; perdant 100 + 50K ; MVP 7 j",
    r.Winner.ArenaTokens == 400 and r.Winner.Money == 250000 and r.Winner.ScorerEggs.egg_mythic == 1
    and r.Loser.ArenaTokens == 100 and r.Loser.Money == 50000 and r.MvpPoseDays == 7 and E:Get("egg_mythic") ~= nil)
check("Issue : gagnant, perdant, égalité (récompenses du gagnant aux deux, déclaré)", Cl.Winner(800, 700) == "A"
    and Cl.Winner(10, 20) == "B" and Cl.Winner(5, 5) == "Tie" and r.TieGivesWinner == true)

-- F4.
local ab = Cl.AntiAbuse
check("F4 : 1 guerre active, 24 h de pause, 30 min pour marquer, 5 membres actifs (7 jours), pas de fusion",
    ab.MaxActiveWars == 1 and ab.CooldownAfterWar == 86400 and ab.MinWarPlayToScore == 1800
    and ab.MinActiveMembers == 5 and ab.ActiveWindow == 604800 and ab.MergeAllowed == false)
check("F4 : 30 min exigées sur Arène et Vol, pas sur le Boss", not Cl.CanScore("Arena", 1799)
    and Cl.CanScore("Arena", 1800) and not Cl.CanScore("Steal", 0) and Cl.CanScore("Steal", 3600)
    and Cl.CanScore("Boss", 0) and not Cl.CanScore("Foo", 9999) and not Cl.CanScore("Arena", nil))

-- Calendrier (instants Europe/Paris, zoneinfo) : dimanche 20:00 → jeudi 20:00 ; boss le mardi 20:00 → 20:50.
local function window(fn, now, active, start, finish)
    local x, s, f = fn(now)
    return x == active and s == start and f == finish
end
local SUN, THU, NEXT = 1791136800, 1791482400, 1791741600 -- 4, 8 et 11 octobre 2026, 20:00 Paris (UTC+2)
check("Guerre : dimanche 10:00 → commence à 20:00", window(Cl.WarAt, 1791100800, false, SUN, THU))
check("Guerre : dimanche 20:00 → en cours jusqu'au jeudi 20:00 (4 jours)", window(Cl.WarAt, SUN, true, SUN, THU)
    and THU - SUN == 345600)
check("Guerre : mercredi midi → en cours", window(Cl.WarAt, 1791367200, true, SUN, THU))
check("Guerre : jeudi 20:00 → finie, prochaine le dimanche 11", window(Cl.WarAt, THU, false, NEXT, NEXT + 345600))
check("Guerre : vendredi → prochaine le dimanche 11", window(Cl.WarAt, 1791540000, false, NEXT, NEXT + 345600))
check("Guerre du 25 octobre, jour du passage à l'heure d'hiver", window(Cl.WarAt, 1792954800, true, 1792954800, 1793300400))
check("Guerre de novembre, heure d'hiver (19:00 UTC)", window(Cl.WarAt, 1793559600 - 1, false, 1793559600, 1793905200))
check("Boss : mardi 20:00 → 20:50", window(Cl.WarBossAt, 1791309600, true, 1791309600, 1791312600))
check("Boss : 20:50 → mardi suivant", window(Cl.WarBossAt, 1791312600, false, 1791914400, 1791914400 + 3000))
check("Boss : pendant la guerre", 1791309600 > SUN and 1791312600 < THU)
-- ParisTime.Weekly : une fenêtre de près d'une semaine commencée le dimanche précédent est encore en cours.
local Paris = require(assert(shared:FindFirstChild("ParisTime"), "ParisTime absent"))
local long = 6 * 86400 + 20 * 3600 -- dimanche 20:00 → dimanche suivant 16:00
check("Fenêtre longue : dimanche 10:00 → celle du dimanche précédent, en cours", window(function(now)
    return Paris.Weekly(now, 0, 72000, long)
end, 1791100800, true, SUN - 7 * 86400, SUN - 7 * 86400 + long))

local summary = ("[CLAN CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
