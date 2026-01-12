--!strict
--[[
	SunSpawnSystem.luau - Server-side sun resource spawning
	
	Priority: 300 (Resource phase)
	
	Spawns sun orbs from the sky at regular intervals.
	Sun falls with simulated gravity until reaching ground level.
	
	MULTIPLAYER: Each player gets their own sky suns (not shared).
]]

-- 1. IMPORTS
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local MapConfig = require(Shared.config.MapConfig)
local GameConstants = require(Shared.config.GameConstants)
local EntityPool = require(Shared.utils.EntityPool)
local ChanceUtils = require(Shared.utils.ChanceUtils)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules (lazy-loaded)
local Server = script.Parent.Parent.Parent

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	SPAWN_INTERVAL = GameConstants.Economy.SKY_SUN_SPAWN_INTERVAL,
	SPAWN_INTERVAL_VARIANCE = GameConstants.Economy.SKY_SUN_SPAWN_VARIANCE,
	SUN_VALUE = GameConstants.Economy.SKY_SUN_VALUE,
	LIFE_TIME = GameConstants.Economy.SKY_SUN_LIFETIME,
	SPAWN_HEIGHT_OFFSET = GameConstants.Economy.SKY_SUN_SPAWN_HEIGHT,
	FALL_SPEED = GameConstants.Economy.SKY_SUN_FALL_SPEED,
	GROUND_OFFSET = 1.5,
	MIN_DT = 1 / 120,
	MAX_DT = 1 / 15,
})

-- 3. STATE
local State = {
	IsInitialized = false,
	LastSpawnTime = 0,
	NextSpawnDelay = 0,
	WaveService = nil :: any,
	CachedGridY = 0 :: number,
	CachedCellWidth = 0 :: number,
	CachedCellDepth = 0 :: number,
}

-- Helper: Get WaveService (lazy load)
local function getWaveService()
	if not State.WaveService then
		State.WaveService = require(Server.services.WaveService)
	end
	return State.WaveService
end

-- Helper: Get ground Y from cached config
local function getGroundY(): number
	return State.CachedGridY
end

-- Helper: Get spawn height for sky suns
local function getSpawnHeight(): number
	return getGroundY() + CONFIG.SPAWN_HEIGHT_OFFSET
end

-- Helper: Get random grid position
local function getRandomGridPosition(): (number, number, number)
	local column, lane = ChanceUtils.RandomGridCell()
	local cellCenter = MapConfig.GridToWorld(column, lane) -- Safe: MapConfig initialized at bootstrap
	local cellW = State.CachedCellWidth
	local cellD = State.CachedCellDepth

	local offsetX = ChanceUtils.RandomOffset(cellW * 0.3)
	local offsetZ = ChanceUtils.RandomOffset(cellD * 0.3)

	return cellCenter.X + offsetX, getSpawnHeight(), cellCenter.Z + offsetZ
end

-- Helper: Spawn sky sun for a specific player
local function spawnSkySunForPlayer(world: any, ownerId: number): number
	local x, y, z = getRandomGridPosition()
	local targetY = getGroundY() + CONFIG.GROUND_OFFSET + ChanceUtils.RandomFloat(0, 2)

	local entityId = EntityPool.Spawn(
		Components.PositionComponent({
			X = x,
			Y = y,
			Z = z,
		}),
		Components.SunComponent({
			Value = CONFIG.SUN_VALUE,
			SpawnTime = os.clock(),
			Lifetime = CONFIG.LIFE_TIME,
			IsFalling = true,
			TargetY = targetY,
			SourceType = "Sky",
			OwnerId = ownerId, -- Only this player can collect this sun
		})
	)

	if not entityId then
		return -1
	end

	-- Broadcast to all clients (they'll grey out suns they can't collect)
	Network.SunSpawned.FireAll({
		EntityId = entityId,
		PositionX = x,
		PositionY = y,
		PositionZ = z,
		Value = CONFIG.SUN_VALUE,
		TargetY = targetY,
		OwnerId = ownerId,
	})

	return entityId
end

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end

	-- Pre-cache config values to avoid yield in OnStep
	if MapConfig.IsInitialized() then
		local config = MapConfig.GetConfigIfReady()
		State.CachedGridY = if config then config.GridY else 0
	else
		-- Fallback: force init (should not happen if bootstrap is correct)
		State.CachedGridY = MapConfig.GetConfig().GridY
	end

	-- Cache cell size
	local cellW, cellD = MapConfig.GetCellSize()
	State.CachedCellWidth = cellW
	State.CachedCellDepth = cellD

	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	State.IsInitialized = false
	State.LastSpawnTime = 0
	State.NextSpawnDelay = 0
	State.WaveService = nil
	State.CachedGridY = 0
	State.CachedCellWidth = 0
	State.CachedCellDepth = 0
end

-- 6. MAIN LOOP
local function OnStep(world)
	local currentTime = os.clock()

	-- Only spawn sun during "Playing" state
	local WaveService = getWaveService()
	local gameState = WaveService.GetGameState()

	if gameState ~= "Playing" then
		State.LastSpawnTime = currentTime
		return
	end

	-- No SUN_DROP_SCALE needed anymore - each player gets their own sun
	-- The economy is already balanced since suns are individual

	-- Check if it's time to spawn new sun
	local baseInterval = CONFIG.SPAWN_INTERVAL + ChanceUtils.RandomOffset(CONFIG.SPAWN_INTERVAL_VARIANCE)
	if currentTime - State.LastSpawnTime >= State.NextSpawnDelay then
		-- Spawn one sun for EACH player (individual economy)
		for _, player in Players:GetPlayers() do
			spawnSkySunForPlayer(world, player.UserId)
		end
		State.LastSpawnTime = currentTime
		State.NextSpawnDelay = baseInterval
	end

	-- Process falling sun and despawning
	for id, pos, sun in world:query(Components.PositionComponent, Components.SunComponent) do
		-- Despawn check
		local age = currentTime - sun.SpawnTime
		if age >= sun.Lifetime then
			if EntityPool.IsPooledEntity(id) then
				EntityPool.Despawn(id)
			else
				world:despawn(id)
			end

			Network.SunDespawned.FireAll({
				EntityId = id,
			})
			continue
		end

		-- Falling physics (frame-rate independent)
		if sun.IsFalling then
			local dtSun = Matter.useDeltaTime()
			dtSun = math.clamp(dtSun, CONFIG.MIN_DT, CONFIG.MAX_DT)
			local newY = pos.Y - CONFIG.FALL_SPEED * dtSun
			local targetY = sun.TargetY or (getGroundY() + CONFIG.GROUND_OFFSET)

			if newY <= targetY then
				-- Landed
				world:insert(
					id,
					Components.PositionComponent({
						X = pos.X,
						Y = targetY,
						Z = pos.Z,
					}),
					Components.SunComponent({
						Value = sun.Value,
						SpawnTime = sun.SpawnTime,
						Lifetime = sun.Lifetime,
						IsFalling = false,
						TargetY = targetY,
						SourceType = sun.SourceType,
					})
				)

				Network.SunPositionUpdate.FireAll({
					EntityId = id,
					PositionY = targetY,
					Falling = false,
				})
			else
				-- Still falling
				world:insert(
					id,
					Components.PositionComponent({
						X = pos.X,
						Y = newY,
						Z = pos.Z,
					})
				)
			end
		end
	end
end

-- 7. EXPORT
return {
	priority = 300,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
