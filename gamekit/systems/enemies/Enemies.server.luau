-- GameKit Enemies (ServerScriptService.GameKit.Enemies)
-- NPCs that chase and attack players, with pathfinding around walls.
--   Spawners: parts tagged "EnemySpawner" with attributes
--     Enemy (type name from Config.Enemies.Types, default "Zombie"),
--     MaxAlive (default 3), RespawnSeconds (default 8)
--   Waves mode (Config.Enemies.Waves.Enabled): enemies come in growing waves; the HUD
--   status shows the wave; everyone alive at the end of a wave is rewarded.
-- Custom look: put a Model with a Humanoid named like the type in
-- ServerStorage.GameKit.Enemies (e.g. "Zombie") and it is used instead of the default rig.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Enemies", {
	Types = {
		Zombie = {
			Health = 100,
			WalkSpeed = 11,
			Damage = 15,
			AttackCooldown = 1,
			AttackRange = 5,
			DetectRange = 90,
			Rewards = { Coins = 5 },
			SkinColor = "#6E9E4C",
			ShirtColor = "#4B3B2A",
			Scale = 1,
		},
	},
	WalkAnimation = "rbxassetid://507777826",
	MaxTotal = 30,
	Waves = {
		Enabled = false,
		FirstWaveSize = 3,
		GrowthPerWave = 2,
		BreakSeconds = 10,
		SurviveRewards = { Coins = 20 },
		DayNight = false,
	},
})

local DEFAULT_TYPE = {
	Health = 100,
	WalkSpeed = 11,
	Damage = 15,
	AttackCooldown = 1,
	AttackRange = 5,
	DetectRange = 90,
	Rewards = { Coins = 5 },
	SkinColor = "#6E9E4C",
	ShirtColor = "#4B3B2A",
	Scale = 1,
}

local function typeInfo(name: string): { [string]: any }
	local info = config.Types[name]
	if type(info) ~= "table" then
		return DEFAULT_TYPE
	end
	for key, value in pairs(DEFAULT_TYPE) do
		if info[key] == nil then
			info[key] = value
		end
	end
	return info
end

for _, info in pairs(config.Types) do
	for stat in pairs(info.Rewards or {}) do
		PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
	end
end

local enemiesFolder = workspace:FindFirstChild("Enemies")
if not enemiesFolder then
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = workspace
end

-- Templates -------------------------------------------------------------------------------
local templates: { [string]: Model } = {}

local function customTemplate(name: string): Model?
	local root = ServerStorage:FindFirstChild("GameKit")
	local folder = root and root:FindFirstChild("Enemies")
	local model = folder and folder:FindFirstChild(name)
	if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	return nil
end

local function buildTemplate(name: string): Model?
	if templates[name] then
		return templates[name]
	end
	local info = typeInfo(name)
	local model = customTemplate(name)
	if model then
		model = model:Clone()
	else
		local description = Instance.new("HumanoidDescription")
		local skin = Util.color(info.SkinColor)
		local shirt = Util.color(info.ShirtColor)
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = shirt
		description.LeftLegColor = shirt
		description.RightLegColor = shirt
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
		end)
		if not ok then
			-- Older engines only have the non-Async name.
			ok, result = pcall(function()
				return (Players :: any):CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
			end)
		end
		if not ok then
			warn(`[GameKit] Could not build enemy rig '{name}': {result}`)
			return nil
		end
		model = result
	end
	local built = model :: Model
	built.Name = name
	local scale = tonumber(info.Scale) or 1
	if scale ~= 1 then
		pcall(function()
			built:ScaleTo(scale)
		end)
	end
	local humanoid = built:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = info.Health
	humanoid.Health = info.Health
	humanoid.WalkSpeed = info.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	-- The Animate LocalScript never runs on NPCs; remove it to avoid confusion.
	local animate = built:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	templates[name] = built
	return built
end

-- Brains ------------------------------------------------------------------------------------
type Enemy = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	info: { [string]: any },
	lastAttack: number,
	waypoints: { PathWaypoint }?,
	waypointIndex: number,
	lastPath: number,
	computing: boolean,
	walkTrack: AnimationTrack?,
}

local enemies: { [Model]: Enemy } = {}

local function nearestTarget(enemy: Enemy): (Model?, BasePart?, number)
	local best, bestRoot, bestDistance = nil, nil, enemy.info.DetectRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and humanoid and root and humanoid.Health > 0 and not character:FindFirstChildOfClass("ForceField") then
			local distance = (root.Position - enemy.root.Position).Magnitude
			if distance < bestDistance then
				best, bestRoot, bestDistance = character, root, distance
			end
		end
	end
	return best, bestRoot, bestDistance
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(enemy: Enemy, target: Model, targetRoot: BasePart): boolean
	rayParams.FilterDescendantsInstances = { enemy.model, target }
	local direction = targetRoot.Position - enemy.root.Position
	return workspace:Raycast(enemy.root.Position, direction, rayParams) == nil
end

local function computePath(enemy: Enemy, goal: Vector3)
	if enemy.computing then
		return
	end
	enemy.computing = true
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function()
			path:ComputeAsync(enemy.root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			enemy.waypoints = path:GetWaypoints()
			enemy.waypointIndex = 2
		else
			enemy.waypoints = nil
		end
		enemy.lastPath = os.clock()
		enemy.computing = false
	end)
end

local function attack(enemy: Enemy, target: Model)
	local now = os.clock()
	if now - enemy.lastAttack < enemy.info.AttackCooldown then
		return
	end
	enemy.lastAttack = now
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(enemy.info.Damage)
	end
end

local function think(enemy: Enemy)
	local target, targetRoot, distance = nearestTarget(enemy)
	if not target or not targetRoot then
		enemy.waypoints = nil
		return
	end
	if distance <= enemy.info.AttackRange then
		attack(enemy, target)
		enemy.humanoid:MoveTo(targetRoot.Position)
		return
	end
	if distance < 25 and canSee(enemy, target, targetRoot) then
		enemy.waypoints = nil
		enemy.humanoid:MoveTo(targetRoot.Position)
		return
	end
	if os.clock() - enemy.lastPath > 1 then
		computePath(enemy, targetRoot.Position)
	end
	local waypoints = enemy.waypoints
	if waypoints and waypoints[enemy.waypointIndex] then
		local waypoint = waypoints[enemy.waypointIndex]
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			enemy.humanoid.Jump = true
		end
		enemy.humanoid:MoveTo(waypoint.Position)
		if (enemy.root.Position - waypoint.Position).Magnitude < 4 then
			enemy.waypointIndex += 1
		end
	else
		enemy.humanoid:MoveTo(targetRoot.Position)
	end
end

local function reward(enemy: Enemy)
	local creator = enemy.humanoid:FindFirstChild("creator")
	local killer = if creator and creator:IsA("ObjectValue") then creator.Value else nil
	if killer and killer:IsA("Player") and killer.Parent then
		local parts = {}
		for stat, amount in pairs(enemy.info.Rewards or {}) do
			local given = PlayerData.reward(killer, stat, amount)
			table.insert(parts, `+{Util.formatNumber(given)} {stat}`)
		end
		if #parts > 0 then
			Net.notify(killer, `Defeated {enemy.model.Name}! ` .. table.concat(parts, " "), "reward")
		end
	end
end

local function aliveCount(): number
	local count = 0
	for _ in enemies do
		count += 1
	end
	return count
end

local function spawnEnemy(typeName: string, cframe: CFrame): Model?
	if aliveCount() >= config.MaxTotal then
		return nil
	end
	local template = buildTemplate(typeName)
	if not template then
		return nil
	end
	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) :: BasePart?
	if not root then
		model:Destroy()
		warn(`[GameKit] Enemy '{typeName}' has no HumanoidRootPart`)
		return nil
	end
	model:PivotTo(cframe + Vector3.new(0, 4, 0))
	model.Parent = enemiesFolder
	CollectionService:AddTag(model, "Enemy")
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
		end
	end
	local enemy: Enemy = {
		model = model,
		humanoid = humanoid,
		root = root :: BasePart,
		info = typeInfo(typeName),
		lastAttack = 0,
		waypoints = nil,
		waypointIndex = 2,
		lastPath = 0,
		computing = false,
		walkTrack = nil,
	}
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator and config.WalkAnimation ~= "" then
		local animation = Instance.new("Animation")
		animation.AnimationId = config.WalkAnimation
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok then
			enemy.walkTrack = track
			humanoid.Running:Connect(function(speed)
				if speed > 0.5 and not track.IsPlaying then
					track:Play()
				elseif speed <= 0.5 and track.IsPlaying then
					track:Stop()
				end
			end)
		end
	end
	enemies[model] = enemy
	humanoid.Died:Connect(function()
		enemies[model] = nil
		reward(enemy)
		task.delay(3, function()
			model:Destroy()
		end)
	end)
	return model
end

task.spawn(function()
	while true do
		task.wait(0.2)
		for model, enemy in enemies do
			if not model.Parent or enemy.humanoid.Health <= 0 then
				enemies[model] = nil
			else
				local ok, err = pcall(think, enemy)
				if not ok then
					warn(`[GameKit] Enemy AI error: {err}`)
				end
			end
		end
	end
end)

-- Spawners (normal mode) -------------------------------------------------------------------
local function spawnerNumber(part: Instance, name: string, default: number): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else default
end

local function spawnerType(part: Instance): string
	local value = part:GetAttribute("Enemy")
	return if type(value) == "string" then value else "Zombie"
end

local function runSpawner(part: BasePart)
	local mine: { Model } = {}
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	while part.Parent do
		for i = #mine, 1, -1 do
			local model = mine[i]
			if not model.Parent or not enemies[model] then
				table.remove(mine, i)
			end
		end
		if #mine < spawnerNumber(part, "MaxAlive", 3) then
			local model = spawnEnemy(spawnerType(part), part.CFrame)
			if model then
				table.insert(mine, model)
			end
		end
		task.wait(spawnerNumber(part, "RespawnSeconds", 8))
	end
end

local waves = config.Waves or {}

if not waves.Enabled then
	Util.onTag("EnemySpawner", function(instance)
		if instance:IsA("BasePart") then
			runSpawner(instance)
		end
	end)
else
	-- Waves mode -------------------------------------------------------------------------------
	for stat in pairs(waves.SurviveRewards or {}) do
		PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
	end

	local function spawners(): { BasePart }
		local list = {}
		for _, part in CollectionService:GetTagged("EnemySpawner") do
			if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
				part.Transparency = 1
				part.CanCollide = false
				table.insert(list, part)
			end
		end
		return list
	end

	local function anyoneAlive(): boolean
		for _, player in Players:GetPlayers() do
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				return true
			end
		end
		return false
	end

	-- DayNight = true: day during breaks, night during waves (turn off Atmosphere.DayNightCycle).
	local function setSky(clockTime: number)
		if waves.DayNight then
			local Lighting = game:GetService("Lighting")
			game:GetService("TweenService"):Create(Lighting, TweenInfo.new(3), { ClockTime = clockTime }):Play()
		end
	end

	task.spawn(function()
		local wave = 0
		while true do
			if #Players:GetPlayers() == 0 then
				kit:SetAttribute("Status", "Waiting for players")
				task.wait(2)
				continue
			end
			setSky(14)
			for remaining = waves.BreakSeconds, 1, -1 do
				kit:SetAttribute("Status", `Wave {wave + 1} incoming`)
				kit:SetAttribute("Timer", remaining)
				task.wait(1)
			end
			kit:SetAttribute("Timer", 0)
			setSky(0)
			wave += 1
			kit:SetAttribute("Wave", wave)
			local list = spawners()
			if #list == 0 then
				warn('[GameKit] Waves: no part tagged "EnemySpawner"')
				task.wait(5)
				continue
			end
			local total = waves.FirstWaveSize + (wave - 1) * waves.GrowthPerWave
			for i = 1, total do
				local spawner = list[(i - 1) % #list + 1]
				spawnEnemy(spawnerType(spawner), spawner.CFrame)
				task.wait(0.3)
			end
			while aliveCount() > 0 and anyoneAlive() do
				kit:SetAttribute("Status", `Wave {wave}: {aliveCount()} enemies left`)
				task.wait(1)
			end
			if anyoneAlive() then
				Net.notify(nil, `Wave {wave} cleared!`, "success")
				for _, player in Players:GetPlayers() do
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						for stat, amount in pairs(waves.SurviveRewards or {}) do
							PlayerData.reward(player, stat, amount * wave)
						end
					end
				end
			else
				Net.notify(nil, `Everyone fell on wave {wave}. Restarting...`, "error")
				for model in enemies do
					model:Destroy()
				end
				table.clear(enemies)
				wave = 0
				kit:SetAttribute("Wave", 0)
				for _, player in Players:GetPlayers() do
					Util.respawn(player)
				end
			end
		end
	end)
end
