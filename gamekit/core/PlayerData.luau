-- GameKit PlayerData (ServerScriptService.GameKit.PlayerData)
-- Saves and loads every player's progress, and shows stats on the leaderboard.
--
--   local PlayerData = require(game:GetService("ServerScriptService").GameKit.PlayerData)
--   PlayerData.defineStat({ Name = "Coins", Default = 0, Leaderstat = true })
--   PlayerData.add(player, "Coins", 10)          -- exact amount
--   PlayerData.reward(player, "Coins", 10)       -- amount x multipliers (gamepasses, pets, rebirths)
--   PlayerData.spend(player, "Coins", 50)        -- true if the player could afford it
--   PlayerData.get(player, "Coins")
--   PlayerData.owns(player, "Sword") / PlayerData.grant(player, "Sword")
--   PlayerData.section(player, "Tycoon")         -- a saved table for your own data
--
-- Every stat is also mirrored as an attribute on the Player (player:GetAttribute("Coins")),
-- so LocalScripts can read any stat, even the ones hidden from the leaderboard.
-- (Characters other than letters/digits/_ become "_" in attribute names: Util.attrName.)
-- Safety: session locking, retries, autosave, save on shutdown, and a Studio fallback
-- (memory only) when "Enable Studio Access to API Services" is off.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Util = require(ReplicatedStorage:WaitForChild("GameKit"):WaitForChild("Util"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))

local config = Util.config("PlayerData", {
	DataStoreName = "GameKit_PlayerData_v1",
	AutoSaveSeconds = 90,
	Stats = {},
	KickOnLoadFailure = true,
	AnalyticsCurrencies = { "Coins", "Cash", "Gems" },
})

local analyticsCurrencies: { [string]: boolean } = {}
for _, name in config.AnalyticsCurrencies do
	analyticsCurrencies[name] = true
end

local LOCK_EXPIRY_SECONDS = 600
local LOAD_ATTEMPTS = 6

export type StatDefinition = {
	Name: string,
	Default: number?,
	Leaderstat: boolean?,
	Save: boolean?,
}

type Profile = {
	Data: { [string]: any },
	Loaded: boolean,
	CanSave: boolean,
	Leaderstats: Folder?,
}

local PlayerData = {}

local definitions: { [string]: StatDefinition } = {}
local definitionOrder: { string } = {}
local profiles: { [Player]: Profile } = {}
local changedCallbacks: { [string]: { (Player, number, number) -> () } } = {}
local loadedCallbacks: { (Player) -> () } = {}
local multiplierSources: { (Player, string) -> number } = {}
local memoryMode = false
local store: DataStore? = nil

local function isStudioAccessError(message: string): boolean
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "Studio access", 1, true) ~= nil
		or string.find(message, "publish", 1, true) ~= nil
		or string.find(message, "API Services", 1, true) ~= nil
end

local function enterMemoryMode(reason: string)
	if memoryMode then
		return
	end
	memoryMode = true
	warn(
		"[GameKit] Saving is OFF in this session ("
			.. reason
			.. "). To test saving in Studio: publish the game, then Game Settings > Security > Enable Studio Access to API Services."
	)
end

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(config.DataStoreName)
	end)
	if ok then
		store = result
	else
		enterMemoryMode(tostring(result))
	end
end

local function newData(): { [string]: any }
	return {
		Stats = {},
		Owned = {},
		Sections = {},
		Meta = { FirstJoin = os.time(), Version = 1 },
	}
end

local function sessionKey(player: Player): string
	return "Player_" .. player.UserId
end

local function sessionId(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

local function applyDefinition(player: Player, profile: Profile, name: string)
	local def = definitions[name]
	if profile.Data.Stats[name] == nil then
		profile.Data.Stats[name] = def.Default or 0
	end
	local value = profile.Data.Stats[name]
	player:SetAttribute(Util.attrName(name), value)
	if def.Leaderstat and profile.Leaderstats and not profile.Leaderstats:FindFirstChild(name) then
		local holder = Instance.new("IntValue")
		holder.Name = name
		holder.Value = math.floor(value)
		holder.Parent = profile.Leaderstats
	end
end

-- Declares a stat. Safe to call many times and from any system, even after players joined.
function PlayerData.defineStat(def: StatDefinition)
	local existing = definitions[def.Name]
	if existing then
		-- Values from the Config module win over values from systems.
		if existing.Leaderstat == nil then
			existing.Leaderstat = def.Leaderstat
		end
		if existing.Default == nil then
			existing.Default = def.Default
		end
	else
		definitions[def.Name] = {
			Name = def.Name,
			Default = def.Default or 0,
			Leaderstat = def.Leaderstat == true,
			Save = def.Save ~= false,
		}
		table.insert(definitionOrder, def.Name)
	end
	for player, profile in profiles do
		if profile.Loaded then
			applyDefinition(player, profile, def.Name)
		end
	end
end

for _, def in ipairs(config.Stats or {}) do
	if type(def) == "table" and def.Name then
		PlayerData.defineStat(def)
	end
end

local function loadData(player: Player): ({ [string]: any }?, string?)
	if memoryMode or not store then
		return newData(), nil
	end
	local key = sessionKey(player)
	local lastError: string? = nil
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedByOther = false
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key, function(old)
				local data = if type(old) == "table" then old else newData()
				local lock = data.Lock
				if
					lock
					and lock.Session ~= sessionId()
					and os.time() - (lock.Time or 0) < LOCK_EXPIRY_SECONDS
					and attempt < LOAD_ATTEMPTS
				then
					lockedByOther = true
					return nil
				end
				data.Lock = { Session = sessionId(), Time = os.time() }
				return data
			end)
		end)
		if ok and not lockedByOther and type(result) == "table" then
			return result, nil
		elseif not ok then
			local message = tostring(result)
			lastError = message
			if isStudioAccessError(message) then
				enterMemoryMode(message)
				return newData(), nil
			end
		end
		if not player.Parent then
			return nil, "left"
		end
		task.wait(if lockedByOther then 5 else attempt * 2)
	end
	return nil, lastError or "session locked"
end

local function serialize(profile: Profile): { [string]: any }
	local copy = table.clone(profile.Data)
	copy.Stats = {}
	for name, value in pairs(profile.Data.Stats) do
		local def = definitions[name]
		if not def or def.Save ~= false then
			copy.Stats[name] = value
		end
	end
	return copy
end

-- Saves one player now. `release` also frees the session lock (used when leaving).
function PlayerData.save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.Loaded or not profile.CanSave then
		return false
	end
	if memoryMode or not store then
		return true
	end
	if game:GetService("ServerScriptService"):FindFirstChild("__GameKitTestRunner") then
		return true -- automated test sessions (test_game) never overwrite real progress
	end
	local snapshot = serialize(profile)
	local stolen = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(sessionKey(player), function(old)
			if type(old) == "table" and old.Lock and old.Lock.Session ~= sessionId() then
				stolen = true
				return nil
			end
			snapshot.Lock = if release then nil else { Session = sessionId(), Time = os.time() }
			return snapshot
		end)
	end)
	if stolen then
		profile.CanSave = false
		warn(`[GameKit] {player.Name}'s data is now owned by another server; this server stopped saving it.`)
		return false
	end
	if not ok then
		warn(`[GameKit] Could not save {player.Name}: {err}`)
		if isStudioAccessError(tostring(err)) then
			enterMemoryMode(tostring(err))
			return true
		end
	end
	return ok
end

local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local profile: Profile = { Data = newData(), Loaded = false, CanSave = false, Leaderstats = leaderstats }
	profiles[player] = profile

	local data, err = loadData(player)
	if not player.Parent then
		profiles[player] = nil
		return
	end
	if not data then
		warn(`[GameKit] Failed to load data for {player.Name}: {err}`)
		if config.KickOnLoadFailure and not RunService:IsStudio() then
			player:Kick("We could not load your progress. Please rejoin in a moment.")
			profiles[player] = nil
			return
		end
		data = newData()
		profile.CanSave = false
	else
		profile.CanSave = true
	end

	data.Stats = data.Stats or {}
	data.Owned = data.Owned or {}
	data.Sections = data.Sections or {}
	data.Meta = data.Meta or { FirstJoin = os.time(), Version = 1 }
	data.Meta.LastJoin = os.time()
	data.Meta.Visits = (data.Meta.Visits or 0) + 1
	profile.Data = data
	profile.Loaded = true

	for _, name in ipairs(definitionOrder) do
		applyDefinition(player, profile, name)
	end
	leaderstats.Parent = player
	player:SetAttribute("GK_DataLoaded", true)

	for _, callback in ipairs(loadedCallbacks) do
		task.spawn(callback, player)
	end
end

local function onPlayerRemoving(player: Player)
	Analytics.flush(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if profile.Loaded then
		PlayerData.save(player, true)
	end
	profiles[player] = nil
end

function PlayerData.isLoaded(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Loaded
end

-- Yields until the player's data is loaded (or `timeout` seconds pass).
function PlayerData.waitForLoad(player: Player, timeout: number?): boolean
	local deadline = os.clock() + (timeout or 30)
	while not PlayerData.isLoaded(player) do
		if os.clock() > deadline or not player.Parent then
			return false
		end
		task.wait(0.1)
	end
	return true
end

-- fn(player) runs once per player right after their data is loaded.
function PlayerData.onLoaded(fn: (Player) -> ())
	table.insert(loadedCallbacks, fn)
	for player, profile in profiles do
		if profile.Loaded then
			task.spawn(fn, player)
		end
	end
end

function PlayerData.get(player: Player, stat: string): number
	local profile = profiles[player]
	if not profile then
		return 0
	end
	local value = profile.Data.Stats[stat]
	if value == nil then
		local def = definitions[stat]
		return if def then def.Default or 0 else 0
	end
	return value
end

function PlayerData.set(player: Player, stat: string, value: number)
	local profile = profiles[player]
	if not profile or not profile.Loaded then
		return
	end
	if not definitions[stat] then
		PlayerData.defineStat({ Name = stat, Default = 0 })
	end
	local old = profile.Data.Stats[stat] or 0
	profile.Data.Stats[stat] = value
	player:SetAttribute(Util.attrName(stat), value)
	local holder = profile.Leaderstats and profile.Leaderstats:FindFirstChild(stat)
	if holder and holder:IsA("IntValue") then
		holder.Value = math.floor(value)
	end
	if old ~= value then
		for _, callback in ipairs(changedCallbacks[stat] or {}) do
			task.spawn(callback, player, value, old)
		end
	end
end

-- Adds an exact amount (can be negative). Returns the new value.
function PlayerData.add(player: Player, stat: string, amount: number): number
	local value = PlayerData.get(player, stat) + amount
	PlayerData.set(player, stat, value)
	return value
end

-- Registers fn(player, stat) -> multiplier. Every PlayerData.reward is multiplied by all sources.
function PlayerData.addMultiplier(fn: (Player, string) -> number)
	table.insert(multiplierSources, fn)
end

function PlayerData.getMultiplier(player: Player, stat: string): number
	local total = 1
	for _, source in ipairs(multiplierSources) do
		local ok, value = pcall(source, player, stat)
		if ok and type(value) == "number" and value > 0 then
			total *= value
		end
	end
	return total
end

-- Adds `amount` x the player's multipliers for this stat. Returns the amount given.
-- kind (optional) is the Analytics transaction type: "Gameplay" (default), "TimedReward",
-- "Onboarding", "IAP"...
function PlayerData.reward(player: Player, stat: string, amount: number, kind: string?): number
	local given = amount * PlayerData.getMultiplier(player, stat)
	if amount == math.floor(amount) then
		-- Whole-number rewards stay whole numbers.
		given = math.floor(given + 0.5)
	end
	local balance = PlayerData.add(player, stat, given)
	if analyticsCurrencies[stat] then
		Analytics.source(player, stat, given, balance, kind)
	end
	return given
end

function PlayerData.canAfford(player: Player, stat: string, price: number): boolean
	return PlayerData.get(player, stat) >= price
end

-- Removes `price` if the player has enough. Returns true when paid.
-- itemSku / kind (optional) are reported to Analytics ("Sword", "Shop").
function PlayerData.spend(player: Player, stat: string, price: number, itemSku: string?, kind: string?): boolean
	if price < 0 or not PlayerData.canAfford(player, stat, price) then
		return false
	end
	local balance = PlayerData.add(player, stat, -price)
	if analyticsCurrencies[stat] then
		Analytics.sink(player, stat, price, balance, kind or "Shop", itemSku)
	end
	return true
end

-- fn(player, newValue, oldValue) runs whenever `stat` changes.
function PlayerData.onChanged(stat: string, fn: (Player, number, number) -> ())
	changedCallbacks[stat] = changedCallbacks[stat] or {}
	table.insert(changedCallbacks[stat], fn)
end

function PlayerData.owns(player: Player, itemId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Data.Owned[itemId] == true
end

function PlayerData.grant(player: Player, itemId: string)
	local profile = profiles[player]
	if profile and profile.Loaded then
		profile.Data.Owned[itemId] = true
		player:SetAttribute("Owned_" .. Util.attrName(itemId), true)
	end
end

function PlayerData.revoke(player: Player, itemId: string)
	local profile = profiles[player]
	if profile then
		profile.Data.Owned[itemId] = nil
		player:SetAttribute("Owned_" .. Util.attrName(itemId), nil)
	end
end

function PlayerData.getOwned(player: Player): { string }
	local list = {}
	local profile = profiles[player]
	if profile then
		for itemId in pairs(profile.Data.Owned) do
			table.insert(list, itemId)
		end
	end
	return list
end

-- A saved table that belongs to your system, e.g. PlayerData.section(player, "Tycoon").
-- Store only plain values (numbers, strings, booleans, tables of those).
function PlayerData.section(player: Player, name: string): { [string]: any }
	local profile = profiles[player]
	if not profile then
		return {}
	end
	local sections = profile.Data.Sections
	if type(sections[name]) ~= "table" then
		sections[name] = {}
	end
	return sections[name]
end

-- Everything this server knows about the player's saved data (read-only use).
function PlayerData.snapshot(player: Player): string
	local profile = profiles[player]
	return if profile then HttpService:JSONEncode(profile.Data) else "{}"
end

function PlayerData.isMemoryMode(): boolean
	return memoryMode
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Mirror owned items as attributes once loaded, so LocalScripts (shop UI) can read them.
PlayerData.onLoaded(function(player)
	local profile = profiles[player]
	if profile then
		for itemId in pairs(profile.Data.Owned) do
			player:SetAttribute("Owned_" .. Util.attrName(itemId), true)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(math.max(30, config.AutoSaveSeconds or 90))
		for player in profiles do
			task.spawn(PlayerData.save, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			PlayerData.save(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

return PlayerData
