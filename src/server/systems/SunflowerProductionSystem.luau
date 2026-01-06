--!strict
--[[
	SunflowerProductionSystem.luau - Server-side sunflower sun production
	
	Priority: 305 (Resource phase - after sky sun spawn)
	
	Sunflowers produce sun orbs every 24 seconds.
	Sun spawns at plant position and can be collected.
	Uses SunComponent for consistency with sky sun.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = Shared.components
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

-- Network
local Server = script.Parent.Parent
local Network = require(Server.network.generated)

-- Components
local PositionComponent = require(Components.PositionComponent)
local PlantTypeComponent = require(Components.PlantTypeComponent)
local SunComponent = require(Components.SunComponent)

-- Production config (defaults for missing plant data)
local ProductionDefaults = {
	PRODUCTION_INTERVAL = 24,  -- Default seconds between sun production
	FIRST_PRODUCTION_DELAY = 7, -- Default seconds before first sun
	SUN_VALUE = 25,            -- Default sun value when collected
	SUN_LIFETIME = 12,         -- Seconds until despawn (global)
	SPAWN_OFFSET_Y = 3,        -- Height above plant to spawn sun (global)
}

-- Track production timers per sunflower entity
local _productionTimers: {[number]: number} = {}

local function SunflowerProductionSystem(world)
	local currentTime = os.clock()
	
	-- Find all plants with ProducesSun flag and manage their production
	for id, plant, pos in world:query(PlantTypeComponent, PositionComponent) do
		-- Get plant stats and check if it produces sun (data-driven)
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.ProducesSun then
			continue
		end
		
		-- Read production values from PlantData (with defaults)
		local firstDelay = stats.FirstSunDelay or ProductionDefaults.FIRST_PRODUCTION_DELAY
		local productionInterval = stats.SunProductionInterval or ProductionDefaults.PRODUCTION_INTERVAL
		local sunValue = stats.SunValue or ProductionDefaults.SUN_VALUE
		
		-- Initialize timer for new sun-producing plants
		if not _productionTimers[id] then
			-- First production is faster to feel rewarding
			_productionTimers[id] = currentTime + firstDelay
			Logger.Debug("SunflowerProduction", `{plant.PlantType} {id} initialized, first sun in {firstDelay}s`)
		end
		
		-- Check if it's time to produce
		if currentTime >= _productionTimers[id] then
			-- Spawn sun at plant position (slightly above)
			local sunId = world:spawn(
				PositionComponent({
					X = pos.X,
					Y = pos.Y + ProductionDefaults.SPAWN_OFFSET_Y,
					Z = pos.Z,
				}),
				SunComponent({
					Value = sunValue,
					SpawnTime = currentTime,
					Lifetime = ProductionDefaults.SUN_LIFETIME,
					IsFalling = false, -- Plant-produced sun doesn't fall, just floats
					SourceType = plant.PlantType,
				})
			)
			
			-- Broadcast to clients
			Network.SunSpawned.FireAll({
				EntityId = sunId,
				PositionX = pos.X,
				PositionY = pos.Y + ProductionDefaults.SPAWN_OFFSET_Y,
				PositionZ = pos.Z,
				Value = sunValue,
				TargetY = pos.Y + ProductionDefaults.SPAWN_OFFSET_Y, -- Plant sun doesn't fall
			})
			
			Logger.Debug("SunflowerProduction", `{plant.PlantType} {id} produced sun {sunId} (value={sunValue})`)
			
			-- Reset timer for next production
			_productionTimers[id] = currentTime + productionInterval
		end
	end
	
	-- Cleanup timers for despawned sunflowers
	for id in _productionTimers do
		if not world:contains(id) then
			_productionTimers[id] = nil
		end
	end
end

return {
	system = SunflowerProductionSystem,
	priority = 305,
}
