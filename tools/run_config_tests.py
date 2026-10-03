#!/usr/bin/env python3
"""Lance hors de Studio les tests de studio/ qui n'ont besoin que de modules purs (Test*Config*, TestCombat*,
TestMatchmaker, TestArenaRewards, TestSeasonRules, TestArenaShop, TestTournament).

Rôle    : rejouer en une commande les batteries qui ne lisent que des ModuleScripts du dépôt (ReplicatedStorage et
          ServerScriptService), avec la CLI Luau (https://github.com/luau-lang/luau/releases), sans Studio ni MCP.
Doc     : PROMPT_EXECUTION_SABL_V4 §25, §26 ; décisions 81 et 122 ; dette 27
Usage   : python3 tools/run_config_tests.py [TestEventConfig ...] [-v]
          La CLI est cherchée dans la variable LUAU_BIN, sinon sous le nom « luau » dans le PATH.
Limite  : les vrais modules du dépôt sont chargés tels quels ; seuls `game` (les dossiers de src/ReplicatedStorage
          et src/ServerScriptService) et `Color3` sont simulés. Un test qui touche un service, un joueur ou une
          Instance doit tourner dans Studio. Un résultat vert ici ne remplace pas le passage du même test dans
          Studio.
Sortie  : la ligne de bilan de chaque test ; code de sortie 1 au moindre FAIL ou à la moindre erreur.
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HARNESS = r'''
local testName = ({...})[1]
local function readFile(path) return assert(SOURCES[path], "absent du dépôt : " .. path) end
local function color3() return {} end
local modules = {}
local baseEnv
-- Un dossier du dépôt vu comme une Instance : ses sous-dossiers et ses modules se trouvent par leur nom.
local function folder(prefix)
    local f = {}
    local function find(_, name)
        local path = prefix .. "/" .. name
        if SOURCES[path .. ".luau"] then return {Name = name, __path = path .. ".luau"} end
        if DIRS[path] then return folder(path) end
        return nil
    end
    f.FindFirstChild = find
    f.WaitForChild = function(self, name) return assert(find(self, name), "WaitForChild : " .. name) end
    return f
end
local services = {ReplicatedStorage = folder("src/ReplicatedStorage"),
    ServerScriptService = folder("src/ServerScriptService")}
local game = {GetService = function(_, name)
    return assert(services[name], "service non simulé : " .. tostring(name))
end}
local function requireInst(inst)
    if not modules[inst.__path] then
        local fn = assert(loadstring(readFile(inst.__path), "=" .. inst.__path))
        setfenv(fn, baseEnv)
        modules[inst.__path] = fn()
    end
    return modules[inst.__path]
end
baseEnv = setmetatable({game = game, require = requireInst,
    Color3 = {fromRGB = color3, new = color3, fromHex = color3}}, {__index = getfenv(0)})
local fn = assert(loadstring(readFile("studio/" .. testName .. ".luau"), "=" .. testName))
setfenv(fn, baseEnv)
local result = fn()
print(("success=%s"):format(tostring(result and result.success)))
'''


def find_luau():
    candidate = os.environ.get("LUAU_BIN") or shutil.which("luau")
    if not candidate or not os.path.isfile(candidate):
        sys.exit("CLI Luau introuvable : définir LUAU_BIN ou mettre « luau » dans le PATH "
                 "(https://github.com/luau-lang/luau/releases).")
    return candidate


def default_tests():
    paths = glob.glob(os.path.join(ROOT, "studio", "Test*Config*.luau"))
    for pattern in ("TestCombat*.luau", "TestMatchmaker.luau", "TestArenaRewards.luau", "TestSeasonRules.luau",
                    "TestArenaShop.luau", "TestTournament.luau"):
        paths += glob.glob(os.path.join(ROOT, "studio", pattern))
    return sorted({os.path.splitext(os.path.basename(p))[0] for p in paths})


def build_bundle():
    paths = sorted(glob.glob(os.path.join(ROOT, "src", "**", "*.luau"), recursive=True))
    paths += sorted(glob.glob(os.path.join(ROOT, "studio", "Test*.luau")))
    sources = {}
    dirs = set()
    for path in paths:
        key = os.path.relpath(path, ROOT).replace(os.sep, "/")
        with open(path, encoding="utf-8") as handle:
            sources[key] = handle.read()
        parent = os.path.dirname(key)
        while parent.startswith("src/"):
            dirs.add(parent)
            parent = os.path.dirname(parent)
    level = 1
    while any(("]" + "=" * level + "]") in text for text in sources.values()):
        level += 1
    open_quote, close_quote = "[" + "=" * level + "[", "]" + "=" * level + "]"
    lines = ["local SOURCES = {}", "local DIRS = {}"]
    lines += ['DIRS["%s"] = true' % d for d in sorted(dirs)]
    for key, text in sources.items():
        # Le premier saut de ligne après un crochet long ouvrant est ignoré par Luau : on en ajoute un.
        lines.append('SOURCES["%s"] = %s\n%s%s' % (key, open_quote, text, close_quote))
    return "\n".join(lines) + "\n" + HARNESS


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    verbose = "-v" in sys.argv[1:]
    luau = find_luau()
    tests = args or default_tests()
    bundle = build_bundle()
    failed = False
    with tempfile.TemporaryDirectory() as tmp:
        bundle_path = os.path.join(tmp, "bundle.luau")
        with open(bundle_path, "w", encoding="utf-8") as handle:
            handle.write(bundle)
        for name in tests:
            run = subprocess.run([luau, bundle_path, "-a", name], capture_output=True, text=True, encoding="utf-8")
            output = run.stdout + run.stderr
            summary = re.findall(r"^\[[A-Z ]+TEST\] \d+ OK / \d+ FAIL$", output, re.MULTILINE)
            ok = run.returncode == 0 and "success=true" in output and summary
            failed = failed or not ok
            if verbose or not ok:
                print(output.rstrip())
            print(("%-26s %s" % (name, summary[-1] if summary else "ERREUR (aucun bilan)")))
    print("BILAN : " + ("ÉCHEC" if failed else "tout vert"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
