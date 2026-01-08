--!strict
--[[
	SunSpawnSystem.luau - Server-side sun resource spawning
	
	Priority: 300 (Resource phase)
	
	Spawns sun orbs from the sky at regular intervals.
	Sun falls with simulated gravity until reaching ground level.
	Despawns after lifetime expires if not collected.
	
	Broadcasts sun events to all clients via Zap.
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - manages sun spawning
	- Dispose(): Reset spawn timing state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local Logger = require(Shared.utils.Logger)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent

-- Lazy-load WaveManager to check game state
local _waveManager: any = nil
local function getWaveManager()
	if not _waveManager then
		local WaveManagerSystemModule = require(Server.systems.wave.WaveManagerSystem)
		_waveManager = WaveManagerSystemModule.WaveManager
	end
	return _waveManager
end

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local SunComponent = Components.SunComponent

-- Sun spawning config
local SunConfig = {
	SPAWN_INTERVAL = 7,       -- Seconds between sky sun spawns
	SPAWN_INTERVAL_VARIANCE = 3, -- +/- variance (so 4-10 seconds)
	SUN_VALUE = 25,           -- Sun value when collected
	LIFE_TIME = 12,           -- Seconds until despawn
	SPAWN_HEIGHT_OFFSET = 25, -- Y offset above grid for spawn
	FALL_SPEED = 4,           -- Studs per second
	GROUND_OFFSET = 1.5,      -- Y offset above GridY for landing
}

-- Get ground Y from MapConfig (dynamic per map)
local function getGroundY(): number
	return MapConfig.GetConfig().GridY
end

-- Get spawn height for sky suns
local function getSpawnHeight(): number
	return getGroundY() + SunConfig.SPAWN_HEIGHT_OFFSET
end

-- State
local _lastSpawnTime = 0
local _nextSpawnDelay = 0

local function getRandomGridPosition(): (number, number, number)
	-- Random column and lane within grid
	local column = math.random(1, GridConfig.GRID_COLUMNS)
	local lane = math.random(1, GridConfig.GRID_LANES)
	
	-- Convert to world position using MapConfig (visual config or defaults)
	local cellCenter = MapConfig.GridToWorld(column, lane)
	local cellW, cellD = MapConfig.GetCellSize()
	
	-- Add some random offset within cell
	local offsetX = (math.random() - 0.5) * cellW * 0.6
	local offsetZ = (math.random() - 0.5) * cellD * 0.6
	
	return cellCenter.X + offsetX, getSpawnHeight(), cellCenter.Z + offsetZ
end

local function spawnSkySun(world: any): number
	local x, y, z = getRandomGridPosition()
	local targetY = getGroundY() + SunConfig.GROUND_OFFSET + math.random() * 2
	
	local entityId = world:spawn(
		PositionComponent({
			X = x,
			Y = y,
			Z = z
		}),
		SunComponent({
			Value = SunConfig.SUN_VALUE,
			SpawnTime = os.clock(),
			Lifetime = SunConfig.LIFE_TIME,
			IsFalling = true,
			TargetY = targetY,
			SourceType = "Sky",
		})
	)
	
	-- Broadcast to all clients
	Network.SunSpawned.FireAll({
		EntityId = entityId,
		PositionX = x,
		PositionY = y,
		PositionZ = z,
		Value = SunConfig.SUN_VALUE,
		TargetY = targetY,
	})
	
	Logger.Debug("SunSpawnSystem", `Spawned sky sun entity {entityId} at ({math.floor(x)}, {math.floor(y)}, {math.floor(z)})`)
	
	return entityId
end

local function SunSpawnSystem(world)
	local currentTime = os.clock()
	
	-- Only spawn sun during "Playing" state (not Waiting, Preparation, Intermission, Victory, or Defeat)
	local WaveManager = getWaveManager()
	local gameState = WaveManager.GetGameState()
	
	if gameState ~= "Playing" then
		-- Reset spawn timer when not playing so sun spawns quickly when game starts
		_lastSpawnTime = currentTime
		return
	end
	
	-- Check if it's time to spawn new sun
	if currentTime - _lastSpawnTime >= _nextSpawnDelay then
		spawnSkySun(world)
		_lastSpawnTime = currentTime
		_nextSpawnDelay = SunConfig.SPAWN_INTERVAL + (math.random() - 0.5) * 2 * SunConfig.SPAWN_INTERVAL_VARIANCE
	end
	
	-- Process falling sun and despawning
	for id, pos, sun in world:query(PositionComponent, SunComponent) do
		-- Despawn check
		local age = currentTime - sun.SpawnTime
		if age >= sun.Lifetime then
			world:despawn(id)
			
			-- Broadcast despawn to all clients
			Network.SunDespawned.FireAll({
				EntityId = id,
			})
			
			Logger.Debug("SunSpawnSystem", `Sun {id} despawned (lifetime expired)`)
			continue
		end
		
		-- Falling physics
		if sun.IsFalling then
			local newY = pos.Y - SunConfig.FALL_SPEED * (1/60) -- Assume 60 FPS
			local targetY = sun.TargetY or (getGroundY() + SunConfig.GROUND_OFFSET)
			
			if newY <= targetY then
				-- Landed
				world:insert(id, 
					PositionComponent({
						X = pos.X,
						Y = targetY,
						Z = pos.Z
					}),
					SunComponent({
						Value = sun.Value,
						SpawnTime = sun.SpawnTime,
						Lifetime = sun.Lifetime,
						IsFalling = false,
						TargetY = targetY,
						SourceType = sun.SourceType,
					})
				)
				
				-- Broadcast landed state
				Network.SunPositionUpdate.FireAll({
					EntityId = id,
					PositionY = targetY,
					Falling = false,
				})
			else
				-- Still falling - update position
				world:insert(id, PositionComponent({
					X = pos.X,
					Y = newY,
					Z = pos.Z
				}))
			end
		end
	end
end

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	_lastSpawnTime = 0
	_nextSpawnDelay = 0
end

return {
	_name = "SunSpawnSystem",
	priority = 300, -- Resource phase
	system = SunSpawnSystem,
	Init = Init,
	Dispose = Dispose,
}
