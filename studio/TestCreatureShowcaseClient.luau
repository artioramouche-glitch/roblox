--!nonstrict
--[[ TestCreatureShowcaseClient
     Rôle    : prouver le critère de l'étape 7 : les 30 brainrots du monde 1 sont vivants en jeu.
     Doc     : GAME_MASTER_V2 H2 étape 7 (« 30 modèles vivants en jeu »), G5.8, §21.2 ;
               PROMPT_EXECUTION_SABL_V4 §25.2
     Étape   : 7, lot C
     Dépend  : Play en cours, datamodel Client ; vitrine posée par studio/FixtureCreatureShowcase.luau ;
               Controllers.CreatureIdleController démarré
     Exposé  : texte de bilan ; exécuté tel quel dans le datamodel Client, car l'outil MCP ne peut pas require
     Limite  : rien n'est déclenché côté jeu. La caméra est posée au-dessus de la vitrine pour que tous
               les modèles soient à portée de l'idle, comme un joueur qui la regarde.
]]
local Workspace = game:GetService("Workspace")

local EXPECTED = 30 -- B1
local SAMPLE_SECONDS = 0.05
local SAMPLE_COUNT = 28 -- 1,4 s : plus d'un cycle G5.8 de 1,2 s
local MIN_SWING = 1 -- degré : en deçà, le modèle est considéré immobile
local AURA_EXPECTED = 20 -- B1 : 4 Épiques, 4 Légendaires, 4 Mythiques, 4 God, 4 SECRET
local BARE_EXPECTED = 10 -- B1 : 5 Communs et 5 Rares, sans aura (§21.2)
local CAMERA_HEIGHT = 30

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local showcase = Workspace:WaitForChild("CreatureShowcase", 10)
check("Vitrine recue par le client", showcase ~= nil)
local models = {}
for _, child in ipairs(showcase and showcase:GetChildren() or {}) do
    if child:IsA("Model") and type(child:GetAttribute("CreatureId")) == "string" then table.insert(models, child) end
end
check(("H2 : les %d brainrots du monde 1 sont en jeu (%d recus)"):format(EXPECTED, #models), #models == EXPECTED)

if #models > 0 then
    -- La caméra surplombe la vitrine : chaque modèle est dans le rayon d'animation.
    local center = Vector3.zero
    for _, model in ipairs(models) do center += model:GetPivot().Position end
    center /= #models
    local camera = Workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.lookAt(center + Vector3.new(0, CAMERA_HEIGHT, -CAMERA_HEIGHT), center)
    task.wait(0.4)

    local low, high = {}, {}
    for _ = 1, SAMPLE_COUNT do
        for _, model in ipairs(models) do
            local _, _, roll = model:GetPivot():ToOrientation()
            local angle = math.deg(roll)
            low[model] = math.min(low[model] or angle, angle)
            high[model] = math.max(high[model] or angle, angle)
        end
        task.wait(SAMPLE_SECONDS)
    end
    local alive, still = 0, {}
    for _, model in ipairs(models) do
        if high[model] - low[model] >= MIN_SWING then
            alive += 1
        else
            table.insert(still, model:GetAttribute("CreatureId"))
        end
    end
    check(("G5.8 : %d brainrots sur %d se balancent%s"):format(alive, #models,
        #still > 0 and (" ; immobiles : " .. table.concat(still, ", ")) or ""), alive == #models)

    -- §21.2 : l'aura est répliquée avec le modèle, le joueur la voit.
    local withAura, bare = 0, 0
    for _, model in ipairs(models) do
        if model:FindFirstChildWhichIsA("ParticleEmitter", true) or model:FindFirstChildWhichIsA("PointLight", true) then
            withAura += 1
        else
            bare += 1
        end
    end
    check(("§21.2 : %d auras recues par le client (attendu %d), %d modeles sans aura (attendu %d)")
        :format(withAura, AURA_EXPECTED, bare, BARE_EXPECTED),
        withAura == AURA_EXPECTED and bare == BARE_EXPECTED)
    camera.CameraType = Enum.CameraType.Custom
end

table.insert(T.lines, ("[SHOWCASE TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
