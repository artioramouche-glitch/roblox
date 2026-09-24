--!strict
--[[ StealConfig
     Rôle    : centraliser les chiffres du vol et de la défense des bases.
     Doc     : GAME_MASTER_V2 A4 (cycle de la cible), A5 (générateur de bouclier) ;
               PROMPT_EXECUTION_SABL_V4 §16.6, §31.5
     Étape   : 5, lot A (section Shield) ; lot B2 (Protection, Thief, Drop) ; lot B3 (Buyback) ;
               étape 9, lot F2 (Defense : tourelle et piège), lot F3 (seuils de l'alarme)
     Dépend  : aucun
     Exposé  : configuration immuable ; GetShieldSeconds(generatorLevel),
               GetAlertSeconds(), GetVulnerableSeconds(), GetBuybackWindowSeconds(),
               TurretHitChance(level)
     Limite  : module absent de G1, ajouté pour respecter la Loi 4 ; écart déclaré.
               Q2 tranchée par le GO du Producer (option A) : aucun bouclier sans générateur.
]]
local SECONDS_PER_MINUTE = 60

local StealConfig = {
    Shield = table.freeze({
        -- A5 : protection 5 / 6 / 7 min aux niveaux 1 / 2 / 3 du générateur.
        -- Le niveau 0 n'a pas d'entrée : pas de bouclier (Q2, option A).
        -- L'option B consisterait à ajouter [0] = 5, sans toucher au service.
        MinutesByGenerator = table.freeze({[1] = 5, [2] = 6, [3] = 7}),
        AlertSeconds = 60, -- A4 : ALERTE, le dôme clignote rouge
        VulnerableMinutes = 8, -- A4 : VULNÉRABLE, seule phase où le vol est possible
    }),
    Protection = table.freeze({
        MinLevel = 5, -- A4 : ni voler ni être volé avant le niveau 5...
        MinPlaytimeSeconds = 3600, -- A4 : ... ET 1 h de jeu cumulé
    }),
    Thief = table.freeze({
        CarrySpeedPenalty = 0.30, -- A4 : vitesse -30 % pendant le portage
        CarryTimeoutSeconds = 60, -- A4 : timeout du portage
        HitsToDrop = 3, -- A4 : 3 coups reçus = lâché
        SecureHoldSeconds = 5, -- A4 : pose 5 s sur son piédestal
        ThiefCooldownSeconds = 60, -- A4 : cooldown par voleur
        TargetCooldownSeconds = 30, -- A4 : cooldown par cible
        SecretCooldownMultiplier = 3, -- A4 : un Secret coûte 3× le cooldown au voleur
        HitRangeStuds = 12, -- G4 : HitThief à moins de 12 studs
        HitCooldownSeconds = 1, -- Q4 option A : 1 coup/s par frappeur (cadence de la tourelle A5)
        InteractRangeStuds = 12, -- écart : portée de HitThief reprise pour voler, poser et ramasser
    }),
    Drop = table.freeze({
        OwnerPrioritySeconds = 10, -- G4 : propriétaire prioritaire 10 s
        GroundSeconds = 60, -- Q5 option A : retour automatique après 60 s au sol
    }),
    Buyback = table.freeze({
        PriceMultiplier = 1.5, -- A4 : rachat du brainrot volé au prix ×1.5 (Q6 : prix de vente G4)
        WindowMinutes = 10, -- A4 : disponible 10 min
    }),
    Defense = table.freeze({
        TurretRangeStuds = 30, -- A5 : la tourelle tire sur les voleurs à 30 studs...
        TurretShotSeconds = 1, -- A5 : ... à raison d'un tir par seconde
        TurretHitChancePerLevel = 0.15, -- Q4 option A (décision 42) : 15 % par niveau, 75 % au niveau 5
        TurretMaxLevel = 5, -- A5 : tourelle 1 → 5
        TrapSlowFactor = 0.5, -- A5 : le piège à colle ralentit le voleur de 50 %...
        TrapSlowSeconds = 5, -- A5 : ... pendant 5 s ; Q5 option A : une plaque par niveau, une fois par portage
        TrapStandHeight = 8, -- technique : hauteur au-dessus d'une plaque où le voleur compte comme dessus
        -- Q5 option A (décision 43) : l'alarme ajoute un effet par niveau, vu par tout le serveur.
        AlarmMessageLevel = 1, -- message à tout le serveur
        AlarmHighlightLevel = 2, -- + voleur surligné pour tous
        AlarmArrowLevel = 3, -- + flèche vers le voleur pour tous
    }),
}

-- Q4, option A : un tir de tourelle touche avec une chance de 15 % par niveau (0 sans tourelle).
function StealConfig.TurretHitChance(level: any): number
    if type(level) ~= "number" or level ~= level or level < 1 then return 0 end
    local defense = StealConfig.Defense
    return defense.TurretHitChancePerLevel * math.min(math.floor(level), defense.TurretMaxLevel)
end

-- Durée du bouclier pour un niveau de générateur ; nil si ce niveau ne protège pas.
function StealConfig.GetShieldSeconds(generatorLevel: any): number?
    if type(generatorLevel) ~= "number" or generatorLevel ~= generatorLevel or generatorLevel % 1 ~= 0 then
        return nil
    end
    local minutes = StealConfig.Shield.MinutesByGenerator[generatorLevel]
    if minutes == nil then return nil end
    return minutes * SECONDS_PER_MINUTE
end

function StealConfig.GetAlertSeconds(): number
    return StealConfig.Shield.AlertSeconds
end

function StealConfig.GetVulnerableSeconds(): number
    return StealConfig.Shield.VulnerableMinutes * SECONDS_PER_MINUTE
end

function StealConfig.GetBuybackWindowSeconds(): number
    return StealConfig.Buyback.WindowMinutes * SECONDS_PER_MINUTE
end

return table.freeze(StealConfig)
