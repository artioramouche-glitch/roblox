--!strict
--[[ BuildWhiteMapZones
     Rôle    : ajouter les quatre zones annexes et positionner le spawn existant.
     Doc     : GAME_MASTER_V2 D1.3 et D1.6 points 4-7
     Étape   : 1, lot C
     Dépend  : Map_Monde1 lot B ; Studio en Édition
     Exposé  : construction manuelle, sans script de gameplay
]]
local Workspace = game:GetService("Workspace")
assert(not game:GetService("RunService"):IsRunning(), "Mode Édition requis")
local map = Workspace:FindFirstChild("Map_Monde1")
assert(map and map:IsA("Model"), "Map_Monde1 absent")
local spawn = Workspace:FindFirstChild("SpawnLocation")
assert(spawn and spawn:IsA("SpawnLocation"), "SpawnLocation existant requis")
-- Lot D : hauteurs corrigées avec accord du Producer (dalle Y=1.5, vitrine Y=5).
local C = {
    shopPosition = Vector3.new(60, 1.5, 0), shopSize = Vector3.new(30, 1, 20),
    pedestalRadius = 2, pedestalHeight = 1, pedestalSpacing = 5, pedestalCount = 5,
    bossPosition = Vector3.new(-60, 2, 0), bossRadius = 25, bossHeight = 4,
    stepDepth = 3, stepWidth = 12, hubTop = 2,
    gatePosition = Vector3.new(0, 1, -55), pillarSize = Vector3.new(4, 12, 4),
    lintelSize = Vector3.new(16, 2, 4), pillarOffset = 6,
    museumPosition = Vector3.new(0, 5, 50), museumSize = Vector3.new(20, 6, 8),
    glassTransparency = 0.5, spawnPosition = Vector3.new(0, 3, 20),
    gray = Color3.fromHex("8A8580"), bossGray = Color3.fromHex("6C757D"),
    gold = Color3.fromHex("FFD23F"), glass = Color3.fromHex("E9ECEF"),
}
local version = map:GetAttribute("WhiteMapZonesBuild")
if version == "LotC_v2" then
    print("[BUILD] LotC_v2 already exists; no changes")
    return
elseif version == "LotC_v1" then
    local shop = map:FindFirstChild("EggShop")
    local museum = map:FindFirstChild("Musee")
    local platform = shop and shop:FindFirstChild("Platform")
    local display = museum and museum:FindFirstChild("DisplayCase")
    assert(platform and platform:IsA("BasePart"), "Dalle à inspecter")
    assert(display and display:IsA("BasePart"), "Vitrine à inspecter")
    assert(platform.Position == Vector3.new(60, 1, 0) or platform.Position == C.shopPosition,
        "Position de dalle modifiée : arbitrage requis")
    assert(display.Position == Vector3.new(0, 1, 50) or display.Position == C.museumPosition,
        "Position de vitrine modifiée : arbitrage requis")
    platform.Position = C.shopPosition
    display.Position = C.museumPosition
    map:SetAttribute("WhiteMapZonesBuild", "LotC_v2")
    print("[FIX] Shop Y=1.5; museum Y=5; existing instances preserved")
    return
end
for _, name in ipairs({"EggShop", "BossArena", "ColiseeGate", "Musee"}) do
    assert(not map:FindFirstChild(name), "Zone existante à inspecter : " .. name)
end
local zones: {Model} = {}
local function zone(name: string): Model
    local model = Instance.new("Model")
    model.Name = name
    table.insert(zones, model)
    return model
end
local count = 0
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, wedge: boolean?): BasePart
    local node: BasePart
    if wedge then node = Instance.new("WedgePart") else node = Instance.new("Part") end
    node.Name = name
    node.Size = size
    node.CFrame = cf
    node.Color = color
    node.Anchored = true
    node.Material = Enum.Material.SmoothPlastic
    node.TopSurface = Enum.SurfaceType.Smooth
    node.BottomSurface = Enum.SurfaceType.Smooth
    node.Parent = parent
    count += 1
    return node
end

local shop = zone("EggShop")
part(shop, "Platform", C.shopSize, CFrame.new(C.shopPosition), C.gray)
for i = 1, C.pedestalCount do
    local position = Vector3.new(C.shopPosition.X + (i - 3) * C.pedestalSpacing,
        C.hubTop + C.pedestalHeight / 2, C.shopPosition.Z)
    local pedestal = part(shop, "Pedestal" .. i,
        Vector3.new(C.pedestalHeight, C.pedestalRadius * 2, C.pedestalRadius * 2),
        CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), C.gold) :: Part
    pedestal.Shape = Enum.PartType.Cylinder
end

-- Octogone régulier inscrit dans r=25 : trois rectangles et quatre triangles.
local boss = zone("BossArena")
local a = C.bossRadius * math.cos(math.pi / 8)
local b = C.bossRadius * math.sin(math.pi / 8)
local side = a - b
local origin = CFrame.new(C.bossPosition)
part(boss, "Center", Vector3.new(2 * a, C.bossHeight, 2 * b), origin, C.bossGray)
for _, sign in ipairs({-1, 1}) do
    part(boss, sign == 1 and "NorthStrip" or "SouthStrip",
        Vector3.new(2 * b, C.bossHeight, side), origin * CFrame.new(0, 0, sign * (a + b) / 2), C.bossGray)
end
for i = 1, 4 do
    local rotation = origin * CFrame.Angles(0, (i - 1) * math.pi / 2, 0)
    local corner = CFrame.fromMatrix(Vector3.new((a + b) / 2, 0, (a + b) / 2),
        Vector3.yAxis, Vector3.xAxis, -Vector3.zAxis)
    part(boss, "Corner" .. i, Vector3.new(C.bossHeight, side, side), rotation * corner, C.bossGray, true)
end
for i = 1, 2 do
    local height = (C.bossPosition.Y + C.bossHeight / 2 - C.hubTop) * i / 3
    local x = C.bossPosition.X + a + C.stepDepth * (2.5 - i)
    part(boss, "AccessStep" .. i, Vector3.new(C.stepDepth, height, C.stepWidth),
        CFrame.new(x, C.hubTop + height / 2, C.bossPosition.Z), C.bossGray)
end

local gate = zone("ColiseeGate")
local gateFrame = CFrame.new(C.gatePosition)
part(gate, "PillarLeft", C.pillarSize, gateFrame * CFrame.new(-C.pillarOffset, C.pillarSize.Y / 2, 0), C.gold)
part(gate, "PillarRight", C.pillarSize, gateFrame * CFrame.new(C.pillarOffset, C.pillarSize.Y / 2, 0), C.gold)
part(gate, "Lintel", C.lintelSize, gateFrame * CFrame.new(0, C.pillarSize.Y + C.lintelSize.Y / 2, 0), C.gold)
local museum = zone("Musee")
local display = part(museum, "DisplayCase", C.museumSize, CFrame.new(C.museumPosition), C.glass)
display.Material = Enum.Material.Glass
display.Transparency = C.glassTransparency

for _, model in ipairs(zones) do model.Parent = map end
spawn.CFrame = CFrame.new(C.spawnPosition)
spawn.Anchored = true
map:SetAttribute("WhiteMapZonesBuild", "LotC_v2")
print(("[BUILD] Lot C: %d zones; %d anchored parts; existing spawn moved to (0, 3, 20)"):format(#zones, count))
