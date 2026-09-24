--!nonstrict
--[[ TestBasePanelClient
     Rôle    : vérifier l'écran de gestion de base (A6 §4) : une ligne par composant A5 et une pour les décos,
               prix affichés, composants sans effet marqués « bientôt », boutons tactiles.
     Doc     : GAME_MASTER_V2 A5, A6 §4 ; PROMPT_EXECUTION_SABL_V4 §20, Loi 7 ; Q2 de l'étape 9
     Étape   : 9, lot B ; Coffre-fort achetable au lot F1 ; Tourelle et Piège au lot F2 ; Alarme au lot F3
     Dépend  : Play en cours, datamodel Client ; Controllers.InventoryController démarré ;
               StarterGui.BasePanel (studio/BuildInventory.luau)
     Exposé  : texte de bilan ; exécuté tel quel par l'outil dans le datamodel Client, car l'outil ne peut
               pas require. Lecture seule : l'écran est ouvert, rien n'est acheté
     Limite  : les libellés attendus sont recopiés de UpgradeConfig, faute de require. L'achat réel, lui,
               se prouve par un clic sur le bouton (outil de souris), annoncé au Producer.
]]
local Players = game:GetService("Players")

local MIN_TOUCH = 44 -- Loi 7
local ROWS = { -- UpgradeConfig : clé, achetable
    {"Slots", true}, {"Generator", true}, {"Alarm", true}, {"Turret", true},
    {"Trap", true}, {"Vault", true}, {"TrainingRing", true}, {"Decor", true},
}
local expectedSoon, expectedBuyable = 0, 0
for _, spec in ipairs(ROWS) do
    if spec[2] then expectedBuyable += 1 else expectedSoon += 1 end
end

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BasePanel")
local list = gui.Panel.ComponentList
gui.Enabled = true
-- Le controller redessine l'écran ouvert à chaque profil synchronisé (au moins une fois par seconde).
local deadline = os.clock() + 6
repeat task.wait(0.25) until list:FindFirstChild("RowDecor") or os.clock() > deadline
task.wait(0.3)

local rows = {}
for _, row in ipairs(list:GetChildren()) do
    if row:IsA("Frame") then rows[row.Name] = row end
end
local count, ordered = 0, true
for index, spec in ipairs(ROWS) do
    local row = rows["Row" .. spec[1]]
    if row then
        count += 1
        if row.LayoutOrder ~= index then ordered = false end
    end
end
check(("A6 §4 : %d lignes dans l'ordre de UpgradeConfig (attendu %d)"):format(count, #ROWS), count == #ROWS and ordered)

local soon, buyable, priced, small, mislabeled = 0, 0, 0, 0, 0
for _, spec in ipairs(ROWS) do
    local row = rows["Row" .. spec[1]]
    if row then
        local text = row.Label.Text
        if spec[2] then
            if row.BuyButton.Visible then buyable += 1 end
            if text:find("💰") or text:find("maximum atteint") then priced += 1 end
            if text:find("bientôt") then mislabeled += 1 end
        elseif text:find("bientôt") and not row.BuyButton.Visible then
            soon += 1
        end
        if row.BuyButton.AbsoluteSize.X < MIN_TOUCH or row.BuyButton.AbsoluteSize.Y < MIN_TOUCH then small += 1 end
    end
end
check(("Q2 : %d composant sans effet marque « bientot », bouton masque (attendu %d)"):format(soon, expectedSoon),
    soon == expectedSoon)
check(("A5 : %d lignes achetables avec leur bouton et leur prix, aucune « bientot » (attendu %d)")
    :format(math.min(buyable, priced), expectedBuyable),
    buyable == expectedBuyable and priced == expectedBuyable and mislabeled == 0)
check(("Loi 7 : %d bouton(s) sous %d px"):format(small, MIN_TOUCH), small == 0)
local summary = gui.Panel.SummaryLabel.Text
check("Resume : revenu, bonus du generateur et des decos affiches",
    summary:find("Revenu") ~= nil and summary:find("générateur") ~= nil and summary:find("décos") ~= nil)
gui.Enabled = false

table.insert(T.lines, ("[BASE PANEL CLIENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
