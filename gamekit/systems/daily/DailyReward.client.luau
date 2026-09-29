-- GameKit Daily reward client (StarterPlayerScripts.GameKit.DailyRewardClient)
-- A HUD gift button that pulses when a reward is ready, and a claim window.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))

local config = Util.config("DailyReward", { Stat = "Coins", OpenOnJoin = true })
local player = Players.LocalPlayer

local window, body = UIKit.window("Daily Reward", UDim2.fromScale(0.35, 0.4))
window.Name = "DailyWindow"
local info = UIKit.label(body, "", UDim2.new(1, 0, 0.55, 0), { TextWrapped = true, ZIndex = 12 })
local claim = UIKit.button(body, "Claim!", UDim2.new(0.6, 0, 0, 52), function()
	Net.send("DailyClaim")
end)
claim.AnchorPoint = Vector2.new(0.5, 1)
claim.Position = UDim2.fromScale(0.5, 1)
claim.ZIndex = 12

local hudButton = UIKit.hudButton("Daily", "🎁", function()
	window.Visible = not window.Visible
end, 2)

local function ready(): boolean
	local nextClaim = player:GetAttribute("DailyNextClaim")
	return type(nextClaim) == "number" and workspace:GetServerTimeNow() >= nextClaim
end

local function refresh()
	local amount = player:GetAttribute("DailyAmount")
	local streak = player:GetAttribute("DailyStreak")
	if ready() then
		info.Text = `Your reward: {Util.formatNumber(if type(amount) == "number" then amount else 0)} {config.Stat}\nStreak: {streak or 0} day(s)`
		claim.Visible = true
	else
		local nextClaim = player:GetAttribute("DailyNextClaim")
		local remaining = if type(nextClaim) == "number" then nextClaim - workspace:GetServerTimeNow() else 0
		info.Text = `Next reward in {math.floor(remaining / 3600)}h {math.floor(remaining % 3600 / 60)}m\nStreak: {streak or 0} day(s)`
		claim.Visible = false
	end
end

player:GetAttributeChangedSignal("DailyNextClaim"):Connect(refresh)
window:GetPropertyChangedSignal("Visible"):Connect(refresh)

local scale = hudButton:FindFirstChildOfClass("UIScale") :: UIScale
local pulse = TweenService:Create(
	scale,
	TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Scale = 1.12 }
)
task.spawn(function()
	local opened = false
	while true do
		if ready() then
			pulse:Play()
			if config.OpenOnJoin and not opened then
				opened = true
				window.Visible = true
			end
		else
			pulse:Cancel()
			scale.Scale = 1
		end
		refresh()
		task.wait(5)
	end
end)
