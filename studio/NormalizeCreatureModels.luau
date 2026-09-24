--!nonstrict
--[[ NormalizeCreatureModels
     Rôle    : transformer les modèles bruts de la réserve en modèles de jeu conformes à B0.
     Doc     : GAME_MASTER_V2 B0, B1, B5 ; PROMPT_EXECUTION_SABL_V4 §21.1, §21.3, §21.4
     Étape   : 6, lot A (5 communs) ; 7, lot A (25 brainrots M1 restants)
     Dépend  : mode Édition ; ServerStorage.CreatureSource (réserve désarmée), ServerStorage.CreatureModels
     Exposé  : un modèle `CRT_<id>` par entrée de la table : nettoyé, mis à la hauteur de sa fiche B5,
               pivot au sol, tout ancré, attribut CreatureId ; bilan hauteur avant/après et pièces
     Limite  : idempotent, chaque modèle est reconstruit depuis la réserve. Les maillages viennent de
               créateurs tiers (voie B, décision 21) : leur orientation n'est pas vérifiable par script,
               c'est le seul point qui demande un œil humain. Une entrée sans source dans la réserve est
               signalée et son modèle existant est laissé intact.
               Le travail se fait dans un atelier posé en Workspace : hors du monde rendu, un maillage
               skinné rapporte une boîte permutée, et toute mesure y est fausse. L'atelier disparaît
               à la fin.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Normalisation autorisée uniquement en mode Édition")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ROOT_SIZE = Vector3.new(0.2, 0.02, 0.2) -- racine plate : elle porte le pivot au sol (B0)
local SCALE_PASSES = 4 -- passes de convergence vers la hauteur de la fiche
local HEIGHT_TOLERANCE = 0.02 -- stud : en deçà, la hauteur est celle de la fiche
local TARGET_FOLDER = "CreatureModels"
local SOURCE_FOLDER = "CreatureSource"
local STAGE_FOLDER = "CreatureStage" -- atelier temporaire, dans le monde, détruit en fin de course

-- id (G5.1) -> nom du modèle dans la réserve, hauteur de la fiche B5.
-- Les écarts de nom entre le doc et la réserve sont volontaires et déclarés dans le rapport.
-- `rotation = {x =, y =, z =}` en degrés corrige à la main une créature que le redressement
-- automatique laisse de travers : c'est la seule chose qui demande un œil, une ligne suffit.
local MAPPING = {
    {id = "noobini", source = "Noobini Pizzanini", height = 2.5},
    {id = "tim_cheese", source = "Tim Cheese", height = 2.2},
    {id = "fluriflura", source = "Fluri Flura", height = 2.5},
    {id = "pipi_kiwi", source = "Pipi Kiwi", height = 2.0},
    {id = "talpa", source = "Talpa Di Fero", height = 2.3},
    {id = "trippi", source = "Trippi Troppi", height = 3.0},
    {id = "tung_tung", source = "Tung Sahur", height = 3.2},
    {id = "boneca", source = "Boneca Ambalabu", height = 2.8},
    {id = "footera", source = "Gangster Footera", height = 3.2},
    {id = "chim_banana", source = "Chimpanzini Bananini", height = 3.0},
    {id = "cappuccino", source = "Cappuccino Assassino", height = 3.0},
    {id = "patapim", source = "Brr Brr Patapim", height = 3.5},
    {id = "blueberrini", source = "Blueberrinni Octopusini", height = 3.5},
    {id = "strawberelli", source = "Strawberrelli Flamingelli", height = 3.2},
    {id = "burbaloni", source = "Burbaloni Luliloli", height = 3.5},
    {id = "bombombini", source = "Bombombini Gusini", height = 3.8},
    {id = "frigo_camelo", source = "Frigo Camelo", height = 4.5},
    {id = "tukanno", source = "Tukanno Bananno", height = 3.5},
    {id = "bombardiro", source = "Bombardiro Crocodilo", height = 5.0},
    {id = "lirili", source = "Lirili Larila", height = 4.2},
    {id = "glorbo", source = "Glorbo Fruttodrillo", height = 4.5},
    {id = "gorillo", source = "Gorillo Watermelondrillo", height = 5.0},
    {id = "tralalero", source = "Tralalero Tralala", height = 5.5},
    {id = "vaca", source = "La Vacca Saturno Saturnita", height = 5.0},
    {id = "sammyni", source = "Sammyni Spyderini", height = 4.5},
    {id = "girafa", source = "Girafa Celeste", height = 6.0},
    {id = "los_tralaleritos", source = "Los Tralaleritos", height = 5.0},
    {id = "chicleteira", source = "Chicleteira Bicicleteira", height = 4.5},
    {id = "la_grande", source = "La Grande Combinasion", height = 5.5},
    {id = "garama", source = "Garamararam", height = 6.5},
}

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

-- La réserve range les modèles du pack sous Normal, et les modèles autonomes à sa racine.
local function findSource(reserve, name)
    local normal = reserve:FindFirstChild("Normal")
    return (normal and normal:FindFirstChild(name)) or reserve:FindFirstChild(name)
end

-- B0 : aucune animation embarquée, rien qui s'exécute, rien qui pèse.
local function strip(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("LuaSourceContainer") or d:IsA("Animator") or d:IsA("AnimationController")
            or d:IsA("Humanoid") or d:IsA("Animation") or d:IsA("Sound") or d:IsA("ObjectValue") then
            d:Destroy()
        end
    end
end

-- Les maillages du pack sont exportés couchés : leur pièce dominante porte la rotation.
-- On l'annule autour du centre du modèle, ce qui remet la créature debout.
local function upright(model, override)
    local main, best = nil, 0
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            local volume = part.Size.X * part.Size.Y * part.Size.Z
            if volume > best then main, best = part, volume end
        end
    end
    if not main then return end
    local center = model:GetPivot().Position
    local rotation = main.CFrame.Rotation:Inverse()
    if override then
        rotation = CFrame.Angles(math.rad(override.x or 0), math.rad(override.y or 0), math.rad(override.z or 0))
            * rotation
    end
    local correction = CFrame.new(center) * rotation * CFrame.new(-center)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then part.CFrame = correction * part.CFrame end
    end
end

local function anchorAll(model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Massless = true
        end
    end
end

local reserve = assert(ServerStorage:FindFirstChild(SOURCE_FOLDER), "Reserve CreatureSource absente")
local target = ensureFolder(TARGET_FOLDER)
-- L'atelier : seul un modèle posé dans le monde rend des mesures fiables.
local stage = Workspace:FindFirstChild(STAGE_FOLDER)
if stage then stage:Destroy() end
stage = Instance.new("Folder")
stage.Name = STAGE_FOLDER
stage.Parent = Workspace
local lines, rebuilt, kept, missing, worst = {}, 0, 0, 0, 0

for _, entry in ipairs(MAPPING) do
    local template = findSource(reserve, entry.source)
    local name = "CRT_" .. entry.id
    if not template then
        missing += 1
        local existing = target:FindFirstChild(name)
        if existing then kept += 1 end
        table.insert(lines, ("[MANQUE] %-18s source « %s » absente de la reserve%s")
            :format(name, entry.source, existing and " ; modele existant conserve" or ""))
    else
        local previous = target:FindFirstChild(name)
        if previous then previous:Destroy() end
        local model = template:Clone()
        model.Parent = stage
        strip(model)
        -- Le maillage est d'abord ramené à l'origine : une racine posée loin de lui gonflerait la boîte.
        model:PivotTo(CFrame.new(0, 0, 0))
        upright(model, entry.rotation)
        -- La racine vient ensuite, avant toute mesure : sans PrimaryPart, les dimensions sont données
        -- dans la boîte orientée du maillage et non sur les axes du monde. C'est le piège qui fausse tout.
        local root = Instance.new("Part")
        root.Name = "Root"
        root.Size = ROOT_SIZE
        root.Transparency = 1
        root.Anchored = true
        root.CFrame = CFrame.new(0, 0, 0)
        root.Parent = model
        model.PrimaryPart = root
        local size = model:GetExtentsSize()
        -- La racine descend aux pieds : la mise à l'échelle se fait autour d'elle, ils ne bougent plus.
        root.CFrame = CFrame.new(0, -size.Y / 2, 0)
        -- ScaleTo fixe une échelle absolue par rapport au modèle d'origine : on part de l'échelle courante.
        for _ = 1, SCALE_PASSES do
            local current = model:GetExtentsSize().Y
            if current <= 0 or math.abs(current - entry.height) <= HEIGHT_TOLERANCE then break end
            model:ScaleTo(model:GetScale() * (entry.height / current))
        end
        anchorAll(model)
        model:PivotTo(CFrame.new(0, 0, 0))
        model.Name = name
        model:SetAttribute("CreatureId", entry.id)
        local final = model:GetExtentsSize() -- mesuré dans l'atelier, avant rangement
        worst = math.max(worst, math.abs(final.Y - entry.height))
        model.Parent = target
        rebuilt += 1
        local meshes = 0
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("MeshPart") then meshes += 1 end
        end
        table.insert(lines, ("[OK] %-18s %-26s %.2f -> %.2f studs (fiche %.1f), largeur %.2f, maillages %d")
            :format(name, entry.source, size.Y, final.Y, entry.height, final.X, meshes))
    end
end

stage:Destroy()
table.insert(lines, ("[BILAN] %d reconstruits, %d conserves faute de source, %d sources manquantes, %d modeles ; ecart de hauteur max %.3f stud")
    :format(rebuilt, kept, missing, #target:GetChildren(), worst))
local output = table.concat(lines, "\n")
print(output)
