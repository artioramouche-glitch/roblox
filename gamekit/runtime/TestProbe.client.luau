-- GameKit client test probe. Inserted into StarterPlayerScripts by test_game and removed
-- afterwards. Reports client-side errors and what the player sees to the test runner.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")
local UserInputService = game:GetService("UserInputService")

local remote = ReplicatedStorage:WaitForChild("__GameKitTestProbe", 20)
if not remote or not remote:IsA("RemoteEvent") then
	return
end
local probe = remote :: RemoteEvent

local sent = 0
ScriptContext.Error:Connect(function(message, stack, source)
	if sent < 30 then
		sent += 1
		probe:FireServer("error", {
			message = message,
			stack = stack,
			script = if source then source:GetFullName() else nil,
		})
	end
end)

task.wait(5)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guis = {}
for _, child in playerGui:GetChildren() do
	if child:IsA("ScreenGui") then
		table.insert(guis, { name = child.Name, enabled = child.Enabled, elements = #child:GetDescendants() })
	end
end

-- Phone checks: buttons too small to tap, UI pushed off the screen, text too small to read.
local function shown(object: GuiObject): boolean
	local node: Instance? = object
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

local tooSmall, offscreen, tinyText = {}, {}, {}
for _, gui in playerGui:GetChildren() do
	if gui:IsA("ScreenGui") and gui.Enabled then
		local canvas = gui.AbsoluteSize
		for _, object in gui:GetDescendants() do
			if object:IsA("GuiObject") and shown(object) then
				local size = object.AbsoluteSize
				local pos = object.AbsolutePosition
				local label = `{gui.Name}.{object.Name}`
				if size.X >= 1 and size.Y >= 1 then
					local visibleW = math.max(0, math.min(pos.X + size.X, canvas.X) - math.max(pos.X, 0))
					local visibleH = math.max(0, math.min(pos.Y + size.Y, canvas.Y) - math.max(pos.Y, 0))
					if visibleW * visibleH < size.X * size.Y * 0.5 and #offscreen < 8 then
						table.insert(offscreen, label)
					end
					if object:IsA("GuiButton") and math.min(size.X, size.Y) < 32 and #tooSmall < 8 then
						table.insert(tooSmall, `{label} ({math.floor(size.X)}x{math.floor(size.Y)})`)
					end
				end
				if (object:IsA("TextLabel") or object:IsA("TextButton")) and object.Text ~= "" and not object.TextScaled and object.TextSize < 11 and #tinyText < 8 then
					table.insert(tinyText, label)
				end
			end
		end
	end
end

local camera = workspace.CurrentCamera
probe:FireServer("facts", {
	screenGuis = guis,
	hudPresent = playerGui:FindFirstChild("GameKitHUD") ~= nil,
	viewport = if camera then { camera.ViewportSize.X, camera.ViewportSize.Y } else nil,
	touch = UserInputService.TouchEnabled,
	playersSeen = #Players:GetPlayers(),
	ui = { tooSmall = tooSmall, offscreen = offscreen, tinyText = tinyText },
})
