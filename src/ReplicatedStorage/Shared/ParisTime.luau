--!strict
--[[ ParisTime
     Rôle    : heure de Paris (été compris) et fenêtres de calendrier hebdomadaires ou mensuelles, pour les rendez-vous
               fixés à l'heure française : Tournoi du Samedi, saisons, guerres de clans.
     Doc     : GAME_MASTER_V2 E7, E9, F3 ; Q3 de l'étape 14 (heure de Paris), lectures de l'étape 15 (guerre)
     Étape   : 14 (sorti d'ArenaConfig à l'étape 15 pour servir aussi à ClanConfig)
     Dépend  : aucun
     Exposé  : StandardOffset, SummerOffset, SwitchHourUtc ; Offset(now), FromParis(localTime),
               Weekly(now, weekday, startSeconds, duration), Month(now)
     Limite  : règle européenne de l'heure d'été (du dernier dimanche de mars au dernier dimanche d'octobre, à
               01:00 UTC). Calcul de dates pur, sans os.time ni os.date, dont le fuseau varie selon l'environnement.
               Une fenêtre ne doit pas contenir un changement d'heure (ils tombent le dimanche à 01:00 UTC).
]]
local ParisTime = {}

local DAY = 86400

ParisTime.StandardOffset = 3600 -- UTC+1
ParisTime.SummerOffset = 7200 -- UTC+2
ParisTime.SwitchHourUtc = 1

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
function ParisTime.Offset(now: number): number
    local y = civilFromDays(now // DAY)
    local summerStart = lastSunday(y, 3) * DAY + ParisTime.SwitchHourUtc * 3600
    local summerEnd = lastSunday(y, 10) * DAY + ParisTime.SwitchHourUtc * 3600
    return if now >= summerStart and now < summerEnd then ParisTime.SummerOffset else ParisTime.StandardOffset
end

-- Instant UTC d'une heure locale de Paris (secondes depuis 1970 comptées à l'heure de Paris).
function ParisTime.FromParis(localTime: number): number
    return localTime - ParisTime.Offset(localTime - ParisTime.StandardOffset)
end

-- Fenêtre qui commence chaque semaine le jour `weekday` (0 = dimanche) à `startSeconds` (heure de Paris) et dure
-- `duration` secondes : renvoie active ?, début et fin UTC de la fenêtre en cours, sinon de la prochaine.
function ParisTime.Weekly(now: number, weekdayIndex: number, startSeconds: number, duration: number): (boolean, number, number)
    local localDays = (now + ParisTime.Offset(now)) // DAY
    local first = localDays - (weekday(localDays) - weekdayIndex) % 7 - 7
    for week = 0, 2 do
        local base = (first + 7 * week) * DAY + startSeconds
        local start, finish = ParisTime.FromParis(base), ParisTime.FromParis(base + duration)
        if now < finish then return now >= start, start, finish end
    end
    error("fenêtre introuvable") -- inatteignable : la semaine suivante est toujours à venir
end

-- Mois calendaire de Paris : identifiant année × 12 + mois - 1, début et fin UTC.
function ParisTime.Month(now: number): (number, number, number)
    local y, m = civilFromDays((now + ParisTime.Offset(now)) // DAY)
    local nextY, nextM = if m == 12 then y + 1 else y, if m == 12 then 1 else m + 1
    return y * 12 + m - 1, ParisTime.FromParis(daysFromCivil(y, m, 1) * DAY),
        ParisTime.FromParis(daysFromCivil(nextY, nextM, 1) * DAY)
end

return table.freeze(ParisTime)
