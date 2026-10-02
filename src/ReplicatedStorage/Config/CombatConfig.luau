local CombatConfig = {}

CombatConfig.TypeCycle = { Salty="Sweet", Sweet="Fruity", Fruity="Salty" } -- qui bat qui
CombatConfig.TypeBonus = 0.20      -- +20% dégâts sur le type battu
CombatConfig.AutoAttackInterval = 1.5
CombatConfig.Variance = 0.10       -- ±10% dégâts
CombatConfig.AbilityChargeTime = 8      -- s pour remplir la jauge
CombatConfig.SwitchCooldown = 5
CombatConfig.BenchRegen = 0.02           -- +2%/s sur le banc
CombatConfig.CrowdPerHitDealt = 0.04     -- jauge de foule
CombatConfig.CrowdPerHitTaken = 0.02
CombatConfig.UltimateMultiplier = 3
CombatConfig.MatchTimeout = 90
CombatConfig.InvulnAfterSwitch = 0.5

-- Capacités : kind = Burst | Heal | Shield | Control
-- power : Burst = mult dégâts | Heal = %HP | Shield = nb coups | Control = durée stun
-- cdPlus : cooldown additionnel
CombatConfig.Abilities = {
    -- Monde 1
    noobini={name="Pizza Slash",kind="Burst",power=3,cdPlus=0},
    tim_cheese={name="Cheese Melt",kind="Heal",power=0.4,cdPlus=0},
    fluriflura={name="Pollen Dodo",kind="Control",power=2,cdPlus=0},
    pipi_kiwi={name="Kiwi Splash",kind="Burst",power=3,cdPlus=0,atkDown=0.10,duration=3},
    talpa={name="Tunnel Trap",kind="Control",power=2,cdPlus=0},
    trippi={name="Shrimp Punch",kind="Burst",power=3,cdPlus=0},
    tung_tung={name="Bam Bam Bam",kind="Burst",power=3,cdPlus=0,shake=true},
    boneca={name="Tire Bounce",kind="Shield",power=2,cdPlus=0},
    footera={name="Drive-By",kind="Burst",power=3,cdPlus=0},
    chim_banana={name="Banana Split",kind="Heal",power=0.4,cdPlus=0},
    cappuccino={name="Espresso Rush",kind="Burst",power=3,cdPlus=0,speedUp=0.3,duration=5},
    patapim={name="Brr Frost",kind="Control",power=2,cdPlus=0},
    blueberrini={name="Ink Blast",kind="Burst",power=3,cdPlus=0,blind=0.15,duration=3},
    strawberelli={name="Flambée",kind="Burst",power=3,cdPlus=0},
    burbaloni={name="Loli Lasso",kind="Control",power=2,cdPlus=0},
    bombombini={name="Bomb Barrage",kind="Burst",power=3.5,cdPlus=2},
    frigo_camelo={name="Frigorification",kind="Control",power=2.5,cdPlus=0},
    tukanno={name="Beak Barrage",kind="Burst",power=3,cdPlus=0},
    bombardiro={name="Bombardement",kind="Burst",power=4,cdPlus=2},
    lirili={name="Cactus Spikes",kind="Shield",power=2,cdPlus=0,reflect=0.25,duration=5},
    glorbo={name="Juice Flood",kind="Heal",power=0.4,cdPlus=0,cleanse=true},
    gorillo={name="Melon Slam",kind="Burst",power=3.5,cdPlus=0},
    tralalero={name="TRALALERO !",kind="Burst",power=4,cdPlus=0,crowdBoost=0.25},
    vaca={name="Saturn Rings",kind="Shield",power=3,cdPlus=0},
    sammyni={name="Spider Web",kind="Control",power=2.5,cdPlus=0},
    girafa={name="Neck Whip",kind="Burst",power=3.5,cdPlus=0},
    los_tralaleritos={name="Chorus Attack",kind="Burst",power=4.5,cdPlus=3},
    chicleteira={name="Gum Trap",kind="Control",power=3,cdPlus=0},
    la_grande={name="La Combinazione",kind="Heal",power=0.5,cdPlus=0,atkUp=0.2,duration=5},
    garama={name="Madundung Quake",kind="Burst",power=5,cdPlus=4},
    -- Monde 2
    biscottino={name="Grand Jeté",kind="Burst",power=3,cdPlus=0},
    gelato_gangsterino={name="Cold Deal",kind="Control",power=2,cdPlus=0},
    tiramisu_tornado={name="Tempête de Cacao",kind="Burst",power=3,cdPlus=0,blind=0.15,duration=3},
    macaroni_mago={name="Abracadolce",kind="Control",power=2,cdPlus=0},
    donut_drago={name="Souffle Sucre",kind="Burst",power=3.5,cdPlus=0},
    croissant_crusherino={name="Croque Suprême",kind="Burst",power=3.5,cdPlus=0},
    gateau_guardiano={name="Mur de Crème",kind="Shield",power=3,cdPlus=0},
    millefeuille_celestre={name="Feuilleton Divin",kind="Burst",power=4.5,cdPlus=3},
    -- Monde 3
    onigirino_orcano={name="Orca Bite",kind="Burst",power=3,cdPlus=0},
    maki_rayona={name="Glide Sting",kind="Burst",power=3,cdPlus=0,atkDown=0.10,duration=3},
    nigiri_anguilla={name="Électro-Shock",kind="Control",power=2,cdPlus=0},
    tempura_titano={name="Friture Impact",kind="Burst",power=3.5,cdPlus=0},
    ramen_krakeno={name="Sauce Piquante",kind="Burst",power=3.5,cdPlus=0},
    unagi_imperatore={name="Décret Impérial",kind="Heal",power=0.4,cdPlus=0,speedUp=0.15,duration=4},
    wasabi_wraitho={name="Sinus Inferno",kind="Control",power=2.5,cdPlus=0},
    sushi_shogun={name="Iai Sushi",kind="Burst",power=5,cdPlus=4},
    -- Monde 4
    bonbonni_bourdonna={name="Buzz Dash",kind="Burst",power=3,cdPlus=0},
    chamallow_astronauta={name="Moon Bounce",kind="Shield",power=2,cdPlus=0},
    sucetta_satellita={name="Satellite Lock",kind="Control",power=2,cdPlus=0},
    gommosa_galattica={name="Wobble Quake",kind="Burst",power=3,cdPlus=0},
    cotone_cosmico={name="Douce Nuée",kind="Heal",power=0.5,cdPlus=0},
    caramel_cometa={name="Comet Crash",kind="Burst",power=3.5,cdPlus=0},
    gravita_grandosa={name="Puits de Gravité",kind="Control",power=2.5,cdPlus=0},
    ourson_galattico={name="Calin Cosmique",kind="Burst",power=5,cdPlus=4},
}

-- Ultime : type → effet bonus
CombatConfig.UltimateBonus = {
    Salty = {atkDown=0.25, duration=5},
    Sweet = {healTeam=0.30},
    Fruity= {stun=2.5},
}

function CombatConfig:GetAbility(creatureId)
    return self.Abilities[creatureId] or {name="Charge",kind="Burst",power=3,cdPlus=0}
end
return CombatConfig
