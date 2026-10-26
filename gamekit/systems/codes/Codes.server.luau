-- GameKit Codes (ServerScriptService.GameKit.Codes)
-- Redeem codes, like in popular Roblox games: share a code on your socials / group /
-- game description, players type it in the 🎟 window and get the rewards once.
--   Config.Codes.List = { WELCOME = { Rewards = { Coins = 100 } },
--                         SUMMER = { Rewards = { Gems = 5 }, Expires = "2026-09-01" } }
-- Codes are not case sensitive. Each player can redeem each code once (saved).
-- Expires ("YYYY-MM-DD", UTC) is optional; MinLevel needs the levels system.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("Codes", {
	List = {
		WELCOME = { Rewards = { Coins = 100 } },
	},
	ShowButton = true,
})

type Code = { Rewards: { [string]: number }?, Expires: string?, MinLevel: number? }

-- Upper-case keys so "welcome", "Welcome" and "WELCOME" all work.
local codes: { [string]: Code } = {}
for name, code in config.List do
	if type(name) == "string" and type(code) == "table" then
		codes[string.upper(name)] = code
		for stat in pairs(code.Rewards or {}) do
			PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = stat ~= "XP" })
		end
	end
end
kit:SetAttribute("CodesButton", config.ShowButton ~= false)

local function redeemed(player: Player): { [string]: boolean }
	local section = PlayerData.section(player, "Codes")
	section.Redeemed = section.Redeemed or {}
	return section.Redeemed
end

-- Returns ok, message.
local function redeem(player: Player, raw: string): (boolean, string)
	if not PlayerData.isLoaded(player) then
		return false, "Please wait, your data is loading."
	end
	local name = string.upper((string.gsub(raw, "%s", "")))
	local code = codes[name]
	if name == "" or not code then
		return false, "Invalid code."
	end
	if code.Expires and os.date("!%Y-%m-%d") > code.Expires then
		return false, "This code has expired."
	end
	if code.MinLevel and PlayerData.get(player, "Level") < code.MinLevel then
		return false, `Reach level {code.MinLevel} to use this code.`
	end
	local done = redeemed(player)
	if done[name] then
		return false, "You already used this code."
	end
	done[name] = true
	local parts = {}
	for stat, amount in pairs(code.Rewards or {}) do
		local given = PlayerData.reward(player, stat, amount, "Gameplay")
		table.insert(parts, `+{Util.formatNumber(given)} {stat}`)
	end
	task.spawn(PlayerData.save, player) -- a used code must not come back after a crash
	Analytics.custom(player, "Code_" .. name, 1)
	return true, `🎉 {table.concat(parts, "  ")}`
end

-- 1 try per second per player: guessing codes by brute force is pointless.
Net.on("RedeemCode", function(player, raw)
	if type(raw) ~= "string" or #raw > 40 then
		return
	end
	local ok, message = redeem(player, raw)
	Net.fire(player, "CodeResult", ok, message)
	if ok then
		Net.notify(player, message, "reward")
	end
end, 1)

-- Test hook used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player)
	if action == "redeemFirst" then
		for name, code in codes do
			if not code.Expires or os.date("!%Y-%m-%d") <= code.Expires then
				local ok = redeem(player, string.lower(name))
				local again = redeem(player, name)
				return { code = name, ok = ok, twice = again }
			end
		end
	end
	return nil
end
hook.Parent = script
