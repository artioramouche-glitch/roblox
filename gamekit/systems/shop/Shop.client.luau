-- GameKit Shop client (StarterPlayerScripts.GameKit.ShopClient)
-- Draws the shop window from Config.Shop.Items. Opens with the HUD "Shop" button or
-- the "Open Shop" prompt on parts tagged "ShopStand". Buying is decided by the server.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))

local config = Util.config("Shop", {
	Currency = "Coins",
	Items = {},
	ShowButton = true,
	Title = "Shop",
})

local player = Players.LocalPlayer
local window, body = UIKit.window(config.Title, UDim2.fromScale(0.6, 0.65))
window.Name = "ShopWindow"

local scroller = Instance.new("ScrollingFrame")
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.Size = UDim2.fromScale(1, 1)
scroller.ScrollBarThickness = 6
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.CanvasSize = UDim2.new()
scroller.ZIndex = 11
scroller.Parent = body

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(160, 200)
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroller

local refreshers: { () -> () } = {}

local function isEquipped(item: { [string]: any }): boolean
	if item.Kind == "Trail" then
		return player:GetAttribute("EquippedTrail") == item.Id
	elseif item.Kind == "Pet" then
		local pets = player:GetAttribute("EquippedPets")
		return type(pets) == "string" and table.find(string.split(pets, ","), item.Id) ~= nil
	end
	return false
end

for index, item in ipairs(config.Items) do
	if type(item) ~= "table" or type(item.Id) ~= "string" then
		continue
	end
	local currency = item.Currency or config.Currency
	local card = Instance.new("Frame")
	card.Name = item.Id
	card.LayoutOrder = index
	card.BackgroundColor3 = UIKit.color("Panel")
	card.ZIndex = 12
	UIKit.corner(card)
	UIKit.stroke(card)
	UIKit.label(card, item.Icon or "🎁", UDim2.new(1, 0, 0, 56), { Position = UDim2.fromOffset(0, 8), ZIndex = 13 })
	UIKit.label(card, item.Name or item.Id, UDim2.new(1, -12, 0, 26), { Position = UDim2.fromOffset(6, 66), ZIndex = 13 })
	UIKit.label(card, item.Description or "", UDim2.new(1, -12, 0, 36), {
		Position = UDim2.fromOffset(6, 94),
		TextColor3 = UIKit.color("SubText"),
		TextWrapped = true,
		ZIndex = 13,
	})
	local button = UIKit.button(card, "", UDim2.new(1, -16, 0, 44), function()
		local owned = player:GetAttribute("Owned_" .. Util.attrName(item.Id)) == true
		local repeatable = item.Kind == "Upgrade" or item.Kind == "Stat"
		if owned and not repeatable then
			if item.Kind == "Trail" or item.Kind == "Pet" then
				Net.send("ShopEquip", item.Id)
			end
		else
			Net.send("ShopBuy", item.Id)
		end
	end)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -8)
	button.ZIndex = 13
	card.Parent = scroller

	local function refresh()
		local owned = player:GetAttribute("Owned_" .. Util.attrName(item.Id)) == true
		local repeatable = item.Kind == "Upgrade" or item.Kind == "Stat"
		local price = player:GetAttribute("Price_" .. Util.attrName(item.Id))
		local shownPrice = if type(price) == "number" then price else item.Price
		if owned and not repeatable then
			if item.Kind == "Trail" or item.Kind == "Pet" then
				button.Text = if isEquipped(item) then "Unequip" else "Equip"
			else
				button.Text = "Owned ✔"
			end
			button.BackgroundColor3 = UIKit.color("Success")
		else
			local level = player:GetAttribute("Level_" .. Util.attrName(item.Id))
			local prefix = if item.Kind == "Upgrade" and type(level) == "number" then `Lv {level} • ` else ""
			button.Text = prefix .. "Buy " .. Util.formatNumber(shownPrice)
			local balance = player:GetAttribute(Util.attrName(currency))
			button.BackgroundColor3 = if type(balance) == "number" and balance >= shownPrice
				then UIKit.color("Accent")
				else Color3.fromRGB(110, 110, 120)
		end
	end
	table.insert(refreshers, refresh)
	refresh()
end

local function refreshAll()
	for _, refresh in ipairs(refreshers) do
		refresh()
	end
end

player.AttributeChanged:Connect(function()
	if window.Visible then
		refreshAll()
	end
end)
window:GetPropertyChangedSignal("Visible"):Connect(refreshAll)

local function toggle()
	window.Visible = not window.Visible
end

if config.ShowButton and #refreshers > 0 then
	UIKit.hudButton("Shop", "🛒", toggle, 1)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "GK_Shop" then
		window.Visible = true
	end
end)
