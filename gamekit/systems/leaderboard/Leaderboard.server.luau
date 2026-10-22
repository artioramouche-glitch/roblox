-- GameKit global leaderboard (ServerScriptService.GameKit.Leaderboard)
-- Tag a part "LeaderboardBoard" (a big flat part works best) and set the attributes
--   Stat  (string, default "Wins")  and  Title (string, optional).
-- It shows the all-time top 10 across every server (OrderedDataStore), refreshed
-- every Config.Leaderboard.RefreshSeconds. Without DataStore access (Studio) it shows
-- the players in the current server instead.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Leaderboard", {
	RefreshSeconds = 60,
	Entries = 10,
	StorePrefix = "GameKit_Top_",
})

type Board = { part: BasePart, stat: string, list: Frame }
local boards: { Board } = {}
local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else ("Player " .. userId)
	return names[userId]
end

local function buildGui(part: BasePart, title: string): Frame
	local old = part:FindFirstChild("GK_Board")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GK_Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
	background.Parent = gui
	local header = Instance.new("TextLabel")
	header.Size = UDim2.fromScale(1, 0.14)
	header.BackgroundColor3 = Color3.fromRGB(255, 201, 64)
	header.Font = Enum.Font.FredokaOne
	header.TextScaled = true
	header.TextColor3 = Color3.fromRGB(30, 30, 30)
	header.Text = "🏆 " .. title
	header.Parent = background
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.16)
	list.Size = UDim2.fromScale(0.92, 0.82)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.005, 0)
	layout.Parent = list
	list.Parent = background
	gui.Parent = part
	return list
end

local function render(board: Board, rows: { { name: string, value: number } })
	for _, child in board.list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for rank, row in ipairs(rows) do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = rank
		label.Size = UDim2.fromScale(1, 1 / (config.Entries + 0.5))
		label.BackgroundTransparency = if rank % 2 == 0 then 1 else 0.85
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if rank == 1
			then Color3.fromRGB(255, 215, 0)
			elseif rank == 2 then Color3.fromRGB(210, 210, 220)
			elseif rank == 3 then Color3.fromRGB(205, 127, 50)
			else Color3.new(1, 1, 1)
		label.Text = `  #{rank}  {row.name}  —  {Util.formatNumber(row.value)}`
		label.Parent = board.list
	end
end

local function localRows(stat: string): { { name: string, value: number } }
	local rows = {}
	for _, player in Players:GetPlayers() do
		table.insert(rows, { name = player.DisplayName, value = PlayerData.get(player, stat) })
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	return rows
end

local function refresh(board: Board)
	if PlayerData.isMemoryMode() then
		render(board, localRows(board.stat))
		return
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(config.StorePrefix .. board.stat)
	end)
	if not ok then
		render(board, localRows(board.stat))
		return
	end
	for _, player in Players:GetPlayers() do
		if PlayerData.isLoaded(player) then
			local value = math.floor(PlayerData.get(player, board.stat))
			pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
	local pageOk, pages = pcall(function()
		return store:GetSortedAsync(false, config.Entries)
	end)
	if not pageOk then
		render(board, localRows(board.stat))
		return
	end
	local rows = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(rows, { name = nameOf(tonumber(entry.key) or 0), value = entry.value })
	end
	render(board, rows)
end

Util.onTag("LeaderboardBoard", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local statValue = instance:GetAttribute("Stat")
	local stat = if type(statValue) == "string" then statValue else "Wins"
	local titleValue = instance:GetAttribute("Title")
	local board: Board = {
		part = instance,
		stat = stat,
		list = buildGui(instance, if type(titleValue) == "string" then titleValue else "Top " .. stat),
	}
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
	table.insert(boards, board)
	task.spawn(refresh, board)
end)

task.spawn(function()
	while true do
		task.wait(math.max(15, config.RefreshSeconds))
		for _, board in ipairs(boards) do
			if board.part.Parent then
				pcall(refresh, board)
			end
		end
	end
end)
