--!nonstrict
--[[ TestArenaRewards
     Rôle    : vérifier le bilan de fin de match : Elo, tokens, abandon, série de défaites, saison, Arène Libre.
     Doc     : GAME_MASTER_V2 G5.4, G5.5 (EndMatch), E1, E2, E6, E7, C7, G2 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot D ;
               décisions 125 à 127
     Étape   : 13, lot D
     Dépend  : ServerScriptService.Combat.ArenaRewards, Matchmaker, CombatEngine ; ReplicatedStorage.Config
               (DefaultProfile, ArenaConfig) ; Shared.EloUtil
     Exposé  : exécution manuelle ; écrit seulement dans des copies locales du profil G2, jamais dans un magasin
     Limite  : la sauvegarde du profil (DataService) et l'écran de résultat se testent en Play.
]]
local combat = assert(game:GetService("ServerScriptService"):FindFirstChild("Combat"), "Combat absent")
local R = require(assert(combat:FindFirstChild("ArenaRewards"), "ArenaRewards absent"))
local MM = require(assert(combat:FindFirstChild("Matchmaker"), "Matchmaker absent"))
local Engine = require(assert(combat:FindFirstChild("CombatEngine"), "CombatEngine absent"))
local RS = game:GetService("ReplicatedStorage")
local Default = require(assert(RS:FindFirstChild("Config"):FindFirstChild("DefaultProfile"), "DefaultProfile absent"))
local A = require(assert(RS:FindFirstChild("Config"):FindFirstChild("ArenaConfig"), "ArenaConfig absent"))
local Elo = require(assert(RS:FindFirstChild("Shared"):FindFirstChild("EloUtil"), "EloUtil absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function fresh(level)
    local p = copy(Default)
    p.Level = level or 10
    return p
end
local function result(winner, reason, seconds, abilities, ultimates)
    return {Over = true, Winner = winner, Reason = reason or "KO", Seconds = seconds or 75,
        A = {Abilities = abilities or 0, Ultimates = ultimates or 0}, B = {Abilities = 0, Ultimates = 0}}
end
local function settle(p, res, opp, mode, now)
    return R.Settle(p, {Mode = mode or "Ranked1v1", Result = res, Side = "A", OpponentElo = opp or 1000,
        Now = now or 0})
end

-- G5.4 / E6 / C7 : victoire, défaite, nul.
local p = fresh()
local before = copy(p)
local win = settle(p, result("A", "KO", 75, 4, 1))
check("Settle ne modifie pas le profil", same(p, before))
check("Victoire à Elo égal : 1000 → 1016 ; 25 + 2 tokens (1 min 15 s)", win.EloBefore == 1000 and win.EloAfter == 1016
    and win.Tokens == 27 and win.Score == 1 and win.LossStreak == 0)
local loss = settle(p, result("B", "KO", 130))
check("Défaite à Elo égal : 1000 → 984 ; 8 + 4 tokens (2 min 10 s) ; série 1", loss.EloAfter == 984
    and loss.Tokens == 12 and loss.LossStreak == 1)
local draw = settle(p, result("Draw", "Timeout", 90))
check("Nul : Elo inchangé, tokens d'une défaite (8 + 2), série inchangée", draw.EloAfter == 1000 and draw.Tokens == 10
    and draw.Score == 0.5 and draw.LossStreak == 0)
local botWin = settle(p, result("A"), 900)
local botLoss = settle(p, result("B"), 900)
check("Contre un bot (Elo − 100) : +12 en victoire, −20 en défaite (11,52 et 20,48 arrondis)", botWin.EloAfter == 1012
    and botLoss.EloAfter == 980)
local bounded = true
for _, opp in ipairs({0, 600, 1000, 1400, 3000}) do
    for _, w in ipairs({"A", "B", "Draw"}) do
        local s = settle(p, result(w), opp)
        bounded = bounded and math.abs(s.EloAfter - 1000) <= 32
    end
end
check("E6 : ±32 au plus, quel que soit l'adversaire", bounded)

-- Q3 (A) : abandon.
local quit = settle(p, result("B", "Forfeit", 80))
local stay = settle(p, result("A", "Forfeit", 80))
check("Q3 (A) : qui abandonne perd l'Elo d'une défaite et ne gagne aucun token, même après 1 min", quit.Forfeited
    and quit.Tokens == 0 and quit.EloAfter == 984 and quit.LossStreak == 1 and A.Tokens.Ranked1v1.Forfeit == 0)
check("L'adversaire de celui qui abandonne gagne normalement (25 + 2)", not stay.Forfeited and stay.Tokens == 27
    and stay.EloAfter == 1016)

-- Application au profil (G2).
R.Apply(p, win)
local s = p.PvP.Season
check("Victoire appliquée : Elo, tokens, saison (victoires, pic, rang Bronze, ultimes), compteurs",
    p.PvP.Elo1v1 == 1016 and p.PvP.ArenaTokens == 27 and s.Wins == 1 and s.Losses == 0 and s.PeakElo == 1016
    and s.BestRank == 3 and s.UltimatesUsed == 1 and p.Stats.ArenaWins == 1 and p.Stats.AbilitiesUsed == 4
    and p.PvP.LossStreak == 0)
R.Apply(p, settle(p, result("B")))
check("Défaite appliquée : pic et meilleur rang de saison gardés, série 1, défaites comptées", p.PvP.Elo1v1 < 1000
    and s.PeakElo == 1016 and s.BestRank == 3 and p.PvP.LossStreak == 1 and s.Losses == 1 and p.Stats.ArenaLosses == 1)
R.Apply(p, settle(p, result("Draw", "Timeout", 90)))
check("Nul appliqué : ni victoire ni défaite comptées, série inchangée", s.Wins == 1 and s.Losses == 1
    and p.Stats.ArenaWins == 1 and p.Stats.ArenaLosses == 1 and p.PvP.LossStreak == 1)

-- E1 / E6 : le bilan nourrit le choix du bot.
p = fresh()
local kinds = {}
for _ = 1, 3 do
    table.insert(kinds, MM.BotKind(p))
    R.Apply(p, settle(p, result("A")))
end
table.insert(kinds, MM.BotKind(p))
for _ = 1, 3 do R.Apply(p, settle(p, result("B"))) end
table.insert(kinds, MM.BotKind(p))
R.Apply(p, settle(p, result("Draw", "Timeout", 90)))
table.insert(kinds, MM.BotKind(p))
R.Apply(p, settle(p, result("A")))
table.insert(kinds, MM.BotKind(p))
check("3 matchs de tutoriel, puis normal ; 3 défaites → garde-fou ; un nul ne l'efface pas ; une victoire si",
    table.concat(kinds, ",") == "Tutorial,Tutorial,Tutorial,Normal,Guard,Guard,Normal")

-- E2 : Arène Libre.
p = fresh()
local f1 = settle(p, result("A"), nil, "Free", 1000)
R.Apply(p, f1)
local f2 = settle(p, result("A"), nil, "Free", 1500)
R.Apply(p, f2)
local f3 = settle(p, result("B"), nil, "Free", 1000 + 900)
R.Apply(p, f3)
check("Arène Libre : 5 tokens au plus par 15 min (5, puis 0, puis 5 à la tranche suivante)", f1.Tokens == 5
    and f2.Tokens == 0 and f3.Tokens == 5 and p.PvP.ArenaTokens == 10 and p.PvP.FreeTokens.WindowStart == 1900)
check("Arène Libre : ni Elo, ni série, ni saison ; victoires et défaites comptées", p.PvP.Elo1v1 == 1000
    and p.PvP.LossStreak == nil and p.PvP.Season.Wins == 0 and p.Stats.ArenaWins == 2 and p.Stats.ArenaLosses == 1)

-- Entrées refusées.
local function refused(input) local out, why = R.Settle(fresh(), input); return out == nil and why == "BAD_INPUT" end
local ok = result("A")
check("Entrées refusées : 2v2, match non fini, côté inconnu, Elo adverse absent, horloge absente, profil absent",
    refused({Mode = "Ranked2v2", Result = ok, Side = "A", OpponentElo = 1000, Now = 0})
    and refused({Mode = "Ranked1v1", Result = {Over = false, Seconds = 1, A = {}}, Side = "A", OpponentElo = 1000,
        Now = 0})
    and refused({Mode = "Ranked1v1", Result = ok, Side = "C", OpponentElo = 1000, Now = 0})
    and refused({Mode = "Ranked1v1", Result = ok, Side = "A", Now = 0})
    and refused({Mode = "Free", Result = ok, Side = "A"})
    and R.Settle(nil, {}) == nil)

-- Bilan d'un vrai match du moteur.
local function tank(id) return {Id = id, HP = 1e6, ATK = 10, Type = "Salty"} end
local m = Engine.New({tank("noobini")}, {tank("trippi")}, 99)
for _ = 1, 300 do Engine.Step(m) end
Engine.Forfeit(m, "B")
local real = R.Settle(fresh(), {Mode = "Ranked1v1", Result = Engine.Result(m), Side = "A", OpponentElo = 1000, Now = 0})
check("Vrai match (abandon de B à 30 s) : victoire de A, 25 tokens", real and real.Score == 1 and real.Tokens == 25
    and real.Seconds == 30)
local _, rank = Elo.GetRank(1016)
check("Rang de saison lu dans EloUtil (G5.4)", rank == 3)

local summary = ("[ARENA REWARDS TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
