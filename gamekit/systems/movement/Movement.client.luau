-- GameKit Movement (StarterPlayerScripts.GameKit.Movement)
-- Sprint (Shift, or the on-screen button on mobile) and optional double jump.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Util = require(ReplicatedStorage:WaitForChild("GameKit"):WaitForChild("Util"))

local config = Util.config("Movement", {
	Sprint = true,
	SprintMultiplier = 1.6,
	DoubleJump = true,
	DoubleJumpPower = 55,
})

local player = Players.LocalPlayer
local sprinting = false
local humanoid: Humanoid? = nil
local baseSpeed = 16
local usedDoubleJump = false

local function setSprint(on: boolean)
	if not humanoid then
		return
	end
	if on and not sprinting then
		baseSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = baseSpeed * config.SprintMultiplier
	elseif not on and sprinting then
		humanoid.WalkSpeed = baseSpeed
	end
	sprinting = on
end

local function onCharacter(character: Model)
	sprinting = false
	usedDoubleJump = false
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local h = humanoid :: Humanoid
	h.StateChanged:Connect(function(_, state)
		if state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running then
			usedDoubleJump = false
		end
	end)
end

if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)

if config.Sprint then
	ContextActionService:BindAction("GK_Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			setSprint(not sprinting or UserInputService.KeyboardEnabled)
		elseif state == Enum.UserInputState.End and UserInputService.KeyboardEnabled then
			setSprint(false)
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("GK_Sprint", "Run")
end

if config.DoubleJump then
	UserInputService.JumpRequest:Connect(function()
		local h = humanoid
		if not h or h.Health <= 0 or usedDoubleJump then
			return
		end
		local state = h:GetState()
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
			local root = h.RootPart
			if root then
				usedDoubleJump = true
				local velocity = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, config.DoubleJumpPower, velocity.Z)
				h:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end)
end
