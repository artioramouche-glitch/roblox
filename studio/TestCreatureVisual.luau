--!nonstrict
--[[ TestCreatureVisual
     Rôle    : vérifier l'apparence servie par CreatureVisual : modèle, repli, et auras de rareté.
     Doc     : GAME_MASTER_V2 B0, B1, §21.2 (auras) ; PROMPT_EXECUTION_SABL_V4 §21.4, §25.2, Loi 5
     Étape   : 7, lot B
     Dépend  : Play serveur ; Creatures.CreatureVisual, ServerStorage.CreatureModels,
               Config.CreatureConfig ; lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; aucun profil lu ou écrit, les modèles construits sont détruits en fin de course
     Limite  : contrôle la présence et la couleur des effets, pas leur rendu à l'écran. Le tremblement
               d'écran des SECRET est un effet client au spawn, hors de ce module.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local CreatureConfig = require(ReplicatedStorage.Config.CreatureConfig)
local CreatureVisual = require(Server.Creatures.CreatureVisual)

local SECRET_COLOR = Color3.fromHex("3A0CA3") -- §21.2

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local built = {}
local function build(id)
    local model = CreatureVisual.Build(id, 1)
    table.insert(built, model)
    return model
end

local function effects(model)
    local particles, light, trail = nil, nil, nil
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ParticleEmitter") then particles = d
        elseif d:IsA("PointLight") then light = d
        elseif d:IsA("Trail") then trail = d end
    end
    return particles, light, trail
end

-- Le socle : un modèle du batch, nommé, pivoté au sol, sans repli.
local common = build("noobini")
check("Modele du batch servi pour noobini", common:IsA("Model") and common.Name == "CRT_noobini"
    and common:GetAttribute("CreatureId") == "noobini" and common:GetAttribute("Placeholder") == false)
check("Pivot au sol et PrimaryPart present", common.PrimaryPart ~= nil
    and math.abs(common:GetPivot().Position.Y) < 0.001)
check("§21.2 : un Commun n'a aucune aura", (function()
    local p, l, t = effects(common)
    return p == nil and l == nil and t == nil
end)())

-- Loi 5 : un identifiant sans modèle retombe sur le cube gris, sans aura non plus.
local missing = build("identifiant_inexistant")
check("Loi 5 : cube gris de repli pour un identifiant inconnu", missing:GetAttribute("Placeholder") == true
    and missing:FindFirstChild("Cube") ~= nil)
check("Creature inconnue : aucune aura", (function()
    local p, l, t = effects(missing)
    return p == nil and l == nil and t == nil
end)())

-- §21.2 rareté par rareté, sur des créatures réelles du monde 1.
local epic = build("cappuccino")
local epicParticles, epicLight, epicTrail = effects(epic)
check("§21.2 Epique : particules legeres, sans lumiere ni trainee",
    CreatureConfig:Get("cappuccino").rarity == "Epic"
    and epicParticles ~= nil and epicLight == nil and epicTrail == nil)

local legendary = build("frigo_camelo")
local legParticles, legLight = effects(legendary)
check("§21.2 Legendaire : halo dore, sans particules",
    CreatureConfig:Get("frigo_camelo").rarity == "Legendary"
    and legLight ~= nil and legParticles == nil)

local mythic = build("bombardiro")
local mythParticles, mythLight = effects(mythic)
check("§21.2 Mythique : particules et lumiere",
    CreatureConfig:Get("bombardiro").rarity == "Mythic" and mythParticles ~= nil and mythLight ~= nil)

local god = build("tralalero")
local godParticles, godLight, godTrail = effects(god)
check("§21.2 God : aura doree intense, sans trainee",
    CreatureConfig:Get("tralalero").rarity == "God" and godParticles ~= nil and godLight ~= nil
    and godTrail == nil and godLight.Brightness > mythLight.Brightness)

local secret = build("garama")
local secretParticles, secretLight, secretTrail = effects(secret)
check("§21.2 SECRET : aura noire-violette 3A0CA3 avec trainee",
    CreatureConfig:Get("garama").rarity == "Secret" and secretParticles ~= nil and secretTrail ~= nil
    and secretLight ~= nil and secretLight.Color == SECRET_COLOR
    and secretParticles.Color.Keypoints[1].Value == SECRET_COLOR)

-- L'aura ne doit pas déplacer la créature ni la faire flotter.
check("L'aura ne change ni la hauteur ni le pivot", math.abs(god:GetPivot().Position.Y) < 0.001
    and math.abs(god:GetExtentsSize().Y - 5.5) < 0.1)

for _, model in ipairs(built) do model:Destroy() end
table.insert(T.lines, ("[VISUAL TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
