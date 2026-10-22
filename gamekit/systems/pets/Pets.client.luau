-- GameKit Pets client (StarterPlayerScripts.GameKit.PetsClient)
-- The 🐾 window (equip / unequip / equip best) and the egg-hatching reveal.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))

local config = Util.config("Pets", {
	Stat = "Coins",
	RarityColors = { Common = "#B0BEC5", Rare = "#42A5F5", Epic = "#AB47BC", Legendary = "#FFCA28" },
})

local player = Players.LocalPlayer
local window, body = UIKit.window("Pets", UDim2.fromScale(0.55, 0.6))
window.Name = "PetsWindow"

local best = UIKit.button(body, "Equip best", UDim2.new(0.35, 0, 0, 40), function()
	Net.send("PetEquipBest")
end)
best.ZIndex = 12

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
grid.CellSize = UDim2.fromOffset(120, 140)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroller

local function defs(): { [string]: { [string]: any } }
	local raw = kit:GetAttribute("PetDefs")
	local ok, value = pcall(function()
		return HttpService:JSONDecode(if type(raw) == "string" then raw else "{}")
	end)
	return if ok and type(value) == "table" then value else {}
end

local function split(attribute: string): { string }
	local raw = player:GetAttribute(attribute)
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	return string.split(raw, ",")
end

local function refresh()
	for _, child in scroller:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local all = defs()
	local equipped = {}
	for _, index in split("PetsEquipped") do
		equipped[tonumber(index) or 0] = true
	end
	for index, petId in split("Pets") do
		local def = all[petId] or {}
		local card = Instance.new("Frame")
		card.LayoutOrder = if equipped[index] then index else 1000 + index
		card.BackgroundColor3 = UIKit.color("Panel")
		card.ZIndex = 12
		UIKit.corner(card)
		UIKit.stroke(card, Util.color(config.RarityColors[def.Rarity or "Common"], Color3.new(1, 1, 1)), 0)
		UIKit.label(card, def.Name or petId, UDim2.new(1, -8, 0, 26), { Position = UDim2.fromOffset(4, 8), ZIndex = 13 })
		UIKit.label(card, `x{def.Multiplier or 1} {config.Stat}`, UDim2.new(1, -8, 0, 22), {
			Position = UDim2.fromOffset(4, 40),
			TextColor3 = UIKit.color("SubText"),
			ZIndex = 13,
		})
		local button = UIKit.button(card, if equipped[index] then "Unequip" else "Equip", UDim2.new(1, -12, 0, 36), function()
			Net.send("PetEquip", index)
		end, if equipped[index] then UIKit.color("Success") else nil)
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -6)
		button.ZIndex = 13
		card.Parent = scroller
	end
end

player:GetAttributeChangedSignal("Pets"):Connect(function()
	if window.Visible then
		refresh()
	end
end)
player:GetAttributeChangedSignal("PetsEquipped"):Connect(function()
	if window.Visible then
		refresh()
	end
end)
window:GetPropertyChangedSignal("Visible"):Connect(function()
	if window.Visible then
		refresh()
	end
end)
UIKit.hudButton("Pets", "🐾", function()
	window.Visible = not window.Visible
end, 4)

-- Hatch reveal: the egg shakes, then the pet name pops in its rarity color.
Net.listen("PetHatched", function(_petId: string, name: string, rarity: string)
	local hud = UIKit.hud()
	local reveal = Instance.new("Frame")
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Position = UDim2.fromScale(0.5, 0.45)
	reveal.Size = UDim2.fromOffset(260, 200)
	reveal.BackgroundTransparency = 1
	reveal.ZIndex = 20
	local egg = UIKit.label(reveal, "🥚", UDim2.fromOffset(120, 120), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), ZIndex = 21 })
	reveal.Parent = hud
	for i = 1, 6 do
		egg.Rotation = if i % 2 == 0 then 15 else -15
		task.wait(0.12)
	end
	egg.Rotation = 0
	egg.Text = "✨"
	local label = UIKit.label(reveal, `{name}!`, UDim2.new(1, 0, 0, 40), {
		Position = UDim2.fromScale(0, 0.75),
		TextColor3 = Util.color(config.RarityColors[rarity] or "#FFFFFF", Color3.new(1, 1, 1)),
		ZIndex = 21,
	})
	UIKit.label(reveal, rarity, UDim2.new(1, 0, 0, 24), { Position = UDim2.fromScale(0, 0.95), ZIndex = 21 })
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.wait(2.2)
	reveal:Destroy()
end)
