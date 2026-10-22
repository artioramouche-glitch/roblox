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
	-- Inventory, levels, quests, pets
	["Inventory"] = { "Inventaire", "Inventario", "Inventário", "Inventar" },
	["Sell all"] = { "Tout vendre", "Vender todo", "Vender tudo", "Alles verkaufen" },
	["Nothing to sell."] = { "Rien à vendre.", "Nada que vender.", "Nada para vender.", "Nichts zu verkaufen." },
	["Your bag is full! Sell some items."] = { "Ton sac est plein ! Vends des objets.", "¡Tu bolsa está llena! Vende algunos objetos.", "Sua bolsa está cheia! Venda alguns itens.", "Deine Tasche ist voll! Verkaufe etwas." },
	["Quests"] = { "Quêtes", "Misiones", "Missões", "Quests" },
	["Pets"] = { "Familiers", "Mascotas", "Mascotes", "Haustiere" },
	["Equip best"] = { "Équiper les meilleurs", "Equipar los mejores", "Equipar os melhores", "Beste ausrüsten" },
	["Hatch"] = { "Faire éclore", "Eclosionar", "Chocar", "Ausbrüten" },
	["This egg costs"] = { "Cet œuf coûte", "Este huevo cuesta", "Este ovo custa", "Dieses Ei kostet" },
	["You can equip {1} pets."] = { "Tu peux équiper {1} familiers.", "Puedes equipar {1} mascotas.", "Você pode equipar {1} mascotes.", "Du kannst {1} Haustiere ausrüsten." },
	["Your pet storage is full ({1})."] = { "Tu as déjà {1} familiers, le maximum.", "Tu almacén de mascotas está lleno ({1}).", "Seu espaço de mascotes está cheio ({1}).", "Dein Haustier-Speicher ist voll ({1})." },
	["⭐ Level {1}!"] = { "⭐ Niveau {1} !", "⭐ ¡Nivel {1}!", "⭐ Nível {1}!", "⭐ Level {1}!" },
	["Common"] = { "Commun", "Común", "Comum", "Gewöhnlich" },
	["Rare"] = { "Rare", "Raro", "Raro", "Selten" },
	["Epic"] = { "Épique", "Épico", "Épico", "Episch" },
	["Legendary"] = { "Légendaire", "Legendario", "Lendário", "Legendär" },
	["Collect {1} coins"] = { "Ramasse {1} pièces", "Recoge {1} monedas", "Colete {1} moedas", "Sammle {1} Münzen" },
	["Reach level {1}"] = { "Atteins le niveau {1}", "Alcanza el nivel {1}", "Alcance o nível {1}", "Erreiche Level {1}" },
	-- Racing
	["Race"] = { "Course", "Carrera", "Corrida", "Rennen" },
	["Lap"] = { "Tour", "Vuelta", "Volta", "Runde" },
	["best"] = { "meilleur", "mejor", "melhor", "beste" },
	["Best lap"] = { "Meilleur tour", "Mejor vuelta", "Melhor volta", "Beste Runde" },
	["🏎 Next race in"] = { "🏎 Prochaine course dans", "🏎 Próxima carrera en", "🏎 Próxima corrida em", "🏎 Nächstes Rennen in" },
	["🟢 GO!"] = { "🟢 PARTEZ !", "🟢 ¡YA!", "🟢 JÁ!", "🟢 LOS!" },
	["Waiting for {1} racers..."] = { "En attente de {1} pilotes...", "Esperando a {1} corredores...", "Esperando {1} pilotos...", "Warte auf {1} Fahrer..." },
	["finished"] = { "arrivés", "terminaron", "terminaram", "im Ziel" },
	["wins!"] = { "gagne !", "gana.", "vence!", "gewinnt!" },
	["⌛ Time is up!"] = { "⌛ Temps écoulé !", "⌛ ¡Se acabó el tiempo!", "⌛ O tempo acabou!", "⌛ Die Zeit ist um!" },
	["🏁 Finished #{1} in {2}!"] = { "🏁 Arrivé {1}e en {2} !", "🏁 ¡Llegaste {1}º en {2}!", "🏁 Chegou em {1}º em {2}!", "🏁 Platz {1} in {2}!" },
	["Finish a race"] = { "Termine une course", "Termina una carrera", "Termine uma corrida", "Beende ein Rennen" },
	["Win a race"] = { "Gagne une course", "Gana una carrera", "Vença uma corrida", "Gewinne ein Rennen" },
	["Win {1} races"] = { "Gagne {1} courses", "Gana {1} carreras", "Vença {1} corridas", "Gewinne {1} Rennen" },
	-- Fishing
	["Fish"] = { "Poissons", "Peces", "Peixes", "Fische" },
	["🎣 REEL!"] = { "🎣 FERRER !", "🎣 ¡TIRA!", "🎣 PUXE!", "🎣 EINHOLEN!" },
	["Waiting for a bite...  ✕"] = { "En attente d'une touche...  ✕", "Esperando a que piquen...  ✕", "Esperando o peixe morder...  ✕", "Warte auf einen Biss...  ✕" },
	["Too early! Wait for the bobber to dip."] = { "Trop tôt ! Attends que le bouchon plonge.", "¡Demasiado pronto! Espera a que el corcho se hunda.", "Cedo demais! Espere a boia afundar.", "Zu früh! Warte, bis der Schwimmer abtaucht." },
	["The fish got away..."] = { "Le poisson s'est échappé...", "El pez se escapó...", "O peixe escapou...", "Der Fisch ist entwischt..." },
	["needs rod level"] = { "demande une canne niveau", "requiere caña de nivel", "exige vara nível", "braucht Angel-Level" },
	["yours"] = { "la tienne", "la tuya", "a sua", "deine" },
	["Minnow"] = { "Vairon", "Pececillo", "Lambari", "Elritze" },
	["Salmon"] = { "Saumon", "Salmón", "Salmão", "Lachs" },
	["Golden Koi"] = { "Koï doré", "Koi dorado", "Carpa dourada", "Goldener Koi" },
	["Pufferfish"] = { "Poisson-globe", "Pez globo", "Baiacu", "Kugelfisch" },
	["Tuna"] = { "Thon", "Atún", "Atum", "Thunfisch" },
	["Shark"] = { "Requin", "Tiburón", "Tubarão", "Hai" },
	["Pond"] = { "Étang", "Estanque", "Lago", "Teich" },
	["Ocean"] = { "Océan", "Océano", "Oceano", "Ozean" },
	["Catch a fish"] = { "Attrape un poisson", "Atrapa un pez", "Pesque um peixe", "Fange einen Fisch" },
	["Catch {1} fish"] = { "Attrape {1} poissons", "Atrapa {1} peces", "Pesque {1} peixes", "Fange {1} Fische" },
	["Sell fish for {1} coins"] = { "Vends des poissons pour {1} pièces", "Vende peces por {1} monedas", "Venda peixes por {1} moedas", "Verkaufe Fische für {1} Münzen" },
	["Buy a better rod"] = { "Achète une meilleure canne", "Compra una caña mejor", "Compre uma vara melhor", "Kauf eine bessere Angel" },
	["Catch a salmon"] = { "Attrape un saumon", "Atrapa un salmón", "Pesque um salmão", "Fange einen Lachs" },
	["Catch a shark"] = { "Attrape un requin", "Atrapa un tiburón", "Pesque um tubarão", "Fange einen Hai" },
	["Unlock the ocean (rod level {1})"] = { "Débloque l'océan (canne niveau {1})", "Desbloquea el océano (caña nivel {1})", "Desbloqueie o oceano (vara nível {1})", "Schalte den Ozean frei (Angel-Level {1})" },
	["Find the secret cove"] = { "Trouve la crique secrète", "Encuentra la cala secreta", "Encontre a enseada secreta", "Finde die geheime Bucht" },
	-- Crafting & survival
	["Crafting"] = { "Fabrication", "Fabricación", "Fabricação", "Herstellung" },
	["Craft"] = { "Fabriquer", "Fabricar", "Fabricar", "Herstellen" },
	["Eat"] = { "Manger", "Comer", "Comer", "Essen" },
	["food"] = { "nourriture", "comida", "comida", "Nahrung" },
	["Needs"] = { "Il faut", "Necesitas", "Precisa de", "Benötigt" },
	["Go to a crafting table 🔨"] = { "Va à un établi 🔨", "Ve a una mesa de trabajo 🔨", "Vá até uma bancada 🔨", "Geh zu einer Werkbank 🔨" },
	["You can place {1} builds."] = { "Tu peux poser {1} constructions.", "Puedes colocar {1} construcciones.", "Você pode colocar {1} construções.", "Du kannst {1} Bauten platzieren." },
	["Wood"] = { "Bois", "Madera", "Madeira", "Holz" },
	["Stone"] = { "Pierre", "Piedra", "Pedra", "Stein" },
	["Berry"] = { "Baie", "Baya", "Fruta silvestre", "Beere" },
	["Planks"] = { "Planches", "Tablones", "Tábuas", "Bretter" },
	["Stone Axe"] = { "Hache en pierre", "Hacha de piedra", "Machado de pedra", "Steinaxt" },
	["Stone Sword"] = { "Épée en pierre", "Espada de piedra", "Espada de pedra", "Steinschwert" },
	["Campfire"] = { "Feu de camp", "Fogata", "Fogueira", "Lagerfeuer" },
	["Wooden Wall"] = { "Mur en bois", "Muro de madera", "Parede de madeira", "Holzwand" },
	["Spikes"] = { "Pics", "Púas", "Espetos", "Stacheln" },
	["Bandage"] = { "Bandage", "Venda", "Curativo", "Verband" },
	["Chop {1} wood"] = { "Coupe {1} bois", "Corta {1} de madera", "Corte {1} de madeira", "Fälle {1} Holz" },
	["Mine {1} stone"] = { "Mine {1} pierres", "Pica {1} piedras", "Minere {1} pedras", "Baue {1} Steine ab" },
	["Craft planks"] = { "Fabrique des planches", "Fabrica tablones", "Fabrique tábuas", "Stelle Bretter her" },
	["Defeat {1} zombies"] = { "Élimine {1} zombies", "Derrota {1} zombis", "Derrote {1} zumbis", "Besiege {1} Zombies" },
	-- Codes & social
	["Codes"] = { "Codes", "Códigos", "Códigos", "Codes" },
	["Redeem"] = { "Utiliser", "Canjear", "Resgatar", "Einlösen" },
	["Enter a code"] = { "Entre un code", "Escribe un código", "Digite um código", "Code eingeben" },
	["Invalid code."] = { "Code invalide.", "Código no válido.", "Código inválido.", "Ungültiger Code." },
	["This code has expired."] = { "Ce code a expiré.", "Este código ha caducado.", "Este código expirou.", "Dieser Code ist abgelaufen." },
	["You already used this code."] = { "Tu as déjà utilisé ce code.", "Ya usaste este código.", "Você já usou este código.", "Du hast diesen Code schon benutzt." },
	["Please wait, your data is loading."] = { "Patiente, tes données se chargent.", "Espera, tus datos se están cargando.", "Aguarde, seus dados estão carregando.", "Bitte warten, deine Daten werden geladen." },
	["Reach level {1} to use this code."] = { "Atteins le niveau {1} pour utiliser ce code.", "Alcanza el nivel {1} para usar este código.", "Alcance o nível {1} para usar este código.", "Erreiche Level {1}, um diesen Code zu nutzen." },
	["Invite"] = { "Inviter", "Invitar", "Convidar", "Einladen" },
	["Invites are not available here (they work in the published game)."] = { "Les invitations ne marchent pas ici (elles marchent dans le jeu publié).", "Las invitaciones no funcionan aquí (funcionan en el juego publicado).", "Convites não funcionam aqui (funcionam no jogo publicado).", "Einladungen gehen hier nicht (sie gehen im veröffentlichten Spiel)." },
	["Thanks for inviting friends! 🎁"] = { "Merci d'inviter tes amis ! 🎁", "¡Gracias por invitar a tus amigos! 🎁", "Obrigado por convidar amigos! 🎁", "Danke fürs Einladen! 🎁" },
	["Thanks for joining the group! 🎁"] = { "Merci d'avoir rejoint le groupe ! 🎁", "¡Gracias por unirte al grupo! 🎁", "Obrigado por entrar no grupo! 🎁", "Danke, dass du der Gruppe beigetreten bist! 🎁" },
	["is your friend"] = { "est ton ami", "es tu amigo", "é seu amigo", "ist dein Freund" },
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
