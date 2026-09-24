--!strict
--[[ ProgressionConfig
     Rôle    : fixer le rythme de montée de niveau, déduit du temps de jeu cumulé.
     Doc     : GAME_MASTER_V2 G2 (Playtime, Level), A4 (niveau 5 ET 1 h), C1, D1.3 Z4 et E1 (Colisée)
     Étape   : 5, lot B1
     Dépend  : Config.DefaultProfile (niveau de départ G2)
     Exposé  : configuration immuable ; LevelFor(playtimeSeconds)
     Limite  : module absent de G1 ; le doc ne décrit aucune progression de niveau.
               Pas de 450 s validé par le Producer (Q1) : niveau 5 à 30 min de jeu.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DefaultProfile = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("DefaultProfile"))

local ProgressionConfig = {
    StartLevel = DefaultProfile.Level, -- G2 : Level = 1
    LevelStepSeconds = 450, -- Q1 : un niveau toutes les 7 min 30 s de jeu
}

-- Niveau atteint après un temps de jeu donné ; une valeur invalide rend le niveau de départ.
function ProgressionConfig.LevelFor(playtimeSeconds: any): number
    if type(playtimeSeconds) ~= "number" or playtimeSeconds ~= playtimeSeconds
        or math.abs(playtimeSeconds) == math.huge or playtimeSeconds < 0 then
        return ProgressionConfig.StartLevel
    end
    return ProgressionConfig.StartLevel + math.floor(playtimeSeconds / ProgressionConfig.LevelStepSeconds)
end

return table.freeze(ProgressionConfig)
