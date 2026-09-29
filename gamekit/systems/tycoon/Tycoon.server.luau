-- GameKit Tycoon (ServerScriptService.GameKit.Tycoon)
-- Plots are Models/Folders tagged "TycoonPlot" containing:
--   Claim   (BasePart)  touch to claim the plot (one plot per player)
--   Buttons (Folder)    BaseParts with attributes:
--                         Item (name of a child of Items), Price (number),
--                         Requires (optional item name that must be bought first)
--   Items   (Folder)    everything that can be bought; hidden until purchased
-- Inside items: parts tagged "Dropper" (DropValue, DropInterval, OreColor),
--   "Upgrader" (Multiplier) and "Collector" (turns ore into cash for the owner).
-- Conveyors use the "Conveyor" tag (Movers system). Purchases are saved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Tycoon", {
	Currency = "Cash",
	StartingCash = 0,
	MaxOrePerPlot = 60,
	OreLifetime = 30,
	PassiveIncome = 0,
})

local CURRENCY = config.Currency
PlayerData.defineStat({ Name = CURRENCY, Default = config.StartingCash, Leaderstat = true })

type Plot = {
	model: Instance,
	owner: Player?,
	storage: Folder,
	items: Folder,
	buttons: { BasePart },
	claim: BasePart?,
	ore: number,
}

local plots: { [Instance]: Plot } = {}
local plotOf: { [Player]: Plot } = {}

local storageRoot = ServerStorage:FindFirstChild("GameKitTycoon")
if not storageRoot then
	storageRoot = Instance.new("Folder")
	storageRoot.Name = "GameKitTycoon"
	storageRoot.Parent = ServerStorage
end

local function label(part: BasePart, text: string, color: Color3?)
	local gui = part:FindFirstChild("GK_Label") :: BillboardGui?
	if not gui then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "GK_Label"
		billboard.Size = UDim2.fromOffset(220, 60)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 80
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "Text"
		textLabel.BackgroundTransparency = 1
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.Font = Enum.Font.FredokaOne
		textLabel.TextScaled = true
		textLabel.TextStrokeTransparency = 0.3
		textLabel.Parent = billboard
		billboard.Parent = part
		gui = billboard
	end
	local textLabel = (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel
	textLabel.Text = text
	textLabel.TextColor3 = color or Color3.new(1, 1, 1)
end

local function attr(instance: Instance, name: string, default: any): any
	local value = instance:GetAttribute(name)
	return if value == nil then default else value
end

local function setButtonVisible(button: BasePart, visible: boolean)
	button.Transparency = if visible then 0 else 1
	button.CanCollide = false
	button.CanTouch = visible
	local gui = button:FindFirstChild("GK_Label")
	if gui and gui:IsA("BillboardGui") then
		gui.Enabled = visible
	end
end

local function bought(plot: Plot): { [string]: boolean }
	if not plot.owner then
		return {}
	end
	local data = PlayerData.section(plot.owner, "Tycoon")
	data.Bought = data.Bought or {}
	return data.Bought
end

local function refreshButtons(plot: Plot)
	local owned = bought(plot)
	for _, button in ipairs(plot.buttons) do
		local item = attr(button, "Item", "")
		local requires = attr(button, "Requires", nil)
		local visible = plot.owner ~= nil and not owned[item] and (requires == nil or requires == "" or owned[requires] == true)
		setButtonVisible(button, visible)
	end
end

local function placeItem(plot: Plot, itemName: string)
	if plot.items:FindFirstChild(itemName) then
		return
	end
	local template = plot.storage:FindFirstChild(itemName)
	if not template then
		warn(`[GameKit] Tycoon: item '{itemName}' not found in {plot.model:GetFullName()}.Items`)
		return
	end
	template:Clone().Parent = plot.items
end

local function resetPlot(plot: Plot)
	plot.items:ClearAllChildren()
	if plot.owner then
		plotOf[plot.owner] = nil
	end
	plot.owner = nil
	plot.model:SetAttribute("Owner", nil)
	if plot.claim then
		plot.claim.CanTouch = true
		label(plot.claim, "Touch to claim!", Color3.fromRGB(120, 255, 120))
	end
	refreshButtons(plot)
end

local function claimPlot(plot: Plot, player: Player)
	if plot.owner or plotOf[player] or not PlayerData.isLoaded(player) then
		return
	end
	plot.owner = player
	plotOf[player] = plot
	plot.model:SetAttribute("Owner", player.UserId)
	if plot.claim then
		label(plot.claim, player.DisplayName .. "'s Tycoon", Color3.fromRGB(255, 220, 90))
	end
	for itemName in pairs(bought(plot)) do
		placeItem(plot, itemName)
	end
	refreshButtons(plot)
	Net.notify(player, "This tycoon is yours! Step on buttons to build.", "success")
end

local function onButton(plot: Plot, button: BasePart, hit: BasePart)
	local player = Util.playerFromHit(hit)
	if not player or plot.owner ~= player or button.Transparency >= 1 then
		return
	end
	local itemName = attr(button, "Item", "")
	local owned = bought(plot)
	if owned[itemName] then
		return
	end
	local price = attr(button, "Price", 0)
	if not PlayerData.spend(player, CURRENCY, price, itemName, "Shop") then
		Net.notify(player, `You need {Util.formatNumber(price)} {CURRENCY}!`, "error")
		return
	end
	owned[itemName] = true
	placeItem(plot, itemName)
	refreshButtons(plot)
end

-- Ore ------------------------------------------------------------------------------------
local function spawnOre(plot: Plot, dropper: BasePart)
	if not plot.owner or plot.ore >= config.MaxOrePerPlot then
		return
	end
	local ore = Instance.new("Part")
	ore.Name = "Ore"
	ore.Size = Vector3.new(1, 1, 1)
	ore.Color = Util.color(attr(dropper, "OreColor", "#FFD24A"))
	ore.Material = Enum.Material.Neon
	ore.TopSurface = Enum.SurfaceType.Smooth
	ore.BottomSurface = Enum.SurfaceType.Smooth
	ore.CFrame = dropper.CFrame * CFrame.new(0, -dropper.Size.Y / 2 - 0.8, 0)
	ore:SetAttribute("GK_OreValue", attr(dropper, "DropValue", 5))
	ore:SetAttribute("GK_Plot", plot.model:GetFullName())
	ore.Parent = plot.items
	pcall(function()
		ore:SetNetworkOwner(nil)
	end)
	plot.ore += 1
	ore.Destroying:Connect(function()
		plot.ore -= 1
	end)
	Debris:AddItem(ore, config.OreLifetime)
end

local function hookItemParts(plot: Plot, root: Instance, allowDroppers: boolean)
	local function hook(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		if allowDroppers and CollectionService:HasTag(part, "Dropper") then
			task.spawn(function()
				while part.Parent and part:IsDescendantOf(plot.items) do
					task.wait(attr(part, "DropInterval", 2))
					if part.Parent then
						spawnOre(plot, part)
					end
				end
			end)
		end
		if CollectionService:HasTag(part, "Collector") then
			part.Touched:Connect(function(hit)
				local value = hit:GetAttribute("GK_OreValue")
				if type(value) == "number" and hit:GetAttribute("GK_Plot") == plot.model:GetFullName() then
					hit:SetAttribute("GK_OreValue", nil)
					hit:Destroy()
					if plot.owner then
						PlayerData.reward(plot.owner, CURRENCY, value)
					end
				end
			end)
		end
		if CollectionService:HasTag(part, "Upgrader") then
			part.Touched:Connect(function(hit)
				local value = hit:GetAttribute("GK_OreValue")
				local key = "GK_Up_" .. part.Name
				if type(value) == "number" and not hit:GetAttribute(key) then
					hit:SetAttribute(key, true)
					hit:SetAttribute("GK_OreValue", value * attr(part, "Multiplier", 2))
				end
			end)
		end
	end
	hook(root)
	for _, descendant in root:GetDescendants() do
		hook(descendant)
	end
end

-- Setup ----------------------------------------------------------------------------------
local function setupPlot(model: Instance)
	if plots[model] then
		return
	end
	local itemsFolder = model:FindFirstChild("Items")
	local buttonsFolder = model:FindFirstChild("Buttons")
	if not itemsFolder or not buttonsFolder then
		warn(`[GameKit] Tycoon plot {model:GetFullName()} needs "Items" and "Buttons" folders`)
		return
	end
	-- Hide every purchasable item in ServerStorage; bought ones are cloned back in.
	local storage = Instance.new("Folder")
	storage.Name = model.Name
	storage.Parent = storageRoot
	for _, child in itemsFolder:GetChildren() do
		child.Parent = storage
	end
	local plot: Plot = {
		model = model,
		owner = nil,
		storage = storage,
		items = itemsFolder :: Folder,
		buttons = {},
		claim = nil,
		ore = 0,
	}
	for _, button in buttonsFolder:GetDescendants() do
		if button:IsA("BasePart") then
			table.insert(plot.buttons, button)
			local item = attr(button, "Item", "?")
			label(button, `{item}\n💵 {Util.formatNumber(attr(button, "Price", 0))}`)
			button.Touched:Connect(function(hit)
				onButton(plot, button, hit)
			end)
		end
	end
	itemsFolder.ChildAdded:Connect(function(child)
		hookItemParts(plot, child, true)
	end)
	-- Collectors/upgraders that are part of the plot itself (not purchasable).
	hookItemParts(plot, model, false)
	local claim = model:FindFirstChild("Claim")
	if claim and claim:IsA("BasePart") then
		plot.claim = claim
		claim.Touched:Connect(function(hit)
			local player = Util.playerFromHit(hit)
			if player then
				claimPlot(plot, player)
			end
		end)
	end
	plots[model] = plot
	resetPlot(plot)
end

Util.onTag("TycoonPlot", setupPlot)

Players.PlayerRemoving:Connect(function(player)
	local plot = plotOf[player]
	if plot then
		resetPlot(plot)
	end
end)

if config.PassiveIncome > 0 then
	task.spawn(function()
		while true do
			task.wait(1)
			for player in plotOf do
				PlayerData.reward(player, CURRENCY, config.PassiveIncome)
			end
		end
	end)
end
