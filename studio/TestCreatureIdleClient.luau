--!nonstrict
--[[ TestCreatureIdleClient
     Rôle    : vérifier l'idle des brainrots posés : balancement, amplitude, cycle, absence de dérive.
     Doc     : GAME_MASTER_V2 G5.8 ; PROMPT_EXECUTION_SABL_V4 §21.3 (étape 6), §25.2, Loi 2
     Étape   : 6, lot B2
     Dépend  : Play en cours, datamodel Client ; au moins un brainrot posé sur un piédestal ;
               Controllers.CreatureIdleController démarré
     Exposé  : texte de bilan ; exécuté tel quel dans le datamodel Client, car l'outil MCP ne peut pas require
     Limite  : rien n'est déclenché côté jeu. Le balancement étant calculé localement, la mesure vaut
               pour ce client : un autre joueur verra la même amplitude, pas la même phase. La batterie
               approche la caméra de la créature, comme le ferait un joueur : au-delà de son rayon de
               visibilité, le controller ne calcule rien, par économie.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SWAY_DEGREES = 8 -- G5.8
local SWAY_SECONDS = 1.2 -- G5.8
local ANGLE_TOLERANCE = 0.5 -- degré de marge sur l'amplitude mesurée
local DRIFT_TOLERANCE = 0.01 -- stud : un balancement ne déplace pas la créature
local SAMPLE_SECONDS = 0.05
local SAMPLE_COUNT = 30 -- 1,5 s : plus d'un cycle complet
local CAMERA_DISTANCE = 12 -- studs : assez près pour que le controller anime la créature

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- On vise un brainrot posé sur un piédestal : c'est le cas que décrit G5.8.
local target
for _, descendant in ipairs(Workspace:GetDescendants()) do
    if descendant:IsA("Model") and type(descendant:GetAttribute("CreatureId")) == "string"
        and descendant.Parent and descendant.Parent.Name == "Placed"
        and descendant.PrimaryPart and descendant.PrimaryPart.Anchored then
        target = descendant
        break
    end
end
check("Un brainrot pose est trouve sur un piedestal", target ~= nil)

if target then
    -- Le controller n'anime que ce qui se voit : on se place devant, comme un joueur qui s'approche.
    local camera = Workspace.CurrentCamera
    local seat = target:GetPivot().Position + Vector3.new(0, 2, -CAMERA_DISTANCE)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.lookAt(seat, target:GetPivot().Position)
    task.wait(0.3)
    local angles, positions = {}, {}
    for _ = 1, SAMPLE_COUNT do
        local pivot = target:GetPivot()
        local _, _, roll = pivot:ToOrientation()
        table.insert(angles, math.deg(roll))
        table.insert(positions, pivot.Position)
        task.wait(SAMPLE_SECONDS)
    end
    local low, high = math.huge, -math.huge
    for _, angle in ipairs(angles) do
        low = math.min(low, angle)
        high = math.max(high, angle)
    end
    local drift = 0
    for _, position in ipairs(positions) do
        drift = math.max(drift, (position - positions[1]).Magnitude)
    end
    check(("G5.8 : le brainrot se balance (de %.1f a %.1f degres)"):format(low, high), high - low > 1)
    check(("G5.8 : amplitude contenue dans +/- %d degres"):format(SWAY_DEGREES),
        low >= -SWAY_DEGREES - ANGLE_TOLERANCE and high <= SWAY_DEGREES + ANGLE_TOLERANCE)
    check(("G5.8 : cycle de %.1f s parcouru, les deux extremes sont atteints"):format(SWAY_SECONDS),
        low <= -SWAY_DEGREES + 2 and high >= SWAY_DEGREES - 2)
    check(("Aucune derive : le brainrot reste sur son piedestal (%.4f stud)"):format(drift),
        drift <= DRIFT_TOLERANCE)
end

-- Un brainrot porté suit son voleur : l'idle ne doit pas s'en mêler.
local carriedSeen, carriedStill = 0, true
for _, player in ipairs(Players:GetPlayers()) do
    local character = player.Character
    for _, child in ipairs(character and character:GetChildren() or {}) do
        if child:IsA("Model") and child:GetAttribute("Carried") == true then
            carriedSeen += 1
            carriedStill = carriedStill and child.PrimaryPart ~= nil and not child.PrimaryPart.Anchored
        end
    end
end
check(("Brainrots portes ignores par l'idle (%d vu(s))"):format(carriedSeen), carriedStill)

table.insert(T.lines, ("[IDLE TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
