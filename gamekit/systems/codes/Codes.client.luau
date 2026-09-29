-- GameKit Codes client (StarterPlayerScripts.GameKit.CodesClient)
-- The 🎟 window: type a code, press Redeem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))
local Lang = require(kit:WaitForChild("Lang"))

local window, body = UIKit.window("Codes", UDim2.fromScale(0.4, 0.4))
window.Name = "CodesWindow"

local box = Instance.new("TextBox")
box.Name = "CodeBox"
box.Size = UDim2.new(1, 0, 0, 50)
box.BackgroundColor3 = UIKit.color("Panel")
box.TextColor3 = UIKit.color("Text")
box.PlaceholderText = Lang.t("Enter a code")
box.PlaceholderColor3 = UIKit.color("SubText")
box.Text = ""
box.ClearTextOnFocus = false
box.TextScaled = true
box.Font = UIKit.font()
box.ZIndex = 12
UIKit.corner(box)
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.Parent = box
box.Parent = body

local message = UIKit.label(body, "", UDim2.new(1, 0, 0, 30), {
	Position = UDim2.fromOffset(0, 116),
	TextColor3 = UIKit.color("SubText"),
	ZIndex = 12,
})

local function submit()
	if box.Text ~= "" then
		message.Text = "..."
		Net.send("RedeemCode", box.Text)
	end
end

local redeem = UIKit.button(body, "Redeem", UDim2.new(1, 0, 0, 48), submit, UIKit.color("Success"))
redeem.Position = UDim2.fromOffset(0, 60)
redeem.ZIndex = 12
box.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submit()
	end
end)

Net.listen("CodeResult", function(ok: boolean, text: string)
	message.Text = Lang.t(text)
	message.TextColor3 = if ok then UIKit.color("Success") else UIKit.color("Error")
	if ok then
		box.Text = ""
	end
end)

if kit:GetAttribute("CodesButton") ~= false then
	UIKit.hudButton("Codes", "🎟", function()
		window.Visible = not window.Visible
		message.Text = ""
	end, 7)
end
