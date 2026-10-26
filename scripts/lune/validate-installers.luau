--[[
	Runs every installer produced by scripts/dump-gamekit-cases.mjs inside a fake Studio
	built with Lune's Roblox library (real class & property database), so wrong property
	names, wrong value types and unknown classes are caught without opening Studio.
	Usage: lune run scripts/lune/validate-installers.luau <casesDir>
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local dir = process.args[1] or error("usage: validate-installers.luau <casesDir>")
local cases = serde.decode("json", fs.readFile(dir .. "/cases.json"))

local failures = 0
local totalInstances = 0

local function makeEnvironment()
	local dm = roblox.Instance.new("DataModel")
	local workspaceService = dm:GetService("Workspace")
	pcall(function()
		local terrain = roblox.Instance.new("Terrain")
		terrain.Parent = workspaceService
	end)
	local baseplate = roblox.Instance.new("Part")
	baseplate.Name = "Baseplate"
	baseplate.Parent = workspaceService
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
	}
	return env, dm
end

for _, name in cases do
	local code = fs.readFile(dir .. "/" .. name .. ".luau")
	local env, dm = makeEnvironment()
	local ok, result = pcall(function()
		local chunk = luau.load(code, { debugName = name, environment = env })
		return chunk()
	end)
	if not ok then
		failures += 1
		print(`FAIL  {name}: {result}`)
	else
		local report = serde.decode("json", result)
		local count = #dm:GetDescendants()
		totalInstances += count
		local bad = report.ok == false or (report.warnings and #report.warnings > 0) or (report.applied == nil and report.created == nil)
		if bad then
			failures += 1
			print(`FAIL  {name}: ok={tostring(report.ok)} error={tostring(report.error)}`)
			for _, w in report.warnings or {} do
				print(`        - {w}`)
			end
		else
			print(`ok    {name} ({count} instances)`)
		end
	end
end

print(`\n{#cases} cases, {failures} failed, {totalInstances} instances created`)
if failures > 0 then
	process.exit(1)
end
