-- GameKit Social (ServerScriptService.GameKit.Social)
-- Growth levers used by popular Roblox games:
--   * Friend boost: +FriendBoost (10%) to the boosted stat for each friend in the same server.
--   * Invite button (👥): opens Roblox's invite window; players who invite get InviteReward once a day.
--   * Group bonus: members of Config.Social.GroupId get GroupBoost and a one-time GroupReward.
-- Player attributes for UIs: FriendsHere, InGroup, SocialBoost (e.g. 1.3 = +30%).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("Social", {
	Stat = "Coins",
	FriendBoost = 0.1,
	MaxFriendBoost = 0.5,
	InviteButton = true,
	InviteReward = { Coins = 50 },
	GroupId = 0,
	GroupBoost = 0.1,
	GroupReward = { Coins = 250 },
})

PlayerData.defineStat({ Name = config.Stat, Default = 0, Leaderstat = true })
for _, rewards in { config.InviteReward, config.GroupReward } do
	for stat in pairs(rewards) do
		PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = stat ~= "XP" })
	end
end
kit:SetAttribute("InviteButton", config.InviteButton ~= false)
kit:SetAttribute("GroupId", config.GroupId)

local friends: { [Player]: { [Player]: boolean } } = {}

local function friendCount(player: Player): number
	local set = friends[player]
	local count = 0
	if set then
		for _ in set do
			count += 1
		end
	end
	return count
end

local function boostOf(player: Player): number
	local count = friendCount(player)
	local boost = math.min(config.MaxFriendBoost, count * config.FriendBoost)
	if player:GetAttribute("InGroup") == true then
		boost += config.GroupBoost
	end
	return 1 + boost
end

local function publish(player: Player)
	player:SetAttribute("FriendsHere", friendCount(player))
	player:SetAttribute("SocialBoost", math.floor(boostOf(player) * 100 + 0.5) / 100)
end

PlayerData.addMultiplier(function(player, stat)
	return if stat == config.Stat then boostOf(player) else 1
end)

local function link(a: Player, b: Player)
	friends[a] = friends[a] or {}
	friends[b] = friends[b] or {}
	if friends[a][b] then
		return
	end
	friends[a][b] = true
	friends[b][a] = true
	publish(a)
	publish(b)
	Net.notify(a, `👥 {b.DisplayName} is your friend: +{math.floor(config.FriendBoost * 100)}% {config.Stat}!`, "success")
	Net.notify(b, `👥 {a.DisplayName} is your friend: +{math.floor(config.FriendBoost * 100)}% {config.Stat}!`, "success")
end

local function checkGroup(player: Player)
	if config.GroupId <= 0 then
		return
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroupAsync(config.GroupId)
	end)
	if not ok then
		ok, inGroup = pcall(function()
			return (player :: any):IsInGroup(config.GroupId)
		end)
	end
	player:SetAttribute("InGroup", ok and inGroup == true)
	if ok and inGroup then
		local data = PlayerData.section(player, "Social")
		if not data.GroupRewarded then
			data.GroupRewarded = true
			for stat, amount in pairs(config.GroupReward) do
				PlayerData.reward(player, stat, amount, "Gameplay")
			end
			Net.notify(player, "Thanks for joining the group! 🎁", "reward")
		end
	end
	publish(player)
end

PlayerData.onLoaded(function(player)
	friends[player] = friends[player] or {}
	checkGroup(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local ok, isFriend = pcall(function()
					return player:IsFriendsWith(other.UserId)
				end)
				if ok and isFriend and other.Parent and player.Parent then
					link(player, other)
				end
			end)
		end
	end
	publish(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local set = friends[player]
	friends[player] = nil
	if set then
		for other in set do
			local theirs = friends[other]
			if theirs then
				theirs[player] = nil
				publish(other)
			end
		end
	end
end)

-- The client opened the invite window: reward once per day (Roblox does not say who accepted).
Net.on("InviteSent", function(player)
	local data = PlayerData.section(player, "Social")
	local today = os.date("!%Y-%m-%d")
	if data.LastInviteReward == today then
		return
	end
	data.LastInviteReward = today
	for stat, amount in pairs(config.InviteReward) do
		PlayerData.reward(player, stat, amount, "Gameplay")
	end
	Analytics.custom(player, "InviteSent", 1)
	Net.notify(player, "Thanks for inviting friends! 🎁", "reward")
end, 1)

-- Test hook used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player, other: Player?)
	if action == "boost" then
		return boostOf(player)
	elseif action == "fakeFriend" and other then
		link(player, other)
		return boostOf(player)
	end
	return nil
end
hook.Parent = script
