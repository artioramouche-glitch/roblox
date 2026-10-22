-- GameKit Levels client (StarterPlayerScripts.GameKit.LevelsClient)
-- A level badge and an XP bar at the bottom of the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local UIKit = require(kit:WaitForChild("UIKit"))
local Lang = require(kit:WaitForChild("Lang"))

local config = Util.config("Levels", {
	XPStat = "XP",
	LevelStat = "Level",
})

local player = Players.LocalPlayer
local hud = UIKit.hud()

local bar = Instance.new("Frame")
bar.Name = "XPBar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -8)
bar.Size = UDim2.new(0.4, 0, 0, 22)
bar.BackgroundColor3 = UIKit.color("Background")
bar.BackgroundTransparency = 0.2
UIKit.corner(bar, 11)
UIKit.stroke(bar)
local limit = Instance.new("UISizeConstraint")
limit.MinSize = Vector2.new(220, 22)
limit.MaxSize = Vector2.new(520, 22)
limit.Parent = bar

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = UIKit.color("Accent")
UIKit.corner(fill, 11)
fill.Parent = bar

local label = UIKit.label(bar, "", UDim2.fromScale(1, 1), { ZIndex = 2 })
bar.Parent = hud

local function refresh()
	local level = player:GetAttribute(Util.attrName(config.LevelStat))
	local xp = player:GetAttribute(Util.attrName(config.XPStat))
	local start = player:GetAttribute("XPLevelStart")
	local nextLevel = player:GetAttribute("XPNextLevel")
	if type(level) ~= "number" or type(xp) ~= "number" or type(start) ~= "number" or type(nextLevel) ~= "number" then
		return
	end
	local span = math.max(1, nextLevel - start)
	local progress = math.clamp((xp - start) / span, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(progress, 1) }):Play()
	label.Text = Lang.t(`⭐ Level {level}  •  {Util.formatNumber(xp - start)} / {Util.formatNumber(span)} XP`)
end

for _, name in { Util.attrName(config.LevelStat), Util.attrName(config.XPStat), "XPLevelStart", "XPNextLevel" } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()
