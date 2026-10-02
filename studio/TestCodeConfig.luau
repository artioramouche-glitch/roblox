--!nonstrict
--[[ TestCodeConfig
     Rôle    : vérifier les 5 codes de lancement I3 et la règle « valide, une seule fois par compte ».
     Doc     : GAME_MASTER_V2 I3, G4, G2 ; PROMPT_EXECUTION_SABL_V4 §18.2-§18.4, §31.18 lot C
     Étape   : 18, lot C (configuration)
     Dépend  : ReplicatedStorage.Config.CodeConfig, EggConfig, CreatureConfig, MonetizationConfig, DefaultProfile
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : ne prouve que la configuration ; le remote RedeemCode, le versement et la persistance se testent en
               Play.
]]
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local K = require(assert(config:FindFirstChild("CodeConfig"), "CodeConfig absent"))
local E = require(assert(config:FindFirstChild("EggConfig"), "EggConfig absent"))
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
local M = require(assert(config:FindFirstChild("MonetizationConfig"), "MonetizationConfig absent"))
local P = require(assert(config:FindFirstChild("DefaultProfile"), "DefaultProfile absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- I3, recopié ici.
local n = 0
for _ in pairs(K.Codes) do n += 1 end
check("I3 : 5 codes exactement", n == 5)
check("RELEASE : 10 000 💰", K.Codes.RELEASE.Money == 10000)
check("TUNGXTUNG : 1 egg_street", K.Codes.TUNGXTUNG.Eggs.egg_street == 1 and E:Get("egg_street") ~= nil)
check("LEGENDS : 30 min de revenus ×2 (boost de la roulette)", K.Codes.LEGENDS.Boost == "Income"
    and K.Codes.LEGENDS.Seconds == 1800 and M.Boosts.Income.Mult == 2)
check("COLISEE : 150 tokens arène", K.Codes.COLISEE.ArenaTokens == 150)
check("FAMILY : 1 Rare garanti du monde 1 + pose de clan 24 h", K.Codes.FAMILY.Rarity == "Rare"
    and K.Codes.FAMILY.World == 1 and K.Codes.FAMILY.ClanPoseSeconds == 86400 and C:GetRarity("Rare") ~= nil)
local noSecret = true
for _, reward in pairs(K.Codes) do noSecret = noSecret and reward.Rarity ~= "Secret" and reward.ATK == nil end
check("Aucun code ne donne de Secret ni de stat de combat", noSecret)

-- Saisie.
check("Saisie sans casse ni espaces autour", K.Normalize("  legends ") == "LEGENDS" and K.Get("Release") == K.Codes.RELEASE
    and K.Get("tungXtung") == K.Codes.TUNGXTUNG)
check("§18.4 : vide, trop long, géant ou pas un texte → refusé", K.Normalize("") == nil and K.Normalize("   ") == nil
    and K.Normalize(string.rep("A", 33)) == nil and K.Normalize(string.rep("A", 100000)) == nil
    and K.Normalize(nil) == nil and K.Normalize(12) == nil and K.Normalize({}) == nil)
check("Un espace au milieu n'est pas retiré", K.Get("LEG ENDS") == nil)

-- §18.2 / §18.3 : valide, une seule fois par compte.
check("G2 : Profile.Codes existe et commence vide", type(P.Codes) == "table" and next(P.Codes) == nil)
local ok1, code1 = K.Check({}, "release")
check("Premier usage → accepté, code normalisé", ok1 == true and code1 == "RELEASE")
local ok2, why2 = K.Check({RELEASE = 1790899200}, " Release")
check("Deuxième usage → CODE_USED", ok2 == false and why2 == "CODE_USED")
local ok3, why3 = K.Check({}, "SECRET")
check("Code inconnu → CODE_INVALID", ok3 == false and why3 == "CODE_INVALID")
local ok4, why4 = K.Check(nil, string.rep("Z", 50000))
check("Saisie géante → CODE_INVALID", ok4 == false and why4 == "CODE_INVALID")
local ok5 = K.Check({LEGENDS = 1}, "COLISEE")
check("Un code déjà utilisé n'empêche pas les autres", ok5 == true)
check("Configuration gelée", table.isfrozen(K.Codes) and table.isfrozen(K.Codes.FAMILY))

local summary = ("[CODE CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
