--!nonstrict
--[[ TestWhiteMap
     Rôle    : vérifier la map blanche sans modifier le DataModel.
     Doc     : GAME_MASTER_V2 G1, D1.6 ; écarts validés rayon 230 et hauteurs lot D
     Étape   : 1, lot D ; compte de pièces remplacé par des invariants à l'étape 8, lot C (accord du Producer)
     Dépend  : BuildStructure, BuildWhiteMap, BuildWhiteMapZones ; BuildPedestals (étape 4)
     Exposé  : test manuel Studio ; complète, sans remplacer, le playtest humain
     Limite  : le compte fixe de 165 pièces était périmé depuis les 300 piédestaux de l'étape 4 : la map
               grandit à chaque étape, seuls ses invariants sont vérifiés.
]]
local map = workspace:FindFirstChild("Map_Monde1")
assert(map and map:IsA("Model"), "Map_Monde1 absent")
local pass, fail = 0, 0
local function check(name, ok)
    if ok then pass += 1 else fail += 1 end
    print((ok and "[OK] " or "[FAIL] ") .. name)
end
local function near(a, b) return math.abs(a - b) < 0.01 end
local parts, loose, duplicates, badNames, placeholders = 0, 0, 0, 0, 0
for _, node in ipairs(map:GetDescendants()) do
    if node:IsA("BasePart") then
        parts += 1
        if not node.Anchored then loose += 1 end
        if node.Name:match("^PROP_") then placeholders += 1 end
    end
    if not node.Name:match("^[%w_]+$") then badNames += 1 end
end
local parents = map:GetDescendants()
table.insert(parents, map)
for _, node in ipairs(parents) do
    local names = {}
    for _, child in ipairs(node:GetChildren()) do
        if names[child.Name] then duplicates += 1 end
        names[child.Name] = true
    end
end
check(("All %d map parts anchored"):format(parts), parts > 0 and loose == 0)
check(("No bare PROP_ placeholder part left (%d)"):format(placeholders), placeholders == 0)
local fullPlots = 0
for _, plot in ipairs(map.Plots:GetChildren()) do
    local pedestals = 0
    for _, child in ipairs(plot:FindFirstChild("Pedestals") and plot.Pedestals:GetChildren() or {}) do
        if child:IsA("BasePart") and child.Name:match("^Pedestal%d+$") then pedestals += 1 end
    end
    if pedestals == 25 then fullPlots += 1 end
end
check(("12 plots with 25 pedestals each (%d)"):format(fullPlots), fullPlots == 12)
check("No duplicate siblings", duplicates == 0)
check("Instance names ASCII alphanumeric or underscore", badNames == 0)
check("Streaming enabled", workspace.StreamingEnabled)
check("Baseplate preserved", workspace:FindFirstChild("Baseplate") ~= nil)
check("Spawn at (0,3,20)", workspace.SpawnLocation.Position == Vector3.new(0,3,20))
check("Shop surface level with hub", near(map.EggShop.Platform.Position.Y + map.EggShop.Platform.Size.Y / 2, 2))
check("Museum bottom on hub", near(map.Musee.DisplayCase.Position.Y - map.Musee.DisplayCase.Size.Y / 2, 2))
check("12 plots", #map.Plots:GetChildren() == 12)
check("12 alleys", #map.Ruelles:GetChildren() == 12)
check("24 connecting roads", #map.Liaisons:GetChildren() == 24)
check("Five egg pedestals", #map.EggShop:GetChildren() == 6)
check("Boss, gate and museum present", map:FindFirstChild("BossArena") and map:FindFirstChild("ColiseeGate") and map:FindFirstChild("Musee"))
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = {map.Plots}
for i = 1, 12 do
    local plot = map.Plots:FindFirstChild("Plot" .. i)
    check("Plot" .. i .. " dimensions / owner / radius", plot and plot:IsA("Part")
        and plot.Size == Vector3.new(80,1,80) and plot:GetAttribute("Owner") == ""
        and near(Vector3.new(plot.Position.X,0,plot.Position.Z).Magnitude, 230))
    if plot and plot:IsA("BasePart") then
        local clear = true
        for _, hit in ipairs(workspace:GetPartBoundsInBox(plot.CFrame, plot.Size - Vector3.new(0.02,0,0.02), overlap)) do
            if hit ~= plot and hit.Parent == map.Plots then clear = false end
        end
        check("Plot" .. i .. " no overlap", clear)
        local path = game:GetService("PathfindingService"):CreatePath({AgentRadius=2, AgentHeight=5, AgentCanJump=true})
        local ok = pcall(function()
            path:ComputeAsync(Vector3.new(0,4,20), plot.Position + Vector3.new(0,3,0))
        end)
        check("Spawn to Plot" .. i .. " path exists", ok and path.Status == Enum.PathStatus.Success)
    end
end
print(("[FINAL MAP TEST] %d OK / %d FAIL"):format(pass, fail))
assert(fail == 0, "Map validation failed")
