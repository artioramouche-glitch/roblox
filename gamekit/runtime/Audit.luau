--!nonstrict
-- GameKit audit collector. Runs inside the Studio plugin (edit mode) through
-- execute_luau and returns a JSON snapshot that the MCP server analyses:
-- every script's source + where it lives, and facts about the place.

local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")

local MAX_SOURCE = 120000
local MAX_TOTAL = 3000000

local SERVICES = {
	"Workspace",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Lighting",
	"SoundService",
	"Teams",
	"Chat",
	"TextChatService",
}

local report = {
	scripts = {},
	facts = {},
	tags = {},
	loose = {},
	checkpointStages = {},
	truncatedScripts = 0,
}

local total = 0
for _, serviceName in ipairs(SERVICES) do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if ok and service then
		for _, instance in ipairs(service:GetDescendants()) do
			if instance:IsA("LuaSourceContainer") then
				local okSource, source = pcall(function()
					return (instance :: any).Source
				end)
				source = if okSource and type(source) == "string" then source else ""
				local entry = {
					path = instance:GetFullName(),
					className = instance.ClassName,
					enabled = true,
					runContext = nil,
					length = #source,
				}
				if instance:IsA("BaseScript") then
					entry.enabled = not instance.Disabled
					pcall(function()
						entry.runContext = instance.RunContext.Name
					end)
				end
				if #source <= MAX_SOURCE and total + #source <= MAX_TOTAL then
					entry.source = source
					total += #source
				else
					report.truncatedScripts += 1
				end
				table.insert(report.scripts, entry)
			end
		end
	end
end

local parts, unanchored, spawns = 0, 0, 0
for _, instance in ipairs(workspace:GetDescendants()) do
	if instance:IsA("BasePart") then
		parts += 1
		if instance:IsA("SpawnLocation") then
			spawns += 1
		end
		if not instance.Anchored and not instance:IsA("Terrain") then
			local model = instance:FindFirstAncestorOfClass("Model")
			local isCharacter = model and model:FindFirstChildOfClass("Humanoid")
			local inTool = instance:FindFirstAncestorOfClass("Tool")
			local okRoot, root = pcall(function()
				return instance.AssemblyRootPart
			end)
			local anchoredAssembly = okRoot and root and root.Anchored
			if not isCharacter and not inTool and not anchoredAssembly then
				unanchored += 1
				if #report.loose < 15 then
					table.insert(report.loose, instance:GetFullName())
				end
			end
		end
	end
end

for _, tag in ipairs({
	"Checkpoint",
	"FinishLine",
	"KillPart",
	"DamagePart",
	"Coin",
	"Collectible",
	"MovingPlatform",
	"Spinner",
	"Disappearing",
	"FallingPlatform",
	"Conveyor",
	"JumpPad",
	"SpeedPad",
	"Teleporter",
	"RoundSpawn",
	"LobbySpawn",
	"EnemySpawner",
	"ShopStand",
	"LeaderboardBoard",
	"TycoonPlot",
	"SellPad",
	"ZoneGate",
	"Key",
	"ExitDoor",
	"ExitZone",
	"GKMelee",
}) do
	local count = #CollectionService:GetTagged(tag)
	if count > 0 then
		report.tags[tag] = count
	end
end

for _, part in ipairs(CollectionService:GetTagged("Checkpoint")) do
	local stage = part:GetAttribute("Stage")
	if type(stage) == "number" then
		table.insert(report.checkpointStages, stage)
	end
end
table.sort(report.checkpointStages)

local kit = ReplicatedStorage:FindFirstChild("GameKit")
local installed = {}
local serverKit = ServerScriptService:FindFirstChild("GameKit")
if serverKit then
	for _, child in ipairs(serverKit:GetChildren()) do
		table.insert(installed, child.Name)
	end
end
local configs = {}
local configFolder = kit and kit:FindFirstChild("Config")
if configFolder then
	for _, child in ipairs(configFolder:GetChildren()) do
		table.insert(configs, child.Name)
	end
end

report.facts = {
	placeName = game.Name,
	placeId = game.PlaceId,
	parts = parts,
	unanchoredLooseParts = unanchored,
	spawnLocations = spawns,
	gameKitInstalled = kit ~= nil,
	gameKitServerScripts = installed,
	gameKitConfigs = configs,
	characterAutoLoads = Players.CharacterAutoLoads,
	httpEnabled = HttpService.HttpEnabled,
	streamingEnabled = workspace.StreamingEnabled,
	lightingTechnology = Lighting.Technology.Name,
	clockTime = Lighting.ClockTime,
	leftoverTestRunner = ServerScriptService:FindFirstChild("__GameKitTestRunner") ~= nil,
	hasBaseplate = workspace:FindFirstChild("Baseplate") ~= nil,
	fallenPartsDestroyHeight = workspace.FallenPartsDestroyHeight,
}

return HttpService:JSONEncode(report)
