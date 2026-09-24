--!nonstrict
--[[ BuildMapProps
     Rôle    : construire en Édition le kit de props du monde 1, en primitives, dans ServerStorage.PropModels.
     Doc     : GAME_MASTER_V2 D1.3 (zones), D1.4 (kit de props), D1.5 (palette), B0 ;
               PROMPT_EXECUTION_SABL_V4 §21.1, §22.1
     Étape   : 8, lot A
     Dépend  : mode Édition ; ServerStorage
     Exposé  : PROP_lampadaire, PROP_ramp, PROP_trampoline, PROP_graffiti, PROP_banc, PROP_boss_totem,
               PROP_arche_colisee, PROP_portail_monde, PROP_batiment1..6 : racine au sol, attribut PropId,
               tout ancré ; idempotent, chaque prop est reconstruit ; bilan dimensions
     Limite  : voie B (décision 21) : primitives, aucun maillage ni texture importés. Les « textures
               brainrot » des graffitis sont remplacées par du texte peint (SurfaceGui). Le trampoline
               porte l'attribut Trampoline : c'est le lot C qui le fera rebondir. Les couleurs sont
               celles de D1.3 et D1.5 ; celles que le doc ne donne pas sont déclarées.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local ServerStorage = game:GetService("ServerStorage")

local FOLDER = "PropModels"
local ROOT_SIZE = Vector3.new(0.2, 0.02, 0.2) -- racine plate : pivot au sol (B0)

-- D1.5 : la palette du monde 1.
local ASPHALT = Color3.fromHex("8A8580")
local MARKING = Color3.fromHex("FFD23F")
local KETCHUP = Color3.fromHex("E63946")
local MUSTARD = Color3.fromHex("FFB703")
local SALAD = Color3.fromHex("8AC926")
local PASTELS = {Color3.fromHex("F4D58D"), Color3.fromHex("CDB4DB"), Color3.fromHex("A8DADC")}
-- D1.3 : couleurs de zone.
local ARENA_GREY = Color3.fromHex("6C757D")
local GOLD = Color3.fromHex("FFD23F")
local MARBLE = Color3.fromHex("E9ECEF")
-- Déclarées, le doc ne les donne pas.
local POLE = Color3.fromHex("3A3A3A")
local BUN = Color3.fromHex("D4A373")
local PATTY = Color3.fromHex("6B4F35")
local WINDOW = Color3.fromHex("2B2D42")

-- D1.4 : dimensions du kit.
local LAMP_POLE_HEIGHT = 8
local RAMP_LENGTH, RAMP_THICKNESS, RAMP_WIDTH, RAMP_ANGLE = 12, 2, 6, 30
local TRAMPOLINE_RADIUS, TRAMPOLINE_THICKNESS, TRAMPOLINE_LEGS = 4, 0.5, 1
local GRAFFITI_WIDTH, GRAFFITI_HEIGHT = 6, 3
local BUILDING_WIDTH, BUILDING_HEIGHT, BUILDING_DEPTH = 20, 30, 6
local COLISEE_WIDTH, COLISEE_HEIGHT = 16, 12 -- D1.3 Z4
local PORTAL_HEIGHT = 12 -- D1.3 Z8

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

local function newModel(name, id)
    local model = Instance.new("Model")
    model.Name = name
    local root = part(model, "Root", ROOT_SIZE, CFrame.new(0, 0, 0), ASPHALT)
    root.Transparency = 1
    root.CanCollide = false
    root.CanQuery = false
    root.CanTouch = false
    model.PrimaryPart = root
    model:SetAttribute("PropId", id)
    return model
end

local function paint(host, face, text, textColor, background)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "Paint"
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = background or Color3.new(0, 0, 0)
    label.BackgroundTransparency = background and 0 or 1
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.Text = text
    label.TextColor3 = textColor
    label.TextStrokeTransparency = 0.2
    label.Parent = gui
    gui.Parent = host
    return gui
end

-- Chaque constructeur rend un Model complet ; la liste fixe l'ordre du bilan.
local BUILDERS = {}

BUILDERS[#BUILDERS + 1] = {"PROP_lampadaire", "lampadaire", function(model)
    column(model, "Pole", LAMP_POLE_HEIGHT, 0.5, Vector3.new(0, 0, 0), POLE)
    column(model, "Base", 0.6, 1.4, Vector3.new(0, 0, 0), POLE)
    local globe = part(model, "Globe", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, LAMP_POLE_HEIGHT + 0.6, 0),
        MUSTARD, Enum.Material.Neon, Enum.PartType.Ball)
    local light = Instance.new("PointLight")
    light.Color = MUSTARD
    light.Brightness = 1.5
    light.Range = 16
    light.Parent = globe
end}

BUILDERS[#BUILDERS + 1] = {"PROP_ramp", "ramp", function(model)
    -- Dalle inclinée à 30°, son arête basse posée au sol : on remonte le centre de ce qu'il faut.
    local angle = math.rad(RAMP_ANGLE)
    local rise = RAMP_LENGTH / 2 * math.sin(angle) + RAMP_THICKNESS / 2 * math.cos(angle)
    local slab = part(model, "Slab", Vector3.new(RAMP_WIDTH, RAMP_THICKNESS, RAMP_LENGTH),
        CFrame.new(0, rise, 0) * CFrame.Angles(angle, 0, 0), ASPHALT)
    part(model, "Stripe", Vector3.new(0.6, 0.05, RAMP_LENGTH * 0.95),
        slab.CFrame * CFrame.new(0, RAMP_THICKNESS / 2 + 0.03, 0), MARKING, Enum.Material.Neon)
end}

BUILDERS[#BUILDERS + 1] = {"PROP_trampoline", "trampoline", function(model)
    for index = 1, 4 do
        local angle = math.rad(45 + (index - 1) * 90)
        column(model, "Leg" .. index, TRAMPOLINE_LEGS, 0.4,
            Vector3.new(math.cos(angle) * TRAMPOLINE_RADIUS * 0.7, 0, math.sin(angle) * TRAMPOLINE_RADIUS * 0.7), POLE)
    end
    local bed = column(model, "Bed", TRAMPOLINE_THICKNESS, TRAMPOLINE_RADIUS * 2, Vector3.new(0, TRAMPOLINE_LEGS, 0),
        KETCHUP, Enum.Material.Neon)
    bed:SetAttribute("Trampoline", true)
    model:SetAttribute("Trampoline", true)
end}

BUILDERS[#BUILDERS + 1] = {"PROP_graffiti", "graffiti", function(model)
    local wall = part(model, "Tag", Vector3.new(GRAFFITI_WIDTH, GRAFFITI_HEIGHT, 0.1),
        CFrame.new(0, GRAFFITI_HEIGHT / 2, 0), ASPHALT)
    wall.CanCollide = false
    paint(wall, Enum.NormalId.Front, "BRAINROT!", MUSTARD, KETCHUP)
    paint(wall, Enum.NormalId.Back, "TUNG TUNG", SALAD, Color3.fromHex("3A0CA3"))
end}

BUILDERS[#BUILDERS + 1] = {"PROP_banc", "banc", function(model)
    -- Banc burger : pain, salade, steak, fromage, pain.
    local y = 0.8
    part(model, "BunBottom", Vector3.new(4, 0.35, 1.4), CFrame.new(0, y, 0), BUN)
    part(model, "Patty", Vector3.new(4.1, 0.25, 1.5), CFrame.new(0, y + 0.3, 0), PATTY)
    part(model, "Cheese", Vector3.new(4.15, 0.08, 1.55), CFrame.new(0, y + 0.46, 0), GOLD)
    part(model, "Salad", Vector3.new(4.2, 0.08, 1.6), CFrame.new(0, y + 0.54, 0), SALAD)
    part(model, "BunTop", Vector3.new(4, 0.4, 1.4), CFrame.new(0, y + 0.78, 0.35) * CFrame.Angles(math.rad(-70), 0, 0), BUN)
    for _, x in ipairs({-1.6, 1.6}) do
        part(model, "Leg", Vector3.new(0.3, y, 1), CFrame.new(x, y / 2, 0), POLE)
    end
end}

BUILDERS[#BUILDERS + 1] = {"PROP_boss_totem", "boss_totem", function(model)
    local y = 0
    for index, color in ipairs({ARENA_GREY, KETCHUP, ARENA_GREY, KETCHUP}) do
        local block = part(model, "Block" .. index, Vector3.new(3, 2.5, 3), CFrame.new(0, y + 1.25, 0), color)
        for _, x in ipairs({-0.7, 0.7}) do
            part(model, "Eye", Vector3.new(0.6, 0.6, 0.2), block.CFrame * CFrame.new(x, 0.3, -1.55), MARBLE, Enum.Material.Neon)
        end
        y += 2.5
    end
    part(model, "Crown", Vector3.new(3.4, 1, 3.4), CFrame.new(0, y + 0.5, 0), GOLD, Enum.Material.Neon)
end}

BUILDERS[#BUILDERS + 1] = {"PROP_arche_colisee", "arche_colisee", function(model)
    local pillar = 3
    for _, x in ipairs({-(COLISEE_WIDTH - pillar) / 2, (COLISEE_WIDTH - pillar) / 2}) do
        part(model, "Plinth", Vector3.new(pillar + 1, 1, pillar + 1), CFrame.new(x, 0.5, 0), MARBLE, Enum.Material.Marble)
        part(model, "Pillar", Vector3.new(pillar, COLISEE_HEIGHT - 3, pillar), CFrame.new(x, 1 + (COLISEE_HEIGHT - 3) / 2, 0),
            GOLD, Enum.Material.Foil)
    end
    part(model, "Lintel", Vector3.new(COLISEE_WIDTH, 2, pillar), CFrame.new(0, COLISEE_HEIGHT - 1, 0), GOLD, Enum.Material.Foil)
    local sign = part(model, "Sign", Vector3.new(8, 1.4, 0.2), CFrame.new(0, COLISEE_HEIGHT - 1, -pillar / 2 - 0.1), MARBLE)
    paint(sign, Enum.NormalId.Front, "COLISÉE — NIVEAU 5+", GOLD)
end}

BUILDERS[#BUILDERS + 1] = {"PROP_portail_monde", "portail_monde", function(model)
    local width = 10
    for _, x in ipairs({-width / 2, width / 2}) do
        part(model, "Pillar", Vector3.new(1.5, PORTAL_HEIGHT, 1.5), CFrame.new(x, PORTAL_HEIGHT / 2, 0), POLE)
    end
    part(model, "Lintel", Vector3.new(width + 1.5, 1.5, 1.5), CFrame.new(0, PORTAL_HEIGHT - 0.75, 0), POLE)
    local vortex = part(model, "Vortex", Vector3.new(width - 1.5, PORTAL_HEIGHT - 2, 0.3),
        CFrame.new(0, (PORTAL_HEIGHT - 2) / 2, 0), Color3.fromHex("3A0CA3"), Enum.Material.Neon)
    vortex.Transparency = 0.35
    vortex.CanCollide = false
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "Vortex"
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Rate = 12
    emitter.Lifetime = NumberRange.new(1, 2)
    emitter.RotSpeed = NumberRange.new(90, 180)
    emitter.Speed = NumberRange.new(0.5, 1)
    emitter.Parent = vortex
    local sign = part(model, "Sign", Vector3.new(6, 1.2, 0.2), CFrame.new(0, PORTAL_HEIGHT + 0.8, 0), MARBLE)
    paint(sign, Enum.NormalId.Front, "REBIRTH REQUIS", KETCHUP)
end}

for index = 1, 6 do
    BUILDERS[#BUILDERS + 1] = {"PROP_batiment" .. index, "batiment" .. index, function(model)
        local color = PASTELS[(index - 1) % #PASTELS + 1]
        part(model, "Facade", Vector3.new(BUILDING_WIDTH, BUILDING_HEIGHT, BUILDING_DEPTH),
            CFrame.new(0, BUILDING_HEIGHT / 2, 0), color)
        part(model, "Roof", Vector3.new(BUILDING_WIDTH + 1, 1, BUILDING_DEPTH + 1),
            CFrame.new(0, BUILDING_HEIGHT + 0.5, 0), color:Lerp(Color3.new(0, 0, 0), 0.25))
        -- Fenêtres : une grille qui change de rythme d'un bâtiment à l'autre.
        local columns = 3 + index % 3
        local rows = 5 + index % 2
        for row = 1, rows do
            for col = 1, columns do
                local x = (col - (columns + 1) / 2) * (BUILDING_WIDTH / (columns + 1))
                local y = row * (BUILDING_HEIGHT / (rows + 1))
                part(model, "Window", Vector3.new(2.2, 2.6, 0.2),
                    CFrame.new(x, y, -BUILDING_DEPTH / 2 - 0.1), WINDOW, Enum.Material.Glass)
            end
        end
    end}
end

local folder = ensureFolder(FOLDER)
local lines = {}
for _, entry in ipairs(BUILDERS) do
    local name, id, build = entry[1], entry[2], entry[3]
    local previous = folder:FindFirstChild(name)
    if previous then previous:Destroy() end
    local model = newModel(name, id)
    build(model)
    model.Parent = folder
    local size = model:GetExtentsSize()
    local parts = 0
    for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
    table.insert(lines, ("[PROP] %-20s %5.1f x %5.1f x %5.1f studs, %2d pieces, pivot y=%.2f")
        :format(name, size.X, size.Y, size.Z, parts, model:GetPivot().Position.Y))
end
table.insert(lines, ("[BILAN] %d props dans ServerStorage.%s"):format(#folder:GetChildren(), FOLDER))
print(table.concat(lines, "\n"))
