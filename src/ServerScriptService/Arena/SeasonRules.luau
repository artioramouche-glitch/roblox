--!strict
--[[ SeasonRules
     Rôle    : clôture d'une saison mensuelle pour un joueur : reset souple de ses deux Elo, récompense du meilleur
               rang atteint, compteurs de la nouvelle saison ; calculée sans rien écrire, puis appliquée au profil.
     Doc     : GAME_MASTER_V2 E6, E7, G5.4, G2 ; PROMPT_EXECUTION_SABL_V4 §31.14 lot C ; décisions 95, 96, 131, 132
     Étape   : 14, lot C
     Dépend  : Shared.EloUtil (G5.4), Config.ArenaConfig (SeasonAt, SeasonRewards, RewardWorld)
     Exposé  : Close(profile, now, champion) -> bilan | (nil, raison) ; Apply(profile, bilan)
     Limite  : le service l'appelle à la connexion, et pour les présents au changement de mois. Le champion (top 1)
               est désigné par le service d'après le classement de tous les serveurs (lot F, session locale), qui
               pose aussi la statue. Œufs et God se livrent par EggService (bilan.Deliver) ; skin et titre sont
               écrits par Apply. Champs du schéma v4 créés à la volée : PvP.Cosmetics, PvP.SeasonTitle.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ArenaConfig"))
local EloUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EloUtil")) :: any

-- Les saisons datées commencent au premier mois représentable ; l'Id 1 du profil neuf (G2) n'est pas daté.
local FIRST_SEASON = ArenaConfig.SeasonAt(0)

local SeasonRules = {}

local function softReset(elo: number, seasons: number): number
    for _ = 1, seasons do elo = EloUtil.SoftReset(elo) end
    return math.round(elo)
end

-- G5.4 / E7 : une saison se clôt une fois ; chaque saison écoulée rapproche l'Elo de 1200 (reset souple), la
-- récompense ne vient que de la saison jouée (décision 96 : celle du meilleur rang atteint, rien sous Or). Une
-- saison jamais datée (profil neuf, Id 1 de G2) est seulement datée : ni reset, ni récompense, Elo de départ
-- gardé.
function SeasonRules.Close(profile: any, now: number, champion: boolean?): (any, string?)
    local pvp = type(profile) == "table" and profile.PvP or nil
    if type(pvp) ~= "table" or type(pvp.Season) ~= "table" or type(now) ~= "number" then return nil, "BAD_INPUT" end
    local current, _, finish = ArenaConfig.SeasonAt(now)
    local season = pvp.Season
    if season.Id == current then return nil, "SEASON_CURRENT" end
    local dated = type(season.Id) == "number" and season.Id >= FIRST_SEASON
    if dated and season.Id > current then return nil, "BAD_SEASON" end
    local elapsed = if dated then current - season.Id else 0
    local played = dated and (season.Wins or 0) + (season.Losses or 0) > 0
    local tier = nil
    if champion and played then
        tier = "BrainrotGod"
    elseif played then
        tier = (EloUtil.GetRank(season.PeakElo or 0))
    end
    local reward = if tier then ArenaConfig.SeasonRewards[tier] else nil
    local elo1, elo2 = pvp.Elo1v1 or 0, pvp.Elo2v2 or 0
    local after1 = softReset(elo1, elapsed)
    local _, rank = EloUtil.GetRank(after1)
    local deliver: any = {}
    if reward then
        if reward.Eggs then deliver.Eggs = reward.Eggs end
        if reward.Rarity then deliver.Rarity, deliver.World = reward.Rarity, ArenaConfig.RewardWorld end
        if reward.Statue then deliver.Statue = true end
    end
    return {
        OldId = season.Id, NewId = current, Elapsed = elapsed, Played = played, Tier = if reward then tier else nil,
        Elo1v1Before = elo1, Elo1v1After = after1, Elo2v2Before = elo2, Elo2v2After = softReset(elo2, elapsed),
        Skin = reward and reward.Skin or nil,
        Title = if reward and reward.Title then {Name = reward.Title, Until = finish} else nil,
        Deliver = deliver,
        Season = if dated
            then {Id = current, PeakElo = after1, Wins = 0, Losses = 0, UltimatesUsed = 0, BestRank = rank}
            else {Id = current, PeakElo = season.PeakElo, Wins = season.Wins, Losses = season.Losses,
                UltimatesUsed = season.UltimatesUsed, BestRank = season.BestRank},
    }, nil
end

function SeasonRules.Apply(profile: any, summary: any)
    local pvp = profile.PvP
    pvp.Elo1v1, pvp.Elo2v2 = summary.Elo1v1After, summary.Elo2v2After
    local s = summary.Season
    pvp.Season = {Id = s.Id, PeakElo = s.PeakElo, Wins = s.Wins, Losses = s.Losses, UltimatesUsed = s.UltimatesUsed,
        BestRank = s.BestRank}
    if summary.Skin then
        pvp.Cosmetics = pvp.Cosmetics or {}
        pvp.Cosmetics[summary.Skin] = true
    end
    if summary.Title then pvp.SeasonTitle = {Name = summary.Title.Name, Until = summary.Title.Until} end
end

return table.freeze(SeasonRules)
