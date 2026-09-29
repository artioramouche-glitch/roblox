-- GameKit Objectives (ServerScriptService.GameKit.Objectives)
-- "Find the keys, open the exit, escape!" -- great for horror/escape games.
--   Parts tagged "Key"      : collect them all (the whole server shares progress).
--   Part tagged "ExitDoor"  : opens when enough keys are found (attribute KeysRequired,
--                             default = number of keys).
--   Part tagged "ExitZone"  : touching it after the door opens = escaped (rewarded).
-- When everyone has escaped or died (or the timer ends) the run resets.
-- Pair it with the Enemies system (a "Monster" type) for the scary part.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Objectives", {
	EscapeRewards = { Wins = 1, Coins = 30 },
	RunSeconds = 300,
	ResetDelay = 8,
	ItemName = "key",
})

for stat in pairs(config.EscapeRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
end

local found = 0
local escaped: { [Player]: boolean } = {}
local doorOpen = false
local runId = 0

local function keys(): { BasePart }
	local list = {}
	for _, part in CollectionService:GetTagged("Key") do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			table.insert(list, part)
		end
	end
	return list
end

local function required(): number
	for _, door in CollectionService:GetTagged("ExitDoor") do
		local value = door:GetAttribute("KeysRequired")
		if type(value) == "number" then
			return value
		end
	end
	return math.max(1, #keys())
end

local function setStatus()
	if doorOpen then
		kit:SetAttribute("Status", "🚪 The exit is open! ESCAPE!")
	else
		kit:SetAttribute("Status", `🔑 Find the {config.ItemName}s: {found}/{required()}`)
	end
end

local function setDoors(open: boolean)
	doorOpen = open
	for _, door in CollectionService:GetTagged("ExitDoor") do
		if door:IsA("BasePart") then
			door.CanCollide = not open
			TweenService:Create(door, TweenInfo.new(0.6), {
				Transparency = if open then 0.85 else 0,
				Color = if open then Color3.fromRGB(80, 220, 120) else Color3.fromRGB(120, 40, 40),
			}):Play()
		end
	end
end

local function resetRun()
	runId += 1
	found = 0
	table.clear(escaped)
	setDoors(false)
	for _, key in ipairs(keys()) do
		key.Transparency = 0
		key.CanTouch = true
		key:SetAttribute("GK_Taken", nil)
	end
	kit:SetAttribute("Timer", 0)
	setStatus()
end

local function everyoneDone(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not escaped[player] and humanoid and humanoid.Health > 0 then
			return false
		end
	end
	return true
end

local function endRun(message: string)
	local myRun = runId
	Net.notify(nil, message, "info")
	kit:SetAttribute("Status", message)
	task.wait(config.ResetDelay)
	if myRun ~= runId then
		return
	end
	resetRun()
	for _, player in Players:GetPlayers() do
		Util.respawn(player)
	end
end

Util.onTag("Key", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local key = instance :: BasePart
	key.CanCollide = false
	key.Anchored = true
	key.Touched:Connect(function(hit)
		local player = Util.playerFromHit(hit)
		if not player or key:GetAttribute("GK_Taken") then
			return
		end
		key:SetAttribute("GK_Taken", true)
		key.Transparency = 1
		key.CanTouch = false
		found += 1
		Net.notify(nil, `🔑 {player.DisplayName} found a {config.ItemName}! ({found}/{required()})`, "success")
		if found >= required() and not doorOpen then
			setDoors(true)
			Net.notify(nil, "🚪 The exit is open!", "reward")
		end
		setStatus()
	end)
end)

Util.onTag("ExitZone", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	instance.Touched:Connect(function(hit)
		local player, character = Util.playerFromHit(hit)
		if not player or not character or not doorOpen or escaped[player] then
			return
		end
		escaped[player] = true
		local parts = {}
		for stat, amount in pairs(config.EscapeRewards) do
			local given = PlayerData.reward(player, stat, amount)
			table.insert(parts, `+{Util.formatNumber(given)} {stat}`)
		end
		Net.notify(player, "🎉 You escaped! " .. table.concat(parts, " "), "reward")
		local lobby = CollectionService:GetTagged("LobbySpawn")[1]
		if lobby and lobby:IsA("BasePart") then
			Util.teleportOnto(character, lobby)
		end
		if everyoneDone() then
			task.spawn(endRun, "Everyone is out! New run soon...")
		end
	end)
end)

-- Timer + "everyone died" check.
task.spawn(function()
	resetRun()
	while true do
		local myRun = runId
		for remaining = config.RunSeconds, 1, -1 do
			if myRun ~= runId then
				break
			end
			kit:SetAttribute("Timer", remaining)
			task.wait(1)
			if everyoneDone() and myRun == runId then
				endRun("The run is over! Restarting...")
				break
			end
		end
		if myRun == runId then
			endRun("⏰ Time's up! Restarting...")
		end
	end
end)
