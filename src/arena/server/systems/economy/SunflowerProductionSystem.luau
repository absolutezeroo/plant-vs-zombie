--!strict
--[[
	SunflowerProductionSystem.luau - Server-side sunflower sun production
	
	Priority: 305 (Resource phase - after sky sun spawn)
	
	Sunflowers produce sun orbs every 24 seconds.
	Sun spawns at plant position and can be collected.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GameConstants = require(Shared.config.GameConstants)
local PlantData = require(Shared.data.PlantData)
local EntityPool = require(Shared.utils.EntityPool)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules (lazy-loaded)
local Server = script.Parent.Parent.Parent

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	PRODUCTION_INTERVAL = GameConstants.Economy.DEFAULT_SUN_PRODUCTION_INTERVAL,
	FIRST_PRODUCTION_DELAY = GameConstants.Economy.DEFAULT_FIRST_SUN_DELAY,
	SUN_VALUE = GameConstants.Economy.DEFAULT_SUN_VALUE,
	SUN_LIFETIME = GameConstants.Economy.PLANT_SUN_LIFETIME,
	SPAWN_OFFSET_Y = 3,
})

-- 3. STATE
local State = {
	IsInitialized = false,
	ProductionTimers = {} :: { [number]: number }, -- entityId -> nextProductionTime
	PlantSpawnTimes = {} :: { [number]: number }, -- entityId -> spawnTime
	WaveService = nil :: any, -- Lazy-loaded reference
}

-- Helper: Get WaveService
local function getWaveService()
	if not State.WaveService then
		State.WaveService = require(Server.services.WaveService)
	end
	return State.WaveService
end

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end
	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	State.IsInitialized = false
	table.clear(State.ProductionTimers)
	table.clear(State.PlantSpawnTimes)
	State.WaveService = nil
end

-- 6. MAIN LOOP
local function OnStep(world)
	local currentTime = os.clock()

	-- Only produce sun during "Playing" or "Preparation" states
	local WaveService = getWaveService()
	local gameState = WaveService.GetGameState()

	if gameState ~= "Playing" and gameState ~= "Preparation" then
		return
	end

	-- Find all plants with ProducesSun flag
	for id, plant, pos in world:query(Components.PlantTypeComponent, Components.PositionComponent) do
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.ProducesSun then
			continue
		end

		-- Read production values from PlantData (with defaults)
		local firstDelay = stats.FirstSunDelay or CONFIG.FIRST_PRODUCTION_DELAY
		local productionInterval = stats.SunProductionInterval or CONFIG.PRODUCTION_INTERVAL
		local sunCount = stats.SunCount or 1 -- Number of suns to spawn per production

		-- Track when this plant was first seen (for growth mechanics like Sun-shroom)
		if not State.PlantSpawnTimes[id] then
			State.PlantSpawnTimes[id] = currentTime
		end

		-- Calculate sun value (supports growth over time like Sun-shroom)
		local sunValue = stats.SunValue or CONFIG.SUN_VALUE
		if stats.SunValueGrown and stats.GrowthTime then
			local plantAge = currentTime - State.PlantSpawnTimes[id]
			if plantAge >= stats.GrowthTime then
				sunValue = stats.SunValueGrown
			end
		end

		-- Initialize timer for new sun-producing plants
		if not State.ProductionTimers[id] then
			State.ProductionTimers[id] = currentTime + firstDelay
		end

		-- Check if it's time to produce
		if currentTime >= State.ProductionTimers[id] then
			-- Get plant owner (sun belongs to the player who placed the plant)
			local owner = world:get(id, Components.OwnerComponent)
			local ownerId = if owner then owner.PlayerId else nil

			-- Spawn multiple suns if SunCount > 1 (e.g., Twin Sunflower)
			for i = 1, sunCount do
				-- Offset each sun slightly for visual variety
				local offsetX = if sunCount > 1 then (i - 1) * 1.5 - 0.75 else 0

				local sunId = EntityPool.Spawn(
					Components.PositionComponent({
						X = pos.X + offsetX,
						Y = pos.Y + CONFIG.SPAWN_OFFSET_Y,
						Z = pos.Z,
					}),
					Components.SunComponent({
						Value = sunValue,
						SpawnTime = currentTime,
						Lifetime = CONFIG.SUN_LIFETIME,
						IsFalling = false,
						SourceType = plant.PlantType,
						OwnerId = ownerId,
					})
				)

				if sunId then
					-- Broadcast to clients
					Network.SunSpawned.FireAll({
						EntityId = sunId,
						PositionX = pos.X + offsetX,
						PositionY = pos.Y + CONFIG.SPAWN_OFFSET_Y,
						PositionZ = pos.Z,
						Value = sunValue,
						TargetY = pos.Y + CONFIG.SPAWN_OFFSET_Y,
						OwnerId = ownerId,
					})
				end
			end

			-- Reset timer for next production
			State.ProductionTimers[id] = currentTime + productionInterval
		end
	end

	-- Cleanup timers for despawned sunflowers
	for id in State.ProductionTimers do
		if not world:contains(id) then
			State.ProductionTimers[id] = nil
			State.PlantSpawnTimes[id] = nil
		end
	end
end

-- 7. EXPORT
return {
	priority = 305,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
