--!strict
--[[
    WaveSpawner.luau - Handles zombie spawning logic
    
    Single Responsibility: Spawn zombies with budget-based system
    - Spawn pools per phase (Trickle, Assault, Flag)
    - Budget calculation per wave
    - Zombie stat multipliers from stage config
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared.config.MapConfig)
local ZombieData = require(Shared.data.ZombieData)
local StageData = require(Shared.data.StageData)
local Logger = require(Shared.utils.Logger)
local Components = require(Shared.components)

-- Components
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local MovementComponent = Components.MovementComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local PlantFoodComponent = Components.PlantFoodComponent

-- Types
export type SpawnPhase = "Trickle" | "Assault" | "Flag"

export type SpawnConfig = {
    SpawnXOffset: number,
    TrickleRatio: number,
    AssaultRatio: number,
    FlagRatio: number,
}

export type WaveSpawner = {
    SetStageConfig: (self: WaveSpawner, stageConfig: StageData.StageConfig?) -> (),
    CalculateBudget: (self: WaveSpawner, waveNumber: number) -> number,
    GetPhaseBudget: (self: WaveSpawner, totalBudget: number, phase: SpawnPhase) -> number,
    SpawnZombie: (self: WaveSpawner, world: any, zombieType: string, lane: number) -> number,
    PickZombie: (self: WaveSpawner, phase: SpawnPhase, remainingBudget: number) -> string?,
    GetZombieCost: (self: WaveSpawner, zombieType: string) -> number,
    GetSpawnPosition: (self: WaveSpawner, lane: number) -> Vector3,
    RebuildSpawnPools: (self: WaveSpawner) -> (),
}

local WaveSpawner = {}
WaveSpawner.__index = WaveSpawner

-- Constants
local DEFAULT_SPAWN_COST = 10
-- Note: SPAWN_X_OFFSET is now handled by MapConfig via ZombieSpawns Attachments

-- State
local _stageConfig: StageData.StageConfig? = nil
local _spawnPools: {Trickle: {string}, Assault: {string}, Flag: {string}} = {
    Trickle = {"Basic", "Basic", "Basic", "Cone", "Imp"},
    Assault = {"Basic", "Basic", "Cone", "Cone", "Bucket", "Imp", "Imp"},
    Flag = {"Cone", "Cone", "Bucket", "Bucket", "Pole", "Imp"},
}

-- Lazy-load PlantFoodSystem to avoid circular deps
local _plantFoodSystem: any = nil
local function getPlantFoodSystem()
    if not _plantFoodSystem then
        local Server = script.Parent.Parent.Parent
        local Systems = Server.systems
        _plantFoodSystem = require(Systems.combat.PlantFoodSystem)
    end
    return _plantFoodSystem
end

-- Lazy-load Network
local _network: any = nil
local function getNetwork()
    if not _network then
        local Server = script.Parent.Parent.Parent
        _network = require(Server.network.generated)
    end
    return _network
end

function WaveSpawner.new(): WaveSpawner
    local self = setmetatable({}, WaveSpawner)
    return self :: any
end

-- Set stage configuration
function WaveSpawner:SetStageConfig(stageConfig: StageData.StageConfig?)
    _stageConfig = stageConfig
    self:RebuildSpawnPools()
end

-- Rebuild spawn pools based on stage config
function WaveSpawner:RebuildSpawnPools()
    if _stageConfig and _stageConfig.ZombiePool then
        local pool = _stageConfig.ZombiePool
        _spawnPools = {
            Trickle = pool,
            Assault = pool,
            Flag = pool,
        }
    else
        _spawnPools = {
            Trickle = {"Basic", "Basic", "Basic", "Cone", "Imp"},
            Assault = {"Basic", "Basic", "Cone", "Cone", "Bucket", "Imp", "Imp"},
            Flag = {"Cone", "Cone", "Bucket", "Bucket", "Pole", "Imp"},
        }
    end
end

-- Get zombie spawn cost
function WaveSpawner:GetZombieCost(zombieType: string): number
    local stats = ZombieData[zombieType]
    if stats and stats.SpawnCost then
        return stats.SpawnCost
    end
    return DEFAULT_SPAWN_COST
end

-- Get zombie health with stage multiplier
function WaveSpawner:GetZombieHealth(zombieType: string): number
    local stats = ZombieData[zombieType]
    if not stats then return 100 end
    
    local baseHealth = stats.Health
    local mult = if _stageConfig then (_stageConfig.ZombieHealthMult or 1) else 1
    return math.floor(baseHealth * mult)
end

-- Get zombie speed with stage multiplier
function WaveSpawner:GetZombieSpeed(zombieType: string): number
    local stats = ZombieData[zombieType]
    if not stats then return 1.5 end
    
    local baseSpeed = stats.Speed
    local mult = if _stageConfig then (_stageConfig.ZombieSpeedMult or 1) else 1
    return baseSpeed * mult
end

-- Calculate wave budget
function WaveSpawner:CalculateBudget(waveNumber: number): number
    if _stageConfig then
        return _stageConfig.BaseBudget + (waveNumber - 1) * _stageConfig.BudgetPerWave
    end
    -- Default fallback
    return 50 * math.pow(1.6, waveNumber)
end

-- Get budget for a specific phase
function WaveSpawner:GetPhaseBudget(totalBudget: number, phase: SpawnPhase): number
    local ratios = {
        Trickle = 0.2,
        Assault = 0.5,
        Flag = 0.3,
    }
    return totalBudget * ratios[phase]
end

-- Get spawn position for lane
function WaveSpawner:GetSpawnPosition(lane: number): Vector3
    -- Use MapConfig for spawn position (reads from Workspace Attachments or defaults)
    return MapConfig.GetZombieSpawn(lane)
end

-- Pick a random affordable zombie from pool
function WaveSpawner:PickZombie(phase: SpawnPhase, remainingBudget: number): string?
    local pool = _spawnPools[phase]
    local affordable = {}
    
    for _, zType in ipairs(pool) do
        if self:GetZombieCost(zType) <= remainingBudget then
            table.insert(affordable, zType)
        end
    end
    
    if #affordable == 0 then
        return nil
    end
    
    return affordable[math.random(1, #affordable)]
end

-- Spawn a zombie entity
function WaveSpawner:SpawnZombie(world: any, zombieType: string, lane: number, waveNumber: number?): number
    local stats = ZombieData[zombieType]
    if not stats then
        Logger.Error("WaveSpawner", `Invalid zombie type: {zombieType}`)
        return -1
    end
    
    local spawnPos = self:GetSpawnPosition(lane)
    local health = self:GetZombieHealth(zombieType)
    local speed = self:GetZombieSpeed(zombieType)
    
    -- Get zombie direction from MapConfig (adapts to visual config)
    local direction = MapConfig.GetZombieDirection()
    
    local entityId = world:spawn(
        PositionComponent({
            X = spawnPos.X,
            Y = spawnPos.Y,
            Z = spawnPos.Z
        }),
        HealthComponent({
            Current = health,
            Max = health
        }),
        MovementComponent({
            VelocityX = direction.X * speed,
            VelocityY = 0,
            VelocityZ = direction.Z * speed
        }),
        ZombieTypeComponent({
            ZombieType = zombieType,
            Lane = lane,
            SpawnTime = os.clock()
        })
    )
    
    -- Check if this zombie should be a Plant Food carrier (glowing)
    local PlantFoodSystemAPI = getPlantFoodSystem().API
    if PlantFoodSystemAPI.ShouldZombieBeGlowing() then
        world:insert(entityId, PlantFoodComponent({
            IsGlowing = true,
        }))
        Logger.Info("WaveSpawner", `🌟 GLOWING {zombieType} in lane {lane}`)
    end
    
    -- Broadcast to clients
    local Network = getNetwork()
    Network.ZombieSpawned.FireAll({
        EntityId = entityId,
        ZombieType = zombieType :: any,
        Lane = lane :: any,
        PositionX = spawnPos.X,
    })
    
    Logger.Debug("WaveSpawner", `Spawned {zombieType} in lane {lane}`)
    
    return entityId
end

-- Singleton instance
local _instance: WaveSpawner? = nil

function WaveSpawner.GetInstance(): WaveSpawner
    if not _instance then
        _instance = WaveSpawner.new()
    end
    return _instance :: any
end

return WaveSpawner
