-- GameKit Lang (ReplicatedStorage.GameKit.Lang)
-- Translates GameKit's interface into the player's language (French, Spanish, Portuguese,
-- German built in). UIKit calls it for every label, button, window title and toast, so
-- most of the UI is translated without any work.
--
--   local Lang = require(ReplicatedStorage.GameKit.Lang)
--   label.Text = Lang.t("Shop")          -- "Boutique" for a French player
--   Lang.t("Stage 5!")                    -- numbers are kept: "Étape 5 !"
--
-- Add your own texts in ReplicatedStorage.GameKit.Config.Lang:
--   Translations = { fr = { ["Buy sword"] = "Acheter l'épée", ["Level {1}"] = "Niveau {1}" } }
-- {1}, {2}... stand for the numbers of the text, in order.
-- Also turn on Creator Dashboard > Localization > automatic translation for everything else.

local Players = game:GetService("Players")

local Util = require(script.Parent:WaitForChild("Util"))

local config = Util.config("Lang", {
	Enabled = true,
	Language = "auto",
	Translations = {},
})

local Lang = {}

-- English text -> { fr, es, pt, de }. Whole texts, templates with {n}, and phrases that are
-- replaced inside longer texts.
local BUILTIN: { [string]: { string } } = {
	["Shop"] = { "Boutique", "Tienda", "Loja", "Shop" },
	["Buy"] = { "Acheter", "Comprar", "Comprar", "Kaufen" },
	["Owned"] = { "Possédé", "Comprado", "Comprado", "Gekauft" },
	["Equip"] = { "Équiper", "Equipar", "Equipar", "Ausrüsten" },
	["Equipped"] = { "Équipé", "Equipado", "Equipado", "Ausgerüstet" },
	["Unequip"] = { "Retirer", "Quitar", "Remover", "Ablegen" },
	["Claim!"] = { "Récupérer !", "¡Reclamar!", "Resgatar!", "Abholen!" },
	["Daily reward"] = { "Récompense du jour", "Recompensa diaria", "Recompensa diária", "Tägliche Belohnung" },
	["Rebirth!"] = { "Renaissance !", "¡Renacer!", "Renascer!", "Wiedergeburt!" },
	["Rebirth"] = { "Renaissance", "Renacer", "Renascer", "Wiedergeburt" },
	["Train"] = { "S'entraîner", "Entrenar", "Treinar", "Trainieren" },
	["Sell"] = { "Vendre", "Vender", "Vender", "Verkaufen" },
	["Settings"] = { "Paramètres", "Ajustes", "Configurações", "Einstellungen" },
	["Close"] = { "Fermer", "Cerrar", "Fechar", "Schließen" },
	["Welcome!"] = { "Bienvenue !", "¡Bienvenido!", "Bem-vindo!", "Willkommen!" },
	["Harvest"] = { "Récolter", "Cosechar", "Colher", "Ernten" },
	["Plant"] = { "Planter", "Plantar", "Plantar", "Pflanzen" },
	["Build"] = { "Construire", "Construir", "Construir", "Bauen" },
	["Upgrade"] = { "Améliorer", "Mejorar", "Melhorar", "Verbessern" },
	["Ready!"] = { "Prêt !", "¡Listo!", "Pronto!", "Fertig!" },
	["Coins"] = { "Pièces", "Monedas", "Moedas", "Münzen" },
	["Cash"] = { "Argent", "Dinero", "Dinheiro", "Geld" },
	["Gems"] = { "Gemmes", "Gemas", "Gemas", "Edelsteine" },
	["Wins"] = { "Victoires", "Victorias", "Vitórias", "Siege" },
	["Stage"] = { "Étape", "Etapa", "Fase", "Stufe" },
	["Power"] = { "Puissance", "Poder", "Poder", "Kraft" },
	["Rebirths"] = { "Renaissances", "Renacimientos", "Renascimentos", "Wiedergeburten" },
	["Kills"] = { "Éliminations", "Bajas", "Abates", "Kills" },
	["Level"] = { "Niveau", "Nivel", "Nível", "Level" },
	["Keys"] = { "Clés", "Llaves", "Chaves", "Schlüssel" },
	["Wave"] = { "Vague", "Oleada", "Onda", "Welle" },
	["Basket"] = { "Panier", "Cesta", "Cesta", "Korb" },
	["Stage {1}!"] = { "Étape {1} !", "¡Etapa {1}!", "Fase {1}!", "Stufe {1}!" },
	["Wave {1} cleared!"] = { "Vague {1} terminée !", "¡Oleada {1} superada!", "Onda {1} concluída!", "Welle {1} geschafft!" },
	["Sold for"] = { "Vendu pour", "Vendido por", "Vendido por", "Verkauft für" },
	["You need"] = { "Il te faut", "Necesitas", "Você precisa de", "Du brauchst" },
	["Not enough"] = { "Pas assez de", "No tienes suficiente", "Não há", "Nicht genug" },
	["You finished!"] = { "Tu as fini !", "¡Terminaste!", "Você terminou!", "Geschafft!" },
	["Come back later for your next reward!"] = { "Reviens plus tard pour ta prochaine récompense !", "¡Vuelve más tarde por tu próxima recompensa!", "Volte mais tarde para a próxima recompensa!", "Komm später für deine nächste Belohnung wieder!" },
	["Backpack full! Go to a Sell pad."] = { "Sac plein ! Va sur une zone de vente.", "¡Mochila llena! Ve a una zona de venta.", "Mochila cheia! Vá até uma área de venda.", "Rucksack voll! Geh zu einem Verkaufsfeld." },
	["You won the round!"] = { "Tu as gagné la manche !", "¡Ganaste la ronda!", "Você venceu a rodada!", "Du hast die Runde gewonnen!" },
	["Victory! The base survived every wave!"] = { "Victoire ! La base a résisté à toutes les vagues !", "¡Victoria! ¡La base resistió todas las oleadas!", "Vitória! A base resistiu a todas as ondas!", "Sieg! Die Basis hat jede Welle überstanden!" },
	["The base was destroyed!"] = { "La base a été détruite !", "¡La base fue destruida!", "A base foi destruída!", "Die Basis wurde zerstört!" },
	["The exit is open!"] = { "La sortie est ouverte !", "¡La salida está abierta!", "A saída está aberta!", "Der Ausgang ist offen!" },
	["You escaped!"] = { "Tu t'es échappé !", "¡Escapaste!", "Você escapou!", "Du bist entkommen!" },
	["unlocked!"] = { "débloqué !", "¡desbloqueado!", "desbloqueado!", "freigeschaltet!" },
	["Your basket is empty: harvest crops first."] = { "Ton panier est vide : récolte d'abord.", "Tu cesta está vacía: cosecha primero.", "Sua cesta está vazia: colha primeiro.", "Dein Korb ist leer: erst ernten." },
	["Reach all {1} checkpoints first!"] = { "Atteins d'abord les {1} checkpoints !", "¡Primero alcanza los {1} puntos de control!", "Alcance os {1} checkpoints primeiro!", "Erreiche zuerst alle {1} Checkpoints!" },
}
local LANGUAGE_INDEX = { fr = 1, es = 2, pt = 3, de = 4 }

type Dictionary = { map: { [string]: string }, phrases: { string } }
local dictionaries: { [string]: Dictionary } = {}
local detected: string? = nil

-- Two-letter language of this player ("fr", "es"...). Config.Lang.Language forces one.
function Lang.language(): string
	local forced = config.Language
	if type(forced) == "string" and forced ~= "" and forced ~= "auto" then
		return string.lower(string.sub(forced, 1, 2))
	end
	if detected then
		return detected
	end
	local ok, locale = pcall(function()
		local player = Players.LocalPlayer
		if player then
			return game:GetService("LocalizationService").RobloxLocaleId
		end
		return "en-us"
	end)
	local language = if ok and type(locale) == "string" and #locale >= 2 then string.lower(string.sub(locale, 1, 2)) else "en"
	detected = language
	return language
end

local function dictionary(language: string): Dictionary
	local cached = dictionaries[language]
	if cached then
		return cached
	end
	local map: { [string]: string } = {}
	local index = LANGUAGE_INDEX[language]
	if index then
		for english, list in BUILTIN do
			map[english] = list[index]
		end
	end
	local custom = config.Translations[language]
	if type(custom) == "table" then
		for english, translated in custom do
			if type(english) == "string" and type(translated) == "string" then
				map[english] = translated
			end
		end
	end
	local phrases: { string } = {}
	for english in map do
		if #english >= 3 and not string.find(english, "{", 1, true) then
			table.insert(phrases, english)
		end
	end
	-- Longest first, so "Rebirths" wins over "Rebirth".
	table.sort(phrases, function(a, b)
		return #a > #b
	end)
	local result = { map = map, phrases = phrases }
	dictionaries[language] = result
	return result
end

local function escapePattern(text: string): string
	return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Translates `text` into `language` (default: the player's). Unknown texts come back unchanged.
function Lang.t(text: string, language: string?): string
	if not config.Enabled or type(text) ~= "string" or text == "" or not string.find(text, "%a") then
		return text
	end
	local lang = language or Lang.language()
	if lang == "en" then
		return text
	end
	local dict = dictionary(lang)
	if next(dict.map) == nil then
		return text
	end
	local exact = dict.map[text]
	if exact then
		return exact
	end
	-- Numbers become {1}, {2}... so "Stage 12!" matches "Stage {1}!".
	local numbers: { string } = {}
	local template = string.gsub(text, "%d[%d%.,]*%u?%l?", function(number)
		table.insert(numbers, number)
		return "{" .. #numbers .. "}"
	end)
	local templated = dict.map[template]
	if templated then
		return (string.gsub(templated, "{(%d+)}", function(i)
			return numbers[tonumber(i) or 0] or ""
		end))
	end
	-- Otherwise translate the known phrases inside the text.
	local out = text
	for _, phrase in dict.phrases do
		if string.find(out, phrase, 1, true) then
			-- Whole words only: "Plant" must not change "Planting".
			local pattern = escapePattern(phrase)
			if string.find(phrase, "^%w") then
				pattern = "%f[%w]" .. pattern
			end
			if string.find(phrase, "%w$") then
				pattern ..= "%f[%W]"
			end
			local replacement = string.gsub(dict.map[phrase], "%%", "%%%%")
			out = string.gsub(out, pattern, replacement)
		end
	end
	return out
end

return Lang
