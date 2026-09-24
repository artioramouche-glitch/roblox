--!nonstrict
--[[ BuildCreatureModels
     Rôle    : construire en Édition les modèles du batch A : 5 communs de M1 et l'œuf de base.
     Doc     : GAME_MASTER_V2 B0, B5 §COMMUNS, B2, G5.8 ; PROMPT_EXECUTION_SABL_V4 §21.1, §21.3, §21.4
     Étape   : 6, lot A
     Dépend  : mode Édition ; ServerStorage
     Exposé  : ServerStorage.CreatureModels (CRT_noobini, CRT_tim_cheese, CRT_fluriflura, CRT_pipi_kiwi,
               CRT_talpa) et ServerStorage.PropModels (PROP_egg_basic) ; idempotent, chaque modèle est
               reconstruit à neuf ; bilan hauteur mesurée contre fiche et nombre de pièces
     Limite  : voie B (§4.4) : primitives assemblées, aucun FBX ni import manuel. Aucune animation dans
               le modèle (B0) : les idles G5.8 sont posés au lot B. Les teintes non données par les fiches
               sont choisies et déclarées. Matériau SmoothPlastic, le plus proche du « flat » de B0.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local ServerStorage = game:GetService("ServerStorage")

local WHITE = Color3.fromHex("FFFFFF")
local BLACK = Color3.fromHex("1A1A1A")
local STEEL = Color3.fromHex("9AA0A6")
local EYE_RATIO = 0.2 -- B0 : les yeux font 20 % de la tête
local LIMB_RADIUS = 0.08 -- B0 : membres cylindriques r=0.08
local LIMB_LENGTH = 0.5 -- B0 : longueur 0.5, sauf mention contraire des fiches

local function ensureFolder(name)
    local folder = ServerStorage:FindFirstChild(name)
    if folder and not folder:IsA("Folder") then folder:Destroy() folder = nil end
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = ServerStorage
    end
    return folder
end

local function piece(parent, name, shape, size, cframe, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Shape = shape
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function block(parent, name, size, cframe, color)
    return piece(parent, name, Enum.PartType.Block, size, cframe, color)
end

local function ball(parent, name, size, cframe, color)
    return piece(parent, name, Enum.PartType.Ball, size, cframe, color)
end

-- Le cylindre Roblox a son axe sur X : ces deux fonctions le dressent ou le couchent.
local function upright(parent, name, length, diameter, cframe, color)
    return piece(parent, name, Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter),
        cframe * CFrame.Angles(0, 0, math.rad(90)), color)
end

local function disc(parent, name, thickness, diameter, cframe, color)
    return piece(parent, name, Enum.PartType.Cylinder, Vector3.new(thickness, diameter, diameter),
        cframe * CFrame.Angles(0, math.rad(90), 0), color)
end

local function wedge(parent, name, size, cframe, color)
    local part = Instance.new("WedgePart")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Parent = parent
    return part
end

local function limb(parent, name, position, color, length)
    return upright(parent, name, length or LIMB_LENGTH, LIMB_RADIUS * 2, CFrame.new(position), color)
end

-- B0 : deux sphères blanches et des pupilles noires décalées, taille 20 % de la tête.
local function eyes(parent, headCenter, headWidth, headDepth)
    local size = headWidth * EYE_RATIO
    for _, side in ipairs({{-1, "L"}, {1, "R"}}) do
        local offset = CFrame.new(side[1] * headWidth * 0.24, headWidth * 0.06, -headDepth * 0.48)
        local eye = ball(parent, "Eye" .. side[2], Vector3.new(size, size, size), headCenter * offset, WHITE)
        ball(parent, "Pupil" .. side[2], Vector3.new(size * 0.55, size * 0.55, size * 0.55),
            eye.CFrame * CFrame.new(0, 0, -size * 0.3), BLACK)
    end
end

local function smile(parent, center, width)
    block(parent, "Smile", Vector3.new(width, 0.06, 0.06), center, BLACK)
end

-- CRT_noobini — Noobini Pizzanini, 2.5 studs (B5) : noob bleu et vert, chapeau et part de pizza.
local function buildNoobini(model)
    local blue, green, yellow = Color3.fromHex("1B6FD0"), Color3.fromHex("7CB518"), Color3.fromHex("FFD23F")
    local crust, sauce = Color3.fromHex("F4D58D"), Color3.fromHex("E63946")
    for _, side in ipairs({{-1, "L"}, {1, "R"}}) do
        block(model, "Leg" .. side[2], Vector3.new(0.34, 0.9, 0.34),
            CFrame.new(side[1] * 0.24, 0.45, 0), green)
        block(model, "Arm" .. side[2], Vector3.new(0.3, 0.8, 0.3),
            CFrame.new(side[1] * 0.63, 1.3, 0), yellow)
    end
    block(model, "Torso", Vector3.new(0.95, 0.85, 0.5), CFrame.new(0, 1.325, 0), blue)
    local head = block(model, "Head", Vector3.new(0.8, 0.75, 0.8), CFrame.new(0, 1.95, 0), yellow)
    eyes(model, head.CFrame, 0.8, 0.8)
    smile(model, head.CFrame * CFrame.new(0, -0.18, -0.4), 0.34)
    -- Le chapeau est un disque horizontal : axe vertical, donc upright et non disc.
    upright(model, "HatBase", 0.1, 1.0, CFrame.new(0, 2.33, 0), crust)
    wedge(model, "HatSlice", Vector3.new(0.06, 0.14, 0.46), CFrame.new(0, 2.43, 0.1), sauce)
    wedge(model, "PizzaSlice", Vector3.new(0.08, 0.4, 0.5),
        CFrame.new(0.72, 0.95, -0.15) * CFrame.Angles(0, math.rad(90), 0), sauce)
end

-- CRT_tim_cheese — Tim Cheese, 2.2 studs (B5) : fromage triangulaire, calotte de chef, lunettes.
local function buildTimCheese(model)
    local cheese, hole = Color3.fromHex("FFD23F"), Color3.fromHex("E0A800")
    for _, side in ipairs({{-1, "L"}, {1, "R"}}) do
        limb(model, "Leg" .. side[2], Vector3.new(side[1] * 0.2, 0.25, 0), hole)
        limb(model, "Arm" .. side[2], Vector3.new(side[1] * 0.62, 1.0, 0), hole, 0.6)
    end
    wedge(model, "Body", Vector3.new(0.9, 1.1, 1.1), CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(180), 0), cheese)
    for index, spot in ipairs({Vector3.new(-0.2, 0.85, -0.42), Vector3.new(0.24, 0.6, -0.5), Vector3.new(0.05, 1.15, -0.3)}) do
        ball(model, "Hole" .. index, Vector3.new(0.22, 0.22, 0.22), CFrame.new(spot), hole)
    end
    local face = CFrame.new(0, 1.05, -0.28)
    eyes(model, face, 0.8, 0.5)
    smile(model, face * CFrame.new(0, -0.22, -0.1), 0.45)
    for _, side in ipairs({{-1, "L"}, {1, "R"}}) do
        disc(model, "Glass" .. side[2], 0.04, 0.26, face * CFrame.new(side[1] * 0.19, 0.05, -0.16), BLACK)
    end
    upright(model, "HatBrim", 0.12, 0.8, CFrame.new(0, 1.62, 0), WHITE)
    ball(model, "HatTop", Vector3.new(0.6, 0.55, 0.6), CFrame.new(0, 1.93, 0), WHITE)
end

-- CRT_fluriflura — FluriFlura, 2.5 studs (B5) : fleur fuchsia à 6 pétales, cœur jaune, tiges vertes.
local function buildFluriflura(model)
    local petal, core, stem = Color3.fromHex("FF70A6"), Color3.fromHex("FFD23F"), Color3.fromHex("8AC926")
    for _, side in ipairs({{-1, "L"}, {1, "R"}}) do
        limb(model, "Stem" .. side[2], Vector3.new(side[1] * 0.16, 0.6, 0), stem, 1.2)
        wedge(model, "Leaf" .. side[2], Vector3.new(0.08, 0.22, 0.4),
            CFrame.new(side[1] * 0.5, 1.45, 0) * CFrame.Angles(0, math.rad(side[1] * 90), 0), stem)
    end
    for index = 1, 6 do
        local angle = math.rad((index - 1) * 60)
        ball(model, "Petal" .. index, Vector3.new(0.52, 0.16, 0.36),
            CFrame.new(math.sin(angle) * 0.46, 1.95 + math.cos(angle) * 0.46, 0) * CFrame.Angles(0, 0, -angle),
            petal)
    end
    local heart = ball(model, "Core", Vector3.new(0.62, 0.62, 0.5), CFrame.new(0, 1.95, -0.04), core)
    eyes(model, heart.CFrame, 0.62, 0.5)
    smile(model, heart.CFrame * CFrame.new(0, -0.16, -0.24), 0.26)
end

-- CRT_pipi_kiwi — Pipi Kiwi, 2 studs (B5) : kiwi coupé, chair verte à graines, dos brun duveteux.
local function buildPipiKiwi(model)
    local flesh, fuzz, seed = Color3.fromHex("7BA428"), Color3.fromHex("8B6F47"), BLACK
    -- Pattes assez longues pour porter le corps : la fiche donne 2 studs au total.
    for _, side in ipairs({{-1, "L"}, {1, "R"}}) do
        limb(model, "Leg" .. side[2], Vector3.new(side[1] * 0.18, 0.45, 0), flesh, 0.9)
    end
    ball(model, "Back", Vector3.new(1.2, 1.15, 1.05), CFrame.new(0, 1.43, 0), fuzz)
    local face = disc(model, "Flesh", 0.12, 1.02, CFrame.new(0, 1.43, -0.48), flesh)
    ball(model, "Heart", Vector3.new(0.3, 0.3, 0.12), CFrame.new(0, 1.43, -0.56), Color3.fromHex("D8E870"))
    for index = 1, 8 do
        local angle = math.rad((index - 1) * 45)
        ball(model, "Seed" .. index, Vector3.new(0.09, 0.09, 0.05),
            CFrame.new(math.sin(angle) * 0.26, 1.43 + math.cos(angle) * 0.26, -0.57), seed)
    end
    eyes(model, face.CFrame * CFrame.Angles(0, math.rad(-90), 0) * CFrame.new(0, 0.18, 0), 0.9, 0.24)
end

-- CRT_talpa — Talpa Di Fero, 2.3 studs (B5) : taupe trapue, casque, lunettes au front, pioche.
local function buildTalpa(model)
    local fur, helmet, snout = Color3.fromHex("6B4F35"), Color3.fromHex("FFD23F"), Color3.fromHex("E8A0A0")
    for _, side in ipairs({{-1, "L"}, {1, "R"}}) do
        limb(model, "Leg" .. side[2], Vector3.new(side[1] * 0.24, 0.22, 0), fur, 0.45)
        limb(model, "Arm" .. side[2], Vector3.new(side[1] * 0.56, 0.95, 0), fur, 0.5)
    end
    ball(model, "Body", Vector3.new(1.1, 1.0, 0.95), CFrame.new(0, 0.95, 0), fur)
    local head = ball(model, "Head", Vector3.new(0.78, 0.72, 0.72), CFrame.new(0, 1.62, -0.05), fur)
    ball(model, "Snout", Vector3.new(0.3, 0.26, 0.3), head.CFrame * CFrame.new(0, -0.1, -0.34), snout)
    eyes(model, head.CFrame, 0.78, 0.72)
    disc(model, "Goggles", 0.06, 0.74, CFrame.new(0, 1.84, -0.28), Color3.fromHex("4A4A4A"))
    upright(model, "HelmetBrim", 0.08, 1.0, CFrame.new(0, 1.94, -0.02), helmet)
    ball(model, "HelmetDome", Vector3.new(0.88, 0.6, 0.88), CFrame.new(0, 2.0, -0.02), helmet)
    upright(model, "PickHandle", 0.95, 0.12,
        CFrame.new(0.62, 1.35, 0.12) * CFrame.Angles(math.rad(18), 0, math.rad(-14)), Color3.fromHex("8B6F47"))
    block(model, "PickHead", Vector3.new(0.52, 0.16, 0.14), CFrame.new(0.78, 1.82, 0.06), STEEL)
end

-- PROP_egg_basic — œuf de base (B2) : aucune fiche 3D dans le doc, forme dérivée de B0.
local function buildEggBasic(model)
    local shell, spot = Color3.fromHex("F4D58D"), Color3.fromHex("8B6F47")
    ball(model, "Shell", Vector3.new(1.05, 1.4, 1.05), CFrame.new(0, 0.7, 0), shell)
    for index, place in ipairs({Vector3.new(-0.3, 0.9, -0.35), Vector3.new(0.34, 0.6, -0.3),
        Vector3.new(0.1, 1.1, 0.3), Vector3.new(-0.25, 0.45, 0.32)}) do
        ball(model, "Spot" .. index, Vector3.new(0.26, 0.2, 0.26), CFrame.new(place), spot)
    end
end

local SPECS = {
    {id = "noobini", height = 2.5, build = buildNoobini},
    {id = "tim_cheese", height = 2.2, build = buildTimCheese},
    {id = "fluriflura", height = 2.5, build = buildFluriflura},
    {id = "pipi_kiwi", height = 2.0, build = buildPipiKiwi},
    {id = "talpa", height = 2.3, build = buildTalpa},
}

local function assemble(folder, name, id, attribute, builder)
    local previous = folder:FindFirstChild(name)
    if previous then previous:Destroy() end
    local model = Instance.new("Model")
    model.Name = name
    -- Racine invisible dans le plan du sol : le pivot d'un modèle suit son PrimaryPart,
    -- donc elle est plate et centrée sur l'origine, comme l'exige B0 (centre des pieds).
    local root = block(model, "Root", Vector3.new(0.2, 0.02, 0.2), CFrame.new(0, 0, 0), WHITE)
    root.Transparency = 1
    builder(model)
    -- B0 : le pivot est au sol et rien ne passe dessous ; l'ensemble est relevé si une pièce dépasse.
    local lowest = math.huge
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part ~= root then
            lowest = math.min(lowest, part.Position.Y - part.Size.Y / 2)
        end
    end
    if lowest < 0 then
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and part ~= root then
                part.CFrame = part.CFrame + Vector3.new(0, -lowest, 0)
            end
        end
    end
    model.PrimaryPart = root
    model:SetAttribute(attribute, id)
    model.Parent = folder
    return model
end

local creatures = ensureFolder("CreatureModels")
local props = ensureFolder("PropModels")
local lines = {}

for _, spec in ipairs(SPECS) do
    local model = assemble(creatures, "CRT_" .. spec.id, spec.id, "CreatureId", spec.build)
    local size = model:GetExtentsSize()
    local pivot = model:GetPivot().Position
    table.insert(lines, ("[3D] %-18s %2d pieces, hauteur %.2f (fiche %.1f), largeur %.2f, pivot y=%.2f")
        :format(model.Name, #model:GetChildren(), size.Y, spec.height, size.X, pivot.Y))
end

local egg = assemble(props, "PROP_egg_basic", "egg_basic", "PropId", buildEggBasic)
table.insert(lines, ("[3D] %-18s %2d pieces, hauteur %.2f, pivot y=%.2f")
    :format(egg.Name, #egg:GetChildren(), egg:GetExtentsSize().Y, egg:GetPivot().Position.Y))

local output = table.concat(lines, "\n")
print(output)
