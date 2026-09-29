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
local expectedPlayers = script:GetAttribute("Players")
local EXPECTED = if type(expectedPlayers) == "number" then expectedPlayers else 1

type Probe = { name: string, ok: boolean, detail: string }

local report = {
	serverErrors = {},
	serverWarnings = {},
	clientErrors = {},
	clientFacts = {},
	clients = {},
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
probeRemote.OnServerEvent:Connect(function(player, kind, data)
	if kind == "error" and type(data) == "table" then
		data.player = player.Name
		push(report.clientErrors, data)
	elseif kind == "facts" and type(data) == "table" then
		report.clientFacts = data
		report.clients[player.Name] = data
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

	-- Genre systems expose a test hook (BindableFunction "__GameKitHook") to play their loop.
	local serverKit = game:GetService("ServerScriptService"):FindFirstChild("GameKit")
	local function hookOf(name: string): BindableFunction?
		local system = serverKit and serverKit:FindFirstChild(name)
		local hook = system and system:FindFirstChild("__GameKitHook")
		return if hook and hook:IsA("BindableFunction") then hook else nil
	end

	-- Tower defense: building a tower on a pad must work.
	local tdHook = hookOf("TowerDefense")
	local pad = CollectionService:GetTagged("TowerPad")[1]
	if tdHook and pad then
		local ok, built = pcall(function()
			return tdHook:Invoke("build", player, pad)
		end)
		local towers = tdHook:Invoke("towers")
		probe("tower build", ok and built == true and type(towers) == "number" and towers >= 1, `build returned {tostring(built)}, towers: {tostring(towers)}`)
	end

	-- Farming: plant -> ripen -> harvest -> sell must earn money.
	local farmHook = hookOf("Farming")
	local plot = CollectionService:GetTagged("FarmPlot")[1]
	if farmHook and plot then
		local ok, result = pcall(function()
			local planted = farmHook:Invoke("plant", player, plot)
			farmHook:Invoke("ripen", player, plot)
			local harvested = farmHook:Invoke("harvest", player, plot)
			local earned = farmHook:Invoke("sell", player)
			return { planted = planted, harvested = harvested, earned = earned }
		end)
		probe("farm loop", ok and result.planted == true and result.harvested == true and type(result.earned) == "number" and result.earned > 0,
			if ok then `planted {tostring(result.planted)}, harvested {tostring(result.harvested)}, earned {tostring(result.earned)}` else tostring(result))
	end

	-- Inventory: give then take an item.
	local inventoryHook = hookOf("InventoryServer")
	if inventoryHook then
		local ok, result = pcall(function()
			local given = inventoryHook:Invoke("give", player, "__TestItem", 2)
			local taken = inventoryHook:Invoke("take", player, "__TestItem", 2)
			return { given = given, taken = taken }
		end)
		probe("inventory", ok and result.given == 2 and result.taken == true, if ok then `give -> {tostring(result.given)}, take -> {tostring(result.taken)}` else tostring(result))
	end

	-- Levels: enough XP for level 2 must level up.
	local levelsHook = hookOf("Levels")
	if levelsHook then
		local ok, result = pcall(function()
			local needed = levelsHook:Invoke("totalFor", player, 2)
			return levelsHook:Invoke("xp", player, needed)
		end)
		probe("level up", ok and type(result) == "number" and result >= 2, if ok then `level after XP: {tostring(result)}` else tostring(result))
	end

	-- Quests: completing the first active quest must move on.
	local questsHook = hookOf("Quests")
	if questsHook then
		local ok, result = pcall(function()
			local before = questsHook:Invoke("active", player)
			local completed = questsHook:Invoke("completeFirst", player)
			return { before = before, completed = completed }
		end)
		probe("quest complete", ok and result.completed ~= nil and result.completed == result.before, if ok then `completed {tostring(result.completed)}` else tostring(result))
	end

	-- Pets: hatching an egg gives a pet and a reward multiplier.
	local petsHook = hookOf("Pets")
	if petsHook then
		local ok, result = pcall(function()
			local pet = petsHook:Invoke("hatch", player)
			return { pet = pet, multiplier = petsHook:Invoke("multiplier", player) }
		end)
		probe("egg hatch", ok and result.pet ~= nil and type(result.multiplier) == "number" and result.multiplier > 1, if ok then `pet {tostring(result.pet)}, multiplier {tostring(result.multiplier)}` else tostring(result))
	end

	-- Racing: a complete track (checkpoints, grid, finish) and a kart that builds.
	local racingHook = hookOf("Racing")
	if racingHook then
		local ok, result = pcall(function()
			local track = racingHook:Invoke("track")
			return { track = track, kart = racingHook:Invoke("kart") }
		end)
		local track = ok and result.track
		probe("race track", ok and type(track) == "table" and track.checkpoints > 0 and track.grid > 0 and track.finish > 0,
			if type(track) == "table" then `{track.checkpoints} checkpoints, {track.grid} grid slots, {track.finish} finish line(s)` else tostring(result))
		probe("kart", ok and result.kart == true, if ok then `kart built: {tostring(result.kart)}` else tostring(result))
	end

	-- Fishing: a catch lands in the inventory.
	local fishingHook = hookOf("Fishing")
	if fishingHook then
		local ok, result = pcall(function()
			return fishingHook:Invoke("catch", player)
		end)
		local count = if ok and type(result) == "string" then player:GetAttribute("Inv_" .. result) else nil
		probe("fishing catch", ok and type(count) == "number" and count > 0, if ok then `caught {tostring(result)}, bag count {tostring(count)}` else tostring(result))
	end

	-- Crafting: a resource node gives items and a recipe crafts.
	local craftingHook = hookOf("Crafting")
	if craftingHook then
		local ok, result = pcall(function()
			return { gathered = craftingHook:Invoke("gather", player), crafted = craftingHook:Invoke("craft", player) }
		end)
		if ok and result.gathered ~= -1 then
			probe("gather", type(result.gathered) == "number" and result.gathered > 0, `items from one node: {tostring(result.gathered)}`)
		end
		if not ok or result.crafted ~= nil then
			probe("craft", ok and result.crafted == true, if ok then `crafted first item recipe: {tostring(result.crafted)}` else tostring(result))
		end
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
	-- Multiplayer test: wait for every client, then check they all spawned and loaded.
	while #Players:GetPlayers() < EXPECTED and os.clock() - started < 30 do
		task.wait(0.5)
	end
	report.facts.expectedPlayers = EXPECTED
	report.facts.playersJoined = #Players:GetPlayers()
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
	if EXPECTED > 1 then
		local all = Players:GetPlayers()
		probe("players joined", #all >= EXPECTED, `{#all}/{EXPECTED} players in the server`)
		local loaded, spawned, alive = 0, 0, 0
		for _, other in all do
			if other:GetAttribute("GK_DataLoaded") == true then
				loaded += 1
			end
			local otherHumanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
			if otherHumanoid then
				spawned += 1
				if otherHumanoid.Health > 0 then
					alive += 1
				end
			end
		end
		probe("every player loaded", loaded == #all, `{loaded}/{#all} players have their data loaded`)
		probe("every player spawned", spawned == #all, `{spawned}/{#all} characters, {alive} alive at the end`)
		local seen = 0
		for _, facts in report.clients do
			if type(facts.playersSeen) == "number" and facts.playersSeen >= EXPECTED then
				seen += 1
			end
		end
		probe("clients see each other", seen >= math.min(#all, EXPECTED), `{seen} client(s) see all {EXPECTED} players`)
	end
	if kit and kit:GetAttribute("Wave") ~= nil then
		report.facts.towerDefense = { wave = kit:GetAttribute("Wave"), baseHealth = kit:GetAttribute("BaseHealth"), enemiesAlive = kit:GetAttribute("EnemiesAlive") }
	end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, report)
	game:GetService("StudioTestService"):EndTest(if ok then encoded else `\{"encodeError":"{encoded}"\}`)
end)
