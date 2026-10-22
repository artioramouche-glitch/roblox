-- GameKit Fishing (ServerScriptService.GameKit.Fishing)
-- Fish at parts tagged "FishingSpot" (attribute Zone = a zone of Config.Fishing.Zones):
--   "Fish" prompt -> the bobber lands -> wait for a bite -> press REEL in time -> catch!
-- Caught fish go to the Inventory (sell them at "ItemSell" parts or in the 🎒 window).
-- Rod level (stat RodStat, raise it with a Shop "Upgrade" item) bites faster, finds rarer
-- fish and unlocks zones with MinRod. Fish count stat (CatchStat) works with Quests/Leaderboard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local serverKit = ServerScriptService:WaitForChild("GameKit")
local PlayerData = require(serverKit:WaitForChild("PlayerData"))
local Analytics = require(serverKit:WaitForChild("Analytics"))
local Inventory = require(serverKit:WaitForChild("Inventory"))

local config = Util.config("Fishing", {
	Zones = {
		Pond = {
			MinRod = 0,
			Fish = {
				{ Id = "Minnow", Name = "Minnow", Icon = "🐟", Chance = 60, SellPrice = 3, Rarity = "Common" },
				{ Id = "Salmon", Name = "Salmon", Icon = "🐠", Chance = 30, SellPrice = 12, Rarity = "Rare" },
				{ Id = "GoldenKoi", Name = "Golden Koi", Icon = "✨", Chance = 10, SellPrice = 60, Rarity = "Legendary" },
			},
		},
		Ocean = {
			MinRod = 2,
			Fish = {
				{ Id = "Pufferfish", Name = "Pufferfish", Icon = "🐡", Chance = 50, SellPrice = 15, Rarity = "Common" },
				{ Id = "Tuna", Name = "Tuna", Icon = "🐟", Chance = 38, SellPrice = 30, Rarity = "Rare" },
				{ Id = "Shark", Name = "Shark", Icon = "🦈", Chance = 12, SellPrice = 150, Rarity = "Epic" },
			},
		},
	},
	RodStat = "RodLevel",
	BiteSeconds = { 2, 6 },
	ReelWindow = 1.6,
	FasterPerRod = 0.15,
	LuckPerRod = 0.1,
	CatchStat = "Fish",
	CatchRewards = { XP = 5 },
})

type Fish = { Id: string, Name: string?, Icon: string?, Chance: number?, SellPrice: number?, Rarity: string? }
type Session = { spot: BasePart, bobber: BasePart, state: string, biteAt: number, token: number }

PlayerData.defineStat({ Name = config.RodStat, Default = 0 })
PlayerData.defineStat({ Name = config.CatchStat, Default = 0, Leaderstat = true })
for stat in pairs(config.CatchRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = stat ~= "XP" })
end
for _, zone in config.Zones do
	for _, fish in zone.Fish or {} do
		Inventory.define(fish.Id, { Name = fish.Name or fish.Id, Icon = fish.Icon or "🐟", SellPrice = fish.SellPrice or 1, Rarity = fish.Rarity or "Common" })
	end
end

local sessions: { [Player]: Session } = {}
local random = Random.new()
local counter = 0

local function rodOf(player: Player): number
	return PlayerData.get(player, config.RodStat)
end

local function roll(zone: { [string]: any }, rod: number): Fish?
	local list = zone.Fish or {}
	local weights = {}
	local total = 0
	for index, fish in list do
		local weight = fish.Chance or 1
		if fish.Rarity and fish.Rarity ~= "Common" then
			weight *= 1 + config.LuckPerRod * rod
		end
		weights[index] = weight
		total += weight
	end
	local pick = random:NextNumber(0, total)
	for index, fish in list do
		pick -= weights[index]
		if pick <= 0 then
			return fish
		end
	end
	return list[#list]
end

local function stop(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	if session then
		session.bobber:Destroy()
	end
	Net.fire(player, "FishState", "idle")
end

local function makeBobber(player: Player, spot: BasePart): BasePart
	local bobber = Instance.new("Part")
	bobber.Name = "GK_Bobber"
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.one * 0.8
	bobber.Color = Color3.fromRGB(230, 57, 53)
	bobber.Anchored = true
	bobber.CanCollide = false
	bobber.CanQuery = false
	bobber.CanTouch = false
	local half = spot.Size * 0.4
	local offset = Vector3.new(random:NextNumber(-half.X, half.X), spot.Size.Y / 2 + 0.3, random:NextNumber(-half.Z, half.Z))
	bobber.CFrame = spot.CFrame * CFrame.new(offset)
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("HumanoidRootPart"))
	if hand and hand:IsA("BasePart") then
		local a0 = Instance.new("Attachment")
		a0.Name = "GK_FishLine"
		a0.Parent = hand
		local a1 = Instance.new("Attachment")
		a1.Parent = bobber
		local line = Instance.new("Beam")
		line.Attachment0 = a0
		line.Attachment1 = a1
		line.Width0 = 0.05
		line.Width1 = 0.05
		line.Color = ColorSequence.new(Color3.new(1, 1, 1))
		line.FaceCamera = true
		line.Parent = bobber
		bobber.Destroying:Connect(function()
			a0:Destroy()
		end)
	end
	bobber.Parent = workspace
	return bobber
end

local function catch(player: Player, session: Session)
	local zone = config.Zones[tostring(session.spot:GetAttribute("Zone") or "Pond")] or {}
	local fish = roll(zone, rodOf(player))
	stop(player)
	if not fish then
		return nil
	end
	if Inventory.give(player, fish.Id, 1) == 0 then
		Net.notify(player, "Your bag is full! Sell some items.", "error")
		return nil
	end
	PlayerData.add(player, config.CatchStat, 1)
	for stat, amount in pairs(config.CatchRewards) do
		PlayerData.reward(player, stat, amount, "Gameplay")
	end
	Net.fire(player, "FishCaught", fish.Id, fish.Name or fish.Id, fish.Icon or "🐟", fish.Rarity or "Common")
	Analytics.custom(player, "Catch_" .. (fish.Rarity or "Common"), 1)
	return fish.Id
end

local function reel(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	if session.state == "bite" and os.clock() - session.biteAt <= config.ReelWindow + 0.35 then
		catch(player, session)
	elseif session.state == "waiting" then
		Net.notify(player, "Too early! Wait for the bobber to dip.", "error")
		stop(player)
	end
end

local function cast(player: Player, spot: BasePart)
	if sessions[player] then
		reel(player)
		return
	end
	local zoneName = tostring(spot:GetAttribute("Zone") or "Pond")
	local zone = config.Zones[zoneName]
	if not zone then
		warn(`[GameKit] FishingSpot {spot:GetFullName()}: no zone "{zoneName}" in Config.Fishing.Zones`)
		return
	end
	local rod = rodOf(player)
	if rod < (zone.MinRod or 0) then
		Net.notify(player, `🎣 {zoneName} needs rod level {zone.MinRod} (yours: {rod}).`, "error")
		return
	end
	counter += 1
	local session: Session = { spot = spot, bobber = makeBobber(player, spot), state = "waiting", biteAt = 0, token = counter }
	sessions[player] = session
	Net.fire(player, "FishState", "waiting")
	local range = config.BiteSeconds
	local waitTime = random:NextNumber(range[1] or 2, range[2] or 6) / (1 + config.FasterPerRod * rod)
	local started = os.clock()
	while os.clock() - started < waitTime do
		task.wait(0.25)
		if sessions[player] ~= session then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - session.bobber.Position).Magnitude > 60 then
			stop(player)
			return
		end
	end
	session.state = "bite"
	session.biteAt = os.clock()
	local dip = session.bobber.CFrame - Vector3.new(0, 0.6, 0)
	TweenService:Create(session.bobber, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 3, true), { CFrame = dip }):Play()
	Net.fire(player, "FishBite", config.ReelWindow)
	task.wait(config.ReelWindow + 0.4)
	if sessions[player] == session then
		Net.notify(player, "The fish got away...", "info")
		stop(player)
	end
end

Util.onTag("FishingSpot", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Fish"
	prompt.ActionText = "Fish"
	prompt.ObjectText = tostring(instance:GetAttribute("Zone") or "Pond")
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 20
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		cast(player, instance)
	end)
end)

Net.on("FishReel", reel, 4)
Net.on("FishCancel", stop, 2)
game:GetService("Players").PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	sessions[player] = nil
	if session then
		session.bobber:Destroy()
	end
end)

-- Test hook used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player, zoneName: string?)
	if action == "catch" then
		local zone = config.Zones[zoneName or "Pond"]
		local fish = zone and roll(zone, rodOf(player))
		if fish then
			Inventory.give(player, fish.Id, 1)
			PlayerData.add(player, config.CatchStat, 1)
			return fish.Id
		end
	elseif action == "zones" then
		local names = {}
		for name in config.Zones do
			table.insert(names, name)
		end
		return names
	end
	return nil
end
hook.Parent = script
