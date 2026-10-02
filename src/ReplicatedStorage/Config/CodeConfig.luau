--!strict
--[[ CodeConfig
     Rôle    : codes de lancement (I3) et règle de leur utilisation : valides, une seule fois par compte.
     Doc     : GAME_MASTER_V2 I3, G4 (RedeemCode), G2 (Codes) ; PROMPT_EXECUTION_SABL_V4 §18.2, §18.3, §18.4,
               §31.18 lot C ; décisions 64, 77, 79 et 112
     Étape   : 18, lot C (configuration seule)
     Dépend  : aucun
     Exposé  : configuration immuable ; Codes, MaxLength ; Normalize(input), Get(input), Check(used, input) → ok, code
               ou motif (CODE_INVALID, CODE_USED)
     Limite  : module absent de G1, comme EconomyConfig ; écart déclaré. Saisie sans casse ni espaces autour,
               32 caractères au plus ; pas d'expiration. Profile.Codes (G2) garde le code normalisé de chaque code
               utilisé ; le versement passe par le service (Loi 2).
]]
local CodeConfig = {}

-- I3, dans l'ordre du document.
CodeConfig.Codes = table.freeze({
    RELEASE = table.freeze({Money = 10000}),
    TUNGXTUNG = table.freeze({Eggs = table.freeze({egg_street = 1})}),
    -- Même boost « revenus ×2 » que la roulette (MonetizationConfig.Boosts.Income) : un 2e boost prolonge (décision 77).
    LEGENDS = table.freeze({Boost = "Income", Seconds = 30 * 60}),
    COLISEE = table.freeze({ArenaTokens = 150}),
    -- Rare tiré dans le monde 1 (décisions 64 et 79) ; pose de clan cosmétique pendant 24 h, avec ou sans clan.
    FAMILY = table.freeze({Rarity = "Rare", World = 1, ClanPoseSeconds = 24 * 3600}),
})

CodeConfig.MaxLength = 32 -- §18.4 : une saisie géante est refusée sans être traitée

local codes: {[string]: any} = CodeConfig.Codes :: any

-- Code saisi, sans espaces autour et en majuscules ; nil pour une saisie vide, trop longue ou qui n'est pas un texte.
function CodeConfig.Normalize(input: any): string?
    if type(input) ~= "string" or #input > CodeConfig.MaxLength * 4 then return nil end
    local trimmed = string.match(input, "^%s*(.-)%s*$") or ""
    if trimmed == "" or #trimmed > CodeConfig.MaxLength then return nil end
    return string.upper(trimmed)
end

-- Récompense d'un code saisi, nil s'il n'existe pas.
function CodeConfig.Get(input: any): any
    local code = CodeConfig.Normalize(input)
    return if code then codes[code] else nil
end

-- §18.2 : code valide (I3) → jamais utilisé par ce compte. `used` = Profile.Codes (code normalisé → date).
-- Renvoie true et le code normalisé, ou false et CODE_INVALID / CODE_USED (§18.3).
function CodeConfig.Check(used: any, input: any): (boolean, string)
    local code = CodeConfig.Normalize(input)
    if not code or codes[code] == nil then return false, "CODE_INVALID" end
    if type(used) == "table" and used[code] ~= nil then return false, "CODE_USED" end
    return true, code
end

return table.freeze(CodeConfig)
