--!strict
--[[ SlotRandom
     Rôle    : hasard fixé par tranche de temps : le même résultat sur tous les serveurs et après un redémarrage
               (minute d'une pluie, arbre ou astéroïdes d'une heure).
     Doc     : GAME_MASTER_V2 C4 (Pluie de Confettis), D2.2 (Forêt Sucrée, Douche de pépites), D4.2 (astéroïdes) ;
               décisions 67 et 106
     Étape   : 10 (sorti d'EventConfig à l'étape 16 pour servir aussi à WorldConfig)
     Dépend  : aucun
     Exposé  : Mix32(n), Start(slot, window, duration), Window(now, window, duration), Pick(slot, count, n)
     Limite  : prévisible par qui connaît le code ; à réserver à des rendez-vous partagés, jamais à un tirage de
               récompense individuelle (œufs, roulette : Random côté serveur).
]]
local SlotRandom = {}

local TWO32 = 4294967296

-- (a × b) mod 2^32 sans dépasser les 53 bits exacts d'un nombre Luau.
local function mul32(a: number, b: number): number
    return (a % 65536 * b + (a // 65536 * b) % 65536 * 65536) % TWO32
end

-- Brassage fmix32 de MurmurHash3 : deux entrées voisines donnent des sorties sans rapport.
function SlotRandom.Mix32(h: number): number
    h = bit32.bxor(h, bit32.rshift(h, 16))
    h = mul32(h, 0x85EBCA6B)
    h = bit32.bxor(h, bit32.rshift(h, 13))
    h = mul32(h, 0xC2B2AE35)
    return bit32.bxor(h, bit32.rshift(h, 16))
end

-- Début d'une fenêtre de `duration` secondes, à une minute tirée entre le début de la tranche `slot` (de `window`
-- secondes) et `duration` avant sa fin.
function SlotRandom.Start(slot: number, window: number, duration: number): number
    local minutes = (window - duration) // 60 + 1
    return slot * window + SlotRandom.Mix32(slot % TWO32) % minutes * 60
end

-- Fenêtre de la tranche en cours, sinon de la suivante : active ?, début, fin.
function SlotRandom.Window(now: number, window: number, duration: number): (boolean, number, number)
    local slot = math.floor(now / window)
    local start = SlotRandom.Start(slot, window, duration)
    if now >= start + duration then start = SlotRandom.Start(slot + 1, window, duration) end
    return now >= start, start, start + duration
end

-- `count` numéros distincts de 1 à `n`, fixes pour la tranche `slot`.
function SlotRandom.Pick(slot: number, count: number, n: number): {number}
    local picked: {number} = {}
    local seen: {[number]: boolean} = {}
    local wanted = math.min(count, n)
    local h = SlotRandom.Mix32(slot % TWO32)
    for _ = 1, 64 * n do
        if #picked >= wanted then break end
        local k = h % n + 1
        if not seen[k] then
            seen[k] = true
            table.insert(picked, k)
        end
        h = SlotRandom.Mix32((h + 1) % TWO32)
    end
    for k = 1, n do -- filet : jamais atteint en pratique, garantit `wanted` numéros
        if #picked >= wanted then break end
        if not seen[k] then
            seen[k] = true
            table.insert(picked, k)
        end
    end
    return picked
end

return table.freeze(SlotRandom)
