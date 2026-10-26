-- GameKit Levels (ServerScriptService.GameKit.Levels)
-- XP and levels. XP is a normal stat: any reward can give it ({ XP = 25 } in quests,
-- checkpoints, rounds...) or any script with PlayerData.reward(player, "XP", 25).
-- XP can also come automatically from other stats (Config.Levels.XPFrom = { Coins = 0.2 }).
-- Each level needs more XP (BaseXP x Growth^level). Level-ups show a toast and give
-- LevelRewards (x the new level). Attributes for UIs: Level, XP, XPLevelStart, XPNextLevel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("Levels", {
	XPStat = "XP",
	LevelStat = "Level",
	BaseXP = 100,
	Growth = 1.25,
	MaxLevel = 100,
	XPFrom = { Coins = 0.2 },
	LevelRewards = { Coins = 25 },
	Effect = true,
})

local XP, LEVEL = config.XPStat, config.LevelStat
PlayerData.defineStat({ Name = XP, Default = 0, Leaderstat = false })
PlayerData.defineStat({ Name = LEVEL, Default = 1, Leaderstat = true })
for stat in pairs(config.LevelRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
end

-- Total XP needed to reach `level` (level 1 = 0 XP).
local function totalFor(level: number): number
	local total = 0
	for l = 1, level - 1 do
		total += math.floor(config.BaseXP * config.Growth ^ (l - 1))
	end
	return total
end

local function levelFor(xp: number): number
	local level = 1
	while level < config.MaxLevel and xp >= totalFor(level + 1) do
		level += 1
	end
	return level
end

local function publish(player: Player)
	local level = PlayerData.get(player, LEVEL)
	player:SetAttribute("XPLevelStart", totalFor(level))
	player:SetAttribute("XPNextLevel", if level >= config.MaxLevel then totalFor(level) else totalFor(level + 1))
end

local function celebrate(player: Player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not config.Effect or not root then
		return
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Rate = 0
	sparkles.Speed = NumberRange.new(6, 12)
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
	sparkles.Parent = root
	sparkles:Emit(40)
	task.delay(2, function()
		sparkles:Destroy()
	end)
end

local function check(player: Player)
	local xp = PlayerData.get(player, XP)
	local current = PlayerData.get(player, LEVEL)
	local target = levelFor(xp)
	if target > current then
		PlayerData.set(player, LEVEL, target)
		for level = current + 1, target do
			for stat, amount in pairs(config.LevelRewards) do
				PlayerData.reward(player, stat, amount * level, "Gameplay")
			end
			Analytics.progression(player, "Levels", level, `Level {level}`)
		end
		Net.notify(player, `⭐ Level {target}!`, "reward")
		celebrate(player)
	end
	publish(player)
end

-- Gives XP from gains of other stats (fractions add up over time).
local partial: { [Player]: number } = {}
for stat, rate in pairs(config.XPFrom) do
	PlayerData.onChanged(stat, function(player, new, old)
		if new > old and rate > 0 then
			local gained = (new - old) * rate + (partial[player] or 0)
			local whole = math.floor(gained)
			partial[player] = gained - whole
			if whole > 0 then
				PlayerData.add(player, XP, whole)
			end
		end
	end)
end

PlayerData.onChanged(XP, function(player)
	check(player)
end)
PlayerData.onLoaded(check)
game:GetService("Players").PlayerRemoving:Connect(function(player)
	partial[player] = nil
end)

-- Test hook used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player, amount: number?)
	if action == "xp" then
		PlayerData.add(player, XP, amount or 0)
		return PlayerData.get(player, LEVEL)
	elseif action == "totalFor" then
		return totalFor(amount or 2)
	end
	return nil
end
hook.Parent = script
