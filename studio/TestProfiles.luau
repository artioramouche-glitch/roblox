--!nonstrict
--[[ TestProfiles
     Rôle    : tester les profils uniquement en mémoire, sans DataStore ni joueur réel.
     Doc     : GAME_MASTER_V2 G2 ; PROMPT_EXECUTION_SABL_V4 §19
     Étape   : 2, lot B ; schéma en version 2 à l'étape 9, lot C (Réserve d'or), en version 3 au lot F1
     Dépend  : DefaultProfile, ServerScriptService.Data.Migrations
     Exposé  : test manuel serveur ou Édition ; retourne le bilan
]]
local config = game:GetService("ReplicatedStorage"):FindFirstChild("Config")
local data = game:GetService("ServerScriptService"):FindFirstChild("Data")
assert(config and data, "Dossiers de données absents")
local Default = require(assert(config:FindFirstChild("DefaultProfile")))
local M = require(assert(data:FindFirstChild("Migrations")))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, callback)
    local ok, result = pcall(callback)
    local passed = ok and result == true
    if passed then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (passed and "[OK] " or "[FAIL] ") .. name
        .. (not ok and (" : " .. tostring(result)) or ""))
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
check("Fresh profile matches G2 defaults and version 3", function()
    local p = M:Create()
    return equal(p, Default) and p.DataVersion == 3 and p.Money == 0 and p.Level == 1
        and p.Base.Slots == 3 and p.PvP.Elo1v1 == 1000 and p.PvP.Elo2v2 == 1000
end)
check("Profiles and template have independent nested tables", function()
    local a, b = M:Create(), M:Create()
    a.Creatures[1] = {Uid="sample", Id="noobini", Tier=1}
    a.Base.Decor[1] = "sample"
    a.PvP.Loadouts.A[1] = "sample"
    a.Settings.Music = false
    return #b.Creatures == 0 and #Default.Creatures == 0
        and #b.Base.Decor == 0 and #Default.Base.Decor == 0
        and #b.PvP.Loadouts.A == 0 and #Default.PvP.Loadouts.A == 0
        and b.Settings.Music and Default.Settings.Music
end)
local legacy = {
    Money=123456, Creatures={{Uid="owned", Id="noobini", Tier=2, Extra="keep"}},
    Base={Slots=7, Decor={"bench"}}, PvP={ArenaTokens=42, Loadouts={A={"owned"}}},
    Settings={Music=false}, Custom={Nested={Value="keep"}},
}
local migrated, migrationError = M:Apply(legacy)
check("Legacy profile gains version and missing nested fields", function()
    return migrationError == nil and migrated.DataVersion == 3
        and migrated.PvP.Elo1v1 == 1000 and migrated.PvP.Season.Id == 1
        and migrated.Base.TrainingRing == 0 and migrated.Settings.SFX == true
end)
check("Migration preserves money, creatures, slots, tokens and loadout", function()
    return migrated.Money == 123456 and equal(migrated.Creatures, legacy.Creatures)
        and migrated.Base.Slots == 7 and migrated.PvP.ArenaTokens == 42
        and migrated.PvP.Loadouts.A[1] == "owned"
end)
check("Unknown fields and false settings survive", function()
    return migrated.Custom.Nested.Value == "keep" and migrated.Settings.Music == false
        and migrated.Creatures[1].Extra == "keep"
end)
check("Successful migration leaves original untouched", function()
    return legacy.DataVersion == nil and legacy.PvP.Season == nil
        and legacy.Base.TrainingRing == nil and legacy.Settings.SFX == nil
        and legacy.Money == 123456
end)
check("Migrated data shares no nested tables with original", function()
    local copy = assert(M:Apply(legacy))
    copy.Creatures[1].Tier = 5
    copy.Custom.Nested.Value = "changed"
    return legacy.Creatures[1].Tier == 2 and legacy.Custom.Nested.Value == "keep"
end)
check("Second migration is idempotent", function()
    local again, err = M:Apply(migrated)
    return err == nil and equal(again, migrated) and again ~= migrated
end)
check("Zero values are preserved", function()
    local p = assert(M:Apply({Money=0, Base={Generator=0}, PvP={ArenaTokens=0}}))
    return p.Money == 0 and p.Base.Generator == 0 and p.PvP.ArenaTokens == 0
end)
check("Empty legacy profile is reconciled", function()
    return equal(assert(M:Apply({})), Default)
end)
check("Future version refused without mutation", function()
    local p = {DataVersion=4, Money=91}
    local result, err = M:Apply(p)
    return result == nil and err == "FUTURE_VERSION" and p.Money == 91 and p.DataVersion == 4
end)
for _, version in ipairs({0, -1, 1.5, "1", false, math.huge, 0/0}) do
    check("Invalid version rejected: " .. tostring(version), function()
        local result, err = M:Apply({DataVersion=version})
        return result == nil and err == "INVALID_VERSION"
    end)
end
check("Non-table profile rejected", function()
    local result, err = M:Apply(nil)
    return result == nil and err == "INVALID_PROFILE"
end)
check("Wrong nested type rejected without partial writes", function()
    local p = {Money=81, PvP={Season="bad"}}
    local result, err = M:Apply(p)
    return result == nil and err == "INCOMPATIBLE_PROFILE"
        and p.DataVersion == nil and p.Base == nil and p.Money == 81 and p.PvP.Season == "bad"
end)
check("Wrong scalar type is not coerced", function()
    local result, err = M:Apply({Money="123"})
    return result == nil and err == "INCOMPATIBLE_PROFILE"
end)
check("Cyclic data refused", function()
    local p = {} p.Custom = p
    local result, err = M:Apply(p)
    return result == nil and err == "INCOMPATIBLE_PROFILE" and p.Custom == p
end)
check("Non-finite numeric data refused", function()
    local result, err = M:Apply({Money=math.huge})
    return result == nil and err == "INCOMPATIBLE_PROFILE"
end)
check("Unsupported data value refused", function()
    local result, err = M:Apply({Custom=function() end})
    return result == nil and err == "INCOMPATIBLE_PROFILE"
end)
check("Metatable refused without executing it", function()
    local touched = false
    local p = setmetatable({}, {__index=function() touched = true end})
    local result, err = M:Apply(p)
    return result == nil and err == "METATABLE_NOT_SUPPORTED" and not touched
end)
check("Shared input tables become independent copies", function()
    local shared = {Value=8}
    local p = assert(M:Apply({CustomA=shared, CustomB=shared}))
    p.CustomA.Value = 9
    return p.CustomB.Value == 8 and shared.Value == 8
end)
table.insert(T.lines, ("[PROFILE TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed=T.pass, failed=T.fail, success=T.fail == 0, output=output}
