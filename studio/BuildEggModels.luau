--!strict
--[[ BuildEggModels
     Rôle    : construire les cinq œufs du monde 1, en Édition, dans ServerStorage.PropModels.
     Doc     : GAME_MASTER_V2 B2 (les 8 œufs), B0 (conventions 3D), D1.3 Z2 (5 socles d'œufs M1)
     Étape   : 7, lot B
     Dépend  : mode Édition ; ServerStorage ; la liste des œufs recopie B2 et Config.EggConfig
               (l'outil MCP ne peut pas `require` un module du jeu, blocage du 15/09)
     Exposé  : ServerStorage.PropModels.PROP_egg_<id> : coquille ovoïde tachetée, pivot au sol,
               attribut PropId ; idempotent, chaque œuf est reconstruit
     Limite  : aucune fiche 3D n'existe pour les œufs dans B5 ni B6. La forme vient de B0 (primitives
               arrondies, couleurs franches) et les teintes sont un choix déclaré, une par gamme,
               du plus commun au plus rare. La taille croît avec la gamme, sans règle de jeu attachée.
               Les socles de la boutique viendront avec la map détaillée, à l'étape 8.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local ServerStorage = game:GetService("ServerStorage")

local FOLDER = "PropModels"
local ROOT_SIZE = Vector3.new(0.2, 0.02, 0.2) -- racine plate : pivot au sol (B0)
local SPOT_COUNT = 4

-- Les cinq gammes du monde 1 (B2), dans l'ordre du document : identifiant, nom, coquille, tache,
-- hauteur. Les teintes et la taille croissante sont un choix déclaré, le doc ne les fixe pas.
local EGGS = {
    {id = "egg_basic", name = "Œuf Street Basic", shell = "F4D58D", spot = "8B6F47", height = 1.25},
    {id = "egg_street", name = "Œuf Street", shell = "8D99AE", spot = "E63946", height = 1.35},
    {id = "egg_golden", name = "Œuf Golden", shell = "FFD23F", spot = "E0A800", height = 1.45},
    {id = "egg_mythic", name = "Œuf Mythic", shell = "FF5555", spot = "7B1E28", height = 1.55},
    {id = "egg_secret", name = "Œuf Interdit", shell = "783CC8", spot = "3A0CA3", height = 1.70},
}
-- Les taches, en proportion de la coquille : même semis pour tous les œufs.
local SPOTS = {
    Vector3.new(-0.28, 0.64, -0.33),
    Vector3.new(0.32, 0.43, -0.28),
    Vector3.new(0.09, 0.79, 0.29),
    Vector3.new(-0.24, 0.32, 0.30),
}

local function ensureFolder(name: string): Folder
    local folder = ServerStorage:FindFirstChild(name)
    if folder and not folder:IsA("Folder") then
        folder:Destroy()
        folder = nil
    end
    if not folder then
        local created = Instance.new("Folder")
        created.Name = name
        created.Parent = ServerStorage
        return created
    end
    return folder :: Folder
end

-- Une pièce Ball refuse une taille non uniforme : l'ovoïde passe par un maillage sphérique,
-- qui accepte l'étirement tout en gardant l'encombrement de la pièce.
local function ovoid(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = CFrame.new(position)
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = part
    part.Parent = parent
    return part
end

local folder = ensureFolder(FOLDER)
local lines = {}

for _, egg in ipairs(EGGS) do
    do
        local spec = egg
        local name = "PROP_" .. egg.id
        local previous = folder:FindFirstChild(name)
        if previous then previous:Destroy() end
        local model = Instance.new("Model")
        model.Name = name
        local root = Instance.new("Part")
        root.Name = "Root"
        root.Size = ROOT_SIZE
        root.CFrame = CFrame.new(0, 0, 0)
        root.Transparency = 1
        root.Anchored = true
        root.CanCollide = false
        root.CanQuery = false
        root.CanTouch = false
        root.Parent = model
        local width = spec.height * 0.75 -- ovoïde : plus haut que large
        ovoid(model, "Shell", Vector3.new(width, spec.height, width),
            Vector3.new(0, spec.height / 2, 0), Color3.fromHex(spec.shell))
        for index = 1, SPOT_COUNT do
            local place = SPOTS[index] * spec.height
            ovoid(model, "Spot" .. index, Vector3.new(width * 0.25, spec.height * 0.14, width * 0.25),
                Vector3.new(place.X, place.Y, place.Z), Color3.fromHex(spec.spot))
        end
        model.PrimaryPart = root
        model:SetAttribute("PropId", egg.id)
        model.Parent = folder
        local size = model:GetExtentsSize()
        table.insert(lines, ("[OEUF] %-18s %s, %.2f stud, %d pieces, pivot y=%.2f")
            :format(name, egg.name, size.Y, #model:GetChildren(), model:GetPivot().Position.Y))
    end
end

table.insert(lines, ("[BILAN] %d props dans ServerStorage.%s"):format(#folder:GetChildren(), FOLDER))
print(table.concat(lines, "\n"))
