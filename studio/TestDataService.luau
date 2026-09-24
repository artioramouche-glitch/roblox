--!nonstrict
--[[ TestDataService
     Rôle    : tester le cycle mémoire avec des profils fictifs isolés du service du jeu.
     Doc     : GAME_MASTER_V2 G2/G4 ; étape 2 lot D1 ; schéma en version 2 à l'étape 9, lot C, en version 3 au lot F1 ;
               contrôle du stockage aligné sur le lot D3 à l'étape 9, lot D (dette 18)
     Dépend  : serveur Play, un joueur connecté, Services.DataService
     Exposé  : bilan ; aucun DataStore ni ProfileService chargé par ces tests
     Exécution : après le démarrage de Main et le chargement du joueur, copier ce
                 contenu dans un Script temporaire sous ServerScriptService du
                 serveur Play, jamais dans le modèle Édition.
                 Le Script doit partager le contexte require de Main : l'exécution
                 directe par MCP peut charger une autre instance du module.
                 L'arrêt du Play retire le Script temporaire ; ne pas sauvegarder
                 ce test comme Script de démarrage du jeu.
]]
local Server = game:GetService("ServerScriptService")
local player = assert(game:GetService("Players"):GetPlayers()[1], "Joueur de test requis")
local D = require(Server.Services.DataService)
local Config = require(Server.Data.DataConfig)
local key = D.KeyFor(player)
local T = {pass=0,fail=0,lines={}}
local services = {}
local function track(s) table.insert(services,s) return s end
local function check(name, callback)
    local ok, result = pcall(callback)
    local passed = ok and result == true
    for _,s in ipairs(services) do
        local closeOK, closed = pcall(s.Stop,s)
        if not closeOK or not closed then passed = false end
    end
    table.clear(services)
    if passed then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines,(passed and "[OK] " or "[FAIL] ") .. name
        .. (not ok and (" : " .. tostring(result)) or ""))
end
local function fixture(store)
    local f = {now=0, sent={}, store=store or D.CreateMemoryStore()}
    f.service = track(D.new({Store=f.store, Clock=function() return f.now end,
        SendProfile=function(p,snapshot)
            assert(p == player)
            if f.sendHook then f.sendHook(snapshot) end
            table.insert(f.sent,snapshot)
        end}))
    return f
end
local function refused(method, object, code, ...)
    local ok, reason = method(object,...)
    return ok == false and reason == code
end
local function addMoney(profile) profile.Money += 7 return true,"OK" end

-- Les fixtures ci-dessous utilisent toujours des magasins mémoire ; le jeu, lui, tourne en mémoire (lot D1)
-- ou sur le magasin de test ProfileService (lot D3), jamais sur un autre magasin.
check("Approved storage (memory, or the ProfileService test store) with one-second synchronization",function()
    local memory = Config.Mode == "Memory" and Config.RealDataStoreEnabled == false
    local testStore = Config.Mode == "ProfileService" and Config.RealDataStoreEnabled == true
        and Config.StoreName == "SABL_Test_v1" and Config.StoreScope == "Persistence_D3"
    return (memory or testStore) and Config.SyncIntervalSeconds == 1
end)
check("Main loads a default profile and exposes a guarded reader",function()
    return D:Get(player) ~= nil and D.Guard ~= nil
end)
check("Missing profile denied before load",function()
    local f = fixture()
    return f.service:Get(player) == nil and refused(f.service.Update,f.service,"NO_PROFILE",player,addMoney)
end)
check("New profile has G2 defaults and version 3",function()
    local f = fixture() assert(f.service:Load(player))
    local p = f.service:Get(player)
    return p.Money == 0 and p.Base.Slots == 3 and p.DataVersion == 3 and p.PvP.Elo1v1 == 1000
end)
check("Get returns an independent snapshot",function()
    local f = fixture() assert(f.service:Load(player))
    local copy = f.service:Get(player) copy.Base.Slots = 25
    return f.service:Get(player).Base.Slots == 3
end)
check("Duplicate load rejected",function()
    local f = fixture() assert(f.service:Load(player))
    return refused(f.service.Load,f.service,"ALREADY_LOADED",player)
end)
check("Successful update commits a copy, not callback aliases",function()
    local f = fixture() assert(f.service:Load(player))
    local retained
    assert(f.service:Update(player,function(p) p.Money=77 retained=p return true,p end))
    retained.Money = 999
    return f.service:Get(player).Money == 77
end)
check("Business refusal discards candidate edits",function()
    local f = fixture() assert(f.service:Load(player))
    local ok = refused(f.service.Update,f.service,"NOT_ENOUGH_MONEY",player,function(p)
        p.Money = 999 return false,"NOT_ENOUGH_MONEY"
    end)
    return ok and f.service:Get(player).Money == 0
end)
check("Update exception rolls back candidate",function()
    local f = fixture() assert(f.service:Load(player))
    local ok = refused(f.service.Update,f.service,"INTERNAL",player,function(p)
        p.Money = 999 error("synthetic failure")
    end)
    return ok and f.service:Get(player).Money == 0
end)
check("Invalid schema cannot be committed",function()
    local f = fixture() assert(f.service:Load(player))
    local ok = refused(f.service.Update,f.service,"INCOMPATIBLE_PROFILE",player,function(p)
        p.Money = "bad" return true
    end)
    return ok and f.service:Get(player).Money == 0
end)
check("Reentrant update is refused while outer update completes",function()
    local f = fixture() assert(f.service:Load(player))
    local blocked = false
    assert(f.service:Update(player,function(p)
        blocked = refused(f.service.Update,f.service,"BUSY",player,addMoney)
        p.Money = 1 return true
    end))
    return blocked and f.service:Get(player).Money == 1
end)
check("Release and reload preserve scalar and nested values in memory",function()
    local f = fixture() assert(f.service:Load(player))
    assert(f.service:Update(player,function(p) p.Money=123456 p.PvP.ArenaTokens=42 return true end))
    assert(f.service:Release(player))
    assert(f.service:Get(player) == nil and not f.store:IsLocked(key))
    assert(f.service:Load(player))
    local p=f.service:Get(player)
    return p.Money == 123456 and p.PvP.ArenaTokens == 42
end)
check("Fresh memory store has no previous session data",function()
    local a=fixture() assert(a.service:Load(player)) assert(a.service:Update(player,addMoney))
    assert(a.service:Release(player))
    local b=fixture() assert(b.service:Load(player))
    return b.service:Get(player).Money == 0
end)
check("Two services cannot acquire the same in-process lease",function()
    local store=D.CreateMemoryStore()
    local a,b=fixture(store),fixture(store)
    assert(a.service:Load(player))
    assert(refused(b.service.Load,b.service,"SESSION_LOCKED",player))
    assert(a.service:Release(player))
    return b.service:Load(player) == true
end)
check("Legacy fields migrated without modifying original record before release",function()
    local old={Money=17,PvP={ArenaTokens=8},Custom={Value="keep"}}
    local store=D.CreateMemoryStore({[key]=old})
    local f=fixture(store) assert(f.service:Load(player))
    local p=f.service:Get(player)
    return p.DataVersion == 3 and p.Money == 17 and p.PvP.ArenaTokens == 8
        and p.Custom.Value == "keep" and old.DataVersion == nil and store:Peek(key).DataVersion == nil
end)
check("Future version refused without overwrite or leaked lease",function()
    local store=D.CreateMemoryStore({[key]={DataVersion=4,Money=81}})
    local f=fixture(store)
    return refused(f.service.Load,f.service,"FUTURE_VERSION",player) and not store:IsLocked(key)
        and store:Peek(key).DataVersion == 4 and store:Peek(key).Money == 81
end)
check("Malformed saved profile refused without overwrite",function()
    local store=D.CreateMemoryStore({[key]={Money="bad"}}) local f=fixture(store)
    return refused(f.service.Load,f.service,"INCOMPATIBLE_PROFILE",player)
        and store:Peek(key).Money == "bad" and not store:IsLocked(key)
end)
check("Acquire exception contained",function()
    local f=fixture({Acquire=function() error("synthetic failure") end})
    return refused(f.service.Load,f.service,"LOAD_FAILED",player) and f.service:Get(player) == nil
end)
check("Cancellation during acquire releases lease without saving",function()
    local store=D.CreateMemoryStore() local service
    local f=fixture({Acquire=function(_,k) service:Release(player) return store:Acquire(k) end})
    service=f.service
    return refused(service.Load,service,"CANCELLED",player) and not store:IsLocked(key) and store:Peek(key) == nil
end)
check("Stop during acquire releases pending lease",function()
    local store=D.CreateMemoryStore() local service
    local f=fixture({Acquire=function(_,k) service:Stop() return store:Acquire(k) end})
    service=f.service
    return refused(service.Load,service,"CANCELLED",player) and not store:IsLocked(key)
end)
check("Release failure retains data for retry",function()
    local store=D.CreateMemoryStore() local fail=true
    local f=fixture({Acquire=function(_,k)
        local lease=store:Acquire(k)
        return {Data=lease.Data, IsActive=function() return lease:IsActive() end,
            Commit=function(_,data) return lease:Commit(data) end,
            Release=function(_,data) if fail then fail=false return false end return lease:Release(data) end}
    end})
    assert(f.service:Load(player)) assert(f.service:Update(player,addMoney))
    assert(refused(f.service.Release,f.service,"RELEASE_FAILED",player))
    assert(f.service:Get(player).Money == 7)
    return f.service:Release(player) and store:Peek(key).Money == 7
end)
check("Release during update cancels candidate and saves previous state",function()
    local f=fixture() assert(f.service:Load(player))
    local ok=refused(f.service.Update,f.service,"CANCELLED",player,function(p)
        p.Money=999 assert(f.service:Release(player)) return true
    end)
    return ok and f.store:Peek(key).Money == 0
end)
check("Sync is throttled; latest update sent at next window",function()
    local f=fixture() assert(f.service:Load(player))
    assert(#f.sent == 1) assert(f.service:Update(player,addMoney))
    assert(refused(f.service.Sync,f.service,"THROTTLED",player))
    f.now=0.999 f.service:Step() assert(#f.sent == 1)
    f.now=1 f.service:Step()
    return #f.sent == 2 and f.sent[2].Money == 7
end)
check("Transport receives an independent copy",function()
    local f=fixture() f.sendHook=function(p) p.Money=999 end
    assert(f.service:Load(player))
    return f.service:Get(player).Money == 0
end)
check("Sync exception is contained and retry remains possible",function()
    local f=fixture() f.sendHook=function() error("synthetic transport failure") end
    assert(f.service:Load(player))
    assert(refused(f.service.Sync,f.service,"SYNC_FAILED",player))
    f.sendHook=nil
    return f.service:Sync(player) and #f.sent == 1
end)
check("Guard follows loaded and released profile readiness",function()
    local f=fixture() local calls=0
    local callback=f.service.Guard:Wrap("BuyEgg",function() calls+=1 return true,"OK" end)
    assert(callback(player) == false)
    assert(f.service:Load(player)) assert(callback(player))
    assert(f.service:Release(player))
    local ok,reason=callback(player)
    return ok == false and reason == "NO_PROFILE" and calls == 1
end)
check("Stop is idempotent, releases records and closes guard",function()
    local f=fixture() assert(f.service:Load(player)) assert(f.service:Update(player,addMoney))
    local callback=f.service.Guard:Wrap("BuyEgg",function() return true end)
    assert(f.service:Stop()) assert(f.service:Stop())
    return not f.store:IsLocked(key) and f.store:Peek(key).Money == 7 and f.service:Get(player) == nil
        and callback(player) == false and refused(f.service.Load,f.service,"UNAVAILABLE",player)
end)
table.insert(T.lines,("[DATA MEMORY TEST] %d OK / %d FAIL"):format(T.pass,T.fail))
local output=table.concat(T.lines,"\n")
print(output)
return {passed=T.pass,failed=T.fail,success=T.fail == 0,output=output}
