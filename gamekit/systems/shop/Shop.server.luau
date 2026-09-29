-- GameKit Shop (ServerScriptService.GameKit.Shop)
-- Server-validated shop. Items live in ReplicatedStorage.GameKit.Config.Shop (Items list).
-- Item fields: Id, Name, Price, Currency (default Config.Shop.Currency), Icon, Description,
--   Kind = "WalkSpeed"  Value = new walk speed
--          "JumpPower"  Value = new jump power
--          "Tool"       Value = tool name in ServerStorage.GameKit.Tools
--          "Trail"      Value = "#RRGGBB" trail color (one trail equipped at a time)
--          "Multiplier" Stat = stat boosted, Value = multiplier (2 = double)
--          "Pet"        Stat = stat boosted, Value = multiplier, Color = "#RRGGBB"
--          "Upgrade"    Stat = stat raised by Value per level (repeatable), PriceGrowth, MaxLevel
--          "Stat"       Stat = stat given, Value = amount (consumable, repeatable)
-- Parts tagged "ShopStand" get an "Open Shop" prompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Shop", {
	Currency = "Coins",
	MaxPets = 3,
	Items = {},
})

PlayerData.defineStat({ Name = config.Currency, Default = 0, Leaderstat = true })

local items: { [string]: { [string]: any } } = {}
for _, item in ipairs(config.Items) do
	if type(item) == "table" and type(item.Id) == "string" then
		items[item.Id] = item
		local currency = item.Currency or config.Currency
		PlayerData.defineStat({ Name = currency, Default = 0, Leaderstat = true })
		if (item.Kind == "Upgrade" or item.Kind == "Stat") and item.Stat then
			PlayerData.defineStat({ Name = item.Stat, Default = 0 })
		end
	end
end

local function shopData(player: Player): { [string]: any }
	local data = PlayerData.section(player, "Shop")
	data.Levels = data.Levels or {}
	data.Pets = data.Pets or {}
	return data
end

local function levelOf(player: Player, itemId: string): number
	return shopData(player).Levels[itemId] or 0
end

local function priceOf(player: Player, item: { [string]: any }): number
	if item.Kind == "Upgrade" then
		return math.floor(item.Price * (item.PriceGrowth or 1.5) ^ levelOf(player, item.Id))
	end
	return item.Price
end

local function publish(player: Player)
	local data = shopData(player)
	for id, level in pairs(data.Levels) do
		player:SetAttribute("Level_" .. Util.attrName(id), level)
		local item = items[id]
		if item then
			player:SetAttribute("Price_" .. Util.attrName(id), priceOf(player, item))
		end
	end
	for id, item in pairs(items) do
		if item.Kind == "Upgrade" and data.Levels[id] == nil then
			player:SetAttribute("Price_" .. Util.attrName(id), priceOf(player, item))
		end
	end
	player:SetAttribute("EquippedTrail", data.Trail)
	player:SetAttribute("EquippedPets", table.concat(data.Pets, ","))
end

-- Effects -----------------------------------------------------------------------------------
local function toolsFolder(): Instance?
	local root = ServerStorage:FindFirstChild("GameKit")
	return root and root:FindFirstChild("Tools")
end

local function giveTool(player: Player, toolName: string)
	local folder = toolsFolder()
	local template = folder and folder:FindFirstChild(toolName)
	if not template then
		warn(`[GameKit] Shop: no tool '{toolName}' in ServerStorage.GameKit.Tools`)
		return
	end
	for _, container in { player:FindFirstChildOfClass("Backpack"), player:FindFirstChild("StarterGear") } do
		if container and not container:FindFirstChild(toolName) then
			template:Clone().Parent = container
		end
	end
end

local function applyTrail(player: Player, character: Model)
	local old = character:FindFirstChild("GK_Trail", true)
	if old then
		old:Destroy()
	end
	local itemId = shopData(player).Trail
	local item = itemId and items[itemId]
	local root = character:FindFirstChild("HumanoidRootPart")
	if not item or not root then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "GK_TrailTop"
	top.Position = Vector3.new(0, 0.8, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "GK_TrailBottom"
	bottom.Position = Vector3.new(0, -0.8, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "GK_Trail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(Util.color(item.Value))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.6
	trail.LightEmission = 0.5
	trail.Parent = root
end

local function buildPet(item: { [string]: any }): Model
	local model = Instance.new("Model")
	model.Name = "GK_Pet_" .. item.Id
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * 1.8
	body.Color = Util.color(item.Color, Color3.fromRGB(255, 170, 60))
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.Parent = model
	model.PrimaryPart = body
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.4
		eye.Color = Color3.new(0.05, 0.05, 0.05)
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Massless = true
		eye.CFrame = body.CFrame * CFrame.new(0.35 * side, 0.25, -0.75)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = model
	end
	return model
end

local function applyPets(player: Player, character: Model)
	for _, child in character:GetChildren() do
		if string.sub(child.Name, 1, 7) == "GK_Pet_" then
			child:Destroy()
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for index, itemId in ipairs(shopData(player).Pets) do
		local item = items[itemId]
		if item then
			local pet = buildPet(item)
			local body = pet.PrimaryPart :: BasePart
			local angle = (index - 1) * math.pi * 0.5 + math.pi * 0.75
			local offset = Vector3.new(math.cos(angle) * 4, 1.5, math.sin(angle) * 4)
			body.CFrame = root.CFrame + offset
			local petAttachment = Instance.new("Attachment")
			petAttachment.Parent = body
			local anchor = Instance.new("Attachment")
			anchor.Name = "GK_PetAnchor"
			anchor.Position = offset
			anchor.Parent = root
			local align = Instance.new("AlignPosition")
			align.Attachment0 = petAttachment
			align.Attachment1 = anchor
			align.Responsiveness = 18
			align.MaxForce = 1e6
			align.Parent = body
			local orient = Instance.new("AlignOrientation")
			orient.Attachment0 = petAttachment
			orient.Attachment1 = anchor
			orient.Responsiveness = 18
			orient.Parent = body
			pet.Parent = character
			pcall(function()
				body:SetNetworkOwner(player)
			end)
		end
	end
end

local function applyAll(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local walk, jump = nil, nil
	for id, item in pairs(items) do
		if PlayerData.owns(player, id) then
			if item.Kind == "WalkSpeed" then
				walk = math.max(walk or 0, item.Value)
			elseif item.Kind == "JumpPower" then
				jump = math.max(jump or 0, item.Value)
			elseif item.Kind == "Tool" then
				giveTool(player, item.Value)
			end
		end
	end
	if walk then
		humanoid.WalkSpeed = walk
	end
	if jump then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = jump
	end
	applyTrail(player, character)
	applyPets(player, character)
end

PlayerData.addMultiplier(function(player, stat)
	local total = 1
	for id, item in pairs(items) do
		if item.Kind == "Multiplier" and item.Stat == stat and PlayerData.owns(player, id) then
			total *= item.Value
		end
	end
	if PlayerData.isLoaded(player) then
		for _, id in ipairs(shopData(player).Pets) do
			local item = items[id]
			if item and item.Stat == stat then
				total *= item.Value
			end
		end
	end
	return total
end)

-- Requests -----------------------------------------------------------------------------------
Net.on("ShopBuy", function(player, itemId)
	local item = type(itemId) == "string" and items[itemId]
	if not item or not PlayerData.isLoaded(player) then
		return
	end
	local repeatable = item.Kind == "Upgrade" or item.Kind == "Stat"
	if not repeatable and PlayerData.owns(player, item.Id) then
		Net.notify(player, "You already own " .. item.Name, "info")
		return
	end
	if item.Kind == "Upgrade" and item.MaxLevel and levelOf(player, item.Id) >= item.MaxLevel then
		Net.notify(player, item.Name .. " is maxed out!", "info")
		return
	end
	local currency = item.Currency or config.Currency
	local price = priceOf(player, item)
	if not PlayerData.spend(player, currency, price) then
		Net.notify(player, `Not enough {currency}! You need {Util.formatNumber(price)}.`, "error")
		return
	end
	local data = shopData(player)
	if item.Kind == "Upgrade" then
		data.Levels[item.Id] = levelOf(player, item.Id) + 1
		PlayerData.add(player, item.Stat, item.Value)
	elseif item.Kind == "Stat" then
		PlayerData.add(player, item.Stat, item.Value)
	else
		PlayerData.grant(player, item.Id)
		if item.Kind == "Trail" then
			data.Trail = item.Id
		elseif item.Kind == "Pet" and #data.Pets < config.MaxPets then
			table.insert(data.Pets, item.Id)
		end
	end
	publish(player)
	applyAll(player)
	Net.notify(player, `Bought {item.Name}!`, "success")
end, 4)

Net.on("ShopEquip", function(player, itemId)
	local item = type(itemId) == "string" and items[itemId]
	if not item or not PlayerData.owns(player, item.Id) then
		return
	end
	local data = shopData(player)
	if item.Kind == "Trail" then
		data.Trail = if data.Trail == item.Id then nil else item.Id
	elseif item.Kind == "Pet" then
		local index = table.find(data.Pets, item.Id)
		if index then
			table.remove(data.Pets, index)
		elseif #data.Pets < config.MaxPets then
			table.insert(data.Pets, item.Id)
		else
			Net.notify(player, `You can equip {config.MaxPets} pets at most.`, "error")
			return
		end
	end
	publish(player)
	applyAll(player)
end, 4)

Util.onTag("ShopStand", function(instance)
	if not instance:IsA("BasePart") or instance:FindFirstChild("GK_Shop") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Shop"
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = "Shop"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
end)

PlayerData.onLoaded(function(player)
	publish(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyAll(player)
	end)
	applyAll(player)
end)
