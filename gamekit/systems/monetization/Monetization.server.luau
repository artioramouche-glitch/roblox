-- GameKit Monetization (ServerScriptService.GameKit.Monetization)
-- Developer products and game passes, handled safely (receipts are never granted twice).
-- 1. Create the product/pass on the Creator Dashboard, copy its ID.
-- 2. Add it to ReplicatedStorage.GameKit.Config.Monetization:
--      Products   = { [123456] = { Kind = "Stat", Stat = "Coins", Amount = 500 },
--                     [123457] = { Kind = "SkipStage" } }
--      GamePasses = { [987654] = { Kind = "Multiplier", Stat = "Coins", Value = 2 },
--                     [987655] = { Kind = "WalkSpeed", Value = 24 },
--                     [987656] = { Kind = "Tool", Value = "Sword" } }
-- 3. Tag a part "PurchasePrompt" with attribute ProductId or GamePassId to sell it in-world,
--    or call MarketplaceService:PromptProductPurchase from your own UI.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("Monetization", {
	Products = {},
	GamePasses = {},
})

-- Config keys may arrive as strings; normalise to numbers.
local products: { [number]: { [string]: any } } = {}
for id, reward in pairs(config.Products) do
	products[tonumber(id) or 0] = reward
end
local passes: { [number]: { [string]: any } } = {}
for id, perk in pairs(config.GamePasses) do
	passes[tonumber(id) or 0] = perk
end

local ownedPasses: { [Player]: { [number]: boolean } } = {}

local function maxStage(): number
	local highest = 1
	for _, part in CollectionService:GetTagged("Checkpoint") do
		local stage = part:GetAttribute("Stage")
		if type(stage) == "number" and stage > highest then
			highest = stage
		end
	end
	return highest
end

local function giveTool(player: Player, toolName: string)
	local root = ServerStorage:FindFirstChild("GameKit")
	local tools = root and root:FindFirstChild("Tools")
	local template = tools and tools:FindFirstChild(toolName)
	if not template then
		warn(`[GameKit] Monetization: no tool '{toolName}' in ServerStorage.GameKit.Tools`)
		return
	end
	for _, container in { player:FindFirstChildOfClass("Backpack"), player:FindFirstChild("StarterGear") } do
		if container and not container:FindFirstChild(toolName) then
			template:Clone().Parent = container
		end
	end
end

local function applyPass(player: Player, perk: { [string]: any })
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if perk.Kind == "WalkSpeed" and humanoid then
		humanoid.WalkSpeed = math.max(humanoid.WalkSpeed, perk.Value)
	elseif perk.Kind == "JumpPower" and humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = math.max(humanoid.JumpPower, perk.Value)
	elseif perk.Kind == "Tool" then
		giveTool(player, perk.Value)
	end
end

local function applyAllPasses(player: Player)
	for passId in pairs(ownedPasses[player] or {}) do
		local perk = passes[passId]
		if perk then
			applyPass(player, perk)
		end
	end
end

PlayerData.addMultiplier(function(player, stat)
	local total = 1
	for passId in pairs(ownedPasses[player] or {}) do
		local perk = passes[passId]
		if perk and perk.Kind == "Multiplier" and perk.Stat == stat then
			total *= perk.Value
		end
	end
	return total
end)

local function grantProduct(player: Player, reward: { [string]: any }): boolean
	if reward.Kind == "Stat" then
		PlayerData.defineStat({ Name = reward.Stat, Default = 0 })
		local balance = PlayerData.add(player, reward.Stat, reward.Amount or 0)
		Analytics.source(player, reward.Stat, reward.Amount or 0, balance, "IAP")
		Net.notify(player, `Thanks! +{Util.formatNumber(reward.Amount or 0)} {reward.Stat}`, "reward")
	elseif reward.Kind == "SkipStage" then
		local stage = PlayerData.get(player, "Stage")
		PlayerData.set(player, "Stage", math.min(stage + 1, maxStage()))
		Util.respawn(player)
		Net.notify(player, "Stage skipped!", "reward")
	elseif reward.Kind == "Item" then
		PlayerData.grant(player, reward.Value)
	else
		warn(`[GameKit] Unknown product kind '{tostring(reward.Kind)}'`)
		return false
	end
	return true
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not PlayerData.waitForLoad(player, 10) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local history = PlayerData.section(player, "Receipts")
	if history[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local reward = products[receipt.ProductId]
	if not reward then
		warn(`[GameKit] Product {receipt.ProductId} is not in Config.Monetization.Products`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grantProduct, player, reward)
	if not ok or not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	history[receipt.PurchaseId] = os.time()
	if not PlayerData.save(player) then
		-- Roblox will call ProcessReceipt again; the receipt is already marked, so the
		-- player is not rewarded twice.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkPasses(player: Player)
	ownedPasses[player] = ownedPasses[player] or {}
	for passId in pairs(passes) do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and owns then
			ownedPasses[player][passId] = true
			player:SetAttribute("Pass_" .. passId, true)
		end
	end
	applyAllPasses(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passes[passId] then
		ownedPasses[player] = ownedPasses[player] or {}
		ownedPasses[player][passId] = true
		player:SetAttribute("Pass_" .. passId, true)
		applyPass(player, passes[passId])
		Net.notify(player, "Game pass unlocked! Thank you!", "reward")
	end
end)

Util.onPlayer(function(player)
	task.spawn(checkPasses, player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyAllPasses(player)
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	ownedPasses[player] = nil
end)

Util.onTag("PurchasePrompt", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local productId = instance:GetAttribute("ProductId")
	local passId = instance:GetAttribute("GamePassId")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Purchase"
	prompt.ActionText = "Buy"
	prompt.ObjectText = instance.Name
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		if type(passId) == "number" then
			MarketplaceService:PromptGamePassPurchase(player, passId)
		elseif type(productId) == "number" then
			MarketplaceService:PromptProductPurchase(player, productId)
		end
	end)
end)
