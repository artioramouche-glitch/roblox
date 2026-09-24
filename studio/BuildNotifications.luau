--!strict
--[[ BuildNotifications
     Rôle    : créer le bandeau d'information (Notifications) dans StarterGui, en mode Édition, sans rien supprimer.
     Doc     : GAME_MASTER_V2 G1 (NotificationController) ; PROMPT_EXECUTION_SABL_V4 §20, Loi 7 ; décision 44
     Étape   : 9, lot F1
     Dépend  : StarterGui
     Exposé  : exécution manuelle dans Studio ; idempotent, aucun script de gameplay
     Limite  : coquille seule : NotificationController écrit le texte et montre le bandeau ; couleurs reprises
               de studio/BuildInventory.luau.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local StarterGui = game:GetService("StarterGui")

local TEXT_BODY = 18 -- §20.1 : au moins 16 px
local TOAST_WIDTH, TOAST_HEIGHT = 560, 52
local TOP_OFFSET = 72 -- sous la barre Roblox (IgnoreGuiInset actif), au-dessus du reste
local PANEL = Color3.fromRGB(30, 30, 38)
local ACCENT = Color3.fromRGB(255, 200, 50)

local function ensure(parent: Instance, className: string, name: string): Instance
    local existing = parent:FindFirstChild(name)
    if existing then
        assert(existing.ClassName == className,
            ("%s existe avec la classe %s"):format(existing:GetFullName(), existing.ClassName))
        return existing
    end
    local created = Instance.new(className)
    created.Name = name
    created.Parent = parent
    return created
end

local screen = ensure(StarterGui, "ScreenGui", "Notifications") :: ScreenGui
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 40 -- au-dessus des écrans (30 à 32) : un versement se lit même écran ouvert
screen.Enabled = true

local toast = ensure(screen, "Frame", "Toast") :: Frame
toast.Visible = false
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, TOP_OFFSET)
toast.Size = UDim2.fromOffset(TOAST_WIDTH, TOAST_HEIGHT)
toast.BackgroundColor3 = PANEL
toast.BackgroundTransparency = 0.1
toast.BorderSizePixel = 0
toast.Active = false -- n'arrête aucun clic
ensure(toast, "UICorner", "UICorner")
local stroke = ensure(toast, "UIStroke", "UIStroke") :: UIStroke
stroke.Color = ACCENT
stroke.Thickness = 2

local label = ensure(toast, "TextLabel", "ToastLabel") :: TextLabel
label.BackgroundTransparency = 1
label.Position = UDim2.fromOffset(12, 0)
label.Size = UDim2.new(1, -24, 1, 0)
label.Font = Enum.Font.GothamBold
label.TextSize = TEXT_BODY
label.TextColor3 = ACCENT
label.TextWrapped = true
label.RichText = false
label.Text = ""

print(("[BUILD NOTIFY] Bandeau pret : %dx%d a %d px du haut, texte %dpx"):format(TOAST_WIDTH, TOAST_HEIGHT,
    TOP_OFFSET, TEXT_BODY))
