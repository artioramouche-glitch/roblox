-- GameKit Analytics (ServerScriptService.GameKit.Analytics)
-- Sends events to the Creator Dashboard (Analytics > Economy / Funnels / Progression /
-- Custom) so you can see where players quit and how money flows. Every call is safe:
-- errors and rate limits are swallowed, and nothing is sent in Studio test sessions.
--
--   local Analytics = require(game:GetService("ServerScriptService").GameKit.Analytics)
--   Analytics.source(player, "Coins", 50, balance, "Gameplay")       -- money earned
--   Analytics.sink(player, "Coins", 100, balance, "Shop", "Sword")   -- money spent
--   Analytics.onboarding(player, 2, "Reached stage 2")              -- first-time steps
--   Analytics.progression(player, "Obby", 5, "Stage 5")             -- levels completed
--   Analytics.custom(player, "BossDefeated", 1)
--
-- PlayerData.reward / PlayerData.spend already report currencies (Config.PlayerData
-- AnalyticsCurrencies), so most games need nothing else.

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}

local ENABLED = not RunService:IsStudio()
local FLUSH_SECONDS = 60
local TRANSACTION_TYPES = {
	Gameplay = true,
	Shop = true,
	IAP = true,
	ContextualPurchase = true,
	TimedReward = true,
	Onboarding = true,
}

-- Frequent small rewards (droppers, coins) are summed and sent once a minute, to stay
-- far below the event rate limits.
type Pending = { amount: number, balance: number }
local pending: { [Player]: { [string]: Pending } } = {}

local function transactionType(kind: string?): string
	if kind and TRANSACTION_TYPES[kind] then
		return kind
	end
	return "Gameplay"
end

local function safe(fn: () -> ())
	if not ENABLED then
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		warn(`[GameKit] Analytics: {err}`)
	end
end

function Analytics.isEnabled(): boolean
	return ENABLED
end

function Analytics.source(player: Player, currency: string, amount: number, balance: number, kind: string?)
	if amount <= 0 or not ENABLED then
		return
	end
	local key = currency .. "|" .. transactionType(kind)
	local byKey = pending[player]
	if not byKey then
		byKey = {}
		pending[player] = byKey
	end
	local entry = byKey[key]
	if entry then
		entry.amount += amount
		entry.balance = balance
	else
		byKey[key] = { amount = amount, balance = balance }
	end
end

function Analytics.sink(player: Player, currency: string, amount: number, balance: number, kind: string?, itemSku: string?)
	if amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, currency, amount, balance, transactionType(kind), itemSku)
	end)
end

function Analytics.onboarding(player: Player, step: number, stepName: string?)
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function Analytics.progression(player: Player, path: string, level: number, levelName: string?)
	safe(function()
		AnalyticsService:LogProgressionCompleteEvent(player, path, level, levelName)
	end)
end

function Analytics.custom(player: Player, eventName: string, value: number?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, eventName, value)
	end)
end

local function flush(player: Player)
	local byKey = pending[player]
	if not byKey then
		return
	end
	pending[player] = nil
	for key, entry in byKey do
		local currency, kind = string.match(key, "^(.*)|(.*)$")
		safe(function()
			AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, currency or key, entry.amount, entry.balance, kind or "Gameplay")
		end)
	end
end

-- Call before the player's data is released (PlayerData does it on leave).
function Analytics.flush(player: Player)
	flush(player)
end

if ENABLED then
	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			for player in pending do
				if player.Parent then
					flush(player)
				else
					pending[player] = nil
				end
			end
		end
	end)
end

return Analytics
