--!strict
--[[
    W1_1.luau - Stage "First Encounter"
    
    World 1, Level 1 - Tutorial level
    Introduces basic zombies, simple waves
]]

local StageRegistry = require(script.Parent.StageRegistry)

local Stage: StageRegistry.StageConfig = {
    -- Identity
    Id = "1-1",
    Name = "First Encounter",
    Description = "Your first battle against the zombie horde!",
    World = 1,
    Level = 1,
    
    -- Map to load
    MapId = "World1_Day",
    
    -- Waves with precise spawns
    Waves = {
        -- Wave 1: Very easy intro
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 3, Delay = 0 },
                { ZombieType = "Basic", Lane = 3, Delay = 5 },
            },
            PreDelay = 2,
        },
        
        -- Wave 2: Spread across lanes
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 2, Delay = 0 },
                { ZombieType = "Basic", Lane = 4, Delay = 2 },
                { ZombieType = "Basic", Lane = 3, Delay = 4 },
            },
        },
        
        -- Wave 3: More pressure
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 1, Delay = 0 },
                { ZombieType = "Basic", Lane = 3, Delay = 1 },
                { ZombieType = "Basic", Lane = 5, Delay = 2 },
                { ZombieType = "Basic", Lane = 2, Delay = 4 },
                { ZombieType = "Basic", Lane = 4, Delay = 5 },
            },
        },
    },
    
    -- Fallback for any budget-based needs
    DefaultZombiePool = {"Basic"},
    BaseBudget = 30,
    BudgetPerWave = 10,
    
    -- Easier difficulty
    SunStarting = 100,
    
    -- Star thresholds (base health %)
    Star1Health = 0,    -- Just survive
    Star2Health = 50,   -- Keep half health
    Star3Health = 90,   -- Nearly perfect
    
    -- Rewards
    CoinReward = 50,
    XPReward = 25,
    FirstClearBonus = 100,
}

return Stage
