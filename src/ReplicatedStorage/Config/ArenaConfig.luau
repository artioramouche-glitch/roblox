--!strict
--[[ ArenaConfig
     Rôle    : chiffres de la compétition PvP hors simulation : tokens arène, rangs et saisons, boutique du Colisée,
               Tournoi du Samedi, et leur calendrier à l'heure de Paris.
     Doc     : GAME_MASTER_V2 C7, E2, E7, E8, E9 ; PROMPT_EXECUTION_SABL_V4 §31.14 ; Q1-Q3 de l'étape 14 (02/10 : A,
               A, A) ; Elo et rangs dans Shared/EloUtil (G5.4, recopié tel quel)
     Étape   : 14 (configuration seule)
     Dépend  : Shared/ParisTime (heure de Paris, sortie de ce module à l'étape 15)
     Exposé  : configuration immuable ; Tokens, RankLabels, SeasonRewards, Shop, Tournament ;
               GetShopItem(key), ParisOffset(now), TournamentAt(now), SeasonAt(now)
     Limite  : module absent de G1, comme EconomyConfig ; écart déclaré. Q3 : le tournoi suit l'heure de Paris, été
               compris ; la saison mensuelle aussi (déclaré). Le calcul des dates vit dans Shared/ParisTime.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ParisTime = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ParisTime"))

local ArenaConfig = {}

-- C7 / E2 : tokens gagnés en jouant, jamais achetés.
ArenaConfig.Tokens = table.freeze({
    Ranked1v1 = table.freeze({Win = 25, Loss = 8}),
    Ranked2v2 = table.freeze({Win = 35, Loss = 12}),
    PerMinutePlayed = 2,
    FreeArenaMax = 5, FreeArenaWindow = 15 * 60, -- E2 : Arène Libre, 5 tokens max par 15 min
})

-- E7 : libellés des rangs que renvoie EloUtil.GetRank ; « BrainrotGod » = top 1 de la saison.
ArenaConfig.RankLabels = table.freeze({
    Bois = "Bois", Bronze = "Bronze", Argent = "Argent", Or = "Or", Platine = "Platine", Diamant = "Diamant",
    BrainrotMaster = "Brainrot Master", BrainrotGod = "Brainrot God",
})

-- E7 : récompense du meilleur rang atteint dans la saison (seulement celle de ce rang ; rien sous Or).
ArenaConfig.SeasonRewards = table.freeze({
    Or = table.freeze({Eggs = table.freeze({egg_mythic = 1})}),
    Platine = table.freeze({Eggs = table.freeze({egg_mythic = 2})}),
    Diamant = table.freeze({Eggs = table.freeze({egg_mythic = 3})}),
    BrainrotMaster = table.freeze({Rarity = "God"}),
    BrainrotGod = table.freeze({Skin = "SkinChampion", Title = "Brainrot God", Statue = true}),
})

-- E8 : boutique du Colisée, prix en tokens. Once = achat unique ; MaxLevel = plafond via la boutique.
ArenaConfig.Shop = table.freeze({
    -- Q2 (option A) : le pool et les odds de egg_golden.
    table.freeze({Key = "EggColisee", Name = "Œuf Colisée", Price = 500, Egg = "egg_golden"}),
    table.freeze({Key = "SkinChampion", Name = "Skin Champion Doré", Price = 1200, Cosmetic = "Skin", Once = true}),
    table.freeze({Key = "TrailFire", Name = "Trail d'attaque feu", Price = 400, Cosmetic = "Trail", Once = true}),
    table.freeze({Key = "TrailLightning", Name = "Trail d'attaque foudre", Price = 400, Cosmetic = "Trail", Once = true}),
    table.freeze({Key = "TrailGalaxy", Name = "Trail d'attaque galaxie", Price = 400, Cosmetic = "Trail", Once = true}),
    table.freeze({Key = "PoseDance1", Name = "Pose de victoire : danse 1", Price = 250, Cosmetic = "Pose", Once = true}),
    table.freeze({Key = "PoseDance2", Name = "Pose de victoire : danse 2", Price = 250, Cosmetic = "Pose", Once = true}),
    table.freeze({Key = "PoseDance3", Name = "Pose de victoire : danse 3", Price = 250, Cosmetic = "Pose", Once = true}),
    table.freeze({Key = "LoadoutB", Name = "2e loadout PvP", Price = 800, Loadout = "B", Once = true}),
    table.freeze({Key = "IncomeBoost", Name = "Boost +20 % revenus 30 min", Price = 100, IncomeMult = 1.2,
        Seconds = 30 * 60}),
    table.freeze({Key = "TrainingRing", Name = "Anneau d'entraînement +1 niveau", Price = 600, TrainingRing = 1,
        MaxLevel = 3}),
})

-- E9 : samedi, inscription 17 h 30, brief et bracket 17 h 45 → 18 h 30, heure de Paris (Q3).
ArenaConfig.Tournament = table.freeze({
    Weekday = 6, -- samedi (0 = dimanche)
    RegistrationAt = 17 * 3600 + 30 * 60, BracketAt = 17 * 3600 + 45 * 60, EndAt = 18 * 3600 + 30 * 60,
    MinElo = 1100, Sizes = table.freeze({8, 16}), Bet = 50, BetPayout = 2, -- pari double ou rien
    Rewards = table.freeze({
        Top8 = table.freeze({ArenaTokens = 300}),
        Top4 = table.freeze({ArenaTokens = 800, Eggs = table.freeze({egg_mythic = 1})}),
        Finalist = table.freeze({ArenaTokens = 1500, Eggs = table.freeze({egg_mythic = 2})}),
        Champion = table.freeze({ArenaTokens = 3000, Rarity = "God", Title = "Champion de la Semaine",
            TitleDays = 7}),
    }),
})

local shopByKey: {[string]: any} = {}
for _, item in ipairs(ArenaConfig.Shop :: {any}) do shopByKey[item.Key] = item end

function ArenaConfig.GetShopItem(key: any): any
    return if type(key) == "string" then shopByKey[key] else nil
end

-- Décalage de Paris (secondes à ajouter à l'UTC) à l'instant UTC `now` (Shared/ParisTime).
ArenaConfig.ParisOffset = ParisTime.Offset

-- Tournoi en cours ou prochain : phase ("Registration", "Bracket" ou "None"), puis les instants UTC de
-- l'inscription, du bracket et de la fin. Aucun changement d'heure ne tombe un samedi soir.
function ArenaConfig.TournamentAt(now: number): (string, number, number, number)
    local t = ArenaConfig.Tournament
    local active, registration, finish = ParisTime.Weekly(now, t.Weekday, t.RegistrationAt, t.EndAt - t.RegistrationAt)
    local bracket = registration + (t.BracketAt - t.RegistrationAt)
    local phase = if not active then "None" elseif now >= bracket then "Bracket" else "Registration"
    return phase, registration, bracket, finish
end

-- Saison mensuelle (E7, mois calendaire de Paris) : identifiant année × 12 + mois - 1, début et fin UTC.
ArenaConfig.SeasonAt = ParisTime.Month

return table.freeze(ArenaConfig)
