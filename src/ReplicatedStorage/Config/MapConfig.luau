--!strict
--[[ MapConfig
     Rôle    : centraliser les chiffres de la map du monde 1 : jour-nuit cosmétique et trampolines.
     Doc     : GAME_MASTER_V2 D1.1 (jour-nuit en 20 min, néons +50 % la nuit), D1.3 Z7, D1.4 (PROP_trampoline)
     Étape   : 8, lot C
     Dépend  : aucun
     Exposé  : configuration immuable ; ClockAt(serverTime), NeonFactorAt(clockTime)
     Limite  : module absent de G1, ajouté pour respecter la Loi 4 ; écart déclaré. Le doc ne chiffre ni
               le rebond ni les heures où les néons basculent : ces valeurs sont déclarées.
]]
local HOURS_PER_DAY = 24

local MapConfig = {
    DayNight = table.freeze({
        CycleSeconds = 20 * 60, -- D1.1 : le jour-nuit cosmétique tourne en 20 min
        NightNeonBoost = 1.5, -- D1.1 : à la tombée de la nuit, néons +50 % d'intensité
        DuskClock = 18, -- heure où les néons montent (déclarée)
        DawnClock = 6, -- heure où ils redescendent (déclarée)
    }),
    Trampoline = table.freeze({
        LaunchSpeed = 100, -- studs/s vers le haut : environ 25 studs de rebond sous la gravité standard (déclaré)
        CooldownSeconds = 0.25, -- un seul rebond par retombée
    }),
}

-- Heure du jour (ClockTime, de 0 à 24) à un instant du serveur : tous les clients voient la même.
function MapConfig.ClockAt(serverTime: number): number
    local cycle = MapConfig.DayNight.CycleSeconds
    return (serverTime % cycle) / cycle * HOURS_PER_DAY
end

-- Facteur d'intensité des néons : 1 le jour, NightNeonBoost la nuit.
function MapConfig.NeonFactorAt(clockTime: number): number
    local dayNight = MapConfig.DayNight
    local night = clockTime >= dayNight.DuskClock or clockTime < dayNight.DawnClock
    return if night then dayNight.NightNeonBoost else 1
end

return table.freeze(MapConfig)
