--!nonstrict
--[[ TestPersistence
     Rôle    : prouver l'auto-save et la persistance entre deux sessions Play distinctes.
     Doc     : GAME_MASTER_V2 G2/G4 ; PROMPT_EXECUTION_SABL_V4 §25 ; étape 2 lot D3 ; version 2 du schéma à l'étape 9, version 3 au lot F1 ;
               témoins adaptés au revenu passif au lot F2
     Dépend  : serveur Play, DataService réel, expérience de test autorisée ; ModuleScript temporaire lancé par
               le TestRunner (depuis le 15/09, l'outil ne peut plus placer de Script), attributs posés sur lui
     Exposé  : bilan (sortie du runner) et attributs ExpectedMoney/ExpectedTokens/UserId/Session sur le Script
     Usage   : Phase="Write" une seule fois ; arrêter Play puis Phase="Verify" avec
               ExpectedMoney, ExpectedTokens, ExpectedUserId, PreviousSession du premier bilan.
     Effets  : Write ajoute 123456 puis 1 Money et 42 puis 1 ArenaTokens au compte de test.
               Verify ne modifie aucun champ du profil. Aucun wipe ni restauration destructive.
     Limite  : le revenu passif et le coffre font monter l'argent pendant le test : il est comparé en « au
               moins » ; les tokens, que rien ne touche, à l'identique.
]]
local Server = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(Server.Data.DataConfig)
assert(RunService:IsServer() and RunService:IsRunning() and RunService:IsStudio(), "Server Play required")
assert(Config.Mode == "ProfileService" and Config.RealDataStoreEnabled, "Live mode required")
assert(game.GameId == Config.AllowedGameId and game.PlaceId == Config.AllowedPlaceId, "Wrong experience")
assert(Config.StoreName == "SABL_Test_v1" and Config.StoreScope == "Persistence_D3", "Wrong test store")
local phase = script:GetAttribute("Phase")
assert(phase == "Write" or phase == "Verify", "Explicit Write or Verify phase required")
local library = require(Server.Packages.ProfileService)
local okLive, live = pcall(library.IsLive)
assert(okLive and live == true, "Mock fallback is not a persistence test")
local D = require(Server.Services.DataService)
local deadline = os.clock() + 20
local player, profile
repeat
    player = Players:GetPlayers()[1]
    profile = player and D:Get(player)
    if profile then break end
    task.wait(0.2)
until os.clock() >= deadline
assert(player and profile, "Player profile did not load")
local session = Server:GetAttribute("SABL_PersistenceRun")
if not session then
    session = HttpService:GenerateGUID(false)
    Server:SetAttribute("SABL_PersistenceRun", session)
end
script:SetAttribute("Session", session)
script:SetAttribute("UserId", player.UserId)
local T = {pass=0,fail=0,lines={}}
local function check(name, callback)
    local ok, result = pcall(callback)
    local passed = ok and result == true
    if passed then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (passed and "[OK] " or "[FAIL] ") .. name
        .. (not ok and (" : " .. tostring(result)) or ""))
    return passed
end
local function equal(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
check("Real test store and loaded profile",function()
    return live and profile.DataVersion == 3
end)
local expectedMoney, expectedTokens
if phase == "Write" then
    assert(not Server:GetAttribute("SABL_PersistenceWriteStarted"), "Write already attempted in this Play session")
    Server:SetAttribute("SABL_PersistenceWriteStarted",true)
    local before = D:Get(player)
    expectedMoney, expectedTokens = before.Money+123456, before.PvP.ArenaTokens+42
    local written = check("Add witnesses without replacing existing balances",function()
        local ok = D:Update(player,function(p)
            p.Money += 123456
            p.PvP.ArenaTokens += 42
            return true
        end)
        local p=D:Get(player)
        return ok and p.Money>=expectedMoney and p.PvP.ArenaTokens==expectedTokens
    end)
    if written then
        -- Lecture seule du stockage : ne pas forcer Save() pour masquer un défaut d'auto-save.
        check("Auto-save persists both witnesses before release",function()
            local opened, store = pcall(library.GetProfileStore,
                {Name=Config.StoreName,Scope=Config.StoreScope},{})
            assert(opened and store, "Cannot open readback store")
            local untilTime=os.clock()+90
            repeat
                task.wait(8)
                local read, saved=pcall(store.ViewProfileAsync,store,D.KeyFor(player))
                if read and saved and saved.Data.Money>=expectedMoney
                    and saved.Data.PvP.ArenaTokens==expectedTokens then return true end
            until os.clock()>=untilTime
            return false
        end)
        local finalWrite = check("Stage final witnesses for shutdown",function()
            local ok = D:Update(player,function(p)
                p.Money += 1
                p.PvP.ArenaTokens += 1
                return true
            end)
            return ok == true
        end)
        if finalWrite then expectedMoney += 1 expectedTokens += 1 end
        check("All other profile data stays unchanged (fields kept by live services excepted)",function()
            local after=D:Get(player)
            after.Money=before.Money
            after.PvP.ArenaTokens=before.PvP.ArenaTokens
            -- Revenu, temps de jeu, niveau, présence et bouclier avancent seuls pendant le test.
            after.Stats.Earned=before.Stats.Earned
            for _,field in ipairs({"Playtime","Level","LastSeenAt","ShieldEndsAt","VulnerableEndsAt"}) do
                after[field]=before[field]
            end
            return equal(before,after)
        end)
    end
else
    expectedMoney = script:GetAttribute("ExpectedMoney")
    expectedTokens = script:GetAttribute("ExpectedTokens")
    assert(type(expectedMoney)=="number" and type(expectedTokens)=="number", "Expected witnesses required")
    check("Verification runs in a different Play session",function()
        local previous=script:GetAttribute("PreviousSession")
        return type(previous)=="string" and previous~=session
    end)
    check("Same test account after restart",function()
        return player.UserId==script:GetAttribute("ExpectedUserId")
    end)
    check("Money survives restart (at least the witness)",function() return profile.Money>=expectedMoney end)
    check("Nested ArenaTokens survive restart",function() return profile.PvP.ArenaTokens==expectedTokens end)
    check("Copies do not alter the loaded profile",function()
        local copy=D:Get(player)
        copy.Money=0 copy.PvP.ArenaTokens=0
        local p=D:Get(player)
        return p.Money>=expectedMoney and p.PvP.ArenaTokens==expectedTokens
    end)
end
script:SetAttribute("ExpectedMoney",expectedMoney)
script:SetAttribute("ExpectedTokens",expectedTokens)
table.insert(T.lines,("[PERSISTENCE %s] %d OK / %d FAIL"):format(string.upper(phase),T.pass,T.fail))
local witness=("[PERSISTENCE WITNESS] user=%d money=%.0f tokens=%.0f session=%s")
    :format(player.UserId,expectedMoney,expectedTokens,session)
print(table.concat(T.lines,"\n"))
print(witness)
return {passed=T.pass,failed=T.fail,success=T.fail==0,output=table.concat(T.lines,"\n").."\n"..witness}
