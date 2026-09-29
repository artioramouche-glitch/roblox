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
-- Round 3 systems
expect("Catch 100 fish", "Attrape 100 poissons")
expect("🏁 Finished #1 in 60.2s!", "🏁 Arrivé 1e en 60.2s !")
expect("Lap 2/3  •  #1  •  best 41.20s", "Tour 2/3  •  #1  •  meilleur 41.20s")
expect("⭐ Level 5!", "⭐ Niveau 5 !")
expect("⭐ Level 5  •  40 / 125 XP", "⭐ Niveau 5  •  40 / 125 XP")
expect("📜 Quests  2/8", "📜 Quêtes  2/8")
expect("Stone Axe", "Hache en pierre")
expect("Needs 3 Stone", "Il faut 3 Pierre")
expect("🎣 REEL!", "🎣 ¡TIRA!", "es")
expect("Unlock the ocean (rod level 2)", "Schalte den Ozean frei (Angel-Level 2)", "de")
expect("Reach level 5 to use this code.", "Atteins le niveau 5 pour utiliser ce code.")
expect("👥 Sam is your friend: +10% Coins!", "👥 Sam est ton ami: +10% Pièces!")
print(if failures == 0 then "LANG OK" else `LANG FAILED ({failures})`)
process.exit(if failures == 0 then 0 else 1)
