--!nonstrict
--[[ TestEggShop
     Rôle    : vérifier l'affichage des probabilités B2 et les contraintes tactiles.
     Doc     : GAME_MASTER_V2 A6 §2, B2 ; PROMPT_EXECUTION_SABL_V4 §20.1, §24, Loi 7
     Étape   : 3, lot D
     Dépend  : Play client, StarterGui.EggShop construit par studio/BuildEggShop.luau
     Exposé  : bilan ; aucun achat déclenché, aucune écriture
     Limite  : le clic réel ne peut pas être simulé par script ; la révélation et
               le bouton Passer sont à vérifier à la main (procédure du rapport).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggConfig = require(ReplicatedStorage.Config.EggConfig)
local CreatureConfig = require(ReplicatedStorage.Config.CreatureConfig)
local MIN_TOUCH, MIN_TEXT = 44, 16
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local shop = playerGui:WaitForChild("EggShop", 10)
check("EggShop present dans PlayerGui", shop ~= nil and shop:IsA("ScreenGui"))
check("Boutique fermee au demarrage (§20.2.6)", shop.Enabled == false)
local panel = shop:WaitForChild("Panel")
local list = panel:WaitForChild("EggList")

local cards = {}
for _, child in ipairs(list:GetChildren()) do
    if child:IsA("Frame") and child.Name:match("^Card_") then cards[child.Name:sub(6)] = child end
end
local cardCount = 0
for _ in pairs(cards) do cardCount += 1 end
check(("Une carte par oeuf (%d/%d)"):format(cardCount, #EggConfig.Eggs), cardCount == #EggConfig.Eggs)

-- §24 : les probabilités de B2 sont affichées telles quelles, sans arrondi.
local oddsOk, nameOk, missing = true, true, {}
for _, egg in ipairs(EggConfig.Eggs) do
    local card = cards[egg.id]
    if not card then
        oddsOk = false
        table.insert(missing, egg.id)
    else
        for rarityId, weight in pairs(egg.odds) do
            local rarity = CreatureConfig:GetRarity(rarityId)
            local expected = ("%s %s%%"):format(rarity.Name, ("%g"):format(weight))
            if not string.find(card.OddsLabel.Text, expected, 1, true) then
                oddsOk = false
                table.insert(missing, egg.id .. "/" .. rarityId)
            end
        end
        if card.NameLabel.Text ~= egg.name then nameOk = false end
    end
end
check("Probabilites B2 affichees sur chaque oeuf (§24)"
    .. (#missing > 0 and (" ; manquant: " .. table.concat(missing, ", ")) or ""), oddsOk)
check("Nom d'oeuf conforme a la config", nameOk)
table.insert(T.lines, "[INFO] egg_secret affiche : " .. cards.egg_secret.OddsLabel.Text)

local world1, otherWorlds = 0, 0
for _, egg in ipairs(EggConfig.Eggs) do
    if cards[egg.id].Visible then
        if egg.world == 1 then world1 += 1 else otherWorlds += 1 end
    end
end
check(("Onglet Monde 1 actif : %d cartes visibles, 0 des autres mondes"):format(world1),
    world1 == 5 and otherWorlds == 0)
check("Oeuf d'un monde verrouille signale", cards.egg_dessert.StateLabel.Text ~= "")

shop.Enabled = true
task.wait(0.3)
local smallButtons, smallTexts = {}, {}
for _, gui in ipairs(shop:GetDescendants()) do
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
check("Boutons de la boutique >= 44 px" .. (#smallButtons > 0 and (" : " .. table.concat(smallButtons, ", ")) or ""),
    #smallButtons == 0)
check("Textes de la boutique >= 16 px" .. (#smallTexts > 0 and (" : " .. table.concat(smallTexts, ", ")) or ""),
    #smallTexts == 0)

local quantitiesOk = true
for _, card in pairs(cards) do
    for _, quantity in ipairs({1, 10, 50}) do
        if not card.BuyRow:FindFirstChild(("Buy%dButton"):format(quantity)) then quantitiesOk = false end
    end
end
check("Boutons x1 / x10 / x50 sur chaque oeuf (G4)", quantitiesOk)
check("Panneau de revelation cache avant achat", shop.ResultPanel.Visible == false)
check("Bouton Passer present (skip animation, A6 §2)", shop.ResultPanel.SkipButton ~= nil)
check("Mention de conformite visible", panel.NoticeLabel.Text ~= "")
check("Bouton de fermeture lisible", panel.CloseButton.Text ~= "")
shop.Enabled = false

table.insert(T.lines, ("[EGGSHOP TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
print(table.concat(T.lines, "\n"))
return {passed = T.pass, failed = T.fail, success = T.fail == 0}
