-- GameKit Tower Defense (ServerScriptService.GameKit.TowerDefense)
-- Co-op tower defense: enemies walk a path in waves, players build and upgrade towers on
-- pads with the match currency, and defend the base together.
--   Path:  a Folder/Model tagged "TDPath" whose parts are waypoints, walked in the order of
--          their "Order" attribute (or the number in their name: WP1, WP2...).
--   Base:  a part tagged "TDBase" (at the end of the path) - shows the base health.
--   Pads:  parts tagged "TowerPad" with attribute Tower = a name from Config.TowerDefense.Towers.
--          A prompt builds the tower, then upgrades it; a second prompt sells it.
-- Shared state (attributes on ReplicatedStorage.GameKit): Wave, BaseHealth, BaseMaxHealth,
-- EnemiesAlive, Status, Timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("TowerDefense", {
	CashStat = "Cash",
	StartCash = 250,
	BaseHealth = 100,
	MinPlayers = 1,
	IntermissionSeconds = 12,
	TimeBetweenWaves = 6,
	MaxWaves = 15,
	HealthScalePerWave = 0.18,
	WaveCashReward = 60,
	WinRewards = { Wins = 1, Coins = 150 },
	SellRefund = 0.6,
	UpgradeDamage = 1.5,
	UpgradeRange = 1.12,
	Waves = {
		{ Enemy = "Basic", Count = 6, Interval = 1.4 },
		{ Enemy = "Basic", Count = 10, Interval = 1.1 },
		{ Enemy = "Fast", Count = 8, Interval = 0.9 },
		{ Enemy = "Tank", Count = 3, Interval = 2.5 },
		{ Enemy = "Basic", Count = 14, Interval = 0.8 },
		{ Enemy = "Fast", Count = 14, Interval = 0.6 },
		{ Enemy = "Tank", Count = 6, Interval = 1.8 },
		{ Enemy = "Boss", Count = 1, Interval = 1 },
	},
	Enemies = {
		Basic = { Health = 12, Speed = 8, Reward = 6, Damage = 5, Color = "#8BC34A", Size = 2.6 },
		Fast = { Health = 8, Speed = 15, Reward = 6, Damage = 4, Color = "#FFEB3B", Size = 2 },
		Tank = { Health = 70, Speed = 5, Reward = 20, Damage = 15, Color = "#795548", Size = 4 },
		Boss = { Health = 450, Speed = 4, Reward = 150, Damage = 60, Color = "#9C27B0", Size = 6.5 },
	},
	Towers = {
		Archer = { Price = 100, Damage = 3, Range = 24, FireRate = 0.6, Color = "#4CAF50", UpgradePrice = 120, MaxLevel = 3, Icon = "🏹" },
		Cannon = { Price = 200, Damage = 8, Range = 20, FireRate = 1.6, Splash = 9, Color = "#607D8B", UpgradePrice = 220, MaxLevel = 3, Icon = "💣" },
		Frost = { Price = 150, Damage = 1, Range = 18, FireRate = 1, Slow = 0.5, SlowSeconds = 2, Color = "#4FC3F7", UpgradePrice = 160, MaxLevel = 3, Icon = "❄️" },
	},
})

local CASH = config.CashStat
PlayerData.defineStat({ Name = CASH, Default = config.StartCash, Leaderstat = true, Save = false })
for stat in pairs(config.WinRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
end

type Enemy = {
	part: BasePart,
	kind: string,
	health: number,
	maxHealth: number,
	speed: number,
	reward: number,
	damage: number,
	index: number,
	progress: number,
	slowUntil: number,
	slowFactor: number,
	bar: Frame,
}

type Tower = {
	pad: BasePart,
	model: Model,
	kind: string,
	level: number,
	owner: Player?,
	spent: number,
	cooldown: number,
}

local enemies: { Enemy } = {}
local towers: { [BasePart]: Tower } = {}
local waypoints: { Vector3 } = {}
local baseHealth = config.BaseHealth
local folder = Instance.new("Folder")
folder.Name = "TDActive"
folder.Parent = workspace

local function setState(status: string, timer: number?)
	kit:SetAttribute("Status", status)
	kit:SetAttribute("Timer", timer or 0)
end

local function refreshBase()
	kit:SetAttribute("BaseHealth", math.max(0, math.floor(baseHealth)))
	kit:SetAttribute("BaseMaxHealth", config.BaseHealth)
	for _, base in CollectionService:GetTagged("TDBase") do
		local label = base:FindFirstChild("GK_BaseLabel")
		if label then
			local text = label:FindFirstChildOfClass("TextLabel")
			if text then
				text.Text = `🏰 {math.max(0, math.floor(baseHealth))} / {config.BaseHealth}`
			end
		end
	end
end

-- Path ----------------------------------------------------------------------------------

local function orderOf(part: Instance): number
	local value = part:GetAttribute("Order")
	if type(value) == "number" then
		return value
	end
	return tonumber(string.match(part.Name, "%d+")) or 0
end

local function loadPath()
	local path = CollectionService:GetTagged("TDPath")[1]
	waypoints = {}
	if not path then
		warn("[GameKit] TowerDefense: no path. Tag a Folder of waypoint parts \"TDPath\" (build_world td_map).")
		return
	end
	local parts = {}
	for _, child in path:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	table.sort(parts, function(a, b)
		return orderOf(a) < orderOf(b)
	end)
	for _, part in parts do
		table.insert(waypoints, part.Position)
	end
end

-- Enemies -------------------------------------------------------------------------------

local function healthBar(part: BasePart): Frame
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 8)
	gui.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = part
	return fill
end

local function spawnEnemy(kind: string, wave: number)
	local def = config.Enemies[kind] or config.Enemies.Basic
	if not def or #waypoints < 2 then
		return
	end
	local scale = 1 + config.HealthScalePerWave * math.max(0, wave - 1)
	local size = def.Size or 2.5
	local part = Instance.new("Part")
	part.Name = kind
	part.Shape = if kind == "Tank" or kind == "Boss" then Enum.PartType.Block else Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = Util.color(def.Color, Color3.fromRGB(140, 200, 80))
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = waypoints[1] + Vector3.new(0, size / 2 + 0.5, 0)
	part:AddTag("TDEnemy")
	part.Parent = folder
	local health = (def.Health or 10) * scale
	table.insert(enemies, {
		part = part,
		kind = kind,
		health = health,
		maxHealth = health,
		speed = def.Speed or 8,
		reward = def.Reward or 5,
		damage = def.Damage or 5,
		index = 2,
		progress = 0,
		slowUntil = 0,
		slowFactor = 1,
		bar = healthBar(part),
	})
	kit:SetAttribute("EnemiesAlive", #enemies)
end

local function removeEnemy(enemy: Enemy)
	local index = table.find(enemies, enemy)
	if index then
		table.remove(enemies, index)
	end
	enemy.part:Destroy()
	kit:SetAttribute("EnemiesAlive", #enemies)
end

local function damageEnemy(enemy: Enemy, amount: number, owner: Player?)
	if enemy.health <= 0 then
		return
	end
	enemy.health -= amount
	enemy.bar.Size = UDim2.fromScale(math.clamp(enemy.health / enemy.maxHealth, 0, 1), 1)
	if enemy.health <= 0 then
		if owner and owner.Parent then
			PlayerData.reward(owner, CASH, enemy.reward)
		end
		removeEnemy(enemy)
	end
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for i = #enemies, 1, -1 do
		local enemy = enemies[i]
		if enemy and enemy.part.Parent then
			local factor = if now < enemy.slowUntil then enemy.slowFactor else 1
			local step = enemy.speed * factor * dt
			local position = enemy.part.Position
			while step > 0 and enemy.index <= #waypoints do
				local target = waypoints[enemy.index] + Vector3.new(0, enemy.part.Size.Y / 2 + 0.5, 0)
				local offset = target - position
				local distance = offset.Magnitude
				if distance <= step then
					position = target
					step -= distance
					enemy.progress += distance
					enemy.index += 1
				else
					position += offset.Unit * step
					enemy.progress += step
					step = 0
				end
			end
			if enemy.index > #waypoints then
				baseHealth -= enemy.damage
				refreshBase()
				removeEnemy(enemy)
			else
				local ahead = waypoints[enemy.index] + Vector3.new(0, enemy.part.Size.Y / 2 + 0.5, 0)
				if (ahead - position).Magnitude > 0.01 then
					enemy.part.CFrame = CFrame.lookAt(position, ahead)
				else
					enemy.part.Position = position
				end
			end
		end
	end
end)

-- Towers --------------------------------------------------------------------------------

local function towerStats(tower: Tower)
	local def = config.Towers[tower.kind]
	local level = tower.level
	return {
		damage = (def.Damage or 1) * config.UpgradeDamage ^ (level - 1),
		range = (def.Range or 20) * config.UpgradeRange ^ (level - 1),
		fireRate = def.FireRate or 1,
		splash = def.Splash,
		slow = def.Slow,
		slowSeconds = def.SlowSeconds or 2,
		color = Util.color(def.Color, Color3.fromRGB(200, 200, 200)),
	}
end

local function buildModel(pad: BasePart, kind: string, level: number): Model
	local def = config.Towers[kind]
	local color = Util.color(def.Color, Color3.fromRGB(200, 200, 200))
	local model = Instance.new("Model")
	model.Name = kind .. "Tower"
	local height = 5 + level * 2
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.Size = Vector3.new(5, height, 5)
	base.CFrame = pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + height / 2, 0)
	base.Color = Color3.fromRGB(120, 110, 100)
	base.Material = Enum.Material.Cobblestone
	base.Parent = model
	local top = Instance.new("Part")
	top.Name = "Top"
	top.Anchored = true
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.new(3.5, 3.5, 3.5)
	top.CFrame = base.CFrame * CFrame.new(0, height / 2 + 1.5, 0)
	top.Color = color
	top.Material = Enum.Material.Neon
	top.Parent = model
	for i = 1, level - 1 do
		local ring = Instance.new("Part")
		ring.Name = "Level" .. i
		ring.Anchored = true
		ring.CanCollide = false
		ring.Size = Vector3.new(5.4, 0.4, 5.4)
		ring.CFrame = base.CFrame * CFrame.new(0, -height / 2 + i * 2, 0)
		ring.Color = Color3.fromRGB(255, 215, 0)
		ring.Material = Enum.Material.Neon
		ring.Parent = model
	end
	model.PrimaryPart = top
	model.Parent = folder
	return model
end

local function refreshPad(pad: BasePart)
	local kind = tostring(pad:GetAttribute("Tower") or "Archer")
	local def = config.Towers[kind]
	local build = pad:FindFirstChild("GK_Build") :: ProximityPrompt?
	local sell = pad:FindFirstChild("GK_Sell") :: ProximityPrompt?
	if not def or not build or not sell then
		return
	end
	local tower = towers[pad]
	if not tower then
		build.ActionText = `Build ({Util.formatNumber(def.Price or 0)} {CASH})`
		build.ObjectText = `{def.Icon or ""} {kind} tower`
		build.Enabled = true
		sell.Enabled = false
	elseif tower.level < (def.MaxLevel or 3) then
		local price = (def.UpgradePrice or def.Price or 100) * tower.level
		build.ActionText = `Upgrade ({Util.formatNumber(price)} {CASH})`
		build.ObjectText = `{def.Icon or ""} {kind} level {tower.level}`
		build.Enabled = true
		sell.Enabled = true
	else
		build.Enabled = false
		sell.Enabled = true
	end
	sell.ActionText = `Sell`
	sell.ObjectText = `{kind} level {if tower then tower.level else 0}`
end

local function buildOrUpgrade(player: Player, pad: BasePart): boolean
	local kind = tostring(pad:GetAttribute("Tower") or "Archer")
	local def = config.Towers[kind]
	if not def then
		Net.notify(player, `Unknown tower "{kind}" (Config.TowerDefense.Towers)`, "error")
		return false
	end
	local tower = towers[pad]
	if tower and tower.level >= (def.MaxLevel or 3) then
		return false
	end
	local price = if tower then (def.UpgradePrice or def.Price or 100) * tower.level else def.Price or 100
	if not PlayerData.spend(player, CASH, price, kind, "Gameplay") then
		Net.notify(player, `You need {Util.formatNumber(price)} {CASH}!`, "error")
		return false
	end
	if tower then
		tower.level += 1
		tower.spent += price
		tower.model:Destroy()
		tower.model = buildModel(pad, kind, tower.level)
		Net.notify(player, `{kind} upgraded to level {tower.level}!`, "success")
	else
		towers[pad] = { pad = pad, model = buildModel(pad, kind, 1), kind = kind, level = 1, owner = player, spent = price, cooldown = 0 }
		Net.notify(player, `{def.Icon or ""} {kind} built!`, "success")
	end
	refreshPad(pad)
	return true
end

local function sellTower(player: Player, pad: BasePart)
	local tower = towers[pad]
	if not tower then
		return
	end
	local refund = math.floor(tower.spent * config.SellRefund)
	tower.model:Destroy()
	towers[pad] = nil
	PlayerData.add(player, CASH, refund)
	Net.notify(player, `Sold for {Util.formatNumber(refund)} {CASH}`, "info")
	refreshPad(pad)
end

Util.onTag("TowerPad", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local pad = instance :: BasePart
	local build = Instance.new("ProximityPrompt")
	build.Name = "GK_Build"
	build.KeyboardKeyCode = Enum.KeyCode.E
	build.RequiresLineOfSight = false
	build.MaxActivationDistance = 12
	build.Parent = pad
	local sell = Instance.new("ProximityPrompt")
	sell.Name = "GK_Sell"
	sell.KeyboardKeyCode = Enum.KeyCode.R
	sell.RequiresLineOfSight = false
	sell.MaxActivationDistance = 12
	sell.UIOffset = Vector2.new(0, 70)
	sell.Parent = pad
	build.Triggered:Connect(function(player)
		buildOrUpgrade(player, pad)
	end)
	sell.Triggered:Connect(function(player)
		sellTower(player, pad)
	end)
	refreshPad(pad)
end)

local function shot(from: Vector3, to: Vector3, color: Color3)
	local distance = (to - from).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.3, 0.3, distance)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
	beam.Parent = folder
	Debris:AddItem(beam, 0.08)
end

task.spawn(function()
	while true do
		local dt = task.wait(0.1)
		local now = os.clock()
		for _, tower in towers do
			tower.cooldown -= dt
			if tower.cooldown <= 0 and tower.model.PrimaryPart then
				local stats = towerStats(tower)
				local origin = tower.model.PrimaryPart.Position
				local target: Enemy? = nil
				for _, enemy in enemies do
					if (enemy.part.Position - origin).Magnitude <= stats.range and (not target or enemy.progress > target.progress) then
						target = enemy
					end
				end
				if target then
					tower.cooldown = stats.fireRate
					local hitPosition = target.part.Position
					shot(origin, hitPosition, stats.color)
					if stats.slow then
						target.slowUntil = now + stats.slowSeconds
						target.slowFactor = stats.slow
					end
					if stats.splash then
						for i = #enemies, 1, -1 do
							local other = enemies[i]
							if other and (other.part.Position - hitPosition).Magnitude <= stats.splash then
								damageEnemy(other, stats.damage, tower.owner)
							end
						end
					else
						damageEnemy(target, stats.damage, tower.owner)
					end
				end
			end
		end
	end
end)

-- Match loop ----------------------------------------------------------------------------

local function waveSpec(wave: number)
	local list = config.Waves
	local spec = list[math.min(wave, #list)] or { Enemy = "Basic", Count = 8, Interval = 1 }
	local extra = math.max(0, wave - #list)
	return spec.Enemy or "Basic", (spec.Count or 8) + extra * 2, math.max(0.3, (spec.Interval or 1) - extra * 0.05)
end

local function resetMatch()
	for pad, tower in towers do
		tower.model:Destroy()
		towers[pad] = nil
		refreshPad(pad)
	end
	for i = #enemies, 1, -1 do
		removeEnemy(enemies[i])
	end
	baseHealth = config.BaseHealth
	refreshBase()
	kit:SetAttribute("Wave", 0)
	for _, player in Players:GetPlayers() do
		if PlayerData.isLoaded(player) then
			PlayerData.set(player, CASH, config.StartCash)
		end
	end
end

local function countdown(seconds: number, label: string)
	for remaining = seconds, 1, -1 do
		setState(label, remaining)
		task.wait(1)
	end
end

local function playWave(wave: number): boolean
	local kind, count, interval = waveSpec(wave)
	kit:SetAttribute("Wave", wave)
	for i = 1, count do
		if baseHealth <= 0 then
			break
		end
		spawnEnemy(kind, wave)
		setState(`🌊 Wave {wave}/{config.MaxWaves}  •  🏰 {math.max(0, math.floor(baseHealth))}  •  👾 {#enemies}`)
		task.wait(interval)
	end
	while #enemies > 0 and baseHealth > 0 do
		setState(`🌊 Wave {wave}/{config.MaxWaves}  •  🏰 {math.max(0, math.floor(baseHealth))}  •  👾 {#enemies}`)
		task.wait(0.5)
	end
	return baseHealth > 0
end

local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player, pad: BasePart?)
	if action == "build" and pad then
		return buildOrUpgrade(player, pad)
	elseif action == "towers" then
		local n = 0
		for _ in towers do
			n += 1
		end
		return n
	end
	return nil
end
hook.Parent = script

loadPath()
refreshBase()
task.spawn(function()
	while true do
		if #waypoints < 2 then
			setState("Tower defense: no path found (build_world td_map)")
			task.wait(5)
			loadPath()
		elseif #Players:GetPlayers() < config.MinPlayers then
			setState(`Waiting for {config.MinPlayers} players...`)
			task.wait(2)
		else
			countdown(config.IntermissionSeconds, "🛠 Build towers on the pads! First wave in")
			local won = true
			for wave = 1, config.MaxWaves do
				if not playWave(wave) then
					won = false
					break
				end
				for _, player in Players:GetPlayers() do
					PlayerData.add(player, CASH, config.WaveCashReward)
					Analytics.progression(player, "TowerDefense", wave, `Wave {wave}`)
				end
				if wave < config.MaxWaves then
					countdown(config.TimeBetweenWaves, `✅ Wave {wave} cleared! +{config.WaveCashReward} {CASH}. Next wave in`)
				end
			end
			if won then
				for _, player in Players:GetPlayers() do
					for stat, amount in pairs(config.WinRewards) do
						PlayerData.reward(player, stat, amount)
					end
					Analytics.custom(player, "TDVictory", config.MaxWaves)
				end
				Net.notify(nil, "🏆 Victory! The base survived every wave!", "reward")
				countdown(8, "🏆 VICTORY! New game in")
			else
				Net.notify(nil, "💥 The base was destroyed!", "error")
				countdown(6, "💥 Base destroyed! Restarting in")
			end
			resetMatch()
		end
	end
end)
