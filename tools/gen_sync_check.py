#!/usr/bin/env python3
"""Génère studio/CheckSablSync.luau : la liste des tailles attendues des modules du dépôt, à comparer dans Studio.

Rôle    : appliquer dans Studio la règle de reprise « chaque script doit faire exactement la même taille en octets
          des deux côtés (retirer les \\r avant de compter) », en un seul appel execute_luau.
Doc     : PROMPT_EXECUTION_SABL_V4 §12.2 ; dette 25
Usage   : python3 tools/gen_sync_check.py   (à relancer après chaque changement de src/ ou de studio/)
Couvre  : src/ReplicatedStorage/Config et Shared → ReplicatedStorage.Config / .Shared ;
          les 25 modules de ServerStorage.Tests listés dans PROGRESS.md → studio/<Nom>.luau.
"""
import glob
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ServerStorage/Tests (PROGRESS.md, arborescence réelle) : modules dont studio/<Nom>.luau est la copie versionnée.
SERVER_TESTS = [
    "FixtureAlarmShow", "FixtureChaseSetup", "FixtureCreatureShowcase", "FixtureDefenseVisuals",
    "FixtureProfileBackup", "FixtureReserveView", "FixtureStealPrompts", "FixtureStealViews",
    "TestCreatureVisual", "TestDefenseService", "TestMapDecor", "TestPlacement",
    "TestProgressionService", "TestQuestService", "TestRebirthService", "TestSettingsService",
    "TestShieldService", "TestStealBuyback", "TestStealChase", "TestStealRemotes",
    "TestStealService", "TestStealViews", "TestTrainingRing", "TestUpgradeService",
    "TestVaultService",
]


def size_without_cr(path):
    with open(path, "rb") as handle:
        return len(handle.read().replace(b"\r", b""))


def main():
    entries = []
    for folder in ("Config", "Shared"):
        for path in sorted(glob.glob(os.path.join(ROOT, "src", "ReplicatedStorage", folder, "*.luau"))):
            name = os.path.splitext(os.path.basename(path))[0]
            entries.append(("ReplicatedStorage", folder, name, size_without_cr(path)))
    for name in SERVER_TESTS:
        entries.append(("ServerStorage", "Tests", name, size_without_cr(os.path.join(ROOT, "studio", name + ".luau"))))
    rows = "\n".join('    {"%s", "%s", "%s", %d},' % entry for entry in entries)
    script = '''--!nonstrict
--[[ CheckSablSync
     Rôle    : comparer, dans Studio, la taille de chaque module à celle du dépôt (sans \\r), en un seul appel.
     Doc     : PROMPT_EXECUTION_SABL_V4 §12.2 ; dette 25
     Étape   : outillage de reprise (généré par tools/gen_sync_check.py, ne pas modifier à la main)
     Dépend  : Studio en Édition ; execute_luau (lecture de Source)
     Exposé  : bilan dans la console : OK, DIFF (tailles), ABSENT ; aucune écriture
     Limite  : %d modules : ReplicatedStorage.Config et .Shared, et ServerStorage.Tests. Les scripts serveur et client
               (Services, Controllers, Main) ne sont pas dans le dépôt GitHub et ne sont donc pas couverts.
]]
local EXPECTED = {
%s
}
local ok, diff, absent = 0, 0, 0
local lines = {}
for _, e in ipairs(EXPECTED) do
    local container = game:GetService(e[1]):FindFirstChild(e[2])
    local module = container and container:FindFirstChild(e[3])
    local label = e[1] .. "." .. e[2] .. "." .. e[3]
    if not module or not module:IsA("LuaSourceContainer") then
        absent += 1
        table.insert(lines, ("[ABSENT] %%s (dépôt : %%d octets)"):format(label, e[4]))
    else
        local size = #(string.gsub(module.Source, "\\r", ""))
        if size == e[4] then
            ok += 1
        else
            diff += 1
            table.insert(lines, ("[DIFF]   %%s : Studio %%d octets, dépôt %%d"):format(label, size, e[4]))
        end
    end
end
table.insert(lines, ("[SYNC] %%d OK / %%d DIFF / %%d ABSENT sur %%d modules"):format(ok, diff, absent, #EXPECTED))
local output = table.concat(lines, "\\n")
print(output)
return {ok = ok, diff = diff, absent = absent, success = diff == 0 and absent == 0, output = output}
''' % (len(entries), rows)
    with open(os.path.join(ROOT, "studio", "CheckSablSync.luau"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(script)
    print("studio/CheckSablSync.luau : %d modules" % len(entries))


if __name__ == "__main__":
    main()
