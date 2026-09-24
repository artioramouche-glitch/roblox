local EggConfig = {}
EggConfig.Eggs = {
    {id="egg_basic",  name="Œuf Street Basic", price=100,          world=1,
     pool={"noobini","tim_cheese","fluriflura","pipi_kiwi","talpa","trippi"},
     odds={Common=85,Rare=15}},
    -- Écart B2/G5.2 validé : cinq candidats ajoutés aux raretés manquantes, sans changer les odds.
    {id="egg_street", name="Œuf Street",        price=8500,        world=1,
     pool={"noobini","trippi","tung_tung","boneca","footera","chim_banana","cappuccino","patapim","burbaloni"},
     odds={Common=10,Rare=55,Epic=33,Legendary=2}},
    {id="egg_golden", name="Œuf Golden",        price=150000,      world=1,
     pool={"chim_banana","cappuccino","patapim","blueberrini","strawberelli","burbaloni","bombombini","frigo_camelo","tukanno","bombardiro"},
     odds={Rare=20,Epic=55,Legendary=22,Mythic=3}},
    {id="egg_mythic", name="Œuf Mythic",        price=5000000,     world=1,
     pool={"burbaloni","bombombini","frigo_camelo","tukanno","bombardiro","lirili","glorbo","gorillo","cappuccino","tralalero"},
     odds={Epic=25,Legendary=50,Mythic=22,God=3}},
    {id="egg_secret", name="Œuf Interdit",      price=250000000,   world=1,
     pool={"gorillo","tralalero","vaca","sammyni","girafa","los_tralaleritos","chicleteira","la_grande","garama","burbaloni"},
     odds={Legendary=30,Mythic=35,God=34.5,Secret=0.5}},
    {id="egg_dessert",name="Œuf Dessert",       price=25000000,    world=2,
     pool={"biscottino","gelato_gangsterino","tiramisu_tornado","macaroni_mago","donut_drago","croissant_crusherino","gateau_guardiano","millefeuille_celestre"},
     odds={Rare=55,Epic=33,Legendary=10,Mythic=1.9,Secret=0.1}},
    {id="egg_abyss",  name="Œuf Abyss",         price=2000000000,  world=3,
     pool={"onigirino_orcano","maki_rayona","nigiri_anguilla","tempura_titano","ramen_krakeno","unagi_imperatore","wasabi_wraitho","sushi_shogun"},
     odds={Rare=55,Epic=33,Legendary=10,Mythic=1.9,Secret=0.1}},
    {id="egg_cosmic", name="Œuf Cosmic",        price=200000000000,world=4,
     pool={"bonbonni_bourdonna","chamallow_astronauta","sucetta_satellita","gommosa_galattica","cotone_cosmico","caramel_cometa","gravita_grandosa","ourson_galattico"},
     odds={Rare=55,Epic=33,Legendary=10,Mythic=1.9,Secret=0.1}},
}
function EggConfig:Get(id)
    for _,e in ipairs(self.Eggs) do if e.id == id then return e end end
end
return EggConfig
