-- GameKit Util (ReplicatedStorage.GameKit.Util)
-- Small helpers shared by every GameKit system, on both server and client.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.2K", 5600000 -> "5.6M". Keeps small numbers exact.
function Util.formatNumber(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	local n = math.abs(value)
	if n < 1000 then
		local text = if n == math.floor(n) then tostring(n) else string.format("%.1f", n)
		return (if negative then "-" else "") .. text
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text = if n >= 100 then string.format("%d", math.floor(n)) else string.format("%.1f", math.floor(n * 10) / 10)
	text = string.gsub(text, "%.0$", "")
	return (if negative then "-" else "") .. text .. SUFFIXES[index]
end

-- Attribute names may only contain letters, digits and "_": "Zone 2" -> "Zone_2".
function Util.attrName(text: string): string
	return (string.gsub(text, "[^%w_]", "_"))
end

-- 65 -> "1:05"
function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local configCache: { [string]: { [string]: any } } = {}

-- Reads ReplicatedStorage.GameKit.Config.<name> and fills missing keys from `defaults`.
-- Systems always call this, so a deleted or half-edited config never crashes a game.
function Util.config(name: string, defaults: { [string]: any }?): { [string]: any }
	local cached = configCache[name]
	if cached then
		return cached
	end
	local result: { [string]: any } = {}
	local folder = (script.Parent :: Instance):FindFirstChild("Config")
	local module = folder and folder:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, value = pcall(require, module)
		if ok and type(value) == "table" then
			for key, v in pairs(value) do
				result[key] = v
			end
		else
			warn(`[GameKit] Config '{name}' has an error, using defaults: {value}`)
		end
	end
	if defaults then
		for key, v in pairs(defaults) do
			if result[key] == nil then
				result[key] = v
			end
		end
	end
	configCache[name] = result
	return result
end

-- Accepts "#RRGGBB", {r, g, b} or a Color3 and returns a Color3.
function Util.color(value: any, fallback: Color3?): Color3
	if typeof(value) == "Color3" then
		return value
	elseif type(value) == "string" and string.sub(value, 1, 1) == "#" then
		local ok, c = pcall(Color3.fromHex, value)
		if ok then
			return c
		end
	elseif type(value) == "table" and #value >= 3 then
		return Color3.fromRGB(value[1], value[2], value[3])
	end
	return fallback or Color3.new(1, 1, 1)
end

-- From any part touched by a character, returns the player, character and a living humanoid.
function Util.playerFromHit(hit: BasePart): (Player?, Model?, Humanoid?)
	local character = hit:FindFirstAncestorOfClass("Model")
	while character and not character:FindFirstChildOfClass("Humanoid") do
		character = character:FindFirstAncestorOfClass("Model")
	end
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, character, nil
	end
	return Players:GetPlayerFromCharacter(character), character, humanoid
end

-- Calls onAdded for every instance with `tag` now and in the future.
function Util.onTag(tag: string, onAdded: (Instance) -> (), onRemoved: ((Instance) -> ())?)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(onAdded, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdded)
	if onRemoved then
		CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemoved)
	end
end

-- Calls fn(player) for players already in the game and every player who joins.
function Util.onPlayer(fn: (Player) -> ())
	for _, player in Players:GetPlayers() do
		task.spawn(fn, player)
	end
	Players.PlayerAdded:Connect(fn)
end

-- Calls fn(character, player) on every spawn of every player.
function Util.onCharacter(fn: (Model, Player) -> ())
	Util.onPlayer(function(player)
		if player.Character then
			task.spawn(fn, player.Character, player)
		end
		player.CharacterAdded:Connect(function(character)
			fn(character, player)
		end)
	end)
end

-- Per-key cooldown: returns true at most once every `seconds` for the same key.
function Util.cooldown(seconds: number): (key: any) -> boolean
	local last: { [any]: number } = {}
	return function(key: any): boolean
		local now = os.clock()
		if last[key] and now - last[key] < seconds then
			return false
		end
		last[key] = now
		return true
	end
end

-- Moves a character so it stands on top of `part`.
function Util.teleportOnto(character: Model, part: BasePart, extraHeight: number?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local offset = part.Size.Y / 2 + 3 + (extraHeight or 0)
	character:PivotTo(CFrame.new(part.Position + Vector3.new(0, offset, 0)) * part.CFrame.Rotation)
	root.AssemblyLinearVelocity = Vector3.zero
end

-- Respawns a player (server only). Uses LoadCharacterAsync when the engine has it.
function Util.respawn(player: Player)
	local ok = pcall(function()
		(player :: any):LoadCharacterAsync()
	end)
	if not ok then
		pcall(function()
			(player :: any):LoadCharacter()
		end)
	end
end

-- Where GameKit publishes shared state (Status text, timers, round state) as attributes.
function Util.state(): Instance
	return script.Parent :: Instance
end

return Util
