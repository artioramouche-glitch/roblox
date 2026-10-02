--!strict
--[[ ClanConfig
     Rôle    : chiffres et règles des clans (Crews) et de la guerre de territoire : création, rôles, coffre et perks,
               3 fronts, calendrier, récompenses, anti-abus.
     Doc     : GAME_MASTER_V2 F1, F2, F3, F4, C2, C4, G4 (CreateClan … ReportWarFlag) ; PROMPT_EXECUTION_SABL_V4 §31.15 ;
               Q1-Q3 de l'étape 15 (02/10 : A, A, A) et lectures déclarées (calendrier, membre actif, drapeaux)
     Étape   : 15 (configuration seule)
     Dépend  : Shared/ParisTime (calendrier de la guerre à l'heure de Paris)
     Exposé  : configuration immuable ; Creation, MaxMembers, Roles, ChestLevels, War, AntiAbuse ;
               ChestLevel(donated), ChestBonus(donated), ValidName(name), ValidTag(tag), WarAt(now), WarBossAt(now),
               ArenaFrontPoints(wins, losses), StealFrontPoints(flags), BossFrontPoints(damageA, damageB),
               CanScore(front, warPlaySeconds), Winner(pointsA, pointsB)
     Limite  : module absent de G1, comme EconomyConfig ; écart déclaré. Le nom de clan passe en plus par le filtre
               TextService côté serveur (§24) : ValidName ne contrôle que la longueur. Q2 : le front Arène plafonne à
               375 points (5 × 75) malgré l'étiquette « 500 max » de F3.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ParisTime = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ParisTime"))

local ClanConfig = {}

local HOUR, DAY = 3600, 86400

-- F1 : création 500 000 💰, nom 3-16 caractères, tag 2-4 lettres, 20 emblèmes, 20 membres.
ClanConfig.Creation = table.freeze({Cost = 500000, NameMin = 3, NameMax = 16, TagMin = 2, TagMax = 4, Emblems = 20})
ClanConfig.MaxMembers = 20
-- F1 : Chef unique et transférable ; 3 officiers (déclarent la guerre, acceptent les membres) ; membres.
ClanConfig.Roles = table.freeze({
    Leader = table.freeze({Max = 1, Transferable = true, CanDeclareWar = true, CanAccept = true}),
    Officer = table.freeze({Max = 3, CanDeclareWar = true, CanAccept = true}),
    Member = table.freeze({}),
})

-- F2 (Q1, option A) : dons cumulés → niveau du coffre, perk de revenus pour tous les membres, couleur du tag.
-- Les dons ne sont jamais remboursés. Sans niveau, tag blanc (cosmétique, déclaré).
ClanConfig.ChestLevels = table.freeze({
    table.freeze({Level = 1, Donated = 500e3, IncomeBonus = 0.03, TagColor = "Gris"}),
    table.freeze({Level = 2, Donated = 5e6, IncomeBonus = 0.06, TagColor = "Bleu"}),
    table.freeze({Level = 3, Donated = 50e6, IncomeBonus = 0.10, TagColor = "Doré", Aura = true}),
    table.freeze({Level = 4, Donated = 500e6, IncomeBonus = 0.15, TagColor = "Violet", Emote = true}),
    table.freeze({Level = 5, Donated = 5e9, IncomeBonus = 0.18, TagColor = "ArcEnCiel", ColiseumBanner = true}),
})
ClanConfig.NoLevelTagColor = "Blanc"

-- F3 : guerre du dimanche 20:00 au jeudi 20:00, heure de Paris (lecture déclarée : les « 4 jours » de C4 et les
-- « résultats jeudi 20h » de F3).
ClanConfig.War = table.freeze({
    Weekday = 0, StartAt = 20 * HOUR, Duration = 4 * DAY,
    -- Front 1 : 5 duels, victoire 75, défaite 15 ; sessions le mardi et le jeudi à 18:00 (Q2 : 375 points au plus).
    Arena = table.freeze({Duels = 5, Win = 75, Loss = 15, Sessions = table.freeze({
        table.freeze({Weekday = 2, At = 18 * HOUR}), table.freeze({Weekday = 4, At = 18 * HOUR}),
    })}),
    -- Front 2 : 50 points par drapeau rapporté, 500 au plus (10 drapeaux).
    Steal = table.freeze({PerFlag = 50, Max = 500}),
    -- Front 3 (Q3, option A) : pas de PV ; « ×10 » sur la durée du Boss du serveur (5 min → 50 min), mardi 20:00 ;
    -- les 500 points se partagent selon les dégâts cumulés de chaque clan.
    Boss = table.freeze({Weekday = 2, StartAt = 20 * HOUR, Duration = 50 * 60, Points = 500}),
    -- F3 : récompenses du jeudi 20:00 ; l'œuf ne va qu'aux membres qui ont marqué au moins 1 point. Égalité : les
    -- deux clans reçoivent les récompenses du gagnant (déclaré).
    Rewards = table.freeze({
        Winner = table.freeze({ArenaTokens = 400, Money = 250000, ScorerEggs = table.freeze({egg_mythic = 1})}),
        Loser = table.freeze({ArenaTokens = 100, Money = 50000}),
        MvpPoseDays = 7, TieGivesWinner = true,
    }),
})

-- F4 : anti-abus. Membre actif = connecté dans les 7 derniers jours (lecture déclarée).
ClanConfig.AntiAbuse = table.freeze({
    MaxActiveWars = 1, CooldownAfterWar = 24 * HOUR, MinWarPlayToScore = 30 * 60,
    PlayRequiredFronts = table.freeze({Arena = true, Steal = true}), -- F4 : seulement les 2 premiers fronts
    MinActiveMembers = 5, ActiveWindow = 7 * DAY, MergeAllowed = false,
})

local levels: {any} = ClanConfig.ChestLevels :: any

-- Niveau du coffre (0 à 5) pour un total de dons.
function ClanConfig.ChestLevel(donated: any): number
    local level = 0
    if type(donated) ~= "number" or donated ~= donated then return level end
    for _, entry in ipairs(levels) do
        if donated >= entry.Donated then level = entry.Level end
    end
    return level
end

-- Perk de revenus (F2) pour un total de dons ; 0 sans niveau.
function ClanConfig.ChestBonus(donated: any): number
    local level = ClanConfig.ChestLevel(donated)
    return if level > 0 then levels[level].IncomeBonus else 0
end

-- Longueur du nom (en caractères, accents compris) ; le filtre TextService reste obligatoire côté serveur.
function ClanConfig.ValidName(name: any): boolean
    if type(name) ~= "string" then return false end
    local length = utf8.len(name)
    local c = ClanConfig.Creation
    return length ~= nil and length >= c.NameMin and length <= c.NameMax
end

-- Tag de 2 à 4 lettres latines sans accent (affiché en majuscules).
function ClanConfig.ValidTag(tag: any): boolean
    local c = ClanConfig.Creation
    return type(tag) == "string" and #tag >= c.TagMin and #tag <= c.TagMax and string.match(tag, "^%a+$") ~= nil
end

-- Guerre en cours ou prochaine : active ?, début et fin UTC.
function ClanConfig.WarAt(now: number): (boolean, number, number)
    local w = ClanConfig.War
    return ParisTime.Weekly(now, w.Weekday, w.StartAt, w.Duration)
end

-- Boss de guerre (front 3) en cours ou prochain : active ?, début et fin UTC.
function ClanConfig.WarBossAt(now: number): (boolean, number, number)
    local b = ClanConfig.War.Boss
    return ParisTime.Weekly(now, b.Weekday, b.StartAt, b.Duration)
end

-- Front 1 : points des duels joués ; nil si les nombres sont invalides ou dépassent les 5 duels.
function ClanConfig.ArenaFrontPoints(wins: any, losses: any): number?
    local a = ClanConfig.War.Arena
    if type(wins) ~= "number" or type(losses) ~= "number" or wins < 0 or losses < 0 or wins % 1 ~= 0
        or losses % 1 ~= 0 or wins + losses > a.Duels then
        return nil
    end
    return wins * a.Win + losses * a.Loss
end

-- Front 2 : 50 points par drapeau, 500 au plus.
function ClanConfig.StealFrontPoints(flags: any): number
    local s = ClanConfig.War.Steal
    if type(flags) ~= "number" or not (flags > 0) then return 0 end
    return math.min(math.floor(flags) * s.PerFlag, s.Max)
end

-- Front 3 : partage des 500 points selon les dégâts cumulés (arrondi au point, total toujours 500 ; 0-0 sans dégâts).
function ClanConfig.BossFrontPoints(damageA: any, damageB: any): (number, number)
    local a = if type(damageA) == "number" and damageA > 0 and damageA < math.huge then damageA else 0
    local b = if type(damageB) == "number" and damageB > 0 and damageB < math.huge then damageB else 0
    if a + b == 0 then return 0, 0 end
    local points = ClanConfig.War.Boss.Points
    local share = math.floor(points * a / (a + b) + 0.5)
    return share, points - share
end

-- F4 : un joueur ne marque sur les fronts Arène et Vol qu'après 30 min de jeu pendant la guerre.
local playRequired: {[string]: boolean} = ClanConfig.AntiAbuse.PlayRequiredFronts :: any
function ClanConfig.CanScore(front: any, warPlaySeconds: any): boolean
    if front == "Boss" then return true end
    if type(front) ~= "string" or not playRequired[front] then return false end
    return type(warPlaySeconds) == "number" and warPlaySeconds >= ClanConfig.AntiAbuse.MinWarPlayToScore
end

-- Issue de la guerre : "A", "B" ou "Tie".
function ClanConfig.Winner(pointsA: number, pointsB: number): string
    return if pointsA > pointsB then "A" elseif pointsB > pointsA then "B" else "Tie"
end

return table.freeze(ClanConfig)
