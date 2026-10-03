--!strict
--[[ ArenaRewards
     Rôle    : bilan d'un match pour un joueur : Elo (classé), tokens, série de défaites, stats de saison et
               compteurs ; d'abord calculé sans rien écrire, puis appliqué au profil.
     Doc     : GAME_MASTER_V2 G5.4, G5.5 (EndMatch), E1, E2, E6, E7, C7, G2 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot D ;
               décisions 125 à 127
     Étape   : 13, lot D
     Dépend  : Shared.EloUtil (G5.4), Config.ArenaConfig (Tokens), Config.DefaultProfile (Elo de départ)
     Exposé  : Settle(profile, input) -> bilan | (nil, raison) ; Apply(profile, bilan).
               input = {Mode = "Ranked1v1" | "Free", Result = CombatEngine.Result(match), Side = "A" | "B",
               OpponentElo = nombre (classé), Now = horloge en secondes}
     Limite  : Settle ne modifie rien ; Apply écrit dans le profil reçu (DataService, en session locale). Un match
               entre deux humains se solde deux fois, les deux Elo lus avant toute écriture. Les champs du schéma
               v4 (PvP.LossStreak, PvP.FreeTokens, Stats.AbilitiesUsed) se créent à la volée tant que la migration
               n'existe pas. Le 2v2 attend son lot (décision 126).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = ReplicatedStorage:WaitForChild("Config")
local ArenaConfig = require(config:WaitForChild("ArenaConfig"))
local DefaultProfile = require(config:WaitForChild("DefaultProfile")) :: any
local EloUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EloUtil")) :: any

local TOKENS = ArenaConfig.Tokens
local START_ELO = DefaultProfile.PvP.Elo1v1 -- E6 : Elo de départ

local ArenaRewards = {}

function ArenaRewards.Settle(profile: any, input: any): (any, string?)
    if type(profile) ~= "table" or type(profile.PvP) ~= "table" or type(input) ~= "table" then
        return nil, "BAD_INPUT"
    end
    local mode, result, side, now = input.Mode, input.Result, input.Side, input.Now
    local ranked = mode == "Ranked1v1"
    if not ranked and mode ~= "Free" then return nil, "BAD_INPUT" end
    if type(result) ~= "table" or result.Over ~= true or type(result.Seconds) ~= "number" then
        return nil, "BAD_INPUT"
    end
    if (side ~= "A" and side ~= "B") or type(result[side]) ~= "table" or type(now) ~= "number" then
        return nil, "BAD_INPUT"
    end
    if ranked and type(input.OpponentElo) ~= "number" then return nil, "BAD_INPUT" end
    local pvp = profile.PvP
    local score = if result.Winner == side then 1 elseif result.Winner == "Draw" then 0.5 else 0
    local forfeited = result.Reason == "Forfeit" and score == 0
    -- E2 / C7 : 25 victoire, 8 défaite ou nul, +2 par minute pleine ; Q3 (A) : abandon = 0 token.
    local tokens = if forfeited then TOKENS.Ranked1v1.Forfeit
        else (if score == 1 then TOKENS.Ranked1v1.Win else TOKENS.Ranked1v1.Loss)
            + TOKENS.PerMinutePlayed * math.floor(result.Seconds / 60)
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
    else
        pvp.FreeTokens = {WindowStart = summary.FreeWindowStart, Earned = summary.FreeEarned}
    end
end

return table.freeze(ArenaRewards)
