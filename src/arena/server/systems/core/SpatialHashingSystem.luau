--!strict
--[[
	SpatialHashingSystem.luau - Rebuilds LaneCache every frame for O(1) targeting
	
	Priority: 95 (FIRST system in Simulation phase)
	
	PHILOSOPHY: "Rebuild, Don't Maintain"
	Cache is rebuilt from scratch every frame to guarantee correctness.
	Iterating 200 entities takes microseconds; dirty flag bugs are expensive.
	
	PIPELINE:
	1. This system runs at Priority 95 → Rebuilds LaneCache
	2. TargetingSystem/ProjectileSystem run at Priority 120+ → Consume fresh cache
	3. All lane queries are O(1) lookups instead of O(N) world:query() loops
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local LaneCache = require(Shared.utils.LaneCache)
local MapConfig = require(Shared.config.MapConfig)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	-- Debug logging (disabled for performance)
	DEBUG_LOGGING = false,
})

-- 3. STATE (minimal - this system is stateless by design)
local State = {
	IsInitialized = false,
}

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end
	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	LaneCache.Clear()
	State.IsInitialized = false
end

-- 6. MAIN LOOP
local function OnStep(world)
	-- Rebuild the cache from scratch every frame
	local mapConfig = MapConfig.IsInitialized() and MapConfig.GetConfig() or nil
	LaneCache.Rebuild(world, Components.PositionComponent, Components.ZombieTypeComponent, mapConfig)
	LaneCache.RebuildPlants(world, Components.PlantTypeComponent)
end

-- 7. EXPORT
return {
	priority = 95,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
