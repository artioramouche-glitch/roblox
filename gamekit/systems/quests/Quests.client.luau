-- GameKit Quests client (StarterPlayerScripts.GameKit.QuestsClient)
-- The quest tracker: active quests with a progress bar, on the right of the screen, and the
-- guide arrow: a beam from the player to where the first quest happens.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))
local Lang = require(kit:WaitForChild("Lang"))

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

-- Guide arrow ---------------------------------------------------------------------------------
local player = Players.LocalPlayer
local currentTarget: string? = nil
local goal = Instance.new("Attachment")
goal.Name = "GK_QuestGoal"
local marker = Instance.new("BillboardGui")
marker.Name = "GK_QuestMarker"
marker.Size = UDim2.fromOffset(60, 60)
marker.AlwaysOnTop = true
marker.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
marker.Adornee = goal
local pin = Instance.new("TextLabel")
pin.Size = UDim2.fromScale(1, 1)
pin.BackgroundTransparency = 1
pin.Text = "📍"
pin.TextScaled = true
pin.Parent = marker
local beam = Instance.new("Beam")
beam.Name = "GK_QuestBeam"
beam.Color = ColorSequence.new(Color3.fromRGB(255, 214, 64))
beam.Transparency = NumberSequence.new(0.2, 0.6)
beam.Width0 = 0.6
beam.Width1 = 0.6
beam.FaceCamera = true
beam.Segments = 1

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

-- "quest:<Id>" (its QuestTarget), "tag:<Tag>" or "tag:<Tag>/<Attribute>=<Value>" (nearest tagged
-- thing, e.g. "tag:ResourceNode/Node=Tree"), or a path like "Workspace/GameKit/Shop".
local function resolve(target: string, from: Vector3): Vector3?
	local questId = string.match(target, "^quest:(.+)$")
	local tagSpec = string.match(target, "^tag:(.+)$")
	if questId or tagSpec then
		local tag, key, value = "QuestTarget", "Quest", questId
		if tagSpec then
			local t, k, v = string.match(tagSpec, "^([^/]+)/([^=]+)=(.+)$")
			tag, key, value = t or tagSpec, k, v
		end
		local best, bestDistance = nil, math.huge
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsDescendantOf(workspace) and (not key or tostring(instance:GetAttribute(key)) == value) then
				local position = positionOf(instance)
				if position and (position - from).Magnitude < bestDistance then
					best, bestDistance = position, (position - from).Magnitude
				end
			end
		end
		return best
	end
	local node: Instance? = game
	for segment in string.gmatch(target, "[^/%.]+") do
		if node == game then
			node = if segment == "Workspace" or segment == "workspace" then workspace else game:FindFirstChild(segment)
		elseif node then
			node = node:FindFirstChild(segment)
		end
	end
	return if node and node ~= game then positionOf(node) else nil
end

task.spawn(function()
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local position = if currentTarget and root and root:IsA("BasePart") then resolve(currentTarget, root.Position) else nil
		if position and root and (position - (root :: BasePart).Position).Magnitude > 12 then
			goal.WorldPosition = position
			goal.Parent = workspace.Terrain
			local start = root:FindFirstChild("GK_QuestStart") or Instance.new("Attachment")
			start.Name = "GK_QuestStart"
			start.Parent = root
			beam.Attachment0 = start :: Attachment
			beam.Attachment1 = goal
			beam.Parent = workspace.Terrain
			marker.Parent = player:WaitForChild("PlayerGui")
		else
			beam.Parent = nil
			marker.Parent = nil
		end
		task.wait(0.5)
	end
end)

Net.listen("QuestsUpdate", function(rows: { any }, done: number, total: number)
	currentTarget = if rows[1] and type(rows[1].target) == "string" then rows[1].target else nil
	for _, child in panel:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	title.Text = Lang.t(`📜 Quests  {done}/{total}`)
	for index, quest in rows do
		row(index, quest.title, quest.progress, quest.goal)
	end
	panel.Visible = #rows > 0
end)

Net.send("QuestsSync")
