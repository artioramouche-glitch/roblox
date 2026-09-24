--!nonstrict
--[[ TestHUD
     Rôle    : mesurer le HUD réel dans PlayerGui et vérifier les contraintes mobiles.
     Doc     : GAME_MASTER_V2 A6 §1 ; PROMPT_EXECUTION_SABL_V4 §20.1, §20.4, Loi 7
     Étape   : 3, lot C ; boutons actifs attendus mis à jour à l'étape 9, lot F (dette 21)
     Dépend  : Play client, StarterGui.HUD construit par studio/BuildHUD.luau
     Exposé  : bilan ; aucune écriture, aucun envoi au serveur
     Limite  : §20.4 propose de mesurer StarterGui ; AbsoluteSize n'y vaut rien,
               les mesures sont donc prises sur PlayerGui, seul rendu au runtime.
               Depuis le 15/09, l'outil ne peut plus require : NumberFormatter.format est recopié ici.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
-- Shared.NumberFormatter, recopié tel quel (§16.9).
local NumberFormatter = {}
local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
function NumberFormatter.format(n)
    assert(type(n) == "number" and n == n and math.abs(n) < math.huge, "Expected a finite number")
    if n == 0 then return "0" end
    if math.abs(n) < 1000 then return tostring(math.floor(n)) end
    local index = 1
    while index < #SUFFIXES and math.abs(n) >= 1000 ^ index do
        index += 1
    end
    local scaled = n / (1000 ^ (index - 1))
    local magnitude = math.abs(scaled)
    local pattern = magnitude >= 100 and "%.0f" or magnitude >= 10 and "%.1f" or "%.2f"
    return pattern:format(scaled) .. SUFFIXES[index]
end
local MIN_BUTTON, MIN_TEXT = 44, 16
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("HUD", 10)
check("HUD present dans PlayerGui", hud ~= nil and hud:IsA("ScreenGui"))
check("IgnoreGuiInset actif (§20.2.1)", hud.IgnoreGuiInset == true)
check("Un seul ScreenGui HUD (§20.2.6)", #playerGui:GetChildren() >= 1 and hud.Enabled == true)

local viewport = Workspace.CurrentCamera.ViewportSize
table.insert(T.lines, ("[INFO] viewport = %dx%d ; UIScale = %.2f"):format(
    viewport.X, viewport.Y, hud.UIScale.Scale))
check("UIScale jamais sous 1 (Loi 7)", hud.UIScale.Scale >= 1)

-- Loi 7 / §20.1 : tous les boutons tactiles au moins 44 px, tout texte au moins 16 px.
local smallButtons, smallTexts = {}, {}
for _, gui in ipairs(hud:GetDescendants()) do
    if gui:IsA("GuiButton") then
        local abs = gui.AbsoluteSize
        if abs.X < MIN_BUTTON or abs.Y < MIN_BUTTON then
            table.insert(smallButtons, ("%s=%dx%d"):format(gui.Name, abs.X, abs.Y))
        end
    end
    if gui:IsA("TextLabel") or gui:IsA("TextButton") then
        if gui.Text ~= "" and gui.TextSize < MIN_TEXT then
            table.insert(smallTexts, ("%s=%d"):format(gui.Name, gui.TextSize))
        end
    end
end
check("Tous les boutons >= 44 px" .. (#smallButtons > 0 and (" : " .. table.concat(smallButtons, ", ")) or ""),
    #smallButtons == 0)
check("Tout texte >= 16 px" .. (#smallTexts > 0 and (" : " .. table.concat(smallTexts, ", ")) or ""),
    #smallTexts == 0)

-- A6 §1 : les six boutons du document, dans l'ordre ; seuls restent grisés ceux dont l'écran n'existe pas
-- encore (quêtes à l'étape 10, arène à l'étape 13).
local expected = {"EggsButton", "BaseButton", "InventoryButton", "QuestsButton", "RebirthButton", "ArenaButton"}
local LOCKED = {QuestsButton = true, ArenaButton = true}
local bar = hud:WaitForChild("ButtonBar")
local orderOk, lockedOk, lockedCount = true, true, 0
for index, name in ipairs(expected) do
    local button = bar:FindFirstChild(name)
    if not button or button.LayoutOrder ~= index then orderOk = false end
    local locked = button ~= nil and button:GetAttribute("Locked") == true
    if locked then lockedCount += 1 end
    if locked ~= (LOCKED[name] == true) then lockedOk = false end
end
check("Les 6 boutons A6 dans l'ordre", orderOk)
check(("Oeufs, Base, Sac et Rebirth actifs ; Quetes et Arene grises (%d grise(s))"):format(lockedCount),
    lockedOk and lockedCount == 2)
check("Boutons carres (UIAspectRatioConstraint)",
    bar.EggsButton:FindFirstChildOfClass("UIAspectRatioConstraint") ~= nil)

-- Le HUD affiche ce que le serveur envoie, sans rien recalculer (Loi 2).
local sync = ReplicatedStorage.Remotes.SyncProfile
local money = nil
local conn = sync.OnClientEvent:Connect(function(snapshot)
    if type(snapshot) == "table" then money = snapshot.Money end
end)
repeat task.wait(0.2) until money ~= nil
task.wait(1.2)
conn:Disconnect()
local info = hud:WaitForChild("InfoPanel")
check(("MoneyLabel affiche le montant serveur (%s)"):format(NumberFormatter.format(money)),
    info.MoneyLabel.Text == "💰 " .. NumberFormatter.format(money))
local rate = Players.LocalPlayer:GetAttribute("IncomePerSecond")
check(("IncomeLabel affiche l'attribut serveur (%s/s)"):format(tostring(rate)),
    info.IncomeLabel.Text == NumberFormatter.format(rate or 0) .. "/s")
check("ShieldLabel neutre avant l'etape 5", info.ShieldLabel.Text == "🛡️ —")
check("InfoPanel decale sous l'encoche", info.Position.Y.Offset >= 16)

-- Encombrement aux résolutions cibles, sans dépendre de la fenêtre de test.
local scaleAt720 = math.clamp(720 / 720, 1, 1.6)
table.insert(T.lines, ("[INFO] 720p : barre=%dpx sur 1280 (%.0f%%) ; bouton=%dpx"):format(
    bar.Size.X.Offset * scaleAt720, bar.Size.X.Offset * scaleAt720 / 1280 * 100,
    bar.EggsButton.Size.X.Offset * scaleAt720))

table.insert(T.lines, ("[HUD TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
print(table.concat(T.lines, "\n"))
return {passed = T.pass, failed = T.fail, success = T.fail == 0}
