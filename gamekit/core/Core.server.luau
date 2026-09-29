-- GameKit Core (ServerScriptService.GameKit.Core)
-- Starts player saving/leaderstats and publishes shared state used by the HUD.
-- Other GameKit systems work without editing this file.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Net = require(kit:WaitForChild("Net"))
local Util = require(kit:WaitForChild("Util"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Core", {
	WelcomeMessage = "Welcome!",
	StartingStatus = "",
})

-- Remotes used by LocalScripts; creating them here means clients never wait for them.
Net.event("Notify")

if kit:GetAttribute("Status") == nil then
	kit:SetAttribute("Status", config.StartingStatus)
end

PlayerData.onLoaded(function(player)
	if config.WelcomeMessage and config.WelcomeMessage ~= "" then
		task.wait(2)
		if player.Parent then
			Net.notify(player, config.WelcomeMessage, "info")
		end
	end
end)
