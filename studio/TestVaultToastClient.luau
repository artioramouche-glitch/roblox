--!nonstrict
--[[ TestVaultToastClient
     Rôle    : vérifier le bandeau du coffre-fort au retour : texte, montant égal au versement du serveur, lisibilité.
     Doc     : GAME_MASTER_V2 A5, G1 (NotificationController) ; PROMPT_EXECUTION_SABL_V4 §20 ; décision 44
     Étape   : 9, lot F1 ; coffre plein au lot F2
     Dépend  : Play en cours, datamodel Client, lancé après une absence avec un coffre au niveau 1 ou plus ;
               Controllers.NotificationController démarré ; attributs joueur VaultOfflineIncome,
               VaultOfflineSeconds et VaultOfflineFull publiés par VaultService
     Exposé  : texte de bilan ; exécuté tel quel par l'outil dans le datamodel Client, car l'outil ne peut pas
               require. Le cas « coffre plein » est simulé en local sur le client (rien n'est envoyé au
               serveur), puis les attributs d'origine sont rétablis
     Limite  : le label garde son texte une fois le bandeau masqué, ce qui permet de le lire après coup.
               NumberFormatter.format est recopié ici.
]]
local Players = game:GetService("Players")

local MIN_TEXT = 16 -- §20.1
-- Shared.NumberFormatter, recopié tel quel (§16.9).
local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
local function format(n)
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

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local player = Players.LocalPlayer
local gain, seconds = player:GetAttribute("VaultOfflineIncome"), player:GetAttribute("VaultOfflineSeconds")
check(("Decision 44 : versement publie par le serveur, %s pour %s s d'absence couverte"):format(tostring(gain),
    tostring(seconds)), type(gain) == "number" and gain > 0 and type(seconds) == "number" and seconds > 0)
local screen = player:WaitForChild("PlayerGui"):WaitForChild("Notifications")
local toast = screen:WaitForChild("Toast")
local label = toast:WaitForChild("ToastLabel")
local text = label.Text
check(("Bandeau : « %s »"):format(text), type(gain) == "number" and text:find("Coffre-fort", 1, true) ~= nil
    and text:find(("+%s 💰"):format(format(gain)), 1, true) ~= nil)
check(("§20.1 : texte de %d px ; le bandeau ne retient aucun clic"):format(label.TextSize),
    label.TextSize >= MIN_TEXT and toast.Active == false)

-- Coffre plein (lot F2) : simulé en local, le serveur n'en sait rien ; les attributs d'origine sont rétablis.
local full = player:GetAttribute("VaultOfflineFull")
player:SetAttribute("VaultOfflineFull", true)
player:SetAttribute("VaultOfflineSeconds", 3600)
player:SetAttribute("VaultOfflineIncome", 50000)
task.wait(0.2)
local fullText = label.Text
player:SetAttribute("VaultOfflineFull", full)
player:SetAttribute("VaultOfflineSeconds", seconds)
player:SetAttribute("VaultOfflineIncome", gain)
check(("Coffre plein (simulation locale) : « %s »"):format(fullText),
    fullText:find("Coffre-fort plein", 1, true) ~= nil and fullText:find("+50.0K 💰", 1, true) ~= nil
    and fullText:find("1 h 00", 1, true) ~= nil and fullText:find("améliore-le", 1, true) ~= nil)

table.insert(T.lines, ("[VAULT TOAST CLIENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
