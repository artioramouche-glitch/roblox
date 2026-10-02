--!strict
--[[ ArenaConfig
     Rôle    : chiffres de la compétition PvP hors simulation : tokens arène, rangs et saisons, boutique du Colisée,
               Tournoi du Samedi, et leur calendrier à l'heure de Paris.
     Doc     : GAME_MASTER_V2 C7, E2, E7, E8, E9 ; PROMPT_EXECUTION_SABL_V4 §31.14 ; Q1-Q3 de l'étape 14 (02/10 : A,
               A, A) ; Elo et rangs dans Shared/EloUtil (G5.4, recopié tel quel)
     Étape   : 14 (configuration seule)
     Dépend  : aucun
     Exposé  : configuration immuable ; Tokens, RankLabels, SeasonRewards, Shop, Tournament, Paris ;
               GetShopItem(key), ParisOffset(now), TournamentAt(now), SeasonAt(now)
     Limite  : module absent de G1, comme EconomyConfig ; écart déclaré. Q3 : le tournoi suit l'heure de Paris, été
               compris (règle européenne : du dernier dimanche de mars au dernier dimanche d'octobre, à 01:00 UTC) ;
               la saison mensuelle aussi (déclaré). Dates calculées sans os.time, dont le fuseau varie.
]]
local ArenaConfig = {}

local DAY = 86400

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

-- Heure de Paris : UTC+1, UTC+2 en été (du dernier dimanche de mars au dernier dimanche d'octobre, à 01:00 UTC).
ArenaConfig.Paris = table.freeze({StandardOffset = 3600, SummerOffset = 7200, SwitchHourUtc = 1})

local shopByKey: {[string]: any} = {}
for _, item in ipairs(ArenaConfig.Shop :: {any}) do shopByKey[item.Key] = item end

function ArenaConfig.GetShopItem(key: any): any
    return if type(key) == "string" then shopByKey[key] else nil
end

-- Jours depuis le 1er janvier 1970 d'une date du calendrier grégorien (algorithme de H. Hinnant), et l'inverse.
local function daysFromCivil(y: number, m: number, d: number): number
    y = if m <= 2 then y - 1 else y
    local era = y // 400
    local yoe = y - era * 400
    local doy = (153 * (if m > 2 then m - 3 else m + 9) + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end

local function civilFromDays(z: number): (number, number, number)
    z += 719468
    local era = z // 146097
    local doe = z - era * 146097
    local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    local mp = (5 * doy + 2) // 153
    local d = doy - (153 * mp + 2) // 5 + 1
    local m = if mp < 10 then mp + 3 else mp - 9
    return yoe + era * 400 + (if m <= 2 then 1 else 0), m, d
end

-- Jour de la semaine d'un numéro de jour (0 = dimanche ; le 1er janvier 1970 est un jeudi).
local function weekday(days: number): number
    return (days + 4) % 7
end

-- Dernier dimanche du mois m de l'année y, en jours depuis 1970.
local function lastSunday(y: number, m: number): number
    local last = daysFromCivil(if m == 12 then y + 1 else y, if m == 12 then 1 else m + 1, 1) - 1
    return last - weekday(last)
end

-- Décalage de Paris (secondes à ajouter à l'UTC) à l'instant UTC `now`.
function ArenaConfig.ParisOffset(now: number): number
    local paris = ArenaConfig.Paris
    local y = civilFromDays(now // DAY)
    local summerStart = lastSunday(y, 3) * DAY + paris.SwitchHourUtc * 3600
    local summerEnd = lastSunday(y, 10) * DAY + paris.SwitchHourUtc * 3600
    return if now >= summerStart and now < summerEnd then paris.SummerOffset else paris.StandardOffset
end

-- Instant UTC d'une heure locale de Paris (secondes depuis 1970 comptées à l'heure de Paris).
local function fromParis(localTime: number): number
    local guess = localTime - ArenaConfig.Paris.StandardOffset
    return localTime - ArenaConfig.ParisOffset(guess)
end

-- Tournoi en cours ou prochain : phase ("Registration", "Bracket" ou "None"), puis les instants UTC de
-- l'inscription, du bracket et de la fin.
function ArenaConfig.TournamentAt(now: number): (string, number, number, number)
    local t = ArenaConfig.Tournament
    local localDays = (now + ArenaConfig.ParisOffset(now)) // DAY
    local saturday = localDays - (weekday(localDays) - t.Weekday) % 7
    for week = 0, 1 do
        local base = (saturday + 7 * week) * DAY
        local registration, bracket, finish = fromParis(base + t.RegistrationAt), fromParis(base + t.BracketAt),
            fromParis(base + t.EndAt)
        if now < finish then
            local phase = if now >= bracket then "Bracket" elseif now >= registration then "Registration" else "None"
            return phase, registration, bracket, finish
        end
    end
    error("tournoi introuvable") -- inatteignable : le samedi suivant est toujours à venir
end

-- Saison mensuelle (E7, mois calendaire de Paris) : identifiant année × 12 + mois - 1, début et fin UTC.
function ArenaConfig.SeasonAt(now: number): (number, number, number)
    local y, m = civilFromDays((now + ArenaConfig.ParisOffset(now)) // DAY)
    local nextY, nextM = if m == 12 then y + 1 else y, if m == 12 then 1 else m + 1
    return y * 12 + m - 1, fromParis(daysFromCivil(y, m, 1) * DAY), fromParis(daysFromCivil(nextY, nextM, 1) * DAY)
end

return table.freeze(ArenaConfig)
