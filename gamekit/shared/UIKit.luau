-- GameKit UIKit (ReplicatedStorage.GameKit.UIKit) -- client only.
-- Builds good-looking, mobile-friendly UI in one line so every GameKit screen shares
-- one style. Colors come from Config.Theme (edit it to restyle the whole game).
--
--   local UIKit = require(ReplicatedStorage.GameKit.UIKit)
--   UIKit.hudButton("Shop", "🛒", function() window.Visible = not window.Visible end)
--   local window, body = UIKit.window("Shop", UDim2.fromScale(0.5, 0.6))
--   UIKit.toast("You bought a sword!", "success")
-- Every text goes through Lang.t (translated into the player's language when known).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Util = require(script.Parent:WaitForChild("Util"))
local Lang = require(script.Parent:WaitForChild("Lang"))

local theme = Util.config("Theme", {
	Background = "#16161F",
	Panel = "#23232F",
	Accent = "#FFC940",
	Text = "#FFFFFF",
	SubText = "#B8B8C8",
	Success = "#4CD964",
	Error = "#FF5A5A",
	Reward = "#FFC940",
	Info = "#5AB4FF",
	Font = "FredokaOne",
	Corner = 12,
})

local UIKit = {}

function UIKit.color(name: string): Color3
	return Util.color(theme[name], Color3.new(1, 1, 1))
end

function UIKit.font(): Enum.Font
	local ok, font = pcall(function()
		return (Enum.Font :: any)[theme.Font]
	end)
	return if ok and font then font else Enum.Font.GothamBold
end

local function playerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

function UIKit.corner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or theme.Corner)
	corner.Parent = parent
end

function UIKit.stroke(parent: GuiObject, color: Color3?, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.new(1, 1, 1)
	stroke.Transparency = transparency or 0.85
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

function UIKit.padding(parent: GuiObject, pixels: number)
	local padding = Instance.new("UIPadding")
	local p = UDim.new(0, pixels)
	padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight = p, p, p, p
	padding.Parent = parent
end

function UIKit.label(parent: Instance, text: string, size: UDim2, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Text = Lang.t(text)
	label.Font = UIKit.font()
	label.TextColor3 = UIKit.color("Text")
	label.TextScaled = true
	for key, value in pairs(props or {}) do
		(label :: any)[key] = value
	end
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 32
	limit.Parent = label
	label.Parent = parent
	return label
end

-- A rounded button with press animation. `color` defaults to the theme accent.
function UIKit.button(parent: Instance, text: string, size: UDim2, onClick: () -> (), color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or UIKit.color("Accent")
	button.Text = Lang.t(text)
	button.Font = UIKit.font()
	button.TextColor3 = if color then Color3.new(1, 1, 1) else Color3.fromRGB(30, 30, 30)
	button.TextScaled = true
	UIKit.corner(button)
	UIKit.padding(button, 6)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 28
	limit.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.05), { Scale = 0.93 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(onClick)
	button.Parent = parent
	return button
end

-- The main HUD ScreenGui (created on first use).
function UIKit.hud(): ScreenGui
	local gui = playerGui()
	local existing = gui:FindFirstChild("GameKitHUD")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "GameKitHUD"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = gui
	return screen
end

-- The vertical column of big buttons on the left side of the screen.
function UIKit.buttonColumn(): Frame
	local hud = UIKit.hud()
	local column = hud:FindFirstChild("Buttons")
	if column and column:IsA("Frame") then
		return column
	end
	local frame = Instance.new("Frame")
	frame.Name = "Buttons"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, 12, 0.5, 0)
	frame.Size = UDim2.new(0, 72, 0.5, 0)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	frame.Parent = hud
	return frame
end

-- Adds a square HUD button with an emoji icon and a caption.
function UIKit.hudButton(name: string, icon: string, onClick: () -> (), order: number?): TextButton
	local column = UIKit.buttonColumn()
	local existing = column:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local button = UIKit.button(column, "", UDim2.fromOffset(68, 68), onClick, UIKit.color("Panel"))
	button.Name = name
	button.LayoutOrder = order or 0
	UIKit.stroke(button)
	UIKit.label(button, icon, UDim2.fromScale(1, 0.68), { Position = UDim2.fromScale(0, 0) })
	UIKit.label(button, name, UDim2.fromScale(1, 0.32), {
		Position = UDim2.fromScale(0, 0.68),
		TextColor3 = UIKit.color("SubText"),
	})
	return button
end

-- A centered modal window. Returns (window, body) -- put your content in body.
function UIKit.window(title: string, size: UDim2?): (Frame, Frame)
	local hud = UIKit.hud()
	local window = Instance.new("Frame")
	window.Name = title .. "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = size or UDim2.fromScale(0.5, 0.6)
	window.BackgroundColor3 = UIKit.color("Background")
	window.Visible = false
	window.ZIndex = 10
	UIKit.corner(window, 18)
	UIKit.stroke(window, UIKit.color("Accent"), 0.4)
	local ratio = Instance.new("UISizeConstraint")
	ratio.MinSize = Vector2.new(280, 220)
	ratio.MaxSize = Vector2.new(720, 560)
	ratio.Parent = window

	UIKit.label(window, title, UDim2.new(1, -120, 0, 44), {
		Position = UDim2.fromOffset(18, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	})
	local close = UIKit.button(window, "X", UDim2.fromOffset(40, 40), function()
		window.Visible = false
	end, UIKit.color("Error"))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.ZIndex = 11

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 64)
	body.Size = UDim2.new(1, -32, 1, -80)
	body.ZIndex = 11
	body.Parent = window

	-- Pop-in animation whenever the window opens.
	local scale = Instance.new("UIScale")
	scale.Parent = window
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end)
	window.Parent = hud
	return window, body
end

local toastQueue = 0

-- Shows a short message at the bottom of the screen. kind: info | success | error | reward
function UIKit.toast(text: string, kind: string?)
	local hud = UIKit.hud()
	local colorName = if kind == "success" then "Success" elseif kind == "error" then "Error" elseif kind == "reward" then "Reward" else "Info"
	local toast = Instance.new("Frame")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Size = UDim2.new(0.4, 0, 0, 46)
	toast.Position = UDim2.new(0.5, 0, 1, -90 - toastQueue * 54)
	toast.BackgroundColor3 = UIKit.color("Background")
	toast.BackgroundTransparency = 0.1
	UIKit.corner(toast)
	UIKit.stroke(toast, UIKit.color(colorName), 0.2)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(240, 46)
	limit.MaxSize = Vector2.new(560, 46)
	limit.Parent = toast
	UIKit.label(toast, text, UDim2.new(1, -20, 1, -10), {
		Position = UDim2.fromOffset(10, 5),
		TextColor3 = UIKit.color(colorName),
	})
	toast.Parent = hud
	toastQueue += 1
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = toast
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(3, function()
		toastQueue -= 1
		TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		for _, child in toast:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.35)
		toast:Destroy()
	end)
end

-- Floating "+10" text that rises and fades from a GUI element.
function UIKit.popText(anchor: GuiObject, text: string, color: Color3?)
	local hud = UIKit.hud()
	local label = UIKit.label(hud, text, UDim2.fromOffset(120, 34), {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(
			anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + 8,
			anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y / 2
		),
		TextColor3 = color or UIKit.color("Reward"),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 20,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	TweenService:Create(label, TweenInfo.new(0.9), {
		Position = label.Position - UDim2.fromOffset(0, 40),
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	task.delay(1, function()
		label:Destroy()
	end)
end

return UIKit
