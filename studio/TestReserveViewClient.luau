--!nonstrict
--[[ TestReserveViewClient
     Rôle    : vérifier l'affichage d'après rebirth sur l'instantané de FixtureReserveView : Réserve d'or marquée
               dans l'inventaire (A6 §3) et écran de rebirth passé au palier suivant (A6 §7).
     Doc     : GAME_MASTER_V2 A6 §3 et §7, C3 ; PROMPT_EXECUTION_SABL_V4 §20, §31.9 lot E ; décisions 32 et 40
     Étape   : 9, lot E
     Dépend  : Play en cours, datamodel Client ; ServerStorage.Tests.FixtureReserveView lancé juste avant par le
               runner (instantané dix fois par seconde pendant 40 s, attribut Workspace SABL_FixtureRebirth) ;
               Controllers.InventoryController (tri par revenu) et RebirthController démarrés
     Exposé  : texte de bilan ; exécuté tel quel par l'outil, faute de require. Lecture seule : les deux écrans
               sont ouverts puis refermés
     Limite  : attend que l'instantané factice soit affiché, puis lit tout d'un seul tenant, sans céder la main ;
               gains recopiés de C3 pour les paliers 2 à 5.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RESERVE = Color3.fromRGB(230, 180, 60)
local WAIT_SECONDS = 5
-- C3, recopié : gains attendus du palier proposé après un rebirth.
local GAINS = {
    [2] = {"×4 (au lieu de ×2)", "+500 tokens"},
    [3] = {"×8 (au lieu de ×4)", "Monde 2 débloqué"},
    [4] = {"×16 (au lieu de ×8)", "+2000 tokens"},
    [5] = {"×32 (au lieu de ×16)", "Monde 3 débloqué"},
}

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function oneLine(text) return (text:gsub("\n", " / ")) end

local expected = Workspace:GetAttribute("SABL_FixtureRebirth")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
local inventory = gui:WaitForChild("Inventory")
local rebirthScreen = gui:WaitForChild("RebirthScreen")
local grid = inventory.Panel.Grid
local rebirthPanel = rebirthScreen.Panel
-- Les deux controllers redessinent un écran ouvert à chaque instantané reçu.
inventory.Enabled = true
rebirthScreen.Enabled = true

local function cards()
    local list = {}
    for _, card in ipairs(grid:GetChildren()) do
        if card:IsA("Frame") and card.Name:match("^Card_") then table.insert(list, card) end
    end
    return list
end
local function fakeShown()
    local list = cards()
    for _, card in ipairs(list) do
        if not card.TierLabel.Text:find("réserve", 1, true) then return false end
    end
    return #list > 0 and rebirthPanel.CostLabel.Text:find(("^Rebirth %d "):format(tonumber(expected) or -1)) ~= nil
end
local deadline = os.clock() + WAIT_SECONDS
while not fakeShown() and os.clock() < deadline do task.wait(0.05) end

-- Tout est lu d'un seul tenant : aucun instantané ne peut s'intercaler entre deux lectures.
local total, reserved, gold, income, lit = 0, 0, 0, 0, 0
for _, card in ipairs(cards()) do
    total += 1
    if card.TierLabel.Text:find("réserve", 1, true) then reserved += 1 end
    if card.TierLabel.TextColor3 == RESERVE then gold += 1 end
    if card.StatLabel.Text == "Réserve d'or" then income += 1 end
    local stroke = card:FindFirstChildOfClass("UIStroke")
    if stroke and stroke.Transparency < 1 then lit += 1 end
end
local cost, gains = rebirthPanel.CostLabel.Text, rebirthPanel.GainsLabel.Text
local losses = rebirthPanel.LossesLabel.Text

check(("Decision 32 : %d cartes sur %d marquees « reserve », dont %d en or"):format(reserved, total, gold),
    total > 0 and reserved == total and gold == total)
check(("Tri par revenu : %d cartes sur %d affichent « Reserve d'or » au lieu d'un revenu"):format(income, total),
    income == total)
check(("A6 §3 : %d doublon(s) surligne(s), la reserve ne fusionne pas"):format(lit), lit == 0)
check(("A6 §7 apres rebirth : « %s » (palier %s attendu)"):format(oneLine(cost), tostring(expected)),
    cost:find(("^Rebirth %d "):format(tonumber(expected) or -1)) ~= nil)
local missing = {}
for _, part in ipairs(GAINS[expected] or {"?"}) do
    if not gains:find(part, 1, true) then table.insert(missing, part) end
end
check(("Gains du palier suivant : %s"):format(oneLine(gains)), #missing == 0)
check(("Pertes apres rebirth : %s"):format(oneLine(losses)),
    losses:find("Tes 0 brainrots actifs", 1, true) ~= nil and losses:find("(0 💰)", 1, true) ~= nil)

inventory.Enabled = false
rebirthScreen.Enabled = false
table.insert(T.lines, ("[RESERVE VIEW CLIENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
