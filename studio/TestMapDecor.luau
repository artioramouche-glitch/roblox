--!nonstrict
--[[ TestMapDecor
     Rôle    : vérifier l'habillage du monde 1 : props du kit à leur place, zones de D1.3, règles de la map.
     Doc     : GAME_MASTER_V2 D1.3 (Z1 à Z8), D1.4, D1.5, H2 étape 8 ; PROMPT_EXECUTION_SABL_V4 §25.2
     Étape   : 8, lot B ; comblements des tranchées au lot D
     Dépend  : Play serveur ; Workspace.Map_Monde1 habillée par studio/DressMapMonde1.luau ;
               Config.EggConfig, Shared.NumberFormatter ; lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; ne modifie rien
     Limite  : contrôle la géométrie et les données, pas le rendu : l'œil humain juge l'ensemble. La traversée
               du spawn à chaque plot reste prouvée par studio/TestWhiteMap.luau, lancé en Édition.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local EggConfig = require(ReplicatedStorage.Config.EggConfig)
local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)

local NEONS = {"E63946", "FFB703", "8AC926"} -- D1.5 : ketchup, moutarde, salade
local ARENA_TRIM = "E63946" -- Z3
local SOCLE = "111111" -- Z5
local PORTALS = {[2] = {"FFD6E8", 3}, [3] = {"00B4D8", 5}, [4] = {"3A0CA3", 10}} -- Z8 : couleur, rebirth requis
local RUELLE_PROPS = {ramp = 2, trampoline = 2, lampadaire = 3, banc = 1, graffiti = 2} -- Z7
local RUELLE_HALF_WIDTH, RUELLE_HALF_LENGTH = 10, 60
local FILL_COUNT = 12 * 2 -- lot D : une tranchée comblée de chaque côté de chaque ruelle
local LAMP_TOTAL = 12 + 12 * 3 -- hub et ruelles
local ARENA_RADIUS = 25 -- Z3, aux sommets
local SHOP_HEIGHT = 12 -- Z2
local STEP_COUNT, STEP_RISE_MAX = 8, 0.5 -- Z4
local SKYLINE_COUNT, SKYLINE_MIN_RADIUS = 24, 300
local PEDESTALS_PER_PLOT = 25
local EPSILON = 0.05

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function finish()
    table.insert(T.lines, ("[DECOR TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
    local output = table.concat(T.lines, "\n")
    print(output)
    return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
end

local function topOf(p)
    local cf, size = p.CFrame, p.Size
    return cf.Position.Y + (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y
        + math.abs(cf.LookVector.Y) * size.Z) / 2
end
local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end
local function hex(color)
    return color:ToHex():upper()
end
local function corners(p)
    local list, half = {}, p.Size / 2
    for _, x in ipairs({-1, 1}) do
        for _, y in ipairs({-1, 1}) do
            for _, z in ipairs({-1, 1}) do
                table.insert(list, p.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z))
            end
        end
    end
    return list
end
local function partsOf(root)
    local list = {}
    for _, node in ipairs(root:GetDescendants()) do
        if node:IsA("BasePart") then table.insert(list, node) end
    end
    return list
end
local function propsIn(container)
    local list = {}
    for _, child in ipairs(container and container:GetChildren() or {}) do
        if child:IsA("Model") and child:GetAttribute("PropId") then table.insert(list, child) end
    end
    return list
end
local function count(set)
    local n = 0
    for _ in pairs(set) do n += 1 end
    return n
end

local map = Workspace:FindFirstChild("Map_Monde1")
local decor = map and map:FindFirstChild("Decor")
check("Map_Monde1.Decor present", decor ~= nil)
if not decor then return finish() end
local function zone(name)
    return decor:FindFirstChild(name) or Instance.new("Folder")
end

-- Z1 : les placeholders sont partis, les lampadaires du kit sont debout sur le hub.
local hub = map.Hub
local hubTop = topOf(hub.Platform)
local arenaCenter = map.BossArena.Center.Position
local arenaTop = topOf(map.BossArena.Center)
local leftovers = 0
for _, container in ipairs({hub, table.unpack(map.Ruelles:GetChildren())}) do
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("BasePart") and child.Name:match("^PROP_") then leftovers += 1 end
    end
end
local lamps, standing = {}, 0
for index = 1, 12 do
    local lamp = hub:FindFirstChild("PROP_lampadaire" .. index)
    if lamp and lamp:IsA("Model") and lamp:GetAttribute("PropId") == "lampadaire" then
        table.insert(lamps, lamp)
        local pivot = lamp:GetPivot().Position
        if math.abs(pivot.Y - hubTop) < EPSILON and flat(pivot - arenaCenter).Magnitude > ARENA_RADIUS then
            standing += 1
        end
    end
end
check(("Z1 : 12 lampadaires du kit remplacent les placeholders (%d poses, %d placeholders restants)")
    :format(#lamps, leftovers), #lamps == 12 and leftovers == 0)
check(("Z1 : lampadaires debout sur le hub, aucun dans l'arene (%d/12)"):format(standing), standing == 12)

-- D1.4 : globe néon multicolore, lumière assortie.
local allLamps = table.clone(lamps)
for _, extras in ipairs(zone("Ruelles"):GetChildren()) do
    for _, prop in ipairs(propsIn(extras)) do
        if prop:GetAttribute("PropId") == "lampadaire" then table.insert(allLamps, prop) end
    end
end
local neon, used, stray = {}, {}, 0
for _, color in ipairs(NEONS) do neon[color] = true end
for _, lamp in ipairs(allLamps) do
    local globe = lamp:FindFirstChild("Globe")
    local light = globe and globe:FindFirstChildWhichIsA("PointLight")
    local key = globe and hex(globe.Color)
    if key and neon[key] and light and hex(light.Color) == key then used[key] = true else stray += 1 end
end
check(("D1.4 : %d globes neon aux %d couleurs de D1.5, %d hors palette"):format(#allLamps, count(used), stray),
    #allLamps == LAMP_TOTAL and count(used) == #NEONS and stray == 0)

-- Z7 : le terrain de chases.
local ruelleCount, complete, misplaced, badRamps, badTrampolines = 0, 0, {}, 0, 0
local backgrounds = {}
for _, ruelle in ipairs(map.Ruelles:GetChildren()) do
    ruelleCount += 1
    local floor = ruelle.Floor
    local floorTop = topOf(floor)
    local center = flat(floor.Position)
    local out = center.Unit
    local across = Vector3.new(-out.Z, 0, out.X)
    local props = propsIn(ruelle)
    for _, prop in ipairs(propsIn(zone("Ruelles"):FindFirstChild(ruelle.Name))) do table.insert(props, prop) end
    local counts = {}
    for _, prop in ipairs(props) do
        local id = prop:GetAttribute("PropId")
        counts[id] = (counts[id] or 0) + 1
        local inside = math.abs(prop:GetPivot().Position.Y - floorTop) < EPSILON
        for _, p in ipairs(partsOf(prop)) do
            for _, corner in ipairs(corners(p)) do
                local offset = flat(corner) - center
                if math.abs(offset:Dot(across)) > RUELLE_HALF_WIDTH + EPSILON
                    or math.abs(offset:Dot(out)) > RUELLE_HALF_LENGTH + EPSILON then
                    inside = false
                end
            end
        end
        if not inside then table.insert(misplaced, ruelle.Name .. "." .. prop.Name) end
        if id == "ramp" then
            local lowest = math.huge
            for _, corner in ipairs(corners(prop.Slab)) do lowest = math.min(lowest, corner.Y) end
            if math.abs(math.abs(prop:GetPivot().LookVector:Dot(across)) - 1) > 0.001
                or math.abs(lowest - floorTop) > EPSILON then
                badRamps += 1
            end
        elseif id == "trampoline" then
            local bed = prop:FindFirstChild("Bed")
            if prop:GetAttribute("Trampoline") ~= true or not bed or bed:GetAttribute("Trampoline") ~= true then
                badTrampolines += 1
            end
        elseif id == "graffiti" then
            for _, gui in ipairs(prop.Tag:GetChildren()) do
                if gui:IsA("SurfaceGui") then backgrounds[hex(gui.TextLabel.BackgroundColor3)] = true end
            end
        end
    end
    local full = true
    for id, expected in pairs(RUELLE_PROPS) do
        if counts[id] ~= expected then full = false end
    end
    if full then complete += 1 end
end
check(("Z7 : %d ruelles completes sur %d (2 rampes, 2 trampolines, 3 lampadaires, 1 banc, 2 graffitis)")
    :format(complete, ruelleCount), ruelleCount == 12 and complete == 12)
check(("Z7 : chaque prop pose sur le sol de sa ruelle, dans ses 20 studs%s")
    :format(#misplaced > 0 and (" ; hors : " .. table.concat(misplaced, ", ")) or ""), #misplaced == 0)
check(("Z7 : les rampes montent en travers vers un plot, arete basse au sol (%d en defaut)"):format(badRamps),
    badRamps == 0)
check(("Lot C : chaque trampoline porte l'attribut Trampoline, modele et toile (%d en defaut)"):format(badTrampolines),
    badTrampolines == 0)
check(("Z7 : graffitis multicolores, %d fonds differents"):format(count(backgrounds)), count(backgrounds) >= 6)

-- Lot D : les tranchées entre ruelle et plots sont comblées au niveau du sol. Au barycentre de chaque coin,
-- le sol doit être le coin lui-même : c'est la preuve qu'il est orienté pour remplir le vide.
local fills, levelled, solid = 0, 0, 0
local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.FilterDescendantsInstances = {map}
for _, ruelle in ipairs(map.Ruelles:GetChildren()) do
    local floorTop = topOf(ruelle.Floor)
    local extras = zone("Ruelles"):FindFirstChild(ruelle.Name)
    for _, fill in ipairs(extras and extras:GetChildren() or {}) do
        if fill:IsA("WedgePart") and fill.Name:match("^Comblement%d$") then
            fills += 1
            if math.abs(topOf(fill) - floorTop) < 0.01 then levelled += 1 end
            local centroid = fill.CFrame * Vector3.new(0, -fill.Size.Y / 6, fill.Size.Z / 6)
            local hit = Workspace:Raycast(centroid + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), ground)
            if hit and hit.Instance == fill then solid += 1 end
        end
    end
end
check(("Lot D : %d tranchees comblees (attendu %d), %d au niveau du sol, %d pleines en leur centre")
    :format(fills, FILL_COUNT, levelled, solid), fills == FILL_COUNT and levelled == FILL_COUNT and solid == FILL_COUNT)

-- Z2 : la boutique d'œufs.
local shop = map.EggShop
local shopDecor = zone("EggShop")
local worldEggs = {}
for _, egg in ipairs(EggConfig.Eggs) do
    if egg.world == 1 then table.insert(worldEggs, egg) end
end
local seated, tagged, tagErrors = 0, 0, {}
for index, egg in ipairs(worldEggs) do
    local pedestal = shop:FindFirstChild("Pedestal" .. index)
    local model = shopDecor:FindFirstChild("PROP_" .. egg.id)
    if pedestal and model and model:GetAttribute("PropId") == egg.id then
        local spot = Vector3.new(pedestal.Position.X, topOf(pedestal), pedestal.Position.Z)
        if (model:GetPivot().Position - spot).Magnitude < EPSILON then seated += 1 end
        local tag = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Etiquette")
        local price = NumberFormatter.format(egg.price) .. " 💰"
        if tag and tag.Nom.Text == egg.name and tag.Prix.Text == price then
            tagged += 1
        else
            table.insert(tagErrors, ("%s attendu « %s » %s"):format(egg.id, egg.name, price))
        end
    end
end
check(("Z2 : les %d oeufs du monde 1 sur les socles, dans l'ordre de EggConfig (%d poses)"):format(#worldEggs, seated),
    #worldEggs == 5 and seated == 5)
check(("Z2 : etiquettes = nom et prix de EggConfig au format de la boutique (%d/5)%s")
    :format(tagged, #tagErrors > 0 and (" ; " .. table.concat(tagErrors, ", ")) or ""), tagged == 5)
local platform = shop.Platform
local shopFloor = topOf(platform)
local roof = shopDecor:FindFirstChild("Toit")
local aisles = RaycastParams.new()
aisles.FilterType = Enum.RaycastFilterType.Include
aisles.FilterDescendantsInstances = {shopDecor}
local crossable = true
for _, dz in ipairs({-6, 6}) do
    local origin = Vector3.new(platform.Position.X - platform.Size.X / 2 - 10, shopFloor + 2, platform.Position.Z + dz)
    if Workspace:Raycast(origin, Vector3.new(platform.Size.X + 20, 0, 0), aisles) then crossable = false end
end
check(("Z2 : batiment de %d au-dessus du sol, traversable d'ouest en est par ses deux allees"):format(SHOP_HEIGHT),
    roof ~= nil and math.abs(roof.Position.Y - roof.Size.Y / 2 - shopFloor - SHOP_HEIGHT) < EPSILON and crossable)

-- Z3 : l'arène.
local arenaDecor = zone("BossArena")
local arenaSpot = Vector3.new(arenaCenter.X, arenaTop, arenaCenter.Z)
local totem = arenaDecor:FindFirstChild("PROP_boss_totem")
check("Z3 : PROP_boss_totem au centre du plateau", totem ~= nil and (totem:GetPivot().Position - arenaSpot).Magnitude < EPSILON)
local trims, places = 0, 0
for _, child in ipairs(arenaDecor:GetChildren()) do
    if child.Name:match("^Lisere%d+$") and hex(child.Color) == ARENA_TRIM and child.Material == Enum.Material.Neon
        and math.abs(topOf(child) - arenaTop) < 0.1 then
        trims += 1
    elseif child.Name:match("^Place%d+$") and not child.CanCollide and math.abs(topOf(child) - arenaTop) < 0.1 then
        places += 1
    end
end
check(("Z3 : liseré rouge de %d segments et %d places de spectateurs a fleur du plateau"):format(trims, places),
    trims == 8 and places == 8)

-- Z4 : l'entrée du Colisée.
local gate = map.ColiseeGate
local arch = gate:FindFirstChild("PROP_arche_colisee")
local stairs = zone("Colisee"):FindFirstChild("Escalier")
local archOk, rises, steepest = false, 0, 0
if arch and stairs then
    local toHub = flat(-arch:GetPivot().Position).Unit
    local slabs = {}
    for _, p in ipairs(stairs:GetChildren()) do
        if p:IsA("BasePart") then table.insert(slabs, p) end
    end
    table.sort(slabs, function(a, b) return a.Position:Dot(toHub) > b.Position:Dot(toHub) end)
    local heights = {hubTop}
    for _, p in ipairs(slabs) do table.insert(heights, topOf(p)) end
    table.insert(heights, hubTop)
    for index = 2, #heights do
        local delta = math.abs(heights[index] - heights[index - 1])
        if delta > 0.01 then rises += 1 end
        steepest = math.max(steepest, delta)
    end
    local landing = stairs:FindFirstChild("Palier")
    local sign = arch:FindFirstChild("Sign")
    archOk = #gate:GetChildren() == 1 and landing ~= nil
        and math.abs(arch:GetPivot().Position.Y - topOf(landing)) < EPSILON
        and sign ~= nil and sign.CFrame.LookVector:Dot(toHub) > 0.99
end
check("Z4 : l'arche du kit remplace les 3 pieces dorees, sur le palier, panneau tourne vers le hub", archOk)
check(("Z4 : escalier de %d contremarches (%d mesurees), %.2f au plus, praticable dans les deux sens")
    :format(STEP_COUNT, rises, steepest), rises == STEP_COUNT and steepest <= STEP_RISE_MAX + 0.001)

-- Z5 : le musée.
local case = map.Musee.DisplayCase
local socles, enclosed = 0, 0
for _, p in ipairs(zone("Musee"):GetChildren()) do
    if p:IsA("BasePart") and p.Name:match("^Socle%d+$") then
        socles += 1
        local ok = hex(p.Color) == SOCLE
        for _, corner in ipairs(corners(p)) do
            local l = case.CFrame:PointToObjectSpace(corner)
            if math.abs(l.X) > case.Size.X / 2 + 0.01 or math.abs(l.Y) > case.Size.Y / 2 + 0.01
                or math.abs(l.Z) > case.Size.Z / 2 + 0.01 then
                ok = false
            end
        end
        if ok then enclosed += 1 end
    end
end
check(("Z5 : %d socles noirs dans la vitrine (%d conformes)"):format(socles, enclosed), socles == 6 and enclosed == 6)

-- Z8 : les portails des mondes.
local north = map.Liaisons.HubToPlot1
local northOut = flat(north.Position).Unit
local towardRoad = Vector3.new(-northOut.Z, 0, northOut.X)
local portals, facing = 0, 0
for world, spec in pairs(PORTALS) do
    local portal = zone("Portails"):FindFirstChild("PROP_portail_monde" .. world)
    if portal and portal:GetAttribute("WorldId") == world and hex(portal.Vortex.Color) == spec[1]
        and portal.Sign.Paint.TextLabel.Text == ("REBIRTH %d REQUIS"):format(spec[2]) then
        portals += 1
        if portal:GetPivot().LookVector:Dot(towardRoad) > 0.99 then facing += 1 end
    end
end
check(("Z8 : portails M2, M3, M4 aux couleurs de D1.3, panneaux Rebirth 3 / 5 / 10 (%d/3)"):format(portals), portals == 3)
check(("Z8 : portails tournes vers la liaison nord (%d/3)"):format(facing), facing == 3)
local plaza = zone("Portails"):FindFirstChild("Parvis")
local ways = OverlapParams.new()
ways.FilterType = Enum.RaycastFilterType.Include
ways.FilterDescendantsInstances = {map.Liaisons, map.Plots}
check("Z8 : le parvis longe la liaison nord sans la chevaucher", plaza ~= nil
    and #Workspace:GetPartBoundsInBox(plaza.CFrame, plaza.Size - Vector3.new(0.04, 0.04, 0.04), ways) == 0)

-- Skyline.
local buildings, far, turned, nearest = 0, 0, 0, math.huge
for _, building in ipairs(zone("Skyline"):GetChildren()) do
    if building:IsA("Model") and (building:GetAttribute("PropId") or ""):match("^batiment%d$") then
        buildings += 1
        local pivot = building:GetPivot()
        local radius = flat(pivot.Position).Magnitude
        nearest = math.min(nearest, radius)
        if radius >= SKYLINE_MIN_RADIUS then far += 1 end
        if pivot.LookVector:Dot(-flat(pivot.Position).Unit) > 0.99 then turned += 1 end
    end
end
check(("Skyline : %d facades, la plus proche a r=%.0f, %d tournees vers le hub"):format(buildings, nearest, turned),
    buildings == SKYLINE_COUNT and far == SKYLINE_COUNT and turned == SKYLINE_COUNT)

-- Règles de la map, sur tout ce que l'habillage a posé.
local placed = partsOf(decor)
local swapped = table.clone(lamps)
for _, ruelle in ipairs(map.Ruelles:GetChildren()) do
    for _, prop in ipairs(propsIn(ruelle)) do table.insert(swapped, prop) end
end
if arch then table.insert(swapped, arch) end
for _, model in ipairs(swapped) do
    for _, p in ipairs(partsOf(model)) do table.insert(placed, p) end
end
local loose = 0
for _, p in ipairs(placed) do
    if not p.Anchored then loose += 1 end
end
check(("Tout le decor est ancre (%d pieces, %d libres)"):format(#placed, loose), loose == 0)
local plots = OverlapParams.new()
plots.FilterType = Enum.RaycastFilterType.Include
plots.FilterDescendantsInstances = {map.Plots}
local biting = {}
for _, p in ipairs(placed) do
    -- Géométrie exacte : la boîte englobante d'un coin de comblement couvre le plot qu'il longe.
    if #Workspace:GetPartsInPart(p, plots) > 0 then table.insert(biting, p:GetFullName()) end
end
check(("Aucun element de decor ne mord sur un plot (%d)%s"):format(#biting,
    #biting > 0 and (" ; " .. table.concat(biting, ", ", 1, math.min(#biting, 5))) or ""), #biting == 0)
local duplicates, badNames = 0, 0
for _, root in ipairs({decor, hub, map.Ruelles, gate}) do
    local nodes = root:GetDescendants()
    table.insert(nodes, root)
    for _, node in ipairs(nodes) do
        local names = {}
        for _, child in ipairs(node:GetChildren()) do
            if names[child.Name] then duplicates += 1 end
            names[child.Name] = true
        end
        if not node.Name:match("^[%w_]+$") then badNames += 1 end
    end
end
check(("Regles de TestWhiteMap tenues : %d freres homonymes, %d noms hors ASCII"):format(duplicates, badNames),
    duplicates == 0 and badNames == 0)
local fullPlots = 0
for _, plot in ipairs(map.Plots:GetChildren()) do
    local pedestals = 0
    for _, child in ipairs(plot:FindFirstChild("Pedestals") and plot.Pedestals:GetChildren() or {}) do
        if child:IsA("BasePart") and child.Name:match("^Pedestal%d+$") then pedestals += 1 end
    end
    if pedestals == PEDESTALS_PER_PLOT then fullPlots += 1 end
end
check(("Map blanche intacte : 12 plots a 25 socles (%d), 24 liaisons, boutique a 6 enfants, spawn en (0,3,20)")
    :format(fullPlots), #map.Plots:GetChildren() == 12 and fullPlots == 12 and #map.Liaisons:GetChildren() == 24
    and #shop:GetChildren() == 6 and Workspace.SpawnLocation.Position == Vector3.new(0, 3, 20))

return finish()
