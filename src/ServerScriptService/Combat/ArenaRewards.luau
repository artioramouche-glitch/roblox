--!strict
--[[ ArenaRewards
     Rôle    : bilan d'un match pour un joueur : Elo (classé), tokens, série de défaites, stats de saison et
               compteurs ; d'abord calculé sans rien écrire, puis appliqué au profil.
     Doc     : GAME_MASTER_V2 G5.4, G5.5 (EndMatch), E1, E2, E6, E7, C7, G2 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot D ;
               décisions 125 à 127, 138 à 142
     Étape   : 13, lot D
     Dépend  : Shared.EloUtil (G5.4), Config.ArenaConfig (Tokens), Config.DefaultProfile (Elo de départ)
     Exposé  : Settle(profile, input) -> bilan | (nil, raison) ; Apply(profile, bilan).
               input = {Mode = "Ranked1v1" | "Ranked2v2" | "Free", Result = CombatEngine.Result(match),
               Side = siège ("A", "B", "A2", "B2"), OpponentElo = Elo adverse (moyenne du duo en 2v2),
               TeamElo = moyenne de son duo (2v2), Now = horloge en secondes}
     Limite  : Settle ne modifie rien ; Apply écrit dans le profil reçu (DataService, en session locale). Un match
               entre deux humains se solde deux fois, les deux Elo lus avant toute écriture. Les champs du schéma
               v4 (PvP.LossStreak, PvP.FreeTokens, Stats.AbilitiesUsed) se créent à la volée tant que la migration
               n'existe pas. En 2v2 (Q2 A), les deux partenaires bougent du même écart, calculé sur les moyennes ;
               qui quitte prend une défaite sans token, même si son partenaire gagne (Q3 A). Le 2v2 ne touche ni à
               la série de défaites ni à la saison, propres au classement 1v1.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = ReplicatedStorage:WaitForChild("Config")
local ArenaConfig = require(config:WaitForChild("ArenaConfig"))
local DefaultProfile = require(config:WaitForChild("DefaultProfile")) :: any
local EloUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EloUtil")) :: any

local TOKENS = ArenaConfig.Tokens
local START_ELO, START_ELO2 = DefaultProfile.PvP.Elo1v1, DefaultProfile.PvP.Elo2v2 -- E6 : Elo de départ

local ArenaRewards = {}

function ArenaRewards.Settle(profile: any, input: any): (any, string?)
    if type(profile) ~= "table" or type(profile.PvP) ~= "table" or type(input) ~= "table" then
        return nil, "BAD_INPUT"
    end
    local mode, result, side, now = input.Mode, input.Result, input.Side, input.Now
    local ranked, duo = mode == "Ranked1v1", mode == "Ranked2v2"
    if not ranked and not duo and mode ~= "Free" then return nil, "BAD_INPUT" end
    if type(result) ~= "table" or result.Over ~= true or type(result.Seconds) ~= "number" then
        return nil, "BAD_INPUT"
    end
    if type(side) ~= "string" or type(result[side]) ~= "table" or type(now) ~= "number" then
        return nil, "BAD_INPUT"
    end
    if (ranked or duo) and type(input.OpponentElo) ~= "number" then return nil, "BAD_INPUT" end
    if duo and type(input.TeamElo) ~= "number" then return nil, "BAD_INPUT" end
    local pvp, mine = profile.PvP, result[side]
    local camp, left = mine.Camp or side, mine.Left == true
    local score = if left then 0 elseif result.Winner == camp then 1 elseif result.Winner == "Draw" then 0.5 else 0
    local forfeited = left or (result.Reason == "Forfeit" and score == 0)
    -- E2 / C7 : 25 (35 en 2v2) victoire, 8 (12) défaite ou nul, +2 par minute pleine ; abandon = 0 token.
    local rates = if duo then TOKENS.Ranked2v2 else TOKENS.Ranked1v1
    local tokens = if forfeited then rates.Forfeit
        else (if score == 1 then rates.Win else rates.Loss) + TOKENS.PerMinutePlayed * math.floor(result.Seconds / 60)
    local summary: any = {
        Mode = mode, Score = score, Forfeited = forfeited, Seconds = result.Seconds, Tokens = tokens,
        Abilities = result[side].Abilities or 0, Ultimates = result[side].Ultimates or 0,
    }
    if ranked then
        -- G5.4 / E6 : K = 32, FIDE ; Elo gardé à l'unité, comme il s'affiche.
        local before = pvp.Elo1v1 or START_ELO
        summary.EloBefore = before
        summary.EloAfter = math.round((EloUtil.Calculate(before, input.OpponentElo, score)))
        local streak = pvp.LossStreak or 0
        summary.LossStreak = if score == 1 then 0 elseif score == 0 then streak + 1 else streak
    elseif duo then
        -- Q2 (A) : écart calculé sur les moyennes des deux duos, le même pour les deux partenaires.
        local before = pvp.Elo2v2 or START_ELO2
        local delta = EloUtil.Calculate(input.TeamElo, input.OpponentElo, score) - input.TeamElo
        summary.EloBefore, summary.EloAfter = before, math.round(before + delta)
    else
        -- E2 : Arène Libre, sans Elo, 5 tokens au plus par tranche de 15 min ouverte au premier gain.
        local window = if type(pvp.FreeTokens) == "table" then pvp.FreeTokens else {WindowStart = 0, Earned = 0}
        local start, earned = window.WindowStart or 0, window.Earned or 0
        if now - start >= TOKENS.FreeArenaWindow then start, earned = now, 0 end
        local grant = math.min(tokens, math.max(0, TOKENS.FreeArenaMax - earned))
        summary.Tokens, summary.FreeWindowStart, summary.FreeEarned = grant, start, earned + grant
    end
    return summary, nil
end

function ArenaRewards.Apply(profile: any, summary: any)
    local pvp, stats = profile.PvP, profile.Stats
    pvp.ArenaTokens = (pvp.ArenaTokens or 0) + summary.Tokens
    if summary.Score == 1 then
        stats.ArenaWins = (stats.ArenaWins or 0) + 1
    elseif summary.Score == 0 then
        stats.ArenaLosses = (stats.ArenaLosses or 0) + 1
    end
    stats.AbilitiesUsed = (stats.AbilitiesUsed or 0) + summary.Abilities -- quête « 5 capacités » (C5, dette 23)
    if summary.Mode == "Ranked1v1" then
        pvp.Elo1v1, pvp.LossStreak = summary.EloAfter, summary.LossStreak
        local season = pvp.Season
        if summary.Score == 1 then
            season.Wins += 1
        elseif summary.Score == 0 then
            season.Losses += 1
        end
        season.PeakElo = math.max(season.PeakElo, summary.EloAfter)
        season.UltimatesUsed += summary.Ultimates
        local _, rank = EloUtil.GetRank(summary.EloAfter)
        season.BestRank = math.max(season.BestRank, rank)
    elseif summary.Mode == "Ranked2v2" then
        pvp.Elo2v2 = summary.EloAfter
    else
        pvp.FreeTokens = {WindowStart = summary.FreeWindowStart, Earned = summary.FreeEarned}
    end
end

return table.freeze(ArenaRewards)
