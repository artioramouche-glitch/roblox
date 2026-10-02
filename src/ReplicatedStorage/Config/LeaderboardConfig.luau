--!strict
--[[ LeaderboardConfig
     Rôle    : les 2 classements du hub (revenus, vols), leur taille, leur rythme et l'encodage des scores pour le
               classement trié de Roblox (OrderedDataStore).
     Doc     : GAME_MASTER_V2 D1.3 Z1 (« 2 leaderboards : revenus, vols »), G1 (LeaderboardService) ;
               PROMPT_EXECUTION_SABL_V4 §31.12 lot B ; Q3 de l'étape 12 (02/10, option A)
     Étape   : 12, lot B (configuration seule)
     Dépend  : aucun
     Exposé  : configuration immuable ; Boards, Rows, RefreshSeconds, LogScale ; Get(key), Encode(board, value),
               Decode(board, code)
     Limite  : module absent de G1, comme EconomyConfig ; écart déclaré. OrderedDataStore n'accepte que des entiers
               sur 64 bits ; Stats.Earned peut dépasser 10^19 dans les mondes 3 et 4 : son score est encodé en
               logarithme (ordre conservé, égalités possibles au-delà de 10^13 ; décodé à 10^-12 près pour
               l'affichage). Le nom du magasin suit celui de DataConfig (test ou production), côté serveur.
]]
local LeaderboardConfig = {}

-- Q3 (option A) : totaux qui ne font que monter et survivent aux rebirths (décision 32).
LeaderboardConfig.Boards = table.freeze({
    table.freeze({Key = "Earned", Label = "Revenus", Stat = "Stats.Earned", Log = true}),
    table.freeze({Key = "Steals", Label = "Vols", Stat = "Stats.Steals", Log = false}),
})
LeaderboardConfig.Rows = 10 -- Q3 : 10 lignes par panneau
LeaderboardConfig.RefreshSeconds = 60 -- Q3 : écriture et relecture toutes les 60 s
LeaderboardConfig.LogScale = 1e13 -- ln(valeur) × 10^13 reste sous 2^53 jusqu'au plus grand nombre Luau

local boards: {any} = LeaderboardConfig.Boards

function LeaderboardConfig.Get(key: any): any
    for _, board in ipairs(boards) do
        if board.Key == key then return board end
    end
    return nil
end

-- Score entier ≥ 0 à écrire ; 0 pour une valeur nulle, négative ou non finie.
function LeaderboardConfig.Encode(board: any, value: any): number
    if type(value) ~= "number" or not (value > 0) or value == math.huge then return 0 end
    if board.Log then return math.floor(math.log(value + 1) * LeaderboardConfig.LogScale) end
    return math.floor(value)
end

-- Valeur affichable d'un score lu dans le classement.
function LeaderboardConfig.Decode(board: any, code: number): number
    if board.Log then return math.exp(code / LeaderboardConfig.LogScale) - 1 end
    return code
end

return table.freeze(LeaderboardConfig)
