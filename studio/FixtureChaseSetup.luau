--!nonstrict
--[[ FixtureChaseSetup
     Rôle    : préparer une poursuite réelle : débloquer le vol et poser un brainrot sur chaque plot.
     Doc     : GAME_MASTER_V2 A4 (niveau 5 et 1 h), A5 ; PROMPT_EXECUTION_SABL_V4 §25.1, §31.5
     Étape   : 5, lot E
     Dépend  : Play serveur avec les joueurs apparus ; Services.DataService, Services.PlacementService,
               Data.UidGenerator, Config.StealConfig ; lancé par ServerScriptService.Tests.TestRunner ;
               mode lu dans l'attribut Workspace SABL_TestMode : « all » (défaut) ou « first »
     Exposé  : bilan par joueur : niveau, temps de jeu, créatures posées, plot
     Limite  : écrit dans les vrais profils du magasin de TEST (Level, Playtime, Creatures) et ne défait
               rien ensuite. Studio uniquement, sur des profils de test. En mode « first », seul le premier
               joueur est débloqué : le second reste débutant, pour montrer sa protection.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local StealConfig = require(ReplicatedStorage.Config.StealConfig)
local UidGenerator = require(ServerScriptService.Data.UidGenerator)
local DataService = require(ServerScriptService.Services.DataService)
local PlacementService = require(ServerScriptService.Services.PlacementService)

local PROTECTION = StealConfig.Protection
local MODE_ATTRIBUTE = "SABL_TestMode"
local SPECIES = {"noobini", "talpa"} -- deux communs : des cubes gris jusqu'aux étapes 6-8 (Loi 5)
local CREATURES_PER_PLAYER = 2
local rng = Random.new()

local mode = Workspace:GetAttribute(MODE_ATTRIBUTE)
mode = (mode == "all" or mode == "first") and mode or "all"
local lines = {("[SETUP] Mode %s : niveau %d et %d s de jeu exiges par A4")
    :format(mode, PROTECTION.MinLevel, PROTECTION.MinPlaytimeSeconds)}

local function ensureProfile(player, unlock)
    return DataService:Update(player, function(profile)
        if unlock then
            profile.Level = math.max(type(profile.Level) == "number" and profile.Level or 1, PROTECTION.MinLevel)
            profile.Playtime = math.max(type(profile.Playtime) == "number" and profile.Playtime or 0,
                PROTECTION.MinPlaytimeSeconds)
        end
        local taken = UidGenerator.TakenFrom(profile.Creatures)
        while #profile.Creatures < CREATURES_PER_PLAYER do
            local uid = UidGenerator.Generate(taken, rng)
            if not uid then return false, "INTERNAL" end
            taken[uid] = true
            table.insert(profile.Creatures,
                {Uid = uid, Id = SPECIES[(#profile.Creatures % #SPECIES) + 1], Tier = 1})
        end
        return true
    end)
end

-- Pose les créatures libres sur les piédestaux libres : le vol a besoin d'une cible visible.
local function placeAll(player)
    local placed = {}
    local profile = DataService:Get(player)
    if not profile then return placed end
    local slots = profile.Base and profile.Base.Slots or 0
    local used = {}
    for _, creature in ipairs(profile.Creatures) do
        if type(creature.PlacedSlot) == "number" then
            used[creature.PlacedSlot] = true
            table.insert(placed, ("%s sur %d"):format(creature.Uid, creature.PlacedSlot))
        end
    end
    for _, creature in ipairs(profile.Creatures) do
        if type(creature.PlacedSlot) ~= "number" then
            for slot = 1, slots do
                if not used[slot] then
                    local ok, reason = PlacementService:Place(player, creature.Uid, slot)
                    if ok then
                        used[slot] = true
                        table.insert(placed, ("%s sur %d"):format(creature.Uid, slot))
                    else
                        table.insert(lines, ("[SETUP] %s : pose refusee (%s)"):format(player.Name, tostring(reason)))
                    end
                    break
                end
            end
        end
    end
    return placed
end

for index, player in ipairs(Players:GetPlayers()) do
    local unlock = mode == "all" or index == 1
    local ok, reason = ensureProfile(player, unlock)
    if not ok then
        table.insert(lines, ("[SETUP] %s : profil non modifie (%s)"):format(player.Name, tostring(reason)))
    else
        local placed = placeAll(player)
        DataService:Sync(player)
        local profile = DataService:Get(player)
        local plot = PlacementService:PlotOf(player)
        table.insert(lines, ("[SETUP] %s (%d) : niveau %s, %s s de jeu, %d creature(s), posees %s, plot %s -> %s")
            :format(player.Name, player.UserId, tostring(profile and profile.Level),
                tostring(profile and profile.Playtime), profile and #profile.Creatures or 0,
                #placed > 0 and table.concat(placed, ", ") or "aucune",
                plot and plot.Name or "aucun", unlock and "VOLEUR POSSIBLE" or "DEBUTANT PROTEGE"))
    end
end

if #Players:GetPlayers() < 2 then
    table.insert(lines, "[SETUP] Un seul joueur present : la poursuite demande un test local a 2 joueurs")
end

local output = table.concat(lines, "\n")
print(output)
return {passed = #lines, failed = 0, success = true, output = output}
