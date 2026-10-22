-- GameKit Inventory (ServerScriptService.GameKit.Inventory) -- server module.
-- Saved item counts per player (fish, wood, potions, keys...), shown in the 🎒 window.
--
--   local Inventory = require(game:GetService("ServerScriptService").GameKit.Inventory)
--   Inventory.define("Salmon", { Name = "Salmon", Icon = "🐟", SellPrice = 12, Rarity = "Rare" })
--   Inventory.give(player, "Wood", 3)       -- returns the new count (0 if full)
--   Inventory.take(player, "Wood", 2)       -- true when the player had enough
--   Inventory.count(player, "Wood")
--   Inventory.sellAll(player)               -- sells everything that has a SellPrice
--
-- Clients read counts with player:GetAttribute("Inv_Wood") and the definitions from the
-- "ItemDefs" attribute (JSON) on ReplicatedStorage.GameKit.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local config = Util.config("Inventory", {
	Items = {
		Wood = { Name = "Wood", Icon = "🪵", SellPrice = 1 },
		Stone = { Name = "Stone", Icon = "🪨", SellPrice = 2 },
	},
	MaxStack = 999,
	SellCurrency = "Coins",
	ShowButton = true,
})

export type ItemDef = {
	Name: string?,
	Icon: string?,
	SellPrice: number?,
	Rarity: string?,
	Description: string?,
	Color: string?,
}

local Inventory = {}

local defs: { [string]: ItemDef } = {}
local changed: { (Player, string, number) -> () } = {}

local function publishDefs()
	kit:SetAttribute("ItemDefs", HttpService:JSONEncode(defs))
end

function Inventory.define(itemId: string, def: ItemDef)
	defs[itemId] = def
	publishDefs()
end

function Inventory.def(itemId: string): ItemDef?
	return defs[itemId]
end

local function bag(player: Player): { [string]: number }
	local section = PlayerData.section(player, "Inventory")
	section.Items = section.Items or {}
	return section.Items
end

local function mirror(player: Player, itemId: string, count: number)
	player:SetAttribute(Util.attrName("Inv_" .. itemId), count)
	local total = 0
	for _, n in bag(player) do
		total += n
	end
	player:SetAttribute("InvItems", total)
end

function Inventory.count(player: Player, itemId: string): number
	return bag(player)[itemId] or 0
end

function Inventory.items(player: Player): { [string]: number }
	return table.clone(bag(player))
end

function Inventory.give(player: Player, itemId: string, amount: number?): number
	if not PlayerData.isLoaded(player) then
		return 0
	end
	local items = bag(player)
	local current = items[itemId] or 0
	local new = math.min(config.MaxStack, current + (amount or 1))
	if new == current then
		return 0
	end
	items[itemId] = new
	mirror(player, itemId, new)
	for _, fn in changed do
		task.spawn(fn, player, itemId, new)
	end
	return new
end

function Inventory.take(player: Player, itemId: string, amount: number?): boolean
	local items = bag(player)
	local need = amount or 1
	local current = items[itemId] or 0
	if current < need then
		return false
	end
	local new = current - need
	items[itemId] = if new > 0 then new else nil
	mirror(player, itemId, new)
	for _, fn in changed do
		task.spawn(fn, player, itemId, new)
	end
	return true
end

-- Sells `amount` (default all) of one item for its SellPrice. Returns the money earned.
function Inventory.sell(player: Player, itemId: string, amount: number?): number
	local def = defs[itemId]
	local price = def and def.SellPrice or 0
	if price <= 0 then
		return 0
	end
	local n = math.min(amount or Inventory.count(player, itemId), Inventory.count(player, itemId))
	if n <= 0 or not Inventory.take(player, itemId, n) then
		return 0
	end
	return PlayerData.reward(player, config.SellCurrency, n * price)
end

function Inventory.sellAll(player: Player): number
	local earned = 0
	for itemId in Inventory.items(player) do
		earned += Inventory.sell(player, itemId)
	end
	return earned
end

-- fn(player, itemId, newCount) after every change.
function Inventory.onChanged(fn: (Player, string, number) -> ())
	table.insert(changed, fn)
end

for itemId, def in config.Items do
	defs[itemId] = def
end
publishDefs()
PlayerData.defineStat({ Name = config.SellCurrency, Default = 0, Leaderstat = true })
PlayerData.onLoaded(function(player)
	for itemId, count in bag(player) do
		mirror(player, itemId, count)
	end
	player:SetAttribute("InvItems", player:GetAttribute("InvItems") or 0)
end)

return Inventory
