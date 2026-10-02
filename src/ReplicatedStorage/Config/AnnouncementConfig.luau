--!strict
--[[ AnnouncementConfig
     Rôle    : annonces faites à tout le serveur (Secret obtenu, vol réussi) et contenu du Musée des Secrets.
     Doc     : GAME_MASTER_V2 A2, A7 (spawn SECRET), D1.3 Z5 (Musée), G1 (AnnouncementService) ;
               PROMPT_EXECUTION_SABL_V4 §31.12 lots A et D ; Q4-Q5 de l'étape 12 (02/10, A et A)
     Étape   : 12, lots A et D (configuration seule)
     Dépend  : aucun
     Exposé  : configuration immuable ; Kinds, MuseumSlots ; Format(kind, fields) → texte ; MuseumPush(list, entry)
     Limite  : module absent de G1, comme EconomyConfig ; écart déclaré. Les textes (FR, décision 2) sont
               cosmétiques et déclarés. Un Secret « obtenu » sort d'un œuf : le Boss donne un egg_mythic (sans
               Secret) et la roulette jamais (C6). Les victoires d'arène s'ajouteront à l'étape 13.
]]
local AnnouncementConfig = {}

-- Q4 (option A) : seuls les Secrets et les vols réussis sont annoncés à tout le serveur.
AnnouncementConfig.Kinds = table.freeze({
    -- A7 : silence 1 s → sting orchestral + secousse d'écran pour tout le serveur, audible partout.
    Secret = table.freeze({Banner = "Big", SilenceSeconds = 1, Sting = true, ScreenShake = true,
        Template = "🌟 {player} a obtenu un SECRET : {creature} !"}),
    -- §31.12 lot A : vol réussi (pose sécurisée A4) ; bandeau simple, sans son ni secousse.
    Steal = table.freeze({Banner = "Small", SilenceSeconds = 0, Sting = false, ScreenShake = false,
        Template = "{thief} a volé {creature} à {victim} !"}),
})

-- D1.3 Z5 : 6 socles. Q5 (option A) : les 6 derniers Secrets obtenus sur ce serveur depuis son ouverture.
AnnouncementConfig.MuseumSlots = 6

local kinds: {[string]: any} = AnnouncementConfig.Kinds :: any

-- Texte d'une annonce : chaque {champ} du modèle est remplacé par fields[champ], « ? » s'il manque. Les valeurs
-- sont insérées telles quelles (un « % » ou des accolades dans un pseudo ne sont jamais interprétés).
function AnnouncementConfig.Format(kind: any, fields: any): string?
    local entry = if type(kind) == "string" then kinds[kind] else nil
    if not entry then return nil end
    local values = if type(fields) == "table" then fields else {}
    local text = string.gsub(entry.Template, "{(%a+)}", function(key: string): string
        local value = values[key]
        return if type(value) == "string" then value else "?"
    end)
    return text
end

-- Nouvelle liste du Musée après un Secret obtenu : le plus récent en premier, MuseumSlots au plus. La liste reçue
-- n'est jamais modifiée ; une entrée qui n'est pas une table est ignorée.
function AnnouncementConfig.MuseumPush(list: any, entry: any): {any}
    local result: {any} = {}
    if type(entry) == "table" then table.insert(result, entry) end
    if type(list) == "table" then
        for _, item in ipairs(list) do
            if #result >= AnnouncementConfig.MuseumSlots then break end
            table.insert(result, item)
        end
    end
    return result
end

return table.freeze(AnnouncementConfig)
