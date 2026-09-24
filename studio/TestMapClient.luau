--!nonstrict
--[[ TestMapClient
     Rôle    : mesurer la map vivante avec un vrai personnage : jour-nuit, rebond des trampolines, saut de
               rampe, et les routes du spawn aux plots, chronométrées.
     Doc     : GAME_MASTER_V2 H2 étape 8 (« Une chase hub→plot = FUN (rampes/trampolines) »), D1.1,
               D1.3 Z7, A4 (portage -30 %) ; PROMPT_EXECUTION_SABL_V4 §25.2
     Étape   : 8, lot C ; son du rebond, saut du voleur chargé et tranchées comblées au lot D
     Dépend  : Play en cours, datamodel Client ; Controllers.TrampolineController et
               Controllers.DayNightController démarrés ; map habillée par studio/DressMapMonde1.luau
     Exposé  : texte de bilan ; exécuté tel quel par l'outil dans le datamodel Client, car l'outil ne peut
               pas require. Section lue dans l'attribut Workspace SABL_TestMode, posé côté client :
               « daynight » (3 s), « bounce » (12 s), « routes » (60 s) ou « all » (défaut). Par l'outil,
               lancer les sections une à une : « all » dépasse son délai de réponse.
     Limite  : déplace le personnage du testeur (téléportations, marche) ; aucun profil touché. Les
               constantes de MapConfig, StealConfig et du kit sont recopiées, faute de require. Le « FUN »
               reste un jugement humain : ce test en fournit les mesures.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Recopiées de Config.MapConfig, Config.StealConfig et du kit (studio/BuildMapProps.luau).
local CYCLE_SECONDS = 1200
local NIGHT_BOOST = 1.5
local LAMP_BRIGHTNESS = 1.5
local LAUNCH_SPEED = 100
local CARRY_PENALTY = 0.30
local HOURS_PER_DAY = 24
local BOUNCE_TOLERANCE = 0.25 -- le rebond mesuré doit tenir à ±25 % de v²/2g
local ROUTE_SLACK, ROUTE_GRACE = 1.3, 1.5 -- une route passe sous 130 % du temps idéal, plus 1,5 s
local ARRIVAL_STUDS = 4
local LEG_STUDS = 40 -- longueur d'un ordre de marche : MoveTo abandonne au bout de 8 s
local SPAWN = Vector3.new(0, 7, 20)
local JUMP_LEAD = 0.3 -- studs avant le bord haut de la rampe où le joueur saute
-- En travers de la ruelle 4, au droit de sa rampe 1 : sol de la ruelle, ancienne tranchée, plot 4.
local CROSS_FROM_V, TRENCH_V, PLOT_V = -7, -12.2, -22

-- Routes du spawn aux plots dont la liaison traverse une zone (D1.3) : musée, boutique, Colisée, arène.
local ROUTES = {
    {name = "plot 7, sud, autour du musee", plot = 7,
        points = {Vector3.new(16, 0, 50), Vector3.new(8, 0, 57), Vector3.new(5, 0, 70), Vector3.new(0, 0, 200)}},
    {name = "plot 4, est, par la boutique", plot = 4,
        points = {Vector3.new(30, 0, -5), Vector3.new(130, 0, -5), Vector3.new(182, 0, -2), Vector3.new(200, 0, 0)}},
    {name = "plot 1, nord, par l'escalier du Colisee", plot = 1,
        points = {Vector3.new(0, 0, -40), Vector3.new(0, 0, -200)}},
    {name = "plot 10, ouest, par l'arene", plot = 10,
        points = {Vector3.new(-25, 0, 0), Vector3.new(-40, 0, 0), Vector3.new(-50, 0, 8), Vector3.new(-70, 0, 8),
            Vector3.new(-86, 0, 0), Vector3.new(-200, 0, 0)}},
}

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
local map = Workspace:WaitForChild("Map_Monde1", 10)
local mode = Workspace:GetAttribute("SABL_TestMode") or "all"
local below = RaycastParams.new()
below.FilterType = Enum.RaycastFilterType.Exclude
below.FilterDescendantsInstances = {character}

local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end
local function feetOffset()
    return math.max(humanoid.HipHeight, 2) + root.Size.Y / 2
end
local function topOf(p)
    local cf, size = p.CFrame, p.Size
    return cf.Position.Y + (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y
        + math.abs(cf.LookVector.Y) * size.Z) / 2
end
local function groundUnder(position)
    local hit = Workspace:Raycast(position, Vector3.new(0, -20, 0), below)
    return hit and hit.Instance
end
local function teleport(position)
    pcall(function() player:RequestStreamAroundAsync(position, 5) end)
    root.AssemblyLinearVelocity = Vector3.zero
    character:PivotTo(CFrame.new(position))
    task.wait(0.8)
end

if mode == "all" or mode == "daynight" then
    -- D1.1 : l'heure suit l'horloge du serveur et avance d'un jour toutes les 20 min.
    Workspace:SetAttribute("SABL_ClockOffset", nil)
    task.wait(0.3)
    local expected = (Workspace:GetServerTimeNow() % CYCLE_SECONDS) / CYCLE_SECONDS * HOURS_PER_DAY
    local drift = math.abs(Lighting.ClockTime - expected)
    drift = math.min(drift, HOURS_PER_DAY - drift)
    local before = Lighting.ClockTime
    task.wait(2)
    local advance = (Lighting.ClockTime - before) % HOURS_PER_DAY
    check(("D1.1 : l'heure suit le serveur (%.2f h, attendu %.2f) et avance de %.3f h en 2 s (attendu %.3f)")
        :format(before, expected, advance, 2 / CYCLE_SECONDS * HOURS_PER_DAY),
        drift < 0.02 and math.abs(advance - 2 / CYCLE_SECONDS * HOURS_PER_DAY) < 0.01)
    -- D1.1 : à la tombée de la nuit, néons +50 %. On avance le cycle à 21 h, puis à 12 h.
    local lights = {}
    for _, descendant in ipairs(map:GetDescendants()) do
        if descendant:IsA("PointLight") and descendant.Parent and descendant.Parent.Name == "Globe" then
            table.insert(lights, descendant)
        end
    end
    local function brightnessAt(hour)
        local now = Workspace:GetServerTimeNow() % CYCLE_SECONDS
        Workspace:SetAttribute("SABL_ClockOffset", hour / HOURS_PER_DAY * CYCLE_SECONDS - now)
        task.wait(0.4)
        local low, high = math.huge, -math.huge
        for _, light in ipairs(lights) do
            low = math.min(low, light.Brightness)
            high = math.max(high, light.Brightness)
        end
        return low, high, Lighting.ClockTime
    end
    local nightLow, nightHigh, nightClock = brightnessAt(21)
    local dayLow, dayHigh, dayClock = brightnessAt(12)
    Workspace:SetAttribute("SABL_ClockOffset", nil)
    check(("D1.1 : %d neons a %.2f-%.2f la nuit (%.1f h, attendu %.2f), %.2f-%.2f le jour (%.1f h, attendu %.2f)")
        :format(#lights, nightLow, nightHigh, nightClock, LAMP_BRIGHTNESS * NIGHT_BOOST, dayLow, dayHigh, dayClock,
            LAMP_BRIGHTNESS), #lights > 0
        and math.abs(nightLow - LAMP_BRIGHTNESS * NIGHT_BOOST) < 0.01 and math.abs(nightHigh - LAMP_BRIGHTNESS * NIGHT_BOOST) < 0.01
        and math.abs(dayLow - LAMP_BRIGHTNESS) < 0.01 and math.abs(dayHigh - LAMP_BRIGHTNESS) < 0.01)
end

if mode == "all" or mode == "bounce" then
    local ruelle = map:WaitForChild("Ruelles"):WaitForChild("Ruelle4")
    local floorTop = topOf(ruelle.Floor)
    local out = flat(ruelle.Floor.Position).Unit
    local across = Vector3.new(-out.Z, 0, out.X)
    -- Trampoline : le personnage est lâché 4 studs au-dessus de la toile, puis on suit ses rebonds.
    local bed = ruelle:WaitForChild("PROP_trampoline1"):WaitForChild("Bed")
    local bedTop = topOf(bed)
    teleport(Vector3.new(bed.Position.X, bedTop + feetOffset() + 4, bed.Position.Z))
    local peak, bounces, heard, lastRise, airtimes = -math.huge, 0, 0, nil, {}
    local rising = false
    local started = os.clock()
    while os.clock() - started < 4 do
        local vertical = root.AssemblyLinearVelocity.Y
        peak = math.max(peak, root.Position.Y - feetOffset() - bedTop)
        if vertical > LAUNCH_SPEED * 0.5 and not rising then
            rising = true
            bounces += 1
            local sound = root:FindFirstChild("Rebond")
            if sound and sound.IsPlaying then heard += 1 end
            local now = os.clock()
            if lastRise then table.insert(airtimes, now - lastRise) end
            lastRise = now
        elseif vertical < 0 then
            rising = false
        end
        task.wait()
    end
    local expected = LAUNCH_SPEED ^ 2 / (2 * Workspace.Gravity)
    local airtime = #airtimes > 0 and airtimes[1] or 0
    check(("Z7 : trampoline, rebond de %.1f studs (attendu %.1f a +-%d %%), %d rebonds en 4 s, %.2f s en l'air")
        :format(peak, expected, BOUNCE_TOLERANCE * 100, bounces, airtime),
        bounces >= 2 and math.abs(peak - expected) <= expected * BOUNCE_TOLERANCE)
    local effect = Workspace.Terrain:FindFirstChild("RebondEffet")
    local emitter = effect and effect:FindFirstChildWhichIsA("ParticleEmitter")
    check(("Lot D : retour du rebond, son joue a %d rebonds sur %d, gerbe %s")
        :format(heard, bounces, emitter and "presente" or "absente"), bounces > 0 and heard == bounces and emitter ~= nil)
    teleport(SPAWN)

    -- Rampe : course depuis le pied, saut au bord haut, vers le plot voisin, à pleine vitesse puis en voleur
    -- chargé. Le bord haut praticable est l'arête supérieure de la dalle : il se lit sur ses coins les plus hauts.
    local ramp = ruelle:WaitForChild("PROP_ramp1")
    local pivot = ramp:GetPivot()
    local rise = flat(pivot.LookVector).Unit
    local base = Vector3.new(pivot.Position.X, floorTop, pivot.Position.Z)
    local topEdge, topY = 0, -math.huge
    local slab = ramp:WaitForChild("Slab")
    local half = slab.Size / 2
    for _, x in ipairs({-1, 1}) do
        for _, y in ipairs({-1, 1}) do
            for _, z in ipairs({-1, 1}) do
                local corner = slab.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z)
                if corner.Y > topY + 0.01 then
                    topY, topEdge = corner.Y, (corner - base):Dot(rise)
                end
            end
        end
    end
    local function rampJump(speedFactor)
        local walkSpeed = humanoid.WalkSpeed
        humanoid.WalkSpeed = walkSpeed * speedFactor
        teleport(base - rise * 9 + Vector3.new(0, feetOffset() + 0.5, 0))
        local jumped, airborne, landing, highest = false, false, nil, -math.huge
        humanoid:MoveTo(base + rise * 24)
        local begun = os.clock()
        while os.clock() - begun < 5 do
            local along = (root.Position - base):Dot(rise)
            highest = math.max(highest, root.Position.Y - feetOffset() - floorTop)
            if not jumped and along >= topEdge - JUMP_LEAD then
                -- Le module de contrôle du joueur réécrit Humanoid.Jump à chaque image : on force l'état.
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                jumped = true
            end
            local state = humanoid:GetState()
            if jumped and (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping) then
                airborne = true
            elseif airborne and (state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running) then
                landing = root.Position
                break
            end
            task.wait()
        end
        humanoid:MoveTo(root.Position)
        humanoid.WalkSpeed = walkSpeed
        local flight = landing and ((landing - base):Dot(rise) - topEdge) or 0
        return highest, flight, landing and Workspace:Raycast(landing, Vector3.new(0, -20, 0), below)
    end
    local function name(hit)
        return hit and hit.Instance:GetFullName():gsub("^Workspace%.", "") or "rien"
    end
    local highest, flight, hit = rampJump(1)
    check(("Z7 : rampe, sommet a %.1f studs du sol, saut de %.1f studs apres le bord haut, atterrissage sur %s")
        :format(highest, flight, name(hit)), highest >= 7 and hit ~= nil and hit.Instance:IsDescendantOf(map.Plots))
    local _, thiefFlight, thiefHit = rampJump(1 - CARRY_PENALTY)
    check(("Lot D : voleur charge (-%d %%) sur la rampe, saut de %.1f studs, atterrissage sur %s a %.2f (sol %.2f)")
        :format(CARRY_PENALTY * 100, thiefFlight, name(thiefHit), thiefHit and thiefHit.Position.Y or -1, floorTop),
        thiefHit ~= nil and math.abs(thiefHit.Position.Y - floorTop) < 0.1)

    -- Lot D : au droit de la rampe, l'ancienne tranchée est comblée ; on traverse de la ruelle au plot sans creux.
    local filled = Workspace:Raycast(base + across * TRENCH_V + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), below)
    teleport(base + across * CROSS_FROM_V + Vector3.new(0, feetOffset() + 0.5, 0))
    local lowest, finished = math.huge, false
    local done = humanoid.MoveToFinished:Connect(function() finished = true end)
    humanoid:MoveTo(base + across * PLOT_V)
    local begun = os.clock()
    while not finished and os.clock() - begun < 5 do
        lowest = math.min(lowest, root.Position.Y - feetOffset())
        task.wait()
    end
    done:Disconnect()
    local after = groundUnder(root.Position)
    check(("Lot D : tranchee comblee (sol a %.2f sur %s, niveau %.2f), traversee ruelle -> plot au point bas %.2f, arrivee sur %s")
        :format(filled and filled.Position.Y or -1, filled and filled.Instance.Name or "rien", floorTop, lowest,
            after and after:GetFullName():gsub("^Workspace%.", "") or "rien"),
        filled ~= nil and math.abs(filled.Position.Y - floorTop) < 0.1 and lowest > floorTop - 0.5
        and after ~= nil and after:IsDescendantOf(map.Plots))
    teleport(SPAWN)
end

if mode == "all" or mode == "routes" then
    local speed = humanoid.WalkSpeed
    for _, route in ipairs(ROUTES) do
        teleport(SPAWN)
        local ideal, from = 0, flat(SPAWN)
        for _, point in ipairs(route.points) do
            ideal += (flat(point) - from).Magnitude
            from = flat(point)
        end
        local started = os.clock()
        local stuck = false
        for _, point in ipairs(route.points) do
            local origin = flat(root.Position)
            local pieces = math.max(1, math.ceil((flat(point) - origin).Magnitude / LEG_STUDS))
            for piece = 1, pieces do
                local waypoint = origin:Lerp(flat(point), piece / pieces)
                humanoid:MoveTo(Vector3.new(waypoint.X, root.Position.Y, waypoint.Z))
                if not humanoid.MoveToFinished:Wait() then stuck = true break end
            end
            if stuck then break end
        end
        local elapsed = os.clock() - started
        local last = route.points[#route.points]
        local ground = groundUnder(root.Position)
        local plot = map.Plots:FindFirstChild("Plot" .. route.plot)
        local arrived = not stuck and (flat(root.Position) - flat(last)).Magnitude <= ARRIVAL_STUDS
            and ground ~= nil and plot ~= nil and (ground == plot or ground:IsDescendantOf(plot))
        local budget = ideal / speed * ROUTE_SLACK + ROUTE_GRACE
        check(("Route %s : %.1f s pour %.0f studs (ideal %.1f s a %d studs/s, voleur charge %.1f s)%s")
            :format(route.name, elapsed, ideal, ideal / speed, speed, ideal / (speed * (1 - CARRY_PENALTY)),
                stuck and " ; bloque en chemin" or ""), arrived and elapsed <= budget)
    end
    teleport(SPAWN)
end

table.insert(T.lines, ("[MAP CLIENT TEST %s] %d OK / %d FAIL"):format(mode, T.pass, T.fail))
return table.concat(T.lines, "\n")
