--!nonstrict
--[[ DressMapMonde1
     Rôle    : habiller la map du monde 1 avec le kit de props. Les placeholders nommés de la map blanche
               sont remplacés sur place ; tout ce qui s'ajoute vit dans Map_Monde1.Decor, un dossier par zone.
     Doc     : GAME_MASTER_V2 D1.2, D1.3 (Z1 à Z8), D1.4, D1.5, H2 étape 8 ; PROMPT_EXECUTION_SABL_V4 §21.1, §22.1
     Étape   : 8, lot B ; tranchées des ruelles comblées au lot D
     Dépend  : mode Édition ; Workspace.Map_Monde1 (étape 1) ; ServerStorage.PropModels
               (studio/BuildMapProps.luau, studio/BuildEggModels.luau)
     Exposé  : Hub.PROP_lampadaire1..12, RuelleN.PROP_ramp1..2 et PROP_trampoline1..2,
               ColiseeGate.PROP_arche_colisee ; Map_Monde1.Decor.{Hub, Ruelles, EggShop, BossArena, Colisee,
               Musee, Portails, Skyline}, dont Decor.Ruelles.RuelleN.Comblement1..2 ; idempotent ; bilan par zone
     Limite  : ne touche ni aux plots, ni aux piédestaux, ni aux liaisons, ni aux sols, ni au spawn.
               Noms et prix des œufs sont recopiés de EggConfig, faute de require depuis l'outil :
               studio/TestMapDecor.luau les compare à la config. Les PNJ (caisse, guide) et les deux
               classements du hub arrivent avec leurs systèmes.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local map = assert(Workspace:FindFirstChild("Map_Monde1"), "Map_Monde1 absent")
local kit = assert(ServerStorage:FindFirstChild("PropModels"), "ServerStorage.PropModels absent : lancer BuildMapProps")

-- D1.5 : la palette du monde 1.
local ASPHALT = Color3.fromHex("8A8580")
local MARKING = Color3.fromHex("FFD23F")
local KETCHUP = Color3.fromHex("E63946")
local MUSTARD = Color3.fromHex("FFB703")
local SALAD = Color3.fromHex("8AC926")
local NEONS = {KETCHUP, MUSTARD, SALAD}
-- D1.3 : couleurs de zone.
local SHOP_FACADE = Color3.fromHex("F4D58D") -- Z2
local MARBLE = Color3.fromHex("E9ECEF") -- Z4
local SOCLE = Color3.fromHex("111111") -- Z5 : socles noirs
local PORTALS = { -- Z8 : M2 rose, M3 bleu, M4 violet, panneaux Rebirth 3 / 5 / 10
    {world = 2, rebirth = 3, color = Color3.fromHex("FFD6E8")},
    {world = 3, rebirth = 5, color = Color3.fromHex("00B4D8")},
    {world = 4, rebirth = 10, color = Color3.fromHex("3A0CA3")},
}
-- Déclarées, le doc ne les donne pas.
local INK = Color3.fromHex("2B2D42")
local WHITE = Color3.new(1, 1, 1)

-- Z1 : la map blanche a posé 12 lampadaires (D1.6) là où D1.3 en compte 6 ; les 12 sont gardés.
local HUB_LAMP_COUNT, HUB_LAMP_RADIUS, HUB_LAMP_FIRST, HUB_LAMP_STEP = 12, 50, -75, 30
-- Les placeholders 9 et 10 tombent dans l'arène (Z3) : ils encadrent plutôt son escalier d'accès.
local ARENA_GATE_LAMPS = {[9] = 1, [10] = -1}
local ARENA_GATE_OFFSET, ARENA_GATE_SPREAD = 4, 8.8
-- Passages piétons aux bouches des liaisons diagonales : les 4 cardinales débouchent déjà sur une zone,
-- celles des plots 9 et 11 sont en partie couvertes par l'arène.
local CROSSWALK_PLOTS = {2, 3, 5, 6, 8, 12}
local CROSSWALK_RADII = {49, 51.4, 53.8, 56.2}
local CROSSWALK_STRIPE = Vector3.new(16, 0.1, 1.2)

-- Z7 : chaque ruelle est repérée depuis le centre de son sol, u le long de la ruelle vers l'extérieur,
-- v en travers vers le plot suivant. Rampes et trampolines reprennent les places de la map blanche.
local RAMPS = {{u = -12, toward = -1}, {u = 12, toward = 1}} -- toward : le plot vers lequel la rampe monte
local TRAMPOLINES = {32, 48}
local LAMPS = {{v = 8.5, u = -36}, {v = -8.5, u = 0}, {v = 8.5, u = 36}}
local BENCH = {v = -8.5, u = 22}
local GRAFFITIS = {{v = 9.5, u = -18}, {v = -9.5, u = 44}}
local TAGS = { -- graffitis multicolores : mots du bestiaire sur les couleurs de la palette
    {"BRAINROT!", MUSTARD, KETCHUP},
    {"TUNG TUNG", SALAD, Color3.fromHex("3A0CA3")},
    {"SAHUR!", KETCHUP, MUSTARD},
    {"TRALALA", Color3.fromHex("FFD6E8"), Color3.fromHex("00B4D8")},
    {"BOMBARDIRO", MARKING, INK},
    {"LA VACA", WHITE, SALAD},
}
local PLACEHOLDER_TOLERANCE = 1 -- stud : au-delà, la map blanche a bougé et le script s'arrête
-- Entre la ruelle et chaque plot voisin, la baseplate laissait une tranchée de 2 studs, large de 0 à 21 studs
-- vers l'extérieur ; un coin d'asphalte au niveau du sol la comble (accord du Producer, étape 8, lot D).
local NEIGHBOUR_COSINE = math.cos(math.rad(20)) -- les deux plots voisins sont à 15° de l'axe de la ruelle
local FILL_MARGIN = 0.05 -- stud laissé le long du plot : le comblement ne le chevauche pas

-- Z2 : les cinq œufs du monde 1, dans l'ordre de B2 et des socles. Noms et prix recopiés de EggConfig.
local EGGS = {
    {id = "egg_basic", name = "Œuf Street Basic", price = 100},
    {id = "egg_street", name = "Œuf Street", price = 8500},
    {id = "egg_golden", name = "Œuf Golden", price = 150000},
    {id = "egg_mythic", name = "Œuf Mythic", price = 5000000},
    {id = "egg_secret", name = "Œuf Interdit", price = 250000000},
}
local EGG_SCALE = 2 -- les œufs du kit mesurent 1,25 à 1,70 stud : perdus sur un socle de 4
local SHOP_HEIGHT, SHOP_WALL, SHOP_FASCIA = 12, 1, 4 -- Z2 : bâtiment 30 × 20 × 12

-- Z3 : octogone de rayon 25 aux sommets, un côté face à chaque axe, accès à l'est.
local ARENA_RADIUS, ARENA_SIDES = 25, 8
local SPECTATOR_RADIUS, SPECTATOR_SIZE = 18.5, 3 -- une place dans chaque coin, l'accès reste libre
-- Z4 : 8 marches, 4 de chaque côté du palier : la liaison vers le plot 1 reste praticable dans les deux sens.
local STEP_RISE, STEP_DEPTH, STEPS_PER_SIDE, STAIR_WIDTH, LANDING_DEPTH = 0.5, 1.5, 4, 20, 6
-- Z5 : 6 socles dans la vitrine, 2 rangées de 3.
local SOCLE_COLUMNS, SOCLE_ROWS, SOCLE_SIZE = {-6, 0, 6}, {-2, 2}, Vector3.new(2.4, 1.6, 2.4)
-- Z8 : un parvis le long de la liaison nord, côté ouest ; les portails regardent la liaison sans la barrer.
-- Le parvis commence au-delà de r=82 : plus au sud, la liaison du plot 12 vient en biais le couper.
local PLAZA_FROM, PLAZA_TO, PLAZA_WIDTH = 82, 134, 22
local PORTAL_ALONG, PORTAL_SIDE = {90, 108, 126}, 26
-- Skyline : 24 façades en couronne, au-delà du bout des ruelles (r = 280).
local SKYLINE_COUNT, SKYLINE_FIRST, SKYLINE_STEP = 24, 7.5, 15
local SKYLINE_RADII = {330, 345, 360, 338}
local SKYLINE_SCALES = {1, 1.5, 2, 1.25, 1.75}

-- Copie de Shared.NumberFormatter.format : l'étiquette doit dire ce que dit la boutique.
local SUFFIXES = {"", "K", "M", "B", "T"}
local function formatPrice(n)
    if n < 1000 then return tostring(math.floor(n)) end
    local index = 1
    while index < #SUFFIXES and n >= 1000 ^ index do index += 1 end
    local scaled = n / (1000 ^ (index - 1))
    local pattern = scaled >= 100 and "%.0f" or scaled >= 10 and "%.1f" or "%.2f"
    return pattern:format(scaled) .. SUFFIXES[index]
end

local function part(parent, name, size, cframe, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cframe
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

-- Marquage au sol ou liseré : ni collision, ni requête, ni contact.
local function flush(p)
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    return p
end

local function folder(parent, name)
    local f = Instance.new("Folder")
    f.Name = name
    f.Parent = parent
    return f
end

local function label(parent, name, text, color, size, position)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.BackgroundTransparency = 1
    l.Size = size
    l.Position = position
    l.TextScaled = true
    l.Font = Enum.Font.FredokaOne
    l.Text = text
    l.TextColor3 = color
    l.TextStrokeTransparency = 0.2
    l.Parent = parent
    return l
end

local function paint(host, face, text, textColor, background, glow)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "Paint" .. face.Name
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    if glow then gui.LightInfluence = 0 end -- néon : le texte ne dépend pas de l'éclairage
    local painted = label(gui, "TextLabel", text, textColor, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
    if background then
        painted.BackgroundColor3 = background
        painted.BackgroundTransparency = 0
    end
    gui.Parent = host
    return gui
end

local function topOf(p)
    local cf, size = p.CFrame, p.Size
    return cf.Position.Y + (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y
        + math.abs(cf.LookVector.Y) * size.Z) / 2
end

local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end

-- La map interdit deux frères homonymes (TestWhiteMap) : les pièces répétées du kit sont numérotées.
local function uniquify(root)
    local nodes = root:GetDescendants()
    table.insert(nodes, root)
    for _, node in ipairs(nodes) do
        local children = node:GetChildren()
        local total, seen = {}, {}
        for _, child in ipairs(children) do total[child.Name] = (total[child.Name] or 0) + 1 end
        for _, child in ipairs(children) do
            local base = child.Name
            if total[base] > 1 then
                seen[base] = (seen[base] or 0) + 1
                child.Name = base .. seen[base]
            end
        end
    end
end

local placed = {} -- nom du kit -> exemplaires posés, pour le bilan
local function spawnProp(kitName, name, cframe, parent)
    local source = assert(kit:FindFirstChild(kitName), "Prop absent du kit : " .. kitName)
    local model = source:Clone()
    model.Name = name
    uniquify(model)
    model:PivotTo(cframe)
    model.Parent = parent
    placed[kitName] = (placed[kitName] or 0) + 1
    return model
end

-- Remplacement sur place : le placeholder (ou le prop d'une passe précédente) cède sa place au prop du kit.
local function swap(parent, name, kitName, cframe, moved)
    local previous = parent:FindFirstChild(name)
    if previous then
        local spot = previous:IsA("Model") and previous:GetPivot().Position or previous.Position
        assert(moved or flat(spot - cframe.Position).Magnitude <= PLACEHOLDER_TOLERANCE,
            ("%s.%s n'est plus à sa place de map blanche"):format(parent.Name, name))
        previous:Destroy()
    end
    return spawnProp(kitName, name, cframe, parent)
end

local function tintLamp(model, color)
    local globe = model:FindFirstChild("Globe")
    globe.Color = color
    globe:FindFirstChildWhichIsA("PointLight").Color = color
end

-- Comble les deux tranchées d'une ruelle. Le bord du plot et celui de la ruelle s'écartent de 15° : le vide
-- est un triangle rectangle, pointe côté hub, angle droit au coin extérieur du plot. Un WedgePart couché le
-- remplit exactement, réduit de FILL_MARGIN le long du plot.
local function fillTrenches(floor, extras, center, out, across)
    local halfWidth, thickness, top = floor.Size.X / 2, floor.Size.Y, topOf(floor)
    local filled = 0
    for _, plot in ipairs(map.Plots:GetChildren()) do
        local direction = flat(plot.Position).Unit
        if plot:IsA("BasePart") and direction:Dot(out) > NEIGHBOUR_COSINE then
            local side = math.sign(direction:Dot(across))
            -- Les deux coins du plot tournés vers la ruelle, en coordonnées (u, v) de la ruelle.
            local corners = {}
            for _, x in ipairs({-1, 1}) do
                for _, z in ipairs({-1, 1}) do
                    local offset = flat(plot.CFrame * Vector3.new(x * plot.Size.X / 2, 0, z * plot.Size.Z / 2))
                        - flat(center)
                    table.insert(corners, {u = offset:Dot(out), v = offset:Dot(across)})
                end
            end
            table.sort(corners, function(a, b) return a.v * side < b.v * side end)
            local inner, outer = corners[1], corners[2]
            if inner.u > outer.u then inner, outer = outer, inner end
            -- La pointe : là où le bord du plot quitte le bord de la ruelle.
            local t = math.max(0, (halfWidth - side * inner.v) / (side * (outer.v - inner.v)))
            local along = outer.u - (inner.u + t * (outer.u - inner.u))
            local width = side * outer.v - halfWidth
            local shrink = 1 - FILL_MARGIN * math.sqrt(along ^ 2 + width ^ 2) / (along * width)
            along, width = along * shrink, width * shrink
            local spot = center + out * (outer.u - along / 2) + across * (side * (halfWidth + width / 2))
            local wedge = Instance.new("WedgePart")
            wedge.Name = "Comblement" .. (if side < 0 then 1 else 2)
            wedge.Size = Vector3.new(thickness, width, along)
            -- Épaisseur à la verticale, largeur en travers, longueur le long de la ruelle, pointe côté hub.
            wedge.CFrame = CFrame.fromMatrix(Vector3.new(spot.X, top - thickness / 2, spot.Z),
                Vector3.yAxis * side, across * side)
            wedge.Color = floor.Color
            wedge.Material = floor.Material
            wedge.Anchored = true
            wedge.TopSurface = Enum.SurfaceType.Smooth
            wedge.BottomSurface = Enum.SurfaceType.Smooth
            wedge.Parent = extras
            filled += 1
        end
    end
    return filled
end

local previousDecor = map:FindFirstChild("Decor")
if previousDecor then previousDecor:Destroy() end
local decor = folder(map, "Decor")
local lines = {}
local function report(zone, text)
    table.insert(lines, ("[DECOR] %-10s %s"):format(zone, text))
end

local hub = map.Hub
local hubTop = topOf(hub.Platform)
local arena = map.BossArena
local arenaTop = topOf(arena.Center)
local arenaSpot = Vector3.new(arena.Center.Position.X, arenaTop, arena.Center.Position.Z)
local apothem = ARENA_RADIUS * math.cos(math.pi / ARENA_SIDES)

-- Z1 — Place centrale.
local hubDecor = folder(decor, "Hub")
for index = 1, HUB_LAMP_COUNT do
    local angle = math.rad(HUB_LAMP_FIRST + (index - 1) * HUB_LAMP_STEP)
    local spot = Vector3.new(math.cos(angle) * HUB_LAMP_RADIUS, hubTop, math.sin(angle) * HUB_LAMP_RADIUS)
    local side = ARENA_GATE_LAMPS[index]
    if side then
        spot = Vector3.new(arenaSpot.X + apothem + ARENA_GATE_OFFSET, hubTop, arenaSpot.Z + side * ARENA_GATE_SPREAD)
    end
    local lamp = swap(hub, "PROP_lampadaire" .. index, "PROP_lampadaire", CFrame.new(spot), side ~= nil)
    tintLamp(lamp, NEONS[(index - 1) % #NEONS + 1])
end
for _, plotIndex in ipairs(CROSSWALK_PLOTS) do
    local road = assert(map.Liaisons:FindFirstChild("HubToPlot" .. plotIndex), "HubToPlot" .. plotIndex .. " absent")
    local out = flat(road.Position).Unit
    local crossing = folder(hubDecor, "Passage" .. plotIndex)
    for stripe, radius in ipairs(CROSSWALK_RADII) do
        local center = out * radius + Vector3.new(0, hubTop, 0)
        flush(part(crossing, "Bande" .. stripe, CROSSWALK_STRIPE, CFrame.lookAt(center, center + out), MARKING))
    end
end
local mark = hub.CenterMark
local logo = flush(part(hubDecor, "Logo", Vector3.new(16, 0.02, 16),
    CFrame.new(mark.Position.X, topOf(mark) + 0.01, mark.Position.Z), MARKING))
logo.Transparency = 1
local logoText = paint(logo, Enum.NormalId.Top, "BRAINROT", KETCHUP, nil, true).TextLabel
logoText.Size = UDim2.fromScale(0.9, 0.3)
logoText.Position = UDim2.fromScale(0.05, 0.35)
report("Hub", ("12 lampadaires du kit (9 et 10 a l'entree de l'arene), %d passages pietons, logo peint")
    :format(#CROSSWALK_PLOTS))

-- Z7 — Ruelles.
local ruellesDecor = folder(decor, "Ruelles")
local tagIndex, fills = 0, 0
for _, ruelle in ipairs(map.Ruelles:GetChildren()) do
    local floor = ruelle.Floor
    local number = tonumber(ruelle.Name:match("%d+"))
    local center = Vector3.new(floor.Position.X, topOf(floor), floor.Position.Z)
    local out = flat(floor.Position).Unit
    local across = Vector3.new(-out.Z, 0, out.X) -- vers le plot suivant, dans le sens des angles croissants
    local function at(v, u)
        return center + across * v + out * u
    end
    for index, ramp in ipairs(RAMPS) do
        local spot = at(0, ramp.u)
        swap(ruelle, "PROP_ramp" .. index, "PROP_ramp", CFrame.lookAt(spot, spot + across * ramp.toward))
    end
    for index, u in ipairs(TRAMPOLINES) do
        swap(ruelle, "PROP_trampoline" .. index, "PROP_trampoline", CFrame.new(at(0, u)))
    end
    local extras = folder(ruellesDecor, ruelle.Name)
    for index, spot in ipairs(LAMPS) do
        local lamp = spawnProp("PROP_lampadaire", "PROP_lampadaire" .. index, CFrame.new(at(spot.v, spot.u)), extras)
        tintLamp(lamp, NEONS[(number + index) % #NEONS + 1])
    end
    local benchSpot = at(BENCH.v, BENCH.u)
    spawnProp("PROP_banc", "PROP_banc1", CFrame.lookAt(benchSpot, benchSpot - across * math.sign(BENCH.v)), extras)
    for index, spot in ipairs(GRAFFITIS) do
        local position = at(spot.v, spot.u)
        local graffiti = spawnProp("PROP_graffiti", "PROP_graffiti" .. index,
            CFrame.lookAt(position, position - across * math.sign(spot.v)), extras)
        tagIndex += 1
        local front, back = TAGS[(tagIndex - 1) % #TAGS + 1], TAGS[tagIndex % #TAGS + 1]
        for _, gui in ipairs(graffiti.Tag:GetChildren()) do
            if gui:IsA("SurfaceGui") then
                local tag = gui.Face == Enum.NormalId.Front and front or back
                gui.TextLabel.Text = tag[1]
                gui.TextLabel.TextColor3 = tag[2]
                gui.TextLabel.BackgroundColor3 = tag[3]
            end
        end
    end
    fills += fillTrenches(floor, extras, center, out, across)
end
report("Ruelles", ("%d ruelles : 2 rampes, 2 trampolines, 3 lampadaires, 1 banc, 2 graffitis chacune ; %d tranchees comblees")
    :format(#map.Ruelles:GetChildren(), fills))

-- Z2 — Boutique d'œufs : ouverte sur la place à l'ouest, et à l'est sur la liaison du plot 4 qu'elle chevauche.
local shop = map.EggShop
local platform = shop.Platform
local shopDecor = folder(decor, "EggShop")
local shopFloor = topOf(platform)
local ground = topOf(Workspace.Baseplate)
local px, pz = platform.Position.X, platform.Position.Z
local halfX, halfZ = platform.Size.X / 2, platform.Size.Z / 2
local wallTop = shopFloor + SHOP_HEIGHT
local wallHeight = wallTop - ground
local trim = SHOP_FACADE:Lerp(Color3.new(0, 0, 0), 0.2)
for _, side in ipairs({-1, 1}) do
    local z = pz + side * (halfZ + SHOP_WALL / 2)
    local wallName = side < 0 and "N" or "S"
    part(shopDecor, "Mur" .. wallName, Vector3.new(halfX * 2, wallHeight, SHOP_WALL),
        CFrame.new(px, ground + wallHeight / 2, z), SHOP_FACADE)
    for _, edge in ipairs({-1, 1}) do
        part(shopDecor, "Pilier" .. wallName .. (edge < 0 and "O" or "E"), Vector3.new(2, wallHeight, 2),
            CFrame.new(px + edge * halfX, ground + wallHeight / 2, z), trim)
    end
end
part(shopDecor, "Toit", Vector3.new(halfX * 2 + 2, 1, halfZ * 2 + 2 * SHOP_WALL + 1),
    CFrame.new(px, wallTop + 0.5, pz), SHOP_FACADE:Lerp(Color3.new(0, 0, 0), 0.25))
for _, edge in ipairs({-1, 1}) do
    part(shopDecor, edge < 0 and "BandeauO" or "BandeauE", Vector3.new(1, SHOP_FASCIA, halfZ * 2 - 1),
        CFrame.new(px + edge * (halfX + 0.5), wallTop - SHOP_FASCIA / 2, pz), SHOP_FACADE)
end
local sign = part(shopDecor, "Enseigne", Vector3.new(0.2, SHOP_FASCIA - 1, halfZ * 2 - 4),
    CFrame.new(px - halfX - 1.1, wallTop - SHOP_FASCIA / 2, pz), INK)
paint(sign, Enum.NormalId.Left, "EGG SHOP", MUSTARD, nil, true)
local counter = part(shopDecor, "Comptoir", Vector3.new(8, 2.2, 2),
    CFrame.new(px + 10, shopFloor + 1.1, pz - halfZ + 1.5), KETCHUP)
part(shopDecor, "ComptoirPlateau", Vector3.new(8.4, 0.3, 2.4),
    CFrame.new(px + 10, shopFloor + 2.35, pz - halfZ + 1.5), MUSTARD)
paint(counter, Enum.NormalId.Back, "CAISSE", WHITE, nil, false)
local eggLines = {}
for index, egg in ipairs(EGGS) do
    local pedestal = assert(shop:FindFirstChild("Pedestal" .. index), "Pedestal" .. index .. " absent")
    local spot = Vector3.new(pedestal.Position.X, topOf(pedestal), pedestal.Position.Z)
    local facing = CFrame.lookAt(spot, spot - Vector3.xAxis) -- vers la place
    local model = spawnProp("PROP_" .. egg.id, "PROP_" .. egg.id, facing, shopDecor)
    model:ScaleTo(EGG_SCALE)
    model:PivotTo(facing)
    local height = model:GetExtentsSize().Y
    local tag = Instance.new("BillboardGui")
    tag.Name = "Etiquette"
    tag.Size = UDim2.fromScale(7, 2.4)
    tag.StudsOffsetWorldSpace = Vector3.new(0, height + 1.6, 0)
    tag.MaxDistance = 90
    tag.LightInfluence = 0
    tag:SetAttribute("EggId", egg.id)
    label(tag, "Nom", egg.name, WHITE, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0))
    label(tag, "Prix", formatPrice(egg.price) .. " 💰", MUSTARD, UDim2.fromScale(1, 0.58), UDim2.fromScale(0, 0.42))
    tag.Parent = model.PrimaryPart
    local mesh = model.Shell:FindFirstChildWhichIsA("SpecialMesh")
    table.insert(eggLines, ("%s %.2f stud (maillage x%.1f) %s"):format(egg.id, height, mesh.Scale.Y,
        formatPrice(egg.price)))
end
report("EggShop", ("batiment %dx%dx%d ouvert ouest et est, enseigne, caisse ; oeufs : %s")
    :format(halfX * 2, halfZ * 2, SHOP_HEIGHT, table.concat(eggLines, " | ")))

-- Z3 — Boss Arena.
local arenaDecor = folder(decor, "BossArena")
local sideLength = 2 * ARENA_RADIUS * math.sin(math.pi / ARENA_SIDES)
for index = 1, ARENA_SIDES do
    local theta = (index - 1) * 2 * math.pi / ARENA_SIDES
    local outward = Vector3.new(math.cos(theta), 0, math.sin(theta))
    local along = Vector3.new(-outward.Z, 0, outward.X)
    flush(part(arenaDecor, "Lisere" .. index, Vector3.new(sideLength, 0.12, 0.8),
        CFrame.fromMatrix(arenaSpot + outward * (apothem - 0.4), along, Vector3.yAxis), KETCHUP, Enum.Material.Neon))
end
spawnProp("PROP_boss_totem", "PROP_boss_totem", CFrame.lookAt(arenaSpot, arenaSpot + Vector3.xAxis), arenaDecor)
for index = 1, ARENA_SIDES do
    local theta = math.pi / ARENA_SIDES + (index - 1) * 2 * math.pi / ARENA_SIDES
    local position = arenaSpot + Vector3.new(math.cos(theta), 0, math.sin(theta)) * SPECTATOR_RADIUS
    local place = flush(part(arenaDecor, "Place" .. index, Vector3.new(SPECTATOR_SIZE, 0.1, SPECTATOR_SIZE),
        CFrame.lookAt(position, arenaSpot), MARKING))
    paint(place, Enum.NormalId.Top, tostring(index), INK, nil, false)
end
report("BossArena", ("totem au centre, liseré de %d segments, %d places de spectateurs"):format(ARENA_SIDES, ARENA_SIDES))

-- Z4 — Entrée du Colisée : l'arche du kit remplace les 3 pièces dorées, sur un palier à 8 marches.
local gate = map.ColiseeGate
local gateSpot
local oldArch = gate:FindFirstChild("PROP_arche_colisee")
if oldArch then
    gateSpot = oldArch:GetPivot().Position
else
    local left, right = gate:FindFirstChild("PillarLeft"), gate:FindFirstChild("PillarRight")
    assert(left and right, "ColiseeGate : ni arche du kit ni piliers de map blanche")
    gateSpot = (left.Position + right.Position) / 2
end
for _, name in ipairs({"PillarLeft", "PillarRight", "Lintel"}) do
    local placeholder = gate:FindFirstChild(name)
    if placeholder then placeholder:Destroy() end
end
local toHub = flat(-gateSpot).Unit
local stairBase = Vector3.new(gateSpot.X, hubTop, gateSpot.Z)
local landingTop = hubTop + STEPS_PER_SIDE * STEP_RISE
local coliseeDecor = folder(decor, "Colisee")
local stairs = Instance.new("Model")
stairs.Name = "Escalier"
local function slab(name, top, offset, depth)
    local center = stairBase + toHub * offset + Vector3.new(0, (top - hubTop) / 2, 0)
    return part(stairs, name, Vector3.new(STAIR_WIDTH, top - hubTop, depth),
        CFrame.lookAt(center, center + toHub), MARBLE, Enum.Material.Marble)
end
slab("Palier", landingTop, 0, LANDING_DEPTH)
local stepCount = 0
for _, direction in ipairs({1, -1}) do
    for step = 1, STEPS_PER_SIDE - 1 do
        stepCount += 1
        slab("Marche" .. stepCount, landingTop - step * STEP_RISE,
            direction * (LANDING_DEPTH / 2 + (step - 0.5) * STEP_DEPTH), STEP_DEPTH)
    end
end
stairs.Parent = coliseeDecor
local archSpot = Vector3.new(gateSpot.X, landingTop, gateSpot.Z)
swap(gate, "PROP_arche_colisee", "PROP_arche_colisee", CFrame.lookAt(archSpot, archSpot + toHub), true)
report("Colisee", ("arche du kit sur un palier a +%.1f, %d contremarches de %.1f"):format(
    landingTop - hubTop, 2 * STEPS_PER_SIDE, STEP_RISE))

-- Z5 — Musée des Secrets.
local case = map.Musee.DisplayCase
local museeDecor = folder(decor, "Musee")
local caseBottom = case.Position.Y - case.Size.Y / 2
local slot = 0
for _, dz in ipairs(SOCLE_ROWS) do
    for _, dx in ipairs(SOCLE_COLUMNS) do
        slot += 1
        local socle = part(museeDecor, "Socle" .. slot, SOCLE_SIZE,
            CFrame.new(case.Position.X + dx, caseBottom + SOCLE_SIZE.Y / 2, case.Position.Z + dz), SOCLE)
        socle:SetAttribute("Slot", slot)
    end
end
local museumSign = part(museeDecor, "Enseigne", Vector3.new(14, 1.8, 0.4),
    CFrame.new(case.Position.X, caseBottom + case.Size.Y + 0.9, case.Position.Z), INK)
paint(museumSign, Enum.NormalId.Front, "MUSÉE DES SECRETS", MARKING, nil, true)
paint(museumSign, Enum.NormalId.Back, "MUSÉE DES SECRETS", MARKING, nil, true)
report("Musee", ("%d socles noirs dans la vitrine, enseigne"):format(slot))

-- Z8 — Portails des mondes, derrière le Colisée.
local north = map.Liaisons.HubToPlot1
local northOut = flat(north.Position).Unit
local west = Vector3.new(northOut.Z, 0, -northOut.X) -- à gauche en marchant vers le plot 1
local roadTop = topOf(north)
local portalsDecor = folder(decor, "Portails")
local plazaCenter = northOut * ((PLAZA_FROM + PLAZA_TO) / 2) + west * (north.Size.X / 2 + PLAZA_WIDTH / 2)
    + Vector3.new(0, roadTop - 0.5, 0)
part(portalsDecor, "Parvis", Vector3.new(PLAZA_WIDTH, 1, PLAZA_TO - PLAZA_FROM),
    CFrame.lookAt(plazaCenter, plazaCenter + northOut), ASPHALT)
for index, spec in ipairs(PORTALS) do
    local spot = northOut * PORTAL_ALONG[index] + west * PORTAL_SIDE + Vector3.new(0, roadTop, 0)
    local portal = spawnProp("PROP_portail_monde", "PROP_portail_monde" .. spec.world,
        CFrame.lookAt(spot, spot - west), portalsDecor)
    portal:SetAttribute("WorldId", spec.world)
    portal.Vortex.Color = spec.color
    portal.Vortex.Vortex.Color = ColorSequence.new(spec.color)
    portal.Sign.Paint.TextLabel.Text = ("REBIRTH %d REQUIS"):format(spec.rebirth)
end
report("Portails", "parvis a l'ouest de la liaison nord, portails M2, M3, M4 tournes vers elle")

-- Skyline.
local skyline = folder(decor, "Skyline")
for index = 1, SKYLINE_COUNT do
    local angle = math.rad(SKYLINE_FIRST + (index - 1) * SKYLINE_STEP)
    local radius = SKYLINE_RADII[(index - 1) % #SKYLINE_RADII + 1]
    local spot = Vector3.new(math.cos(angle) * radius, ground, math.sin(angle) * radius)
    local building = spawnProp("PROP_batiment" .. ((index - 1) % 6 + 1), "Batiment" .. index,
        CFrame.lookAt(spot, Vector3.new(0, ground, 0)), skyline)
    building:ScaleTo(SKYLINE_SCALES[(index - 1) % #SKYLINE_SCALES + 1])
end
report("Skyline", ("%d facades entre r=%d et r=%d, echelles 1 a 2, tournees vers le hub")
    :format(SKYLINE_COUNT, math.min(table.unpack(SKYLINE_RADII)), math.max(table.unpack(SKYLINE_RADII))))

-- Bilan : ce qui a été posé, et les règles de TestWhiteMap tenues sur toute la map.
local parts, loose = 0, 0
for _, node in ipairs(decor:GetDescendants()) do
    if node:IsA("BasePart") then
        parts += 1
        if not node.Anchored then loose += 1 end
    end
end
local leftovers, duplicates, badNames = 0, 0, 0
for _, zone in ipairs({hub, gate, table.unpack(map.Ruelles:GetChildren())}) do
    for _, child in ipairs(zone:GetChildren()) do
        if child:IsA("BasePart") and child.Name:match("^PROP_") then leftovers += 1 end
    end
end
local nodes = map:GetDescendants()
table.insert(nodes, map)
for _, node in ipairs(nodes) do
    local names = {}
    for _, child in ipairs(node:GetChildren()) do
        if names[child.Name] then duplicates += 1 end
        names[child.Name] = true
    end
    if not node.Name:match("^[%w_]+$") then badNames += 1 end
end
local kinds = {}
for name, count in pairs(placed) do table.insert(kinds, ("%s x%d"):format(name, count)) end
table.sort(kinds)
table.insert(lines, "[DECOR] props     " .. table.concat(kinds, ", "))
table.insert(lines, ("[BILAN] %d pieces dans Decor, %d non ancrees ; %d placeholders restants ; %d freres homonymes ; %d noms hors ASCII")
    :format(parts, loose, leftovers, duplicates, badNames))
print(table.concat(lines, "\n"))
return table.concat(lines, "\n")
