--!strict
--[[
	SpatialHashingSystem.luau - Rebuilds LaneCache every frame for O(1) targeting
	
	Priority: 100 (FIRST system in Simulation phase)
	
	PHILOSOPHY: "Rebuild, Don't Maintain"
	Cache is rebuilt from scratch every frame to guarantee correctness.
	Iterating 200 entities takes microseconds; dirty flag bugs are expensive.
	
	PIPELINE:
	1. This system runs at Priority 100 → Rebuilds LaneCache
	2. TargetingSystem/ProjectileSystem run at Priority 120+ → Consume fresh cache
	3. All lane queries are O(1) lookups instead of O(N) world:query() loops
	
	LIFECYCLE:
	- Init(): None needed
	- system(): Rebuild cache every frame (CANNOT yield)
	- Dispose(): None needed (cache is stateless)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local LaneCache = require(Shared.utils.LaneCache)
local Logger = require(Shared.utils.Logger)

-- Components needed for cache rebuild
local PositionComponent = Components.PositionComponent
local ZombieTypeComponent = Components.ZombieTypeComponent

local SpatialHashingSystem = {}

-- Priority 95: BEFORE all Simulation phase systems (before WaveManager at 100)
-- Must run first to rebuild LaneCache before any targeting systems use it
SpatialHashingSystem.priority = 95

--[[
	Rebuild lane cache from current world state.
	Called every frame at the start of Simulation phase.
]]
function SpatialHashingSystem.system(world: any)
	-- Rebuild the cache from scratch (Philosophy: Rebuild, Don't Maintain)
	-- Uses PositionComponent (X, Z) + ZombieTypeComponent.Lane
	LaneCache.Rebuild(world, PositionComponent, ZombieTypeComponent)
	
	-- Optional: Log stats in debug mode (commented out for performance)
	-- local total = LaneCache.GetTotalCount()
	-- if total > 0 then
	-- 	Logger.Debug("SpatialHashing", `Rebuilt cache: {total} zombies in {GridConfig.GRID_LANES} lanes`)
	-- end
end

return SpatialHashingSystem
