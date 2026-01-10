--!strict
--[[
	LaneCache.luau - Lane-based spatial hashing for O(1) targeting
	
	PHILOSOPHY: "Rebuild, Don't Maintain"
	Cache is rebuilt from scratch every frame to guarantee correctness.
	Iterating 200 entities takes microseconds; dirty flag bugs are expensive.
	
	USAGE:
	1. SpatialHashingSystem calls Rebuild() at Priority 100
	2. TargetingSystem/ProjectileSystem calls GetEntitiesInLane() at Priority 120+
	3. Cache is always fresh when targeting runs
	
	STORED DATA:
	- Entity IDs per lane for O(1) lookup
	- World positions for front/back targeting checks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GridConfig = require(ReplicatedStorage.Shared.config.GridConfig)

local LaneCache = {}

-- Lane storage: [laneIndex] = {entityId1, entityId2, ...}
local _lanes: {{number}} = {}

-- Position cache: [entityId] = {X: number, Z: number}
local _positions: {[number]: {X: number, Z: number}} = {}

-- Initialize empty lanes (5 lanes for 9×5 grid)
for i = 1, GridConfig.GRID_LANES do
	_lanes[i] = {}
end

--[[
	Rebuild the lane cache from current world state
	
	MUST be called at start of Simulation phase (Priority 100)
	before any targeting systems run.
	
	@param world - Matter World instance
	@param PositionComponent - Position component type (has X, Z)
	@param ZombieTypeComponent - Zombie type component (has Lane)
]]
function LaneCache.Rebuild(world: any, PositionComponent: any, ZombieTypeComponent: any)
	-- Clear all lanes (fast table recycle)
	for i = 1, GridConfig.GRID_LANES do
		table.clear(_lanes[i])
	end
	table.clear(_positions)
	
	-- Rebuild from current world state using ZombieTypeComponent.Lane
	for entityId, pos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
		local lane = zombie.Lane
		
		-- Validate lane is within bounds
		if lane >= 1 and lane <= GridConfig.GRID_LANES then
			table.insert(_lanes[lane], entityId)
			_positions[entityId] = { X = pos.X, Z = pos.Z }
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
	Get cached position for an entity
	
	@param entityId - Entity ID
	@return {X: number, Z: number} or nil if not cached
]]
function LaneCache.GetPosition(entityId: number): {X: number, Z: number}?
	return _positions[entityId]
end

--[[
	Check if there are zombies in a lane in front of or behind a position
	Uses cached positions for O(1) lookup + O(lane_size) iteration
	
	@param laneIndex - Lane number (1-5)
	@param plantX - Plant's X position
	@param plantZ - Plant's Z position  
	@param zombieDir - Zombie direction vector (from MapConfig.GetZombieDirection())
	@param checkBehind - If true, check behind plant; otherwise check in front
	@param maxRange - Maximum distance to check (0 or nil = unlimited)
	@return true if zombies exist in the specified direction within range
]]
function LaneCache.HasZombiesInDirection(
	laneIndex: number, 
	plantX: number, 
	plantZ: number, 
	zombieDir: {X: number, Z: number},
	checkBehind: boolean?,
	maxRange: number?
): boolean
	local entities = LaneCache.GetEntitiesInLane(laneIndex)
	local rangeLimit = maxRange or 0
	
	for _, entityId in entities do
		local pos = _positions[entityId]
		if pos then
			local dx = pos.X - plantX
			local dz = pos.Z - plantZ
			
			-- Dot product with zombie direction
			-- Negative = zombie is in front of plant (coming towards it)
			-- Positive = zombie is behind plant (already passed)
			local dotProduct = dx * zombieDir.X + dz * zombieDir.Z
			
			-- First check direction
			local isInCorrectDirection = false
			if checkBehind then
				-- Behind = same direction as zombie movement (positive dot product)
				isInCorrectDirection = dotProduct > 0
			else
				-- In front = opposite of zombie direction (negative dot product)
				isInCorrectDirection = dotProduct < 0
			end
			
			if not isInCorrectDirection then
				continue
			end
			
			-- Then check range (only for zombies in correct direction)
			local distance = math.abs(dotProduct)
			if rangeLimit > 0 and distance > rangeLimit then
				continue
			end
			
			-- Found a valid zombie in range and correct direction
			return true
		end
	end
	
	return false
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