-- GameKit Movers (ServerScriptService.GameKit.Movers)
-- Moving obstacles driven by tags + attributes (all optional):
--   "MovingPlatform" : Offset (Vector3, default 0,0,16), Duration (s, 3), Pause (s, 0.5)
--   "Spinner"        : Speed (degrees/s, 90), Axis ("X" | "Y" | "Z", "Y")
--   "Disappearing"   : OnTime (s, 2), OffTime (s, 1.5), Offset (s, 0) -- blinks in and out
--   "FallingPlatform": Delay (s, 0.6), RespawnTime (s, 3)          -- drops after a touch
--   "Conveyor"       : Speed (studs/s, 16) -- pushes along the part's front (LookVector)
--   "Teleporter"     : Target (name of a part anywhere in Workspace)
-- Platforms carry players because their velocity is set every frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))

local function number(part: Instance, name: string, default: number): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else default
end

-- Moving platforms and spinners ------------------------------------------------------------
type Mover = { part: BasePart, origin: CFrame, kind: string, previous: Vector3 }
local movers: { [BasePart]: Mover } = {}

local function addMover(instance: Instance, kind: string)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	part.Anchored = true
	movers[part] = { part = part, origin = part.CFrame, kind = kind, previous = part.Position }
end

local function removeMover(instance: Instance)
	movers[instance :: BasePart] = nil
end

Util.onTag("MovingPlatform", function(instance)
	addMover(instance, "move")
end, removeMover)
Util.onTag("Spinner", function(instance)
	addMover(instance, "spin")
end, removeMover)

local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

RunService.Heartbeat:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	for part, mover in movers do
		if not part.Parent then
			movers[part] = nil
			continue
		end
		if mover.kind == "move" then
			local offsetValue = part:GetAttribute("Offset")
			local offset = if typeof(offsetValue) == "Vector3" then offsetValue else Vector3.new(0, 0, 16)
			local duration = math.max(0.2, number(part, "Duration", 3))
			local pause = math.max(0, number(part, "Pause", 0.5))
			local cycle = (duration + pause) * 2
			local t = now % cycle
			local alpha
			if t < pause then
				alpha = 0
			elseif t < pause + duration then
				alpha = (t - pause) / duration
			elseif t < pause * 2 + duration then
				alpha = 1
			else
				alpha = 1 - (t - pause * 2 - duration) / duration
			end
			alpha = (1 - math.cos(alpha * math.pi)) / 2 -- smooth start and stop
			local target = mover.origin + offset * alpha
			part.CFrame = target
			part.AssemblyLinearVelocity = (target.Position - mover.previous) / math.max(dt, 1 / 240)
			mover.previous = target.Position
		else
			local speed = number(part, "Speed", 90)
			local axisName = part:GetAttribute("Axis")
			local axis = AXES[if type(axisName) == "string" then string.upper(axisName) else "Y"] or Vector3.yAxis
			local angle = math.rad(speed) * now
			part.CFrame = mover.origin * CFrame.fromAxisAngle(axis, angle)
			part.AssemblyAngularVelocity = mover.origin:VectorToWorldSpace(axis) * math.rad(speed)
		end
	end
end)

-- Disappearing platforms --------------------------------------------------------------------
local function setSolid(part: BasePart, solid: boolean, baseTransparency: number)
	part.CanCollide = solid
	part.CanTouch = solid
	TweenService:Create(part, TweenInfo.new(0.2), { Transparency = if solid then baseTransparency else 0.9 }):Play()
end

Util.onTag("Disappearing", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	local base = part.Transparency
	task.spawn(function()
		task.wait(number(part, "Offset", 0))
		while part.Parent do
			setSolid(part, true, base)
			task.wait(math.max(0.2, number(part, "OnTime", 2)))
			if not part.Parent then
				break
			end
			-- Warning blink before vanishing.
			for _ = 1, 3 do
				part.Transparency = math.min(1, base + 0.5)
				task.wait(0.12)
				part.Transparency = base
				task.wait(0.12)
			end
			setSolid(part, false, base)
			task.wait(math.max(0.2, number(part, "OffTime", 1.5)))
		end
	end)
end)

-- Falling platforms ------------------------------------------------------------------------
Util.onTag("FallingPlatform", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	local base = part.Transparency
	local busy = false
	part.Touched:Connect(function(hit)
		if busy or not Util.playerFromHit(hit) then
			return
		end
		busy = true
		local origin = part.CFrame
		TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 3, true), {
			CFrame = origin * CFrame.new(0.3, 0, 0),
		}):Play()
		task.wait(number(part, "Delay", 0.6))
		part.CanCollide = false
		TweenService:Create(part, TweenInfo.new(0.5), { Transparency = 1, CFrame = origin - Vector3.new(0, 8, 0) }):Play()
		task.wait(number(part, "RespawnTime", 3))
		part.CFrame = origin
		part.Transparency = base
		part.CanCollide = true
		busy = false
	end)
end)

-- Conveyors -------------------------------------------------------------------------------
Util.onTag("Conveyor", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	part.Anchored = true
	local function refresh()
		part.AssemblyLinearVelocity = part.CFrame.LookVector * number(part, "Speed", 16)
	end
	refresh()
	part:GetAttributeChangedSignal("Speed"):Connect(refresh)
	part:GetPropertyChangedSignal("CFrame"):Connect(refresh)
end)

-- Teleporters -----------------------------------------------------------------------------
local teleportCooldown = Util.cooldown(1.5)
Util.onTag("Teleporter", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	part.Touched:Connect(function(hit)
		local player, character = Util.playerFromHit(hit)
		if not player or not character or not teleportCooldown(player) then
			return
		end
		local targetName = part:GetAttribute("Target")
		local target = if type(targetName) == "string" then workspace:FindFirstChild(targetName, true) else nil
		if target and target:IsA("BasePart") then
			Util.teleportOnto(character, target)
		else
			warn(`[GameKit] Teleporter {part:GetFullName()} has no valid "Target" attribute`)
		end
	end)
end)
