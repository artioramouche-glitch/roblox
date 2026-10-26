-- GameKit Rounds (ServerScriptService.GameKit.Rounds)
-- The classic loop: Intermission -> Round -> Results -> Intermission...
-- Spawns: parts tagged "RoundSpawn" (arena) and "LobbySpawn" (lobby).
-- Maps (optional): put Models in ServerStorage.GameKit.Maps; one is picked each round and
-- copied into Workspace (its own "RoundSpawn" parts are used).
-- Modes (Config.Rounds.Mode):
--   "LastStanding" -- last player alive wins (ends early when one is left)
--   "Survive"      -- everyone still alive when the timer ends wins
-- Shared state for other systems/UI (attributes on ReplicatedStorage.GameKit):
--   Status (string), Timer (number), RoundActive (bool), RoundNumber (number)
-- Players in the round have the attribute InRound = true.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Rounds", {
	Mode = "LastStanding",
	MinPlayers = 1,
	IntermissionSeconds = 15,
	RoundSeconds = 90,
	ResultsSeconds = 5,
	WinnerRewards = { Wins = 1, Coins = 25 },
	ParticipationRewards = { Coins = 5 },
})

for stat in pairs(config.WinnerRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
end
for stat in pairs(config.ParticipationRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
end

local function setStatus(text: string, timer: number?)
	kit:SetAttribute("Status", text)
	kit:SetAttribute("Timer", timer or 0)
end

local function countdown(seconds: number, label: string, shouldStop: (() -> boolean)?)
	for remaining = seconds, 1, -1 do
		setStatus(label, remaining)
		task.wait(1)
		if shouldStop and shouldStop() then
			return
		end
	end
	setStatus(label, 0)
end

local function readyPlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and PlayerData.isLoaded(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function pickMap(): Instance?
	local mapsFolder = ServerStorage:FindFirstChild("GameKit")
	mapsFolder = mapsFolder and mapsFolder:FindFirstChild("Maps")
	if not mapsFolder or #mapsFolder:GetChildren() == 0 then
		return nil
	end
	local maps = mapsFolder:GetChildren()
	local map = maps[math.random(1, #maps)]:Clone()
	map.Name = "ActiveMap"
	local holder = workspace:FindFirstChild("GameKit") or workspace
	map.Parent = holder
	return map
end

local function spawnsIn(tag: string, container: Instance?): { BasePart }
	local list = {}
	for _, part in CollectionService:GetTagged(tag) do
		if part:IsA("BasePart") and (not container or part:IsDescendantOf(container)) and part:IsDescendantOf(workspace) then
			table.insert(list, part)
		end
	end
	return list
end

local function sendTo(player: Player, spawns: { BasePart }, index: number)
	local character = player.Character
	if character and #spawns > 0 then
		Util.teleportOnto(character, spawns[(index - 1) % #spawns + 1])
	end
end

local roundNumber = 0

local function runRound()
	local participants = readyPlayers()
	roundNumber += 1
	local map = pickMap()
	local arenaSpawns = spawnsIn("RoundSpawn", map)
	if #arenaSpawns == 0 then
		warn('[GameKit] Rounds: no part tagged "RoundSpawn". Players stay where they are.')
	end

	local alive: { [Player]: boolean } = {}
	local aliveCount = 0
	local connections: { RBXScriptConnection } = {}
	for index, player in ipairs(participants) do
		alive[player] = true
		aliveCount += 1
		player:SetAttribute("InRound", true)
		sendTo(player, arenaSpawns, index)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(
				connections,
				humanoid.Died:Connect(function()
					if alive[player] then
						alive[player] = nil
						aliveCount -= 1
						player:SetAttribute("InRound", false)
					end
				end)
			)
		end
	end
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			if alive[player] then
				alive[player] = nil
				aliveCount -= 1
			end
		end)
	)

	kit:SetAttribute("RoundNumber", roundNumber)
	kit:SetAttribute("RoundActive", true)
	Net.notify(nil, "⚔️ Round " .. roundNumber .. " started!", "info")

	local startedWith = #participants
	countdown(config.RoundSeconds, if config.Mode == "Survive" then "Survive!" else "Be the last one standing!", function()
		if aliveCount <= 0 then
			return true
		end
		return config.Mode == "LastStanding" and startedWith >= 2 and aliveCount <= 1
	end)

	kit:SetAttribute("RoundActive", false)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end

	local winners = {}
	for player in alive do
		if player.Parent then
			table.insert(winners, player)
		end
	end
	for _, player in ipairs(participants) do
		if player.Parent then
			player:SetAttribute("InRound", false)
			for stat, amount in pairs(config.ParticipationRewards) do
				PlayerData.reward(player, stat, amount)
			end
		end
	end
	for _, player in ipairs(winners) do
		for stat, amount in pairs(config.WinnerRewards) do
			PlayerData.reward(player, stat, amount)
		end
		Net.notify(player, "🏆 You won the round!", "reward")
	end

	local names = {}
	for _, player in ipairs(winners) do
		table.insert(names, player.DisplayName)
	end
	setStatus(if #names > 0 then "Winner: " .. table.concat(names, ", ") else "Nobody survived!", config.ResultsSeconds)
	task.wait(config.ResultsSeconds)

	local lobby = spawnsIn("LobbySpawn")
	for index, player in ipairs(Players:GetPlayers()) do
		if #lobby > 0 then
			sendTo(player, lobby, index)
		else
			Util.respawn(player)
		end
	end
	if map then
		map:Destroy()
	end
end

-- Players who respawn during a round are not part of it anymore.
Util.onCharacter(function(_, player)
	if not kit:GetAttribute("RoundActive") then
		player:SetAttribute("InRound", false)
	end
end)

kit:SetAttribute("RoundActive", false)
task.spawn(function()
	while true do
		local ready = readyPlayers()
		if #ready < config.MinPlayers then
			setStatus(`Waiting for players ({#ready}/{config.MinPlayers})`)
			task.wait(2)
		else
			countdown(config.IntermissionSeconds, "Intermission")
			local ok, err = pcall(runRound)
			if not ok then
				warn(`[GameKit] Round error: {err}`)
				kit:SetAttribute("RoundActive", false)
				task.wait(3)
			end
		end
	end
end)
