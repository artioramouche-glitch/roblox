-- GameKit Racing (ServerScriptService.GameKit.Racing)
-- Races in rounds: intermission -> grid -> 3-2-1-GO -> laps -> results -> again.
--   Track:  parts tagged "RaceCheckpoint" with attribute Order (1, 2, 3...) passed in order,
--           and a part tagged "RaceFinish" (the start/finish line).
--   Grid:   parts tagged "RaceGrid" (attribute Order): where racers start.
--   Karts:  Config.Racing.UseKarts = true gives every racer an arcade kart (VehicleSeat:
--           WASD / thumbstick). false = running race (boost pads help).
-- Rewards by finishing position (Config.Racing.PlaceRewards). Best lap time is saved.
-- Player attributes for UIs: RaceLap, RaceLaps, RacePosition, RaceTime, BestLap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("Racing", {
	Laps = 3,
	MinPlayers = 1,
	IntermissionSeconds = 15,
	TimeLimit = 240,
	UseKarts = true,
	KartSpeed = 70,
	KartTurnSpeed = 2.4,
	KartColor = "#E53935",
	PlaceRewards = {
		{ Wins = 1, Coins = 100 },
		{ Coins = 60 },
		{ Coins = 40 },
	},
	FinishRewards = { Coins = 15 },
})

for _, rewards in config.PlaceRewards do
	for stat in pairs(rewards) do
		PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
	end
end
for stat in pairs(config.FinishRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
end
PlayerData.defineStat({ Name = "BestLap", Default = 0, Leaderstat = false })

type Racer = {
	player: Player,
	lap: number,
	nextCheckpoint: number,
	lapStart: number,
	finished: boolean,
	finishTime: number?,
	kart: Model?,
}

local racers: { [Player]: Racer } = {}
local raceStart = 0
local running = false
local finishOrder: { Player } = {}
local karts = Instance.new("Folder")
karts.Name = "RaceKarts"
karts.Parent = workspace

local function setStatus(text: string, timer: number?)
	kit:SetAttribute("Status", text)
	kit:SetAttribute("Timer", timer or 0)
end

local function orderOf(part: Instance): number
	local value = part:GetAttribute("Order")
	return if type(value) == "number" then value else 0
end

local function checkpointCount(): number
	local highest = 0
	for _, part in CollectionService:GetTagged("RaceCheckpoint") do
		highest = math.max(highest, orderOf(part))
	end
	return highest
end

-- Karts ------------------------------------------------------------------------------------

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function buildKart(at: CFrame): (Model, VehicleSeat)
	local model = Instance.new("Model")
	model.Name = "Kart"
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(5, 1.2, 8)
	chassis.CFrame = at + Vector3.new(0, 2, 0)
	chassis.Color = Util.color(config.KartColor, Color3.fromRGB(229, 57, 53))
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1, 0.2, 0, 1, 1)
	chassis.Parent = model
	model.PrimaryPart = chassis
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2.5, 1, 2.5)
	seat.CFrame = chassis.CFrame * CFrame.new(0, 1, 0.8)
	seat.MaxSpeed = config.KartSpeed
	seat.Color = Color3.fromRGB(40, 40, 45)
	seat.Parent = model
	weld(chassis, seat)
	for _, corner in { Vector3.new(-2.6, -0.4, -2.8), Vector3.new(2.6, -0.4, -2.8), Vector3.new(-2.6, -0.4, 2.8), Vector3.new(2.6, -0.4, 2.8) } do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel"
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(1, 2, 2)
		wheel.CFrame = chassis.CFrame * CFrame.new(corner)
		wheel.Color = Color3.fromRGB(25, 25, 25)
		wheel.CanCollide = false
		wheel.Massless = true
		wheel.Parent = model
		weld(chassis, wheel)
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = attachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	drive.LineDirection = Vector3.new(0, 0, -1)
	drive.LineVelocity = 0
	drive.MaxForce = 30000
	drive.Parent = chassis
	local turn = Instance.new("AngularVelocity")
	turn.Name = "Turn"
	turn.Attachment0 = attachment
	turn.RelativeTo = Enum.ActuatorRelativeTo.World
	turn.AngularVelocity = Vector3.zero
	turn.MaxTorque = 60000
	turn.Parent = chassis
	-- Keeps the kart upright (only the up axis is aligned, steering stays free).
	local up = Instance.new("Attachment")
	up.Name = "Up"
	up.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.zAxis)
	up.Parent = chassis
	local upright = Instance.new("AlignOrientation")
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.AlignType = Enum.AlignType.PrimaryAxisParallel
	upright.PrimaryAxis = Vector3.yAxis
	upright.Attachment0 = up
	upright.MaxTorque = 40000
	upright.Responsiveness = 20
	upright.Parent = chassis
	model.Parent = karts
	return model, seat
end

-- Arcade handling: throttle drives along the kart's forward line, steer spins it (and keeps it upright).
RunService.Heartbeat:Connect(function()
	for _, kart in karts:GetChildren() do
		local chassis = kart:FindFirstChild("Chassis")
		local seat = kart:FindFirstChild("Seat")
		if chassis and seat and seat:IsA("VehicleSeat") then
			local drive = chassis:FindFirstChild("Drive")
			local turn = chassis:FindFirstChild("Turn")
			local canMove = running or not kart:GetAttribute("Locked")
			if drive and drive:IsA("LinearVelocity") then
				drive.LineVelocity = if canMove then seat.ThrottleFloat * config.KartSpeed else 0
			end
			if turn and turn:IsA("AngularVelocity") then
				local forward = if seat.ThrottleFloat < 0 then -1 else 1
				turn.AngularVelocity = Vector3.new(0, if canMove then -seat.SteerFloat * config.KartTurnSpeed * forward else 0, 0)
			end
		end
	end
end)

-- Race logic ------------------------------------------------------------------------------

local function playerOf(hit: BasePart): Player?
	local player = Util.playerFromHit(hit)
	if player then
		return player
	end
	local kart = hit:FindFirstAncestor("Kart")
	local driver = kart and kart:GetAttribute("Driver")
	return if type(driver) == "number" then Players:GetPlayerByUserId(driver) else nil
end

local function publish(racer: Racer)
	local player = racer.player
	player:SetAttribute("RaceLap", math.min(racer.lap, config.Laps))
	player:SetAttribute("RaceLaps", config.Laps)
end

local function lapFinished(racer: Racer)
	local now = os.clock()
	local lapTime = now - racer.lapStart
	racer.lapStart = now
	local best = PlayerData.get(racer.player, "BestLap")
	if best == 0 or lapTime < best then
		PlayerData.set(racer.player, "BestLap", math.floor(lapTime * 100) / 100)
		Net.notify(racer.player, `⏱ Best lap: {string.format("%.2f", lapTime)}s`, "success")
	end
	racer.lap += 1
	racer.nextCheckpoint = 1
	if racer.lap > config.Laps then
		racer.finished = true
		racer.finishTime = now - raceStart
		table.insert(finishOrder, racer.player)
		local place = #finishOrder
		Net.notify(racer.player, `🏁 Finished #{place} in {string.format("%.1f", racer.finishTime or 0)}s!`, "reward")
		Analytics.custom(racer.player, "RaceFinished", place)
	end
	publish(racer)
end

local function onCheckpoint(part: BasePart, hit: BasePart, isFinish: boolean)
	if not running then
		return
	end
	local player = playerOf(hit)
	local racer = player and racers[player]
	if not racer or racer.finished then
		return
	end
	local total = checkpointCount()
	if isFinish then
		if racer.nextCheckpoint > total then
			lapFinished(racer)
		end
	elseif orderOf(part) == racer.nextCheckpoint then
		racer.nextCheckpoint += 1
	end
end

Util.onTag("RaceCheckpoint", function(instance)
	if instance:IsA("BasePart") then
		instance.Touched:Connect(function(hit)
			onCheckpoint(instance, hit, false)
		end)
	end
end)
Util.onTag("RaceFinish", function(instance)
	if instance:IsA("BasePart") then
		instance.Touched:Connect(function(hit)
			onCheckpoint(instance, hit, true)
		end)
	end
end)

local function gridSlots(): { BasePart }
	local slots = {}
	for _, part in CollectionService:GetTagged("RaceGrid") do
		if part:IsA("BasePart") then
			table.insert(slots, part)
		end
	end
	table.sort(slots, function(a, b)
		return orderOf(a) < orderOf(b)
	end)
	return slots
end

local function positions(): { Racer }
	local list = {}
	for _, racer in racers do
		table.insert(list, racer)
	end
	table.sort(list, function(a, b)
		if a.finished ~= b.finished then
			return a.finished
		end
		if a.finished and b.finished then
			return (a.finishTime or 0) < (b.finishTime or 0)
		end
		if a.lap ~= b.lap then
			return a.lap > b.lap
		end
		return a.nextCheckpoint > b.nextCheckpoint
	end)
	return list
end

local function cleanup()
	for _, racer in racers do
		racer.player:SetAttribute("RaceLap", nil)
		racer.player:SetAttribute("RacePosition", nil)
	end
	racers = {}
	finishOrder = {}
	karts:ClearAllChildren()
end

local function startRace(): boolean
	local slots = gridSlots()
	if #slots == 0 or checkpointCount() == 0 then
		setStatus("Racing: build a track (build_world race_track)")
		return false
	end
	local ready = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and humanoid.Health > 0 and PlayerData.isLoaded(player) then
			table.insert(ready, player)
		end
	end
	if #ready < config.MinPlayers then
		setStatus(`Waiting for {config.MinPlayers} racers...`)
		return false
	end
	for index, player in ready do
		local slot = slots[((index - 1) % #slots) + 1]
		local character = player.Character :: Model
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		local racer: Racer = { player = player, lap = 1, nextCheckpoint = 1, lapStart = 0, finished = false }
		if config.UseKarts then
			local kart, seat = buildKart(slot.CFrame)
			kart:SetAttribute("Driver", player.UserId)
			kart:SetAttribute("Locked", true)
			character:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
			seat:Sit(humanoid)
			racer.kart = kart
		else
			Util.teleportOnto(character, slot)
		end
		racers[player] = racer
		publish(racer)
	end
	for count = 3, 1, -1 do
		setStatus(`🚦 {count}...`)
		task.wait(1)
	end
	setStatus("🟢 GO!")
	running = true
	raceStart = os.clock()
	for _, racer in racers do
		racer.lapStart = raceStart
		if racer.kart then
			racer.kart:SetAttribute("Locked", false)
		end
	end
	return true
end

local function runRace()
	while running do
		local elapsed = os.clock() - raceStart
		local allDone = true
		for place, racer in positions() do
			racer.player:SetAttribute("RacePosition", place)
			racer.player:SetAttribute("RaceTime", math.floor(elapsed))
			if not racer.finished and racer.player.Parent then
				allDone = false
			end
		end
		setStatus(`🏁 Race  •  {#finishOrder}/{#positions()} finished`, math.max(0, config.TimeLimit - math.floor(elapsed)))
		if allDone or elapsed >= config.TimeLimit then
			running = false
		end
		task.wait(0.5)
	end
	for place, player in finishOrder do
		local rewards = config.PlaceRewards[place]
		for stat, amount in pairs(rewards or {}) do
			PlayerData.reward(player, stat, amount, "Gameplay")
		end
		for stat, amount in pairs(config.FinishRewards) do
			PlayerData.reward(player, stat, amount, "Gameplay")
		end
	end
	local winner = finishOrder[1]
	setStatus(if winner then `🏆 {winner.DisplayName} wins!` else "⌛ Time is up!")
	task.wait(5)
	for _, racer in racers do
		local character = racer.player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.Sit = false
		end
		Util.respawn(racer.player)
	end
	cleanup()
end

Players.PlayerRemoving:Connect(function(player)
	local racer = racers[player]
	if racer and racer.kart then
		racer.kart:Destroy()
	end
	racers[player] = nil
end)

-- Test hook used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string)
	if action == "track" then
		return { checkpoints = checkpointCount(), grid = #gridSlots(), finish = #CollectionService:GetTagged("RaceFinish") }
	elseif action == "kart" then
		local slot = gridSlots()[1]
		if not slot then
			return false
		end
		local kart = buildKart(slot.CFrame + Vector3.new(0, 20, 0))
		local ok = kart.PrimaryPart ~= nil and kart:FindFirstChild("Seat") ~= nil
		kart:Destroy()
		return ok
	end
	return nil
end
hook.Parent = script

task.spawn(function()
	while true do
		for remaining = config.IntermissionSeconds, 1, -1 do
			setStatus("🏎 Next race in", remaining)
			task.wait(1)
		end
		if startRace() then
			runRace()
		else
			task.wait(3)
		end
	end
end)
