--!nonstrict
--[[ TestStealBuyback
     Rôle    : batterie du rachat ×1.5 pendant 10 min (A4), logique serveur sans remote.
     Doc     : GAME_MASTER_V2 A4, G4 ; PROMPT_EXECUTION_SABL_V4 §25.2, §27 ; Q6 à Q8 option A
     Étape   : 5, lot B3
     Dépend  : Play serveur ; Migrations, TableUtil, EconomyUtil, StealConfig, ShieldService.BaseState
     Exposé  : bilan ; joueurs, profils, plots, positions, bouclier et horloge factices
     Limite  : aucun profil réel lu ou écrit. Depuis le 15/09, l'outil MCP ne peut plus require les
               modules du jeu : à lancer depuis la barre de commande de Studio, en vue Serveur.
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local Migrations = require(Server.Data.Migrations)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local EconomyUtil = require(ReplicatedStorage.Shared.EconomyUtil)
local StealConfig = require(ReplicatedStorage.Config.StealConfig)
local ShieldService = require(Server.Services.ShieldService)
local StealService = require(Server.Services.StealService)
local B = ShieldService.BaseState

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- A4 et Q6 recopiés : les attendus ne sont jamais déduits de la configuration testée.
check("A4 : rachat x1.5 pendant 10 min (600 s)", StealConfig.Buyback.PriceMultiplier == 1.5
    and StealConfig.Buyback.WindowMinutes == 10 and StealConfig.GetBuybackWindowSeconds() == 600)
check("Configuration gelee", table.isfrozen(StealConfig.Buyback))

local function makeWorld()
    local w = {clock = 10000, present = {}, positions = {}, speeds = {}, profiles = {}, plots = {},
        refreshed = {}, busy = {}}
    local data = {}
    function data:Get(p) local s = w.profiles[p] return s and TableUtil.DeepCopy(s) or nil end
    function data:Update(p, callback)
        if (w.busy[p] or 0) > 0 then w.busy[p] -= 1 return false, "BUSY" end
        local current = w.profiles[p]
        if not current then return false, "NO_PROFILE" end
        local candidate = TableUtil.DeepCopy(current)
        local ok, accepted, result = pcall(callback, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        local reconciled, reason = Migrations:Apply(candidate)
        if not reconciled then return false, reason end
        w.profiles[p] = reconciled
        return true, result
    end
    local shield = {BaseState = B}
    function shield:GetPhase() return B.VULNERABLE end
    local placement = {}
    function placement:PlotOf(p) return w.plots[p] end
    function placement:Refresh(p) w.refreshed[p] = (w.refreshed[p] or 0) + 1 return true end
    w.service = StealService.new({
        Data = data, Shield = shield, Placement = placement, Clock = function() return w.clock end,
        Remotes = false, World = false,
        IsPresent = function(p) return w.present[p] == true end,
        Characters = {
            GetPosition = function(p) return w.positions[p] end,
            SetSpeedMultiplier = function(p, m) w.speeds[p] = m end,
        },
    })
    w.service:Init()
    return w
end

local function addPlayer(w, name, id, x, creatures, overrides)
    local p = {Name = name, UserId = id}
    local profile = Migrations:Create()
    profile.Level, profile.Playtime = 5, 3600
    profile.Creatures = creatures or {}
    for key, value in pairs(overrides or {}) do profile[key] = value end
    w.profiles[p], w.present[p] = profile, true
    local plot = Instance.new("Part")
    plot.Anchored, plot.Size, plot.Position = true, Vector3.new(80, 1, 80), Vector3.new(x, 1.5, 0)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "Pedestals", plot
    for slot = 1, 3 do
        local pedestal = Instance.new("Part")
        pedestal.Name, pedestal.Anchored = "Pedestal" .. slot, true
        pedestal.Position, pedestal.Parent = plot.Position + Vector3.new(slot * 4, 1, 0), folder
    end
    w.plots[p] = plot
    return p
end

local function pedestal(w, owner, slot) return w.plots[owner].Pedestals["Pedestal" .. slot].Position end
local function code(ok, result) return ok and "OK" or result end

-- Vol sécurisé de la première créature de la victime, au piédestal 1 du voleur, à t = 10005.
local function securedWorld(victimCreatures, victimOverrides)
    local w = makeWorld()
    local creatures = victimCreatures or {{Uid = "v1", Id = "noobini", Tier = 1, PlacedSlot = 1}}
    local victim = addPlayer(w, "Victime", 101, 0, creatures, victimOverrides or {Money = 1000})
    local thief = addPlayer(w, "Voleur", 202, 300)
    w.positions[thief] = pedestal(w, victim, creatures[1].PlacedSlot)
    assert(w.service:AttemptSteal(thief, victim, creatures[1].Uid) == true, "vol de preparation refuse")
    w.positions[thief] = pedestal(w, thief, 1)
    assert(w.service:BeginSecure(thief, 1) == true, "pose de preparation refusee")
    w.clock += 5
    local ok, secured = w.service:CompleteSecure(thief)
    assert(ok == true, "transfert de preparation refuse : " .. tostring(secured))
    return w, victim, thief, secured
end

local w, V, Th, secured = securedWorld()
local offers = w.service:GetBuybacks(V)
check("Pose securisee : offre de rachat ouverte a la victime", type(secured.OfferId) == "string"
    and #offers == 1 and offers[1].Id == secured.OfferId)
check("Q6 : prix = vente G4 x1.5 (noobini Normal 400 -> 600)", offers[1].Price == 600)
check("A4 : offre valable 10 min (fin a 10605), creature et voleur exacts", offers[1].ExpiresAt == 10605
    and offers[1].CreatureId == "noobini" and offers[1].Tier == 1 and offers[1].ThiefUserId == 202)
check("Aucune offre visible par le voleur", #w.service:GetBuybacks(Th) == 0)
check("Rachat par le voleur : NOT_OWNER ; offre inconnue : BUYBACK_GONE",
    code(w.service:Buyback(Th, secured.OfferId)) == "NOT_OWNER" and code(w.service:Buyback(V, "buyback_999")) == "BUYBACK_GONE")

w.profiles[V].Money = 599
check("Victime a 599 : NOT_ENOUGH_MONEY", code(w.service:Buyback(V, secured.OfferId)) == "NOT_ENOUGH_MONEY")
check("Refus sans effet : argent 599, brainrot toujours chez le voleur", w.profiles[V].Money == 599
    and #w.profiles[V].Creatures == 0 and #w.profiles[Th].Creatures == 1)
w.profiles[V].Money = 1000
local thiefMoney = w.profiles[Th].Money
local okBuy, bought = w.service:Buyback(V, secured.OfferId)
check("Rachat accepte : 600 payes, brainrot rendu au piedestal d'origine", okBuy == true and bought.Price == 600
    and bought.PlacedSlot == 1 and bought.Uid == "v1")
check("Q7 : argent detruit (victime 400, voleur inchange)", w.profiles[V].Money == 400
    and w.profiles[Th].Money == thiefMoney)
check("Loi 8 : un seul exemplaire, chez la victime", #w.profiles[V].Creatures == 1
    and w.profiles[V].Creatures[1].Uid == "v1" and #w.profiles[Th].Creatures == 0)
check("Bases rafraichies et vol toujours compte chez le voleur", w.refreshed[V] == 2 and w.refreshed[Th] == 2
    and w.profiles[Th].Stats.Steals == 1)
check("Offre fermee : second rachat BUYBACK_GONE", #w.service:GetBuybacks(V) == 0
    and code(w.service:Buyback(V, secured.OfferId)) == "BUYBACK_GONE")

w, V, Th, secured = securedWorld()
w.clock = 10604
w.service:Step()
check("A 599 s : offre toujours ouverte", #w.service:GetBuybacks(V) == 1)
w.clock = 10605
check("A 600 s : BUYBACK_GONE", code(w.service:Buyback(V, secured.OfferId)) == "BUYBACK_GONE")
w, V, Th, secured = securedWorld()
w.clock = 10605
w.service:Step()
check("Echeance atteinte : offre retiree par le tick", #w.service:GetBuybacks(V) == 0)

w, V, Th, secured = securedWorld()
w.present[Th] = nil
check("Q8 : voleur parti : BUYBACK_GONE", code(w.service:Buyback(V, secured.OfferId)) == "BUYBACK_GONE"
    and #w.service:GetBuybacks(V) == 0)
w, V, Th, secured = securedWorld()
w.service:PlayerLeft(V)
check("Q8 : victime partie : offre fermee", #w.service:GetBuybacks(V) == 0)

w, V, Th, secured = securedWorld()
w.profiles[Th].Creatures = {}
check("Brainrot vendu par le voleur : BUYBACK_GONE, argent intact",
    code(w.service:Buyback(V, secured.OfferId)) == "BUYBACK_GONE" and w.profiles[V].Money == 1000)

w, V, Th, secured = securedWorld()
table.insert(w.profiles[V].Creatures, {Uid = "n2", Id = "talpa", Tier = 1, PlacedSlot = 1})
local _, moved = w.service:Buyback(V, secured.OfferId)
check("Piedestal d'origine occupe : premier piedestal libre (2)", moved ~= nil and moved.PlacedSlot == 2)
w, V, Th, secured = securedWorld()
for slot = 1, 3 do
    table.insert(w.profiles[V].Creatures, {Uid = "f" .. slot, Id = "talpa", Tier = 1, PlacedSlot = slot})
end
local _, stored = w.service:Buyback(V, secured.OfferId)
check("Tous les piedestaux occupes : retour dans l'inventaire", stored ~= nil and stored.PlacedSlot == nil
    and #w.profiles[V].Creatures == 4)

w, V, Th, secured = securedWorld()
for index = 1, 150 do
    table.insert(w.profiles[V].Creatures, {Uid = ("i%03d"):format(index), Id = "talpa", Tier = 1})
end
check("Victime a 150 creatures : INVENTORY_FULL", code(w.service:Buyback(V, secured.OfferId)) == "INVENTORY_FULL")

w, V, Th, secured = securedWorld()
table.insert(w.profiles[V].Creatures, {Uid = "v1", Id = "talpa", Tier = 1})
local okClash, clash = w.service:Buyback(V, secured.OfferId)
check("Uid deja pris chez la victime : nouvel Uid genere", okClash == true and clash.Uid ~= "v1"
    and #w.profiles[V].Creatures == 2)

w, V, Th, secured = securedWorld()
w.busy[Th] = 1
local okFail, failCode = w.service:Buyback(V, secured.OfferId)
check("Loi 8 : retrait impossible chez le voleur -> rachat annule", okFail == false and failCode == "BUSY")
check("Loi 8 : argent rendu, ni perte ni doublon, offre conservee", w.profiles[V].Money == 1000
    and #w.profiles[V].Creatures == 0 and #w.profiles[Th].Creatures == 1 and #w.service:GetBuybacks(V) == 1)
check("Nouvel essai apres l'echec : rachat accepte", w.service:Buyback(V, secured.OfferId) == true)

w, V, Th, secured = securedWorld({{Uid = "g1", Id = "tralalero", Tier = 5, PlacedSlot = 1}})
local godOffer = w.service:GetBuybacks(V)[1]
check("Q6 : tralalero Celeste : 742 500 000 x1.5 = 1 113 750 000", godOffer ~= nil and godOffer.Price == 1113750000
    and godOffer.Price == math.round(EconomyUtil.GetSellPrice("tralalero", 5) * 1.5))
check("Stop retourne true et vide les offres", w.service:Stop() == true and #w.service:GetBuybacks(V) == 0)

table.insert(T.lines, ("[BUYBACK TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
