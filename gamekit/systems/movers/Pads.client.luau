-- GameKit Pads (StarterPlayerScripts.GameKit.Pads)
-- Characters are simulated by their own player's computer, so launches happen here.
--   "JumpPad"  : Power (studs/s upward, default 90)
--   "SpeedPad" : Speed (WalkSpeed, default 40), Duration (s, default 3)
--   "BoostPad" : Power (studs/s forward along the pad's LookVector, default 80)

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage:WaitForChild("GameKit"):WaitForChild("Util"))

local player = Players.LocalPlayer
local cooldown = Util.cooldown(0.4)
local speedToken = 0

local function number(part: Instance, name: string, default: number): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else default
end

local function myRoot(hit: BasePart): (BasePart?, Humanoid?)
	local character = player.Character
	if not character or not hit:IsDescendantOf(character) then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil
	end
	return root, humanoid
end

local function boing(pad: BasePart)
	local sound = pad:FindFirstChildOfClass("Sound")
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

local function hookPad(tag: string, onTouch: (BasePart, BasePart, Humanoid) -> ())
	Util.onTag(tag, function(instance)
		if not instance:IsA("BasePart") then
			return
		end
		local pad = instance :: BasePart
		pad.Touched:Connect(function(hit)
			local root, humanoid = myRoot(hit)
			if root and humanoid and cooldown(pad) then
				onTouch(pad, root, humanoid)
				boing(pad)
			end
		end)
	end)
end

hookPad("JumpPad", function(pad, root, humanoid)
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, number(pad, "Power", 90), velocity.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
end)

hookPad("BoostPad", function(pad, root)
	local push = pad.CFrame.LookVector * number(pad, "Power", 80)
	root.AssemblyLinearVelocity = Vector3.new(push.X, math.max(root.AssemblyLinearVelocity.Y, 20), push.Z)
end)

hookPad("SpeedPad", function(pad, _root, humanoid)
	speedToken += 1
	local token = speedToken
	local normal = humanoid:GetAttribute("GK_NormalSpeed")
	if type(normal) ~= "number" then
		normal = humanoid.WalkSpeed
		humanoid:SetAttribute("GK_NormalSpeed", normal)
	end
	humanoid.WalkSpeed = number(pad, "Speed", 40)
	task.delay(number(pad, "Duration", 3), function()
		if token == speedToken and humanoid.Parent then
			humanoid.WalkSpeed = normal
			humanoid:SetAttribute("GK_NormalSpeed", nil)
		end
	end)
end)
