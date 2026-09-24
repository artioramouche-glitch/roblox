local CreatureConfig = {}

CreatureConfig.Rarities = {
    {Id="Common",    Name="Commun",       Color=Color3.fromRGB(170,170,170), Weight=60,   SellMult=0.4,  BaseHP=300,  BaseATK=25},
    {Id="Rare",      Name="Rare",         Color=Color3.fromRGB(85,170,255),  Weight=25,   SellMult=0.4,  BaseHP=500,  BaseATK=40},
    {Id="Epic",      Name="Épique",       Color=Color3.fromRGB(170,85,255),  Weight=10,   SellMult=0.4,  BaseHP=850,  BaseATK=65},
    {Id="Legendary", Name="Légendaire",   Color=Color3.fromRGB(255,200,50),  Weight=4,    SellMult=0.45, BaseHP=1400, BaseATK=105},
    {Id="Mythic",    Name="Mythique",     Color=Color3.fromRGB(255,85,85),   Weight=0.9,  SellMult=0.5,  BaseHP=2400, BaseATK=175},
    {Id="God",       Name="Brainrot God", Color=Color3.fromRGB(255,170,0),   Weight=0.09, SellMult=0.55, BaseHP=4000, BaseATK=280},
    {Id="Secret",    Name="SECRET",       Color=Color3.fromRGB(120,60,200),  Weight=0.01, SellMult=0.6,  BaseHP=7000, BaseATK=480},
}

CreatureConfig.Tiers = {
    [1]={Name="Normal",       Mult=1,   PvpMult=1},
    [2]={Name="Doré",         Mult=3,   PvpMult=1.15},
    [3]={Name="Arc-en-ciel",  Mult=10,  PvpMult=1.30},
    [4]={Name="Galaxie",      Mult=40,  PvpMult=1.45},
    [5]={Name="Céleste",      Mult=150, PvpMult=1.60},
}

-- WorldMult appliqué aux stats PvP : M1=1, M2=2.5, M3=6, M4=15
CreatureConfig.Worlds = {
    [1]={Name="Brainrot Street",  Mult=1},
    [2]={Name="Dessert Kingdom",  Mult=2.5},
    [3]={Name="Sushi Abyss",      Mult=6},
    [4]={Name="Candy Space",      Mult=15},
}

CreatureConfig.Creatures = {
    -- MONDE 1 — BRAINROT STREET
    {id="noobini",           name="Noobini Pizzanini",        rarity="Common",    income=10,      world=1, ptype="Salty"},
    {id="tim_cheese",        name="Tim Cheese",               rarity="Common",    income=12,      world=1, ptype="Salty"},
    {id="fluriflura",        name="FluriFlura",               rarity="Common",    income=15,      world=1, ptype="Fruity"},
    {id="pipi_kiwi",         name="Pipi Kiwi",                rarity="Common",    income=18,      world=1, ptype="Fruity"},
    {id="talpa",             name="Talpa Di Fero",            rarity="Common",    income=22,      world=1, ptype="Salty"},
    {id="trippi",            name="Trippi Troppi",            rarity="Rare",      income=65,      world=1, ptype="Salty"},
    {id="tung_tung",         name="Tung Tung Tung Sahur",     rarity="Rare",      income=80,      world=1, ptype="Salty"},
    {id="boneca",            name="Boneca Ambalabu",          rarity="Rare",      income=95,      world=1, ptype="Salty"},
    {id="footera",           name="Gangster Footera",         rarity="Rare",      income=110,     world=1, ptype="Salty"},
    {id="chim_banana",       name="Chimpanzini Bananini",     rarity="Rare",      income=130,     world=1, ptype="Fruity"},
    {id="cappuccino",        name="Cappuccino Assassino",     rarity="Epic",      income=400,     world=1, ptype="Salty"},
    {id="patapim",           name="Brr Brr Patapim",          rarity="Epic",      income=480,     world=1, ptype="Fruity"},
    {id="blueberrini",       name="Blueberrinni Octopusini",  rarity="Epic",      income=550,     world=1, ptype="Fruity"},
    {id="strawberelli",      name="Strawberelli Flamingelli", rarity="Epic",      income=620,     world=1, ptype="Fruity"},
    {id="burbaloni",         name="Burbaloni Loliloli",       rarity="Legendary", income=2500,    world=1, ptype="Salty"},
    {id="bombombini",        name="Bombombini Gusini",        rarity="Legendary", income=3000,    world=1, ptype="Salty"},
    {id="frigo_camelo",      name="Frigo Camelo",             rarity="Legendary", income=3600,    world=1, ptype="Salty"},
    {id="tukanno",           name="Tukanno Bananno",          rarity="Legendary", income=4200,    world=1, ptype="Fruity"},
    {id="bombardiro",        name="Bombardiro Crocodilo",     rarity="Mythic",    income=15000,   world=1, ptype="Salty"},
    {id="lirili",            name="Lirili Larila",            rarity="Mythic",    income=18000,   world=1, ptype="Fruity"},
    {id="glorbo",            name="Glorbo Fruttodrillo",      rarity="Mythic",    income=22000,   world=1, ptype="Fruity"},
    {id="gorillo",           name="Gorillo Watermelondrillo", rarity="Mythic",    income=26000,   world=1, ptype="Fruity"},
    {id="tralalero",         name="Tralalero Tralala",        rarity="God",       income=90000,   world=1, ptype="Salty"},
    {id="vaca",              name="La Vaca Saturno Saturnita",rarity="God",       income=110000,  world=1, ptype="Salty"},
    {id="sammyni",           name="Sammyni Spyderini",        rarity="God",       income=130000,  world=1, ptype="Salty"},
    {id="girafa",            name="Girafa Celestre",          rarity="God",       income=150000,  world=1, ptype="Fruity"},
    {id="los_tralaleritos",  name="Los Tralaleritos",         rarity="Secret",    income=600000,  world=1, ptype="Salty"},
    {id="chicleteira",       name="Chicleteira Bicicleteira", rarity="Secret",    income=800000,  world=1, ptype="Sweet"},
    {id="la_grande",         name="La Grande Combinazione",   rarity="Secret",    income=1000000, world=1, ptype="Salty"},
    {id="garama",            name="Garama and Madundung",     rarity="Secret",    income=1500000, world=1, ptype="Salty"},
    -- MONDE 2 — DESSERT KINGDOM
    {id="biscottino",          name="Biscottino Ballerino",       rarity="Rare",      income=8000,     world=2, ptype="Sweet"},
    {id="gelato_gangsterino",  name="Gelato Gangsterino",         rarity="Rare",      income=12000,    world=2, ptype="Sweet"},
    {id="tiramisu_tornado",    name="Tiramisù Tornado",           rarity="Epic",      income=30000,    world=2, ptype="Sweet"},
    {id="macaroni_mago",       name="Macaroni Mago",              rarity="Epic",      income=45000,    world=2, ptype="Sweet"},
    {id="donut_drago",         name="Donut Drago",                rarity="Legendary", income=150000,   world=2, ptype="Sweet"},
    {id="croissant_crusherino",name="Croissant Crusherino",       rarity="Legendary", income=220000,   world=2, ptype="Sweet"},
    {id="gateau_guardiano",    name="Gateau Guardiano",           rarity="Mythic",    income=900000,   world=2, ptype="Sweet"},
    {id="millefeuille_celestre",name="Millefeuille Célestre",     rarity="Secret",    income=6000000,  world=2, ptype="Sweet"},
    -- MONDE 3 — SUSHI ABYSS
    {id="onigirino_orcano",  name="Onigirino Orcano",           rarity="Rare",      income=150000,   world=3, ptype="Salty"},
    {id="maki_rayona",       name="Maki Rayona",                rarity="Rare",      income=220000,   world=3, ptype="Fruity"},
    {id="nigiri_anguilla",   name="Nigiri Anguilla",            rarity="Epic",      income=500000,   world=3, ptype="Salty"},
    {id="tempura_titano",    name="Tempura Titano",             rarity="Epic",      income=750000,   world=3, ptype="Salty"},
    {id="ramen_krakeno",     name="Ramen Krakeno",              rarity="Legendary", income=2500000,  world=3, ptype="Salty"},
    {id="unagi_imperatore",  name="Unagi Imperatore",           rarity="Legendary", income=4000000,  world=3, ptype="Salty"},
    {id="wasabi_wraitho",    name="Wasabi Wraitho",             rarity="Mythic",    income=15000000, world=3, ptype="Salty"},
    {id="sushi_shogun",      name="Sushi Shogun Supremo",       rarity="Secret",    income=80000000, world=3, ptype="Salty"},
    -- MONDE 4 — CANDY SPACE
    {id="bonbonni_bourdonna",  name="Bonbonni Bourdonna",        rarity="Rare",      income=3000000,   world=4, ptype="Sweet"},
    {id="chamallow_astronauta",name="Chamallow Astronauta",      rarity="Rare",      income=5000000,   world=4, ptype="Sweet"},
    {id="sucetta_satellita",   name="Sucetta Satellita",         rarity="Epic",      income=12000000,  world=4, ptype="Sweet"},
    {id="gommosa_galattica",   name="Gommosa Galattica",         rarity="Epic",      income=20000000,  world=4, ptype="Sweet"},
    {id="cotone_cosmico",      name="Cotone Cosmico",            rarity="Legendary", income=60000000,  world=4, ptype="Sweet"},
    {id="caramel_cometa",      name="Caramel Cometa",            rarity="Legendary", income=100000000, world=4, ptype="Fruity"},
    {id="gravita_grandosa",    name="Gravita Grandosa",          rarity="Mythic",    income=500000000, world=4, ptype="Sweet"},
    {id="ourson_galattico",    name="Ourson Galattico",          rarity="Secret",    income=3000000000,world=4, ptype="Sweet"},
}

function CreatureConfig:Get(id)
    for _,c in ipairs(self.Creatures) do if c.id == id then return c end end
end
function CreatureConfig:GetRarity(rarityId)
    for _,r in ipairs(self.Rarities) do if r.Id == rarityId then return r end end
end
-- Stats PvP normalisées (mode classé) ou brutes (mode libre)
function CreatureConfig:GetCombatStats(id, tier, ranked)
    local c = self:Get(id); if not c then return nil end
    local r = self:GetRarity(c.rarity)
    local w = self.Worlds[c.world] or self.Worlds[1]
    local t = self.Tiers[tier] or self.Tiers[1]
    local mult = ranked and t.PvpMult or t.Mult
    return {
        HP  = math.floor(r.BaseHP  * w.Mult * mult),
        ATK = math.floor(r.BaseATK * w.Mult * mult),
        Type = c.ptype,
    }
end
return CreatureConfig
