--!strict
--[[ ArenaShop
     Rôle    : achat dans la boutique du Colisée (E8) : contrôles, débit des tokens et livraison dans la même
               opération, jamais deux fois ; multiplicateur du boost de revenus acheté.
     Doc     : GAME_MASTER_V2 E8, A5, C7, G2 ; PROMPT_EXECUTION_SABL_V4 §31.14 lot D ; décisions 94, 97, 132
     Étape   : 14, lot D
     Dépend  : Config.ArenaConfig (Shop), Config.MonetizationConfig (ExtendBoost)
     Exposé  : Buy(profile, key, now) -> reçu | (nil, raison) ; IncomeMultiplier(profile, now)
     Limite  : Buy écrit dans le profil reçu (dans une mise à jour de DataService, en session locale). L'œuf
               Colisée est débité ici et ouvert par EggService aux odds d'`egg_golden` (reçu.Egg, décision 94) :
               le service l'ouvre dans la même mise à jour. Champs du schéma v4 créés à la volée : PvP.Cosmetics,
               Boosts.ShopIncome.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = ReplicatedStorage:WaitForChild("Config")
local ArenaConfig = require(config:WaitForChild("ArenaConfig"))
local MonetizationConfig = require(config:WaitForChild("MonetizationConfig"))

local ArenaShop = {}

local function owned(profile: any, item: any): boolean
    local pvp = profile.PvP
    if item.Cosmetic then return type(pvp.Cosmetics) == "table" and pvp.Cosmetics[item.Key] == true end
    if item.Loadout then return type(pvp.Loadouts) == "table" and pvp.Loadouts[item.Loadout] ~= nil end
    return false
end

function ArenaShop.Buy(profile: any, key: any, now: number): (any, string?)
    local item = ArenaConfig.GetShopItem(key)
    if not item then return nil, "UNKNOWN_ITEM" end
    if type(profile) ~= "table" or type(profile.PvP) ~= "table" or type(profile.Base) ~= "table" then
        return nil, "BAD_INPUT"
    end
    local pvp, base = profile.PvP, profile.Base
    if item.Once and owned(profile, item) then return nil, "ALREADY_OWNED" end
    -- E8 : l'anneau ne monte par la boutique que jusqu'au niveau 3 (au-delà, par l'écran de base, A5).
    if item.TrainingRing and (base.TrainingRing or 0) >= item.MaxLevel then return nil, "MAX_LEVEL" end
    local tokens = pvp.ArenaTokens or 0
    if tokens < item.Price then return nil, "NOT_ENOUGH_TOKENS" end
    pvp.ArenaTokens = tokens - item.Price
    local receipt: any = {Key = item.Key, Price = item.Price}
    if item.Egg then
        receipt.Egg = item.Egg
    elseif item.Cosmetic then
        pvp.Cosmetics = pvp.Cosmetics or {}
        pvp.Cosmetics[item.Key] = true
    elseif item.Loadout then
        pvp.Loadouts = pvp.Loadouts or {}
        pvp.Loadouts[item.Loadout] = {} -- 3 places vides, à remplir comme l'équipe A
    elseif item.IncomeMult then
        -- Décision 97 : un rachat prolonge la durée restante, sans dépasser ×1,2.
        profile.Boosts = profile.Boosts or {}
        profile.Boosts.ShopIncome = MonetizationConfig.ExtendBoost(profile.Boosts.ShopIncome, now, item.Seconds)
    elseif item.TrainingRing then
        base.TrainingRing = (base.TrainingRing or 0) + item.TrainingRing
    end
    return receipt, nil
end

-- Décision 97 : ×1,2 tant que le boost acheté court, multiplié avec le reste par IncomeService.
function ArenaShop.IncomeMultiplier(profile: any, now: number): number
    local boosts = type(profile) == "table" and profile.Boosts or nil
    local endsAt = if type(boosts) == "table" then boosts.ShopIncome else nil
    if type(endsAt) ~= "number" or not (endsAt > now) then return 1 end
    return ArenaConfig.GetShopItem("IncomeBoost").IncomeMult
end

return table.freeze(ArenaShop)
