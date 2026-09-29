-- GameKit test runner. The test_game tool inserts this Script into ServerScriptService
-- before a playtest and removes it afterwards. It only does anything during a Studio
-- playtest: it records errors, plays through the game a little (checkpoints, coins),
-- then ends the test and hands the report back to the MCP server.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() or not RunService:IsRunning() then
	return
end

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local duration = script:GetAttribute("Duration")
local DURATION = if type(duration) == "number" then duration else 15
local autoplay = script:GetAttribute("Autoplay") ~= false

type Probe = { name: string, ok: boolean, detail: string }

local report = {
	serverErrors = {},
	serverWarnings = {},
	clientErrors = {},
	clientFacts = {},
	facts = {},
	probes = {} :: { Probe },
}

local function push(list: { any }, value: any)
	if #list < 40 then
		table.insert(list, value)
	end
end

LogService.MessageOut:Connect(function(message, messageType)
	if string.find(message, "__GameKit", 1, true) then
		return
	end
	if messageType == Enum.MessageType.MessageWarning then
		push(report.serverWarnings, message)
	end
end)

ScriptContext.Error:Connect(function(message, stack, source)
	push(report.serverErrors, {
		message = message,
		stack = stack,
		script = if source then source:GetFullName() else nil,
	})
end)

local probeRemote = Instance.new("RemoteEvent")
probeRemote.Name = "__GameKitTestProbe"
probeRemote.Parent = ReplicatedStorage
probeRemote.OnServerEvent:Connect(function(_, kind, data)
	if kind == "error" and type(data) == "table" then
		push(report.clientErrors, data)
	elseif kind == "facts" and type(data) == "table" then
		report.clientFacts = data
	end
end)

local function probe(name: string, ok: boolean, detail: string)
	table.insert(report.probes, { name = name, ok = ok, detail = detail })
end

local function stat(player: Player, name: string): number?
	local value = player:GetAttribute(name)
	if type(value) == "number" then
		return value
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local holder = leaderstats and leaderstats:FindFirstChild(name)
	if holder and holder:IsA("ValueBase") then
		return (holder :: any).Value
	end
	return nil
end

local function standOn(character: Model, part: BasePart)
	character:PivotTo(CFrame.new(part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 0)))
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function autoplayChecks(player: Player, character: Model)
	-- Checkpoints: walk the first stages in order and expect Stage to follow.
	local checkpoints = {}
	for _, part in CollectionService:GetTagged("Checkpoint") do
		local stage = part:GetAttribute("Stage")
		if part:IsA("BasePart") and type(stage) == "number" then
			checkpoints[stage] = part
		end
	end
	if checkpoints[2] then
		local reached = 1
		for stage = 2, 5 do
			local part = checkpoints[stage]
			if not part then
				break
			end
			standOn(character, part)
			task.wait(0.8)
			local now = stat(player, "Stage")
			if now == stage then
				reached = stage
			else
				probe("checkpoint " .. stage, false, `Stood on checkpoint {stage} but Stage is {tostring(now)}`)
				break
			end
		end
		if reached >= 2 then
			probe("checkpoints", true, `Stage advanced correctly up to {reached}`)
		end
	end

	-- Coins: touching one should raise its stat.
	local coin = CollectionService:GetTagged("Coin")[1]
	if coin and coin:IsA("BasePart") then
		local statName = coin:GetAttribute("Stat")
		local name = if type(statName) == "string" then statName else "Coins"
		local before = stat(player, name) or 0
		standOn(character, coin)
		task.wait(0.8)
		local after = stat(player, name) or 0
		probe("coin pickup", after > before, `{name}: {before} -> {after}`)
	end

	-- Kill parts: standing on one should kill (checked last; the character respawns).
	local kill = CollectionService:GetTagged("KillPart")[1]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if kill and kill:IsA("BasePart") and humanoid then
		standOn(character, kill)
		task.wait(1)
		probe("kill part", humanoid.Health <= 0, `Health after touching a KillPart: {math.floor(humanoid.Health)}`)
	end
end

task.spawn(function()
	local started = os.clock()
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	report.facts.playerJoined = player ~= nil
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	report.facts.characterSpawned = root ~= nil
	if root then
		report.facts.spawnPosition = { root.Position.X, root.Position.Y, root.Position.Z }
	end

	task.wait(3)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stats = {}
	if leaderstats then
		for _, holder in leaderstats:GetChildren() do
			if holder:IsA("ValueBase") then
				stats[holder.Name] = (holder :: any).Value
			end
		end
	end
	report.facts.leaderstats = stats
	report.facts.dataLoaded = player:GetAttribute("GK_DataLoaded") == true
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local currentRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	report.facts.aliveAfter3s = humanoid ~= nil and humanoid.Health > 0
	report.facts.fellIntoVoid = currentRoot ~= nil and currentRoot.Position.Y < workspace.FallenPartsDestroyHeight + 20
	local kit = ReplicatedStorage:FindFirstChild("GameKit")
	report.facts.status = if kit then kit:GetAttribute("Status") else nil

	if autoplay and humanoid and humanoid.Health > 0 then
		local ok, err = pcall(autoplayChecks, player, character)
		if not ok then
			probe("autoplay", false, tostring(err))
		end
	end

	local remaining = DURATION - (os.clock() - started)
	if remaining > 0 then
		task.wait(remaining)
	end
	report.facts.playersAtEnd = #Players:GetPlayers()
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, report)
	game:GetService("StudioTestService"):EndTest(if ok then encoded else `\{"encodeError":"{encoded}"\}`)
end)
