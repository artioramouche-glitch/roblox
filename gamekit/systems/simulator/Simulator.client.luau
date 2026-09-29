-- GameKit Simulator client (StarterPlayerScripts.GameKit.SimulatorClient)
-- Big "Train" button + backpack bar, Rebirth window, and zone gates you can walk
-- through once unlocked.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))

local config = Util.config("Simulator", {
	PowerStat = "Power",
	CoinStat = "Coins",
	TrainButtonText = "💪 Train",
})

local player = Players.LocalPlayer
local hud = UIKit.hud()

-- Train button + backpack bar ----------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Name = "Trainer"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -20)
panel.Size = UDim2.fromOffset(300, 120)
panel.BackgroundTransparency = 1
panel.Parent = hud

local barBack = Instance.new("Frame")
barBack.Size = UDim2.new(1, 0, 0, 28)
barBack.BackgroundColor3 = UIKit.color("Background")
barBack.BackgroundTransparency = 0.2
UIKit.corner(barBack)
UIKit.stroke(barBack)
barBack.Parent = panel
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = UIKit.color("Accent")
UIKit.corner(barFill)
barFill.Parent = barBack
local barText = UIKit.label(barBack, "", UDim2.fromScale(1, 1), { ZIndex = 3 })

local function refreshBar()
	local power = player:GetAttribute(Util.attrName(config.PowerStat))
	local capacity = player:GetAttribute("Capacity")
	local p = if type(power) == "number" then power else 0
	local c = if type(capacity) == "number" and capacity > 0 then capacity else 1
	barFill.Size = UDim2.fromScale(math.clamp(p / c, 0, 1), 1)
	barText.Text = `🎒 {Util.formatNumber(p)} / {Util.formatNumber(c)}`
end
player:GetAttributeChangedSignal(Util.attrName(config.PowerStat)):Connect(refreshBar)
player:GetAttributeChangedSignal("Capacity"):Connect(refreshBar)
refreshBar()

local function train()
	Net.send("SimTrain")
end

local trainButton = UIKit.button(panel, config.TrainButtonText, UDim2.new(1, 0, 0, 72), train)
trainButton.Position = UDim2.fromOffset(0, 40)

ContextActionService:BindAction("GK_Train", function(_, state)
	if state == Enum.UserInputState.Begin then
		train()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)

-- Rebirth ------------------------------------------------------------------------------------
local window, body = UIKit.window("Rebirth", UDim2.fromScale(0.35, 0.4))
window.Name = "RebirthWindow"
local info = UIKit.label(body, "", UDim2.new(1, 0, 0.55, 0), { TextWrapped = true, ZIndex = 12 })
local confirm = UIKit.button(body, "Rebirth!", UDim2.new(0.6, 0, 0, 52), function()
	Net.send("SimRebirth")
	window.Visible = false
end)
confirm.AnchorPoint = Vector2.new(0.5, 1)
confirm.Position = UDim2.fromScale(0.5, 1)
confirm.ZIndex = 12

window:GetPropertyChangedSignal("Visible"):Connect(function()
	local cost = player:GetAttribute("RebirthCost")
	info.Text = `Reset your {config.CoinStat} and {config.PowerStat} for a permanent Power bonus.\nCost: {Util.formatNumber(if type(cost) == "number" then cost else 0)} {config.CoinStat}`
end)
UIKit.hudButton("Rebirth", "🔁", function()
	window.Visible = not window.Visible
end, 3)

-- Zone gates -----------------------------------------------------------------------------------
Util.onTag("ZoneGate", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local gate = instance :: BasePart
	local zone = tostring(gate:GetAttribute("Zone") or gate.Name)
	local attribute = "Owned_" .. Util.attrName("Zone_" .. zone)
	local function refresh()
		if player:GetAttribute(attribute) == true then
			gate.CanCollide = false
			gate.Transparency = 0.85
			local prompt = gate:FindFirstChild("GK_Zone")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = false
			end
		end
	end
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
	refresh()
end)
