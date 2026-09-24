--!nonstrict
--[[ FixtureProfileBackup
     Rôle    : copier le profil du joueur dans une clé de sauvegarde du magasin de test, sans le modifier.
     Doc     : PROMPT_EXECUTION_SABL_V4 Loi 11, §25.1 ; suggestion du lot E de l'étape 9 (avant le rebirth réel)
     Étape   : 9, lot F
     Dépend  : Play serveur avec un joueur connecté ; Services.DataService, Packages.ProfileService,
               Data.ProfileStoreAdapter, Data.DataConfig, Shared.TableUtil ; lancé par le TestRunner
     Exposé  : bilan ; clé <StoreName>/Backup_<UserId> écrite, relue et comparée au profil vivant
     Limite  : le profil du joueur n'est que lu. Une restauration, si le Producer la demande, passera par une
               fixture à part, annoncée avant exécution.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local DataConfig = require(Server.Data.DataConfig)
local DataService = require(Server.Services.DataService)

local RELEASE_SECONDS = 15
local key = ("%s/Backup_%d"):format(DataConfig.StoreName, player.UserId)

local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for field, value in pairs(a) do if not equal(value, b[field]) then return false end end
    for field in pairs(b) do if a[field] == nil then return false end end
    return true
end

local live = assert(DataService:Get(player), "Profil du joueur absent")
local ok, same = pcall(function()
    local library = require(Server.Packages.ProfileService)
    local store = library.GetProfileStore({Name = DataConfig.StoreName, Scope = DataConfig.StoreScope}, {})
    local Adapter = require(Server.Data.ProfileStoreAdapter)
    local adapter = Adapter.new(store, {BindUserIds = false})
    local lease = assert(adapter:Acquire(key))
    assert(lease:Release(live))
    assert(adapter:AwaitPendingReleases(RELEASE_SECONDS))
    local reread = assert(adapter:Acquire(key))
    local copy = TableUtil.DeepCopy(reread.Data)
    reread:Release(nil)
    adapter:AwaitPendingReleases(RELEASE_SECONDS)
    return equal(copy, live)
end)
local creatures = type(live.Creatures) == "table" and #live.Creatures or 0
local output = ("[PROFILE BACKUP] cle %s : %s ; argent %.0f, %d brainrots, rebirths %d, version %s")
    :format(key, if not ok then "erreur : " .. tostring(same) elseif same then "relue identique au profil"
        else "relue DIFFERENTE", tonumber(live.Money) or 0, creatures, tonumber(live.Rebirths) or 0,
        tostring(live.DataVersion))
print(output)
return {passed = (ok and same) and 1 or 0, failed = (ok and same) and 0 or 1, success = ok and same == true,
    output = output}
