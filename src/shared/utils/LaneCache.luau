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
local _lanes: { { number } } = {}

-- Position cache: [entityId] = {X: number, Z: number}
local _positions: { [number]: { X: number, Z: number } } = {}

-- Plant grid storage: [column][lane] = entityId (O(1) lookup)
-- Using nested tables for 9x5 grid
local _plantGrid: { { number? } } = {}

-- Grid bounds cache (set during rebuild)
local _gridMinX: number = 0
local _gridMaxX: number = 0

-- O(1) zombie on grid cache: [lane] = { onGrid = {entityId...}, behindX = {[entityId] = X position} }
local _zombiesOnGrid: { { number } } = {}
local _zombiePositionsOnGrid: { [number]: number } = {} -- entityId -> X position (only for zombies on grid)

-- O(1) total count cache
local _totalCount: number = 0
local _totalOnGridCount: number = 0

-- Initialize empty lanes (5 lanes for 9×5 grid)
for i = 1, GridConfig.GRID_LANES do
	_lanes[i] = {}
	_zombiesOnGrid[i] = {}
end

-- Initialize empty plant grid (9 columns x 5 lanes)
for col = 1, GridConfig.GRID_COLUMNS do
	_plantGrid[col] = {}
	for lane = 1, GridConfig.GRID_LANES do
		_plantGrid[col][lane] = nil
	end
end

--[[
	Rebuild the lane cache from current world state
	
	MUST be called at start of Simulation phase (Priority 100)
	before any targeting systems run.
	
	@param world - Matter World instance
	@param PositionComponent - Position component type (has X, Z)
	@param ZombieTypeComponent - Zombie type component (has Lane)
	@param mapConfig - Optional map config with grid bounds
]]
function LaneCache.Rebuild(world: any, PositionComponent: any, ZombieTypeComponent: any, mapConfig: any?)
	-- Clear all lanes (fast table recycle)
	for i = 1, GridConfig.GRID_LANES do
		table.clear(_lanes[i])
		table.clear(_zombiesOnGrid[i])
	end
	table.clear(_positions)
	table.clear(_zombiePositionsOnGrid)
	_totalCount = 0
	_totalOnGridCount = 0

	-- Update grid bounds if provided
	if mapConfig then
		_gridMinX = mapConfig.GridCornerA.X
		_gridMaxX = mapConfig.GridCornerB.X
	end

	-- Rebuild from current world state using ZombieTypeComponent.Lane
	for entityId, pos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
		local lane = zombie.Lane

		-- Validate lane is within bounds
		if lane >= 1 and lane <= GridConfig.GRID_LANES then
			table.insert(_lanes[lane], entityId)
			_positions[entityId] = { X = pos.X, Z = pos.Z }
			_totalCount = _totalCount + 1

			-- Also cache if zombie is on the grid (O(1) lookup later)
			if pos.X >= _gridMinX and pos.X <= _gridMaxX then
				table.insert(_zombiesOnGrid[lane], entityId)
				_zombiePositionsOnGrid[entityId] = pos.X
				_totalOnGridCount = _totalOnGridCount + 1
			end
		end
	end
end

--[[
	Rebuild the plant grid from current world state
	
	MUST be called at start of Simulation phase (Priority 100)
	before any targeting systems run.
	
	@param world - Matter World instance
	@param PlantTypeComponent - Plant type component (has Column, Lane)
]]
function LaneCache.RebuildPlants(world: any, PlantTypeComponent: any)
	-- Clear plant grid (fast table clear)
	for col = 1, GridConfig.GRID_COLUMNS do
		for lane = 1, GridConfig.GRID_LANES do
			_plantGrid[col][lane] = nil
		end
	end
	
	-- Rebuild from current world state
	for entityId, plant in world:query(PlantTypeComponent) do
		local column = plant.Column
		local lane = plant.Lane
		
		-- Validate bounds
		if column and lane 
			and column >= 1 and column <= GridConfig.GRID_COLUMNS 
			and lane >= 1 and lane <= GridConfig.GRID_LANES then
			-- Store plant entity at grid position
			-- Note: If multiple plants at same position, last one wins
			-- (shouldn't happen with proper placement validation)
			_plantGrid[column][lane] = entityId
		end
	end
end

--[[
	Get plant entity at a specific grid position (O(1) lookup)
	
	@param column - Grid column (1-9)
	@param lane - Lane number (1-5)
	@return Entity ID or nil if no plant at position
]]
function LaneCache.GetPlantAt(column: number, lane: number): number?
	if column < 1 or column > GridConfig.GRID_COLUMNS then
		return nil
	end
	if lane < 1 or lane > GridConfig.GRID_LANES then
		return nil
	end
	return _plantGrid[column][lane]
end

--[[
	Get all zombie entities in a specific lane
	
	@param laneIndex - Lane number (1-5)
	@return Array of entity IDs in that lane
]]
function LaneCache.GetEntitiesInLane(laneIndex: number): { number }
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
function LaneCache.GetPosition(entityId: number): { X: number, Z: number }?
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
	zombieDir: { X: number, Z: number },
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
function LaneCache.GetEntitiesInLaneRange(centerLane: number, radius: number): { number }
	local results: { number } = {}

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
function LaneCache.GetLaneCounts(): { number }
	local counts: { number } = {}
	for i = 1, GridConfig.GRID_LANES do
		counts[i] = #_lanes[i]
	end
	return counts
end

--[[
	Get total cached zombie count (O(1))
	
	@return Total zombies in cache
]]
function LaneCache.GetTotalCount(): number
	return _totalCount
end

--[[
	Get total cached zombie count ON THE GRID (O(1))
	
	@return Total zombies on grid
]]
function LaneCache.GetTotalOnGridCount(): number
	return _totalOnGridCount
end

--[[
	Check if lane has zombies ON THE GRID (O(1) lookup)
	
	@param lane - Lane to check
	@return True if any zombies are on the grid in this lane
]]
function LaneCache.HasZombiesOnGrid(lane: number): boolean
	if lane < 1 or lane > GridConfig.GRID_LANES then
		return false
	end
	return #_zombiesOnGrid[lane] > 0
end

--[[
	Get zombies on the grid in a lane (O(1) lookup)
	
	@param lane - Lane to check
	@return Array of entity IDs on the grid
]]
function LaneCache.GetZombiesOnGrid(lane: number): { number }
	if lane < 1 or lane > GridConfig.GRID_LANES then
		return {}
	end
	return _zombiesOnGrid[lane]
end

--[[
	Check if lane has zombies BEHIND a position AND on grid (O(n) but n = zombies on grid only)
	
	@param lane - Lane to check
	@param referenceX - X position to compare
	@param forwardSign - 1 if zombies come from +X, -1 if from -X
	@return True if zombies behind referenceX on grid
]]
function LaneCache.HasZombiesBehindOnGrid(lane: number, referenceX: number, forwardSign: number): boolean
	if lane < 1 or lane > GridConfig.GRID_LANES then
		return false
	end
	
	for _, entityId in _zombiesOnGrid[lane] do
		local posX = _zombiePositionsOnGrid[entityId]
		if posX then
			local isBehind = (forwardSign > 0 and posX < referenceX) or (forwardSign < 0 and posX > referenceX)
			if isBehind then
				return true
			end
		end
	end
	return false
end

--[[
	Clear all cached data
	Used during system dispose/cleanup
]]
function LaneCache.Clear()
	for i = 1, GridConfig.GRID_LANES do
		table.clear(_lanes[i])
		table.clear(_zombiesOnGrid[i])
	end
	table.clear(_positions)
	table.clear(_zombiePositionsOnGrid)
	
	-- Clear plant grid
	for col = 1, GridConfig.GRID_COLUMNS do
		for lane = 1, GridConfig.GRID_LANES do
			_plantGrid[col][lane] = nil
		end
	end
end

--[[
	Get all zombie entity IDs across all lanes
	
	Useful for global effects (IceShroom freeze all, etc.)
	
	@return Array of all zombie entity IDs
]]
function LaneCache.GetAllZombies(): { number }
	local all = {}
	for i = 1, GridConfig.GRID_LANES do
		for _, entityId in _lanes[i] do
			table.insert(all, entityId)
		end
	end
	return all
end

return LaneCache
