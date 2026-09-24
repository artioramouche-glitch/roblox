--!strict
--[[ BuildStealAlert
     Rôle    : créer les deux écrans du vol dans StarterGui, en mode Édition, sans rien supprimer.
     Doc     : GAME_MASTER_V2 A4, A5 (Alarme), A6 §5 ; PROMPT_EXECUTION_SABL_V4 §20.1, §20.2, §20.3 (écran 5),
               Loi 7 ; décision 43
     Étape   : 5, lot D2 ; traqueur de l'alarme (StealStatus.AlarmTracker) à l'étape 9, lot F3
     Dépend  : StarterGui
     Exposé  : exécution manuelle en Édition ; idempotent ; StarterGui.StealAlert et StarterGui.StealStatus
     Limite  : aucune logique de jeu ici : StealAlertController remplit et allume ces écrans à partir
               des attributs publiés par StealService. Les couleurs ne sont pas spécifiées par le doc,
               choix sobre déclaré ; aucun asset ni glyphe (Loi 5), la flèche est dessinée en barres.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local StarterGui = game:GetService("StarterGui")

local GO_BUTTON = Vector2.new(220, 56) -- > 44 px exigés par la Loi 7, avant tout UIScale
local ROW_BUTTON = Vector2.new(176, 48) -- bouton « Racheter » d'une ligne de rachat
local ROW_SMALL = Vector2.new(112, 48) -- bouton « Y aller » d'une ligne de rachat
local PANEL_WIDTH = 320
local ROW_HEIGHT = 112 -- deux lignes de texte, un espace, puis les boutons de 48 px
local ROW_GAP = 8
local BANNER = Vector2.new(520, 56)
local TITLE_TEXT_SIZE = 32
local BODY_TEXT_SIZE = 18
local SMALL_TEXT_SIZE = 16 -- minimum absolu du §20.1
local ARROW_BOX = 96 -- côté du cadre de la flèche, tourné par le controller
local ARROW_THICKNESS = 12
local ARROW_HEAD = 46 -- longueur d'une branche de la pointe
local ARROW_STEM = 70
local ARROW_TIP = 14 -- distance du haut du cadre à la pointe
local ARROW_SPREAD = 40 -- degrés entre une branche et la hampe
local HUD_CLEARANCE = 104 -- barre de boutons du HUD (72 px) et sa marge : le bouton passe au-dessus
local MARGIN = 16
-- Traqueur de l'alarme (lot F3) : la même flèche aux deux tiers, sous le bandeau d'information (72 à 124 px).
local TRACKER = Vector2.new(220, 110)
local TRACKER_TOP = 132
local TRACKER_ARROW_BOX = 64
local TRACKER_ARROW_THICKNESS = 8
local TRACKER_ARROW_HEAD = 31
local TRACKER_ARROW_STEM = 47
local TRACKER_ARROW_TIP = 9
local ALARM_RED = Color3.fromRGB(230, 57, 70) -- ketchup D1.5, le rouge des tirs au but
local RED = Color3.fromRGB(180, 30, 30)
local DARK = Color3.fromRGB(18, 18, 24)
local LIGHT = Color3.fromRGB(255, 255, 255)
local DIM = Color3.fromRGB(150, 150, 160)

local function ensure(parent: Instance, className: string, name: string): Instance
    local existing = parent:FindFirstChild(name)
    if existing then
        if existing.ClassName == className then return existing end
        existing:Destroy() -- classe changée entre deux versions : l'écran se reconstruit proprement
    end
    local created = Instance.new(className)
    created.Name = name
    created.Parent = parent
    return created
end

local function ensureScreen(name: string, order: number, enabled: boolean): ScreenGui
    local screen = ensure(StarterGui, "ScreenGui", name) :: ScreenGui
    screen.IgnoreGuiInset = true -- §20.2.1 : l'encoche est gérée par le controller
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = order
    screen.Enabled = enabled
    local scale = ensure(screen, "UIScale", "UIScale") :: UIScale
    scale.Scale = 1 -- §20.2.2 : ajusté au runtime, jamais sous 1
    return screen
end

local function label(parent: Instance, name: string, size: number, color: Color3): TextLabel
    local text = ensure(parent, "TextLabel", name) :: TextLabel
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextSize = size
    text.TextColor3 = color
    text.TextWrapped = true
    text.RichText = false
    return text
end

local function button(parent: Instance, name: string, size: Vector2, text: string): TextButton
    local action = ensure(parent, "TextButton", name) :: TextButton
    action.Size = UDim2.fromOffset(size.X, size.Y) -- pixels fixes : mesurable par le test §20.4
    action.BackgroundColor3 = DARK
    action.BackgroundTransparency = 0.05
    action.BorderSizePixel = 0
    action.AutoButtonColor = true
    action.Font = Enum.Font.GothamBold
    action.TextSize = BODY_TEXT_SIZE
    action.TextColor3 = LIGHT
    action.Text = text
    ensure(action, "UICorner", "UICorner")
    return action
end

-- Écran 5 de la liste A6 : alerte de vol plein écran, flèche vers le voleur, bouton « Y ALLER ».
local alert = ensureScreen("StealAlert", 30, false)

local overlay = ensure(alert, "Frame", "Overlay") :: Frame
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = RED
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel = 0
overlay.Active = false -- le voile ne capture aucun clic : le joueur doit pouvoir courir
overlay.ZIndex = 1

local title = label(alert, "Title", TITLE_TEXT_SIZE, LIGHT)
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, MARGIN * 4)
title.Size = UDim2.new(0.8, 0, 0, TITLE_TEXT_SIZE + 8)
title.Text = "VOL EN COURS"
title.ZIndex = 2

local subtitle = label(alert, "Subtitle", BODY_TEXT_SIZE, LIGHT)
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0, MARGIN * 4 + TITLE_TEXT_SIZE + 12)
subtitle.Size = UDim2.new(0.8, 0, 0, BODY_TEXT_SIZE + 8)
subtitle.Text = ""
subtitle.ZIndex = 2

-- Flèche dessinée en barres : aucun asset (Loi 5) et aucun glyphe, que toutes les polices n'ont pas.
-- Au repos elle pointe vers le haut ; le controller fait tourner le cadre entier.
local arrow = ensure(alert, "Frame", "Arrow") :: Frame
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Position = UDim2.fromScale(0.5, 0.42)
arrow.Size = UDim2.fromOffset(ARROW_BOX, ARROW_BOX)
arrow.BackgroundTransparency = 1
arrow.ZIndex = 2

local function arrowBar(name: string, length: number, rotation: number): Frame
    local bar = ensure(arrow, "Frame", name) :: Frame
    bar.AnchorPoint = Vector2.new(0.5, 0) -- la rotation pivote autour de la pointe
    bar.Position = UDim2.fromOffset(ARROW_BOX / 2, ARROW_TIP)
    bar.Size = UDim2.fromOffset(ARROW_THICKNESS, length)
    bar.Rotation = rotation
    bar.BackgroundColor3 = LIGHT
    bar.BorderSizePixel = 0
    bar.ZIndex = 2
    ensure(bar, "UICorner", "UICorner")
    return bar
end

arrowBar("Stem", ARROW_STEM, 0)
arrowBar("Left", ARROW_HEAD, -ARROW_SPREAD)
arrowBar("Right", ARROW_HEAD, ARROW_SPREAD)

local go = button(alert, "GoButton", GO_BUTTON, "Y ALLER")
go.AnchorPoint = Vector2.new(0.5, 1)
go.Position = UDim2.new(0.5, 0, 1, -(MARGIN + HUD_CLEARANCE)) -- au-dessus de la barre du HUD (§20.2.4)
go.ZIndex = 2

-- Second écran : bandeau de refus (§18.3) et suivi des rachats (A4, Q10).
local status = ensureScreen("StealStatus", 20, true)

local banner = ensure(status, "Frame", "Banner") :: Frame
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, MARGIN)
banner.Size = UDim2.fromOffset(BANNER.X, BANNER.Y)
banner.BackgroundColor3 = DARK
banner.BackgroundTransparency = 0.1
banner.BorderSizePixel = 0
banner.Visible = false
ensure(banner, "UICorner", "UICorner")
local message = label(banner, "Message", BODY_TEXT_SIZE, LIGHT)
message.Size = UDim2.fromScale(1, 1)
message.Text = ""

local panel = ensure(status, "Frame", "RevengePanel") :: Frame
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -MARGIN, 0.5, 0)
panel.Size = UDim2.fromOffset(PANEL_WIDTH, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y -- la hauteur suit les lignes affichées, écrans courts compris
panel.BackgroundTransparency = 1
panel.Visible = false
local layout = ensure(panel, "UIListLayout", "UIListLayout") :: UIListLayout
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.Padding = UDim.new(0, ROW_GAP)

-- Pastille sombre comme les lignes : §20.2.5, pas de texte clair posé sur le voile rouge.
local header = label(panel, "Header", BODY_TEXT_SIZE, LIGHT)
header.Size = UDim2.new(1, 0, 0, BODY_TEXT_SIZE + MARGIN)
header.LayoutOrder = 0
header.TextXAlignment = Enum.TextXAlignment.Right
header.Text = "Rachats possibles"
header.BackgroundColor3 = DARK
header.BackgroundTransparency = 0.15
ensure(header, "UICorner", "UICorner")
local headerPadding = ensure(header, "UIPadding", "UIPadding") :: UIPadding
headerPadding.PaddingRight = UDim.new(0, 12)

-- Gabarit cloné par le controller, une ligne par offre de rachat.
local template = ensure(panel, "Frame", "Template") :: Frame
template.Size = UDim2.fromOffset(PANEL_WIDTH, ROW_HEIGHT)
template.BackgroundColor3 = DARK
template.BackgroundTransparency = 0.15
template.BorderSizePixel = 0
template.Visible = false
template.LayoutOrder = 99
ensure(template, "UICorner", "UICorner")
local padding = ensure(template, "UIPadding", "UIPadding") :: UIPadding
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)

local info = label(template, "Info", SMALL_TEXT_SIZE, LIGHT)
info.Size = UDim2.new(1, 0, 0, SMALL_TEXT_SIZE + 4)
info.TextXAlignment = Enum.TextXAlignment.Left
info.Text = ""
local timer = label(template, "Timer", SMALL_TEXT_SIZE, DIM)
timer.Position = UDim2.fromOffset(0, SMALL_TEXT_SIZE + 6)
timer.Size = UDim2.new(1, 0, 0, SMALL_TEXT_SIZE + 4)
timer.TextXAlignment = Enum.TextXAlignment.Left
timer.Text = ""

local buy = button(template, "BuyButton", ROW_BUTTON, "Racheter")
buy.AnchorPoint = Vector2.new(0, 1)
buy.Position = UDim2.new(0, 0, 1, 0)
local revenge = button(template, "GoButton", ROW_SMALL, "Y aller")
revenge.AnchorPoint = Vector2.new(1, 1)
revenge.Position = UDim2.new(1, 0, 1, 0)

-- Décision 43, niveau 3 de l'alarme : flèche vers le voleur pour tout le serveur, avec son nom. Pastille sombre
-- en haut au centre, masquée tant qu'aucune alarme de niveau 3 ne sonne ; aucun bouton, rien à toucher.
local tracker = ensure(status, "Frame", "AlarmTracker") :: Frame
tracker.AnchorPoint = Vector2.new(0.5, 0)
tracker.Position = UDim2.new(0.5, 0, 0, TRACKER_TOP)
tracker.Size = UDim2.fromOffset(TRACKER.X, TRACKER.Y)
tracker.BackgroundColor3 = DARK
tracker.BackgroundTransparency = 0.15
tracker.BorderSizePixel = 0
tracker.Active = false
tracker.Visible = false
ensure(tracker, "UICorner", "UICorner")
local thiefLabel = label(tracker, "ThiefLabel", BODY_TEXT_SIZE, LIGHT)
thiefLabel.Position = UDim2.fromOffset(8, 6)
thiefLabel.Size = UDim2.new(1, -16, 0, BODY_TEXT_SIZE + 6)
thiefLabel.TextWrapped = false
thiefLabel.TextTruncate = Enum.TextTruncate.AtEnd
thiefLabel.Text = ""
local trackerArrow = ensure(tracker, "Frame", "Arrow") :: Frame
trackerArrow.AnchorPoint = Vector2.new(0.5, 0)
trackerArrow.Position = UDim2.new(0.5, 0, 0, BODY_TEXT_SIZE + 16)
trackerArrow.Size = UDim2.fromOffset(TRACKER_ARROW_BOX, TRACKER_ARROW_BOX)
trackerArrow.BackgroundTransparency = 1

-- Mêmes barres que la flèche de l'alerte, à l'échelle du traqueur ; le controller fait tourner le cadre entier.
local function trackerBar(name: string, length: number, rotation: number): Frame
    local bar = ensure(trackerArrow, "Frame", name) :: Frame
    bar.AnchorPoint = Vector2.new(0.5, 0)
    bar.Position = UDim2.fromOffset(TRACKER_ARROW_BOX / 2, TRACKER_ARROW_TIP)
    bar.Size = UDim2.fromOffset(TRACKER_ARROW_THICKNESS, length)
    bar.Rotation = rotation
    bar.BackgroundColor3 = ALARM_RED
    bar.BorderSizePixel = 0
    ensure(bar, "UICorner", "UICorner")
    return bar
end

trackerBar("Stem", TRACKER_ARROW_STEM, 0)
trackerBar("Left", TRACKER_ARROW_HEAD, -ARROW_SPREAD)
trackerBar("Right", TRACKER_ARROW_HEAD, ARROW_SPREAD)

print(("[BUILD STEAL ALERT] StealAlert (bouton %dx%d) et StealStatus (boutons %dx%d et %dx%d, traqueur %dx%d) prets, texte minimal %dpx"):format(
    GO_BUTTON.X, GO_BUTTON.Y, ROW_BUTTON.X, ROW_BUTTON.Y, ROW_SMALL.X, ROW_SMALL.Y, TRACKER.X, TRACKER.Y,
    SMALL_TEXT_SIZE))
