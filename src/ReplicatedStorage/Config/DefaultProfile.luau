--!strict
--[[ DefaultProfile
     Rôle    : modèle du profil G2 ; ne jamais utiliser cette table comme profil vivant.
     Doc     : GAME_MASTER_V2 G2 ; PROMPT_EXECUTION_SABL_V4 §19
     Étape   : 2, lot B ; version 2 à l'étape 9, lot C (Réserve d'or) ; version 3 au lot F1 (coffre-fort)
     Dépend  : aucun
     Exposé  : modèle de données ; copies via Migrations:Create()
     Limite  : Reserve = true marque un brainrot rangé en Réserve d'or par un rebirth (C3, décision 32) :
               conservé, non productif, utilisable en PvP. Absent, il est hors réserve.
               LastSeenAt = 0 : dernière présence inconnue, le prochain retour ne verse rien (décision 44).
]]
return {
    DataVersion = 3,
    Money = 0, Clicks = 0, Rebirths = 0, Playtime = 0, Level = 1,
    WorldUnlocked = 1,

    Creatures = {},
    -- { {Uid="abc", Id="tralalero", Tier=1, PlacedSlot=nil, InPvPTeam=nil, Reserve=nil}, ... }

    Base = { Plot = nil, Slots = 3, Turret = 0, Alarm = 0, Generator = 0,
             Trap = 0, Vault = 0, TrainingRing = 0, Decor = {} },

    ShieldEndsAt = 0, VulnerableEndsAt = 0, LastStealAttempt = 0,
    LastSeenAt = 0, -- dernière présence (os.time), base du revenu hors ligne du coffre-fort

    PvP = {
        Elo1v1 = 1000, Elo2v2 = 1000,
        ArenaTokens = 0,
        Season = { Id = 1, PeakElo = 1000, Wins = 0, Losses = 0,
                   UltimatesUsed = 0, BestRank = 0 },
        Loadouts = { A = {nil,nil,nil}, B = nil },   -- 3 Uids par loadout
        Tournament = { Entered = false, Wins = 0, Titles = {} },
    },

    Clan = { Id = nil, Donated = 0, Role = nil, WarPoints = 0 },

    Quests = { List = {}, ResetAt = 0, Streak = 0, LastDailyClaim = 0 },
    Stats = { Steals = 0, Defends = 0, Fusions = 0, EggsOpened = 0,
              Earned = 0, ArenaWins = 0, ArenaLosses = 0 },
    Purchases = { Gamepasses = {}, DevProducts = {} },
    Codes = {}, Settings = { Music = true, SFX = true },
}
