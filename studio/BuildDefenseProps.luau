--!nonstrict
--[[ BuildDefenseProps
     Rôle    : construire en Édition la tourelle de base (A5), en primitives, dans ServerStorage.PropModels.
     Doc     : GAME_MASTER_V2 A5 (Tourelle), D1.5 (palette) ; PROMPT_EXECUTION_SABL_V4 §21.1, §22.1 ; décision 42
     Étape   : 9, lot F2
     Dépend  : mode Édition ; ServerStorage.PropModels (studio/BuildMapProps.luau)
     Exposé  : PROP_turret : racine au sol, canon vers −Z à 4,5 studs (bouche des tirs de Base.DefenseVisual),
               attribut PropId, tout ancré, noms de pièces uniques ; idempotent ; bilan dimensions
     Limite  : voie B (décision 21) : aucun maillage importé ; forme et couleurs déclarées, A5 ne les décrit pas.
               Les plaques de colle ne sont pas un prop : Base.DefenseVisual les crée à la taille de leur zone.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local ServerStorage = game:GetService("ServerStorage")

local FOLDER = "PropModels"
local NAME = "PROP_turret"
local ROOT_SIZE = Vector3.new(0.2, 0.02, 0.2) -- racine plate : pivot au sol (B0)
local MUZZLE_HEIGHT = 4.5 -- repris de Base.DefenseVisual (l'outil ne peut pas require)

-- D1.5 : la palette du monde 1 ; le gris et l'encre sont déclarés.
local KETCHUP = Color3.fromHex("E63946")
local MARKING = Color3.fromHex("FFD23F")
local INK = Color3.fromHex("2B2D42")
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

local folder = ServerStorage:FindFirstChild(FOLDER)
assert(folder and folder:IsA("Folder"), "ServerStorage.PropModels absent : lancer BuildMapProps")
local previous = folder:FindFirstChild(NAME)
if previous then previous:Destroy() end
local model = Instance.new("Model")
model.Name = NAME
local root = part(model, "Root", ROOT_SIZE, CFrame.new(0, 0, 0), GREY)
root.Transparency = 1
root.CanCollide = false
root.CanQuery = false
root.CanTouch = false
model.PrimaryPart = root
model:SetAttribute("PropId", "turret")

column(model, "Socle", 0.8, 3, Vector3.new(0, 0, 0), INK, Enum.Material.Metal)
column(model, "Colonne", 3, 1.2, Vector3.new(0, 0.8, 0), GREY, Enum.Material.Metal)
part(model, "Tete", Vector3.new(2.2, 1.4, 2.2), CFrame.new(0, MUZZLE_HEIGHT, 0), KETCHUP)
-- Canon couché sur Z : l'axe X du cylindre est tourné de 90° autour de Y, bouche vers −Z (l'entrée du plot).
part(model, "Canon", Vector3.new(2, 0.5, 0.5), CFrame.new(0, MUZZLE_HEIGHT, -2.1) * CFrame.Angles(0, math.rad(90), 0),
    INK, Enum.Material.Metal, Enum.PartType.Cylinder)
part(model, "Bande", Vector3.new(2.3, 0.25, 2.3), CFrame.new(0, MUZZLE_HEIGHT - 0.45, 0), MARKING)
local light = part(model, "Voyant", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, MUZZLE_HEIGHT + 0.95, 0), KETCHUP,
    Enum.Material.Neon, Enum.PartType.Ball)
light.CanCollide = false
model.Parent = folder

local size = model:GetExtentsSize()
local names, duplicates, parts = {}, 0, 0
for _, child in ipairs(model:GetChildren()) do
    if names[child.Name] then duplicates += 1 end
    names[child.Name] = true
    if child:IsA("BasePart") then parts += 1 end
end
local line = ("[DEFENSE PROP] %s %4.1f x %4.1f x %4.1f studs, %d pieces, %d homonyme(s), canon a %.1f stud(s)")
    :format(NAME, size.X, size.Y, size.Z, parts, duplicates, MUZZLE_HEIGHT)
print(line)
return line
