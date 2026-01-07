--!strict
--[[
    StageRegistry.luau - Dynamic stage loader and registry
    
    Loads stage configurations from individual module files.
    Each stage is defined in its own file (e.g., W1_1.luau, W2_3.luau)
    
    Usage:
        local StageRegistry = require(path.to.StageRegistry)
        local stage = StageRegistry.GetStage("1-1")
        local worldStages = StageRegistry.GetWorldStages(1)
]]

local _ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types
export type SpawnEntry = {
    ZombieType: string,
    Lane: number?,        -- If nil, random lane
    Delay: number?,       -- Delay in seconds from wave start (default 0)
    Count: number?,       -- Number of this zombie to spawn (default 1)
}

export type WaveDefinition = {
    -- Option 1: Precise spawns (takes priority)
    Spawns: {SpawnEntry}?,
    
    -- Option 2: Budget-based (fallback)
    Budget: number?,
    ZombiePool: {string}?,
    
    -- Wave timing overrides
    SpawnInterval: number?,    -- Override default spawn interval
    PreDelay: number?,         -- Wait before wave starts
}

export type StageConfig = {
    -- Identity
    Id: string,               -- "1-1", "2-3", etc.
    Name: string,
    Description: string?,
    World: number,
    Level: number,
    
    -- Map reference
    MapId: string,            -- "World1_Day" or specific "Map_1_1"
    
    -- Wave definitions
    Waves: {WaveDefinition},
    
    -- Fallback for budget-based spawning
    DefaultZombiePool: {string}?,
    BaseBudget: number?,
    BudgetPerWave: number?,
    
    -- Difficulty modifiers
    ZombieHealthMult: number?,
    ZombieSpeedMult: number?,
    SunStarting: number?,
    
    -- Boss configuration
    BossWave: number?,
    BossType: string?,
    
    -- Star rating thresholds (base health %)
    Star1Health: number,
    Star2Health: number,
    Star3Health: number,
    
    -- Rewards
    CoinReward: number,
    XPReward: number,
    FirstClearBonus: number?,
    
    -- Unlock requirements
    RequiredStage: string?,
    RequiredLevel: number?,
    
    -- Grid configuration overrides (optional - usually from map)
    GridLanes: number?,       -- Override default 5 lanes
    GridColumns: number?,     -- Override default 9 columns
}

-- Registry state
local _stages: {[string]: StageConfig} = {}
local _worldIndex: {[number]: {string}} = {}  -- World -> list of stage IDs
local _isInitialized = false

local StageRegistry = {}

--[[
    Initialize the registry by loading all stage modules
]]
function StageRegistry.Initialize()
    if _isInitialized then
        return
    end
    
    local stagesFolder = script.Parent
    
    -- Load all stage modules (W1_1, W1_2, W2_1, etc.)
    for _, child in stagesFolder:GetChildren() do
        if child:IsA("ModuleScript") and child ~= script then
            local stageName = child.Name
            
            -- Skip non-stage modules
            if not stageName:match("^W%d+_%d+") then
                continue
            end
            
            local success, stageConfig = pcall(function()
                return require(child) :: StageConfig
            end)
            
            if success and stageConfig and stageConfig.Id then
                StageRegistry._RegisterStage(stageConfig)
            else
                warn(`[StageRegistry] Failed to load stage: {stageName}`)
            end
        end
    end
    
    _isInitialized = true
    print(`[StageRegistry] Loaded {StageRegistry.GetStageCount()} stages`)
end

--[[
    Register a stage in the registry
]]
function StageRegistry._RegisterStage(config: StageConfig)
    local id = config.Id
    
    -- Store in main registry
    _stages[id] = config
    
    -- Index by world
    local world = config.World
    if not _worldIndex[world] then
        _worldIndex[world] = {}
    end
    table.insert(_worldIndex[world], id)
    
    -- Sort world stages by level
    table.sort(_worldIndex[world], function(a, b)
        local stageA = _stages[a]
        local stageB = _stages[b]
        return stageA.Level < stageB.Level
    end)
end

--[[
    Get a stage by ID
    @param stageId - Stage identifier (e.g., "1-1", "2-3")
    @return StageConfig or nil
]]
function StageRegistry.GetStage(stageId: string): StageConfig?
    if not _isInitialized then
        StageRegistry.Initialize()
    end
    return _stages[stageId]
end

--[[
    Get all stages in a world
    @param world - World number (1-5)
    @return Array of StageConfig
]]
function StageRegistry.GetWorldStages(world: number): {StageConfig}
    if not _isInitialized then
        StageRegistry.Initialize()
    end
    
    local stageIds: {string} = _worldIndex[world] or {}
    local stages: {StageConfig} = {}
    
    for _, id in ipairs(stageIds) do
        local stage = _stages[id]
        if stage then
            table.insert(stages, stage)
        end
    end
    
    return stages
end

--[[
    Get all registered stages
    @return Dictionary of stageId -> StageConfig
]]
function StageRegistry.GetAllStages(): {[string]: StageConfig}
    if not _isInitialized then
        StageRegistry.Initialize()
    end
    return _stages
end

--[[
    Get total number of stages
]]
function StageRegistry.GetStageCount(): number
    local count = 0
    for _ in _stages do
        count += 1
    end
    return count
end

--[[
    Get list of all world numbers that have stages
]]
function StageRegistry.GetWorlds(): {number}
    if not _isInitialized then
        StageRegistry.Initialize()
    end
    
    local worlds: {number} = {}
    for world in _worldIndex do
        table.insert(worlds, world)
    end
    table.sort(worlds)
    return worlds
end

--[[
    Check if a stage is unlocked for a player
    @param stageId - Stage to check
    @param completedStages - Set of completed stage IDs
    @param playerLevel - Player's current level
    @return boolean
]]
function StageRegistry.IsUnlocked(stageId: string, completedStages: {[string]: boolean}, playerLevel: number): boolean
    local stage = StageRegistry.GetStage(stageId)
    if not stage then
        return false
    end
    
    -- First stage is always unlocked
    if stage.World == 1 and stage.Level == 1 then
        return true
    end
    
    -- Check required stage
    if stage.RequiredStage then
        if not completedStages[stage.RequiredStage] then
            return false
        end
    end
    
    -- Check required level
    if stage.RequiredLevel then
        if playerLevel < stage.RequiredLevel then
            return false
        end
    end
    
    return true
end

--[[
    Get the next stage after the given one
    @param stageId - Current stage ID
    @return Next stage ID or nil
]]
function StageRegistry.GetNextStage(stageId: string): string?
    local stage = StageRegistry.GetStage(stageId)
    if not stage then
        return nil
    end
    
    -- Try next level in same world
    local nextId = `{stage.World}-{stage.Level + 1}`
    if StageRegistry.GetStage(nextId) then
        return nextId
    end
    
    -- Try first level of next world
    nextId = `{stage.World + 1}-1`
    if StageRegistry.GetStage(nextId) then
        return nextId
    end
    
    return nil
end

return StageRegistry
