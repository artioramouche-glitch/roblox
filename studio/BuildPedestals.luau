--!strict
--[[ BuildPedestals
     Rôle    : poser les 25 piédestaux de chaque plot, en mode Édition, sans rien supprimer.
     Doc     : GAME_MASTER_V2 A5 (3 → 25 slots), D1.3 ; PROMPT_EXECUTION_SABL_V4 §15, Loi 5
     Étape   : 4, lot A
     Dépend  : Workspace.Map_Monde1.Plots construit à l'étape 1
     Exposé  : exécution manuelle dans Studio ; idempotent
     Limite  : la disposition n'est pas spécifiée par le doc ; grille 5×5 déclarée en écart.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local Workspace = game:GetService("Workspace")

local SLOT_MAX = 25 -- A5 : 3 slots au départ, 25 au maximum
local GRID = 5
local SPACING = 12
local PEDESTAL_SIZE = Vector3.new(3, 1, 3)
local PEDESTAL_COLOR = Color3.fromRGB(120, 120, 130)

local map = assert(Workspace:FindFirstChild("Map_Monde1"), "Map_Monde1 absent")
local plots = assert(map:FindFirstChild("Plots"), "Plots absent")

local created, existing = 0, 0
for _, plot in ipairs(plots:GetChildren()) do
    if plot:IsA("BasePart") and plot.Name:match("^Plot%d+$") then
        local folder = plot:FindFirstChild("Pedestals")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "Pedestals"
            folder.Parent = plot
        end
        local top = plot.Position.Y + plot.Size.Y / 2
        for slot = 1, SLOT_MAX do
            local name = "Pedestal" .. slot
            local pedestal = folder:FindFirstChild(name)
            if pedestal then
                existing += 1
            else
                -- Grille 5×5 centrée sur le plot : 4 × 12 = 48 studs sur 80 disponibles.
                local column = (slot - 1) % GRID
                local row = math.floor((slot - 1) / GRID)
                local offsetX = (column - (GRID - 1) / 2) * SPACING
                local offsetZ = (row - (GRID - 1) / 2) * SPACING
                local part = Instance.new("Part")
                part.Name = name
                part.Anchored = true
                part.CanCollide = true
                part.Size = PEDESTAL_SIZE
                part.Color = PEDESTAL_COLOR
                part.Material = Enum.Material.SmoothPlastic
                part.TopSurface = Enum.SurfaceType.Smooth
                part.BottomSurface = Enum.SurfaceType.Smooth
                part.Position = Vector3.new(
                    plot.Position.X + offsetX,
                    top + PEDESTAL_SIZE.Y / 2,
                    plot.Position.Z + offsetZ)
                part:SetAttribute("Slot", slot)
                part:SetAttribute("Uid", "")
                part.Parent = folder
                created += 1
            end
        end
    end
end

print(("[BUILD PEDESTALS] %d crees, %d deja presents ; %d slots par plot, grille %dx%d espacee de %d studs")
    :format(created, existing, SLOT_MAX, GRID, GRID, SPACING))
