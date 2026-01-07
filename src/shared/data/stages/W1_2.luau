--!strict
--[[
    W1_2.luau - Stage "Growing Horde"
    
    World 1, Level 2 - More zombies, introduces Flag zombie
]]

local StageRegistry = require(script.Parent.StageRegistry)

local Stage: StageRegistry.StageConfig = {
    -- Identity
    Id = "1-2",
    Name = "Growing Horde",
    Description = "The zombies are getting organized...",
    World = 1,
    Level = 2,
    
    -- Map to load (same as 1-1, Day map)
    MapId = "World1_Day",
    
    -- Waves
    Waves = {
        -- Wave 1
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 2, Delay = 0 },
                { ZombieType = "Basic", Lane = 4, Delay = 2 },
                { ZombieType = "Basic", Lane = 3, Delay = 4 },
            },
        },
        
        -- Wave 2
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 1, Delay = 0 },
                { ZombieType = "Basic", Lane = 3, Delay = 1 },
                { ZombieType = "Basic", Lane = 5, Delay = 2 },
                { ZombieType = "Basic", Lane = 2, Delay = 4 },
            },
        },
        
        -- Wave 3: Introduces Flag zombie
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 2, Delay = 0 },
                { ZombieType = "Basic", Lane = 4, Delay = 1 },
                { ZombieType = "Flag", Lane = 3, Delay = 2 },
                { ZombieType = "Basic", Lane = 1, Delay = 3 },
                { ZombieType = "Basic", Lane = 5, Delay = 4 },
            },
        },
        
        -- Wave 4: Final push
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 1, Delay = 0 },
                { ZombieType = "Basic", Lane = 2, Delay = 0.5 },
                { ZombieType = "Basic", Lane = 3, Delay = 1 },
                { ZombieType = "Basic", Lane = 4, Delay = 1.5 },
                { ZombieType = "Basic", Lane = 5, Delay = 2 },
                { ZombieType = "Flag", Lane = 3, Delay = 4 },
            },
        },
    },
    
    DefaultZombiePool = {"Basic", "Flag"},
    BaseBudget = 40,
    BudgetPerWave = 15,
    
    SunStarting = 50,
    
    Star1Health = 0,
    Star2Health = 50,
    Star3Health = 85,
    
    CoinReward = 75,
    XPReward = 35,
    FirstClearBonus = 75,
    
    RequiredStage = "1-1",
}

return Stage
