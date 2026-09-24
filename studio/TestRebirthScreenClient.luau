--!nonstrict
--[[ TestRebirthScreenClient
     Rôle    : vérifier l'écran de rebirth (A6 §7) : ouvert par ♻️, coût et gains C3 du prochain palier, pertes,
               bouton de confirmation, et refus du serveur affiché quand l'argent manque.
     Doc     : GAME_MASTER_V2 A6 §1 et §7, C3, G4 ; PROMPT_EXECUTION_SABL_V4 §20, §31.9 lot E, Loi 7 ;
               décisions 32 et 40
     Étape   : 9, lot E
     Dépend  : Play en cours, datamodel Client ; Controllers.RebirthController démarré ; écran ouvert par un clic
               sur HUD.ButtonBar.RebirthButton, puis CONFIRMER cliqué (outil de souris) seulement si l'écran
               affiche « Il te manque » : le serveur doit alors refuser, et rien ne change
     Exposé  : texte de bilan ; exécuté tel quel par l'outil dans le datamodel Client, car l'outil ne peut pas
               require. Lecture seule
     Limite  : coûts et gains recopiés de C3 pour les paliers 1 à 5, faute de require côté outil.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MIN_TOUCH, MIN_TEXT = 44, 16 -- Loi 7, §20.1
local DIM = Color3.fromRGB(150, 150, 160)
-- C3, recopié : coût affiché et gains attendus de chaque palier.
local C3 = {
    [1] = {cost = "1.00M", gains = {"×2 (au lieu de ×1)", "+10 % de chance"}},
    [2] = {cost = "50.0M", gains = {"×4 (au lieu de ×2)", "+500 tokens"}},
    [3] = {cost = "2.50B", gains = {"×8 (au lieu de ×4)", "Monde 2 débloqué"}},
    [4] = {cost = "100B", gains = {"×16 (au lieu de ×8)", "+2000 tokens"}},
    [5] = {cost = "500B", gains = {"×32 (au lieu de ×16)", "Monde 3 débloqué"}},
}

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function oneLine(text) return (text:gsub("\n", " / ")) end

local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hudButton = gui.HUD.ButtonBar.RebirthButton
local screen = gui:WaitForChild("RebirthScreen")
local panel = screen.Panel
check("A6 §1 : bouton ♻️ deverrouille et actif", hudButton:GetAttribute("Locked") == false and hudButton.Active)
check("A6 §7 : le clic sur ♻️ ouvre l'ecran de rebirth", screen.Enabled)

local cost = panel.CostLabel.Text
local rebirth = tonumber(cost:match("^Rebirth (%d+) :"))
local spec = rebirth and C3[rebirth]
check(("C3 : « %s »"):format(oneLine(cost)), spec ~= nil and cost:find(spec.cost .. " 💰", 1, true) ~= nil)
local gains = panel.GainsLabel.Text
local missing = {}
for _, part in ipairs(spec and spec.gains or {"?"}) do
    if not gains:find(part, 1, true) then table.insert(missing, part) end
end
check(("Gains avant confirmation : %s%s"):format(oneLine(gains),
    #missing > 0 and (" (manque " .. table.concat(missing, ", ") .. ")") or ""), spec ~= nil and #missing == 0)
local losses = panel.LossesLabel.Text
check(("Pertes avant confirmation : %s"):format(oneLine(losses)),
    losses:find("repart de 0", 1, true) ~= nil and losses:find("base", 1, true) ~= nil
    and losses:find("bouclier", 1, true) ~= nil and losses:find("Réserve d'or", 1, true) ~= nil)

local shortOf = cost:find("Il te manque", 1, true) ~= nil
local confirm = panel.ConfirmButton
check(("Loi 7 : CONFIRMER %dx%d px%s"):format(confirm.AbsoluteSize.X, confirm.AbsoluteSize.Y,
    shortOf and ", grise faute d'argent" or ""), confirm.AbsoluteSize.X >= MIN_TOUCH
    and confirm.AbsoluteSize.Y >= MIN_TOUCH and (not shortOf or confirm.TextColor3 == DIM))
local small = 0
for _, object in ipairs(screen:GetDescendants()) do
    if (object:IsA("TextLabel") or object:IsA("TextButton")) and object.TextSize < MIN_TEXT then small += 1 end
end
local viewport = Workspace.CurrentCamera.ViewportSize
local top, bottom = panel.AbsolutePosition.Y, panel.AbsolutePosition.Y + panel.AbsoluteSize.Y
check(("§20.1 : %d texte(s) sous %d px ; panneau de y = %d a %d dans une fenetre de %d px"):format(small, MIN_TEXT,
    top, bottom, viewport.Y), small == 0 and top >= 0 and bottom <= viewport.Y)
local status = panel.StatusLabel.Text
check(("G4 : CONFIRMER sans l'argent, refus du serveur affiche : « %s »"):format(status),
    shortOf and status == "Pas assez d'argent.")

table.insert(T.lines, ("[REBIRTH SCREEN CLIENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
