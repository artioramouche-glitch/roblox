--!strict
--[[ CombatEngine
     Rôle    : simuler un match PvP 1v1 ou 2v2 pas à pas (0,1 s) : auto-attaques, jauges de capacité et de foule,
               capacités, switch, ultime, KO, temps limite et abandon ; seule autorité sur l'état d'un match.
     Doc     : GAME_MASTER_V2 G5.6, E2, E3, E4, E5, E12, B0bis, B4, B5 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot C, §25.2
               (lot COMBAT) ; Q1-Q3 du lot C (03/10 : A, A, A) et du 2v2 (03/10 : A, A, A) ; décisions 118 à 122,
               138 à 142
     Étape   : 13, lot C ; 2v2 (dette 33)
     Dépend  : Config.CombatConfig (G5.3), Config.ArenaConfig (Match), Shared.SlotRandom (brassage Mix32)
     Exposé  : New(teamA, teamB, seed) et New2v2({teamA, teamA2}, {teamB, teamB2}, seed) -> match | (nil, raison) ;
               Step(match) ; Activate(match, siège) ; Switch(match, siège, slot) ; Ultimate(match, siège) ;
               Forfeit(match, siège) -> (ok, raison?) ; sièges : "A", "B" (1v1), plus "A2", "B2" (2v2) ;
               Snapshot(match) -> charge utile de CombatSync ; View(match, side) ; Result(match) ;
               TypeMultiplier(attaquant, défenseur)
     Limite  : ni temps réel, ni remote, ni Instance : CombatService (session locale) appelle Step toutes les 0,1 s,
               relaie les 3 actions des clients, pousse Snapshot par CombatSync une fois par tick et garde l'Elo,
               les tokens et les créatures (le moteur ne lit ni n'écrit jamais un profil). En 2v2 (Q1 A), deux
               couloirs : chaque siège frappe celui d'en face, ou l'autre adversaire si son couloir est vide ; un
               siège abandonné reste en jeu, mené par CombatBot (Q3 A). La graine ne quitte jamais le serveur
               (décision 121). Les actions s'appliquent dès leur appel, dans l'ordre des appels.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = ReplicatedStorage:WaitForChild("Config")
local CombatConfig = require(config:WaitForChild("CombatConfig")) :: any
local ArenaConfig = require(config:WaitForChild("ArenaConfig"))
local SlotRandom = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SlotRandom"))

local MATCH = ArenaConfig.Match
local PER_SECOND = math.round(1 / MATCH.TickSeconds)
local TWO32 = 4294967296
local EPS = 1e-9

-- Toutes les durées se comptent en ticks entiers : aucune dérive d'arrondi sur 90 s.
local function ticks(seconds: number): number
    return math.round(seconds * PER_SECOND)
end

local ATTACK = ticks(CombatConfig.AutoAttackInterval)
local SWITCH = ticks(CombatConfig.SwitchCooldown)
local INVULN = ticks(CombatConfig.InvulnAfterSwitch)
local TIMEOUT = ticks(CombatConfig.MatchTimeout)
local TIMEOUT_2V2 = ticks(MATCH.Timeout2v2)
local RAGDOLL = ticks(MATCH.RagdollSeconds)
local FREEZE = ticks(MATCH.UltimateFreezeSeconds)
local OTHER: {[string]: string} = {A = "B", B = "A"} -- camps
local TARGETED: {[string]: boolean} = {Burst = true, Control = true} -- capacités qui visent l'adversaire
table.freeze(OTHER)
table.freeze(TARGETED)

type Effect = {Value: number, Left: number}
type Fighter = {
    Id: string, Type: string, MaxHP: number, HP: number, ATK: number, Ability: any, Alive: boolean,
    Progress: number, Shield: number, Stun: number, Invuln: number,
    AtkDown: Effect, AtkUp: Effect, SpeedUp: Effect, Blind: Effect, Reflect: Effect,
}
-- Un siège = un joueur : son équipe, ses jauges, son couloir. Le camp est "A" ou "B".
type Side = {
    Team: {Fighter}, Active: number, Charge: number, Crowd: number, SwitchCd: number, Down: number,
    Damage: number, Abilities: number, Ultimates: number, Switches: number, Camp: string, Lane: number, Left: boolean,
}
export type Match = {
    Sides: {[string]: Side}, Order: {string}, Camps: {[string]: {string}}, Timeout: number, Seed: number,
    Draws: number, Clock: number, Freeze: number, Pending: string?, Over: boolean, Winner: string?, Reason: string?,
    Events: {any},
}

local CombatEngine = {}
CombatEngine.TickSeconds = MATCH.TickSeconds

local function effect(): Effect
    return {Value = 0, Left = 0}
end

-- Une entrée d'équipe = {Id, HP, ATK, Type} : stats déjà calculées par l'appelant (Shared/CombatUtil, B4).
local function newFighter(entry: any): Fighter?
    if type(entry) ~= "table" then return nil end
    local id, hp, atk, kind = entry.Id, entry.HP, entry.ATK, entry.Type
    if type(id) ~= "string" or type(hp) ~= "number" or type(atk) ~= "number" or type(kind) ~= "string" then
        return nil
    end
    if not (hp >= 1 and hp < math.huge and atk >= 0 and atk < math.huge) or CombatConfig.TypeCycle[kind] == nil then
        return nil
    end
    return {
        Id = id, Type = kind, MaxHP = hp, HP = hp, ATK = atk, Ability = CombatConfig:GetAbility(id), Alive = true,
        Progress = 0, Shield = 0, Stun = 0, Invuln = 0,
        AtkDown = effect(), AtkUp = effect(), SpeedUp = effect(), Blind = effect(), Reflect = effect(),
    }
end

-- 1 à 3 brainrots ; l'équipe complète de 3 est exigée par ArenaService (G5.5), pas ici.
local function newSide(team: any, camp: string, lane: number): Side?
    if type(team) ~= "table" or #team < 1 or #team > MATCH.TeamSize then return nil end
    local fighters: {Fighter} = {}
    for i = 1, #team do
        local fighter = newFighter(team[i])
        if not fighter then return nil end
        fighters[i] = fighter
    end
    return {
        Team = fighters, Active = 1, Charge = 0, Crowd = 0, SwitchCd = 0, Down = 0,
        Damage = 0, Abilities = 0, Ultimates = 0, Switches = 0, Camp = camp, Lane = lane, Left = false,
    }
end

-- Sièges du couloir 1 : "A" et "B" ; du couloir 2 : "A2" et "B2".
local function build(teamsA: {any}, teamsB: {any}, seed: any, timeout: number): (Match?, string?)
    if type(seed) ~= "number" or seed % 1 ~= 0 or seed < 0 or seed >= TWO32 then return nil, "BAD_SEED" end
    local sides: {[string]: Side} = {}
    local order: {string} = {}
    local camps: {[string]: {string}} = {A = {}, B = {}}
    for lane = 1, #teamsA do
        for _, camp in ipairs({"A", "B"}) do
            local name = if lane == 1 then camp else camp .. lane
            local side = newSide((if camp == "A" then teamsA else teamsB)[lane], camp, lane)
            if not side then return nil, "BAD_TEAM" end
            sides[name] = side
            table.insert(order, name)
            table.insert(camps[camp], name)
        end
    end
    return {
        Sides = sides, Order = order, Camps = camps, Timeout = timeout, Seed = seed, Draws = 0, Clock = 0,
        Freeze = 0, Pending = nil, Over = false, Winner = nil, Reason = nil, Events = {},
    }, nil
end

function CombatEngine.New(teamA: any, teamB: any, seed: any): (Match?, string?)
    return build({teamA}, {teamB}, seed, TIMEOUT)
end

-- E2 / Q1 (A) : 2v2, deux couloirs, temps limite de 120 s.
function CombatEngine.New2v2(teamsA: any, teamsB: any, seed: any): (Match?, string?)
    if type(teamsA) ~= "table" or type(teamsB) ~= "table" or #teamsA ~= 2 or #teamsB ~= 2 then
        return nil, "BAD_TEAM"
    end
    return build(teamsA, teamsB, seed, TIMEOUT_2V2)
end

-- B0bis : +20 % sur le type battu, −20 % contre le type qui bat l'attaquant.
function CombatEngine.TypeMultiplier(attacker: string, defender: string): number
    if CombatConfig.TypeCycle[attacker] == defender then return 1 + CombatConfig.TypeBonus end
    if CombatConfig.TypeCycle[defender] == attacker then return 1 - CombatConfig.TypeBonus end
    return 1
end

-- Tirage reproductible dans [0, 1) : la graine du serveur et le rang du tirage, brassés par Mix32. Un match se
-- rejoue à l'identique à partir de sa graine et de ses actions.
local function roll(match: Match): number
    match.Draws += 1
    return SlotRandom.Mix32(bit32.bxor(match.Seed, SlotRandom.Mix32(match.Draws % TWO32))) / TWO32
end

local function emit(match: Match, event: any)
    table.insert(match.Events, event)
end

local function active(side: Side): Fighter
    return side.Team[side.Active]
end

-- Le brainrot actif s'il est sur le terrain (ni KO, ni en ragdoll).
local function fighting(side: Side): Fighter?
    local fighter = side.Team[side.Active]
    return if side.Down == 0 and fighter.Alive then fighter else nil
end

-- Cible d'un siège : le brainrot d'en face s'il est sur le terrain, sinon celui de l'autre couloir adverse (2v2).
local function foeOf(match: Match, sideName: string): string?
    local side = match.Sides[sideName]
    local foes = match.Camps[OTHER[side.Camp]]
    local facing = foes[side.Lane]
    if facing and fighting(match.Sides[facing]) then return facing end
    for _, name in ipairs(foes) do
        if fighting(match.Sides[name]) then return name end
    end
    return nil
end

local function live(e: Effect): number
    return if e.Left > 0 then e.Value else 0
end

-- Un même effet ne se cumule pas : la valeur la plus forte et la durée la plus longue l'emportent.
local function apply(match: Match, sideName: string, e: Effect, name: string, value: number, seconds: number)
    e.Value = math.max(live(e), value)
    e.Left = math.max(e.Left, ticks(seconds))
    emit(match, {k = "Effect", s = sideName, e = name, v = value, d = seconds})
end

local function stun(match: Match, sideName: string, fighter: Fighter, seconds: number)
    fighter.Stun = math.max(fighter.Stun, ticks(seconds))
    emit(match, {k = "Effect", s = sideName, e = "Stun", d = seconds})
end

local function attackOf(fighter: Fighter): number
    return fighter.ATK * (1 + live(fighter.AtkUp)) * (1 - live(fighter.AtkDown))
end

local function gain(side: Side, amount: number)
    side.Crowd = math.min(1, side.Crowd + amount)
end

local function heal(match: Match, sideName: string, slot: number, share: number)
    local fighter = match.Sides[sideName].Team[slot]
    local before = fighter.HP
    fighter.HP = math.min(fighter.MaxHP, fighter.HP + fighter.MaxHP * share)
    emit(match, {k = "Heal", s = sideName, slot = slot, amt = fighter.HP - before})
end

local function finish(match: Match, winner: string, reason: string)
    match.Over, match.Winner, match.Reason = true, winner, reason
    match.Freeze, match.Pending = 0, nil
    emit(match, {k = "End", w = winner, r = reason})
end

-- Remplaçant suivant dans l'ordre de l'équipe (choisi en préparation, E3), en repartant du début.
local function nextAlive(side: Side): number?
    local n = #side.Team
    for step = 1, n - 1 do
        local slot = (side.Active - 1 + step) % n + 1
        if side.Team[slot].Alive then return slot end
    end
    return nil
end

local function enter(match: Match, sideName: string, slot: number)
    local side = match.Sides[sideName]
    side.Active = slot
    local fighter = side.Team[slot]
    fighter.Invuln, fighter.Progress = INVULN, 0
    emit(match, {k = "Enter", s = sideName, slot = slot})
end

-- Un coup de `sideName` sur le brainrot actif adverse ; source = "Auto", "Ability" ou "Ultimate". Esquivé si la
-- cible est invulnérable, raté selon la précision de l'attaquant (jamais pour l'ultime), absorbé par un bouclier,
-- sinon encaissé. Renvoie vrai si le coup a porté (encaissé ou absorbé).
local function hit(match: Match, sideName: string, mult: number, source: string): boolean
    local foeName = foeOf(match, sideName)
    if not foeName then return false end
    local side, foe = match.Sides[sideName], match.Sides[foeName]
    local attacker, target = active(side), fighting(foe) :: Fighter
    if target.Invuln > 0 then
        emit(match, {k = "Dodge", s = sideName, to = foeName, src = source})
        return false
    end
    local ultimate = source == "Ultimate"
    if not ultimate and live(attacker.Blind) > 0 and roll(match) < live(attacker.Blind) then
        emit(match, {k = "Miss", s = sideName, to = foeName, src = source})
        return false
    end
    -- E3 : ±10 % tiré côté serveur ; E5 : l'ultime vaut 3 × l'ATK du moment, sans variance.
    local factor = if ultimate then 1 else 1 + (roll(match) * 2 - 1) * CombatConfig.Variance
    local typeMult = CombatEngine.TypeMultiplier(attacker.Type, target.Type)
    local damage = math.max(1, math.round(attackOf(attacker) * mult * typeMult * factor))
    if not ultimate then -- l'ultime remet la foule à 0 et n'en rapporte pas (E5)
        gain(side, CombatConfig.CrowdPerHitDealt)
        gain(foe, CombatConfig.CrowdPerHitTaken)
    end
    local absorbed = target.Shield > 0
    if absorbed then
        target.Shield -= 1
    else
        target.HP -= damage
        side.Damage += damage
    end
    local reflected = 0
    if live(target.Reflect) > 0 then -- renvoi calculé sur le coup reçu, absorbé ou non
        reflected = math.max(1, math.round(damage * live(target.Reflect)))
        attacker.HP -= reflected
        foe.Damage += reflected
    end
    emit(match, {k = "Hit", s = sideName, to = foeName, src = source, dmg = damage, abs = absorbed, ref = reflected,
        tm = typeMult})
    return true
end

local function empty(side: Side): boolean
    for _, fighter in ipairs(side.Team) do
        if fighter.Alive then return false end
    end
    return true
end

-- KO des brainrots actifs tombés à 0 PV, puis fin du match si un camp n'a plus aucun brainrot (les deux : nul).
local function settle(match: Match)
    if match.Over then return end
    for _, name in ipairs(match.Order) do
        local side = match.Sides[name]
        local fighter = active(side)
        if side.Down == 0 and fighter.Alive and fighter.HP <= 0 then
            fighter.Alive, fighter.HP, fighter.Progress = false, 0, 0
            emit(match, {k = "KO", s = name, slot = side.Active})
            if nextAlive(side) then side.Down = RAGDOLL end
        end
    end
    local wiped: {[string]: boolean} = {}
    for camp, names in pairs(match.Camps) do
        local all = true
        for _, name in ipairs(names) do all = all and empty(match.Sides[name]) end
        wiped[camp] = all
    end
    if wiped.A and wiped.B then
        finish(match, "Draw", "KO")
    elseif wiped.A then
        finish(match, "B", "KO")
    elseif wiped.B then
        finish(match, "A", "KO")
    end
end

-- E3 : au temps limite, la plus forte part de PV restants sur toute l'équipe gagne ; à égalité, match nul.
local function share(sides: {Side}): number
    local hp, max = 0, 0
    for _, side in ipairs(sides) do
        for _, fighter in ipairs(side.Team) do
            hp += math.max(0, fighter.HP)
            max += fighter.MaxHP
        end
    end
    return hp / max
end

local function campSides(match: Match, camp: string): {Side}
    local out = {}
    for _, name in ipairs(match.Camps[camp]) do table.insert(out, match.Sides[name]) end
    return out
end

local function landUltimate(match: Match)
    local name = match.Pending :: string
    match.Pending = nil
    local side, foeName = match.Sides[name], foeOf(match, name)
    local caster, target = active(side), if foeName then fighting(match.Sides[foeName]) else nil
    local bonus = CombatConfig.UltimateBonus[caster.Type]
    if hit(match, name, CombatConfig.UltimateMultiplier, "Ultimate") and target and foeName then
        if bonus.atkDown then apply(match, foeName, target.AtkDown, "AtkDown", bonus.atkDown, bonus.duration) end
        if bonus.stun then stun(match, foeName, target, bonus.stun) end
    end
    if bonus.healTeam then
        for slot, fighter in ipairs(side.Team) do
            if fighter.Alive then heal(match, name, slot, bonus.healTeam) end
        end
    end
    settle(match)
end

local function tickDown(fighter: Fighter)
    fighter.Stun = math.max(0, fighter.Stun - 1)
    fighter.Invuln = math.max(0, fighter.Invuln - 1)
    for _, e in ipairs({fighter.AtkDown, fighter.AtkUp, fighter.SpeedUp, fighter.Blind, fighter.Reflect}) do
        e.Left = math.max(0, e.Left - 1)
    end
end

-- Un tick de 0,1 s. Pendant le gel d'un ultime, seul le gel avance (horloge des 90 s comprise).
function CombatEngine.Step(match: Match)
    if match.Over then return end
    if match.Freeze > 0 then
        match.Freeze -= 1
        if match.Freeze == 0 then landUltimate(match) end
        return
    end
    match.Clock += 1
    -- 1. Entrée du remplaçant au bout du ragdoll.
    for _, name in ipairs(match.Order) do
        local side = match.Sides[name]
        if side.Down > 0 then
            side.Down -= 1
            if side.Down == 0 then enter(match, name, nextAlive(side) :: number) end
        end
    end
    -- 2. Auto-attaques, simultanées : les KO ne se comptent qu'après tous les coups du tick.
    local firing: {string} = {}
    for _, name in ipairs(match.Order) do
        local fighter = fighting(match.Sides[name])
        if fighter and fighter.Stun == 0 then
            fighter.Progress += 1 + live(fighter.SpeedUp) -- Q2 (A) : +30 % = 30 % d'attaques en plus
            if fighter.Progress >= ATTACK - EPS then
                if foeOf(match, name) then
                    fighter.Progress -= ATTACK
                    table.insert(firing, name)
                else
                    fighter.Progress = ATTACK -- l'attaque attend que l'adversaire ait un brainrot sur le terrain
                end
            end
        end
    end
    for _, name in ipairs(firing) do hit(match, name, 1, "Auto") end
    settle(match)
    if match.Over then return end
    -- 3. Fin du tick : effets, jauge de capacité, recharge du switch, soin du banc.
    for _, name in ipairs(match.Order) do
        local side = match.Sides[name]
        local chargeTime = CombatConfig.AbilityChargeTime + active(side).Ability.cdPlus
        side.Charge = math.min(1, side.Charge + 1 / (chargeTime * PER_SECOND))
        side.SwitchCd = math.max(0, side.SwitchCd - 1)
        for slot, fighter in ipairs(side.Team) do
            tickDown(fighter)
            if fighter.Alive and slot ~= side.Active then
                fighter.HP = math.min(fighter.MaxHP, fighter.HP + fighter.MaxHP * CombatConfig.BenchRegen / PER_SECOND)
            end
        end
    end
    -- 4. Temps limite.
    if match.Clock >= match.Timeout then
        local a, b = share(campSides(match, "A")), share(campSides(match, "B"))
        finish(match, if math.abs(a - b) < EPS then "Draw" elseif a > b then "A" else "B", "Timeout")
    end
end

-- Contrôles communs aux 3 actions du joueur (E4, E12).
local function ready(match: Match, sideName: any): (Side?, string?)
    if type(sideName) ~= "string" or match.Sides[sideName] == nil then return nil, "BAD_SIDE" end
    if match.Over then return nil, "MATCH_OVER" end
    if match.Freeze > 0 then return nil, "FROZEN" end
    local side = match.Sides[sideName]
    if not fighting(side) then return nil, "NO_ACTIVE" end
    return side, nil
end

-- E4 : capacité signature, jauge pleine côté serveur. Une capacité qui vise l'adversaire ne part pas sans cible
-- touchable, et la jauge est alors gardée.
function CombatEngine.Activate(match: Match, sideName: any): (boolean, string?)
    local side, why = ready(match, sideName)
    if not side then return false, why end
    local caster = active(side)
    if caster.Stun > 0 then return false, "STUNNED" end -- Q1 (A)
    if side.Charge < 1 - EPS then return false, "CHARGE_NOT_FULL" end
    local ability = caster.Ability
    local foeName = foeOf(match, sideName)
    local target = if foeName then fighting(match.Sides[foeName]) else nil
    if TARGETED[ability.kind] and (not target or target.Invuln > 0) then return false, "NO_TARGET" end
    side.Charge = 0
    side.Abilities += 1
    emit(match, {k = "Ability", s = sideName, id = caster.Id, kind = ability.kind, shake = ability.shake == true})
    if ability.kind == "Burst" then
        if hit(match, sideName, ability.power, "Ability") and target and foeName then
            if ability.atkDown then
                apply(match, foeName, target.AtkDown, "AtkDown", ability.atkDown, ability.duration)
            end
            if ability.blind then apply(match, foeName, target.Blind, "Blind", ability.blind, ability.duration) end
        end
        if ability.speedUp then apply(match, sideName, caster.SpeedUp, "SpeedUp", ability.speedUp, ability.duration) end
        if ability.crowdBoost then gain(side, ability.crowdBoost) end -- Q3 (A) : +25 points tout de suite
    elseif ability.kind == "Heal" then
        heal(match, sideName, side.Active, ability.power)
        if ability.atkUp then apply(match, sideName, caster.AtkUp, "AtkUp", ability.atkUp, ability.duration) end
        if ability.speedUp then apply(match, sideName, caster.SpeedUp, "SpeedUp", ability.speedUp, ability.duration) end
        if ability.cleanse then
            caster.AtkDown.Left, caster.Blind.Left, caster.Stun = 0, 0, 0
            emit(match, {k = "Effect", s = sideName, e = "Cleanse"})
        end
    elseif ability.kind == "Shield" then
        caster.Shield = math.max(caster.Shield, ability.power)
        emit(match, {k = "Effect", s = sideName, e = "Shield", v = ability.power})
        if ability.reflect then apply(match, sideName, caster.Reflect, "Reflect", ability.reflect, ability.duration) end
    elseif ability.kind == "Control" and target and foeName then
        stun(match, foeName, target, ability.power)
    end
    settle(match)
    return true, nil
end

-- E4 : switch vers un remplaçant vivant, recharge de 5 s ; permis même étourdi (Q1 A).
function CombatEngine.Switch(match: Match, sideName: any, slot: any): (boolean, string?)
    local side, why = ready(match, sideName)
    if not side then return false, why end
    if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > #side.Team then return false, "BAD_SLOT" end
    if slot == side.Active then return false, "ALREADY_ACTIVE" end
    if side.SwitchCd > 0 then return false, "SWITCH_COOLDOWN" end
    if not side.Team[slot].Alive then return false, "DEAD" end
    local from = side.Active
    active(side).Progress = 0
    side.SwitchCd = SWITCH
    side.Switches += 1
    emit(match, {k = "Switch", s = sideName, from = from, to = slot})
    enter(match, sideName, slot)
    return true, nil
end

-- E5 : ultime à jauge de foule pleine ; le match se fige 3 s, puis le coup tombe.
function CombatEngine.Ultimate(match: Match, sideName: any): (boolean, string?)
    local side, why = ready(match, sideName)
    if not side then return false, why end
    if active(side).Stun > 0 then return false, "STUNNED" end -- Q1 (A)
    if side.Crowd < 1 - EPS then return false, "CROWD_NOT_FULL" end
    local foeName = foeOf(match, sideName)
    local target = if foeName then fighting(match.Sides[foeName]) else nil
    if not target or target.Invuln > 0 then return false, "NO_TARGET" end
    side.Crowd = 0
    side.Ultimates += 1
    match.Freeze, match.Pending = FREEZE, sideName
    emit(match, {k = "UltStart", s = sideName, id = active(side).Id})
    return true, nil
end

-- E1 / E12 : déconnexion ou abandon = défaite ; le moteur ne touche à aucune créature. Q3 (A) du 2v2 : le siège
-- quitté reste en jeu (CombatBot le mène) ; le camp perd quand tous ses joueurs sont partis (1v1 : aussitôt).
function CombatEngine.Forfeit(match: Match, sideName: any): (boolean, string?)
    if type(sideName) ~= "string" or match.Sides[sideName] == nil then return false, "BAD_SIDE" end
    if match.Over then return false, "MATCH_OVER" end
    local side = match.Sides[sideName]
    if side.Left then return false, "ALREADY_LEFT" end
    side.Left = true
    emit(match, {k = "Left", s = sideName})
    for _, name in ipairs(match.Camps[side.Camp]) do
        if not match.Sides[name].Left then return true, nil end
    end
    finish(match, OTHER[side.Camp], "Forfeit")
    return true, nil
end

local function hpList(side: Side): {number}
    local list = {}
    for i, fighter in ipairs(side.Team) do list[i] = math.ceil(math.max(0, fighter.HP)) end
    return list
end

-- G5.6 : la charge utile unique de CombatSync, identique pour les 2 joueurs et les spectateurs. Vide la liste
-- des événements : un appel par tick, après Step. Aucune graine ni aucun tirage à venir n'y figure (E12).
function CombatEngine.Snapshot(match: Match): any
    local events = match.Events
    match.Events = {}
    local snap: any = {
        t = match.Clock / PER_SECOND, freeze = match.Freeze / PER_SECOND,
        over = match.Over, winner = match.Winner, reason = match.Reason, events = events,
    }
    for _, name in ipairs(match.Order) do -- hpA, activeA, chargeA, crowdA, switchCdA… (et A2, B2 en 2v2)
        local side = match.Sides[name]
        snap["hp" .. name], snap["active" .. name] = hpList(side), side.Active
        snap["charge" .. name], snap["crowd" .. name] = side.Charge, side.Crowd
        snap["switchCd" .. name] = side.SwitchCd / PER_SECOND
    end
    return snap
end

-- Vue d'un camp en lecture seule, sans vider les événements : ce que le bot (CombatBot, lot D) a le droit de
-- savoir, comme un joueur devant son écran.
function CombatEngine.View(match: Match, sideName: string): any
    local side = match.Sides[sideName]
    local team = {}
    for i, fighter in ipairs(side.Team) do
        team[i] = {HP = fighter.HP, MaxHP = fighter.MaxHP, Alive = fighter.Alive, Kind = fighter.Ability.kind}
    end
    return {
        Active = side.Active, OnField = fighting(side) ~= nil, Team = team,
        AbilityReady = side.Charge >= 1 - EPS, UltimateReady = side.Crowd >= 1 - EPS, SwitchReady = side.SwitchCd == 0,
        Over = match.Over, Frozen = match.Freeze > 0,
    }
end

-- E3 : bilan de l'écran de résultat (l'Elo et les tokens sont ajoutés par ArenaRewards, lot D).
function CombatEngine.Result(match: Match): any
    local result: any = {
        Over = match.Over, Winner = match.Winner, Reason = match.Reason, Seconds = match.Clock / PER_SECOND,
    }
    for _, name in ipairs(match.Order) do -- un bilan par siège ; Winner désigne un camp ("A", "B" ou "Draw")
        local side = match.Sides[name]
        result[name] = {
            HP = hpList(side), Share = share({side}), Damage = side.Damage, Abilities = side.Abilities,
            Ultimates = side.Ultimates, Switches = side.Switches, Camp = side.Camp, Left = side.Left,
        }
    end
    return result
end

return table.freeze(CombatEngine)
