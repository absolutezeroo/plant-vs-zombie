--!strict
--[[
	ZombieSpawnSystem.luau - Server-side zombie spawning
	
	Priority: 100 (Simulation phase - early)
	
	Spawns zombies at the right edge of the grid.
	For MVP: spawns test zombies on a timer.
	Later: integrates with WaveManager for wave-based spawning.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local ZombieData = require(Shared.data.ZombieData)
local Logger = require(Shared.utils.Logger)

-- Network (script.Parent.Parent.Parent = server root, since we're in systems/units/)
local Server = script.Parent.Parent.Parent
local Network = require(Server.network.generated)

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local MovementComponent = Components.MovementComponent
local ZombieTypeComponent = Components.ZombieTypeComponent

-- Spawn config (MVP - simple timer)
-- NOTE: This system is DEPRECATED. Use WaveManagerSystem instead.
local SpawnConfig = {
	ENABLED = false,          -- DISABLED - WaveManagerSystem handles spawning now
	SPAWN_INTERVAL = 8,       -- Seconds between spawns
	SPAWN_VARIANCE = 3,       -- +/- variance
	SPAWN_X_OFFSET = 10,      -- Studs beyond grid edge
}

-- State
local _lastSpawnTime = 0
local _nextSpawnDelay = 5 -- First spawn after 5 seconds
local _zombieTypes = {"Basic", "Basic", "Basic", "Cone"} -- Weighted spawn pool

local function getSpawnPosition(lane: number): Vector3
	-- Spawn at right edge of grid + offset
	local x = GridConfig.GRID_WIDTH + SpawnConfig.SPAWN_X_OFFSET + GridConfig.GRID_ORIGIN_X
	local y = 0
	local z = (lane - 1) * GridConfig.CELL_SIZE + GridConfig.CELL_SIZE / 2 + GridConfig.GRID_ORIGIN_Z
	
	return Vector3.new(x, y, z)
end

local function spawnZombie(world: any, zombieType: string, lane: number): number
	local stats = ZombieData[zombieType]
	if not stats then
		Logger.Error("ZombieSpawn", `Invalid zombie type: {zombieType}`)
		return -1
	end
	
	local spawnPos = getSpawnPosition(lane)
	
	local entityId = world:spawn(
		PositionComponent({
			X = spawnPos.X,
			Y = spawnPos.Y,
			Z = spawnPos.Z
		}),
		HealthComponent({
			Current = stats.Health,
			Max = stats.Health
		}),
		MovementComponent({
			VelocityX = -stats.Speed, -- Move left towards house
			VelocityY = 0,
			VelocityZ = 0
		}),
		ZombieTypeComponent({
			ZombieType = zombieType,
			Lane = lane,
			SpawnTime = os.clock()
		})
	)
	
	-- Broadcast to all clients
	-- Note: Zap enum uses index, we need to map string to enum
	local zombieTypeEnum = ({
		Basic = "Basic",
		Cone = "Cone", 
		Bucket = "Bucket",
		Pole = "Pole",
		Newspaper = "Newspaper",
		Football = "Football"
	})[zombieType] or "Basic"
	
	Network.ZombieSpawned.FireAll({
		EntityId = entityId,
		ZombieType = zombieTypeEnum :: any,
		Lane = lane :: any,
		PositionX = spawnPos.X,
	})
	
	Logger.Info("ZombieSpawn", `Spawned {zombieType} zombie in lane {lane} (entity {entityId})`)
	
	return entityId
end

local function ZombieSpawnSystem(world)
	if not SpawnConfig.ENABLED then
		return
	end
	
	local currentTime = os.clock()
	
	-- Check if it's time to spawn
	if currentTime - _lastSpawnTime >= _nextSpawnDelay then
		-- Random lane and type
		local lane = math.random(1, GridConfig.GRID_LANES)
		local zombieType = _zombieTypes[math.random(1, #_zombieTypes)]
		
		spawnZombie(world, zombieType, lane)
		
		_lastSpawnTime = currentTime
		_nextSpawnDelay = SpawnConfig.SPAWN_INTERVAL + (math.random() - 0.5) * 2 * SpawnConfig.SPAWN_VARIANCE
	end
end

-- API for wave manager
local ZombieSpawnAPI = {}

function ZombieSpawnAPI.SpawnZombie(world: any, zombieType: string, lane: number): number
	return spawnZombie(world, zombieType, lane)
end

function ZombieSpawnAPI.SetEnabled(enabled: boolean)
	SpawnConfig.ENABLED = enabled
end

return {
	system = ZombieSpawnSystem,
	priority = 100,
	API = ZombieSpawnAPI,
}
