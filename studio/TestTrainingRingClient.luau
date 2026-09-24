--!nonstrict
--[[ TestTrainingRingClient
     Rôle    : vérifier l'affichage de l'anneau : stats PvP de l'inventaire identiques au calcul serveur, anneau
               compris, et effet de l'anneau lisible sur l'écran de base et au choix du tri PvP.
     Doc     : GAME_MASTER_V2 A5, A6 §3-4, B4 ; PROMPT_EXECUTION_SABL_V4 §20, §31.9 lot D
     Étape   : 9, lot D
     Dépend  : Play en cours, datamodel Client ; Controllers.InventoryController démarré ; attribut Workspace
               SABL_ExpectedPvp publié juste avant par la batterie serveur TestTrainingRing (runner) ;
               inventaire ouvert puis trié par un clic sur Inventory.Panel.SortBar.SortPvpButton (outil de souris)
     Exposé  : texte de bilan ; exécuté tel quel par l'outil dans le datamodel Client, car l'outil ne peut pas
               require. Lecture seule : rien n'est acheté ni déplacé
     Limite  : compare au calcul du serveur plutôt qu'à des chiffres recopiés, faute de require côté outil.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local raw = Workspace:GetAttribute("SABL_ExpectedPvp")
local decoded, expected = pcall(function() return HttpService:JSONDecode(raw) end)
if not decoded or type(expected) ~= "table" or type(expected.Stats) ~= "table" then expected = {Ring = -1, Stats = {}} end
local wanted = 0
for _ in pairs(expected.Stats) do wanted += 1 end
check(("Attendus publies par la batterie serveur : %d brainrots, anneau +%d %%"):format(wanted, expected.Ring),
    decoded and wanted > 0 and expected.Ring >= 0)

local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
local panel = gui:WaitForChild("Inventory").Panel
local cards, formatted, matched, wrong = 0, 0, 0, {}
for _, card in ipairs(panel.Grid:GetChildren()) do
    if card:IsA("Frame") and card.Name:match("^Card_") then
        cards += 1
        local uid, text = card.Name:sub(6), card.StatLabel.Text
        if text:match("^%d+ PV · %d+ ATK$") then formatted += 1 end
        if expected.Stats[uid] == text then
            matched += 1
        elseif #wrong < 3 then
            table.insert(wrong, ("%s : %s au lieu de %s"):format(uid, text, tostring(expected.Stats[uid])))
        end
    end
end
check(("Tri PvP : %d cartes sur %d au format « PV · ATK »"):format(formatted, cards), cards > 0 and formatted == cards)
check(("Stats affichees = calcul serveur, anneau compris : %d/%d%s"):format(matched, wanted,
    #wrong > 0 and (" (" .. table.concat(wrong, " ; ") .. ")") or ""), matched == wanted and cards == wanted)

local status = panel.StatusLabel.Text
if expected.Ring > 0 then
    check(("Statut du tri PvP : « %s »"):format(status),
        status == ("Anneau : +%d %% PvP sur les brainrots posés"):format(expected.Ring))
else
    check("Anneau a 0 : le tri PvP n'annonce aucun bonus", status:find("Anneau", 1, true) == nil)
end

local base = gui:WaitForChild("BasePanel")
base.Enabled = true
-- Le controller redessine l'écran ouvert à chaque profil synchronisé (au moins une fois par seconde).
local deadline = os.clock() + 6
repeat task.wait(0.25) until base.Panel.ComponentList:FindFirstChild("RowTrainingRing") or os.clock() > deadline
task.wait(1.2) -- une synchronisation de plus : les lignes d'une ouverture précédente sont alors redessinées
local row = base.Panel.ComponentList:FindFirstChild("RowTrainingRing")
local label = row and row.Label.Text or ""
if expected.Ring > 0 then
    check(("Ecran de base : « %s »"):format(label),
        label:find(("+%d %% PvP des posés"):format(expected.Ring), 1, true) ~= nil)
else
    check(("Ecran de base, anneau 0 : « %s », sans bonus affiche"):format(label),
        row ~= nil and label:find("PvP", 1, true) == nil)
end
base.Enabled = false

table.insert(T.lines, ("[TRAINING RING CLIENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
