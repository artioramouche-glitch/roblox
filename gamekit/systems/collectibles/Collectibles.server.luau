-- GameKit Collectibles (ServerScriptService.GameKit.Collectibles)
-- Tag parts "Coin" (or "Collectible"). Attributes (all optional):
--   Stat (string, default "Coins"), Amount (number, default 1), RespawnTime (s, default 10)
-- The amount is multiplied by the player's multipliers (gamepasses, pets, rebirths...).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Collectibles", {
	DefaultStat = "Coins",
	DefaultAmount = 1,
	DefaultRespawnTime = 10,
})

PlayerData.defineStat({ Name = config.DefaultStat, Default = 0, Leaderstat = true })
local collected = Net.event("GK_Collected")

local function hook(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	part.Anchored = true
	part.CanCollide = false
	local statName = part:GetAttribute("Stat")
	local stat = if type(statName) == "string" then statName else config.DefaultStat
	if stat ~= config.DefaultStat then
		PlayerData.defineStat({ Name = stat, Default = 0 })
	end
	local available = true
	part.Touched:Connect(function(hit)
		if not available then
			return
		end
		local player = Util.playerFromHit(hit)
		if not player or not PlayerData.isLoaded(player) then
			return
		end
		available = false
		local amount = part:GetAttribute("Amount")
		PlayerData.reward(player, stat, if type(amount) == "number" then amount else config.DefaultAmount)
		collected:FireClient(player, part.Position)
		local originalTransparency = part.Transparency
		part.Transparency = 1
		part.CanTouch = false
		for _, child in part:GetDescendants() do
			if child:IsA("ParticleEmitter") or child:IsA("PointLight") or child:IsA("BillboardGui") then
				(child :: any).Enabled = false
			end
		end
		local respawn = part:GetAttribute("RespawnTime")
		task.wait(if type(respawn) == "number" then respawn else config.DefaultRespawnTime)
		if part.Parent then
			part.Transparency = originalTransparency
			part.CanTouch = true
			for _, child in part:GetDescendants() do
				if child:IsA("ParticleEmitter") or child:IsA("PointLight") or child:IsA("BillboardGui") then
					(child :: any).Enabled = true
				end
			end
			available = true
		end
	end)
end

Util.onTag("Coin", hook)
Util.onTag("Collectible", hook)
