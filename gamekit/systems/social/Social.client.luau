-- GameKit Social client (StarterPlayerScripts.GameKit.SocialClient)
-- The 👥 invite button (Roblox's own invite window) with the current boost (friends here, group).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Net = require(kit:WaitForChild("Net"))
local UIKit = require(kit:WaitForChild("UIKit"))
local Lang = require(kit:WaitForChild("Lang"))

local player = Players.LocalPlayer

-- The boost (friends here, group) shows as a small green tag on the 👥 button.
local boostTag: TextLabel? = nil

if kit:GetAttribute("InviteButton") ~= false then
	local button = UIKit.hudButton("Invite", "👥", function()
		local ok, canInvite = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and canInvite then
			local opened = pcall(function()
				SocialService:PromptGameInvite(player)
			end)
			if opened then
				Net.send("InviteSent")
			end
		else
			UIKit.toast(Lang.t("Invites are not available here (they work in the published game)."), "info")
		end
	end, 8)
	local tag = UIKit.label(button, "", UDim2.fromOffset(52, 20), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -8),
		BackgroundTransparency = 0,
		BackgroundColor3 = UIKit.color("Success"),
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 5,
	})
	UIKit.corner(tag)
	boostTag = tag
end

local function refresh()
	local tag = boostTag
	if not tag then
		return
	end
	local boost = player:GetAttribute("SocialBoost")
	if type(boost) == "number" and boost > 1.001 then
		tag.Visible = true
		tag.Text = `+{math.floor((boost - 1) * 100 + 0.5)}%`
	else
		tag.Visible = false
	end
end
player:GetAttributeChangedSignal("SocialBoost"):Connect(refresh)
refresh()
