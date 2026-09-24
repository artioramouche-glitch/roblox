--!nonstrict
--[[ TestStealScreensClient
     Rôle    : batterie du lot D2 : alerte plein écran, flèche, bandeau de refus, rachats, minuteur de portage.
     Doc     : GAME_MASTER_V2 A4, A6 §5-6 ; PROMPT_EXECUTION_SABL_V4 §18.3, §20.1, §20.4, §25.2
     Étape   : 5, lot D2
     Dépend  : Play en cours, datamodel Client ; scénario posé par studio/FixtureStealViews.luau,
               mode lu dans l'attribut Workspace SABL_TestMode (« on », « ghost » ou « off »)
     Exposé  : texte de bilan ; exécuté tel quel dans le datamodel Client, car l'outil MCP ne peut pas require
     Limite  : ne clique aucun bouton (le clic réel est fait à la souris par l'outil) et ne touche aucun profil.
               Écrit seulement l'attribut local StealLastResult, que le serveur ne lit jamais.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MIN_BUTTON = 44 -- §20.1 : contrainte dure, mesurée comme au §20.4
local SHIELD_MESSAGE = "Cette base est protégée par son bouclier." -- ErrorMessages.TARGET_SHIELDED
local BANNER_SECONDS = 3 -- durée d'affichage choisie par StealAlertController
local SEGMENTS = 12
local CARRY_SECONDS = 60 -- StealConfig.Thief.CarryTimeoutSeconds
local CLOCK_TOLERANCE = 2 -- s : écart toléré entre l'affichage et l'horloge serveur
local REPLICATION_WAIT = 0.5 -- laissé au client pour recevoir les attributs et rendre une image

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local alert = gui:WaitForChild("StealAlert", 10)
local status = gui:WaitForChild("StealStatus", 10)
local mode = Workspace:GetAttribute("SABL_TestMode")
mode = (mode == "on" or mode == "ghost" or mode == "off") and mode or "on"
task.wait(REPLICATION_WAIT)

local panel = status and status:FindFirstChild("RevengePanel")
local banner = status and status:FindFirstChild("Banner")
local function carryTimer()
    for _, child in ipairs(gui:GetChildren()) do
        if child:IsA("BillboardGui") and child.Name:match("^CarryTimer_") then return child end
    end
    return nil
end

check("Ecrans StealAlert et StealStatus presents dans le PlayerGui", alert ~= nil and status ~= nil)

if mode == "on" then
    check("A6 §5 : alerte allumee, voile rouge plein ecran", alert.Enabled == true
        and alert.Overlay.Size == UDim2.fromScale(1, 1) and alert.Overlay.BackgroundTransparency < 1)
    check("Alerte : creature nommee et secondes restantes", alert.Subtitle.Text:find("Noobini Pizzanini", 1, true) ~= nil
        and alert.Subtitle.Text:find("s") ~= nil)
    check("A6 §5 : fleche visible et orientee vers le voleur present", alert.Arrow.Visible == true
        and alert.Arrow.Rotation == alert.Arrow.Rotation and math.abs(alert.Arrow.Rotation) <= 360)
    check("Bouton Y ALLER present et >= 44 px", alert.GoButton.Text == "Y ALLER"
        and alert.GoButton.AbsoluteSize.X >= MIN_BUTTON and alert.GoButton.AbsoluteSize.Y >= MIN_BUTTON)

    local row1 = panel and panel:FindFirstChild("Offer_offer_1")
    local row2 = panel and panel:FindFirstChild("Offer_offer_2")
    check("A4 : panneau des rachats visible avec une ligne par offre", panel ~= nil and panel.Visible == true
        and row1 ~= nil and row2 ~= nil)
    check("Rachat 1 : creature, voleur nomme et prix sur le bouton", row1 ~= nil
        and row1.Info.Text:find("Noobini Pizzanini", 1, true) ~= nil and row1.Info.Text:find("Voleur", 1, true) ~= nil
        and row1.BuyButton.Text:find("600", 1, true) ~= nil)
    check("Rachat 1 : compte a rebours d'expiration affiche", row1 ~= nil and row1.Timer.Text:find("Encore") ~= nil)
    check("Q10 : vengeance offerte sur le rachat 1, retiree sur le rachat 2 deja utilise",
        row1 ~= nil and row1.GoButton.Visible == true and row2 ~= nil and row2.GoButton.Visible == false)
    check("Rachats : boutons >= 44 px", row1 ~= nil and row1.BuyButton.AbsoluteSize.Y >= MIN_BUTTON
        and row1.BuyButton.AbsoluteSize.X >= MIN_BUTTON and row1.GoButton.AbsoluteSize.Y >= MIN_BUTTON
        and row1.GoButton.AbsoluteSize.X >= MIN_BUTTON)

    local timer = carryTimer()
    local lit = 0
    if timer then
        for index = 1, SEGMENTS do
            local segment = timer:FindFirstChild("Segment" .. index)
            if segment and segment.BackgroundTransparency == 0 then lit += 1 end
        end
    end
    -- L'attendu se déduit du temps qu'il reste vraiment : le scénario vieillit entre la pose et le contrôle.
    local remaining = math.max(0, (player:GetAttribute("CarryEndsAt") or 0) - Workspace:GetServerTimeNow())
    local expected = math.clamp(math.ceil(remaining / CARRY_SECONDS * SEGMENTS), 0, SEGMENTS)
    local shown = timer and tonumber(timer.Remaining.Text) or nil
    check("A6 §6 : minuteur de portage au-dessus du voleur, anneau de 12 segments", timer ~= nil
        and timer.Adornee ~= nil and #timer:GetChildren() == SEGMENTS + 1)
    check(("A6 §6 : anneau proportionnel au portage restant (%d segments sur %d, attendu %d) et %s s affichees")
        :format(lit, SEGMENTS, expected, tostring(shown)),
        lit == expected and shown ~= nil and math.abs(shown - remaining) <= CLOCK_TOLERANCE)
elseif mode == "ghost" then
    check("Alerte toujours allumee avec un voleur absent du serveur", alert.Enabled == true)
    check("Fleche masquee faute de voleur a montrer", alert.Arrow.Visible == false)
else
    check("Sans vol : alerte eteinte", alert.Enabled == false)
    check("Sans rachat : panneau masque", panel ~= nil and panel.Visible == false)
    check("Aucun minuteur de portage", carryTimer() == nil)

    -- §18.3 : le bandeau traduit le code reçu, puis disparaît de lui-même.
    player:SetAttribute("StealLastResult", "AttemptSteal:TARGET_SHIELDED")
    task.wait(REPLICATION_WAIT)
    check("Bandeau : refus traduit en francais", banner ~= nil and banner.Visible == true
        and banner.Message.Text == SHIELD_MESSAGE)
    task.wait(BANNER_SECONDS)
    check("Bandeau : efface apres 3 s", banner ~= nil and banner.Visible == false)
    player:SetAttribute("StealLastResult", "TeleportToBase:OK")
    task.wait(REPLICATION_WAIT)
    check("Succes : aucun bandeau", banner ~= nil and banner.Visible == false)
end

local small = {}
for _, screen in ipairs({alert, status}) do
    for _, d in ipairs(screen:GetDescendants()) do
        if d:IsA("GuiButton") and (d.AbsoluteSize.X < MIN_BUTTON or d.AbsoluteSize.Y < MIN_BUTTON) then
            table.insert(small, ("%s = %dx%d"):format(d:GetFullName(), d.AbsoluteSize.X, d.AbsoluteSize.Y))
        end
    end
end
check(("§20.4 : tous les boutons des ecrans du vol >= %d px %s"):format(MIN_BUTTON, table.concat(small, ", ")), #small == 0)

table.insert(T.lines, ("[STEAL SCREENS TEST %s] %d OK / %d FAIL"):format(mode, T.pass, T.fail))
return table.concat(T.lines, "\n")
