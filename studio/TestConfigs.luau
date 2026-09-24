--!nonstrict
--[[ TestConfigs
     Rôle    : vérifier les configurations et signaler toute rareté sans candidat.
     Doc     : GAME_MASTER_V2 B1, B2, B4, G5.1, G5.2
     Étape   : 2, lot A
     Dépend  : ReplicatedStorage.Config.CreatureConfig et EggConfig
     Exposé  : exécution manuelle ; aucune écriture de données
]]
local config = game:GetService("ReplicatedStorage"):FindFirstChild("Config")
assert(config, "Config absent")
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
local E = require(assert(config:FindFirstChild("EggConfig"), "EggConfig absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
check("54 creatures", #C.Creatures == 54)
check("8 eggs", #E.Eggs == 8)
local ids, worlds, valid = {}, {}, true
for _, creature in ipairs(C.Creatures) do
    local rarity = C:GetRarity(creature.rarity)
    valid = valid and type(creature.id) == "string" and not ids[creature.id]
        and rarity ~= nil and C.Worlds[creature.world] ~= nil
        and type(creature.income) == "number" and creature.income > 0
        and (creature.ptype == "Salty" or creature.ptype == "Sweet" or creature.ptype == "Fruity")
        and C:Get(creature.id) == creature
    ids[creature.id] = true
    worlds[creature.world] = (worlds[creature.world] or 0) + 1
end
check("Creature IDs, references, income and types valid", valid)
for world, count in ipairs({30, 8, 8, 8}) do
    check("World" .. world .. " count=" .. count, worlds[world] == count)
end
-- Référence B2/G5.2, avec uniquement les cinq ajouts de pools validés par le Producer.
-- Les valeurs attendues ne sont jamais déduites de la configuration testée.
local expectedEggs = {
    egg_basic = {price=100, world=1, odds={Common=85,Rare=15},
        pool={"noobini","tim_cheese","fluriflura","pipi_kiwi","talpa","trippi"}},
    egg_street = {price=8500, world=1, odds={Common=10,Rare=55,Epic=33,Legendary=2},
        pool={"noobini","trippi","tung_tung","boneca","footera","chim_banana","cappuccino","patapim","burbaloni"}},
    egg_golden = {price=150000, world=1, odds={Rare=20,Epic=55,Legendary=22,Mythic=3},
        pool={"chim_banana","cappuccino","patapim","blueberrini","strawberelli","burbaloni","bombombini","frigo_camelo","tukanno","bombardiro"}},
    egg_mythic = {price=5000000, world=1, odds={Epic=25,Legendary=50,Mythic=22,God=3},
        pool={"burbaloni","bombombini","frigo_camelo","tukanno","bombardiro","lirili","glorbo","gorillo","cappuccino","tralalero"}},
    egg_secret = {price=250000000, world=1, odds={Legendary=30,Mythic=35,God=34.5,Secret=0.5},
        pool={"gorillo","tralalero","vaca","sammyni","girafa","los_tralaleritos","chicleteira","la_grande","garama","burbaloni"}},
    egg_dessert = {price=25000000, world=2, odds={Rare=55,Epic=33,Legendary=10,Mythic=1.9,Secret=0.1},
        pool={"biscottino","gelato_gangsterino","tiramisu_tornado","macaroni_mago","donut_drago","croissant_crusherino","gateau_guardiano","millefeuille_celestre"}},
    egg_abyss = {price=2000000000, world=3, odds={Rare=55,Epic=33,Legendary=10,Mythic=1.9,Secret=0.1},
        pool={"onigirino_orcano","maki_rayona","nigiri_anguilla","tempura_titano","ramen_krakeno","unagi_imperatore","wasabi_wraitho","sushi_shogun"}},
    egg_cosmic = {price=200000000000, world=4, odds={Rare=55,Epic=33,Legendary=10,Mythic=1.9,Secret=0.1},
        pool={"bonbonni_bourdonna","chamallow_astronauta","sucetta_satellita","gommosa_galattica","cotone_cosmico","caramel_cometa","gravita_grandosa","ourson_galattico"}},
}
local function sameValues(actual, expected)
    if type(actual) ~= type(expected) then return false end
    if type(actual) ~= "table" then return actual == expected end
    for key, value in pairs(expected) do
        if not sameValues(actual[key], value) then return false end
    end
    for key in pairs(actual) do if expected[key] == nil then return false end end
    return true
end
local eggIds = {}
for _, egg in ipairs(E.Eggs) do
    local poolIds, available, references = {}, {}, true
    for _, id in ipairs(egg.pool) do
        local creature = C:Get(id)
        if not creature or poolIds[id] then
            references = false
        else
            available[creature.rarity] = true
            references = references and creature.world == egg.world
        end
        poolIds[id] = true
    end
    check(egg.id .. " unique ID, price and pool references", references and #egg.pool > 0
        and not eggIds[egg.id] and E:Get(egg.id) == egg
        and type(egg.price) == "number" and egg.price > 0)
    eggIds[egg.id] = true
    local sum, weightsValid, missing = 0, true, {}
    for rarity, weight in pairs(egg.odds) do
        if type(weight) ~= "number" or weight ~= weight or weight < 0 or weight == math.huge then
            weightsValid = false
        else
            sum += weight
            weightsValid = weightsValid and C:GetRarity(rarity) ~= nil
            if weight > 0 and not available[rarity] then table.insert(missing, rarity) end
        end
    end
    check(egg.id .. " odds sum=100", weightsValid and math.abs(sum - 100) < 0.000001)
    table.sort(missing)
    check(egg.id .. " rarity coverage" .. (#missing > 0 and ("; missing=" .. table.concat(missing, ",")) or ""), #missing == 0)
    local expected = expectedEggs[egg.id]
    check(egg.id .. " price and world unchanged", expected ~= nil
        and egg.price == expected.price and egg.world == expected.world)
    check(egg.id .. " exact odds unchanged", expected ~= nil and sameValues(egg.odds, expected.odds))
    check(egg.id .. " exact approved pool", expected ~= nil and sameValues(egg.pool, expected.pool))
end
local tung = C:GetCombatStats("tung_tung", 4, true)
check("Ranked Tung tier4 HP=725 ATK=58", tung and tung.HP == 725 and tung.ATK == 58)
local tralalero = C:GetCombatStats("tralalero", 5, true)
check("Ranked Tralalero tier5 HP=6400 ATK=448", tralalero and tralalero.HP == 6400 and tralalero.ATK == 448)
local summary = ("[CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
-- Les échecs connus restent des échecs, jamais des exceptions de test.
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
