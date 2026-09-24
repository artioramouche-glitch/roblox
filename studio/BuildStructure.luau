--!strict
--[[ BuildStructure
     Rôle    : créer les dossiers G1 en mode Édition sans supprimer d'instance.
     Doc     : GAME_MASTER_V2 G1 ; PROMPT_EXECUTION_SABL_V4 §31.1 lot A
     Étape   : 1
     Dépend  : services Roblox et StarterPlayerScripts
     Exposé  : exécution manuelle dans Studio, pas de script de gameplay
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")

local starterScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(starterScripts, "StarterPlayerScripts absent")

type Entry = {parent: Instance, name: string}
local entries: {Entry} = {
    {parent = game:GetService("ReplicatedStorage"), name = "Config"},
    {parent = game:GetService("ReplicatedStorage"), name = "Remotes"},
    {parent = game:GetService("ReplicatedStorage"), name = "Shared"},
    {parent = game:GetService("ServerScriptService"), name = "Services"},
    {parent = starterScripts, name = "Controllers"},
    {parent = game:GetService("Workspace"), name = "ArenaInstances"},
    {parent = game:GetService("Workspace"), name = "Effects"},
    {parent = game:GetService("Workspace"), name = "Placeholders"},
    {parent = game:GetService("ServerStorage"), name = "CreatureModels"},
    {parent = game:GetService("ServerStorage"), name = "EggModels"},
    {parent = game:GetService("ServerStorage"), name = "BaseKit"},
    {parent = game:GetService("ServerStorage"), name = "ArenaKit"},
}

-- Vérifier tous les conflits avant la première écriture ; ne jamais remplacer.
for _, entry in ipairs(entries) do
    local count = 0
    for _, child in ipairs(entry.parent:GetChildren()) do
        if child.Name == entry.name then
            count += 1
            assert(child:IsA("Folder"), "Classe incompatible : " .. child:GetFullName())
        end
    end
    assert(count <= 1, "Doublon : " .. entry.parent:GetFullName() .. "." .. entry.name)
end

local created = 0
for _, entry in ipairs(entries) do
    if not entry.parent:FindFirstChild(entry.name) then
        local folder = Instance.new("Folder")
        folder.Name = entry.name
        folder.Parent = entry.parent
        created += 1
    end
end

local passed = 0
for _, entry in ipairs(entries) do
    local folder = entry.parent:FindFirstChild(entry.name)
    assert(folder and folder:IsA("Folder"), "Dossier manquant : " .. entry.name)
    passed += 1
end
print(("[STRUCTURE] %d created; %d preserved"):format(created, #entries - created))
print(("[TEST] Structure: %d OK / 0 FAIL"):format(passed))
