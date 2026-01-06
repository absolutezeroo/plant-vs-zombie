-- Zap Network Schema
-- IDL definition for Plant vs Zombie network packets
-- Generated code will be type-safe Luau

opt server_output = "../../server/network/generated.luau"
opt client_output = "../../client/network/generated.luau"

-- Types for reusability
type RequestId = u16
type EntityId = u32
type Lane = u8(1..5)           -- Lane index 1-5 (ranged integer)
type Column = u8(1..9)         -- Column index 1-9 (ranged integer)
type PlantType = enum { Peashooter, Sunflower, WallNut, SnowPea, CherryBomb, PotatoMine, Repeater }
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

