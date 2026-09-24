--!nonstrict
--[[ TestRemoteGuard
     Rôle    : tester les filtres avec des profils fictifs et une horloge contrôlée.
     Doc     : GAME_MASTER_V2 G3/G4 ; PROMPT_EXECUTION_SABL_V4 §16.5
     Étape   : 2, lot C2
     Dépend  : RemoteConfig, RemoteGuard ; Play serveur avec un joueur connecté
     Exposé  : bilan ; aucun remote créé, aucun profil réel consulté ou modifié
]]
local Players = game:GetService("Players")
assert(game:GetService("RunService"):IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local Config = require(game:GetService("ReplicatedStorage").Config.RemoteConfig)
local RemoteGuard = require(game:GetService("ServerScriptService").Networking.RemoteGuard)
local T = {pass=0, fail=0, skipped=0, lines={}}
local guards = {}
local function track(guard) table.insert(guards, guard) return guard end
local function check(name, callback)
    local ok, result = pcall(callback)
    local passed = ok and result == true
    if passed then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (passed and "[OK] " or "[FAIL] ") .. name
        .. (not ok and (" : " .. tostring(result)) or ""))
    for _, guard in ipairs(guards) do guard:Close() end
    table.clear(guards)
end
local function signal()
    local s = {callbacks={}, connected=0, disconnected=0, nextId=0}
    function s:Connect(callback)
        self.nextId += 1
        local id = self.nextId
        self.callbacks[id] = callback
        self.connected += 1
        return {Disconnect=function()
            if not self.callbacks[id] then return end
            self.callbacks[id] = nil
            self.connected -= 1
            self.disconnected += 1
        end}
    end
    function s:Fire(p)
        for _, callback in pairs(table.clone(self.callbacks)) do callback(p) end
    end
    return s
end
local function fixture()
    local f = {now=0, loaded=true, reads=0, calls=0, profile={Money=100}, removing=signal()}
    f.guard = track(RemoteGuard.new(function(p)
        f.reads += 1
        assert(p == player, "Unexpected test player")
        if f.readerHook then return f.readerHook(p) end
        return f.loaded and f.profile or nil
    end, {Clock=function()
        if f.clockHook then return f.clockHook() end
        return f.now
    end, PlayerRemoving=f.removing}))
    function f:Wrap(name, handler)
        return self.guard:Wrap(name, handler or function()
            self.calls += 1
            return true, "OK"
        end)
    end
    return f
end
local function fill(callback)
    for _=1,Config.MaxRequestsPerWindow do assert(callback(player) == true) end
end
local function refused(callback, code, ...)
    local ok, result = callback(...)
    return ok == false and result == code
end

check("Config is immutable: 10 requests / 1 second", function()
    return table.isfrozen(Config) and Config.MaxRequestsPerWindow == 10 and Config.WindowSeconds == 1
end)
check("Missing profile reader refuses action", function()
    local calls = 0
    local guard = track(RemoteGuard.new())
    local callback = guard:Wrap("BuyEgg", function() calls += 1 return true, "OK" end)
    return refused(callback,"NO_PROFILE",player) and calls == 0
end)
check("Unloaded profile refuses without side effects", function()
    local f = fixture() f.loaded = false
    local callback = f:Wrap("BuyEgg")
    return refused(callback,"NO_PROFILE",player) and f.calls == 0 and f.profile.Money == 100
end)
check("Rate limit runs before profile lookup", function()
    local f = fixture() f.loaded = false
    local callback = f:Wrap("BuyEgg")
    for _=1,10 do assert(refused(callback,"NO_PROFILE",player)) end
    return refused(callback,"RATE_LIMIT",player) and f.reads == 10 and f.calls == 0
end)
check("30 requests: 10 admitted, 20 refused, no excess effects", function()
    local f = fixture()
    local callback = f:Wrap("ClickGain",function()
        f.profile.Money += 1
        return true, "OK"
    end)
    local accepted, rejected = 0,0
    for _=1,30 do
        local ok, reason = callback(player)
        if ok then accepted += 1 elseif reason == "RATE_LIMIT" then rejected += 1 end
    end
    return accepted == 10 and rejected == 20 and f.profile.Money == 110 and f.reads == 10
end)
check("Different remotes have independent counters", function()
    local f = fixture()
    local a,b = f:Wrap("ClickGain"),f:Wrap("BuyEgg")
    fill(a)
    return refused(a,"RATE_LIMIT",player) and b(player) == true
end)
check("Wrapping same remote again does not reset its counter", function()
    local f = fixture()
    fill(f:Wrap("BuyEgg"))
    return refused(f:Wrap("BuyEgg"),"RATE_LIMIT",player)
end)
check("Window stays closed before one second and opens at boundary", function()
    local f = fixture() local callback = f:Wrap("BuyEgg")
    fill(callback)
    f.now = Config.WindowSeconds - 0.001
    assert(refused(callback,"RATE_LIMIT",player))
    f.now = Config.WindowSeconds
    return callback(player) == true and f.calls == 11
end)
check("Clock rollback cannot reset an exhausted window", function()
    local f = fixture() local callback = f:Wrap("BuyEgg")
    fill(callback) f.now = -1
    return refused(callback,"RATE_LIMIT",player) and f.calls == 10
end)
check("Arguments including nil are forwarded intact", function()
    local f = fixture() local payload = {value=7}
    local callback = f:Wrap("BuyEgg",function(p,...)
        local args = table.pack(...)
        return p == player and args.n == 4 and args[1] == "egg_basic"
            and args[2] == nil and args[3] == payload and args[4] == false, payload
    end)
    local ok, result = callback(player,"egg_basic",nil,payload,false)
    return ok == true and result == payload
end)
check("Business refusal is preserved without effects", function()
    local f = fixture()
    local callback = f:Wrap("BuyEgg",function() return false,"NOT_ENOUGH_MONEY" end)
    return refused(callback,"NOT_ENOUGH_MONEY",player) and f.profile.Money == 100
end)
check("Malformed business inputs rejected before effects", function()
    local f = fixture()
    local callback = f:Wrap("BuyEgg",function(_,quantity)
        if quantity ~= 1 and quantity ~= 10 and quantity ~= 50 then return false,"BAD_QTY" end
        f.calls += 1
        return true,"OK"
    end)
    for _,value in ipairs({-1,0,7,{},string.rep("x",10000)}) do
        assert(refused(callback,"BAD_QTY",player,value))
    end
    return refused(callback,"BAD_QTY",player,nil) and f.calls == 0 and f.profile.Money == 100
end)
check("Profile reader exception returns INTERNAL, handler not called", function()
    local f = fixture() f.readerHook = function() error("PRIVATE_TEST_VALUE") end
    return refused(f:Wrap("BuyEgg"),"INTERNAL",player) and f.calls == 0
end)
check("Non-table profile is refused", function()
    local f = fixture() f.readerHook = function() return true end
    return refused(f:Wrap("BuyEgg"),"NO_PROFILE",player) and f.calls == 0
end)
check("Handler exception returns INTERNAL without exposing exception", function()
    local f = fixture()
    local callback = f:Wrap("BuyEgg",function() error("PRIVATE_TEST_VALUE") end)
    return refused(callback,"INTERNAL",player)
end)
check("Invalid handler response returns INTERNAL", function()
    local f = fixture()
    return refused(f:Wrap("BuyEgg",function() return "not a boolean" end),"INTERNAL",player)
end)
check("Handler exception still consumes request budget", function()
    local f = fixture()
    local callback = f:Wrap("BuyEgg",function() f.calls += 1 error("PRIVATE_TEST_VALUE") end)
    for _=1,10 do assert(refused(callback,"INTERNAL",player)) end
    return refused(callback,"RATE_LIMIT",player) and f.calls == 10
end)
check("Non-Player arguments rejected before profile lookup", function()
    local f = fixture() local callback = f:Wrap("BuyEgg")
    return refused(callback,"NO_PROFILE",nil) and refused(callback,"NO_PROFILE",{})
        and refused(callback,"NO_PROFILE",workspace) and f.reads == 0 and f.calls == 0
end)
for _,value in ipairs({math.huge,0/0,"bad"}) do
    check("Invalid clock value refused: " .. tostring(value),function()
        local f = fixture() f.clockHook = function() return value end
        return refused(f:Wrap("BuyEgg"),"INTERNAL",player) and f.reads == 0 and f.calls == 0
    end)
end
check("Clock exception is contained",function()
    local f = fixture() f.clockHook = function() error("PRIVATE_TEST_VALUE") end
    return refused(f:Wrap("BuyEgg"),"INTERNAL",player) and f.calls == 0
end)
check("Simulated PlayerRemoving clears all counters for player",function()
    local f = fixture()
    local a,b = f:Wrap("ClickGain"),f:Wrap("BuyEgg")
    fill(a) fill(b)
    f.removing:Fire(player)
    return a(player) == true and b(player) == true and f.calls == 22
end)
check("Removal during profile lookup cancels pending handler",function()
    local f = fixture()
    f.readerHook = function(p) f.removing:Fire(p) return f.profile end
    return refused(f:Wrap("BuyEgg"),"NO_PROFILE",player) and f.calls == 0
end)
check("Close disconnects once and revokes existing wrappers",function()
    local f = fixture() local callback = f:Wrap("BuyEgg")
    assert(f.removing.connected == 1)
    f.guard:Close() f.guard:Close()
    return f.removing.connected == 0 and f.removing.disconnected == 1
        and refused(callback,"NO_PROFILE",player) and f.reads == 0
end)
check("Close during profile lookup cancels pending handler",function()
    local f = fixture()
    f.readerHook = function() f.guard:Close() return f.profile end
    return refused(f:Wrap("BuyEgg"),"NO_PROFILE",player) and f.calls == 0
end)
check("Closed guard refuses new wrappers",function()
    local f = fixture() f.guard:Close()
    return not pcall(function() f:Wrap("BuyEgg") end)
end)
check("Invalid wrapper configuration rejected",function()
    local f = fixture()
    return not pcall(function() f.guard:Wrap("",function() return true end) end)
        and not pcall(function() f.guard:Wrap("Buy Egg",function() return true end) end)
        and not pcall(function() f.guard:Wrap("BuyEgg",nil) end)
end)
local second = Players:GetPlayers()[2]
if second then
    check("Two connected players have independent counters",function()
        local guard = track(RemoteGuard.new(function() return {} end,{Clock=function() return 0 end}))
        local callback = guard:Wrap("BuyEgg",function() return true,"OK" end)
        fill(callback)
        return refused(callback,"RATE_LIMIT",player) and callback(second) == true
    end)
else
    T.skipped += 1
    table.insert(T.lines,"[SKIP] Two-player isolation requires a second connected test player")
end
table.insert(T.lines,("[REMOTE GUARD TEST] %d OK / %d FAIL / %d SKIP"):format(T.pass,T.fail,T.skipped))
local output = table.concat(T.lines,"\n")
print(output)
return {passed=T.pass,failed=T.fail,skipped=T.skipped,success=T.fail == 0 and T.skipped == 0,output=output}
