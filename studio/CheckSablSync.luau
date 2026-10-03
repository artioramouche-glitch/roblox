--!nonstrict
--[[ CheckSablSync
     Rôle    : comparer, dans Studio, la taille de chaque module à celle du dépôt (sans \r), en un seul appel.
     Doc     : PROMPT_EXECUTION_SABL_V4 §12.2 ; dette 25
     Étape   : outillage de reprise (généré par tools/gen_sync_check.py, ne pas modifier à la main)
     Dépend  : Studio en Édition ; execute_luau (lecture de Source)
     Exposé  : bilan dans la console : OK, DIFF (tailles), ABSENT ; aucune écriture
     Limite  : 65 modules : ReplicatedStorage.Config et .Shared, ServerScriptService.Arena, .Clan et .Combat,
               ServerStorage.Tests.
               Les autres scripts serveur et client (Services, Controllers, Main) ne sont pas dans le dépôt GitHub
               et ne sont donc pas couverts.
]]
local EXPECTED = {
    {"ReplicatedStorage", "Config", "AnnouncementConfig", 3093},
    {"ReplicatedStorage", "Config", "AntiCheatConfig", 3770},
    {"ReplicatedStorage", "Config", "ArenaConfig", 8087},
    {"ReplicatedStorage", "Config", "ClanConfig", 8476},
    {"ReplicatedStorage", "Config", "CodeConfig", 2813},
    {"ReplicatedStorage", "Config", "CombatConfig", 5259},
    {"ReplicatedStorage", "Config", "CreatureConfig", 9261},
    {"ReplicatedStorage", "Config", "DefaultProfile", 1963},
    {"ReplicatedStorage", "Config", "EconomyConfig", 950},
    {"ReplicatedStorage", "Config", "EggConfig", 2388},
    {"ReplicatedStorage", "Config", "EventConfig", 5950},
    {"ReplicatedStorage", "Config", "LeaderboardConfig", 2521},
    {"ReplicatedStorage", "Config", "MapConfig", 1815},
    {"ReplicatedStorage", "Config", "MonetizationConfig", 6697},
    {"ReplicatedStorage", "Config", "ProgressionConfig", 1405},
    {"ReplicatedStorage", "Config", "QuestConfig", 5370},
    {"ReplicatedStorage", "Config", "RebirthConfig", 3404},
    {"ReplicatedStorage", "Config", "RemoteConfig", 357},
    {"ReplicatedStorage", "Config", "StealConfig", 4913},
    {"ReplicatedStorage", "Config", "UpgradeConfig", 6178},
    {"ReplicatedStorage", "Config", "WorldConfig", 5464},
    {"ReplicatedStorage", "Shared", "CombatUtil", 2286},
    {"ReplicatedStorage", "Shared", "EconomyUtil", 4443},
    {"ReplicatedStorage", "Shared", "EloUtil", 811},
    {"ReplicatedStorage", "Shared", "ErrorMessages", 3456},
    {"ReplicatedStorage", "Shared", "LuckUtil", 2544},
    {"ReplicatedStorage", "Shared", "NumberFormatter", 1043},
    {"ReplicatedStorage", "Shared", "ParisTime", 4474},
    {"ReplicatedStorage", "Shared", "SlotRandom", 3036},
    {"ReplicatedStorage", "Shared", "TableUtil", 920},
    {"ReplicatedStorage", "Shared", "WeightedRandom", 2374},
    {"ServerScriptService", "Arena", "ArenaShop", 3633},
    {"ServerScriptService", "Arena", "SeasonRules", 4714},
    {"ServerScriptService", "Arena", "TournamentBracket", 11541},
    {"ServerScriptService", "Clan", "ClanRules", 9632},
    {"ServerScriptService", "Clan", "WarRules", 10168},
    {"ServerScriptService", "Combat", "ArenaRewards", 6446},
    {"ServerScriptService", "Combat", "CombatBot", 5292},
    {"ServerScriptService", "Combat", "CombatEngine", 26245},
    {"ServerScriptService", "Combat", "Matchmaker", 11868},
    {"ServerStorage", "Tests", "FixtureAlarmShow", 3974},
    {"ServerStorage", "Tests", "FixtureChaseSetup", 5418},
    {"ServerStorage", "Tests", "FixtureCreatureShowcase", 3599},
    {"ServerStorage", "Tests", "FixtureDefenseVisuals", 2882},
    {"ServerStorage", "Tests", "FixtureProfileBackup", 2995},
    {"ServerStorage", "Tests", "FixtureReserveView", 2913},
    {"ServerStorage", "Tests", "FixtureStealPrompts", 3438},
    {"ServerStorage", "Tests", "FixtureStealViews", 5085},
    {"ServerStorage", "Tests", "TestCreatureVisual", 4883},
    {"ServerStorage", "Tests", "TestDefenseService", 21547},
    {"ServerStorage", "Tests", "TestMapDecor", 19979},
    {"ServerStorage", "Tests", "TestPlacement", 10555},
    {"ServerStorage", "Tests", "TestProgressionService", 6368},
    {"ServerStorage", "Tests", "TestQuestService", 14240},
    {"ServerStorage", "Tests", "TestRebirthService", 17516},
    {"ServerStorage", "Tests", "TestSettingsService", 5486},
    {"ServerStorage", "Tests", "TestShieldService", 12443},
    {"ServerStorage", "Tests", "TestStealBuyback", 10858},
    {"ServerStorage", "Tests", "TestStealChase", 8168},
    {"ServerStorage", "Tests", "TestStealRemotes", 16724},
    {"ServerStorage", "Tests", "TestStealService", 15227},
    {"ServerStorage", "Tests", "TestStealViews", 12567},
    {"ServerStorage", "Tests", "TestTrainingRing", 12464},
    {"ServerStorage", "Tests", "TestUpgradeService", 15119},
    {"ServerStorage", "Tests", "TestVaultService", 8556},
}
local ok, diff, absent = 0, 0, 0
local lines = {}
for _, e in ipairs(EXPECTED) do
    local container = game:GetService(e[1]):FindFirstChild(e[2])
    local module = container and container:FindFirstChild(e[3])
    local label = e[1] .. "." .. e[2] .. "." .. e[3]
    if not module or not module:IsA("LuaSourceContainer") then
        absent += 1
        table.insert(lines, ("[ABSENT] %s (dépôt : %d octets)"):format(label, e[4]))
    else
        local size = #(string.gsub(module.Source, "\r", ""))
        if size == e[4] then
            ok += 1
        else
            diff += 1
            table.insert(lines, ("[DIFF]   %s : Studio %d octets, dépôt %d"):format(label, size, e[4]))
        end
    end
end
table.insert(lines, ("[SYNC] %d OK / %d DIFF / %d ABSENT sur %d modules"):format(ok, diff, absent, #EXPECTED))
local output = table.concat(lines, "\n")
print(output)
return {ok = ok, diff = diff, absent = absent, success = diff == 0 and absent == 0, output = output}
