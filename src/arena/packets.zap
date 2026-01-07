-- Zap Network Schema
-- IDL definition for Plant vs Zombie network packets
-- Generated code will be type-safe Luau

opt server_output = "server/network/generated.luau"
opt client_output = "client/network/generated.luau"

-- Types for reusability
type RequestId = u16
type EntityId = u32
type Lane = u8(1..5)           -- Lane index 1-5 (ranged integer)
type Column = u8(1..9)         -- Column index 1-9 (ranged integer)
type PlantType = enum { 
    -- Starters
    Sunflower, Peashooter, WallNut,
    -- Tier 1
    PotatoMine, PuffShroom, SunShroom, Chomper, SnowPea,
    -- Tier 2
    Repeater, FumeShroom, Squash, Garlic, CherryBomb, TallNut,
    -- Tier 3
    Threepeater, Jalapeno, Spikeweed, Torchwood, CabbagePult, Pumpkin, ScaredyShroom, HypnoShroom,
    -- Tier 4
    SplitPea, KernelPult, Starfruit, Cactus, Blover, SeaShroom, TwinSunflower, MelonPult,
    -- Tier 5
    GatlingPea, GloomShroom, Cattail, WinterMelon, IceShroom, DoomShroom,
    -- Tier 6
    CobCannon, Marigold, GoldMagnet, Imitater,
    -- Utility
    LilyPad, FlowerPot, TangleKelp, GraveBuster, Plantern, UmbrellaLeaf, CoffeeBean, ExplodeONut
}
type ZombieType = enum { Basic, Cone, Bucket, Pole, Newspaper, Football, Imp, Flag }
type GamePhase = enum { Pregame, Wave, Intermission, GameOver }

-- ===================
-- CLIENT -> SERVER
-- ===================

-- Player wants to place a plant
event PlacePlantRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        RequestId: RequestId,
        PlantType: PlantType,
        Lane: Lane,
        Column: Column,
    }
}

-- Player collected sun (clicking on spawned sun)
event CollectSunRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        RequestId: RequestId,
        SunEntityId: EntityId,
    }
}

-- Player wants to shovel a plant
event ShovelPlantRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        RequestId: RequestId,
        PlantEntityId: EntityId,
    }
}

-- Player signals ready to start wave
event StartWaveRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        RequestId: RequestId,
    }
}

-- ===================
-- LOBBY EVENTS
-- ===================

-- Player requests teleport to Arena (Lobby -> Server)
event TeleportToArenaRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        StageId: string.utf8(..50),
        Deck: PlantType[1..6],  -- Max 6 plants in deck
    }
}

-- Server confirms teleport is starting (Server -> Client)
event TeleportToArenaResponse = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Success: boolean,
        ErrorCode: u8?,  -- 0=None, 1=InvalidStage, 2=InvalidDeck, 3=NotUnlocked
    }
}

-- ===================
-- SERVER -> CLIENT
-- ===================

-- Response to any client request (success/fail)
event RequestResponse = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        RequestId: RequestId,
        Success: boolean,
        ErrorCode: u8?,  -- 0=None, 1=NotEnoughSun, 2=CellOccupied, 3=InvalidPosition, 4=PlantNotOwned
    }
}

-- Server spawned a plant (broadcast to all clients)
event PlantSpawned = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
        PlantType: PlantType,
        Lane: Lane,
        Column: Column,
        OwnerId: f64,  -- Player UserId (f64 for Roblox compatibility)
    }
}

-- Server spawned a zombie (broadcast to all clients)
event ZombieSpawned = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
        ZombieType: ZombieType,
        Lane: Lane,
        PositionX: f32,  -- X position in world space
    }
}

-- Entity took damage
event EntityDamaged = {
    from: Server,
    type: Unreliable,  -- High frequency, can drop
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
        NewHealth: u16,
        DamageAmount: u16,
    }
}

-- Entity died (plant or zombie)
event EntityDied = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
    }
}

-- Projectile spawned
event ProjectileSpawned = {
    from: Server,
    type: Unreliable,  -- Visual only, can be predicted
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
        Lane: Lane,
        StartX: f32,
        TargetEntityId: EntityId?,  -- Optional target for homing
    }
}

-- Sun spawned (from Sunflower or sky)
event SunSpawned = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
        PositionX: f32,
        PositionY: f32,
        PositionZ: f32,
        Value: u8,  -- Sun value (typically 25 or 50)
        TargetY: f32, -- Y position to stop falling
    }
}

-- Sun position update (for falling animation)
event SunPositionUpdate = {
    from: Server,
    type: Unreliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
        PositionY: f32,
        Falling: boolean,
    }
}

-- Sun despawned (timeout or collected by another player)
event SunDespawned = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
    }
}

-- Base health updated (zombie reached house)
event BaseHealthUpdated = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        CurrentHealth: u16,
        MaxHealth: u16,
        DamageAmount: u16,
    }
}

-- Game over (victory or defeat)
event GameOver = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Victory: boolean,
        WaveReached: u8,
    }
}

-- Sun collected confirmation
event SunCollected = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        SunEntityId: EntityId,
        CollectorId: f64,  -- Player UserId (f64 for Roblox compatibility)
        NewTotal: u16,     -- Player's new sun total
    }
}

-- Wave started
event WaveStarted = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        WaveNumber: u8,
        ZombieCount: u16,
    }
}

-- Wave completed
event WaveCompleted = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        WaveNumber: u8,
        Survived: boolean,
    }
}

-- Preparation phase countdown
event PreparationTime = {
    from: Server,
    type: Unreliable,
    call: ManyAsync,
    data: struct {
        TimeRemaining: f32,
    }
}

-- Intermission phase countdown
event IntermissionTime = {
    from: Server,
    type: Unreliable,
    call: ManyAsync,
    data: struct {
        TimeRemaining: f32,
    }
}

-- Game phase changed
event GamePhaseChanged = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Phase: GamePhase,
    }
}

-- Zombie position update (batched, unreliable for smooth movement)
event ZombiePositionBatch = {
    from: Server,
    type: Unreliable,
    call: ManyAsync,
    data: struct {
        EntityIds: EntityId[..100],  -- Max 100 zombies per batch
        PositionsX: f32[..100],
    }
}

-- Full state sync (on player join or reconnect)
event FullStateSync = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        SunCount: u16,
        WaveNumber: u8,
        Phase: GamePhase,
        -- Detailed entity lists sent as separate events after this
    }
}

-- ===================
-- PROGRESSION SYSTEM
-- ===================

type UpgradeType = enum { Damage, Health, Cooldown }

-- Client requests to unlock a plant
event UnlockPlantRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        RequestId: RequestId,
        PlantType: PlantType,
    }
}

-- Client requests to purchase an upgrade
event PurchaseUpgradeRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        RequestId: RequestId,
        PlantType: PlantType,
        UpgradeType: UpgradeType,
    }
}

-- Server sends full player data (on join and after changes)
event PlayerDataSync = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Coins: u32,
        Gems: u32,
        XP: u32,
        Level: u8,
        LevelProgress: f32,
        UnlockedPlants: PlantType[..10],
        -- Upgrades sent as parallel arrays (PlantType, Damage, Health, Cooldown)
        UpgradePlantTypes: PlantType[..10],
        UpgradeDamage: u8[..10],
        UpgradeHealth: u8[..10],
        UpgradeCooldown: u8[..10],
    }
}

-- Server notifies client of coin gain (for UI feedback)
event CoinGained = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Amount: u16,
        TotalCoins: u32,
        SourceX: f32?,  -- World position for floating text (optional)
        SourceZ: f32?,
    }
}

-- Server notifies end of game rewards
event GameEndRewards = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Victory: boolean,
        CoinsEarned: u32,
        ZombiesKilled: u16,
        WavesCompleted: u8,
        BonusCoins: u16,
        StarRating: u8,  -- 1-3 stars based on base damage taken
        XPEarned: u16,   -- Total XP earned this game
        GemsEarned: u8,  -- Gems earned (3-star bonus, level ups)
        NewLevel: u8,    -- Player's new level (if leveled up)
        LevelsGained: u8, -- Number of levels gained this game
    }
}

-- Explosion VFX event (CherryBomb, PotatoMine)
event ExplosionVFX = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        PositionX: f32,
        PositionY: f32,
        PositionZ: f32,
        Radius: f32,
    }
}

-- ===================
-- PLANT FOOD SYSTEM
-- ===================

-- Client requests to use Plant Food on a plant
event PlantFoodRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        PlantEntityId: EntityId,  -- Target plant to power up
    }
}

-- Server notifies Plant Food charge collected
event PlantFoodCollected = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        CollectorId: f64,         -- Player who collected it
        NewChargeCount: u8,       -- Updated charge count (0-3)
        ZombieEntityId: EntityId, -- Zombie that dropped it
    }
}

-- Server notifies Plant Food activated on a plant
event PlantFoodActivated = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        PlantEntityId: EntityId,  -- Plant that was powered up
        PlantType: PlantType,     -- For ability VFX
        OwnerId: f64,             -- Player who activated it
    }
}

-- Server updates player's Plant Food charges
event PlantFoodChargeUpdate = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        ChargeCount: u8,  -- Current charges (0-3)
    }
}

-- ===================
-- XP / LEVEL SYSTEM
-- ===================

-- Server notifies player of XP gain
event XPGained = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Amount: u16,
        TotalXP: u32,
        CurrentLevel: u8,
        LevelProgress: f32,  -- 0.0 to 1.0 progress to next level
    }
}

-- Server notifies player of level up
event LevelUp = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        NewLevel: u8,
        RewardCoins: u16?,
        RewardGems: u8?,
        UnlockedPlant: PlantType?,
    }
}

-- ===================
-- GEMS SYSTEM
-- ===================

-- Server notifies player of gems earned
event GemsEarned = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Amount: u8,
        TotalGems: u32,
        Reason: u8,  -- 0=LevelUp, 1=3StarVictory, 2=FirstClear
    }
}

-- ===================
-- DECK SYSTEM
-- ===================

-- Client requests to save their deck loadout
event SaveDeckRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Slot1: PlantType?,
        Slot2: PlantType?,
        Slot3: PlantType?,
        Slot4: PlantType?,
        Slot5: PlantType?,
        Slot6: PlantType?,
    }
}

-- Server confirms deck saved
event DeckSaved = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Success: boolean,
        Error: string.utf8?,
    }
}

-- Server sends player's current deck (on join or after save)
event DeckSync = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Slot1: PlantType?,
        Slot2: PlantType?,
        Slot3: PlantType?,
        Slot4: PlantType?,
        Slot5: PlantType?,
        Slot6: PlantType?,
    }
}

-- ===================
-- STAGE SYSTEM
-- ===================

-- Client requests to start a specific stage
event StartStageRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        StageId: string.utf8,
    }
}

-- Server confirms stage started (sent to all players in game)
event StageStarted = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        StageId: string.utf8,
        StageName: string.utf8,
        WaveCount: u8,
    }
}

-- Server notifies stage completion with rewards
event StageComplete = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        StageId: string.utf8,
        Victory: boolean,
        Stars: u8,
        CoinsEarned: u32,
        XPEarned: u32,
        IsFirstClear: boolean,
        IsNewBest: boolean,
        PreviousStars: u8,
    }
}

-- Server notifies teleport countdown
event TeleportCountdown = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        TimeRemaining: u8,  -- Seconds until teleport
    }
}

-- Server syncs stage progression data (on join)
event StageProgressSync = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        CurrentStage: string.utf8,
        TotalStars: u16,
        -- Completed stages as parallel arrays
        CompletedStageIds: string.utf8[],
        CompletedStageStars: u8[],
    }
}