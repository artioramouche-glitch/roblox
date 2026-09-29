--[[
	A fake Roblox Studio plugin for integration tests. It speaks the real plugin protocol
	(GET /poll, POST /response) and runs execute_luau requests inside a Lune DataModel
	built from Roblox's class database, so the whole chain MCP -> bridge -> plugin ->
	Luau -> result can be exercised without Studio.
	Usage: lune run scripts/lune/fake-studio.luau <port>
]]
local net = require("@lune/net")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local port = process.args[1] or "3002"
local base = "http://localhost:" .. port

local dm = roblox.Instance.new("DataModel")
local workspaceService = dm:GetService("Workspace")
pcall(function()
	roblox.Instance.new("Terrain").Parent = workspaceService
end)
local baseplate = roblox.Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Anchored = true
baseplate.Parent = workspaceService
for _, name in { "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "Lighting", "Players", "SoundService", "ReplicatedFirst" } do
	dm:GetService(name)
end
local starterPlayer = dm:GetService("StarterPlayer")
if not starterPlayer:FindFirstChild("StarterPlayerScripts") then
	roblox.Instance.new("StarterPlayerScripts").Parent = starterPlayer
end

local fakes = {
	HttpService = {
		HttpEnabled = true,
		JSONDecode = function(_, text)
			return serde.decode("json", text)
		end,
		JSONEncode = function(_, value)
			return serde.encode("json", value)
		end,
	},
	ChangeHistoryService = {
		TryBeginRecording = function()
			return "recording"
		end,
		FinishRecording = function() end,
		SetWaypoint = function() end,
	},
	CollectionService = {
		AddTag = function(_, instance, tag)
			instance:AddTag(tag)
		end,
		GetTagged = function(_, tag)
			local list = {}
			for _, d in dm:GetDescendants() do
				if d:HasTag(tag) then
					table.insert(list, d)
				end
			end
			return list
		end,
	},
}
local game = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				return fakes[name] or dm:GetService(name)
			end
		elseif key == "FindFirstChild" then
			return function(_, name)
				return dm:FindFirstChild(name)
			end
		elseif key == "PlaceId" then
			return 0
		elseif key == "Name" then
			return "FakeStudio"
		end
		return (dm :: any)[key]
	end,
})
local env = {
	game = game,
	workspace = workspaceService,
	Instance = roblox.Instance,
	Enum = roblox.Enum,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	CFrame = roblox.CFrame,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	BrickColor = roblox.BrickColor,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	Region3 = roblox.Region3,
	task = task,
}

local handled = 0

local function handle(endpoint: string, data: any): any
	if endpoint == "/api/execute-luau" then
		local ok, result = pcall(function()
			return luau.load(data.code, { debugName = "execute_luau", environment = env })()
		end)
		if ok then
			return { success = true, returnValue = if result ~= nil then tostring(result) else nil, output = {} }
		end
		return { success = false, error = tostring(result), output = {} }
	elseif endpoint == "/api/get-playtest-output" then
		return { isRunning = false, output = {} }
	end
	return { error = "fake studio does not implement " .. endpoint }
end

print("[fake-studio] polling " .. base)
while true do
	local ok, response = pcall(net.request, { url = base .. "/poll?v=fake&sid=fake-studio", method = "GET" })
	if ok and response.ok then
		local body = serde.decode("json", response.body)
		if body.request and body.requestId then
			local reply = handle(body.request.endpoint, body.request.data)
			handled += 1
			net.request({
				url = base .. "/response",
				method = "POST",
				headers = { ["Content-Type"] = "application/json" },
				body = serde.encode("json", { requestId = body.requestId, response = reply }),
			})
		end
	end
	task.wait(0.05)
end
