-- GameKit Quests client (StarterPlayerScripts.GameKit.QuestsClient)
-- The quest tracker: active quests with a progress bar, on the right of the screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))

local config = Util.config("Quests", {
	ShowTracker = true,
})

if not config.ShowTracker then
	return
end

local hud = UIKit.hud()
local panel = Instance.new("Frame")
panel.Name = "Quests"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -12, 0.45, 0)
panel.Size = UDim2.fromOffset(250, 60)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = UIKit.color("Background")
panel.BackgroundTransparency = 0.25
panel.Visible = false
UIKit.corner(panel)
UIKit.stroke(panel)
UIKit.padding(panel, 8)
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel
local title = UIKit.label(panel, "📜 Quests", UDim2.new(1, 0, 0, 22), { LayoutOrder = 0, TextXAlignment = Enum.TextXAlignment.Left })
panel.Parent = hud

local function row(order: number, text: string, progress: number, goal: number)
	local frame = Instance.new("Frame")
	frame.Name = "Quest" .. order
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 42)
	UIKit.label(frame, text, UDim2.new(1, 0, 0, 20), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.color("Text") })
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 24)
	back.Size = UDim2.new(1, 0, 0, 14)
	back.BackgroundColor3 = UIKit.color("Panel")
	UIKit.corner(back, 7)
	back.Parent = frame
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UIKit.color("Success")
	UIKit.corner(fill, 7)
	fill.Parent = back
	UIKit.label(back, `{Util.formatNumber(progress)} / {Util.formatNumber(goal)}`, UDim2.fromScale(1, 1), { ZIndex = 2 })
	TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(progress / math.max(goal, 1), 0, 1), 1) }):Play()
	frame.Parent = panel
end

Net.listen("QuestsUpdate", function(rows: { any }, done: number, total: number)
	for _, child in panel:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	title.Text = `📜 Quests  {done}/{total}`
	for index, quest in rows do
		row(index, quest.title, quest.progress, quest.goal)
	end
	panel.Visible = #rows > 0
end)

Net.send("QuestsSync")
