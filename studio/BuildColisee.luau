--!strict
--[[ BuildColisee
     Rôle    : construire le Colisée placeholder (D5.6) : Workspace/Map_Colisee à Y = 1000, en primitives ancrées.
     Doc     : GAME_MASTER_V2 D5.2, D5.3, D5.5, D5.6, E2 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot B, §22.1 ;
               Q1-Q2 du lot B (02/10 : A, A) ; décision 116
     Étape   : 13, lot B
     Dépend  : Studio en Édition ; aucun script de gameplay
     Exposé  : construction manuelle, idempotente (attribut ColiseeBuild) ; aucun script, aucune téléportation
     Limite  : placeholders (Loi 5, H5.6) : arcades, banderoles, PNJ et écran sont des blocs nommés. Entrée sud
               ouverte sur ±15° pour les 2 tunnels ; les étages 2 et 3 de la coque font arche au-dessus.
               SpawnColisee est désactivé : point d'arrivée des téléportations, il ne capte jamais l'apparition.
]]
local Workspace = game:GetService("Workspace")
-- Mode Édition requis ; pcall : hors de Studio (test Lune), RunService n'expose pas IsRunning.
local okRun, running = pcall(function() return game:GetService("RunService"):IsRunning() end)
assert(not (okRun and running), "Mode Édition requis")

local C = {
    origin = Vector3.new(0, 1000, 0), -- D5.6 : Y = 1000
    floorTop = 1, -- dessus du sol, en relatif ; les cercles d'apparition sont à y = 1 (D5.6)
    pitRadius = 30, wallHeight = 6, wallThickness = 1, -- D5.6 : fosse r = 30, murets h = 6
    spawnRadius = 4, spawnOffset = 10, -- D5.6 : cercles r = 4 à x = ∓10
    tiers = { -- D5.3 : N1 45-60, N2 60-75, N3 75-90 ; Q2 : 6, 12, 18 au-dessus du sol de la fosse
        {Name = "N1", Inner = 45, Outer = 60, Rise = 6},
        {Name = "N2", Inner = 60, Outer = 75, Rise = 12},
        {Name = "N3", Inner = 75, Outer = 90, Rise = 18},
    },
    segments = 24, -- D5.6 : 24 segments de 15°
    openSouth = {[6] = true, [7] = true}, -- segments centrés à 82,5° et 97,5° : l'entrée sud (±15°)
    shellInner = 90, shellThickness = 2, shellLevelHeight = 8, shellLevels = 3, -- D5.6 : coque r = 90, 3 anneaux
    screenSize = Vector3.new(40, 20, 1), screenZ = 80, screenGap = 2, -- D5.3 : écran 40 × 20 au sud
    hallRadius = 45, hallSegments = 12, -- Q1 : demi-disque r = 45 hors de la coque, au sud
    lodgeSize = 10, lodges = 4, -- D5.3 : 4 loges 10 × 10
    tunnelWidth = 6, tunnelOffset = 3.5, -- D5.3 : 2 tunnels larges de 6, bleu (A) et rouge (B)
    spectators = 60, spectatorRadius = 67.5, spectatorSize = Vector3.new(2, 3, 2), -- D5.3 : 60 PNJ en N2
    braziers = 4, brazierRadius = 38, -- D5.6 : 4 braseros or
    gold = Color3.fromHex("FFD23F"), stone = Color3.fromHex("B8A88A"), marble = Color3.fromHex("E9ECEF"),
    blue = Color3.fromHex("4CC9F0"), red = Color3.fromHex("E63946"), neon = Color3.fromHex("F72585"), -- D5.5
}

local existing = Workspace:FindFirstChild("Map_Colisee")
if existing then
    assert(existing:GetAttribute("ColiseeBuild") == "LotB_v1", "Map_Colisee existant à inspecter")
    print("[BUILD] Map_Colisee LotB_v1 already exists; no changes")
    return
end

local map = Instance.new("Model")
map.Name = "Map_Colisee"
local count = 0
local function folder(name: string, parent: Instance?): Model
    local node = Instance.new("Model")
    node.Name = name
    node.Parent = parent or map
    return node
end
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
    local node = Instance.new("Part")
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
-- Disque vertical : cylindre couché dont l'axe X devient l'axe Y.
local function disc(parent: Instance, name: string, radius: number, height: number, center: Vector3, color: Color3): Part
    local node = part(parent, name, Vector3.new(height, radius * 2, radius * 2),
        CFrame.new(C.origin + center) * CFrame.Angles(0, 0, math.pi / 2), color)
    node.Shape = Enum.PartType.Cylinder
    return node
end
local function at(x: number, y: number, z: number): CFrame
    return CFrame.new(C.origin + Vector3.new(x, y, z))
end
local step = 2 * math.pi / C.segments
-- Segment d'anneau k (1 à 24) entre deux rayons, du bas au haut (relatifs) ; le bloc couvre le bord extérieur.
local function ringSegment(parent: Instance, name: string, k: number, inner: number, outer: number,
        bottom: number, top: number, color: Color3): Part
    local angle = (k - 0.5) * step
    local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
    local width = 2 * outer * math.tan(step / 2)
    local center = C.origin + radial * ((inner + outer) / 2) + Vector3.new(0, (bottom + top) / 2, 0)
    return part(parent, name, Vector3.new(width, top - bottom, outer - inner),
        CFrame.new(center) * CFrame.Angles(0, math.pi / 2 - angle, 0), color)
end

-- Sol commun (fosse, couloir, gradins) : disque r = 90, dessus à y = 1.
local ground = folder("Sol")
disc(ground, "Sol", C.shellInner, 2, Vector3.new(0, C.floorTop - 1, 0), C.stone)

-- Fosse : murets de 6 de haut à r = 30, ouverts au sud ; 2 cercles d'apparition (D5.6).
local pit = folder("Fosse")
for k = 1, C.segments do
    if not C.openSouth[k] then
        ringSegment(pit, "Muret" .. k, k, C.pitRadius, C.pitRadius + C.wallThickness,
            C.floorTop, C.floorTop + C.wallHeight, C.stone)
    end
end
disc(pit, "CercleBleu", C.spawnRadius, 0.2, Vector3.new(-C.spawnOffset, C.floorTop, 0), C.blue).Material =
    Enum.Material.Neon
disc(pit, "CercleRouge", C.spawnRadius, 0.2, Vector3.new(C.spawnOffset, C.floorTop, 0), C.red).Material =
    Enum.Material.Neon

-- Gradins : 3 niveaux × 24 segments, ouverts au sud ; N3 en or (loges VIP, D5.3).
local stands = folder("Gradins")
for _, tier in ipairs(C.tiers) do
    local tierModel = folder(tier.Name, stands)
    for k = 1, C.segments do
        if not C.openSouth[k] then
            ringSegment(tierModel, "Segment" .. k, k, tier.Inner, tier.Outer, C.floorTop, C.floorTop + tier.Rise,
                if tier.Name == "N3" then C.gold else C.stone)
        end
    end
end

-- Coque : 3 anneaux d'arcades de 8 ; le premier s'ouvre au sud (entrée), les deux autres font arche.
local shell = folder("Coque")
for level = 1, C.shellLevels do
    local ring = folder("Anneau" .. level, shell)
    local bottom = C.floorTop + (level - 1) * C.shellLevelHeight
    for k = 1, C.segments do
        if level > 1 or not C.openSouth[k] then
            ringSegment(ring, "Arcade" .. k, k, C.shellInner, C.shellInner + C.shellThickness,
                bottom, bottom + C.shellLevelHeight, C.gold)
        end
    end
end

-- Écran géant 40 × 20, suspendu au sud au-dessus de N3, tourné vers la fosse (D5.3, SurfaceGui de D5.6).
local screen = part(map, "EcranGeant", C.screenSize,
    at(0, C.floorTop + C.tiers[3].Rise + C.screenGap + C.screenSize.Y / 2, C.screenZ), C.neon)
screen.Material = Enum.Material.Neon
local gui = Instance.new("SurfaceGui")
gui.Name = "Affichage"
gui.Face = Enum.NormalId.Front -- face -Z : vers le centre de la fosse
gui.Parent = screen
local label = Instance.new("TextLabel")
label.Name = "Titre"
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "COLISÉE BRAINROT"
label.TextScaled = true
label.Parent = gui

-- Tunnels A (bleu) et B (rouge) : du hall (z = 92) à la fosse (z = 30), entre 3 cloisons de 6 de haut.
local tunnels = folder("Tunnels")
local tunnelStart, tunnelEnd = C.pitRadius, C.shellInner + C.shellThickness
local tunnelLength = tunnelEnd - tunnelStart
local tunnelZ = (tunnelStart + tunnelEnd) / 2
part(tunnels, "TunnelA", Vector3.new(C.tunnelWidth, 0.2, tunnelLength), at(-C.tunnelOffset, C.floorTop + 0.1, tunnelZ),
    C.blue).Material = Enum.Material.Neon
part(tunnels, "TunnelB", Vector3.new(C.tunnelWidth, 0.2, tunnelLength), at(C.tunnelOffset, C.floorTop + 0.1, tunnelZ),
    C.red).Material = Enum.Material.Neon
for i, x in ipairs({-(C.tunnelOffset + C.tunnelWidth / 2 + 0.5), 0, C.tunnelOffset + C.tunnelWidth / 2 + 0.5}) do
    part(tunnels, "Cloison" .. i, Vector3.new(1, C.wallHeight, tunnelLength), at(x, C.floorTop + C.wallHeight / 2, tunnelZ),
        C.stone)
end

-- Hall (Q1, option A) : demi-disque r = 45 collé à la coque côté sud, en marbre.
local hall = folder("Hall")
local hallCenter = C.shellInner + C.shellThickness
-- Parvis : comble le vide entre le bord circulaire du sol (r = 90) et le bord droit du hall (z = 92) dans l'entrée
-- ouverte ; 5 cm sous le sol pour ne pas se superposer à lui.
local gapHalfWidth = (C.shellInner + C.shellThickness) * math.sin(step) + 1
part(hall, "Parvis", Vector3.new(2 * gapHalfWidth, 2, 8), at(0, C.floorTop - 1.05, hallCenter - 4), C.stone)
local hallStep = math.pi / C.hallSegments
for k = 1, C.hallSegments do
    local angle = (k - 0.5) * hallStep -- de +X à -X en passant par +Z (sud)
    local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
    local width = 2 * C.hallRadius * math.tan(hallStep / 2)
    local center = Vector3.new(0, C.floorTop - 1, hallCenter) + radial * (C.hallRadius / 2)
    part(hall, "Dalle" .. k, Vector3.new(width, 2, C.hallRadius),
        CFrame.new(C.origin + center) * CFrame.Angles(0, math.pi / 2 - angle, 0), C.marble)
end
local hallY = C.floorTop
for i, board in ipairs({"ClassementGlobal", "ClassementServeur", "ClassementSaison"}) do -- D5.3 : 3 panneaux Elo
    part(hall, board, Vector3.new(8, 6, 0.5), at((i - 2) * 10, hallY + 3, hallCenter + 3), C.gold)
end
part(hall, "BoutiqueTokens", Vector3.new(10, 4, 4), at(-24, hallY + 2, hallCenter + 14), C.gold)
part(hall, "NPC_File1v1", Vector3.new(2, 5, 2), at(-8, hallY + 2.5, hallCenter + 16), C.blue) -- E2 : NPC bleu
part(hall, "NPC_File2v2", Vector3.new(2, 5, 2), at(8, hallY + 2.5, hallCenter + 16), C.red) -- E2 : NPC rouge
part(hall, "PorteSpectateur", Vector3.new(6, 8, 1), at(24, hallY + 4, hallCenter + 14), C.marble)
local lodgesModel = folder("Loges", hall)
for i = 1, C.lodges do
    local lodge = folder("Loge" .. i, lodgesModel)
    local x = (i - 2.5) * (C.lodgeSize + 2)
    local z = hallCenter + 30
    local color = if i <= 2 then C.blue else C.red
    part(lodge, "Sol", Vector3.new(C.lodgeSize, 0.2, C.lodgeSize), at(x, hallY + 0.1, z), color)
    part(lodge, "MurFond", Vector3.new(C.lodgeSize, 4, 0.5), at(x, hallY + 2, z + C.lodgeSize / 2), C.marble)
    part(lodge, "MurGauche", Vector3.new(0.5, 4, C.lodgeSize), at(x - C.lodgeSize / 2, hallY + 2, z), C.marble)
    part(lodge, "MurDroit", Vector3.new(0.5, 4, C.lodgeSize), at(x + C.lodgeSize / 2, hallY + 2, z), C.marble)
end
local spawnPoint = Instance.new("SpawnLocation")
spawnPoint.Name = "SpawnColisee"
spawnPoint.Size = Vector3.new(6, 1, 6)
spawnPoint.CFrame = at(0, hallY + 0.5, hallCenter + 8)
spawnPoint.Anchored = true
spawnPoint.Enabled = false -- point d'arrivée des téléportations : ne capte jamais l'apparition (décision 116)
spawnPoint.Parent = hall
count += 1

-- 60 spectateurs placeholders sur N2, répartis hors de l'entrée sud (D5.3).
local crowd = folder("Spectateurs")
local arcStart, arcEnd = math.rad(105), math.rad(435) -- 330° hors du secteur sud (75° → 105°)
for i = 1, C.spectators do
    local angle = arcStart + (i - 0.5) * (arcEnd - arcStart) / C.spectators
    local position = Vector3.new(math.cos(angle) * C.spectatorRadius,
        C.floorTop + C.tiers[2].Rise + C.spectatorSize.Y / 2, math.sin(angle) * C.spectatorRadius)
    part(crowd, "Spectateur" .. i, C.spectatorSize, CFrame.lookAt(C.origin + position, C.origin), C.stone)
end

-- 4 braseros or dans le couloir entre la fosse et N1 (D5.6).
local fires = folder("Braseros")
for i = 1, C.braziers do
    local angle = math.rad(45 + (i - 1) * 90)
    local x, z = math.cos(angle) * C.brazierRadius, math.sin(angle) * C.brazierRadius
    part(fires, "Brasero" .. i, Vector3.new(2, 4, 2), at(x, C.floorTop + 2, z), C.gold)
    part(fires, "Flamme" .. i, Vector3.new(1.5, 1.5, 1.5), at(x, C.floorTop + 4.75, z), C.red).Material =
        Enum.Material.Neon
end

map:SetAttribute("ColiseeBuild", "LotB_v1")
map.Parent = Workspace
print(("[BUILD] Map_Colisee LotB_v1 : %d pièces ancrées à Y = 1000"):format(count))
