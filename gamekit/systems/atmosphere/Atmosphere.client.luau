-- GameKit Atmosphere client (StarterPlayerScripts.GameKit.AtmosphereClient)
--   * Background music: Config.Atmosphere.Music = { "rbxassetid://123", ... } (plays in order).
--     Use sounds you own or that are public (search with the MCP asset tools).
--   * Parts tagged "FlickerLight" (with a PointLight/SpotLight inside) flicker randomly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Util = require(ReplicatedStorage:WaitForChild("GameKit"):WaitForChild("Util"))

local config = Util.config("Atmosphere", {
	Music = {},
	MusicVolume = 0.3,
})

if #config.Music > 0 then
	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.Name = "GK_Music"
		sound.Volume = config.MusicVolume
		sound.Parent = SoundService
		local index = 0
		while true do
			index = index % #config.Music + 1
			sound.SoundId = config.Music[index]
			sound:Play()
			local deadline = os.clock() + 5
			while not sound.IsLoaded and os.clock() < deadline do
				task.wait(0.25)
			end
			if sound.IsLoaded then
				local finish = os.clock() + sound.TimeLength + 1
				while sound.IsPlaying and os.clock() < finish do
					task.wait(0.5)
				end
			else
				warn(`[GameKit] Music {sound.SoundId} did not load (not public or not owned?)`)
			end
		end
	end)
end

Util.onTag("FlickerLight", function(instance)
	local light = instance:FindFirstChildWhichIsA("Light", true)
	if not light then
		return
	end
	local baseBrightness = light.Brightness
	task.spawn(function()
		while instance.Parent do
			task.wait(math.random() * 3 + 0.5)
			for _ = 1, math.random(1, 4) do
				light.Brightness = baseBrightness * math.random() * 0.3
				if instance:IsA("BasePart") then
					instance.Material = Enum.Material.SmoothPlastic
				end
				task.wait(0.05 + math.random() * 0.1)
				light.Brightness = baseBrightness
				if instance:IsA("BasePart") then
					instance.Material = Enum.Material.Neon
				end
				task.wait(0.05 + math.random() * 0.1)
			end
		end
	end)
end)
