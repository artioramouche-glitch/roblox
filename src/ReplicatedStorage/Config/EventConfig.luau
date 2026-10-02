--!strict
--[[ EventConfig
     Rôle    : calendrier et effets des événements du lot C (Frénésie Minuit, Boss du Serveur, Pluie de Confettis,
               Week-end Chance) et combinaison des sources de chance.
     Doc     : GAME_MASTER_V2 C4, C3 (+10 % chance) ; PROMPT_EXECUTION_SABL_V4 §31.10 lot C ; décision 59 ;
               Q1-Q3 du lot C (02/10, options A)
     Étape   : 10, lot C (configuration seule)
     Dépend  : aucun
     Exposé  : configuration immuable ; Frenzy, Boss, Confetti, Weekend, LuckCap ;
               FrenzyAt(now), BossAt(now), ConfettiAt(now), WeekendAt(now) → actif ?, début, fin (l'occurrence en
               cours, sinon la prochaine) ; LuckMultiplier(now, rebirthBonus)
     Limite  : module absent de G1, comme EconomyConfig ; écart déclaré. Toutes les horloges sont en UTC (Q1) : le
               calendrier est le même sur tous les serveurs. La minute de chaque pluie est tirée d'un brassage du
               numéro de sa tranche : fixe pour la tranche, sur tous les serveurs et après un redémarrage.
               La récompense du Boss attend sa question ; Double Colisée (C4) viendra avec l'arène (étape 13).
]]
local EventConfig = {}

local DAY = 86400

-- C4 : toutes les 3 h pendant 15 min, chance ×10 sur tous les œufs. Q1 : à 0 h, 3 h, 6 h… UTC.
EventConfig.Frenzy = table.freeze({Period = 3 * 3600, Duration = 15 * 60, Luck = 10})
-- C4 : toutes les 2 h pendant 5 min. Q1 : à 0 h, 2 h, 4 h… UTC.
EventConfig.Boss = table.freeze({Period = 2 * 3600, Duration = 5 * 60})
-- C4 : 10 min de revenus ×2 ; Q2 : une pluie par tranche de 4 h, à une minute tirée au hasard.
EventConfig.Confetti = table.freeze({Window = 4 * 3600, Duration = 10 * 60, IncomeMult = 2})
-- C4 : samedi-dimanche, 48 h, chance ×2. Q1 : du samedi 0 h au lundi 0 h UTC ; Phase = premier samedi après
-- le 1er janvier 1970 (un jeudi), à 0 h UTC.
EventConfig.Weekend = table.freeze({Period = 7 * DAY, Duration = 2 * DAY, Phase = 2 * DAY, Luck = 2})
-- Décision 59 : la chance ne pousse le palier le plus rare d'un œuf que jusqu'à 50 % (en points, comme les odds).
EventConfig.LuckCap = 50

-- Occurrence d'un événement périodique : en cours (true, début, fin), sinon la prochaine (false, début, fin).
local function periodic(now: number, period: number, duration: number, phase: number): (boolean, number, number)
    local start = math.floor((now - phase) / period) * period + phase
    if now < start + duration then return true, start, start + duration end
    return false, start + period, start + period + duration
end

function EventConfig.FrenzyAt(now: number): (boolean, number, number)
    return periodic(now, EventConfig.Frenzy.Period, EventConfig.Frenzy.Duration, 0)
end

function EventConfig.BossAt(now: number): (boolean, number, number)
    return periodic(now, EventConfig.Boss.Period, EventConfig.Boss.Duration, 0)
end

function EventConfig.WeekendAt(now: number): (boolean, number, number)
    local weekend = EventConfig.Weekend
    return periodic(now, weekend.Period, weekend.Duration, weekend.Phase)
end

-- (a × b) mod 2^32 sans dépasser les 53 bits exacts d'un nombre Luau.
local function mul32(a: number, b: number): number
    return (a % 65536 * b + (a // 65536 * b) % 65536 * 65536) % 4294967296
end

-- Brassage fmix32 de MurmurHash3 : deux tranches voisines donnent des minutes sans rapport.
local function mix32(h: number): number
    h = bit32.bxor(h, bit32.rshift(h, 16))
    h = mul32(h, 0x85EBCA6B)
    h = bit32.bxor(h, bit32.rshift(h, 13))
    h = mul32(h, 0xC2B2AE35)
    return bit32.bxor(h, bit32.rshift(h, 16))
end

-- Début de la pluie de la tranche `slot` : une minute entre le début de la tranche et 10 min avant sa fin.
local function confettiStart(slot: number): number
    local confetti = EventConfig.Confetti
    local minutes = (confetti.Window - confetti.Duration) // 60 + 1
    return slot * confetti.Window + mix32(slot % 4294967296) % minutes * 60
end

function EventConfig.ConfettiAt(now: number): (boolean, number, number)
    local confetti = EventConfig.Confetti
    local slot = math.floor(now / confetti.Window)
    local start = confettiStart(slot)
    if now >= start + confetti.Duration then start = confettiStart(slot + 1) end
    return now >= start, start, start + confetti.Duration
end

-- Q3 : les sources de chance se multiplient (Frénésie ×10, Week-end ×2, rebirths 1 + bonus de RebirthConfig).
function EventConfig.LuckMultiplier(now: number, rebirthBonus: any): number
    local multiplier = 1
    if type(rebirthBonus) == "number" and rebirthBonus > 0 and rebirthBonus < math.huge then
        multiplier = 1 + rebirthBonus
    end
    if EventConfig.FrenzyAt(now) then multiplier *= EventConfig.Frenzy.Luck end
    if EventConfig.WeekendAt(now) then multiplier *= EventConfig.Weekend.Luck end
    return multiplier
end

return table.freeze(EventConfig)
