-- GameKit Inventory client (StarterPlayerScripts.GameKit.InventoryClient)
-- The 🎒 window: every item the player has, with its count and a Sell button.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))

local config = Util.config("Inventory", {
	ShowButton = true,
})

local player = Players.LocalPlayer
local window, body = UIKit.window("Inventory", UDim2.fromScale(0.55, 0.6))
window.Name = "InventoryWindow"

local sellAll = UIKit.button(body, "Sell all", UDim2.new(0.35, 0, 0, 40), function()
	Net.send("InventorySellAll")
end, UIKit.color("Success"))
sellAll.ZIndex = 12

local scroller = Instance.new("ScrollingFrame")
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.Position = UDim2.fromOffset(0, 50)
scroller.Size = UDim2.new(1, 0, 1, -50)
scroller.ScrollBarThickness = 6
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.CanvasSize = UDim2.new()
scroller.ZIndex = 11
scroller.Parent = body

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(130, 150)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.Name
grid.Parent = scroller

local function definitions(): { [string]: { [string]: any } }
	local raw = kit:GetAttribute("ItemDefs")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, value = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(value) == "table" then value else {}
end

local function refresh()
	for _, child in scroller:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local empty = true
	for itemId, def in definitions() do
		local count = player:GetAttribute(Util.attrName("Inv_" .. itemId))
		if type(count) == "number" and count > 0 then
			empty = false
			local card = Instance.new("Frame")
			card.Name = itemId
			card.BackgroundColor3 = UIKit.color("Panel")
			card.ZIndex = 12
			UIKit.corner(card)
			UIKit.stroke(card)
			UIKit.label(card, def.Icon or "📦", UDim2.new(1, 0, 0, 44), { Position = UDim2.fromOffset(0, 6), ZIndex = 13 })
			UIKit.label(card, `{def.Name or itemId} x{count}`, UDim2.new(1, -8, 0, 24), { Position = UDim2.fromOffset(4, 54), ZIndex = 13 })
			if type(def.SellPrice) == "number" and def.SellPrice > 0 then
				local sell = UIKit.button(card, `Sell {Util.formatNumber(def.SellPrice * count)}`, UDim2.new(1, -12, 0, 36), function()
					Net.send("InventorySell", itemId)
				end)
				sell.AnchorPoint = Vector2.new(0.5, 1)
				sell.Position = UDim2.new(0.5, 0, 1, -6)
				sell.ZIndex = 13
			end
			card.Parent = scroller
		end
	end
	sellAll.Visible = not empty
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

if config.ShowButton then
	UIKit.hudButton("Inventory", "🎒", function()
		window.Visible = not window.Visible
	end, 3)
end
