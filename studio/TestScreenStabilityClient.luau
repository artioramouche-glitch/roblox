--!nonstrict
--[[ TestScreenStabilityClient
     Rôle    : prouver le correctif du bug 12 : l'inventaire et l'écran de base ouverts ne recréent plus leurs
               cartes et leurs lignes à chaque synchronisation, un clic n'y tombe donc plus sur un bouton détruit.
     Doc     : GAME_MASTER_V2 A6 §3-4 ; PROMPT_EXECUTION_SABL_V4 §20 ; bug 12 de PROGRESS
     Étape   : 9, lot E
     Dépend  : Play en cours, datamodel Client, profil réel synchronisé chaque seconde (revenu) ;
               Controllers.InventoryController démarré
     Exposé  : texte de bilan ; exécuté tel quel par l'outil. Lecture seule : les deux écrans sont ouverts puis
               refermés
     Limite  : une reconstruction reste normale quand le contenu change (achat, pose, vente, prix atteint).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WATCH_SECONDS = 4

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
local inventory, base = gui:WaitForChild("Inventory"), gui:WaitForChild("BasePanel")
local grid, list = inventory.Panel.Grid, base.Panel.ComponentList
inventory.Enabled = true
base.Enabled = true
task.wait(1.5) -- une synchronisation après l'ouverture : les deux écrans sont dessinés

local function firstCard()
    local names = {}
    for _, card in ipairs(grid:GetChildren()) do
        if card:IsA("Frame") and card.Name:match("^Card_") then table.insert(names, card.Name) end
    end
    table.sort(names)
    return names[1]
end
local cardName = firstCard()
local lastCard = cardName and grid:FindFirstChild(cardName)
local lastButton = list:FindFirstChild("RowSlots") and list.RowSlots.BuyButton
local syncs, cardChanges, rowChanges = 0, 0, 0
local connection = ReplicatedStorage.Remotes.SyncProfile.OnClientEvent:Connect(function() syncs += 1 end)
local start = os.clock()
while os.clock() - start < WATCH_SECONDS do
    task.wait(0.05)
    local card = cardName and grid:FindFirstChild(cardName)
    if card ~= lastCard then cardChanges += 1 lastCard = card end
    local row = list:FindFirstChild("RowSlots")
    local button = row and row.BuyButton
    if button ~= lastButton then rowChanges += 1 lastButton = button end
end
connection:Disconnect()
check(("Bug 12 : %d synchronisations en %d s ; %d carte et %d ligne recreees"):format(syncs, WATCH_SECONDS,
    cardChanges, rowChanges), syncs >= 2 and cardName ~= nil and lastButton ~= nil and cardChanges == 0
    and rowChanges == 0)
check("Resume de la base toujours mis a jour sur place (revenu affiche)",
    base.Panel.SummaryLabel.Text:find("Revenu", 1, true) ~= nil)

inventory.Enabled = false
base.Enabled = false
table.insert(T.lines, ("[SCREEN STABILITY CLIENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
