-- GameKit Crafting (ServerScriptService.GameKit.Crafting)
-- Survival loop: gather -> craft -> build -> survive.
--   Gather: parts/models tagged "ResourceNode" (attribute Node = a name of Config.Crafting.Nodes:
--           Tree, Rock, Bush...). Hit them with the prompt; equipped tools with a Gather
--           attribute hit harder. They break, give items and grow back.
--   Craft:  the 🔨 window (anywhere, or only at "CraftingTable" parts if RequireTable) turns
--           items into items, tools (melee weapons / better gathering), builds and heals.
--   Build:  Campfire (heals nearby players), Wall (blocks enemies), Spikes (hurt enemies).
--   Hunger: optional (Hunger.Enabled): drains over time, eat food from the window.
-- Items live in the Inventory system (🎒 window).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local serverKit = ServerScriptService:WaitForChild("GameKit")
local PlayerData = require(serverKit:WaitForChild("PlayerData"))
local Analytics = require(serverKit:WaitForChild("Analytics"))
local Inventory = require(serverKit:WaitForChild("Inventory"))

local config = Util.config("Crafting", {
	Items = {
		Berry = { Name = "Berry", Icon = "🫐", SellPrice = 1 },
		Planks = { Name = "Planks", Icon = "🟫", SellPrice = 3 },
	},
	Nodes = {
		Tree = { Item = "Wood", Amount = 2, Hits = 3, Respawn = 20, Action = "Chop" },
		Rock = { Item = "Stone", Amount = 2, Hits = 4, Respawn = 25, Action = "Mine" },
		Bush = { Item = "Berry", Amount = 3, Hits = 1, Respawn = 15, Action = "Pick" },
	},
	Recipes = {
		{ Id = "Planks", Needs = { Wood = 2 }, Gives = 3 },
		{ Id = "StoneAxe", Name = "Stone Axe", Icon = "🪓", Kind = "Tool", Needs = { Wood = 3, Stone = 2 }, Damage = 20, Gather = 2 },
		{ Id = "StoneSword", Name = "Stone Sword", Icon = "🗡", Kind = "Tool", Needs = { Planks = 2, Stone = 4 }, Damage = 35, Gather = 1 },
		{ Id = "Campfire", Name = "Campfire", Icon = "🔥", Kind = "Build", Needs = { Wood = 5, Stone = 3 } },
		{ Id = "Wall", Name = "Wooden Wall", Icon = "🧱", Kind = "Build", Needs = { Planks = 4 } },
		{ Id = "Spikes", Name = "Spikes", Icon = "📌", Kind = "Build", Needs = { Planks = 2, Stone = 2 } },
		{ Id = "Bandage", Name = "Bandage", Icon = "🩹", Kind = "Heal", Needs = { Berry = 4 }, Heal = 40 },
	},
	RequireTable = false,
	MaxBuilds = 25,
	CraftRewards = { XP = 5 },
	Hunger = { Enabled = false, Max = 100, DrainPerMinute = 6, StarveDamage = 4, Food = { Berry = 12 } },
})

type Recipe = {
	Id: string,
	Name: string?,
	Icon: string?,
	Kind: string?,
	Needs: { [string]: number }?,
	Gives: number?,
	Damage: number?,
	Gather: number?,
	Heal: number?,
}

for itemId, def in config.Items do
	Inventory.define(itemId, def)
end
for stat in pairs(config.CraftRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = stat ~= "XP" })
end

local recipes: { [string]: Recipe } = {}
local published = {}
for index, recipe in config.Recipes do
	if type(recipe) == "table" and type(recipe.Id) == "string" then
		recipes[recipe.Id] = recipe
		if (recipe.Kind or "Item") == "Item" and not Inventory.def(recipe.Id) then
			Inventory.define(recipe.Id, { Name = recipe.Name or recipe.Id, Icon = recipe.Icon or "📦", SellPrice = 1 })
		end
		table.insert(published, { id = recipe.Id, name = recipe.Name or recipe.Id, icon = recipe.Icon or "📦", kind = recipe.Kind or "Item", needs = recipe.Needs or {}, order = index })
	end
end
kit:SetAttribute("Recipes", HttpService:JSONEncode(published))
kit:SetAttribute("Food", HttpService:JSONEncode(if config.Hunger.Enabled then config.Hunger.Food else {}))

local buildsFolder = Instance.new("Folder")
buildsFolder.Name = "GameKitBuilds"
buildsFolder.Parent = workspace

-- Gathering ----------------------------------------------------------------------------------

local function nodeParts(node: Instance): { BasePart }
	if node:IsA("BasePart") then
		return { node }
	end
	local parts = {}
	for _, descendant in node:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function gatherPower(player: Player): number
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local bonus = tool and tool:GetAttribute("Gather")
	return 1 + (if type(bonus) == "number" then bonus else 0)
end

local function setNodeVisible(node: Instance, visible: boolean)
	for _, part in nodeParts(node) do
		if visible then
			part.Transparency = part:GetAttribute("GK_Transparency") or 0
			part.CanCollide = part:GetAttribute("GK_CanCollide") ~= false
		else
			part:SetAttribute("GK_Transparency", part.Transparency)
			part:SetAttribute("GK_CanCollide", part.CanCollide)
			part.Transparency = 1
			part.CanCollide = false
		end
	end
end

local function hitNode(player: Player, node: Instance, prompt: ProximityPrompt): number
	local def = config.Nodes[tostring(node:GetAttribute("Node") or "Tree")]
	if not def or node:GetAttribute("Broken") then
		return 0
	end
	local current = node:GetAttribute("Hits")
	local hits = (if type(current) == "number" then current else 0) + gatherPower(player)
	if hits < (def.Hits or 1) then
		node:SetAttribute("Hits", hits)
		return 0
	end
	node:SetAttribute("Hits", 0)
	node:SetAttribute("Broken", true)
	prompt.Enabled = false
	local amount = def.Amount or 1
	Inventory.give(player, def.Item, amount)
	local itemDef = Inventory.def(def.Item)
	Net.notify(player, `+{amount} {(itemDef and itemDef.Icon) or ""} {(itemDef and itemDef.Name) or def.Item}`, "reward")
	setNodeVisible(node, false)
	task.delay(def.Respawn or 20, function()
		setNodeVisible(node, true)
		node:SetAttribute("Broken", nil)
		prompt.Enabled = true
	end)
	return amount
end

Util.onTag("ResourceNode", function(node)
	local def = config.Nodes[tostring(node:GetAttribute("Node") or "Tree")]
	local anchor = nodeParts(node)[1]
	if not def or not anchor then
		warn(`[GameKit] ResourceNode {node:GetFullName()}: set attribute Node to one of Config.Crafting.Nodes`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Gather"
	prompt.ActionText = def.Action or "Gather"
	prompt.ObjectText = tostring(node:GetAttribute("Node") or "Tree")
	prompt.HoldDuration = 0.35
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = anchor
	local cooldown = Util.cooldown(0.3)
	prompt.Triggered:Connect(function(player)
		if cooldown(player) then
			hitNode(player, node, prompt)
		end
	end)
end)

-- Crafting -----------------------------------------------------------------------------------

local function nearTable(player: Player): boolean
	if not config.RequireTable then
		return true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	for _, bench in CollectionService:GetTagged("CraftingTable") do
		if bench:IsA("BasePart") and (bench.Position - root.Position).Magnitude < 16 then
			return true
		end
	end
	return false
end

local function makeTool(recipe: Recipe): Tool
	local tool = Instance.new("Tool")
	tool.Name = recipe.Name or recipe.Id
	tool.ToolTip = recipe.Name or recipe.Id
	tool.CanBeDropped = false
	tool:SetAttribute("Damage", recipe.Damage or 20)
	tool:SetAttribute("Cooldown", 0.6)
	tool:SetAttribute("Range", 7)
	tool:SetAttribute("Gather", recipe.Gather or 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 3.6, 0.4)
	handle.Color = Color3.fromRGB(121, 85, 58)
	handle.Material = Enum.Material.Wood
	handle.Parent = tool
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = if recipe.Gather and recipe.Gather > 1 then Vector3.new(1.4, 0.8, 0.3) else Vector3.new(0.3, 2.4, 0.5)
	head.Color = Color3.fromRGB(140, 140, 150)
	head.Material = Enum.Material.Slate
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 1.8 + head.Size.Y / 2, 0)
	head.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle
	tool.Grip = CFrame.new(0, -1, 0)
	CollectionService:AddTag(tool, "GKMelee")
	return tool
end

local function buildCount(player: Player): number
	local count = 0
	for _, model in buildsFolder:GetChildren() do
		if model:GetAttribute("Owner") == player.UserId then
			count += 1
		end
	end
	return count
end

local function part(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = model
	return p
end

local function placeBuild(player: Player, recipe: Recipe): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local front = root.CFrame * CFrame.new(0, 0, -7)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character :: Model, buildsFolder }
	local hit = workspace:Raycast(front.Position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	local ground = if hit then hit.Position else front.Position - Vector3.new(0, 3, 0)
	local base = CFrame.lookAt(ground, ground + root.CFrame.LookVector * Vector3.new(1, 0, 1))
	local model = Instance.new("Model")
	model.Name = recipe.Id
	model:SetAttribute("Owner", player.UserId)
	if recipe.Id == "Campfire" then
		part(model, { Name = "Stones", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 5, 5), CFrame = base * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(110, 110, 115), Material = Enum.Material.Slate })
		local logs = part(model, { Name = "Logs", Size = Vector3.new(3, 1, 1), CFrame = base * CFrame.new(0, 1.2, 0), Color = Color3.fromRGB(101, 67, 33), Material = Enum.Material.Wood, CanCollide = false })
		Instance.new("Fire").Parent = logs
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 80)
		light.Range = 24
		light.Brightness = 2
		light.Parent = logs
		CollectionService:AddTag(model, "GKCampfire")
	elseif recipe.Id == "Spikes" then
		local plate = part(model, { Name = "Spikes", Size = Vector3.new(6, 0.6, 6), CFrame = base * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.DiamondPlate, CanCollide = false })
		local cooldown = {}
		plate.Touched:Connect(function(hitPart)
			local enemy = hitPart:FindFirstAncestorWhichIsA("Model")
			local humanoid = enemy and enemy:FindFirstChildOfClass("Humanoid")
			if enemy and humanoid and CollectionService:HasTag(enemy, "Enemy") and (cooldown[enemy] or 0) < os.clock() then
				cooldown[enemy] = os.clock() + 0.8
				humanoid:TakeDamage(20)
			end
		end)
	else
		part(model, { Name = "Wall", Size = Vector3.new(10, 8, 1), CFrame = base * CFrame.new(0, 4, 0), Color = Color3.fromRGB(150, 105, 60), Material = Enum.Material.WoodPlanks })
	end
	model.Parent = buildsFolder
	return model
end

local function craft(player: Player, recipeId: string): boolean
	local recipe = recipes[recipeId]
	if not recipe or not PlayerData.isLoaded(player) then
		return false
	end
	if not nearTable(player) then
		Net.notify(player, "Go to a crafting table 🔨", "error")
		return false
	end
	local kind = recipe.Kind or "Item"
	if kind == "Build" and buildCount(player) >= config.MaxBuilds then
		Net.notify(player, `You can place {config.MaxBuilds} builds.`, "error")
		return false
	end
	local needs = recipe.Needs or {}
	for itemId, amount in needs do
		if Inventory.count(player, itemId) < amount then
			local def = Inventory.def(itemId)
			Net.notify(player, `Needs {amount} {(def and def.Name) or itemId}`, "error")
			return false
		end
	end
	for itemId, amount in needs do
		Inventory.take(player, itemId, amount)
	end
	if kind == "Tool" then
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			makeTool(recipe).Parent = backpack
		end
	elseif kind == "Build" then
		placeBuild(player, recipe)
	elseif kind == "Heal" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (recipe.Heal or 30))
		end
	else
		Inventory.give(player, recipe.Id, recipe.Gives or 1)
	end
	for stat, amount in pairs(config.CraftRewards) do
		PlayerData.reward(player, stat, amount, "Gameplay")
	end
	Net.notify(player, `🔨 {recipe.Icon or ""} {recipe.Name or recipe.Id}`, "success")
	Analytics.custom(player, "Craft_" .. recipe.Id, 1)
	return true
end

Net.on("Craft", function(player, recipeId)
	if type(recipeId) == "string" then
		craft(player, recipeId)
	end
end, 4)

Util.onTag("CraftingTable", function(bench)
	if not bench:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Craft"
	prompt.ActionText = "Craft"
	prompt.ObjectText = "Crafting table"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = bench
	prompt.Triggered:Connect(function(player)
		Net.fire(player, "OpenCrafting")
	end)
end)

-- Campfires heal players around them.
task.spawn(function()
	while true do
		task.wait(2)
		local fires = CollectionService:GetTagged("GKCampfire")
		if #fires > 0 then
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
					for _, fire in fires do
						if fire:IsA("Model") and (fire:GetPivot().Position - root.Position).Magnitude < 16 then
							humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 4)
							break
						end
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for _, model in buildsFolder:GetChildren() do
		if model:GetAttribute("Owner") == player.UserId then
			model:Destroy()
		end
	end
end)

-- Hunger -------------------------------------------------------------------------------------

local hunger = config.Hunger
if hunger.Enabled then
	local function eat(player: Player, itemId: string)
		local value = hunger.Food[itemId]
		if type(value) ~= "number" or not Inventory.take(player, itemId, 1) then
			return
		end
		local current = player:GetAttribute("Hunger")
		player:SetAttribute("Hunger", math.min(hunger.Max, (if type(current) == "number" then current else hunger.Max) + value))
	end
	Net.on("Eat", function(player, itemId)
		if type(itemId) == "string" then
			eat(player, itemId)
		end
	end, 4)
	Util.onCharacter(function(_, player)
		player:SetAttribute("Hunger", hunger.Max)
		player:SetAttribute("HungerMax", hunger.Max)
	end)
	task.spawn(function()
		local step = 5
		while true do
			task.wait(step)
			for _, player in Players:GetPlayers() do
				local current = player:GetAttribute("Hunger")
				if type(current) == "number" then
					local nextValue = math.max(0, current - hunger.DrainPerMinute * step / 60)
					player:SetAttribute("Hunger", nextValue)
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if nextValue <= 0 and humanoid then
						humanoid:TakeDamage(hunger.StarveDamage)
					end
				end
			end
		end
	end)
end

-- Test hook used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player, recipeId: string?)
	if action == "craft" then
		local id = recipeId
		for _, r in config.Recipes do
			if not id and (r.Kind or "Item") == "Item" then
				id = r.Id
			end
		end
		local recipe = id and recipes[id]
		if not recipe then
			return nil
		end
		for itemId, amount in recipe.Needs or {} do
			Inventory.give(player, itemId, amount)
		end
		return craft(player, recipe.Id)
	elseif action == "gather" then
		local node = CollectionService:GetTagged("ResourceNode")[1]
		local anchor = node and nodeParts(node)[1]
		local prompt = anchor and anchor:FindFirstChild("GK_Gather")
		if node and prompt and prompt:IsA("ProximityPrompt") then
			local total = 0
			for _ = 1, 10 do
				total += hitNode(player, node, prompt)
				if total > 0 then
					break
				end
			end
			return total
		end
		return -1
	end
	return nil
end
hook.Parent = script
