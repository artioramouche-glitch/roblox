--!strict
--[[ MonetizationConfig
     Rôle    : les 9 produits de C6 (6 passes, 3 produits de développeur, les spins en 3 paquets), leurs prix, leurs
               effets et leurs identifiants Roblox.
     Doc     : GAME_MASTER_V2 C6, C7, E11.3, C3/A5 (coffre-fort) ; PROMPT_EXECUTION_SABL_V4 §31.11 lot A, §24 ;
               Q1-Q3 de l'étape 11 (02/10 : B, A, A)
     Étape   : 11, lot A
     Dépend  : aucun
     Exposé  : configuration immuable ; Gamepasses, Products, Get(key), GetByRobloxId(kind, id), IsConfigured()
     Limite  : Id = 0 tant que le Producer n'a pas créé le produit sur le site Roblox (handoff H-4, Loi 12) ; un
               identifiant à 0 ne correspond jamais à un achat. Price est le prix de C6 en Robux, pour l'affichage et
               H-4 : Roblox facture le prix réglé sur son site. Règles d'or C6 et E11.3 : aucun produit ne touche
               aux stats de combat, aucun ne donne de Secret ; la roulette (contenu à trancher) non plus.
]]
local MonetizationConfig = {}

-- Passes (achat unique, permanent).
MonetizationConfig.Gamepasses = table.freeze({
    -- C6 : +50 % revenus permanent, tag doré, zone VIP.
    table.freeze({Key = "VIP", Name = "VIP", Price = 199, Id = 0, IncomeBonus = 0.50, GoldTag = true, VipZone = true}),
    -- C6 : chance ×2 permanente, multipliée avec les autres sources (Q3 du lot C de l'étape 10).
    table.freeze({Key = "Luck2x", Name = "×2 Chance", Price = 149, Id = 0, LuckMult = 2}),
    -- C6 : vitesse ×2, en course comme en poursuite.
    table.freeze({Key = "Speed2x", Name = "×2 Vitesse", Price = 99, Id = 0, SpeedMult = 2}),
    -- Q1 (option B) : le revenu d'absence du coffre-fort passe de 50 % (UpgradeConfig) à 100 %.
    table.freeze({Key = "AutoCollect", Name = "Auto-collect", Price = 249, Id = 0, VaultIncomeShare = 1}),
    -- Q2 (option A) : 5 piédestaux tout de suite, au-delà du maximum de 25, gardés après un rebirth.
    table.freeze({Key = "ExtraSlots", Name = "+5 Slots", Price = 199, Id = 0, ExtraSlots = 5}),
    -- C6 et E11.3 : +25 % de tokens arène gagnés et une emote de victoire ; jamais un avantage de stats.
    table.freeze({Key = "Gladiator", Name = "Passe Gladiateur", Price = 179, Id = 0, ArenaTokenBonus = 0.25,
        VictoryEmote = true}),
})

-- Produits de développeur (achetables plusieurs fois, sauf Once).
MonetizationConfig.Products = table.freeze({
    -- C6 : consommable, +3 min de bouclier, jamais permanent (§18.2 : utilisable bouclier inactif).
    table.freeze({Key = "EmergencyShield", Name = "Bouclier d'urgence", Price = 49, Id = 0, EmergencyShields = 1}),
    -- C6 : 10K + un Rare garanti (tiré dans le monde 1, comme J7 de la série) + un bouclier d'urgence ; une fois.
    table.freeze({Key = "StarterPack", Name = "Starter Pack", Price = 99, Id = 0, Money = 10000, Rarity = "Rare",
        EmergencyShields = 1, Once = true}),
    -- Q3 (option A) : C6 « 25-499 R$ » en 3 paquets.
    table.freeze({Key = "Spins1", Name = "1 spin", Price = 25, Id = 0, Spins = 1}),
    table.freeze({Key = "Spins10", Name = "10 spins", Price = 199, Id = 0, Spins = 10}),
    table.freeze({Key = "Spins25", Name = "25 spins", Price = 499, Id = 0, Spins = 25}),
})

MonetizationConfig.EmergencyShieldSeconds = 3 * 60 -- C6 : +3 min

-- Passes et produits n'ont pas les mêmes champs : listes vues comme {any} pour le typage strict.
local gamepasses: {any} = MonetizationConfig.Gamepasses
local products: {any} = MonetizationConfig.Products

local byKey: {[string]: any} = {}
for _, list in ipairs({gamepasses, products}) do
    for _, item in ipairs(list) do byKey[item.Key] = item end
end

function MonetizationConfig.Get(key: any): any
    return if type(key) == "string" then byKey[key] else nil
end

-- Produit d'un achat Roblox : kind = "Gamepass" ou "Product" ; un identifiant à 0 ou inconnu donne nil.
function MonetizationConfig.GetByRobloxId(kind: any, id: any): any
    local list = if kind == "Gamepass" then gamepasses elseif kind == "Product" then products else nil
    if not list or type(id) ~= "number" or id <= 0 then return nil end
    for _, item in ipairs(list) do
        if item.Id == id then return item end
    end
    return nil
end

-- Vrai quand les 11 identifiants sont renseignés (handoff H-4 fait).
function MonetizationConfig.IsConfigured(): boolean
    for _, item in pairs(byKey) do
        if item.Id <= 0 then return false end
    end
    return true
end

return table.freeze(MonetizationConfig)
