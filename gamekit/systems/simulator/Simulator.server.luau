-- GameKit Simulator (ServerScriptService.GameKit.Simulator)
-- The simulator loop: Train -> fill your backpack with Power -> Sell for Coins ->
-- buy upgrades/pets (Shop) -> unlock zones -> Rebirth for a permanent multiplier.
--   Parts tagged "SellPad"  : touching sells all Power for Coins.
--   Parts tagged "ZoneGate" : attributes Zone (string) and Price (number); pay once to pass.
--   Coins/orbs: use the Collectibles system with Stat = "Power".
-- Upgrades for Capacity and ClickPower are Shop items of Kind "Upgrade".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Simulator", {
	PowerStat = "Power",
	CoinStat = "Coins",
	StartCapacity = 50,
	StartClickPower = 1,
	SellRate = 1,
	RebirthBaseCost = 1000,
	RebirthBonus = 0.5,
	TrainsPerSecond = 8,
})

local POWER, COINS = config.PowerStat, config.CoinStat
PlayerData.defineStat({ Name = COINS, Default = 0, Leaderstat = true })
PlayerData.defineStat({ Name = "Rebirths", Default = 0, Leaderstat = true })
PlayerData.defineStat({ Name = POWER, Default = 0 })
PlayerData.defineStat({ Name = "Capacity", Default = config.StartCapacity })
PlayerData.defineStat({ Name = "ClickPower", Default = config.StartClickPower })

PlayerData.addMultiplier(function(player, stat)
	if stat == POWER then
		return 1 + PlayerData.get(player, "Rebirths") * config.RebirthBonus
	end
	return 1
end)

local function rebirthCost(player: Player): number
	return config.RebirthBaseCost * (PlayerData.get(player, "Rebirths") + 1)
end

local function publish(player: Player)
	player:SetAttribute("RebirthCost", rebirthCost(player))
end

-- Collected power (e.g. orbs from the Collectibles system) can't go over capacity.
PlayerData.onChanged(POWER, function(player, value)
	local capacity = PlayerData.get(player, "Capacity")
	if value > capacity then
		PlayerData.set(player, POWER, capacity)
	end
end)

local fullWarning = Util.cooldown(3)

Net.on("SimTrain", function(player)
	if not PlayerData.isLoaded(player) then
		return
	end
	local capacity = PlayerData.get(player, "Capacity")
	local power = PlayerData.get(player, POWER)
	if power >= capacity then
		if fullWarning(player) then
			Net.notify(player, "🎒 Backpack full! Go to a Sell pad.", "error")
		end
		return
	end
	local gain = PlayerData.get(player, "ClickPower") * PlayerData.getMultiplier(player, POWER)
	PlayerData.set(player, POWER, math.min(capacity, power + math.floor(gain + 0.5)))
end, config.TrainsPerSecond)

Net.on("SimRebirth", function(player)
	local cost = rebirthCost(player)
	if not PlayerData.spend(player, COINS, cost) then
		Net.notify(player, `Rebirth costs {Util.formatNumber(cost)} {COINS}.`, "error")
		return
	end
	PlayerData.set(player, COINS, 0)
	PlayerData.set(player, POWER, 0)
	local rebirths = PlayerData.add(player, "Rebirths", 1)
	publish(player)
	Net.notify(player, `🔁 Rebirth {rebirths}! Power x{1 + rebirths * config.RebirthBonus}`, "reward")
end, 1)

local sellCooldown = Util.cooldown(1)
Util.onTag("SellPad", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	instance.Touched:Connect(function(hit)
		local player = Util.playerFromHit(hit)
		if not player or not PlayerData.isLoaded(player) or not sellCooldown(player) then
			return
		end
		local power = PlayerData.get(player, POWER)
		if power <= 0 then
			return
		end
		PlayerData.set(player, POWER, 0)
		local earned = PlayerData.reward(player, COINS, power * config.SellRate)
		Net.notify(player, `Sold for {Util.formatNumber(earned)} {COINS}!`, "reward")
	end)
end)

Util.onTag("ZoneGate", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local zone = tostring(instance:GetAttribute("Zone") or instance.Name)
	local priceValue = instance:GetAttribute("Price")
	local price = if type(priceValue) == "number" then priceValue else 100
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Zone"
	prompt.ActionText = `Unlock ({Util.formatNumber(price)} {COINS})`
	prompt.ObjectText = zone
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		local id = "Zone_" .. zone
		if PlayerData.owns(player, id) then
			return
		end
		if PlayerData.spend(player, COINS, price) then
			PlayerData.grant(player, id)
			Net.notify(player, `🔓 {zone} unlocked!`, "success")
		else
			Net.notify(player, `You need {Util.formatNumber(price)} {COINS}.`, "error")
		end
	end)
end)

PlayerData.onLoaded(publish)
