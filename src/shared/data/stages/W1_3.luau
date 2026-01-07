--!strict
--[[
    W1_3.luau - Stage "Cone Heads"
    
    World 1, Level 3 - Introduces Cone zombies
]]

local StageRegistry = require(script.Parent.StageRegistry)

local Stage: StageRegistry.StageConfig = {
    Id = "1-3",
    Name = "Cone Heads",
    Description = "Traffic cones provide extra protection!",
    World = 1,
    Level = 3,
    
    MapId = "World1_Day",
    
    Waves = {
        -- Wave 1: Warm up
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 2, Delay = 0 },
                { ZombieType = "Basic", Lane = 4, Delay = 2 },
                { ZombieType = "Cone", Lane = 3, Delay = 4 },
            },
        },
        
        -- Wave 2
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 1, Delay = 0 },
                { ZombieType = "Cone", Lane = 3, Delay = 1 },
                { ZombieType = "Basic", Lane = 5, Delay = 2 },
                { ZombieType = "Cone", Lane = 2, Delay = 4 },
            },
        },
        
        -- Wave 3
        {
            Spawns = {
                { ZombieType = "Cone", Lane = 1, Delay = 0 },
                { ZombieType = "Cone", Lane = 5, Delay = 1 },
                { ZombieType = "Basic", Lane = 3, Delay = 2 },
                { ZombieType = "Basic", Lane = 2, Delay = 3 },
                { ZombieType = "Basic", Lane = 4, Delay = 4 },
            },
        },
        
        -- Wave 4
        {
            Spawns = {
                { ZombieType = "Basic", Lane = 1, Delay = 0 },
                { ZombieType = "Basic", Lane = 2, Delay = 0.5 },
                { ZombieType = "Cone", Lane = 3, Delay = 1 },
                { ZombieType = "Basic", Lane = 4, Delay = 1.5 },
                { ZombieType = "Basic", Lane = 5, Delay = 2 },
                { ZombieType = "Cone", Lane = 3, Delay = 4 },
                { ZombieType = "Flag", Lane = 3, Delay = 5 },
            },
        },
        
        -- Wave 5: Big finish
        {
            Spawns = {
                { ZombieType = "Cone", Lane = 1, Delay = 0 },
                { ZombieType = "Cone", Lane = 2, Delay = 0.5 },
                { ZombieType = "Cone", Lane = 3, Delay = 1 },
                { ZombieType = "Cone", Lane = 4, Delay = 1.5 },
                { ZombieType = "Cone", Lane = 5, Delay = 2 },
                { ZombieType = "Basic", Count = 5, Delay = 3 },  -- 5 basics in random lanes
                { ZombieType = "Flag", Lane = 3, Delay = 6 },
            },
        },
    },
    
    DefaultZombiePool = {"Basic", "Cone", "Flag"},
    BaseBudget = 50,
    BudgetPerWave = 20,
    
    Star1Health = 0,
    Star2Health = 40,
    Star3Health = 80,
    
    CoinReward = 100,
    XPReward = 50,
    FirstClearBonus = 75,
    
    RequiredStage = "1-2",
}

return Stage
