--!strict
--[[ RemoteConfig
     Rôle    : centraliser la limite des requêtes entrantes.
     Doc     : GAME_MASTER_V2 G3 ; PROMPT_EXECUTION_SABL_V4 §16.5
     Étape   : 2, lot C2
     Dépend  : aucun
     Exposé  : configuration immuable ; aucune sanction automatique
]]
return table.freeze({
    MaxRequestsPerWindow = 10,
    WindowSeconds = 1,
})
