--[[ lune_build_test
     Rôle    : exécuter un script de construction de studio/ dans un faux Studio (Lune), puis son test, puis la
               construction une 2e fois pour prouver l'idempotence.
     Doc     : PROMPT_EXECUTION_SABL_V4 §25, §4.3 (idempotence) ; décision 116
     Usage   : lune run tools/lune_build_test.luau BuildColisee TestColisee   (depuis la racine du dépôt)
     Limite  : Lune imite les objets Roblox (Instance, CFrame, Color3…) sans moteur : ni rendu, ni physique, ni
               mise en page. Les mesures (positions, tailles, couleurs, ancrage, nombres) sont fiables ; le reste
               se juge dans Studio.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local buildName, testName = process.args[1], process.args[2]
assert(buildName and testName, "usage : lune run tools/lune_build_test.luau <Build> <Test>")

local game = roblox.Instance.new("DataModel")
local env = {
    game = game, workspace = game:GetService("Workspace"),
    Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
    UDim2 = roblox.UDim2, UDim = roblox.UDim, Enum = roblox.Enum,
}

local function run(name: string): any
    local source = fs.readFile("studio/" .. name .. ".luau")
    local chunk = luau.load(source, {debugName = name, environment = env})
    return chunk()
end

local function partCount(): number
    local count = 0
    for _, d in ipairs(game:GetService("Workspace"):GetDescendants()) do
        if d:IsA("BasePart") then count += 1 end
    end
    return count
end

run(buildName)
local before = partCount()
local result = run(testName)
run(buildName) -- 2e passage : doit s'arrêter sans rien ajouter
local after = partCount()
print(("[IDEMPOTENCE] %s rejoué : %d pièces avant, %d après"):format(buildName, before, after))
local ok = result and result.success and before == after
print(ok and "BILAN : tout vert" or "BILAN : ÉCHEC")
process.exit(if ok then 0 else 1)
