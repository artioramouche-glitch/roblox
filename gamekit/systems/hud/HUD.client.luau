-- GameKit HUD (StarterPlayerScripts.GameKit.HUD)
-- Shows the player's stats (with +N pop-ups), the round/status bar and toast messages.
-- Restyle it from ReplicatedStorage.GameKit.Config.Hud and Config.Theme.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))

local config = Util.config("Hud", {
	ShowLeaderstats = true,
	ExtraStats = {},
	HiddenStats = {},
	ShowStatus = true,
	Icons = {
		Coins = "💰",
		Cash = "💵",
		Gems = "💎",
		Wins = "🏆",
		Stage = "🚩",
		Kills = "⚔️",
		Level = "⭐",
		Power = "⚡",
		Rebirths = "🔁",
		Keys = "🔑",
		Wave = "🌊",
		Basket = "🧺",
		XP = "✨",
		Fish = "🐟",
	},
})

local player = Players.LocalPlayer
local hud = UIKit.hud()

-- Toasts sent by the server with Net.notify(...). Connected first so none are missed.
Net.listen("Notify", function(text: string, kind: string?)
	UIKit.toast(text, kind)
end)

-- Stats panel ------------------------------------------------------------------------
local statsFrame = Instance.new("Frame")
statsFrame.Name = "Stats"
statsFrame.BackgroundTransparency = 1
statsFrame.Position = UDim2.fromOffset(12, 12)
statsFrame.Size = UDim2.fromOffset(210, 400)
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = statsFrame
statsFrame.Parent = hud

local hidden: { [string]: boolean } = {}
for _, name in ipairs(config.HiddenStats) do
	hidden[name] = true
end

local rows: { [string]: Frame } = {}
local rowCount = 0

local function addRow(statName: string)
	if rows[statName] or hidden[statName] then
		return
	end
	rowCount += 1
	local row = Instance.new("Frame")
	row.Name = statName
	row.LayoutOrder = rowCount
	row.Size = UDim2.fromOffset(200, 46)
	row.BackgroundColor3 = UIKit.color("Background")
	row.BackgroundTransparency = 0.2
	UIKit.corner(row)
	UIKit.stroke(row)
	UIKit.label(row, config.Icons[statName] or "⭐", UDim2.fromOffset(38, 38), { Position = UDim2.fromOffset(6, 4) })
	UIKit.label(row, statName, UDim2.new(1, -54, 0, 14), {
		Position = UDim2.fromOffset(48, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UIKit.color("SubText"),
	})
	local value = UIKit.label(row, "0", UDim2.new(1, -54, 0, 24), {
		Name = "Value",
		Position = UDim2.fromOffset(48, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = row
	row.Parent = statsFrame
	rows[statName] = row

	local attribute = Util.attrName(statName)
	local last = player:GetAttribute(attribute)
	local function refresh()
		local current = player:GetAttribute(attribute)
		if type(current) ~= "number" then
			return
		end
		value.Text = Util.formatNumber(current)
		if type(last) == "number" and current > last then
			UIKit.popText(row, "+" .. Util.formatNumber(current - last))
			scale.Scale = 1.08
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		last = current
	end
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
	refresh()
end

if config.ShowLeaderstats then
	local leaderstats = player:WaitForChild("leaderstats", 30)
	if leaderstats then
		for _, child in leaderstats:GetChildren() do
			addRow(child.Name)
		end
		leaderstats.ChildAdded:Connect(function(child)
			addRow(child.Name)
		end)
	end
end
for _, name in ipairs(config.ExtraStats) do
	addRow(name)
end

-- Status bar (round info, objectives...) ------------------------------------------------
if config.ShowStatus then
	local bar = Instance.new("Frame")
	bar.Name = "StatusBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 12)
	bar.Size = UDim2.new(0.4, 0, 0, 48)
	bar.BackgroundColor3 = UIKit.color("Background")
	bar.BackgroundTransparency = 0.2
	bar.Visible = false
	UIKit.corner(bar)
	UIKit.stroke(bar, UIKit.color("Accent"), 0.5)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(260, 48)
	limit.MaxSize = Vector2.new(620, 48)
	limit.Parent = bar
	local text = UIKit.label(bar, "", UDim2.new(1, -24, 1, -12), { Position = UDim2.fromOffset(12, 6) })
	bar.Parent = hud

	local function refresh()
		local status = kit:GetAttribute("Status")
		local timer = kit:GetAttribute("Timer")
		local message = if type(status) == "string" then status else ""
		if type(timer) == "number" and timer > 0 then
			message = (if message ~= "" then message .. "  •  " else "") .. "⏱ " .. Util.formatTime(timer)
		end
		text.Text = message
		bar.Visible = message ~= ""
	end
	kit:GetAttributeChangedSignal("Status"):Connect(refresh)
	kit:GetAttributeChangedSignal("Timer"):Connect(refresh)
	refresh()
end
