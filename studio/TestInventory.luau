--!nonstrict
--[[ TestInventory
     Rôle    : vérifier l'écran d'inventaire et le panneau de base sur des données réelles.
     Doc     : GAME_MASTER_V2 A6 §3-4, A5, B1, B3 ; PROMPT_EXECUTION_SABL_V4 §18.3, §20.1, Loi 7
     Étape   : 4, lot D
     Dépend  : Play client, écrans construits par studio/BuildInventory.luau
     Exposé  : bilan ; lecture seule, aucune action envoyée au serveur
     Limite  : on pilote le controller déjà démarré par Main.client ; en créer un
               second via require ferait rendre deux fois la même grille.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyUtil = require(ReplicatedStorage.Shared.EconomyUtil)
local ErrorMessages = require(ReplicatedStorage.Shared.ErrorMessages)
local MIN_TOUCH, MIN_TEXT = 44, 16
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local screen = playerGui:WaitForChild("Inventory", 10)
local basePanel = playerGui:WaitForChild("BasePanel", 10)
check("Les deux ecrans sont fermes au demarrage (§20.2.6)",
    screen.Enabled == false and basePanel.Enabled == false)
check("Resume vide avant le premier profil", basePanel.Panel.SummaryLabel.Text == "")

local sync, profile = ReplicatedStorage.Remotes.SyncProfile, nil
local conn = sync.OnClientEvent:Connect(function(s) if type(s) == "table" then profile = s end end)
repeat task.wait(0.2) until profile ~= nil
task.wait(1.2)
table.insert(T.lines, ("[INFO] profil : %d creatures, plot %s, %d slots"):format(
    #profile.Creatures, tostring(profile.Base.Plot), profile.Base.Slots))

local hudBar = playerGui.HUD.ButtonBar
check("Bouton Sac deverrouille", hudBar.InventoryButton:GetAttribute("Locked") == false)
check("Bouton Base deverrouille", hudBar.BaseButton:GetAttribute("Locked") == false)
screen.Enabled = true
basePanel.Enabled = true
task.wait(1.3) -- un snapshot suffit : le controller redessine les écrans ouverts
conn:Disconnect()

local grid = screen.Panel.Grid
local cards = {}
for _, child in ipairs(grid:GetChildren()) do
    if child:IsA("Frame") and child.Name:match("^Card_") then table.insert(cards, child) end
end
check(("Une carte par creature, sans doublon (%d/%d)"):format(#cards, #profile.Creatures),
    #cards == #profile.Creatures)

local incomes = {}
for _, card in ipairs(cards) do
    local uid = card.Name:sub(6)
    for _, creature in ipairs(profile.Creatures) do
        if creature.Uid == uid then
            incomes[card.LayoutOrder] = EconomyUtil.GetCreatureIncome(creature.Id, creature.Tier)
            break
        end
    end
end
local sorted = #incomes == #cards
for order = 2, #incomes do
    if incomes[order] > incomes[order - 1] then sorted = false end
end
check("Tri par revenu decroissant", sorted)
table.insert(T.lines, ("[INFO] revenus affiches : %s"):format(table.concat(incomes, ", ")))

local placedLabels = 0
for _, card in ipairs(cards) do
    if string.find(card.TierLabel.Text, "posé", 1, true) then placedLabels += 1 end
end
local placedProfile = 0
for _, creature in ipairs(profile.Creatures) do
    if creature.PlacedSlot ~= nil then placedProfile += 1 end
end
check(("Creatures posees signalees (%d/%d)"):format(placedLabels, placedProfile),
    placedLabels == placedProfile)

-- A6 §3 : seuls les lots d'au moins trois identiques sont surlignés.
local counts = {}
for _, creature in ipairs(profile.Creatures) do
    local key = creature.Id .. "|" .. tostring(creature.Tier)
    counts[key] = (counts[key] or 0) + 1
end
local expectedHighlight, triplets = 0, {}
for key, count in pairs(counts) do
    if count >= 3 then
        expectedHighlight += count
        table.insert(triplets, key .. " x" .. count)
    end
end
local actualHighlight = 0
for _, card in ipairs(cards) do
    if card.UIStroke.Transparency < 1 then actualHighlight += 1 end
end
table.sort(triplets)
check(("Duplicatas surlignes : %d attendus, %d surlignes%s"):format(expectedHighlight, actualHighlight,
    #triplets > 0 and (" | " .. table.concat(triplets, ", ")) or ""),
    expectedHighlight == actualHighlight)

local first = cards[1]
check("Carte renseignee (nom, tier, statistique)", first ~= nil
    and first.NameLabel.Text ~= "" and first.NameLabel.Text ~= "Label"
    and first.TierLabel.Text ~= "" and first.StatLabel.Text ~= "")
if first then
    table.insert(T.lines, ("[INFO] premiere carte : %s / %s / %s"):format(
        first.NameLabel.Text, first.TierLabel.Text, first.StatLabel.Text))
end

local smallButtons, smallTexts = {}, {}
for _, ui in ipairs({screen, basePanel}) do
    for _, gui in ipairs(ui:GetDescendants()) do
        if gui:IsA("GuiButton") and gui.Visible then
            local abs = gui.AbsoluteSize
            if abs.X > 0 and (abs.X < MIN_TOUCH or abs.Y < MIN_TOUCH) then
                table.insert(smallButtons, ("%s=%dx%d"):format(gui.Name, abs.X, abs.Y))
            end
        end
        if (gui:IsA("TextLabel") or gui:IsA("TextButton")) and gui.Text ~= "" and gui.TextSize < MIN_TEXT then
            table.insert(smallTexts, ("%s=%d"):format(gui.Name, gui.TextSize))
        end
    end
end
check("Boutons >= 44 px" .. (#smallButtons > 0 and (" : " .. table.concat(smallButtons, ", ")) or ""),
    #smallButtons == 0)
check("Textes >= 16 px" .. (#smallTexts > 0 and (" : " .. table.concat(smallTexts, ", ")) or ""),
    #smallTexts == 0)

local bar = screen.Panel.ActionBar
check("4 actions presentes (A6 §3)", bar:FindFirstChild("PlaceButton") ~= nil
    and bar:FindFirstChild("SellButton") ~= nil and bar:FindFirstChild("FuseButton") ~= nil
    and bar:FindFirstChild("EngageButton") ~= nil)
check("ENGAGER verrouille jusqu'a l'etape 13", bar.EngageButton:GetAttribute("Locked") == true)
check("Les deux tris sont proposes (A6 §3)",
    screen.Panel.SortBar:FindFirstChild("SortIncomeButton") ~= nil
    and screen.Panel.SortBar:FindFirstChild("SortPvpButton") ~= nil)

local summary = basePanel.Panel.SummaryLabel.Text
check("Resume de base renseigne", string.find(summary, "Revenu", 1, true) ~= nil)
local rows = 0
for _, child in ipairs(basePanel.Panel.ComponentList:GetChildren()) do
    if child:IsA("TextLabel") then rows += 1 end
end
check(("Composants A5 listes (%d lignes)"):format(rows), rows == 7)
table.insert(T.lines, "[INFO] resume = " .. summary:gsub("\n", " | "))

check("Messages d'erreur traduits (§18.3)",
    ErrorMessages.Get("NO_SLOT") ~= ErrorMessages.Get("INTERNAL")
    and ErrorMessages.Get("MISMATCH") ~= ErrorMessages.Get("INTERNAL")
    and ErrorMessages.Get("CODE_INCONNU") == ErrorMessages.Get("INTERNAL"))

screen.Enabled = false
basePanel.Enabled = false
table.insert(T.lines, ("[INVENTORY TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
print(table.concat(T.lines, "\n"))
return {passed = T.pass, failed = T.fail, success = T.fail == 0}
