-- GameKit Checkpoints (ServerScriptService.GameKit.Checkpoints)
-- Obby progression. Tag parts "Checkpoint" and give each a number attribute "Stage"
-- (1, 2, 3...). Tag the end part "FinishLine". Progress is saved and players respawn
-- on their last checkpoint.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))

local config = Util.config("Checkpoints", {
	StageStat = "Stage",
	RequireOrder = true,
	ReachedColor = "#4CD964",
	FinishRewards = { Wins = 1, Coins = 50 },
	ResetOnFinish = true,
	AnnounceFinish = true,
})

local STAGE = config.StageStat
PlayerData.defineStat({ Name = STAGE, Default = 1, Leaderstat = true })
for stat in pairs(config.FinishRewards) do
	PlayerData.defineStat({ Name = stat, Default = 0, Leaderstat = true })
end

local checkpoints: { [number]: BasePart } = {}
local maxStage = 1
local touchCooldown = Util.cooldown(0.5)

local function stageOf(part: Instance): number?
	local value = part:GetAttribute("Stage")
	return if type(value) == "number" then math.floor(value) else nil
end

local function refreshMaxStage()
	maxStage = 1
	for stage in pairs(checkpoints) do
		maxStage = math.max(maxStage, stage)
	end
	kit:SetAttribute("MaxStage", maxStage)
end

local function spawnAtCheckpoint(character: Model, player: Player)
	local stage = PlayerData.get(player, STAGE)
	local target = checkpoints[stage]
	if not target then
		-- Fall back to the highest checkpoint the player has reached.
		for s = stage, 1, -1 do
			if checkpoints[s] then
				target = checkpoints[s]
				break
			end
		end
	end
	if not target or stage <= 1 and not checkpoints[1] then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait() -- let the default spawn finish first
	if character.Parent then
		Util.teleportOnto(character, target)
	end
end

local function onCheckpointTouched(part: BasePart, hit: BasePart)
	local player = Util.playerFromHit(hit)
	if not player or not PlayerData.isLoaded(player) or not touchCooldown(player) then
		return
	end
	local stage = stageOf(part)
	if not stage then
		return
	end
	local current = PlayerData.get(player, STAGE)
	local allowed = if config.RequireOrder then stage == current + 1 else stage > current
	if allowed then
		PlayerData.set(player, STAGE, stage)
		Net.notify(player, `Stage {stage}!`, "success")
	elseif stage > current + 1 and config.RequireOrder then
		Net.notify(player, `You skipped a checkpoint! Go back to stage {current + 1}.`, "error")
	end
end

local function finishRun(player: Player)
	local rewardText = {}
	for stat, amount in pairs(config.FinishRewards) do
		local given = PlayerData.reward(player, stat, amount)
		table.insert(rewardText, `+{Util.formatNumber(given)} {stat}`)
	end
	Net.notify(player, "🏁 You finished! " .. table.concat(rewardText, "  "), "reward")
	if config.AnnounceFinish then
		for _, other in game:GetService("Players"):GetPlayers() do
			if other ~= player then
				Net.notify(other, `{player.DisplayName} finished the obby!`, "info")
			end
		end
	end
	if config.ResetOnFinish then
		task.wait(2)
		if player.Parent then
			PlayerData.set(player, STAGE, 1)
			Util.respawn(player)
		end
	end
end

local finishing: { [Player]: boolean } = {}

local function onFinishTouched(hit: BasePart)
	local player = Util.playerFromHit(hit)
	if not player or finishing[player] or not PlayerData.isLoaded(player) then
		return
	end
	if PlayerData.get(player, STAGE) < maxStage then
		if touchCooldown(player) then
			Net.notify(player, `Reach all {maxStage} checkpoints first!`, "error")
		end
		return
	end
	finishing[player] = true
	finishRun(player)
	finishing[player] = nil
end

Util.onTag("Checkpoint", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	local stage = stageOf(part)
	if not stage then
		warn(`[GameKit] Checkpoint {part:GetFullName()} has no number attribute "Stage"`)
		return
	end
	checkpoints[stage] = part
	refreshMaxStage()
	part.Touched:Connect(function(hit)
		onCheckpointTouched(part, hit)
	end)
end, function(instance)
	local stage = stageOf(instance)
	if stage and checkpoints[stage] == instance then
		checkpoints[stage] = nil
		refreshMaxStage()
	end
end)

Util.onTag("FinishLine", function(instance)
	if instance:IsA("BasePart") then
		instance.Touched:Connect(onFinishTouched)
	end
end)

Util.onCharacter(function(character, player)
	if PlayerData.waitForLoad(player) then
		spawnAtCheckpoint(character, player)
	end
end)

-- Highlight reached checkpoints for each player (client does the coloring).
PlayerData.onChanged(STAGE, function(player, stage)
	player:SetAttribute("GK_ReachedStage", stage)
end)

if #CollectionService:GetTagged("Checkpoint") == 0 then
	warn('[GameKit] Checkpoints: no part tagged "Checkpoint" yet. Use build_world (obby_course or checkpoint) to add some.')
end
