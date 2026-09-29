-- GameKit Crafting client (StarterPlayerScripts.GameKit.CraftingClient)
-- The 🔨 window (recipes + Craft buttons, food + Eat buttons) and the hunger bar.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local window, body = UIKit.window("Crafting", UDim2.fromScale(0.5, 0.65))
window.Name = "CraftingWindow"

local scroller = Instance.new("ScrollingFrame")
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.Size = UDim2.fromScale(1, 1)
scroller.ScrollBarThickness = 6
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.CanvasSize = UDim2.new()
scroller.ZIndex = 11
scroller.Parent = body
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroller

local function decode(attribute: string): any
	local raw = kit:GetAttribute(attribute)
	local ok, value = pcall(function()
		return HttpService:JSONDecode(if type(raw) == "string" then raw else "[]")
	end)
	return if ok then value else {}
end

local function count(itemId: string): number
	local value = player:GetAttribute(Util.attrName("Inv_" .. itemId))
	return if type(value) == "number" then value else 0
end

local function row(order: number, title: string, detail: string, action: string, enabled: boolean, onClick: () -> ())
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -10, 0, 60)
	frame.BackgroundColor3 = UIKit.color("Panel")
	frame.ZIndex = 12
	UIKit.corner(frame)
	UIKit.label(frame, title, UDim2.new(0.62, -12, 0, 28), { Position = UDim2.fromOffset(10, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
	UIKit.label(frame, detail, UDim2.new(0.62, -12, 0, 22), {
		Position = UDim2.fromOffset(10, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if enabled then UIKit.color("SubText") else UIKit.color("Error"),
		ZIndex = 13,
	})
	local button = UIKit.button(frame, action, UDim2.new(0.34, 0, 0, 44), onClick, if enabled then UIKit.color("Success") else UIKit.color("Panel"))
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -8, 0.5, 0)
	button.ZIndex = 13
	button.AutoButtonColor = enabled
	frame.Parent = scroller
end

local function refresh()
	for _, child in scroller:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local defs = {}
	local rawDefs = kit:GetAttribute("ItemDefs")
	pcall(function()
		defs = HttpService:JSONDecode(if type(rawDefs) == "string" then rawDefs else "{}")
	end)
	for _, recipe in decode("Recipes") do
		local parts = {}
		local canCraft = true
		for itemId, amount in recipe.needs or {} do
			local def = defs[itemId]
			local have = count(itemId)
			canCraft = canCraft and have >= amount
			table.insert(parts, `{amount} {(def and def.Icon) or itemId} ({have})`)
		end
		row(recipe.order or 0, `{recipe.icon} {recipe.name}`, table.concat(parts, "  "), if recipe.kind == "Build" then "Build" else "Craft", canCraft, function()
			Net.send("Craft", recipe.id)
		end)
	end
	local food = decode("Food")
	if type(food) == "table" then
		local order = 1000
		for itemId, value in food do
			if count(itemId) > 0 then
				order += 1
				local def = defs[itemId]
				row(order, `{(def and def.Icon) or "🍖"} {(def and def.Name) or itemId} x{count(itemId)}`, `+{value} food`, "Eat", true, function()
					Net.send("Eat", itemId)
				end)
			end
		end
	end
end

player.AttributeChanged:Connect(function(name)
	if window.Visible and string.sub(name, 1, 4) == "Inv_" then
		refresh()
	end
end)
window:GetPropertyChangedSignal("Visible"):Connect(function()
	if window.Visible then
		refresh()
	end
end)
UIKit.hudButton("Crafting", "🔨", function()
	window.Visible = not window.Visible
end, 5)
Net.listen("OpenCrafting", function()
	window.Visible = true
end)

-- Hunger bar (only when Config.Crafting.Hunger.Enabled).
local hud = UIKit.hud()
local bar = Instance.new("Frame")
bar.Name = "Hunger"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -38)
bar.Size = UDim2.fromOffset(220, 16)
bar.BackgroundColor3 = UIKit.color("Background")
bar.BackgroundTransparency = 0.2
bar.Visible = false
UIKit.corner(bar)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Color3.fromRGB(255, 167, 38)
UIKit.corner(fill)
fill.Parent = bar
UIKit.label(bar, "🍗", UDim2.fromOffset(20, 16), { Position = UDim2.fromOffset(-24, 0) })
bar.Parent = hud

local function refreshHunger()
	local value = player:GetAttribute("Hunger")
	local max = player:GetAttribute("HungerMax")
	if type(value) ~= "number" or type(max) ~= "number" or max <= 0 then
		bar.Visible = false
		return
	end
	bar.Visible = true
	fill.Size = UDim2.fromScale(math.clamp(value / max, 0, 1), 1)
	fill.BackgroundColor3 = if value / max < 0.25 then Color3.fromRGB(229, 57, 53) else Color3.fromRGB(255, 167, 38)
end
player:GetAttributeChangedSignal("Hunger"):Connect(refreshHunger)
player:GetAttributeChangedSignal("HungerMax"):Connect(refreshHunger)
refreshHunger()
