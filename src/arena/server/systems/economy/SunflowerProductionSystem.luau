--!strict
--[[
	SunflowerProductionSystem.luau - Server-side sunflower sun production
	
	Priority: 305 (Resource phase - after sky sun spawn)
	
	Sunflowers produce sun orbs every 24 seconds.
	Sun spawns at plant position and can be collected.
	
	HOOKS ARCHITECTURE:
	- Uses per-entity useMap for production timers (auto-cleanup)
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local MatterHooks = require(Packages.MatterHooks)
local useMap = MatterHooks.useMap
local useMemo = MatterHooks.useMemo

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GameConstants = require(Shared.config.GameConstants)
local PlantData = require(Shared.data.PlantData)
local EntityPool = require(Shared.utils.ecs.EntityPool)

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

-- 3. MAIN LOOP
local function SunflowerProductionSystem(world)
	local currentTime = os.clock()

	-- Lazy-load WaveService once per system lifecycle
	local WaveService = useMemo(function()
		return require(Server.services.WaveService)
	end, {})

	-- Only produce sun during "Playing" or "Preparation" states
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

		-- Per-entity production state (auto-cleanup when entity leaves query)
		local productionState = useMap(id, {
			spawnTime = currentTime,
			nextProductionTime = currentTime + (stats.FirstSunDelay or CONFIG.FIRST_PRODUCTION_DELAY),
		})

		-- Read production values from PlantData (with defaults)
		local productionInterval = stats.SunProductionInterval or CONFIG.PRODUCTION_INTERVAL
		local sunCount = stats.SunCount or 1 -- Number of suns to spawn per production

		-- Calculate sun value (supports growth over time like Sun-shroom)
		local sunValue = stats.SunValue or CONFIG.SUN_VALUE
		if stats.SunValueGrown and stats.GrowthTime then
			local plantAge = currentTime - productionState.value.spawnTime
			if plantAge >= stats.GrowthTime then
				sunValue = stats.SunValueGrown
			end
		end

		-- Check if it's time to produce
		if currentTime >= productionState.value.nextProductionTime then
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
			productionState.value.nextProductionTime = currentTime + productionInterval
		end
	end
end

-- 4. EXPORT
return {
	priority = 305,
	system = SunflowerProductionSystem,
}
