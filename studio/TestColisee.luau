--!nonstrict
--[[ TestColisee
     Rôle    : vérifier le Colisée placeholder construit par BuildColisee, sans modifier le DataModel.
     Doc     : GAME_MASTER_V2 D5.3, D5.5, D5.6, E2 ; PROMPT_EXECUTION_SABL_V4 §25.2 (lot MAP), §31.13 lot B ;
               Q1-Q2 du lot B ; décision 116
     Étape   : 13, lot B
     Dépend  : BuildColisee exécuté (Studio en Édition, ou faux Studio Lune : tools/lune_build_test.luau)
     Exposé  : bilan ; aucune écriture
     Limite  : géométrie, couleurs et ancrage seulement ; le rendu, la navigation et la performance se jugent en
               Play (§22.3). Les positions se lisent sur CFrame (Lune n'expose pas Position).
]]
local Workspace = game:GetService("Workspace")
local map = Workspace:FindFirstChild("Map_Colisee")
assert(map, "Map_Colisee absent")
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 0.01) end
local function pos(p) return p.CFrame.Position end
local function top(p) return pos(p).Y + p.Size.Y / 2 end
local function radius(p) local v = pos(p); return math.sqrt(v.X * v.X + v.Z * v.Z) end
local function hex(p) return p.Color:ToHex():upper() end
local O = 1000
local function children(path)
    local node = map
    for name in string.gmatch(path, "[^%.]+") do node = node and node:FindFirstChild(name) end
    local parts = {}
    if node then
        for _, d in ipairs(node:GetChildren()) do if d:IsA("BasePart") then table.insert(parts, d) end end
    end
    return parts, node
end

-- Généralités (§25.2 lot MAP, §15).
check("Map_Colisee construit (LotB_v1)", map:GetAttribute("ColiseeBuild") == "LotB_v1")
local parts, loose, badNames, outside = 0, 0, 0, 0
for _, d in ipairs(map:GetDescendants()) do
    if d:IsA("BasePart") then
        parts += 1
        if not d.Anchored then loose += 1 end
        local y = pos(d).Y
        if y < O - 2 or y > O + 45 then outside += 1 end
    end
    if not d.Name:match("^[%w_]+$") then badNames += 1 end
end
local duplicates = 0
for _, node in ipairs(map:GetDescendants()) do
    local seen = {}
    for _, child in ipairs(node:GetChildren()) do
        if seen[child.Name] then duplicates += 1 end
        seen[child.Name] = true
    end
end
check(("272 pièces, toutes ancrées (%d, %d libres)"):format(parts, loose), parts == 272 and loose == 0)
check("D5.6 : tout entre Y = 998 et Y = 1045", outside == 0)
check("Noms sans accent ni espace, aucun doublon entre voisins", badNames == 0 and duplicates == 0)

-- Sol et fosse (D5.6).
local sol = map.Sol.Sol
-- Disque = cylindre couché : diamètre sur Y et Z, épaisseur sur X (tournée à la verticale).
check("Sol : disque r = 90, dessus à Y = 1001", sol.Shape == Enum.PartType.Cylinder and near(sol.Size.Y, 180)
    and near(sol.Size.Z, 180) and near(pos(sol).Y + sol.Size.X / 2, 1001))
local walls = {}
for _, p in ipairs(children("Fosse")) do if p.Name:match("^Muret") then table.insert(walls, p) end end
local wallOk = #walls == 22
for _, w in ipairs(walls) do wallOk = wallOk and near(w.Size.Y, 6) and near(radius(w), 30.5) and near(top(w), 1007) end
check("Fosse : 22 murets de 6 à r = 30 (entrée sud ouverte)", wallOk)
local blue, red = map.Fosse.CercleBleu, map.Fosse.CercleRouge
check("D5.6 : cercle bleu r = 4 à (−10, 1, 0), #4CC9F0", near(blue.Size.Y, 8) and near(pos(blue).X, -10)
    and near(pos(blue).Y, O + 1) and near(pos(blue).Z, 0) and hex(blue) == "4CC9F0")
check("D5.6 : cercle rouge r = 4 à (10, 1, 0), #E63946", near(red.Size.Y, 8) and near(pos(red).X, 10)
    and near(pos(red).Y, O + 1) and hex(red) == "E63946")

-- Gradins (D5.3, Q2).
for _, tier in ipairs({{"N1", 52.5, 1007, "B8A88A"}, {"N2", 67.5, 1013, "B8A88A"}, {"N3", 82.5, 1019, "FFD23F"}}) do
    local segs = children("Gradins." .. tier[1])
    local ok = #segs == 22
    for _, s in ipairs(segs) do ok = ok and near(radius(s), tier[2]) and near(top(s), tier[3]) and hex(s) == tier[4] end
    check(("Gradins %s : 22 segments de 15°, r moyen %.1f, dessus à Y = %d"):format(tier[1], tier[2], tier[3]), ok)
end

-- Coque (D5.6).
local shellOk = true
for level, wanted in ipairs({22, 24, 24}) do
    local segs = children("Coque.Anneau" .. level)
    shellOk = shellOk and #segs == wanted
    for _, s in ipairs(segs) do shellOk = shellOk and near(radius(s), 91) and hex(s) == "FFD23F" end
end
local topRing = children("Coque.Anneau3")
check("Coque or r = 90 : 3 anneaux (22, 24, 24), sommet à Y = 1025", shellOk and near(top(topRing[1]), 1025))

-- Écran géant (D5.3).
local screen = map.EcranGeant
check("Écran 40 × 20 au sud, au-dessus de N3, avec SurfaceGui", near(screen.Size.X, 40) and near(screen.Size.Y, 20)
    and pos(screen).Z > 0 and pos(screen).Y - 10 >= 1019 and screen:FindFirstChildWhichIsA("SurfaceGui") ~= nil)

-- Tunnels (D5.3) et couloir dégagé.
local ta, tb = map.Tunnels.TunnelA, map.Tunnels.TunnelB
check("Tunnels A bleu et B rouge, larges de 6, de la fosse (z = 30) au hall (z = 92)", near(ta.Size.X, 6)
    and near(tb.Size.X, 6) and hex(ta) == "4CC9F0" and hex(tb) == "E63946" and near(pos(ta).Z - ta.Size.Z / 2, 30)
    and near(pos(ta).Z + ta.Size.Z / 2, 92))
local blocking = 0
for _, path in ipairs({"Fosse", "Gradins.N1", "Gradins.N2", "Gradins.N3", "Coque.Anneau1"}) do
    for _, p in ipairs(children(path)) do
        if p.Name:match("^Muret") or p.Name:match("^Segment") or p.Name:match("^Arcade") then
            for _, sx in ipairs({-0.5, 0.5}) do
                for _, sz in ipairs({-0.5, 0.5}) do
                    local corner = p.CFrame * Vector3.new(sx * p.Size.X, 0, sz * p.Size.Z)
                    if math.abs(corner.X) < 7.5 and corner.Z > 30.5 and corner.Z < 92 then blocking += 1 end
                end
            end
        end
    end
end
check("Couloir des tunnels (|x| < 7,5) libre de murets, gradins et coque", blocking == 0)

-- Hall (Q1) et sol continu à l'entrée.
local hallSlabs = {}
for _, p in ipairs(children("Hall")) do if p.Name:match("^Dalle") then table.insert(hallSlabs, p) end end
local hallOk = #hallSlabs == 12
for _, s in ipairs(hallSlabs) do hallOk = hallOk and pos(s).Z > 92 and near(top(s), 1001) and hex(s) == "E9ECEF" end
check("Hall : demi-disque r = 45 en marbre, hors de la coque au sud", hallOk)
local h = map.Hall
check("Hall : 3 classements, boutique, NPC 1v1 bleu et 2v2 rouge, porte spectateur", h:FindFirstChild("ClassementGlobal")
    and h:FindFirstChild("ClassementServeur") and h:FindFirstChild("ClassementSaison") and h:FindFirstChild("BoutiqueTokens")
    and hex(h.NPC_File1v1) == "4CC9F0" and hex(h.NPC_File2v2) == "E63946" and h:FindFirstChild("PorteSpectateur") ~= nil)
local lodgeOk = #h.Loges:GetChildren() == 4
for _, lodge in ipairs(h.Loges:GetChildren()) do
    lodgeOk = lodgeOk and near(lodge.Sol.Size.X, 10) and near(lodge.Sol.Size.Z, 10) and pos(lodge.Sol).Z > 92
end
check("Hall : 4 loges 10 × 10", lodgeOk)
check("Décision 116 : SpawnColisee dans le hall, désactivé", h.SpawnColisee:IsA("SpawnLocation")
    and h.SpawnColisee.Enabled == false and pos(h.SpawnColisee).Z > 92)
local parvis = h:FindFirstChild("Parvis")
local holes = 0
for x = -23, 23 do
    local z = math.sqrt(90 * 90 - x * x)
    while z < 92 do
        local covered = parvis ~= nil and math.abs(x - pos(parvis).X) <= parvis.Size.X / 2
            and math.abs(z - pos(parvis).Z) <= parvis.Size.Z / 2
        if not covered then holes += 1 end
        z += 0.25
    end
end
check(("Entrée : pas de vide entre le sol (r = 90) et le hall (z = 92) (%d points découverts)"):format(holes),
    parvis ~= nil and holes == 0 and near(top(parvis), 1000.95))

-- Spectateurs (D5.3) et braseros (D5.6).
local crowd = children("Spectateurs")
local crowdOk = #crowd == 60
for _, p in ipairs(crowd) do
    local v = pos(p)
    local angle = math.deg(math.atan2(v.Z, v.X)) % 360
    crowdOk = crowdOk and near(radius(p), 67.5) and near(v.Y - p.Size.Y / 2, 1013) and not (angle > 75 and angle < 105)
end
check("60 spectateurs posés sur N2, hors de l'entrée sud", crowdOk)
local fires = children("Braseros")
local fireOk = #fires == 8
for _, p in ipairs(fires) do
    if p.Name:match("^Brasero") then fireOk = fireOk and hex(p) == "FFD23F" and near(radius(p), 38) end
end
check("4 braseros or (et leurs flammes) dans le couloir de la fosse", fireOk)

local summary = ("[COLISEE TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
