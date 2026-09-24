--!nonstrict
--[[ BuildDecoProps
     Rôle    : construire en Édition les 12 décos de base (A5), en primitives, dans ServerStorage.PropModels.
     Doc     : GAME_MASTER_V2 A5 (Décos : 12 objets), D1.5 (palette) ; PROMPT_EXECUTION_SABL_V4 §21.1, §22.1
     Étape   : 9, lot B
     Dépend  : mode Édition ; ServerStorage ; ids et ordre de Config.UpgradeConfig (recopiés, l'outil ne
               peut pas require)
     Exposé  : PROP_deco_<id> : racine au sol, face à −Z, attribut PropId, tout ancré, noms de pièces uniques ;
               idempotent ; bilan dimensions
     Limite  : voie B (décision 21) : aucun maillage importé. Les 12 objets et leurs couleurs sont déclarés :
               A5 ne les décrit pas. Base.DecorVisual les pose sur le plot, tournés vers son centre.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local ServerStorage = game:GetService("ServerStorage")

local FOLDER = "PropModels"
local ROOT_SIZE = Vector3.new(0.2, 0.02, 0.2) -- racine plate : pivot au sol (B0)

-- D1.5 : la palette du monde 1.
local KETCHUP = Color3.fromHex("E63946")
local MUSTARD = Color3.fromHex("FFB703")
local SALAD = Color3.fromHex("8AC926")
local MARKING = Color3.fromHex("FFD23F")
local PINK = Color3.fromHex("FFD6E8")
local CYAN = Color3.fromHex("00B4D8")
local VIOLET = Color3.fromHex("3A0CA3")
local MARBLE = Color3.fromHex("E9ECEF")
-- Déclarées, le doc ne les donne pas.
local TERRACOTTA = Color3.fromHex("C65D3B")
local SOIL = Color3.fromHex("4A3728")
local WOOD = Color3.fromHex("8B5A2B")
local SKIN = Color3.fromHex("F1C27D")
local BLUE = Color3.fromHex("3A86FF")
local INK = Color3.fromHex("2B2D42")
local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromHex("6C757D")

local function part(parent, name, size, cframe, color, material, shape)
    local p = Instance.new("Part")
    p.Name = name
    if shape then p.Shape = shape end
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

-- Cylindre dressé : l'axe du cylindre Roblox est X, on le couche sur Y.
local function column(parent, name, height, diameter, base, color, material)
    return part(parent, name, Vector3.new(height, diameter, diameter),
        CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        color, material, Enum.PartType.Cylinder)
end

local function ball(parent, name, diameter, center, color, material)
    return part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color, material,
        Enum.PartType.Ball)
end

local function paint(host, face, text, color)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "Paint" .. face.Name
    gui.Face = face
    gui.LightInfluence = 0
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.2
    label.Parent = gui
    gui.Parent = host
end

-- Ordre et ids de UpgradeConfig.Decor.Items.
local BUILDERS = {}

BUILDERS[#BUILDERS + 1] = {"pot_fleurs", function(model)
    column(model, "Pot", 1.2, 1.6, Vector3.zero, TERRACOTTA)
    column(model, "Terre", 0.1, 1.4, Vector3.new(0, 1.15, 0), SOIL)
    ball(model, "Buisson", 1.6, Vector3.new(0, 1.9, 0), SALAD)
    for index, spec in ipairs({{KETCHUP, -0.45, 0.2}, {MUSTARD, 0.4, -0.3}, {PINK, 0.05, 0.5}}) do
        ball(model, "Fleur" .. index, 0.5, Vector3.new(spec[2], 2.55, spec[3]), spec[1])
    end
end}

BUILDERS[#BUILDERS + 1] = {"parasol", function(model)
    column(model, "Socle", 0.3, 1.4, Vector3.zero, GREY)
    column(model, "Mat", 5, 0.25, Vector3.zero, WHITE)
    column(model, "Toile", 0.25, 5, Vector3.new(0, 4.9, 0), KETCHUP)
    column(model, "Bande", 0.3, 3, Vector3.new(0, 4.9, 0), WHITE)
    ball(model, "Pommeau", 0.4, Vector3.new(0, 5.35, 0), MUSTARD)
end}

BUILDERS[#BUILDERS + 1] = {"nain", function(model)
    part(model, "Bottes", Vector3.new(1.2, 0.4, 0.8), CFrame.new(0, 0.2, 0), WOOD)
    column(model, "Corps", 1.2, 1.2, Vector3.new(0, 0.4, 0), BLUE)
    column(model, "Ceinture", 0.15, 1.25, Vector3.new(0, 0.9, 0), INK)
    ball(model, "Tete", 0.9, Vector3.new(0, 2.0, 0), SKIN)
    ball(model, "Barbe", 0.8, Vector3.new(0, 1.75, -0.3), WHITE)
    for index, spec in ipairs({{0.9, 2.35}, {0.6, 2.75}, {0.3, 3.15}}) do
        column(model, "Bonnet" .. index, 0.4, spec[1], Vector3.new(0, spec[2], 0), KETCHUP)
    end
end}

BUILDERS[#BUILDERS + 1] = {"borne_incendie", function(model)
    column(model, "Socle", 0.3, 1.4, Vector3.zero, KETCHUP)
    column(model, "Fut", 1.6, 1, Vector3.new(0, 0.3, 0), KETCHUP)
    column(model, "Chapeau", 0.3, 1.2, Vector3.new(0, 1.9, 0), KETCHUP)
    ball(model, "Dome", 0.6, Vector3.new(0, 2.3, 0), MUSTARD)
    for index, side in ipairs({-1, 1}) do
        part(model, "Sortie" .. index, Vector3.new(0.5, 0.4, 0.4), CFrame.new(side * 0.7, 1.3, 0), MUSTARD,
            Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
    end
end}

BUILDERS[#BUILDERS + 1] = {"distributeur", function(model)
    part(model, "Caisse", Vector3.new(2.4, 4, 1.6), CFrame.new(0, 2, 0), KETCHUP)
    local front = part(model, "Vitrine", Vector3.new(1.8, 2.4, 0.1), CFrame.new(0, 2.6, -0.85), CYAN,
        Enum.Material.Neon)
    front.Transparency = 0.3
    paint(front, Enum.NormalId.Front, "SODA", WHITE)
    part(model, "Fente", Vector3.new(1, 0.4, 0.1), CFrame.new(0, 0.9, -0.85), INK)
end}

BUILDERS[#BUILDERS + 1] = {"palmier", function(model)
    local y = 0
    for index = 1, 4 do
        column(model, "Tronc" .. index, 1.5, 0.7 - index * 0.05, Vector3.new(index * 0.12, y, 0), WOOD)
        y += 1.5
    end
    local top = Vector3.new(0.5, y, 0)
    for index = 1, 6 do
        local angle = math.rad((index - 1) * 60)
        part(model, "Palme" .. index, Vector3.new(0.8, 0.1, 3.5),
            CFrame.new(top) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 0, -1.6),
            SALAD)
    end
    for index, offset in ipairs({Vector3.new(0.3, -0.3, 0.2), Vector3.new(-0.2, -0.3, -0.3)}) do
        ball(model, "Noix" .. index, 0.5, top + offset, WOOD)
    end
end}

BUILDERS[#BUILDERS + 1] = {"jukebox", function(model)
    part(model, "Caisse", Vector3.new(2, 3, 1.2), CFrame.new(0, 1.5, 0), Color3.fromHex("7B2CBF"))
    part(model, "Arrondi", Vector3.new(1.2, 2, 2), CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0),
        Color3.fromHex("7B2CBF"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
    for index, color in ipairs({KETCHUP, MUSTARD, SALAD}) do
        part(model, "Neon" .. index, Vector3.new(1.6, 0.15, 0.1), CFrame.new(0, 1.6 + index * 0.35, -0.62), color,
            Enum.Material.Neon)
    end
    part(model, "Grille", Vector3.new(1.4, 0.9, 0.1), CFrame.new(0, 0.8, -0.62), INK)
end}

BUILDERS[#BUILDERS + 1] = {"fontaine", function(model)
    column(model, "Bassin", 0.8, 5, Vector3.zero, MARBLE, Enum.Material.Marble)
    local water = column(model, "Eau", 0.1, 4.4, Vector3.new(0, 0.72, 0), CYAN, Enum.Material.Glass)
    water.Transparency = 0.3
    column(model, "Colonne", 1.6, 0.6, Vector3.new(0, 0.8, 0), MARBLE, Enum.Material.Marble)
    column(model, "Vasque", 0.3, 1.6, Vector3.new(0, 2.4, 0), MARBLE, Enum.Material.Marble)
    local jet = ball(model, "Jet", 0.8, Vector3.new(0, 3, 0), CYAN, Enum.Material.Glass)
    jet.Transparency = 0.4
end}

BUILDERS[#BUILDERS + 1] = {"statue", function(model)
    part(model, "Piedestal", Vector3.new(1.8, 1.2, 1.8), CFrame.new(0, 0.6, 0), MARBLE, Enum.Material.Marble)
    column(model, "Corps", 1.6, 1, Vector3.new(0, 1.2, 0), MARKING, Enum.Material.Foil)
    ball(model, "Tete", 0.9, Vector3.new(0, 3.2, 0), MARKING, Enum.Material.Foil)
    for index, side in ipairs({-1, 1}) do
        part(model, "Bras" .. index, Vector3.new(0.3, 1.2, 0.3),
            CFrame.new(side * 0.6, 2.9, 0) * CFrame.Angles(0, 0, math.rad(side * -25)), MARKING, Enum.Material.Foil)
    end
end}

BUILDERS[#BUILDERS + 1] = {"enseigne", function(model)
    for index, x in ipairs({-1.8, 1.8}) do
        column(model, "Poteau" .. index, 4, 0.25, Vector3.new(x, 0, 0), INK)
    end
    local board = part(model, "Panneau", Vector3.new(4, 1.5, 0.2), CFrame.new(0, 3.5, 0), INK)
    paint(board, Enum.NormalId.Front, "BRAINROT", MUSTARD)
    paint(board, Enum.NormalId.Back, "BRAINROT", KETCHUP)
end}

BUILDERS[#BUILDERS + 1] = {"arche_ballons", function(model)
    local colors = {KETCHUP, MUSTARD, SALAD, PINK, CYAN}
    for index = 1, 9 do
        local angle = math.rad(180 - (index - 1) * 22.5)
        ball(model, "Ballon" .. index, 0.9, Vector3.new(math.cos(angle) * 2.2, 0.5 + math.sin(angle) * 2.2, 0),
            colors[(index - 1) % #colors + 1])
    end
    for index, x in ipairs({-2.2, 2.2}) do
        part(model, "Lest" .. index, Vector3.new(0.6, 0.3, 0.6), CFrame.new(x, 0.15, 0), GREY)
    end
end}

BUILDERS[#BUILDERS + 1] = {"trone", function(model)
    for index, spec in ipairs({{-1, -0.8}, {1, -0.8}, {-1, 0.8}, {1, 0.8}}) do
        part(model, "Pied" .. index, Vector3.new(0.3, 0.6, 0.3), CFrame.new(spec[1], 0.3, spec[2]), MARKING,
            Enum.Material.Foil)
    end
    part(model, "Assise", Vector3.new(2.4, 0.8, 2), CFrame.new(0, 1, 0), VIOLET)
    part(model, "Dossier", Vector3.new(2.4, 3, 0.4), CFrame.new(0, 2.9, 0.8), VIOLET)
    for index, x in ipairs({-1.3, 1.3}) do
        part(model, "Accoudoir" .. index, Vector3.new(0.3, 0.8, 2), CFrame.new(x, 1.7, 0), MARKING, Enum.Material.Foil)
    end
    ball(model, "Couronne", 0.7, Vector3.new(0, 4.7, 0.8), MARKING, Enum.Material.Foil)
end}

local folder = ServerStorage:FindFirstChild(FOLDER)
assert(folder and folder:IsA("Folder"), "ServerStorage.PropModels absent : lancer BuildMapProps")
local lines = {}
for _, entry in ipairs(BUILDERS) do
    local id, build = entry[1], entry[2]
    local name = "PROP_deco_" .. id
    local previous = folder:FindFirstChild(name)
    if previous then previous:Destroy() end
    local model = Instance.new("Model")
    model.Name = name
    local root = part(model, "Root", ROOT_SIZE, CFrame.new(0, 0, 0), GREY)
    root.Transparency = 1
    root.CanCollide = false
    root.CanQuery = false
    root.CanTouch = false
    model.PrimaryPart = root
    model:SetAttribute("PropId", "deco_" .. id)
    build(model)
    model.Parent = folder
    local size = model:GetExtentsSize()
    local names, duplicates, parts = {}, 0, 0
    for _, child in ipairs(model:GetChildren()) do
        if names[child.Name] then duplicates += 1 end
        names[child.Name] = true
        if child:IsA("BasePart") then parts += 1 end
    end
    table.insert(lines, ("[DECO] %-26s %4.1f x %4.1f x %4.1f studs, %2d pieces, %d homonyme(s)")
        :format(name, size.X, size.Y, size.Z, parts, duplicates))
end
table.insert(lines, ("[BILAN] %d decos construites dans ServerStorage.%s"):format(#BUILDERS, FOLDER))
print(table.concat(lines, "\n"))
return table.concat(lines, "\n")
