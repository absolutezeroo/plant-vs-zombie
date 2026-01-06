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

-- Production config
local ProductionConfig = {
	PRODUCTION_INTERVAL = 24,  -- Seconds between sun production
	FIRST_PRODUCTION_DELAY = 7, -- Seconds before first sun (faster start)
	SUN_VALUE = 25,            -- Sun value when collected
	SUN_LIFETIME = 12,         -- Seconds until despawn
	SPAWN_OFFSET_Y = 3,        -- Height above plant to spawn sun
}

-- Track production timers per sunflower entity
local _productionTimers: {[number]: number} = {}

local function SunflowerProductionSystem(world)
	local currentTime = os.clock()
	
	-- Find all Sunflowers and manage their production
	for id, plant, pos in world:query(PlantTypeComponent, PositionComponent) do
		-- Only process Sunflowers
		if plant.PlantType ~= "Sunflower" then
			continue
		end
		
		-- Initialize timer for new sunflowers
		if not _productionTimers[id] then
			-- First production is faster to feel rewarding
			_productionTimers[id] = currentTime + ProductionConfig.FIRST_PRODUCTION_DELAY
			Logger.Debug("SunflowerProduction", `Sunflower {id} initialized, first sun in {ProductionConfig.FIRST_PRODUCTION_DELAY}s`)
		end
		
		-- Check if it's time to produce
		if currentTime >= _productionTimers[id] then
			-- Spawn sun at plant position (slightly above)
			local sunId = world:spawn(
				PositionComponent({
					X = pos.X,
					Y = pos.Y + ProductionConfig.SPAWN_OFFSET_Y,
					Z = pos.Z,
				}),
				SunComponent({
					Value = ProductionConfig.SUN_VALUE,
					SpawnTime = currentTime,
					Lifetime = ProductionConfig.SUN_LIFETIME,
					IsFalling = false, -- Sunflower sun doesn't fall, just floats
					SourceType = "Sunflower",
				})
			)
			
			-- Broadcast to clients
			Network.SunSpawned.FireAll({
				EntityId = sunId,
				PositionX = pos.X,
				PositionY = pos.Y + ProductionConfig.SPAWN_OFFSET_Y,
				PositionZ = pos.Z,
				Value = ProductionConfig.SUN_VALUE,
				TargetY = pos.Y + ProductionConfig.SPAWN_OFFSET_Y, -- Sunflower sun doesn't fall
			})
			
			Logger.Debug("SunflowerProduction", `Sunflower {id} produced sun {sunId}`)
			
			-- Reset timer for next production
			_productionTimers[id] = currentTime + ProductionConfig.PRODUCTION_INTERVAL
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
