--!nonstrict
--[[ TestProfileStoreAdapter
     Rôle    : vérifier l'adaptateur et DataService avec un faux ProfileStore déterministe.
     Doc     : GAME_MASTER_V2 G1/G2 ; étape 2 lot D2
     Dépend  : Script temporaire serveur Play, Data.ProfileStoreAdapter, Services.DataService
     Exposé  : bilan ; aucun require de Packages.ProfileService, aucun DataStore réel
]]
local Server = game:GetService("ServerScriptService")
local Adapter = require(Server.Data.ProfileStoreAdapter)
local D = require(Server.Services.DataService)
local Copy = require(game:GetService("ReplicatedStorage").Shared.TableUtil).DeepCopy
local player = assert(game:GetService("Players"):GetPlayers()[1], "Joueur de test requis")
local T = {pass=0, fail=0, lines={}}
local cleanup = {}
local function check(name, callback)
    local ok, result = pcall(callback)
    local passed = ok and result == true
    for _, service in ipairs(cleanup) do
        local stopped, success = pcall(service.Stop, service)
        if not stopped or success ~= true then passed = false end
    end
    table.clear(cleanup)
    if passed then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (passed and "[OK] " or "[FAIL] ") .. name
        .. (not ok and (" : " .. tostring(result)) or ""))
end

local function fake(initial)
    local f = {time=0, loads=0, releases=0, saves=0, profiles={}, records={}, store={}}
    function f.store:LoadProfileAsync(key, conflictHandler)
        f.loads += 1
        if f.loadError then error("synthetic load failure") end
        if f.conflict then f.conflictResult=conflictHandler(1,"other-session") return nil end
        if f.noProfile then return nil end
        local profile = {Data=Copy(f.records[key] or initial or {}), active=true,
            releaseListeners={}, hopListeners={}}
        f.latest = profile
        table.insert(f.profiles, profile)
        function profile:IsActive() return self.active end
        function profile:AddUserId(userId) self.boundUserId = userId end
        function profile:ListenToRelease(listener) table.insert(self.releaseListeners, listener) end
        function profile:ListenToHopReady(listener) table.insert(self.hopListeners, listener) end
        function profile:AutoSave()
            assert(self.active)
            f.records[key] = Copy(self.Data)
            f.saves += 1
        end
        function profile:CompleteRelease()
            if self.completed then return end
            f.records[key] = Copy(self.Data)
            f.saves += 1
            self.completed = true
            for _, listener in ipairs(self.hopListeners) do listener() end
        end
        function profile:Release()
            if f.releaseError then error("synthetic release failure") end
            if not self.active then return end
            self.active = false
            f.releases += 1
            for _, listener in ipairs(self.releaseListeners) do listener() end
            if not f.defer then self:CompleteRelease() end
        end
        if f.onLoad then f.onLoad(profile) end
        return profile
    end
    f.adapter = Adapter.new(f.store, {
        Clock=function() return f.time end,
        Wait=function()
            f.time += 1
            if f.completeAt and f.time >= f.completeAt then
                for _, profile in ipairs(f.profiles) do
                    if not profile.active then profile:CompleteRelease() end
                end
            end
        end,
    })
    return f
end
local function serviceFixture(initial)
    local f = fake(initial)
    f.service = D.new({Store=f.adapter, SendProfile=function() end})
    table.insert(cleanup, f.service)
    return f
end

check("Construction never loads a profile", function()
    local f=fake()
    return f.loads==0 and f.saves==0
end)
check("Explicit injected store is required", function()
    return not pcall(Adapter.new,nil) and not pcall(Adapter.new,{})
end)
check("Acquire copies data and preserves the key", function()
    local f=fake({Money=7, Nested={Value=3}})
    local lease=assert(f.adapter:Acquire("Player_test"))
    lease.Data.Nested.Value=9
    return f.latest.Data.Nested.Value==3 and lease:IsActive() and f.loads==1
end)
check("Duplicate acquisition does not call the backing store twice", function()
    local f=fake()
    assert(f.adapter:Acquire("k"))
    local lease,reason=f.adapter:Acquire("k")
    return lease==nil and reason=="SESSION_LOCKED" and f.loads==1
end)
check("Concurrent acquisition is refused before the first load returns", function()
    local f=fake() local refused=false
    f.onLoad=function()
        local lease,reason=f.adapter:Acquire("k")
        refused=lease==nil and reason=="SESSION_LOCKED"
    end
    assert(f.adapter:Acquire("k"))
    return refused and f.loads==1
end)
check("Session conflict cancels rather than forcing a load", function()
    local f=fake() f.conflict=true
    local lease,reason=f.adapter:Acquire("k")
    return lease==nil and reason=="SESSION_LOCKED" and f.conflictResult=="Cancel"
end)
check("Load errors and nil results allow a retry", function()
    local f=fake() f.loadError=true
    local a,reason=f.adapter:Acquire("k")
    assert(a==nil and reason=="LOAD_FAILED")
    f.loadError=false f.noProfile=true
    assert(f.adapter:Acquire("k")==nil)
    f.noProfile=false
    return f.adapter:Acquire("k")~=nil
end)
check("Invalid keys do not reach the backing store", function()
    local f=fake()
    return f.adapter:Acquire(12)==nil and f.adapter:Acquire("")==nil and f.loads==0
end)
check("Commit feeds auto-save before release, without forcing a save", function()
    local f=fake() local lease=assert(f.adapter:Acquire("k"))
    local data={Money=123456,PvP={ArenaTokens=42}}
    assert(lease:Commit(data))
    data.PvP.ArenaTokens=999
    assert(f.saves==0 and f.releases==0 and f.latest.Data.PvP.ArenaTokens==42)
    f.latest:AutoSave()
    return f.records.k.Money==123456 and f.records.k.PvP.ArenaTokens==42
end)
check("Non-serializable commits leave auto-save data intact", function()
    local f=fake({Money=7}) local lease=assert(f.adapter:Acquire("k"))
    local cycle={} cycle.Self=cycle
    local invalid={
        {Money=0/0}, {Money=math.huge}, {Value=function() end}, {Value=workspace},
        {Value={[2]="gap"}}, {Value={[1]="array",Name="mixed"}},
        {Value={[-1]="negative"}}, {Value=cycle}, {Value=string.char(255)},
        {Value=setmetatable({},{})},
    }
    for _, data in ipairs(invalid) do
        local ok,reason=lease:Commit(data)
        assert(ok==false and reason=="UNSERIALIZABLE_PROFILE")
        assert(f.latest.Data.Money==7)
    end
    return f.saves==0
end)
check("Dense arrays, empty tables and dictionaries are preserved", function()
    local f=fake() local lease=assert(f.adapter:Acquire("k"))
    assert(lease:Commit({Creatures={{Uid="a"},{Uid="b"}},Empty={},Settings={Music=false}}))
    return f.latest.Data.Creatures[2].Uid=="b" and f.latest.Data.Settings.Music==false
end)
check("Release nil does not reconcile or overwrite the original", function()
    local f=fake({DataVersion=9,Money=81,Custom={Value="keep"}})
    local lease=assert(f.adapter:Acquire("k"))
    lease.Data.Money=999
    assert(lease:Release(nil))
    return f.records.k.Money==81 and f.records.k.DataVersion==9
        and f.records.k.Custom.Value=="keep" and f.adapter:AwaitPendingReleases(0)
end)
check("Release is idempotent and commits no further data", function()
    local f=fake() local lease=assert(f.adapter:Acquire("k"))
    assert(lease:Release({Money=8}))
    assert(lease:Release({Money=999}))
    return f.releases==1 and f.records.k.Money==8 and not lease:IsActive()
end)
check("Release exception keeps the session available for retry", function()
    local f=fake() local lease=assert(f.adapter:Acquire("k"))
    f.releaseError=true
    assert(lease:Release({Money=7})==false and lease:IsActive())
    f.releaseError=false
    return lease:Release({Money=7}) and f.records.k.Money==7
end)
check("Release acceptance is not mistaken for save completion", function()
    local f=fake() f.defer=true
    local lease=assert(f.adapter:Acquire("k"))
    assert(lease:Release({Money=7}))
    local ok,reason=f.adapter:AwaitPendingReleases(2)
    assert(not ok and reason=="RELEASE_TIMEOUT" and f.saves==0)
    f.latest:CompleteRelease()
    return f.adapter:AwaitPendingReleases(0) and f.records.k.Money==7
end)
check("Shutdown wait completes when HopReady arrives", function()
    local f=fake() f.defer=true f.completeAt=3
    local lease=assert(f.adapter:Acquire("k"))
    assert(lease:Release({Money=7}))
    return f.adapter:AwaitPendingReleases(5) and f.time==3
end)
check("Late release notifications cannot remove a newer session", function()
    local f=fake() local old=assert(f.adapter:Acquire("k"))
    local oldProfile=f.latest
    assert(old:Release(nil))
    local current=assert(f.adapter:Acquire("k"))
    for _, listener in ipairs(oldProfile.releaseListeners) do listener() end
    return current:IsActive() and f.adapter:Acquire("k")==nil
end)
check("Expired profiles cannot accept commits", function()
    local f=fake({Money=7}) local lease=assert(f.adapter:Acquire("k"))
    f.latest:Release()
    return lease:Commit({Money=999})==false and f.records.k.Money==7
end)
check("DataService commits defaults and migrations before first auto-save", function()
    local f=serviceFixture({Money=17,PvP={ArenaTokens=8},Custom={Value="keep"}})
    assert(f.service:Load(player))
    local p=f.latest.Data
    assert(p.DataVersion==1 and p.Base.Slots==3 and p.Money==17 and p.Custom.Value=="keep")
    f.latest:AutoSave()
    return f.records[D.KeyFor(player)].PvP.ArenaTokens==8
end)
check("DataService updates feed auto-save immediately with no aliases", function()
    local f=serviceFixture() assert(f.service:Load(player))
    local retained
    assert(f.service:Update(player,function(p)
        p.Money=123456 p.PvP.ArenaTokens=42 retained=p return true
    end))
    retained.PvP.ArenaTokens=999
    f.latest:AutoSave()
    return f.records[D.KeyFor(player)].Money==123456 and f.records[D.KeyFor(player)].PvP.ArenaTokens==42
end)
check("Business refusal leaves the auto-save candidate unchanged", function()
    local f=serviceFixture() assert(f.service:Load(player))
    assert(f.service:Update(player,function(p) p.Money=999 return false,"REFUSED" end)==false)
    f.latest:AutoSave()
    return f.records[D.KeyFor(player)].Money==0
end)
check("Serialization refusal rolls back DataService and backing profile", function()
    local f=serviceFixture() assert(f.service:Load(player))
    local ok,reason=f.service:Update(player,function(p)
        p.Money=999 p.Custom={[2]="gap"} return true
    end)
    return ok==false and reason=="UNSERIALIZABLE_PROFILE"
        and f.service:Get(player).Money==0 and f.latest.Data.Money==0
end)
check("Future profiles are released without replacement by defaults", function()
    local f=serviceFixture({DataVersion=9,Money=81})
    local ok,reason=f.service:Load(player)
    return ok==false and reason=="FUTURE_VERSION" and f.service:Get(player)==nil
        and f.records[D.KeyFor(player)].DataVersion==9 and f.records[D.KeyFor(player)].Money==81
end)
check("Cancellation during load releases original data", function()
    local f=serviceFixture({Money=17})
    f.onLoad=function() f.service:Release(player) end
    local ok,reason=f.service:Load(player)
    return ok==false and reason=="CANCELLED" and f.service:Get(player)==nil
        and f.records[D.KeyFor(player)].Money==17 and f.records[D.KeyFor(player)].DataVersion==nil
end)
check("External release invalidates the service snapshot and permits reload", function()
    local f=serviceFixture() assert(f.service:Load(player))
    f.latest:Release()
    f.service:Step()
    assert(f.service:Get(player)==nil)
    return f.service:Load(player)==true
end)
check("DataService Stop waits for simulated release completion", function()
    local f=serviceFixture() f.defer=true f.completeAt=2
    assert(f.service:Load(player))
    assert(f.service:Update(player,function(p) p.Money=77 return true end))
    return f.service:Stop() and f.time==2 and f.records[D.KeyFor(player)].Money==77
end)
check("DataService Stop reports a timeout, then succeeds after completion", function()
    local f=serviceFixture() f.defer=true
    assert(f.service:Load(player))
    assert(f.service:Stop()==false)
    f.latest:CompleteRelease()
    return f.service:Stop()==true
end)

check("Live adapter associates a positive user ID without changing data", function()
    local f=fake({Money=7})
    local adapter=Adapter.new(f.store,{BindUserIds=true})
    local lease=assert(adapter:Acquire("k",12345))
    return f.latest.boundUserId==12345 and f.latest.Data.Money==7 and lease:Release(nil)
end)
check("Synthetic Studio user IDs are not attached to live metadata", function()
    local f=fake()
    local adapter=Adapter.new(f.store,{BindUserIds=true})
    local lease=assert(adapter:Acquire("k",-1))
    return f.latest.boundUserId==nil and lease:Release(nil)
end)
check("Externally released profiles are awaited until HopReady", function()
    local f=fake() f.defer=true
    assert(f.adapter:Acquire("k"))
    f.latest:Release()
    assert(f.adapter:AwaitPendingReleases(2)==false)
    f.latest:CompleteRelease()
    return f.adapter:AwaitPendingReleases(0)
end)
check("Shutdown wait detects an acquisition still in progress", function()
    local f=fake() local pending=false
    f.onLoad=function() pending=f.adapter:AwaitPendingReleases(2)==false end
    local lease=assert(f.adapter:Acquire("k"))
    return pending and lease:Release(nil) and f.adapter:AwaitPendingReleases(0)
end)
check("Configured service can be stopped before initialization", function()
    local service=D.new({UseConfiguredStore=true})
    table.insert(cleanup,service)
    return service:Stop() and service:Get(player)==nil
end)

table.insert(T.lines, ("[PROFILE ADAPTER TEST] %d OK / %d FAIL"):format(T.pass,T.fail))
local output=table.concat(T.lines,"\n")
print(output)
return {passed=T.pass,failed=T.fail,success=T.fail==0,output=output}
