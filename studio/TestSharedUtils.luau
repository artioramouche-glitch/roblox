--!nonstrict
--[[ TestSharedUtils
     Rôle    : tester les utilitaires sans profil réel, Remote ni DataStore.
     Doc     : PROMPT_EXECUTION_SABL_V4 §16.9, §16.10 ; GAME_MASTER_V2 G1
     Étape   : 2, lot C1
     Dépend  : ReplicatedStorage.Shared ; exécution serveur ou Édition
     Exposé  : bilan de tests ; aucune installation de script runtime
]]
local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
assert(shared, "Shared absent")
local N = require(assert(shared:FindFirstChild("NumberFormatter")))
local W = require(assert(shared:FindFirstChild("WeightedRandom")))
local U = require(assert(shared:FindFirstChild("TableUtil")))
local T = {pass=0, fail=0, lines={}}
local function check(name, callback)
    local ok, result = pcall(callback)
    local passed = ok and result == true
    if passed then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (passed and "[OK] " or "[FAIL] ") .. name
        .. (not ok and (" : " .. tostring(result)) or ""))
end
local function rejects(callback) return not pcall(callback) end

for _, case in ipairs({
    {0,"0"}, {0.9,"0"}, {999,"999"}, {999.9,"999"}, {1000,"1.00K"},
    {1250,"1.25K"}, {12500,"12.5K"}, {125000,"125K"},
    {1000000,"1.00M"}, {1000000000,"1.00B"}, {1000000000000,"1.00T"},
    {100000000000000,"100T"}, {-1250,"-1.25K"}, {-1.2,"-2"},
}) do
    check("format " .. case[1] .. " = " .. case[2], function() return N.format(case[1]) == case[2] end)
end
for index, suffix in ipairs({"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}) do
    check("Exact suffix boundary " .. suffix, function()
        return N.format(1000 ^ index) == "1.00" .. suffix
    end)
end
check("Large finite number has no scientific notation", function()
    local text = N.format(1e36)
    return text:sub(-2) == "Dc" and not text:find("[eE]")
end)
for _, value in ipairs({math.huge, -math.huge, 0/0, "1000", false}) do
    check("Formatter rejects invalid value " .. tostring(value), function()
        return rejects(function() N.format(value) end)
    end)
end
check("Formatter rejects nil", function() return rejects(function() N.format(nil) end) end)

check("Zero-weight entries never selected", function()
    local rng = Random.new(12345)
    local entries = {{key="zeroBefore",weight=0},{key="only",weight=1},{key="zeroAfter",weight=0}}
    for _=1,1000 do if W.pick(entries,rng) ~= "only" then return false end end
    return true
end)
check("False is a valid key", function()
    return W.pick({{key=false,weight=1}}, Random.new(1)) == false
end)
check("Same seed yields same sequence", function()
    local a,b = Random.new(2468),Random.new(2468)
    local entries = {{key="A",weight=85},{key="B",weight=15}}
    for _=1,100 do if W.pick(entries,a) ~= W.pick(entries,b) then return false end end
    return true
end)
check("85/15 weighted sample within two percentage points (10000 draws)", function()
    local rng, count = Random.new(67890), 0
    local entries = {{key="A",weight=85},{key="B",weight=15}}
    for _=1,10000 do if W.pick(entries,rng) == "A" then count += 1 end end
    return math.abs(count / 10000 - 0.85) <= 0.02
end)
check("Large finite weights do not overflow", function()
    local entries = {{key="A",weight=1e308},{key="B",weight=1e308}}
    local seen, rng = {}, Random.new(1357)
    for _=1,100 do seen[W.pick(entries,rng)] = true end
    return seen.A == true and seen.B == true and entries[1].weight == 1e308
end)
check("Fractional weights accepted and input preserved", function()
    local entries = {{key="A",weight=0.25},{key="B",weight=0.75}}
    local rng, seen = Random.new(123), {}
    for _=1,100 do seen[W.pick(entries,rng)] = true end
    return seen.A and seen.B and entries[1].weight == 0.25 and entries[2].weight == 0.75
end)
for _, case in ipairs({
    {name="empty",entries={}},
    {name="all zero",entries={{key="A",weight=0}}},
    {name="negative",entries={{key="A",weight=-1}}},
    {name="infinite",entries={{key="A",weight=math.huge}}},
    {name="NaN",entries={{key="A",weight=0/0}}},
    {name="string weight",entries={{key="A",weight="1"}}},
    {name="missing key",entries={{weight=1}}},
    {name="non-table entry",entries={false}},
    {name="sparse array",entries={[1]={key="A",weight=1},[3]={key="B",weight=1}}},
    {name="dictionary",entries={A={key="A",weight=1}}},
}) do
    check("Draw rejects " .. case.name, function()
        return rejects(function() W.pick(case.entries,Random.new(1)) end)
    end)
end
check("Draw rejects nil entries", function()
    return rejects(function() W.pick(nil,Random.new(1)) end)
end)
check("Draw rejects missing RNG", function()
    return rejects(function() W.pick({{key="A",weight=1}},nil) end)
end)

check("DeepCopy preserves nested values without sharing tables", function()
    local original = {Money=0, Settings={Music=false}, Creatures={{Uid="sample"}}}
    local copy = U.DeepCopy(original)
    if copy.Money ~= 0 or copy.Settings.Music ~= false or copy.Creatures[1].Uid ~= "sample" then return false end
    copy.Creatures[1].Uid = "changed"
    return original.Creatures[1].Uid == "sample" and copy.Settings ~= original.Settings
end)
check("DeepCopy preserves internal aliases", function()
    local child = {n=1}
    local copy = U.DeepCopy({a=child,b=child})
    return copy.a == copy.b and copy.a ~= child
end)
check("DeepCopy preserves cycles in the copy only", function()
    local original = {} original.self = original
    local copy = U.DeepCopy(original)
    return copy ~= original and copy.self == copy and original.self == original
end)
check("DeepCopy copies table keys and values consistently", function()
    local key = {id=1}
    local copy = U.DeepCopy({[key]=key})
    for k,v in pairs(copy) do return k == v and k ~= key and k.id == 1 end
    return false
end)
check("DeepCopy preserves sparse indices", function()
    local copy = U.DeepCopy({[1]="a",[4]="b"})
    return copy[1] == "a" and copy[2] == nil and copy[4] == "b"
end)
check("DeepCopy accepts scalar and nil values", function()
    return U.DeepCopy(nil) == nil and U.DeepCopy(false) == false and U.DeepCopy(7) == 7
end)
check("DeepCopy rejects metatables without changing input", function()
    local original = setmetatable({n=8},{})
    return rejects(function() U.DeepCopy(original) end) and original.n == 8
end)
check("DeepCopy rejects nested metatables", function()
    return rejects(function() U.DeepCopy({child=setmetatable({},{})}) end)
end)
table.insert(T.lines,("[SHARED UTILS TEST] %d OK / %d FAIL"):format(T.pass,T.fail))
local output=table.concat(T.lines,"\n")
print(output)
return {passed=T.pass,failed=T.fail,success=T.fail == 0,output=output}
