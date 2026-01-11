-- Zap Network Schema
-- UNIFIED IDL definition for Plant vs Zombie network packets
-- This single file serves both Arena and Lobby places
-- Generated code will be type-safe Luau

-- Output paths (relative to this file)
opt server_output = "generated/server.luau"
opt client_output = "generated/client.luau"

-- ==========================
-- SHARED TYPES
-- ==========================

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

type ZombieType = enum { Basic, Cone, Bucket, Pole, Newspaper, Football, Imp, Flag, ScreenDoor, Ladder, Balloon, Gargantuar, MiniGargantuar }
type GamePhase = enum { Pregame, Wave, Intermission, GameOver }

type MutationType = enum {
    Fire, Inferno,
    Ice, Frost,
    Electric, Tesla,
    Toxic, Venomous,
    Shadow, Void,
    Solar, Radiant,
    Reinforced, Fortified,
    Primal, Savage,
    Swift, Hasty
}

type ProjectileVariant = enum {
    Pea,         -- Standard green pea
    FrozenPea,   -- Blue ice pea (SnowPea, Winter Melon)
    FirePea,     -- Flaming pea (Torchwood enhanced)
    Spore,       -- Mushroom spores (PuffShroom, SeaShroom)
    Fume,        -- Purple fumes (FumeShroom, GloomShroom)
    Cabbage,     -- Cabbage lobbed projectile
    Kernel,      -- Corn kernel
    Butter,      -- Butter (stun)
    Melon,       -- Melon slice
    Star,        -- Star projectile (Starfruit)
    Spike,       -- Cactus spike
    Seed         -- Generic seed
}

-- ==========================
-- ARENA: CLIENT -> SERVER
-- ==========================

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

-- Client requests to use Plant Food on a plant
event PlantFoodRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        PlantEntityId: EntityId,
    }
}

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

-- Client requests to start a game (Arena)
event StartGameRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        WorldId: string.utf8,
        Difficulty: string.utf8,
    }
}

-- ==========================
-- LOBBY: CLIENT -> SERVER
-- ==========================

-- Player requests teleport to Arena
event TeleportToArenaRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        WorldId: string.utf8(..50),
        Difficulty: string.utf8(..20),
        Deck: PlantType[1..6],
    }
}

-- Client requests to leave the current pad
event LeavePadRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {}
}

-- Client requests to save new deck (lobby)
event SaveDeck = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Deck: PlantType[1..6],
    }
}

-- Client requests to purchase a plant
event PurchasePlantRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        PlantType: PlantType,
    }
}

-- Client requests full player data sync
event RequestPlayerData = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {}
}

-- Client requests to purchase a mutation for a plant
event PurchaseMutationRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        PlantType: PlantType,
        MutationType: MutationType,
    }
}

-- Client requests to equip an owned mutation on a plant
event EquipMutationRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        PlantType: PlantType,
        MutationType: MutationType,
    }
}

-- Client requests to unequip a mutation from a plant
event UnequipMutationRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        PlantType: PlantType,
        MutationType: MutationType,
    }
}

-- ==========================
-- DEV COMMANDS (Client -> Server)
-- ==========================

-- Dev command types
type DevCommandType = enum {
    GiveCoins,
    GiveGems,
    SetLevel,
    UnlockAllPlants,
    UnlockPlant,
    AddMutation,
    ResetData,
    GiveXP,
    MaxResources
}

-- Generic dev command request
event DevCommand = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Command: DevCommandType,
        StringArg: string.utf8(..50)?,
        NumberArg: i32?,
    }
}

-- Dev command response
event DevCommandResponse = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Success: boolean,
        Message: string.utf8(..200),
    }
}

-- ==========================
-- ARENA: SERVER -> CLIENT
-- ==========================

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
        OwnerId: f64,
        Mutations: MutationType[0..8],
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
        PositionX: f32,
    }
}

-- Entity took damage (Reliable to ensure UI health bars stay in sync)
event EntityDamaged = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
        NewHealth: u16,
        DamageAmount: u16,
        ShieldDestroyed: boolean?,  -- True when zombie shield is destroyed
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

-- Projectile spawned (Unreliable: visual-only, client can handle missing spawns)
event ProjectileSpawned = {
    from: Server,
    type: Unreliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
        Lane: Lane,
        StartX: f32,
        TargetEntityId: EntityId?,
        Variant: ProjectileVariant?,  -- Visual type (default: Pea)
        IsFrozen: boolean?,           -- Has slow effect
        IsEnhanced: boolean?,         -- Fire enhanced by Torchwood
    }
}

-- Projectile hit a target (for impact VFX) - Reliable: critical for gameplay feedback
event ProjectileHit = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,           -- Projectile entity ID
        PositionX: f32,               -- Impact position
        PositionY: f32,
        PositionZ: f32,
        Variant: ProjectileVariant?,  -- Visual type for VFX
        IsFrozen: boolean?,           -- For ice impact VFX
        IsEnhanced: boolean?,         -- For fire impact VFX
    }
}

-- Projectile despawned without hitting (out of bounds, max range)
event ProjectileDespawned = {
    from: Server,
    type: Unreliable,
    call: ManyAsync,
    data: struct {
        EntityId: EntityId,
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
        Value: u8,
        TargetY: f32,
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

-- Sun collected confirmation
event SunCollected = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        SunEntityId: EntityId,
        CollectorId: f64,
        NewTotal: u16,
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
        EntityIds: EntityId[..100],
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
        UnlockedPlants: PlantType[..100],
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
        SourceX: f32?,
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
        StarRating: u8,
        XPEarned: u16,
        GemsEarned: u8,
        NewLevel: u8,
        LevelsGained: u8,
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

-- Plant Food charge collected
event PlantFoodCollected = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        CollectorId: f64,
        NewChargeCount: u8,
        ZombieEntityId: EntityId,
    }
}

-- Plant Food activated on a plant
event PlantFoodActivated = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        PlantEntityId: EntityId,
        PlantType: PlantType,
        OwnerId: f64,
    }
}

-- Plant Food charges update
event PlantFoodChargeUpdate = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        ChargeCount: u8,
    }
}

-- XP gain notification
event XPGained = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Amount: u16,
        TotalXP: u32,
        CurrentLevel: u8,
        LevelProgress: f32,
    }
}

-- Level up notification
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

-- Deck saved confirmation
event DeckSaved = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Success: boolean,
        Error: string.utf8?,
    }
}

-- Deck sync (on join or after save)
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

-- Game started confirmation
event GameStarted = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        WorldId: string.utf8,
        Difficulty: string.utf8,
        WaveCount: u8,
    }
}

-- Teleport countdown
event TeleportCountdown = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        TimeRemaining: u8,
    }
}

-- Progression data sync
event ProgressionSync = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Level: u16,
        TotalXP: u32,
        Coins: u32,
        Gems: u32,
        UnlockedPlants: string.utf8[],
        OwnedSkins: string.utf8[],
    }
}

-- ==========================
-- MAP LOADING EVENTS
-- ==========================

-- Server sends map configuration to client
event MapConfigSync = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        MapId: string.utf8,
        GridCornerAX: f32,
        GridCornerAY: f32,
        GridCornerAZ: f32,
        GridCornerBX: f32,
        GridCornerBY: f32,
        GridCornerBZ: f32,
        GridY: f32,
        CellWidth: f32,
        CellDepth: f32,
        BasePositionX: f32,
        BasePositionY: f32,
        BasePositionZ: f32,
        ZombieDirectionX: f32,
        ZombieDirectionZ: f32,
    }
}

-- Server notifies map loading started
event MapLoadingStarted = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        MapId: string.utf8,
        TotalAssets: u16,
    }
}

-- Map loading progress
event MapLoadingProgress = {
    from: Server,
    type: Unreliable,
    call: ManyAsync,
    data: struct {
        LoadedAssets: u16,
        TotalAssets: u16,
        AssetName: string.utf8(..64),
    }
}

-- Map loading complete
event MapLoadingComplete = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        MapId: string.utf8,
        Success: boolean,
    }
}

-- ==========================
-- LOBBY: SERVER -> CLIENT
-- ==========================

-- Teleport to arena response
event TeleportToArenaResponse = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Success: boolean,
        ErrorCode: u8?,  -- 0=None, 1=InvalidWorld, 2=InvalidDeck, 3=InvalidDifficulty
        ErrorMessage: string.utf8(..100)?,
    }
}

-- Sync player data to client (coins, unlocked plants, etc.)
event SyncPlayerData = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Coins: u32,
        Gems: u32,
        Level: u8,
        XP: u32,
    }
}

-- Show battle results after returning from Arena
event ShowResults = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        WorldId: string.utf8(..50),
        Difficulty: string.utf8(..20),
        Victory: boolean,
        Stars: u8,
        CoinsEarned: u32,
        XPEarned: u32,
    }
}

-- Update pad state (server broadcasts to all clients)
event PadStateUpdate = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        PadId: string.utf8(..100),
        WorldId: string.utf8(..50),
        Difficulty: string.utf8(..20),
        PlayersCount: u8,
        MaxPlayers: u8,
        CountdownRemaining: u8?,
        PlayerNames: string.utf8(..200)?,
    }
}

-- Server tells client they joined a pad
event JoinedPad = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        PadId: string.utf8(..100),
        WorldId: string.utf8(..50),
        Difficulty: string.utf8(..20),
        Position: Vector3,
    }
}

-- Server tells client they left a pad
event LeftPad = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {}
}

-- Deck changed notification
event DeckChanged = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Deck: PlantType[1..6],
    }
}

-- Purchase plant response
event PurchasePlantResponse = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Success: boolean,
        PlantType: PlantType,
        ErrorCode: u8?,  -- 0=None, 1=AlreadyOwned, 2=NotEnoughCoins, 3=InvalidPlant
        NewCoins: u32?,
    }
}

-- Sync unlocked plants to client
event SyncUnlockedPlants = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        UnlockedPlants: PlantType[0..48],
    }
}

-- Full player data sync (extended)
event FullPlayerDataSync = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Coins: u32,
        Gems: u32,
        Level: u8,
        XP: u32,
        TotalXPForNextLevel: u32,
        GamesPlayed: u32,
        GamesWon: u32,
        ZombiesKilled: u32,
        PlantsPlaced: u32,
        UnlockedPlants: PlantType[0..48],
        Deck: PlantType[0..6],
    }
}

-- ==========================
-- MUTATION SYSTEM (LOBBY)
-- ==========================

-- Mutation purchase response
event PurchaseMutationResponse = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Success: boolean,
        PlantType: PlantType,
        MutationType: MutationType,
        ErrorCode: u8?,  -- 0=None, 1=AlreadyHas, 2=NotEnoughCoins, 3=InvalidMutation, 4=Incompatible, 5=LevelTooLow, 6=PlantNotUnlocked
        NewCoins: u32?,
    }
}

-- Equip mutation response
event EquipMutationResponse = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Success: boolean,
        PlantType: PlantType,
        MutationType: MutationType,
        ErrorCode: u8?,  -- 0=None, 1=NotOwned, 2=AlreadyEquipped, 3=Incompatible
    }
}

-- Unequip mutation response  
event UnequipMutationResponse = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Success: boolean,
        PlantType: PlantType,
        MutationType: MutationType,
    }
}

-- Sync plant mutations to client (individual plant)
event SyncPlantMutations = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        PlantType: PlantType,
        OwnedMutations: MutationType[0..8],
        EquippedMutations: MutationType[0..8],
    }
}

-- Sync all mutations for all plants at once
event SyncAllMutations = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        OwnedMutations: struct {
            PlantType: PlantType,
            Mutations: MutationType[0..8],
        }[0..48],
        EquippedMutations: struct {
            PlantType: PlantType,
            Mutations: MutationType[0..8],
        }[0..48],
    }
}
