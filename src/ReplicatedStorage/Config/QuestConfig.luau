--!strict
--[[ QuestConfig
     Rôle    : les 8 quêtes quotidiennes de C5 (objectif, compteur du profil qui les fait avancer, récompense),
               leur rythme, et les récompenses de la série de 7 jours.
     Doc     : GAME_MASTER_V2 C5, G1 (QuestConfig), G2 (Quests) ; PROMPT_EXECUTION_SABL_V4 §31.10 lots A et B ;
               décisions 57 (Q1, option A) et 58 (Q2, option A) ; Q1-Q3 du lot B (02/10, options A)
     Étape   : 10, lot A ; série de 7 jours au lot B (configuration seule)
     Dépend  : aucun
     Exposé  : configuration immuable ; Quests, Get(id), PerDay, DaySeconds, ArenaOpen, DayIndex(now), NextReset(now),
               Streak, StreakReward(day), StreakWorld, StreakNext(streak, lastClaim, now)
     Limite  : les deux quêtes PvP sont prêtes mais ne sont pas tirées avant le Colisée (ArenaOpen, étape 13) ;
               « Voler » et « Défendre » ne vont qu'aux joueurs que A4 ne protège plus (niveau 5 et 1 h de jeu).
               Counter est le chemin du compteur du profil ; « Stats.AbilitiesUsed » naîtra à l'étape 13.
               Série : le tirage de l'espèce (serveur) et la garde du spin de J7 (champ Quests.Spins, schéma v4)
               relèvent du service ; seule la règle des jours et ce qu'ils versent vivent ici.
]]
local QuestConfig = {}

QuestConfig.PerDay = 3 -- C5 : 3 quêtes par jour
QuestConfig.DaySeconds = 86400 -- C5 : reset à 00 h 00 UTC ; le jour se compte sur l'horloge UTC du serveur
QuestConfig.ArenaOpen = false -- §31.10 : les quêtes PvP existent dès maintenant, actives à l'étape 13

-- C5, dans l'ordre du document ; Money ou ArenaTokens : la récompense versée à la réclamation.
QuestConfig.Quests = table.freeze({
    table.freeze({Id = "clicks", Label = "Cliquer 200×", Counter = "Clicks", Target = 200, Money = 2500}),
    table.freeze({Id = "eggs", Label = "Ouvrir 5 œufs", Counter = "Stats.EggsOpened", Target = 5, Money = 10000}),
    table.freeze({Id = "fusions", Label = "Fusionner 3×", Counter = "Stats.Fusions", Target = 3, Money = 25000}),
    table.freeze({Id = "steal", Label = "Voler 1 brainrot", Counter = "Stats.Steals", Target = 1, Money = 50000,
        Steal = true}),
    table.freeze({Id = "defend", Label = "Défendre ta base 2×", Counter = "Stats.Defends", Target = 2, Money = 30000,
        Steal = true}),
    table.freeze({Id = "arena_win", Label = "Gagner 1 match d'arène", Counter = "Stats.ArenaWins", Target = 1,
        ArenaTokens = 40, Arena = true}),
    table.freeze({Id = "abilities", Label = "Utiliser 5 capacités PvP", Counter = "Stats.AbilitiesUsed", Target = 5,
        ArenaTokens = 25, Arena = true}),
    table.freeze({Id = "playtime", Label = "Passe 20 min en jeu", Counter = "Playtime", Target = 1200, Money = 100000}),
})

-- C5 « Streak quotidien 7 jours » et décision 58 : un clic par jour UTC valide le jour ; un jour manqué ramène à J1.
-- Une seule récompense par jour : Money, Egg (un œuf de EggConfig offert) ou Rarity (une créature garantie de cette
-- rareté) ; Spins : tours de roulette gardés pour l'étape 11.
QuestConfig.Streak = table.freeze({
    table.freeze({Money = 10000}), -- J1
    table.freeze({Money = 25000}), -- J2
    table.freeze({Money = 50000}), -- J3
    table.freeze({Egg = "egg_street"}), -- J4
    table.freeze({Egg = "egg_street"}), -- J5
    table.freeze({Rarity = "Epic"}), -- J6
    table.freeze({Rarity = "Rare", Spins = 1}), -- J7
})
QuestConfig.StreakWorld = 1 -- Q2 du lot B : l'Épique de J6 et le Rare de J7 sont tirés parmi les espèces du monde 1

local byId: {[string]: any} = {}
for _, quest in ipairs(QuestConfig.Quests) do byId[quest.Id] = quest end

function QuestConfig.Get(id: any): any
    return if type(id) == "string" then byId[id] else nil
end

-- Récompense du jour `day` de la série (1 à 7) ; nil pour tout autre numéro.
function QuestConfig.StreakReward(day: any): any
    return if type(day) == "number" then QuestConfig.Streak[day] else nil
end

-- Réclamation de la récompense du jour à l'instant `now`, d'après Quests.Streak (jours consécutifs réclamés) et
-- Quests.LastDailyClaim (os.time, 0 = jamais). Renvoie : réclamable ?, jour versé (1 à 7), nouvelle valeur de Streak.
-- Réclamé hier : jour suivant, et après J7 la série repart à J1 (Q1 du lot B). Jour manqué ou première fois : J1.
-- Déjà réclamé ce jour UTC : non réclamable, jour du jour et Streak inchangé.
function QuestConfig.StreakNext(streak: number, lastClaim: number, now: number): (boolean, number, number)
    local days = #QuestConfig.Streak
    local today = QuestConfig.DayIndex(now)
    if lastClaim > 0 then
        local lastDay = QuestConfig.DayIndex(lastClaim)
        if lastDay >= today then
            return false, (math.max(streak, 1) - 1) % days + 1, streak
        elseif lastDay == today - 1 then
            return true, streak % days + 1, streak + 1
        end
    end
    return true, 1, 1
end

-- Numéro du jour UTC d'un instant (secondes depuis 1970) ; deux instants du même jour ont le même numéro.
function QuestConfig.DayIndex(now: number): number
    return math.floor(now / QuestConfig.DaySeconds)
end

-- Prochain 00 h 00 UTC après `now`.
function QuestConfig.NextReset(now: number): number
    return (QuestConfig.DayIndex(now) + 1) * QuestConfig.DaySeconds
end

return table.freeze(QuestConfig)
