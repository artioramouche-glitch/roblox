-- GameKit Fishing client (StarterPlayerScripts.GameKit.FishingClient)
-- Big REEL button when a fish bites (tap / click / E), catch reveal, cancel button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))

local RARITY = { Common = "#B0BEC5", Rare = "#42A5F5", Epic = "#AB47BC", Legendary = "#FFCA28" }

local hud = UIKit.hud()

local reelButton = UIKit.button(hud, "🎣 REEL!", UDim2.fromOffset(220, 80), function()
	Net.send("FishReel")
end, UIKit.color("Success"))
reelButton.Name = "FishReel"
reelButton.AnchorPoint = Vector2.new(0.5, 1)
reelButton.Position = UDim2.new(0.5, 0, 1, -150)
reelButton.Visible = false
local pulse = Instance.new("UIScale")
pulse.Parent = reelButton

local waiting = UIKit.button(hud, "Waiting for a bite...  ✕", UDim2.fromOffset(260, 44), function()
	Net.send("FishCancel")
end)
waiting.Name = "FishWaiting"
waiting.AnchorPoint = Vector2.new(0.5, 1)
waiting.Position = UDim2.new(0.5, 0, 1, -160)
waiting.Visible = false

local pulseTween: Tween? = nil

Net.listen("FishState", function(state: string)
	waiting.Visible = state == "waiting"
	if state ~= "bite" then
		reelButton.Visible = false
		if pulseTween then
			pulseTween:Cancel()
			pulseTween = nil
		end
	end
end)

Net.listen("FishBite", function(window: number)
	waiting.Visible = false
	reelButton.Visible = true
	pulse.Scale = 1
	pulseTween = TweenService:Create(pulse, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.15 })
	if pulseTween then
		pulseTween:Play()
	end
	task.delay(window + 0.5, function()
		reelButton.Visible = false
	end)
end)

Net.listen("FishCaught", function(_id: string, name: string, icon: string, rarity: string)
	reelButton.Visible = false
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(240, 150)
	card.BackgroundColor3 = UIKit.color("Background")
	card.BackgroundTransparency = 0.1
	card.ZIndex = 20
	UIKit.corner(card)
	UIKit.stroke(card, Util.color(RARITY[rarity] or "#FFFFFF", Color3.new(1, 1, 1)), 0)
	UIKit.label(card, icon, UDim2.new(1, 0, 0, 60), { Position = UDim2.fromOffset(0, 8), ZIndex = 21 })
	UIKit.label(card, `{name}!`, UDim2.new(1, -16, 0, 36), { Position = UDim2.fromOffset(8, 70), ZIndex = 21 })
	UIKit.label(card, rarity, UDim2.new(1, -16, 0, 26), {
		Position = UDim2.fromOffset(8, 108),
		TextColor3 = Util.color(RARITY[rarity] or "#FFFFFF", Color3.new(1, 1, 1)),
		ZIndex = 21,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = card
	card.Parent = hud
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.wait(1.8)
	card:Destroy()
end)
