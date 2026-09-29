-- GameKit Pets (ServerScriptService.GameKit.Pets)
-- Eggs and pets (gacha): hatch eggs at parts tagged "EggStand" (attribute Egg = a name from
-- Config.Pets.Eggs), get a random pet by chance, equip the best ones: each equipped pet
-- multiplies rewards of its stat (Coins, Power...). Pets follow their owner. Saved.
-- The 🐾 window lists pets (equip / unequip / equip best).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("Pets", {
	Stat = "Coins",
	MaxEquipped = 3,
	MaxOwned = 60,
	Eggs = {
		Basic = {
			Price = 100,
			Currency = "Coins",
			Color = "#F5F5F5",
			Pets = {
				{ Id = "Dog", Name = "Dog", Chance = 55, Multiplier = 1.2, Rarity = "Common", Color = "#C8A165" },
				{ Id = "Cat", Name = "Cat", Chance = 35, Multiplier = 1.5, Rarity = "Rare", Color = "#F5A623" },
				{ Id = "Dragon", Name = "Dragon", Chance = 10, Multiplier = 3, Rarity = "Legendary", Color = "#E53935" },
			},
		},
	},
	RarityColors = { Common = "#B0BEC5", Rare = "#42A5F5", Epic = "#AB47BC", Legendary = "#FFCA28" },
})

type PetDef = { Id: string, Name: string?, Chance: number?, Multiplier: number?, Rarity: string?, Color: string?, Stat: string? }

local petDefs: { [string]: PetDef } = {}
for _, egg in config.Eggs do
	PlayerData.defineStat({ Name = egg.Currency or config.Stat, Default = 0, Leaderstat = true })
	for _, pet in egg.Pets or {} do
		petDefs[pet.Id] = pet
	end
end
kit:SetAttribute("PetDefs", HttpService:JSONEncode(petDefs))
PlayerData.defineStat({ Name = config.Stat, Default = 0, Leaderstat = true })

local random = Random.new()

local function data(player: Player): { Owned: { string }, Equipped: { number } }
	local section = PlayerData.section(player, "Pets")
	section.Owned = section.Owned or {}
	section.Equipped = section.Equipped or {}
	return section :: any
end

local function multiplierOf(petId: string): number
	local def = petDefs[petId]
	return if def and type(def.Multiplier) == "number" then def.Multiplier else 1
end

-- Clients read the list from attributes: Pets = "Dog,Cat,...", PetsEquipped = "1,3" (indexes).
local function publish(player: Player)
	local d = data(player)
	player:SetAttribute("Pets", table.concat(d.Owned, ","))
	local equipped = {}
	for _, index in d.Equipped do
		table.insert(equipped, tostring(index))
	end
	player:SetAttribute("PetsEquipped", table.concat(equipped, ","))
end

-- Pets follow the character (same technique as Shop pets, on the other side).
local function buildPet(petId: string): Model
	local def = petDefs[petId]
	local model = Instance.new("Model")
	model.Name = "GK_EggPet_" .. petId
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * (if def and def.Rarity == "Legendary" then 2.4 else 1.8)
	body.Color = Util.color(def and def.Color, Color3.fromRGB(255, 200, 120))
	body.Material = if def and def.Rarity == "Legendary" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.Parent = model
	model.PrimaryPart = body
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(90, 24)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	tag.MaxDistance = 60
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.Text = (def and def.Name) or petId
	text.TextColor3 = Util.color(config.RarityColors[(def and def.Rarity) or "Common"], Color3.new(1, 1, 1))
	text.TextStrokeTransparency = 0.3
	text.Parent = tag
	tag.Parent = body
	return model
end

local function applyPets(player: Player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	for _, child in character:GetChildren() do
		if string.sub(child.Name, 1, 10) == "GK_EggPet_" then
			child:Destroy()
		end
	end
	for _, child in root:GetChildren() do
		if child.Name == "GK_EggPetAnchor" then
			child:Destroy()
		end
	end
	local d = data(player)
	for slot, index in d.Equipped do
		local petId = d.Owned[index]
		if petId then
			local pet = buildPet(petId)
			local body = pet.PrimaryPart :: BasePart
			local angle = (slot - 1) * math.pi * 0.4 - math.pi * 0.2
			local offset = Vector3.new(math.sin(angle) * 5, 1.5, math.cos(angle) * 5)
			body.CFrame = root.CFrame + offset
			local petAttachment = Instance.new("Attachment")
			petAttachment.Parent = body
			local anchor = Instance.new("Attachment")
			anchor.Name = "GK_EggPetAnchor"
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

local function equipBest(player: Player)
	local d = data(player)
	local order = {}
	for index in d.Owned do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		return multiplierOf(d.Owned[a]) > multiplierOf(d.Owned[b])
	end)
	d.Equipped = {}
	for i = 1, math.min(config.MaxEquipped, #order) do
		table.insert(d.Equipped, order[i])
	end
	publish(player)
	applyPets(player)
end

local function roll(egg: { [string]: any }): string?
	local total = 0
	for _, pet in egg.Pets or {} do
		total += pet.Chance or 1
	end
	local pick = random:NextNumber(0, total)
	for _, pet in egg.Pets or {} do
		pick -= pet.Chance or 1
		if pick <= 0 then
			return pet.Id
		end
	end
	local last = egg.Pets and egg.Pets[#egg.Pets]
	return last and last.Id
end

local function hatch(player: Player, eggName: string): string?
	local egg = config.Eggs[eggName]
	if not egg or not PlayerData.isLoaded(player) then
		return nil
	end
	local d = data(player)
	if #d.Owned >= config.MaxOwned then
		Net.notify(player, `Your pet storage is full ({config.MaxOwned}).`, "error")
		return nil
	end
	local currency = egg.Currency or config.Stat
	if (egg.Price or 0) > 0 and not PlayerData.spend(player, currency, egg.Price, eggName .. "Egg", "Shop") then
		Net.notify(player, `This egg costs {Util.formatNumber(egg.Price)} {currency}.`, "error")
		return nil
	end
	local petId = roll(egg)
	if not petId then
		return nil
	end
	table.insert(d.Owned, petId)
	if #d.Equipped < config.MaxEquipped then
		table.insert(d.Equipped, #d.Owned)
		applyPets(player)
	end
	publish(player)
	local def = petDefs[petId]
	Net.fire(player, "PetHatched", petId, (def and def.Name) or petId, (def and def.Rarity) or "Common")
	Analytics.custom(player, "Hatch_" .. ((def and def.Rarity) or "Common"), 1)
	return petId
end

PlayerData.addMultiplier(function(player, stat)
	local d = data(player)
	local total = 1
	for _, index in d.Equipped do
		local petId = d.Owned[index]
		local def = petId and petDefs[petId]
		if def and (def.Stat or config.Stat) == stat then
			total *= multiplierOf(petId)
		end
	end
	return total
end)

Util.onTag("EggStand", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local eggName = tostring(instance:GetAttribute("Egg") or "Basic")
	local egg = config.Eggs[eggName]
	if not egg then
		warn(`[GameKit] EggStand {instance:GetFullName()}: no egg "{eggName}" in Config.Pets.Eggs`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Egg"
	prompt.ActionText = `Hatch ({Util.formatNumber(egg.Price or 0)} {egg.Currency or config.Stat})`
	prompt.ObjectText = `{eggName} egg`
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = instance
	local cooldown = Util.cooldown(1.2)
	prompt.Triggered:Connect(function(player)
		if cooldown(player) then
			hatch(player, eggName)
		end
	end)
end)

Net.on("PetEquip", function(player, index)
	local d = data(player)
	if type(index) ~= "number" or not d.Owned[index] then
		return
	end
	local at = table.find(d.Equipped, index)
	if at then
		table.remove(d.Equipped, at)
	elseif #d.Equipped < config.MaxEquipped then
		table.insert(d.Equipped, index)
	else
		Net.notify(player, `You can equip {config.MaxEquipped} pets.`, "error")
		return
	end
	publish(player)
	applyPets(player)
end, 5)
Net.on("PetEquipBest", equipBest, 2)

PlayerData.onLoaded(function(player)
	publish(player)
	applyPets(player)
end)
Util.onCharacter(function(_, player)
	task.wait(0.5)
	applyPets(player)
end)

-- Test hook used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player, eggName: string?)
	if action == "hatch" then
		local egg = config.Eggs[eggName or "Basic"]
		if egg then
			PlayerData.add(player, egg.Currency or config.Stat, egg.Price or 0)
		end
		return hatch(player, eggName or "Basic")
	elseif action == "multiplier" then
		return PlayerData.getMultiplier(player, config.Stat)
	end
	return nil
end
hook.Parent = script
