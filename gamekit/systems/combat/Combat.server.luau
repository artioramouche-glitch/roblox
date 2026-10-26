-- GameKit Combat (ServerScriptService.GameKit.Combat)
-- A ready-to-use sword with server-side hit detection and kill rewards.
--   * Creates ServerStorage.GameKit.Tools.Sword (replace its parts to restyle it).
--   * Any Tool tagged "GKMelee" works as a melee weapon; attributes: Damage, Cooldown, Range.
--   * Kills give Config.Combat.KillRewards. Hits on NPCs are credited to the attacker.
-- Config.Combat.GiveSword: "Always" | "InRound" (only while player has InRound=true) | "Never"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Combat", {
	GiveSword = "Always",
	Damage = 25,
	Cooldown = 0.6,
	SwingWindow = 0.35,
	Range = 6,
	FriendlyFire = false,
	KillRewards = { Kills = 1, Coins = 10 },
	BladeColor = "#D7DCE6",
	HiltColor = "#6B4226",
})

for stat in pairs(config.KillRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
end

-- Sword template --------------------------------------------------------------------------
local function toolsFolder(): Folder
	local root = ServerStorage:FindFirstChild("GameKit")
	if not root then
		root = Instance.new("Folder")
		root.Name = "GameKit"
		root.Parent = ServerStorage
	end
	local tools = root:FindFirstChild("Tools")
	if not tools then
		tools = Instance.new("Folder")
		tools.Name = "Tools"
		tools.Parent = root
	end
	return tools :: Folder
end

local function weldTo(handle: BasePart, part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	part.Parent = handle
end

local function buildSword(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.CanBeDropped = false
	tool.ToolTip = "Click to swing"
	tool.GripPos = Vector3.new(0, 0, -1.9)
	tool.GripForward = Vector3.new(0, -1, 0)
	tool.GripRight = Vector3.new(1, 0, 0)
	tool.GripUp = Vector3.new(0, 0, 1)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.25, 0.7, 5)
	handle.Material = Enum.Material.Metal
	handle.Color = Util.color(config.BladeColor)
	handle.CanCollide = false
	handle.Parent = tool

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(0.35, 1.6, 0.3)
	guard.Color = Color3.fromRGB(212, 175, 55)
	guard.Material = Enum.Material.Metal
	guard.CFrame = handle.CFrame * CFrame.new(0, 0, -1.35)
	weldTo(handle, guard)

	local hilt = Instance.new("Part")
	hilt.Name = "Hilt"
	hilt.Size = Vector3.new(0.35, 0.4, 1.2)
	hilt.Color = Util.color(config.HiltColor)
	hilt.Material = Enum.Material.Wood
	hilt.CFrame = handle.CFrame * CFrame.new(0, 0, -2.05)
	weldTo(handle, hilt)

	local slash = Instance.new("Sound")
	slash.Name = "Slash"
	slash.SoundId = "rbxasset://sounds/swordslash.wav"
	slash.Volume = 0.6
	slash.Parent = handle

	tool:SetAttribute("Damage", config.Damage)
	tool:SetAttribute("Cooldown", config.Cooldown)
	tool:AddTag("GKMelee")
	return tool
end

local folder = toolsFolder()
if not folder:FindFirstChild("Sword") then
	buildSword().Parent = folder
end

-- Hits ------------------------------------------------------------------------------------
local function tagCreator(humanoid: Humanoid, attacker: Player)
	local old = humanoid:FindFirstChild("creator")
	if old then
		old:Destroy()
	end
	local creator = Instance.new("ObjectValue")
	creator.Name = "creator"
	creator.Value = attacker
	creator.Parent = humanoid
	Debris:AddItem(creator, 3)
end

local function canHit(attacker: Player, targetCharacter: Model): boolean
	if targetCharacter == attacker.Character then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(targetCharacter)
	if victim then
		if not config.FriendlyFire and attacker.Team and victim.Team == attacker.Team and not attacker.Neutral then
			return false
		end
		if targetCharacter:FindFirstChildOfClass("ForceField") then
			return false
		end
	end
	return true
end

local function hookMelee(instance: Instance)
	if not instance:IsA("Tool") then
		return
	end
	local tool = instance :: Tool
	if tool:GetAttribute("GK_Hooked") then
		return
	end
	tool:SetAttribute("GK_Hooked", true)
	local handle = tool:WaitForChild("Handle", 5) :: BasePart?
	if not handle then
		return
	end
	local swinging = false
	local lastSwing = 0
	local hitThisSwing: { [Humanoid]: boolean } = {}

	local function owner(): Player?
		local character = tool.Parent
		return if character and character:IsA("Model") then Players:GetPlayerFromCharacter(character) else nil
	end

	local function tryHit(part: BasePart)
		if not swinging then
			return
		end
		local attacker = owner()
		local character = part:FindFirstAncestorOfClass("Model")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not attacker or not character or not humanoid or humanoid.Health <= 0 or hitThisSwing[humanoid] then
			return
		end
		local root = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local range = tool:GetAttribute("Range")
		if root and (part.Position - root.Position).Magnitude > (if type(range) == "number" then range else config.Range) + 4 then
			return -- too far to be a real hit (anti-exploit sanity check)
		end
		if not canHit(attacker, character) then
			return
		end
		hitThisSwing[humanoid] = true
		tagCreator(humanoid, attacker)
		local damage = tool:GetAttribute("Damage")
		humanoid:TakeDamage(if type(damage) == "number" then damage else config.Damage)
	end

	(handle :: BasePart).Touched:Connect(tryHit)

	tool.Activated:Connect(function()
		local cooldown = tool:GetAttribute("Cooldown")
		local now = os.clock()
		if now - lastSwing < (if type(cooldown) == "number" then cooldown else config.Cooldown) then
			return
		end
		lastSwing = now
		swinging = true
		table.clear(hitThisSwing)
		-- The default character Animate script plays the slash when it sees this value.
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		Debris:AddItem(anim, 1)
		local sound = (handle :: BasePart):FindFirstChild("Slash")
		if sound and sound:IsA("Sound") then
			sound:Play()
		end
		-- Also check what is already overlapping the blade (Touched misses resting contacts).
		task.delay(0.12, function()
			if not swinging or not handle then
				return
			end
			local params = OverlapParams.new()
			local character = tool.Parent
			if character then
				params.FilterDescendantsInstances = { character }
				params.FilterType = Enum.RaycastFilterType.Exclude
			end
			for _, part in workspace:GetPartBoundsInBox(handle.CFrame, handle.Size + Vector3.new(2, 2, 2), params) do
				tryHit(part)
			end
		end)
		task.delay(config.SwingWindow, function()
			swinging = false
		end)
	end)
end

Util.onTag("GKMelee", hookMelee)

-- Kill rewards for player-vs-player -------------------------------------------------------
Util.onCharacter(function(character, victim)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local creator = humanoid:FindFirstChild("creator")
		local killer = if creator and creator:IsA("ObjectValue") then creator.Value else nil
		if killer and killer:IsA("Player") and killer ~= victim and killer.Parent then
			local parts = {}
			for stat, amount in pairs(config.KillRewards) do
				local given = PlayerData.reward(killer, stat, amount)
				table.insert(parts, `+{Util.formatNumber(given)} {stat}`)
			end
			Net.notify(killer, `You defeated {victim.DisplayName}! ` .. table.concat(parts, " "), "reward")
		end
	end)
end)

-- Giving swords ---------------------------------------------------------------------------
local function hasTool(player: Player, name: string): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	return (backpack ~= nil and backpack:FindFirstChild(name) ~= nil)
		or (player.Character ~= nil and player.Character:FindFirstChild(name) ~= nil)
end

local function removeTool(player: Player, name: string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in { backpack, player.Character } do
		local tool = container and container:FindFirstChild(name)
		if tool and tool:IsA("Tool") then
			tool:Destroy()
		end
	end
end

local function giveSword(player: Player)
	if hasTool(player, "Sword") then
		return
	end
	local template = toolsFolder():FindFirstChild("Sword")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if template and backpack then
		template:Clone().Parent = backpack
	end
end

local function refresh(player: Player)
	if config.GiveSword == "Always" or (config.GiveSword == "InRound" and player:GetAttribute("InRound") == true) then
		giveSword(player)
	elseif config.GiveSword == "InRound" then
		removeTool(player, "Sword")
	end
end

Util.onCharacter(function(_, player)
	task.wait(0.5)
	refresh(player)
end)
Util.onPlayer(function(player)
	player:GetAttributeChangedSignal("InRound"):Connect(function()
		refresh(player)
	end)
end)
