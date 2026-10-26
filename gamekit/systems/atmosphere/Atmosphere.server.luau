-- GameKit Atmosphere (ServerScriptService.GameKit.Atmosphere)
-- Day/night cycle. (Lighting presets are applied at edit time with the set_environment tool.)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Util = require(ReplicatedStorage:WaitForChild("GameKit"):WaitForChild("Util"))

local config = Util.config("Atmosphere", {
	DayNightCycle = true,
	DayLengthMinutes = 12,
	StartTime = 14,
})

if config.StartTime then
	Lighting.ClockTime = config.StartTime
end

if config.DayNightCycle then
	local hoursPerSecond = 24 / math.max(1, config.DayLengthMinutes * 60)
	RunService.Heartbeat:Connect(function(dt)
		Lighting.ClockTime = (Lighting.ClockTime + dt * hoursPerSecond) % 24
	end)
end
