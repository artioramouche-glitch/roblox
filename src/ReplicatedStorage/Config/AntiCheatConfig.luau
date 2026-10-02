--!strict
--[[ AntiCheatConfig
     Rôle    : seuils et règles de l'anti-triche G3 : escalade des sanctions après les refus de débit, contrôle de
               vitesse.
     Doc     : GAME_MASTER_V2 G3 ; PROMPT_EXECUTION_SABL_V4 §23, §31.12 lot C ; Q1-Q2 de l'étape 12 (02/10, A et A)
     Étape   : 12, lot C (configuration seule)
     Dépend  : aucun (la limite de 10 requêtes/s reste dans RemoteConfig)
     Exposé  : configuration immuable ; Escalation, Speed ; OnInfraction(state, now) → nouvel état, action ;
               ExceedsSpeed(distance, dt)
     Limite  : module absent de G1, comme EconomyConfig ; écart déclaré. Règles pures : AntiCheatService compte une
               infraction par seconde de dépassement et par remote, applique l'action (Players:BanAsync pour
               l'exclusion et le ban, Q2) et remet la position de référence à chaque téléportation voulue par le jeu
               (apparition, « Y ALLER », vengeance, rebirth). Les exclusions des dernières 24 h, même subies sur un
               autre serveur, doivent figurer dans state.Kicks (historique des bans Roblox).
]]
local AntiCheatConfig = {}

-- G3 « warn → kick 60 s → ban 24 h » ; Q1 (option A) : 3 infractions en 1 min → avertissement, 3 avertissements
-- en 10 min → exclusion de 60 s, 2e exclusion en 24 h → ban de 24 h.
AntiCheatConfig.Escalation = table.freeze({
    InfractionsForWarning = 3, InfractionWindow = 60,
    WarningsForKick = 3, WarningWindow = 10 * 60,
    KicksForBan = 2, KickWindow = 24 * 3600,
    KickSeconds = 60, BanSeconds = 24 * 3600,
})

-- G3 : déplacement > 50 studs par image → retour à la dernière position valide ; une image = 1/60 s.
AntiCheatConfig.Speed = table.freeze({MaxStudsPerFrame = 50, FramesPerSecond = 60})

-- Dates de `list` encore dans la fenêtre ]now - window ; now] ; une liste absente ou mal formée est vide.
local function recent(state: any, key: string, now: number, window: number): {number}
    local kept: {number} = {}
    local list = if type(state) == "table" then state[key] else nil
    if type(list) ~= "table" then return kept end
    for _, at in ipairs(list) do
        if type(at) == "number" and at > now - window and at <= now then table.insert(kept, at) end
    end
    return kept
end

-- Une infraction à `now` : renvoie le nouvel état {Infractions, Warnings, Kicks} et l'action à appliquer :
-- "none", "warn", "kick" ou "ban". Un palier atteint vide le palier du dessous.
function AntiCheatConfig.OnInfraction(state: any, now: number): (any, string)
    local rules = AntiCheatConfig.Escalation
    local infractions = recent(state, "Infractions", now, rules.InfractionWindow)
    local warnings = recent(state, "Warnings", now, rules.WarningWindow)
    local kicks = recent(state, "Kicks", now, rules.KickWindow)
    table.insert(infractions, now)
    local action = "none"
    if #infractions >= rules.InfractionsForWarning then
        infractions = {}
        table.insert(warnings, now)
        action = "warn"
        if #warnings >= rules.WarningsForKick then
            warnings = {}
            table.insert(kicks, now)
            action = if #kicks >= rules.KicksForBan then "ban" else "kick"
        end
    end
    return {Infractions = infractions, Warnings = warnings, Kicks = kicks}, action
end

-- Vrai si `distance` studs parcourus en `dt` secondes dépassent 50 studs par image ; au moins une image est comptée.
function AntiCheatConfig.ExceedsSpeed(distance: number, dt: number): boolean
    local speed = AntiCheatConfig.Speed
    local frames = if dt > 0 and dt < math.huge then math.max(1, dt * speed.FramesPerSecond) else 1
    return distance > speed.MaxStudsPerFrame * frames
end

return table.freeze(AntiCheatConfig)
