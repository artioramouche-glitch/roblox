-- GameKit Admin commands (ServerScriptService.GameKit.Admin)
-- Chat commands for the game owner and Config.Admin.Admins (UserIds). In Studio every
-- tester is an admin. Commands (type them in chat):
--   /give <player|me> <stat> <amount>   /set <player|me> <stat> <amount>
--   /reset <player|me>                  /kick <player> [reason]
--   /tp <player>  (go to them)          /bring <player>
--   /speed <number>                     /heal [player|me]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Admin", {
	Admins = {},
	GroupRank = 254,
})

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(config.Admins, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		local p = player :: any
		return if p.GetRankInGroupAsync then p:GetRankInGroupAsync(game.CreatorId) else p:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= config.GroupRank
end

local function findPlayer(caller: Player, query: string?): Player?
	if not query or query == "" or string.lower(query) == "me" then
		return caller
	end
	local lower = string.lower(query)
	for _, player in Players:GetPlayers() do
		if string.sub(string.lower(player.Name), 1, #lower) == lower or string.sub(string.lower(player.DisplayName), 1, #lower) == lower then
			return player
		end
	end
	return nil
end

local commands: { [string]: (Player, { string }) -> string? } = {}

commands.give = function(caller, args)
	local target = findPlayer(caller, args[1])
	local amount = tonumber(args[3])
	if not target or not args[2] or not amount then
		return "Usage: /give <player|me> <stat> <amount>"
	end
	PlayerData.add(target, args[2], amount)
	return `Gave {amount} {args[2]} to {target.Name}`
end

commands.set = function(caller, args)
	local target = findPlayer(caller, args[1])
	local amount = tonumber(args[3])
	if not target or not args[2] or not amount then
		return "Usage: /set <player|me> <stat> <amount>"
	end
	PlayerData.set(target, args[2], amount)
	return `Set {target.Name}'s {args[2]} to {amount}`
end

commands.reset = function(caller, args)
	local target = findPlayer(caller, args[1])
	if not target then
		return "Player not found"
	end
	for _, statHolder in ipairs((target:FindFirstChild("leaderstats") :: Instance):GetChildren()) do
		PlayerData.set(target, statHolder.Name, if statHolder.Name == "Stage" then 1 else 0)
	end
	return `Reset {target.Name}'s stats`
end

commands.kick = function(caller, args)
	local target = findPlayer(caller, args[1])
	if not target or target == caller then
		return "Player not found"
	end
	target:Kick(table.concat(args, " ", 2))
	return `Kicked {target.Name}`
end

commands.tp = function(caller, args)
	local target = findPlayer(caller, args[1])
	local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if caller.Character and root and root:IsA("BasePart") then
		Util.teleportOnto(caller.Character, root)
		return nil
	end
	return "Player not found"
end

commands.bring = function(caller, args)
	local target = findPlayer(caller, args[1])
	local root = caller.Character and caller.Character:FindFirstChild("HumanoidRootPart")
	if target and target.Character and root and root:IsA("BasePart") then
		Util.teleportOnto(target.Character, root)
		return nil
	end
	return "Player not found"
end

commands.speed = function(caller, args)
	local humanoid = caller.Character and caller.Character:FindFirstChildOfClass("Humanoid")
	local speed = tonumber(args[1])
	if humanoid and speed then
		humanoid.WalkSpeed = math.clamp(speed, 0, 500)
		return nil
	end
	return "Usage: /speed <number>"
end

commands.heal = function(caller, args)
	local target = findPlayer(caller, args[1])
	local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
		return nil
	end
	return "Player not found"
end

local function run(player: Player, message: string)
	if string.sub(message, 1, 1) ~= "/" or not isAdmin(player) then
		return
	end
	local words = string.split(string.sub(message, 2), " ")
	local name = string.lower(table.remove(words, 1) or "")
	local command = commands[name]
	if not command then
		return
	end
	local ok, result = pcall(command, player, words)
	if not ok then
		Net.notify(player, "Command error: " .. tostring(result), "error")
	elseif result then
		Net.notify(player, result, "info")
	end
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	for name in pairs(commands) do
		local command = Instance.new("TextChatCommand")
		command.Name = "GK_" .. name
		command.PrimaryAlias = "/" .. name
		command.Parent = TextChatService
		command.Triggered:Connect(function(source, message)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				run(player, message)
			end
		end)
	end
else
	Util.onPlayer(function(player)
		player.Chatted:Connect(function(message)
			run(player, message)
		end)
	end)
end
