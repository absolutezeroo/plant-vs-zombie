--!strict
--[[
	SunSpawnSystem.luau - Server-side sun resource spawning
	
	Priority: 300 (Resource phase)
	
	Spawns sun orbs from the sky at regular intervals.
	Sun falls with simulated gravity until reaching ground level.
	
	MULTIPLAYER: Each player gets their own sky suns (not shared).

	V3 Architecture: Matter Hooks pattern
]]

-- 1. IMPORTS
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Hooks = require(Packages.MatterHooks)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local MapConfig = require(Shared.config.MapConfig)
local GameConstants = require(Shared.config.GameConstants)
local EntityPool = require(Shared.utils.ecs.EntityPool)
local ChanceUtils = require(Shared.utils.core.ChanceUtils)

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

-- 3. HELPER TYPES
type SunSpawnState = {
	LastSpawnTime: number,
	NextSpawnDelay: number,
	WaveService: any,
	CachedGridY: number,
	CachedCellWidth: number,
	CachedCellDepth: number,
}

-- Helper: Get WaveService (lazy load)
local function getWaveService(state: { value: SunSpawnState })
	if not state.value.WaveService then
		state.value.WaveService = require(Server.services.WaveService)
	end
	return state.value.WaveService
end

-- Helper: Get ground Y from cached config
local function getGroundY(state: { value: SunSpawnState }): number
	return state.value.CachedGridY
end

-- Helper: Get spawn height for sky suns
local function getSpawnHeight(state: { value: SunSpawnState }): number
	return getGroundY(state) + CONFIG.SPAWN_HEIGHT_OFFSET
end

-- Helper: Get random grid position
local function getRandomGridPosition(state: { value: SunSpawnState }): (number, number, number)
	local column, lane = ChanceUtils.RandomGridCell()
	local cellCenter = MapConfig.GridToWorld(column, lane)
	local cellW = state.value.CachedCellWidth
	local cellD = state.value.CachedCellDepth

	local offsetX = ChanceUtils.RandomOffset(cellW * 0.3)
	local offsetZ = ChanceUtils.RandomOffset(cellD * 0.3)

	return cellCenter.X + offsetX, getSpawnHeight(state), cellCenter.Z + offsetZ
end

-- Helper: Spawn sky sun for a specific player
local function spawnSkySunForPlayer(world: any, state: { value: SunSpawnState }, ownerId: number): number
	local x, y, z = getRandomGridPosition(state)
	local targetY = getGroundY(state) + CONFIG.GROUND_OFFSET + ChanceUtils.RandomFloat(0, 2)

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

-- 4. SYSTEM FUNCTION
local function SunSpawnSystem(world)
	local currentTime = os.clock()

	-- State managed via Hooks.useMap
	local state = Hooks.useMap("SunSpawnState", {
		LastSpawnTime = 0,
		NextSpawnDelay = 0,
		WaveService = nil :: any,
		CachedGridY = 0,
		CachedCellWidth = 0,
		CachedCellDepth = 0,
	})

	-- Initialize cached config values once via useMemo
	Hooks.useMemo(function()
		if MapConfig.IsInitialized() then
			local config = MapConfig.GetConfigIfReady()
			state.value.CachedGridY = if config then config.GridY else 0
		else
			state.value.CachedGridY = MapConfig.GetConfig().GridY
		end

		local cellW, cellD = MapConfig.GetCellSize()
		state.value.CachedCellWidth = cellW
		state.value.CachedCellDepth = cellD
		return true
	end, {})

	-- Only spawn sun during "Playing" state
	local WaveService = getWaveService(state)
	local gameState = WaveService.GetGameState()

	if gameState ~= "Playing" then
		state.value.LastSpawnTime = currentTime
		return
	end

	-- Check if it's time to spawn new sun
	local baseInterval = CONFIG.SPAWN_INTERVAL + ChanceUtils.RandomOffset(CONFIG.SPAWN_INTERVAL_VARIANCE)
	if currentTime - state.value.LastSpawnTime >= state.value.NextSpawnDelay then
		-- Spawn one sun for EACH player (individual economy)
		for _, player in Players:GetPlayers() do
			spawnSkySunForPlayer(world, state, player.UserId)
		end
		state.value.LastSpawnTime = currentTime
		state.value.NextSpawnDelay = baseInterval
	end

	-- Process falling sun and despawning
	for id, pos, sun in world:query(Components.PositionComponent, Components.SunComponent) do
		-- Despawn check
		local age = currentTime - sun.SpawnTime
		if age >= sun.Lifetime then
			EntityPool.SafeDespawn(id, world)

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
			local targetY = sun.TargetY or (state.value.CachedGridY + CONFIG.GROUND_OFFSET)

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

-- 5. EXPORT
return {
	priority = 300,
	system = SunSpawnSystem,
}
