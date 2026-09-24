--!strict
--[[ ErrorMessages
     Rôle    : traduire en français les codes d'erreur renvoyés par les remotes.
     Doc     : PROMPT_EXECUTION_SABL_V4 §18.3 (liste normalisée des codes)
     Étape   : 4, lot D ; extrait d'EggShopController pour servir tous les écrans ; codes du vol en 5, lot D1 ;
               codes des upgrades en 9, lot B ; codes du rebirth en 9, lot C ; quêtes et réglages en 10, lot A
     Dépend  : Config.EconomyConfig, Config.StealConfig
     Exposé  : Get(code) -> texte lisible
     Limite  : le client traduit, il n'invente aucun code ni aucune décision (§18.3).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local StealConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("StealConfig"))

local SECONDS_PER_MINUTE = 60

local ErrorMessages = {}

ErrorMessages.Codes = {
    RATE_LIMIT = "Trop d'actions d'un coup, patiente une seconde.",
    NO_PROFILE = "Profil pas encore chargé.",
    NOT_OWNER = "Cette créature ne t'appartient pas.",
    ALREADY_PLACED = "Cette créature est déjà posée sur un piédestal.",
    NOT_PLACED = "Cette créature n'est pas posée.",
    SLOT_TAKEN = "Ce piédestal est déjà occupé.",
    NO_SLOT = "Plus de piédestal libre.",
    NOT_ENOUGH_MONEY = "Pas assez d'argent.",
    INVENTORY_FULL = "Inventaire plein (" .. Economy.InventoryMax .. " maximum).",
    BAD_QTY = "Sélection invalide.",
    BAD_EGG = "Œuf indisponible.",
    WORLD_LOCKED = "Ce monde n'est pas encore débloqué.",
    MISMATCH = "Il faut trois créatures identiques, de même tier.",
    MAX_TIER = "Cette créature est déjà au tier maximal.",
    IN_ARENA = "Cette créature est engagée en arène.",
    ON_COOLDOWN = "Patiente encore un peu avant de recommencer.",
    TARGET_SHIELDED = "Cette base est protégée par son bouclier.",
    TOO_FAR = "Trop loin : rapproche-toi.",
    LEVEL_TOO_LOW = ("Le vol se débloque au niveau %d et après %d min de jeu."):format(
        StealConfig.Protection.MinLevel, StealConfig.Protection.MinPlaytimeSeconds / SECONDS_PER_MINUTE),
    TARGET_PROTECTED = "Ce joueur débute encore : il est protégé.",
    ALREADY_CARRYING = "Tu portes déjà un brainrot.",
    NOT_CARRYING = "Ce joueur ne porte rien.",
    SECURE_NOT_READY = "Maintiens la pose jusqu'au bout.",
    DROP_GONE = "Ce brainrot n'est plus au sol.",
    BUYBACK_GONE = "Ce rachat n'est plus disponible.",
    NO_TELEPORT = "Téléportation indisponible.",
    BAD_UPGRADE = "Amélioration inconnue.",
    MAX_LEVEL = "Déjà au niveau maximal.",
    NOT_AVAILABLE = "Bientôt disponible.",
    IN_RESERVE = "Ce brainrot est en Réserve d'or : il ne produit plus, mais reste engageable en PvP.",
    NOT_CONFIRMED = "Confirme le rebirth pour continuer.",
    IN_STEAL = "Impossible pendant un vol ou un rachat en cours.",
    BAD_QUEST = "Quête inconnue.",
    QUEST_GONE = "Cette quête n'est plus au programme du jour.",
    QUEST_NOT_DONE = "Quête pas encore terminée.",
    ALREADY_CLAIMED = "Récompense déjà réclamée.",
    BAD_SETTING = "Réglage inconnu.",
    INTERNAL = "Erreur interne, réessaie.",
}

function ErrorMessages.Get(code: any): string
    if type(code) ~= "string" then return ErrorMessages.Codes.INTERNAL end
    return ErrorMessages.Codes[code] or ErrorMessages.Codes.INTERNAL
end

return table.freeze(ErrorMessages)
