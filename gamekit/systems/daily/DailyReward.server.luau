-- GameKit Daily reward (ServerScriptService.GameKit.DailyReward)
-- Players can claim a reward every Config.DailyReward.CooldownHours hours. Claiming on
-- consecutive days builds a streak that increases the reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("DailyReward", {
	Stat = "Coins",
	BaseAmount = 50,
	StreakBonus = 25,
	MaxStreak = 7,
	CooldownHours = 20,
	StreakResetHours = 48,
})

PlayerData.defineStat({ Name = config.Stat, Default = 0, Leaderstat = true })

local function publish(player: Player)
	local data = PlayerData.section(player, "Daily")
	local nextClaim = (data.LastClaim or 0) + config.CooldownHours * 3600
	player:SetAttribute("DailyNextClaim", nextClaim)
	player:SetAttribute("DailyStreak", data.Streak or 0)
	local streak = if os.time() - (data.LastClaim or 0) > config.StreakResetHours * 3600 then 0 else (data.Streak or 0)
	player:SetAttribute("DailyAmount", config.BaseAmount + math.min(streak, config.MaxStreak - 1) * config.StreakBonus)
end

Net.on("DailyClaim", function(player)
	if not PlayerData.isLoaded(player) then
		return
	end
	local data = PlayerData.section(player, "Daily")
	local now = os.time()
	local last = data.LastClaim or 0
	if now - last < config.CooldownHours * 3600 then
		Net.notify(player, "Come back later for your next reward!", "info")
		return
	end
	local streak = if now - last > config.StreakResetHours * 3600 then 1 else (data.Streak or 0) + 1
	local amount = config.BaseAmount + (math.min(streak, config.MaxStreak) - 1) * config.StreakBonus
	data.LastClaim = now
	data.Streak = streak
	local balance = PlayerData.add(player, config.Stat, amount)
	Analytics.source(player, config.Stat, amount, balance, "TimedReward")
	Net.notify(player, `🎁 Day {streak} reward: +{Util.formatNumber(amount)} {config.Stat}!`, "reward")
	publish(player)
end, 2)

PlayerData.onLoaded(publish)
