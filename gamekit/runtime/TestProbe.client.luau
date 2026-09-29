-- GameKit client test probe. Inserted into StarterPlayerScripts by test_game and removed
-- afterwards. Reports client-side errors and what the player sees to the test runner.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

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
local camera = workspace.CurrentCamera
probe:FireServer("facts", {
	screenGuis = guis,
	hudPresent = playerGui:FindFirstChild("GameKitHUD") ~= nil,
	viewport = if camera then { camera.ViewportSize.X, camera.ViewportSize.Y } else nil,
})
