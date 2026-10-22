-- GameKit Inventory server (ServerScriptService.GameKit.InventoryServer)
-- Starts the Inventory module and handles selling: the "Sell" buttons of the 🎒 window
-- and parts tagged "ItemSell" (touch or prompt sells everything that has a SellPrice).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local Inventory = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Inventory"))

local sellCooldown = Util.cooldown(1)

local function sellEverything(player: Player)
	local earned = Inventory.sellAll(player)
	if earned > 0 then
		Net.notify(player, `Sold for {Util.formatNumber(earned)}!`, "reward")
	else
		Net.notify(player, "Nothing to sell.", "info")
	end
end

Net.on("InventorySell", function(player, itemId)
	if type(itemId) ~= "string" then
		return
	end
	local earned = Inventory.sell(player, itemId)
	if earned > 0 then
		Net.notify(player, `Sold for {Util.formatNumber(earned)}!`, "reward")
	end
end, 5)

Net.on("InventorySellAll", sellEverything, 2)

Util.onTag("ItemSell", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_ItemSell"
	prompt.ActionText = "Sell all"
	prompt.ObjectText = "Market"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = instance
	prompt.Triggered:Connect(sellEverything)
	instance.Touched:Connect(function(hit)
		local player = Util.playerFromHit(hit)
		if player and sellCooldown(player) and (player:GetAttribute("InvItems") or 0) > 0 then
			sellEverything(player)
		end
	end)
end)

-- Test hook used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player, itemId: string?, amount: number?)
	if action == "give" and itemId then
		return Inventory.give(player, itemId, amount)
	elseif action == "take" and itemId then
		return Inventory.take(player, itemId, amount)
	elseif action == "count" and itemId then
		return Inventory.count(player, itemId)
	end
	return nil
end
hook.Parent = script
