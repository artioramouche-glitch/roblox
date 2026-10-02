--!nonstrict
--[[ TestCombatConfig
     Rôle    : vérifier CombatConfig (G5.3, recopié tel quel) contre E3, E5, B0bis, B3 et les fiches B5/B6.
     Doc     : GAME_MASTER_V2 G5.3, E3, E5, E11, B0bis, B3, B5, B6 ; PROMPT_EXECUTION_SABL_V4 §25.2 (lot COMBAT),
               §31.13 lot A
     Étape   : 13, lot A (configuration)
     Dépend  : ReplicatedStorage.Config.CombatConfig, CreatureConfig
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : ne prouve que la configuration ; la boucle 10 Hz, les jauges et les dégâts se testent en Play avec
               CombatService. Les capacités attendues sont relevées dans les fiches B5/B6, pas dans G5.3.
]]
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local Cb = require(assert(config:FindFirstChild("CombatConfig"), "CombatConfig absent"))
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- E3, recopié ici.
check("E3 : attaque toutes les 1,5 s, ±10 %, type ±20 %", Cb.AutoAttackInterval == 1.5 and Cb.Variance == 0.10
    and Cb.TypeBonus == 0.20)
check("E3 : jauge 8 s, switch 5 s, banc +2 %/s", Cb.AbilityChargeTime == 8 and Cb.SwitchCooldown == 5
    and Cb.BenchRegen == 0.02)
check("E3 : foule +4 % porté, +2 % encaissé", Cb.CrowdPerHitDealt == 0.04 and Cb.CrowdPerHitTaken == 0.02)
check("E3 / E5 : ultime ×3, timeout 90 s, 0,5 s d'invulnérabilité", Cb.UltimateMultiplier == 3
    and Cb.MatchTimeout == 90 and Cb.InvulnAfterSwitch == 0.5)
-- B0bis : SALÉ bat SUCRÉ, SUCRÉ bat FRUITÉ, FRUITÉ bat SALÉ.
check("B0bis : triangle des types", Cb.TypeCycle.Salty == "Sweet" and Cb.TypeCycle.Sweet == "Fruity"
    and Cb.TypeCycle.Fruity == "Salty")
-- E5 : SALÉ −25 % ATK 5 s ; SUCRÉ soin 30 % de l'équipe ; FRUITÉ étourdit 2,5 s.
local u = Cb.UltimateBonus
check("E5 : bonus d'ultime par type", u.Salty.atkDown == 0.25 and u.Salty.duration == 5 and u.Sweet.healTeam == 0.30
    and u.Fruity.stun == 2.5)
-- E11.1 / B3 : en classé, les tiers sont aplatis de ×1 à ×1,6.
local flat = {1, 1.15, 1.30, 1.45, 1.60}
local flatOk = true
for tier, mult in ipairs(flat) do flatOk = flatOk and C.Tiers[tier].PvpMult == mult end
check("B3 / E11.1 : tiers classés ×1 → ×1,6", flatOk)

-- Fiches B5/B6 : {nom, type, puissance, cooldown en plus}.
local EXPECTED = {
    noobini = {"Pizza Slash", "Burst", 3, 0},
    tim_cheese = {"Cheese Melt", "Heal", 0.4, 0},
    fluriflura = {"Pollen Dodo", "Control", 2, 0},
    pipi_kiwi = {"Kiwi Splash", "Burst", 3, 0},
    talpa = {"Tunnel Trap", "Control", 2, 0},
    trippi = {"Shrimp Punch", "Burst", 3, 0},
    tung_tung = {"Bam Bam Bam", "Burst", 3, 0},
    boneca = {"Tire Bounce", "Shield", 2, 0},
    footera = {"Drive-By", "Burst", 3, 0},
    chim_banana = {"Banana Split", "Heal", 0.4, 0},
    cappuccino = {"Espresso Rush", "Burst", 3, 0},
    patapim = {"Brr Frost", "Control", 2, 0},
    blueberrini = {"Ink Blast", "Burst", 3, 0},
    strawberelli = {"Flambée", "Burst", 3, 0},
    burbaloni = {"Loli Lasso", "Control", 2, 0},
    bombombini = {"Bomb Barrage", "Burst", 3.5, 2},
    frigo_camelo = {"Frigorification", "Control", 2.5, 0},
    tukanno = {"Beak Barrage", "Burst", 3, 0},
    bombardiro = {"Bombardement", "Burst", 4, 2},
    lirili = {"Cactus Spikes", "Shield", 2, 0},
    glorbo = {"Juice Flood", "Heal", 0.4, 0},
    gorillo = {"Melon Slam", "Burst", 3.5, 0},
    tralalero = {"TRALALERO !", "Burst", 4, 0},
    vaca = {"Saturn Rings", "Shield", 3, 0},
    sammyni = {"Spider Web", "Control", 2.5, 0},
    girafa = {"Neck Whip", "Burst", 3.5, 0},
    los_tralaleritos = {"Chorus Attack", "Burst", 4.5, 3},
    chicleteira = {"Gum Trap", "Control", 3, 0},
    la_grande = {"La Combinazione", "Heal", 0.5, 0},
    garama = {"Madundung Quake", "Burst", 5, 4},
    biscottino = {"Grand Jeté", "Burst", 3, 0},
    gelato_gangsterino = {"Cold Deal", "Control", 2, 0},
    tiramisu_tornado = {"Tempête de Cacao", "Burst", 3, 0},
    macaroni_mago = {"Abracadolce", "Control", 2, 0},
    donut_drago = {"Souffle Sucre", "Burst", 3.5, 0},
    croissant_crusherino = {"Croque Suprême", "Burst", 3.5, 0},
    gateau_guardiano = {"Mur de Crème", "Shield", 3, 0},
    millefeuille_celestre = {"Feuilleton Divin", "Burst", 4.5, 3},
    onigirino_orcano = {"Orca Bite", "Burst", 3, 0},
    maki_rayona = {"Glide Sting", "Burst", 3, 0},
    nigiri_anguilla = {"Électro-Shock", "Control", 2, 0},
    tempura_titano = {"Friture Impact", "Burst", 3.5, 0},
    ramen_krakeno = {"Sauce Piquante", "Burst", 3.5, 0},
    unagi_imperatore = {"Décret Impérial", "Heal", 0.4, 0},
    wasabi_wraitho = {"Sinus Inferno", "Control", 2.5, 0},
    sushi_shogun = {"Iai Sushi", "Burst", 5, 4},
    bonbonni_bourdonna = {"Buzz Dash", "Burst", 3, 0},
    chamallow_astronauta = {"Moon Bounce", "Shield", 2, 0},
    sucetta_satellita = {"Satellite Lock", "Control", 2, 0},
    gommosa_galattica = {"Wobble Quake", "Burst", 3, 0},
    cotone_cosmico = {"Douce Nuée", "Heal", 0.5, 0},
    caramel_cometa = {"Comet Crash", "Burst", 3.5, 0},
    gravita_grandosa = {"Puits de Gravité", "Control", 2.5, 0},
    ourson_galattico = {"Calin Cosmique", "Burst", 5, 4},
}
local count, exact, kinds = 0, true, true
for id, want in pairs(EXPECTED) do
    count += 1
    local a = Cb.Abilities[id]
    local ok = a ~= nil and a.name == want[1] and a.kind == want[2] and a.power == want[3] and a.cdPlus == want[4]
    if not ok then table.insert(T.lines, "  écart : " .. id) end
    exact = exact and ok
end
local extra = 0
for id, a in pairs(Cb.Abilities) do
    if not EXPECTED[id] then extra += 1 end
    kinds = kinds and (a.kind == "Burst" and a.power >= 3 or a.kind == "Heal" and a.power > 0 and a.power <= 0.5
        or a.kind == "Shield" and (a.power == 2 or a.power == 3) or a.kind == "Control" and a.power >= 2 and a.power <= 3)
end
check(("54 capacités, nom, type, puissance et cooldown des fiches (%d attendues)"):format(count), count == 54 and exact)
check("Aucune capacité hors fiches", extra == 0)
check("Puissances dans les bornes de leur type (B5 : BURST ×3+, SOIN ≤ 50 %, BOUCLIER 2-3, CONTRÔLE 2-3 s)", kinds)
-- Effets secondaires des fiches, recopiés de G5.3.
local sideOk = Cb.Abilities.pipi_kiwi.atkDown == 0.10 and Cb.Abilities.pipi_kiwi.duration == 3
    and Cb.Abilities.cappuccino.speedUp == 0.3 and Cb.Abilities.cappuccino.duration == 5
    and Cb.Abilities.blueberrini.blind == 0.15 and Cb.Abilities.lirili.reflect == 0.25
    and Cb.Abilities.glorbo.cleanse == true and Cb.Abilities.tralalero.crowdBoost == 0.25
    and Cb.Abilities.la_grande.atkUp == 0.2 and Cb.Abilities.la_grande.duration == 5
    and Cb.Abilities.tung_tung.shake == true and Cb.Abilities.unagi_imperatore.speedUp == 0.15
    and Cb.Abilities.unagi_imperatore.duration == 4 and Cb.Abilities.tiramisu_tornado.blind == 0.15
    and Cb.Abilities.maki_rayona.atkDown == 0.10
check("Effets secondaires des fiches (ATK, vitesse, précision, renvoi, purge, foule)", sideOk)
local everyCreature = true
for _, creature in ipairs(C.Creatures) do
    everyCreature = everyCreature and Cb.Abilities[creature.id] ~= nil and Cb:GetAbility(creature.id) == Cb.Abilities[creature.id]
end
check("Chacune des 54 créatures de CreatureConfig a sa capacité", everyCreature)
local default = Cb:GetAbility("inconnu")
check("Créature inconnue : « Charge », BURST ×3", default.name == "Charge" and default.kind == "Burst"
    and default.power == 3 and default.cdPlus == 0)

local summary = ("[COMBAT CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
