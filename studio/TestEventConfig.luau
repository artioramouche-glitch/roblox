--!nonstrict
--[[ TestEventConfig
     Rôle    : vérifier le calendrier des événements du lot C et le calcul de chance de la décision 59.
     Doc     : GAME_MASTER_V2 C4, C3, B2 ; PROMPT_EXECUTION_SABL_V4 §31.10 lot C ; décision 59 ; Q1-Q3 du lot C
     Étape   : 10, lot C (configuration)
     Dépend  : ReplicatedStorage.Config.EventConfig, EggConfig, CreatureConfig ; ReplicatedStorage.Shared.LuckUtil
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : ne prouve que la configuration et le calcul ; le déclenchement réel, le Boss, le ciel et l'affichage
               des odds se testent en Play.
]]
local RS = game:GetService("ReplicatedStorage")
local config = assert(RS:FindFirstChild("Config"), "Config absent")
local shared = assert(RS:FindFirstChild("Shared"), "Shared absent")
local Ev = require(assert(config:FindFirstChild("EventConfig"), "EventConfig absent"))
local E = require(assert(config:FindFirstChild("EggConfig"), "EggConfig absent"))
local Luck = require(assert(shared:FindFirstChild("LuckUtil"), "LuckUtil absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-9 end

-- Dates UTC de référence (date -u) : vendredi 2 octobre 2026 à 0 h, puis samedi, dimanche, lundi.
local H = 3600
local DAY = 86400
local FRI, SAT, SUN, MON = 1790899200, 1790985600, 1791072000, 1791158400

-- Chiffres de C4 et des Q1-Q3, recopiés ici.
check("Frénésie : 3 h, 15 min, ×10", Ev.Frenzy.Period == 10800 and Ev.Frenzy.Duration == 900 and Ev.Frenzy.Luck == 10)
check("Boss : 2 h, 5 min", Ev.Boss.Period == 7200 and Ev.Boss.Duration == 300)
check("Confettis : tranche 4 h, 10 min, ×2", Ev.Confetti.Window == 14400 and Ev.Confetti.Duration == 600
    and Ev.Confetti.IncomeMult == 2)
check("Week-end : 48 h, ×2", Ev.Weekend.Duration == 172800 and Ev.Weekend.Luck == 2)
check("Plafond de chance 50 %", Ev.LuckCap == 50)

local function at(name, fn, now, active, start, finish)
    local a, s, f = fn(now)
    check(("%s → %s %d-%d"):format(name, tostring(active), start - FRI, finish - FRI),
        a == active and s == start and f == finish)
end
at("Frénésie ven. 0:00:00", Ev.FrenzyAt, FRI, true, FRI, FRI + 900)
at("Frénésie ven. 0:14:59", Ev.FrenzyAt, FRI + 899, true, FRI, FRI + 900)
at("Frénésie ven. 0:15:00", Ev.FrenzyAt, FRI + 900, false, FRI + 3 * H, FRI + 3 * H + 900)
at("Frénésie ven. 3:00:00", Ev.FrenzyAt, FRI + 3 * H, true, FRI + 3 * H, FRI + 3 * H + 900)
at("Frénésie ven. 21:14:59", Ev.FrenzyAt, FRI + 21 * H + 899, true, FRI + 21 * H, FRI + 21 * H + 900)
at("Frénésie ven. 23:59:59", Ev.FrenzyAt, FRI + DAY - 1, false, SAT, SAT + 900)
at("Boss ven. 0:04:59", Ev.BossAt, FRI + 299, true, FRI, FRI + 300)
at("Boss ven. 0:05:00", Ev.BossAt, FRI + 300, false, FRI + 2 * H, FRI + 2 * H + 300)
at("Boss ven. 2:00:00", Ev.BossAt, FRI + 2 * H, true, FRI + 2 * H, FRI + 2 * H + 300)
at("Week-end ven. 23:59:59", Ev.WeekendAt, SAT - 1, false, SAT, MON)
at("Week-end sam. 0:00:00", Ev.WeekendAt, SAT, true, SAT, MON)
at("Week-end dim. 23:59:59", Ev.WeekendAt, MON - 1, true, SAT, MON)
at("Week-end lun. 0:00:00", Ev.WeekendAt, MON, false, SAT + 7 * DAY, MON + 7 * DAY)
check("Dimanche au cœur du week-end", (Ev.WeekendAt(SUN + 12 * H)))

-- Q2 : une pluie par tranche de 4 h, à la minute, entière dans sa tranche ; 6 pluies (60 min) par jour.
local SLOTS = 3000
local first = FRI // 14400
local inSlot, onMinute, oneRain, offsets, repeats = true, true, true, {}, 0
for slot = first, first + SLOTS - 1 do
    local slotStart = slot * 14400
    local _, start, finish = Ev.ConfettiAt(slotStart)
    inSlot = inSlot and start >= slotStart and finish <= slotStart + 14400 and finish - start == 600
    onMinute = onMinute and start % 60 == 0
    local a1, s1 = Ev.ConfettiAt(start)
    local a2, s2 = Ev.ConfettiAt(start + 599)
    local _, s3 = Ev.ConfettiAt(start + 600)
    oneRain = oneRain and a1 and s1 == start and a2 and s2 == start and s3 ~= start
    local offset = (start - slotStart) // 60
    if #offsets > 0 and offsets[#offsets] == offset then repeats += 1 end
    table.insert(offsets, offset)
end
check(("Confettis : %d tranches, pluie entière dans sa tranche"):format(SLOTS), inSlot)
check("Confettis : début à la minute pile", onMinute)
check("Confettis : actif de début à fin, puis pluie suivante", oneRain)
local minutesPerDay = true
for day = 0, 29 do
    local active = 0
    for minute = 0, 1439 do
        if Ev.ConfettiAt(FRI + day * DAY + minute * 60) then active += 1 end
    end
    minutesPerDay = minutesPerDay and active == 60
end
check("Confettis : 60 min actives par jour sur 30 jours", minutesPerDay)
local low, high, sum = math.huge, -math.huge, 0
for _, offset in ipairs(offsets) do
    low, high, sum = math.min(low, offset), math.max(high, offset), sum + offset
end
local mean = sum / #offsets
check(("Confettis : minutes réparties (min %d, max %d, moyenne %.1f, attendu ≈ 115)"):format(low, high, mean),
    low < 15 and high > 215 and mean > 100 and mean < 130)
check(("Confettis : %d tranches voisines à la même minute (hasard ≈ 13)"):format(repeats), repeats < 40)
local a1, s1 = Ev.ConfettiAt(FRI + 5000)
local a2, s2 = Ev.ConfettiAt(FRI + 5000)
check("Confettis : même réponse à chaque appel", a1 == a2 and s1 == s2)

-- Q3 : les chances se multiplient.
check("Chance ven. 1 h, sans rebirth = 1", Ev.LuckMultiplier(FRI + H, 0) == 1)
check("Chance ven. 1 h, R1 = 1,1", near(Ev.LuckMultiplier(FRI + H, 0.10), 1.1))
check("Chance Frénésie seule = 10", Ev.LuckMultiplier(FRI, 0) == 10)
check("Chance Week-end seul = 2", Ev.LuckMultiplier(SAT + H, 0) == 2)
check("Chance Frénésie × Week-end × R1 = 22", near(Ev.LuckMultiplier(SAT, 0.10), 22))
local badBonus = true
for _, bonus in ipairs({-1, 0 / 0, math.huge, "0.1", false}) do
    badBonus = badBonus and Ev.LuckMultiplier(FRI + H, bonus) == 1
end
check("Chance : bonus de rebirth invalide ignoré", badBonus and Ev.LuckMultiplier(FRI + H, nil) == 1)

-- Décision 59 : seul le palier le plus rare monte, jusqu'à 50 %, les autres au prorata.
local street, secret = E:Get("egg_street").odds, E:Get("egg_secret").odds
local s10 = Luck.Apply(street, 10)
check("Street ×10 : Légendaire 2 → 20", s10.Legendary == 20)
check("Street ×10 : Commun 10 → 8,163 (prorata 80/98)", near(s10.Common, 10 * 80 / 98))
check("Interdit ×10 : Secret 0,5 → 5", Luck.Apply(secret, 10).Secret == 5)
check("Street ×22 : Légendaire 2 → 44", Luck.Apply(street, 22).Legendary == 44)
local b10 = Luck.Apply(E:Get("egg_basic").odds, 10)
check("Basic ×10 : Rare plafonné à 50, Commun 50", b10.Rare == 50 and b10.Common == 50)
check("Golden ×22 : Mythique plafonné à 50", Luck.Apply(E:Get("egg_golden").odds, 22).Mythic == 50)
local unchanged = true
for _, multiplier in ipairs({1, 0.5, 0 / 0, "10", false}) do
    local r = Luck.Apply(street, multiplier)
    unchanged = unchanged and r.Common == 10 and r.Rare == 55 and r.Epic == 33 and r.Legendary == 2
end
check("Multiplicateur ≤ 1 ou invalide : odds inchangées", unchanged and Luck.Apply(street, nil).Legendary == 2)
check("La table de l'œuf n'est jamais modifiée", street.Common == 10 and street.Rare == 55 and street.Epic == 33
    and street.Legendary == 2 and secret.Secret == 0.5)
local rarest = {egg_basic = "Rare", egg_street = "Legendary", egg_golden = "Mythic", egg_mythic = "God",
    egg_secret = "Secret", egg_dessert = "Secret", egg_abyss = "Secret", egg_cosmic = "Secret"}
local rarestOk, sums, prorata = true, true, true
for _, egg in ipairs(E.Eggs) do
    rarestOk = rarestOk and Luck.Rarest(egg.odds) == rarest[egg.id]
    for _, multiplier in ipairs({1.1, 2, 10, 22, 1000}) do
        local r = Luck.Apply(egg.odds, multiplier)
        local total = 0
        for _, weight in pairs(r) do total += weight end
        sums = sums and near(total, 100) and r[rarest[egg.id]] <= 50
        for a, wa in pairs(egg.odds) do
            for b, wb in pairs(egg.odds) do
                if a ~= rarest[egg.id] and b ~= rarest[egg.id] and wb > 0 then
                    prorata = prorata and near(r[a] / r[b], wa / wb)
                end
            end
        end
    end
end
check("Palier le plus rare des 8 œufs", rarestOk)
check("8 œufs × 5 multiplicateurs : somme 100, plus rare ≤ 50 %", sums)
check("8 œufs × 5 multiplicateurs : rapports entre autres paliers conservés", prorata)

local summary = ("[EVENT CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
