-- GameKit Net (ReplicatedStorage.GameKit.Net)
-- RemoteEvents made simple and safe:
--   server: Net.on("Buy", function(player, itemId) ... end)  -- rate limited, errors caught
--           Net.fire(player, "Notify", "Hello")  /  Net.fireAll("Notify", "Round starts!")
--   client: Net.send("Buy", "Sword")  /  Net.listen("Notify", function(text) ... end)
-- Remotes are created by the server on demand in ReplicatedStorage.GameKit.Remotes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local Net = {}

local function remotesFolder(): Instance
	local kit = script.Parent :: Instance
	local folder = kit:FindFirstChild("Remotes")
	if folder then
		return folder
	end
	if IS_SERVER then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = kit
		return folder
	end
	return kit:WaitForChild("Remotes")
end

-- Returns the RemoteEvent called `name` (the server creates it if missing).
function Net.event(name: string): RemoteEvent
	local folder = remotesFolder()
	local remote = folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	if IS_SERVER then
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		return created
	end
	local waited = folder:WaitForChild(name, 30)
	if not waited then
		error(`[GameKit] RemoteEvent '{name}' was never created by the server. Is the matching server system installed?`)
	end
	return waited :: RemoteEvent
end

-- SERVER: listen to a client request. `handler(player, ...)` runs protected and at most
-- `perSecond` times per second per player (extra requests are dropped silently).
function Net.on(name: string, handler: (Player, ...any) -> (), perSecond: number?)
	assert(IS_SERVER, "Net.on is server-only; use Net.listen on the client")
	local limit = perSecond or 10
	local windows: { [Player]: { start: number, count: number } } = {}
	Players.PlayerRemoving:Connect(function(player)
		windows[player] = nil
	end)
	Net.event(name).OnServerEvent:Connect(function(player, ...)
		local now = os.clock()
		local window = windows[player]
		if not window or now - window.start >= 1 then
			window = { start = now, count = 0 }
			windows[player] = window
		end
		window.count += 1
		if window.count > limit then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(`[GameKit] Error in '{name}' handler: {err}`)
		end
	end)
end

-- SERVER: send to one player.
function Net.fire(player: Player, name: string, ...: any)
	Net.event(name):FireClient(player, ...)
end

-- SERVER: send to everyone.
function Net.fireAll(name: string, ...: any)
	Net.event(name):FireAllClients(...)
end

-- SERVER: show a toast message on one player's screen (or everyone's when player is nil).
-- kind: "info" | "success" | "error" | "reward"
function Net.notify(player: Player?, text: string, kind: string?)
	if player then
		Net.fire(player, "Notify", text, kind or "info")
	else
		Net.fireAll("Notify", text, kind or "info")
	end
end

-- CLIENT: send a request to the server.
function Net.send(name: string, ...: any)
	Net.event(name):FireServer(...)
end

-- CLIENT: listen to messages from the server.
function Net.listen(name: string, handler: (...any) -> ()): RBXScriptConnection
	return Net.event(name).OnClientEvent:Connect(handler)
end

return Net
