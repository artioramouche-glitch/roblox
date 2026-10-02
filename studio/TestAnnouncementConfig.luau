--!nonstrict
--[[ TestAnnouncementConfig
     Rôle    : vérifier les annonces (Secret, vol réussi) et la liste du Musée des Secrets.
     Doc     : GAME_MASTER_V2 A7, D1.3 Z5 ; PROMPT_EXECUTION_SABL_V4 §31.12 lots A et D ; Q4-Q5 de l'étape 12
     Étape   : 12, lots A et D (configuration)
     Dépend  : ReplicatedStorage.Config.AnnouncementConfig
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : ne prouve que la configuration ; la bannière, le sting, la secousse et les socles se testent en Play.
]]
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local A = require(assert(config:FindFirstChild("AnnouncementConfig"), "AnnouncementConfig absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- A7 et Q4, recopiés ici.
local secret, steal = A.Kinds.Secret, A.Kinds.Steal
local count = 0
for _ in pairs(A.Kinds) do count += 1 end
check("Q4 : 2 annonces seulement (Secret, vol)", count == 2 and secret ~= nil and steal ~= nil)
check("A7 : Secret = grande bannière, 1 s de silence, sting, secousse", secret.Banner == "Big"
    and secret.SilenceSeconds == 1 and secret.Sting == true and secret.ScreenShake == true)
check("Q4 : vol = bandeau simple, sans son ni secousse", steal.Banner == "Small" and steal.SilenceSeconds == 0
    and steal.Sting == false and steal.ScreenShake == false)
check("Texte du Secret", A.Format("Secret", {player = "Léa", creature = "Garama and Madundung"})
    == "🌟 Léa a obtenu un SECRET : Garama and Madundung !")
check("Texte du vol", A.Format("Steal", {thief = "Tom", creature = "Tung Tung Tung Sahur", victim = "Léa"})
    == "Tom a volé Tung Tung Tung Sahur à Léa !")
check("Champ manquant → « ? »", A.Format("Steal", {thief = "Tom"}) == "Tom a volé ? à ? !"
    and A.Format("Secret", nil) == "🌟 ? a obtenu un SECRET : ? !")
check("Pseudo avec % et accolades inséré tel quel", A.Format("Steal",
    {thief = "%1 {victim}", creature = "x%%y", victim = "Z"}) == "%1 {victim} a volé x%%y à Z !")
check("Annonce inconnue → nil", A.Format("God", {}) == nil and A.Format(nil, {}) == nil)

-- D1.3 Z5 et Q5 : 6 socles, le plus récent en premier.
check("D1.3 Z5 : 6 socles", A.MuseumSlots == 6)
check("Musée vide au démarrage", #A.MuseumPush(nil, nil) == 0)
local museum = {}
for i = 1, 8 do museum = A.MuseumPush(museum, {CreatureId = "garama", PlayerName = "P" .. i, At = i}) end
local order = {}
for _, item in ipairs(museum) do table.insert(order, item.PlayerName) end
check("8 Secrets → les 6 derniers, du plus récent au plus ancien", table.concat(order, ",") == "P8,P7,P6,P5,P4,P3")
local before = {{PlayerName = "A"}, {PlayerName = "B"}}
local after = A.MuseumPush(before, {PlayerName = "C"})
check("La liste d'origine n'est pas modifiée", #before == 2 and before[1].PlayerName == "A" and #after == 3
    and after[1].PlayerName == "C")
check("Entrée invalide ignorée", #A.MuseumPush(before, "garama") == 2 and #A.MuseumPush(before, nil) == 2)
check("Configuration gelée", table.isfrozen(A.Kinds) and table.isfrozen(secret))

local summary = ("[ANNOUNCEMENT CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
