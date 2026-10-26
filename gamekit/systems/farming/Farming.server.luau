-- GameKit Farming (ServerScriptService.GameKit.Farming)
-- Plant -> wait -> harvest -> sell -> unlock better crops. Relaxed idle-style loop.
--   Plots:       parts tagged "FarmPlot" (soil). Prompt: plant the selected seed, harvest when ripe.
--   Seed stands: parts tagged "SeedStand" with attribute Crop = a name from Config.Farming.Crops.
--                Prompt: unlock the crop (UnlockPrice), then choose it as your seed.
--   Selling:     parts tagged "CropSell": prompt (or touch) sells everything in the basket.
-- Crops in the basket are saved stats (one per crop, hidden from the leaderboard); the
-- total is the player attribute "Basket" (HUD: Config.Hud ExtraStats = { "Basket" }).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("PlayerData"))
local Analytics = require(ServerScriptService:WaitForChild("GameKit"):WaitForChild("Analytics"))

local config = Util.config("Farming", {
	Currency = "Coins",
	MaxPlotsPerPlayer = 8,
	Yield = 1,
	RipeGraceSeconds = 90,
	Crops = {
		Wheat = { Order = 1, SeedPrice = 0, GrowSeconds = 15, SellPrice = 3, UnlockPrice = 0, Color = "#F4D03F", Icon = "🌾" },
		Carrot = { Order = 2, SeedPrice = 5, GrowSeconds = 30, SellPrice = 15, UnlockPrice = 100, Color = "#E67E22", Icon = "🥕" },
		Tomato = { Order = 3, SeedPrice = 15, GrowSeconds = 45, SellPrice = 45, UnlockPrice = 500, Color = "#E74C3C", Icon = "🍅" },
		Pumpkin = { Order = 4, SeedPrice = 40, GrowSeconds = 75, SellPrice = 140, UnlockPrice = 2500, Color = "#D35400", Icon = "🎃" },
		Crystal = { Order = 5, SeedPrice = 150, GrowSeconds = 120, SellPrice = 600, UnlockPrice = 9000, Color = "#8E44AD", Icon = "💎" },
	},
})

local CURRENCY = config.Currency
PlayerData.defineStat({ Name = CURRENCY, Default = 0, Leaderstat = true })

type CropDef = { Order: number?, SeedPrice: number?, GrowSeconds: number?, SellPrice: number?, UnlockPrice: number?, Color: string?, Icon: string? }

local cropNames: { string } = {}
for name in pairs(config.Crops) do
	table.insert(cropNames, name)
	PlayerData.defineStat({ Name = name, Default = 0, Leaderstat = false })
end
table.sort(cropNames, function(a, b)
	return ((config.Crops[a] :: CropDef).Order or 99) < ((config.Crops[b] :: CropDef).Order or 99)
end)
local FIRST_CROP = cropNames[1]

type PlotState = {
	owner: Player,
	crop: string,
	plantedAt: number,
	grow: number,
	stage: number,
	visual: Model?,
}

local plots: { [BasePart]: PlotState } = {}

local function cropDef(name: string): CropDef
	return (config.Crops[name] or config.Crops[FIRST_CROP]) :: CropDef
end

local function unlocked(player: Player, crop: string): boolean
	return (cropDef(crop).UnlockPrice or 0) <= 0 or PlayerData.owns(player, "Crop_" .. crop)
end

local function selectedSeed(player: Player): string
	local seed = player:GetAttribute("FarmSeed")
	if type(seed) == "string" and config.Crops[seed] and unlocked(player, seed) then
		return seed
	end
	-- Best unlocked crop by default.
	local best = FIRST_CROP
	for _, name in cropNames do
		if unlocked(player, name) then
			best = name
		end
	end
	return best
end

local function refreshBasket(player: Player)
	local total = 0
	for _, name in cropNames do
		total += PlayerData.get(player, name)
	end
	player:SetAttribute("Basket", total)
	player:SetAttribute("FarmSeed", selectedSeed(player))
end

local function countPlots(player: Player): number
	local n = 0
	for _, state in plots do
		if state.owner == player then
			n += 1
		end
	end
	return n
end

-- Visuals: sprout -> young plant -> ripe crop -----------------------------------------------

local function makeVisual(plot: BasePart, crop: string, stage: number): Model
	local def = cropDef(crop)
	local model = Instance.new("Model")
	model.Name = "GK_Crop"
	local top = plot.CFrame * CFrame.new(0, plot.Size.Y / 2, 0)
	local count = 4
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * plot.Size.X * 0.25, 0, math.sin(angle) * plot.Size.Z * 0.25)
		local height = if stage == 1 then 0.8 elseif stage == 2 then 2 else 2.6
		local stem = Instance.new("Part")
		stem.Name = "Stem"
		stem.Anchored = true
		stem.CanCollide = false
		stem.Size = Vector3.new(0.3, height, 0.3)
		stem.CFrame = top * CFrame.new(offset + Vector3.new(0, height / 2, 0))
		stem.Color = Color3.fromRGB(76, 175, 80)
		stem.Material = Enum.Material.Grass
		stem.Parent = model
		if stage >= 3 then
			local fruit = Instance.new("Part")
			fruit.Name = "Fruit"
			fruit.Anchored = true
			fruit.CanCollide = false
			fruit.Shape = Enum.PartType.Ball
			fruit.Size = Vector3.new(1.4, 1.4, 1.4)
			fruit.CFrame = top * CFrame.new(offset + Vector3.new(0, height + 0.4, 0))
			fruit.Color = Util.color(def.Color, Color3.fromRGB(255, 200, 60))
			fruit.Material = if crop == "Crystal" then Enum.Material.Neon else Enum.Material.SmoothPlastic
			fruit.Parent = model
		end
	end
	model.Parent = plot
	return model
end

local function label(plot: BasePart): TextLabel
	local gui = plot:FindFirstChild("GK_PlotLabel") :: BillboardGui?
	if not gui then
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "GK_PlotLabel"
		newGui.Size = UDim2.fromOffset(120, 34)
		newGui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		newGui.MaxDistance = 60
		newGui.AlwaysOnTop = true
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.FredokaOne
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Parent = newGui
		newGui.Parent = plot
		gui = newGui
	end
	return (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel
end

local function refreshPlot(plot: BasePart)
	local prompt = plot:FindFirstChild("GK_Farm") :: ProximityPrompt?
	local state = plots[plot]
	local text = label(plot)
	if not prompt then
		return
	end
	if not state then
		prompt.ActionText = "Plant"
		prompt.ObjectText = "Empty plot"
		prompt.Enabled = true
		text.Text = ""
		return
	end
	local def = cropDef(state.crop)
	local remaining = math.max(0, math.ceil(state.grow - (os.clock() - state.plantedAt)))
	if remaining > 0 then
		prompt.Enabled = false
		text.Text = `{def.Icon or ""} {remaining}s`
	else
		prompt.Enabled = true
		prompt.ActionText = "Harvest"
		prompt.ObjectText = `{def.Icon or ""} {state.crop} ({state.owner.Name})`
		text.Text = `{def.Icon or ""} Ready!`
	end
end

local function clearPlot(plot: BasePart)
	local state = plots[plot]
	if state and state.visual then
		state.visual:Destroy()
	end
	plots[plot] = nil
	refreshPlot(plot)
end

local function plant(player: Player, plot: BasePart): boolean
	if plots[plot] then
		return false
	end
	if countPlots(player) >= config.MaxPlotsPerPlayer then
		Net.notify(player, `You can farm {config.MaxPlotsPerPlayer} plots at once. Harvest first!`, "error")
		return false
	end
	local crop = selectedSeed(player)
	local def = cropDef(crop)
	local price = def.SeedPrice or 0
	if price > 0 and not PlayerData.spend(player, CURRENCY, price, crop .. "Seed", "Gameplay") then
		Net.notify(player, `{crop} seeds cost {Util.formatNumber(price)} {CURRENCY}. Sell crops or pick cheaper seeds!`, "error")
		return false
	end
	local state: PlotState = { owner = player, crop = crop, plantedAt = os.clock(), grow = math.max(1, def.GrowSeconds or 20), stage = 1 }
	state.visual = makeVisual(plot, crop, 1)
	plots[plot] = state
	refreshPlot(plot)
	return true
end

local function harvest(player: Player, plot: BasePart): boolean
	local state = plots[plot]
	if not state then
		return false
	end
	local ripeFor = os.clock() - state.plantedAt - state.grow
	if ripeFor < 0 then
		return false
	end
	-- Other players may pick crops left ripe for too long, so plots never stay blocked.
	if state.owner ~= player and state.owner.Parent and ripeFor < config.RipeGraceSeconds then
		Net.notify(player, `These crops belong to {state.owner.Name}.`, "error")
		return false
	end
	PlayerData.add(player, state.crop, config.Yield)
	clearPlot(plot)
	refreshBasket(player)
	Net.notify(player, `+{config.Yield} {cropDef(state.crop).Icon or ""} {state.crop}`, "success")
	return true
end

local function sellAll(player: Player): number
	local earned = 0
	for _, name in cropNames do
		local amount = PlayerData.get(player, name)
		if amount > 0 then
			PlayerData.set(player, name, 0)
			earned += PlayerData.reward(player, CURRENCY, amount * (cropDef(name).SellPrice or 1))
		end
	end
	refreshBasket(player)
	if earned > 0 then
		Net.notify(player, `Sold for {Util.formatNumber(earned)} {CURRENCY}!`, "reward")
	else
		Net.notify(player, "Your basket is empty: harvest crops first.", "info")
	end
	return earned
end

-- Wiring -----------------------------------------------------------------------------------

Util.onTag("FarmPlot", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local plot = instance :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Farm"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0.2
	prompt.Parent = plot
	prompt.Triggered:Connect(function(player)
		if plots[plot] then
			harvest(player, plot)
		else
			plant(player, plot)
		end
	end)
	refreshPlot(plot)
end, function(instance)
	if instance:IsA("BasePart") then
		plots[instance] = nil
	end
end)

Util.onTag("SeedStand", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local crop = tostring(instance:GetAttribute("Crop") or FIRST_CROP)
	local def = config.Crops[crop] :: CropDef?
	if not def then
		warn(`[GameKit] SeedStand {instance:GetFullName()}: unknown crop "{crop}" (Config.Farming.Crops)`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Seed"
	prompt.ActionText = if (def.UnlockPrice or 0) > 0 then `Choose (unlock: {Util.formatNumber(def.UnlockPrice or 0)} {CURRENCY})` else "Choose these seeds"
	prompt.ObjectText = `{def.Icon or ""} {crop} (sells {Util.formatNumber(def.SellPrice or 0)})`
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		if not unlocked(player, crop) then
			if not PlayerData.spend(player, CURRENCY, def.UnlockPrice or 0, "Unlock" .. crop, "Shop") then
				Net.notify(player, `Unlocking {crop} costs {Util.formatNumber(def.UnlockPrice or 0)} {CURRENCY}.`, "error")
				return
			end
			PlayerData.grant(player, "Crop_" .. crop)
			Net.notify(player, `🔓 {def.Icon or ""} {crop} unlocked!`, "success")
			Analytics.progression(player, "Farming", def.Order or 1, crop)
		end
		player:SetAttribute("FarmSeed", crop)
		Net.notify(player, `Planting {def.Icon or ""} {crop} now (seed {Util.formatNumber(def.SeedPrice or 0)} {CURRENCY}).`, "info")
	end)
end)

local sellCooldown = Util.cooldown(1.5)
Util.onTag("CropSell", function(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GK_Sell"
	prompt.ActionText = "Sell crops"
	prompt.ObjectText = "Market"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		sellAll(player)
	end)
	instance.Touched:Connect(function(hit)
		local player = Util.playerFromHit(hit)
		if player and sellCooldown(player) and (player:GetAttribute("Basket") or 0) > 0 then
			sellAll(player)
		end
	end)
end)

PlayerData.onLoaded(function(player)
	refreshBasket(player)
end)

Players.PlayerRemoving:Connect(function(player)
	for plot, state in plots do
		if state.owner == player then
			clearPlot(plot)
		end
	end
end)

-- Growth: update stages and labels once per second.
task.spawn(function()
	while true do
		task.wait(1)
		for plot, state in plots do
			local progress = (os.clock() - state.plantedAt) / state.grow
			local stage = if progress >= 1 then 3 elseif progress >= 0.5 then 2 else 1
			if stage ~= state.stage then
				state.stage = stage
				if state.visual then
					state.visual:Destroy()
				end
				state.visual = makeVisual(plot, state.crop, stage)
			end
			refreshPlot(plot)
		end
	end
end)

-- Test hooks used by test_game (harmless in live games).
local hook = Instance.new("BindableFunction")
hook.Name = "__GameKitHook"
hook.OnInvoke = function(action: string, player: Player, plot: BasePart?)
	if action == "plant" and plot then
		return plant(player, plot)
	elseif action == "ripen" and plot then
		local state = plots[plot]
		if state then
			state.plantedAt -= state.grow
			return true
		end
		return false
	elseif action == "harvest" and plot then
		return harvest(player, plot)
	elseif action == "sell" then
		return sellAll(player)
	end
	return nil
end
hook.Parent = script
