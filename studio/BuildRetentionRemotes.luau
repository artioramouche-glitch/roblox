--!nonstrict
--[[ BuildRetentionRemotes
     Rôle    : créer en Édition les remotes de l'étape 10 dans ReplicatedStorage.Remotes, comme les remotes existants.
     Doc     : GAME_MASTER_V2 G4 (ClaimQuest), G2 (Settings) ; PROMPT_EXECUTION_SABL_V4 §8.2 (remotes vides d'abord),
               §15.1 ; décisions 57 et 62
     Étape   : 10, lot A
     Dépend  : mode Édition ; ReplicatedStorage.Remotes
     Exposé  : bilan ; idempotent (rejouable sans doublon, mauvaise classe remplacée)
     Limite  : ne branche aucune logique : QuestService et SettingsService retrouvent ces remotes au démarrage.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = assert(ReplicatedStorage:FindFirstChild("Remotes"), "Remotes absent")

local NAMES = {"ClaimQuest", "SetSetting"}
local lines = {}
for _, name in ipairs(NAMES) do
    local existing = remotes:FindFirstChild(name)
    if existing and existing:IsA("RemoteFunction") then
        table.insert(lines, "[OK] " .. name .. " deja present")
    else
        if existing then existing:Destroy() end
        local remote = Instance.new("RemoteFunction")
        remote.Name = name
        remote.Parent = remotes
        table.insert(lines, "[CREE] " .. name)
    end
end
local output = table.concat(lines, "\n")
print(output)
return output
