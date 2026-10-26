-- GameKit Collectibles client (StarterPlayerScripts.GameKit.CollectiblesClient)
-- Makes coins spin and bob, and plays a small burst when you collect one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))

local animated: { [BasePart]: CFrame } = {}

local function track(instance: Instance)
	if instance:IsA("BasePart") and instance:GetAttribute("Spin") ~= false then
		animated[instance] = instance.CFrame
	end
end

local function untrack(instance: Instance)
	animated[instance :: BasePart] = nil
end

Util.onTag("Coin", track, untrack)
Util.onTag("Collectible", track, untrack)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for part, origin in animated do
		if not part.Parent then
			animated[part] = nil
			continue
		end
		local phase = (origin.Position.X + origin.Position.Z) * 0.1
		part.CFrame = CFrame.new(origin.Position + Vector3.new(0, math.sin(t * 2 + phase) * 0.4, 0))
			* CFrame.Angles(0, t * 2 + phase, 0)
			* origin.Rotation
	end
end)

Net.listen("GK_Collected", function(position: Vector3)
	local burst = Instance.new("Part")
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.Shape = Enum.PartType.Ball
	burst.Material = Enum.Material.Neon
	burst.Color = Color3.fromRGB(255, 220, 90)
	burst.Size = Vector3.one * 1.5
	burst.Position = position
	burst.Parent = workspace
	TweenService:Create(burst, TweenInfo.new(0.35), { Size = Vector3.one * 5, Transparency = 1 }):Play()
	task.delay(0.4, function()
		burst:Destroy()
	end)
end)
