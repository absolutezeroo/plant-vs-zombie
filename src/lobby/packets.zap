-- Zap Network Schema for Lobby
-- Handles teleport requests and lobby-specific events

opt server_output = "server/network/generated.luau"
opt client_output = "client/network/generated.luau"
opt remote_scope = "LOBBY"

-- Plant type enum (same as arena)
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

-- ===================
-- CLIENT -> SERVER
-- ===================

-- Player requests teleport to Arena
event TeleportToArenaRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        WorldId: string.utf8(..50),     -- World ID from WorldData
        Difficulty: string.utf8(..20),  -- Difficulty from DifficultyData
        Deck: PlantType[1..6],  -- Max 6 plants in deck
    }
}

-- ===================
-- SERVER -> CLIENT
-- ===================

-- Server responds to teleport request
event TeleportToArenaResponse = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Success: boolean,
        ErrorCode: u8?,  -- 0=None, 1=InvalidStage, 2=InvalidDeck, 3=NotUnlocked, 4=TeleportFailed
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
        Stars: u8,  -- 0-3
        CoinsEarned: u32,
        XPEarned: u32,
    }
}

-- ===================
-- PHYSICAL LOBBY (3D)
-- ===================

-- Update pad state (server broadcasts to all clients)
event PadStateUpdate = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        PadId: string.utf8(..100),  -- Unique pad identifier
        WorldId: string.utf8(..50),
        Difficulty: string.utf8(..20),
        PlayersCount: u8,
        MaxPlayers: u8,
        CountdownRemaining: u8?,    -- nil = no countdown
        PlayerNames: string.utf8(..200)?, -- Comma-separated player names
    }
}

-- Server tells client they joined a pad (lock movement, show UI)
event JoinedPad = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        PadId: string.utf8(..100),
        WorldId: string.utf8(..50),
        Difficulty: string.utf8(..20),
        Position: Vector3,  -- Center of pad to teleport to
    }
}

-- Server tells client they left a pad (unlock movement)
event LeftPad = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {}
}

-- Client requests to leave the current pad
event LeavePadRequest = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {}
}

-- Player changed their deck
event DeckChanged = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Deck: PlantType[1..6],
    }
}

-- Client requests to save new deck
event SaveDeck = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Deck: PlantType[1..6],
    }
}
