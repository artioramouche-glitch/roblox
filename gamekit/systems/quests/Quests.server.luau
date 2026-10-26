-- GameKit Quests (ServerScriptService.GameKit.Quests)
-- Missions with rewards, tracked automatically and saved. Quest types (Config.Quests.List):
--   Earn  -- gain Amount of Stat after the quest starts ("Collect 100 coins", "Defeat 10 enemies" with Kills)
--   Reach -- have Stat >= Amount ("Reach stage 10", "Reach level 5")
--   Have  -- own Amount of an inventory Item ("Catch 3 salmon")
--   Touch -- touch a part tagged "QuestTarget" whose attribute Quest = the quest Id ("Find the secret cave")
-- Mode "Chain": one quest at a time, in order (great for onboarding). Mode "All": all at once.
-- Rewards are stats, e.g. { Coins = 100, XP = 50 }. The tracker panel shows progress.
-- Guide arrow (ShowArrow): a beam from the player to where the quest happens. Touch quests
-- point at their QuestTarget; others use Target = "tag:FishingSpot" (nearest tagged part),
-- "tag:ResourceNode/Node=Tree" (nearest with that attribute) or a path like "Workspace/GameKit/Shop".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("Quests", {
	Mode = "Chain",
	List = {
		{ Id = "FirstCoins", Title = "Collect 25 coins", Type = "Earn", Stat = "Coins", Amount = 25, Rewards = { XP = 50 } },
		{ Id = "MoreCoins", Title = "Collect 200 coins", Type = "Earn", Stat = "Coins", Amount = 200, Rewards = { XP = 150, Coins = 50 } },
	},
	ShowTracker = true,
	ShowArrow = true,
})

type Quest = { Id: string, Title: string?, Type: string?, Stat: string?, Item: string?, Amount: number?, Rewards: { [string]: number }?, Target: string? }

local quests: { Quest } = {}
for _, quest in config.List do
	if type(quest) == "table" and type(quest.Id) == "string" then
		table.insert(quests, quest)
		for stat in pairs(quest.Rewards or {}) do
			PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = stat ~= "XP" })
		end
		if (quest.Type == "Earn" or quest.Type == "Reach") and quest.Stat then
			PlayerData.defineStat({ Name = quest.Stat, Default = 0 })
		end
	end
end

local function state(player: Player): { Done: { [string]: boolean }, Progress: { [string]: number } }
	local data = PlayerData.section(player, "Quests")
	data.Done = data.Done or {}
	data.Progress = data.Progress or {}
	return data :: any
end

local function active(player: Player): { Quest }
	local data = state(player)
	local list = {}
	for _, quest in quests do
		if not data.Done[quest.Id] then
			table.insert(list, quest)
			if config.Mode == "Chain" then
				break
			end
		end
	end
	return list
end

local function progressOf(player: Player, quest: Quest): number
	local data = state(player)
	if quest.Type == "Reach" and quest.Stat then
		return PlayerData.get(player, quest.Stat)
	elseif quest.Type == "Have" and quest.Item then
		local count = player:GetAttribute(Util.attrName("Inv_" .. quest.Item))
		return if type(count) == "number" then count else 0
	end
	return data.Progress[quest.Id] or 0
end

local function publish(player: Player)
	local rows = {}
	for _, quest in active(player) do
		local target = if quest.Type == "Touch" then `quest:{quest.Id}` else quest.Target
		table.insert(rows, {
			id = quest.Id,
			title = quest.Title or quest.Id,
			progress = math.min(progressOf(player, quest), quest.Amount or 1),
			goal = quest.Amount or 1,
			target = if config.ShowArrow ~= false then target else nil,
		})
	end
	local data = state(player)
	local done = 0
	for _ in data.Done do
		done += 1
	end
	Net.fire(player, "QuestsUpdate", rows, done, #quests)
end

local function complete(player: Player, quest: Quest)
	local data = state(player)
	if data.Done[quest.Id] then
		return
	end
	data.Done[quest.Id] = true
	data.Progress[quest.Id] = nil
	local rewardText = {}
	for stat, amount in pairs(quest.Rewards or {}) do
		local given = PlayerData.reward(player, stat, amount, "Gameplay")
		table.insert(rewardText, `+{Util.formatNumber(given)} {stat}`)
	end
	Net.notify(player, `✅ {quest.Title or quest.Id}! {table.concat(rewardText, "  ")}`, "reward")
	local index = table.find(quests, quest) or 0
	if config.Mode == "Chain" and index <= 10 then
		Analytics.onboarding(player, index, quest.Id)
	end
	Analytics.custom(player, "QuestDone_" .. quest.Id, 1)
end

local function evaluate(player: Player)
	if not PlayerData.isLoaded(player) then
		return
	end
	-- Loop: completing a chain quest may immediately complete the next one ("Reach").
	for _ = 1, #quests do
		local finished = false
		for _, quest in active(player) do
			if quest.Type ~= "Touch" and progressOf(player, quest) >= (quest.Amount or 1) then
				complete(player, quest)
				finished = true
			end
		end
		if not finished then
			break
		end
	end
	publish(player)
end

-- One listener per stat: "Earn" quests count gains made while they are active, and any
-- change can complete a "Reach" quest. (A stat can be used by both kinds.)
local watched: { [string]: boolean } = {}
for _, quest in quests do
	local stat = quest.Stat
	if (quest.Type == "Earn" or quest.Type == "Reach") and stat and not watched[stat] then
		watched[stat] = true
		PlayerData.onChanged(stat, function(player, new, old)
			if new > old then
				local data = state(player)
				for _, q in active(player) do
					if q.Type == "Earn" and q.Stat == stat then
						data.Progress[q.Id] = (data.Progress[q.Id] or 0) + (new - old)
					end
				end
			end
			evaluate(player)
		end)
	end
end

Util.onPlayer(function(player)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 4) == "Inv_" then
			evaluate(player)
		end
	end)
end)

local touchCooldown = Util.cooldown(1)
Util.onTag("QuestTarget", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	instance.Touched:Connect(function(hit)
		local player = Util.playerFromHit(hit)
		local questId = instance:GetAttribute("Quest")
		if not player or type(questId) ~= "string" or not touchCooldown(player) then
			return
		end
		for _, quest in active(player) do
			if quest.Id == questId then
				complete(player, quest)
				evaluate(player)
			end
		end
	end)
end)

PlayerData.onLoaded(evaluate)
Net.on("QuestsSync", function(player)
	publish(player)
end, 2)

-- Test hook used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player)
	if action == "active" then
		local list = active(player)
		return if list[1] then list[1].Id else nil
	elseif action == "completeFirst" then
		local list = active(player)
		if list[1] then
			complete(player, list[1])
			evaluate(player)
			return list[1].Id
		end
	end
	return nil
end
hook.Parent = script
