-- GameKit Racing client (StarterPlayerScripts.GameKit.RacingClient)
-- Lap, position and time while racing; best lap at all times.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local UIKit = require(kit:WaitForChild("UIKit"))
local Lang = require(kit:WaitForChild("Lang"))

local player = Players.LocalPlayer
local hud = UIKit.hud()

local panel = Instance.new("Frame")
panel.Name = "Race"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 70)
panel.Size = UDim2.fromOffset(300, 44)
panel.BackgroundColor3 = UIKit.color("Background")
panel.BackgroundTransparency = 0.2
panel.Visible = false
UIKit.corner(panel)
UIKit.stroke(panel, UIKit.color("Accent"), 0.4)
local text = UIKit.label(panel, "", UDim2.new(1, -16, 1, -8), { Position = UDim2.fromOffset(8, 4) })
panel.Parent = hud

local function refresh()
	local lap = player:GetAttribute("RaceLap")
	local laps = player:GetAttribute("RaceLaps")
	local position = player:GetAttribute("RacePosition")
	local best = player:GetAttribute("BestLap")
	if type(lap) ~= "number" then
		panel.Visible = false
		return
	end
	panel.Visible = true
	local place = if type(position) == "number" then `#{position}` else "-"
	local bestText = if type(best) == "number" and best > 0 then `  •  best {string.format("%.2f", best)}s` else ""
	text.Text = Lang.t(`Lap {lap}/{laps or "?"}  •  {place}{bestText}`)
end

for _, name in { "RaceLap", "RaceLaps", "RacePosition", Util.attrName("BestLap") } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()
