--[[
	Unit test for gamekit/shared/Lang.luau (run by scripts/gamekit-integration.mjs).
	Usage: lune run scripts/lune/test-lang.luau
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Util = { config = function(_, defaults) return defaults end }
local env = {
	script = { Parent = { WaitForChild = function(_, name) return name end } },
	require = function(name)
		assert(name == "Util", "unexpected require " .. tostring(name))
		return Util
	end,
	game = {
		GetService = function(_, name)
			if name == "Players" then
				return { LocalPlayer = {} }
			elseif name == "LocalizationService" then
				return { RobloxLocaleId = "fr-fr" }
			end
			error("unexpected service " .. name)
		end,
	},
}
Util.config = function(_, defaults)
	return defaults
end
local Lang = luau.load(fs.readFile("gamekit/shared/Lang.luau"), { debugName = "Lang", environment = env })()

local failures = 0
local function expect(input: string, expected: string, language: string?)
	local got = Lang.t(input, language)
	if got ~= expected then
		failures += 1
		print(`FAIL Lang.t({input}, {language or "auto"}) = {got}, expected {expected}`)
	end
end
expect("Shop", "Boutique")
expect("Stage 12!", "Étape 12 !")
expect("+50 Coins", "+50 Pièces")
expect("Sold for 1.2K Coins!", "Vendu pour 1.2K Pièces!")
expect("Planting 🥕 Carrot now", "Planting 🥕 Carrot now")
expect("Rebirths", "Renaissances")
expect("0", "0")
expect("Unknown sentence", "Unknown sentence")
expect("You finished!", "¡Terminaste!", "es")
expect("Stage 4!", "Stufe 4!", "de")
expect("Shop", "Shop", "en")
expect("Shop", "Shop", "ja")
print(if failures == 0 then "LANG OK" else `LANG FAILED ({failures})`)
process.exit(if failures == 0 then 0 else 1)
