--!strict
--[[
	LaneCache.lua - Lane-based spatial hashing for O(1) targeting
	
	PHILOSOPHY: "Rebuild, Don't Maintain"
	Cache is rebuilt from scratch every frame to guarantee correctness.
	Iterating 200 entities takes microseconds; dirty flag bugs are expensive.
	
	USAGE:
	1. SpatialHashingSystem calls Rebuild() at Priority 100
	2. TargetingSystem calls GetEntitiesInLane() at Priority 120
	3. Cache is always fresh when targeting runs
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GridConfig = require(ReplicatedStorage.Shared.config.GridConfig)

local LaneCache = {}

-- Lane storage: [laneIndex] = {entityId1, entityId2, ...}
local _lanes: {{number}} = {}

-- Initialize empty lanes (5 lanes for 9×5 grid)
for i = 1, GridConfig.GRID_LANES do
	_lanes[i] = {}
end

--[[
	Rebuild the lane cache from current world state
	
	MUST be called at start of Simulation phase (Priority 100)
	before any targeting systems run.
	
	@param world - Matter World instance
	@param GridPositionComponent - GridPosition component type
	@param ZombieTag - Zombie tag component type
]]
function LaneCache.Rebuild(world: any, GridPositionComponent: any, ZombieTag: any)
	-- Clear all lanes (fast table recycle)
	for i = 1, GridConfig.GRID_LANES do
		table.clear(_lanes[i])
	end
	
	-- Rebuild from current world state
	for entityId, position in world:query(GridPositionComponent, ZombieTag) do
		local lane = position.Row
		
		-- Validate lane is within bounds
		if lane >= 1 and lane <= GridConfig.GRID_LANES then
			table.insert(_lanes[lane], entityId)
		end
	end
end

--[[
	Get all zombie entities in a specific lane
	
	@param laneIndex - Lane number (1-5)
	@return Array of entity IDs in that lane
]]
function LaneCache.GetEntitiesInLane(laneIndex: number): {number}
	if laneIndex < 1 or laneIndex > GridConfig.GRID_LANES then
		return {}
	end
	return _lanes[laneIndex]
end

--[[
	Get entities in multiple lanes (for splash damage)
	
	@param centerLane - Center lane of the attack
	@param radius - Number of lanes above/below center (e.g., 1 for 3×3)
	@return Combined array of entity IDs
]]
function LaneCache.GetEntitiesInLaneRange(centerLane: number, radius: number): {number}
	local results: {number} = {}
	
	local minLane = math.max(1, centerLane - radius)
	local maxLane = math.min(GridConfig.GRID_LANES, centerLane + radius)
	
	for lane = minLane, maxLane do
		for _, entityId in _lanes[lane] do
			table.insert(results, entityId)
		end
	end
	
	return results
end

--[[
	Get count of entities per lane (for debugging/monitoring)
	
	@return Array of counts [lane1Count, lane2Count, ...]
]]
function LaneCache.GetLaneCounts(): {number}
	local counts: {number} = {}
	for i = 1, GridConfig.GRID_LANES do
		counts[i] = #_lanes[i]
	end
	return counts
end

--[[
	Get total cached zombie count
	
	@return Total zombies in cache
]]
function LaneCache.GetTotalCount(): number
	local total = 0
	for i = 1, GridConfig.GRID_LANES do
		total = total + #_lanes[i]
	end
	return total
end

return LaneCache
