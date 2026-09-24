--!strict
--[[ BuildWhiteMap
     Rôle    : construire la map blanche M1, lot B, sans modifier l'existant.
     Doc     : GAME_MASTER_V2 D1.3-D1.6 ; rayon 230 validé par le Producer.
     Étape   : 1, lot B (hub, plots, liaisons, ruelles)
     Dépend  : Studio en Édition, StreamingEnabled actif
     Exposé  : exécution manuelle ; aucun script runtime installé
]]
local Workspace = game:GetService("Workspace")
assert(not game:GetService("RunService"):IsRunning(), "Mode Édition requis")
assert(Workspace.StreamingEnabled, "Activer StreamingEnabled avant construction")
local existing = Workspace:FindFirstChild("Map_Monde1")
if existing then
    assert(existing:IsA("Model") and existing:GetAttribute("WhiteMapBuild") == "LotB_v1",
        "Map_Monde1 existe déjà : inspection requise, aucun remplacement automatique")
    print("[BUILD] LotB_v1 already exists; no changes")
    return
end

-- Valeurs documentées, plus implantation technique des liaisons du rayon validé.
local C = {
    plotCount = 12, plotRadius = 230, plotSize = 80, plotTop = 2,
    hubRadius = 60, hubHeight = 2, logoRadius = 8, logoHeight = 0.2,
    lampCount = 12, lampRadius = 50, lampHeight = 8, lampDiameter = 1,
    roadWidth = 20, ringRadius = 170, roadStart = 58, roadEnd = 194,
    alleyStart = 160, alleyEnd = 280, rampAngle = math.rad(30),
    rampSize = Vector3.new(12, 2, 6), rampRadii = {208, 232},
    trampolineRadius = 4, trampolineHeight = 0.5, trampolineRadii = {252, 268},
    asphalt = Color3.fromHex("8A8580"), plotColor = Color3.fromHex("9B9484"),
    yellow = Color3.fromHex("FFD23F"), red = Color3.fromHex("E63946"),
    placeholder = Color3.fromRGB(160, 160, 160),
}
local map = Instance.new("Model")
map.Name = "Map_Monde1"
map:SetAttribute("PlotRadius", C.plotRadius)
map:SetAttribute("WorldId", 1)

local function folder(parent: Instance, name: string): Folder
    local node = Instance.new("Folder")
    node.Name = name
    node.Parent = parent
    return node
end

local partCount = 0
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
    local node = Instance.new("Part")
    node.Name = name
    node.Size = size
    node.CFrame = cf
    node.Color = color
    node.Material = Enum.Material.SmoothPlastic
    node.Anchored = true
    node.TopSurface = Enum.SurfaceType.Smooth
    node.BottomSurface = Enum.SurfaceType.Smooth
    node.Parent = parent
    partCount += 1
    return node
end

local function cylinder(parent: Instance, name: string, radius: number, height: number, position: Vector3, color: Color3): Part
    local node = part(parent, name, Vector3.new(height, radius * 2, radius * 2),
        CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color)
    node.Shape = Enum.PartType.Cylinder
    return node
end

local function radial(radius: number, angle: number, y: number): Vector3
    return Vector3.new(math.sin(angle) * radius, y, -math.cos(angle) * radius)
end

local function frame(radius: number, angle: number, y: number): CFrame
    local position = radial(radius, angle, y)
    return CFrame.lookAt(position, Vector3.new(0, y, 0))
end

local hub = folder(map, "Hub")
cylinder(hub, "Platform", C.hubRadius, C.hubHeight, Vector3.new(0, 1, 0), C.asphalt)
cylinder(hub, "CenterMark", C.logoRadius, C.logoHeight, Vector3.new(0, 2.1, 0), C.yellow)
for i = 1, C.lampCount do
    local angle = (i - 0.5) * math.pi * 2 / C.lampCount
    cylinder(hub, "PROP_lampadaire" .. i, C.lampDiameter / 2, C.lampHeight,
        radial(C.lampRadius, angle, C.plotTop + C.lampHeight / 2), C.placeholder)
end

local plots = folder(map, "Plots")
local roads = folder(map, "Liaisons")
local alleys = folder(map, "Ruelles")
for i = 1, C.plotCount do
    local angle = (i - 1) * math.pi * 2 / C.plotCount
    local plot = part(plots, "Plot" .. i, Vector3.new(C.plotSize, 1, C.plotSize),
        frame(C.plotRadius, angle, C.plotTop - 0.5), C.plotColor)
    plot:SetAttribute("Owner", "")
    local entrance = frame(C.plotRadius - C.plotSize / 2 + 1, angle, C.plotTop)
    part(plot, "EntranceLeft", Vector3.new(2, 8, 2), entrance * CFrame.new(-4, 4, 0), C.placeholder)
    part(plot, "EntranceRight", Vector3.new(2, 8, 2), entrance * CFrame.new(4, 4, 0), C.placeholder)
    part(plot, "EntranceLintel", Vector3.new(10, 2, 2), entrance * CFrame.new(0, 9, 0), C.placeholder)
    part(roads, "HubToPlot" .. i, Vector3.new(C.roadWidth, 1, C.roadEnd - C.roadStart),
        frame((C.roadStart + C.roadEnd) / 2, angle, C.plotTop - 0.5), C.asphalt)
    local nextAngle = i * math.pi * 2 / C.plotCount
    local a = radial(C.ringRadius, angle, C.plotTop - 0.5)
    local b = radial(C.ringRadius, nextAngle, C.plotTop - 0.5)
    part(roads, "RingLink" .. i, Vector3.new(C.roadWidth, 1, (b - a).Magnitude),
        CFrame.lookAt((a + b) / 2, b), C.asphalt)

    local alleyAngle = angle + math.pi / C.plotCount
    local alley = folder(alleys, "Ruelle" .. i)
    part(alley, "Floor", Vector3.new(C.roadWidth, 1, C.alleyEnd - C.alleyStart),
        frame((C.alleyStart + C.alleyEnd) / 2, alleyAngle, C.plotTop - 0.5), C.asphalt)
    -- Le point le plus bas touche le sol ; aucune rampe enterrée ou flottante.
    local rampHalfHeight = C.rampSize.X / 2 * math.sin(C.rampAngle)
        + C.rampSize.Y / 2 * math.cos(C.rampAngle)
    for j, radius in ipairs(C.rampRadii) do
        part(alley, "PROP_ramp" .. j, C.rampSize,
            frame(radius, alleyAngle, C.plotTop + rampHalfHeight)
                * CFrame.Angles(0, 0, (j == 1 and 1 or -1) * C.rampAngle), C.placeholder)
    end
    for j, radius in ipairs(C.trampolineRadii) do
        local pad = cylinder(alley, "PROP_trampoline" .. j, C.trampolineRadius, C.trampolineHeight,
            radial(radius, alleyAngle, C.plotTop + C.trampolineHeight / 2), C.red)
        pad:SetAttribute("Placeholder", true)
    end
end

-- Publication dans Workspace seulement une fois l'assemblage complet.
map:SetAttribute("WhiteMapBuild", "LotB_v1")
map.Parent = Workspace
print(("[BUILD] Map_Monde1: %d anchored parts; %d plots; radius %d")
    :format(partCount, C.plotCount, C.plotRadius))
