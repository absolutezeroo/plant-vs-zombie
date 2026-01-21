--!strict
--[[
	GridDetection.luau - Utility for detecting entities on the grid
	
	Provides O(1) functions to check if zombies are on specific grid positions,
	behind/ahead of plants, etc. Used by Starfruit and other multi-directional plants.
	
	NOTE: These functions use pre-computed data from LaneCache.Rebuild().
	Make sure SpatialHashingSystem runs before any system that uses this.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Utils = Shared:WaitForChild("utils")
local Config = Shared:WaitForChild("config")

local LaneCache = require(Utils:WaitForChild("ecs"):WaitForChild("LaneCache"))
local MapConfig = require(Config:WaitForChild("MapConfig"))
local GridConfig = require(Config:WaitForChild("GridConfig"))

local GridDetection = {}

--[[
	Check if a lane has zombies ON THE GRID (O(1) lookup)
	Uses pre-computed cache from LaneCache.Rebuild()
	
	@param checkLane - Lane number to check
	@return boolean - True if zombies exist on grid in this lane
]]
function GridDetection.HasZombiesOnGrid(checkLane: number): boolean
	return LaneCache.HasZombiesOnGrid(checkLane)
end

--[[
	Check if a lane has zombies ON THE GRID AND BEHIND a specific X position
	O(n) where n = zombies on grid in that lane (usually small)
	
	@param checkLane - Lane number to check
	@param referenceX - X position to compare against (usually plant position)
	@return boolean - True if zombies exist on grid behind referenceX in this lane
]]
function GridDetection.HasZombiesBehindOnGrid(checkLane: number, referenceX: number): boolean
	if checkLane < 1 or checkLane > GridConfig.GRID_LANES then
		return false
	end

	-- Determine which direction is "behind" based on zombie movement
	local zombieDir = MapConfig.GetZombieDirection()
	local forwardSign = if zombieDir.X < 0 then 1 else -1

	return LaneCache.HasZombiesBehindOnGrid(checkLane, referenceX, forwardSign)
end

--[[
	Check if a lane has zombies ON THE GRID AND AHEAD of a specific X position
	O(n) where n = zombies on grid in that lane (usually small)
	
	@param checkLane - Lane number to check
	@param referenceX - X position to compare against (usually plant position)
	@return boolean - True if zombies exist on grid ahead of referenceX in this lane
]]
function GridDetection.HasZombiesAheadOnGrid(checkLane: number, referenceX: number): boolean
	if checkLane < 1 or checkLane > GridConfig.GRID_LANES then
		return false
	end

	-- Determine which direction is "ahead" based on zombie movement
	local zombieDir = MapConfig.GetZombieDirection()
	local forwardSign = if zombieDir.X < 0 then 1 else -1

	-- Ahead is the opposite of behind
	local zombiesOnGrid = LaneCache.GetZombiesOnGrid(checkLane)
	for _, entityId in zombiesOnGrid do
		local pos = LaneCache.GetPosition(entityId)
		if pos then
			local isAhead = (forwardSign > 0 and pos.X > referenceX) or (forwardSign < 0 and pos.X < referenceX)
			if isAhead then
				return true
			end
		end
	end
	return false
end

--[[
	Get zombies on the grid in a lane (O(1) lookup)
	
	@param lane - Lane to check
	@return Array of entity IDs on the grid
]]
function GridDetection.GetZombiesOnGrid(lane: number): { number }
	return LaneCache.GetZombiesOnGrid(lane)
end

--[[
	Get grid bounds
	@return gridMinX, gridMaxX - The X bounds of the grid
]]
function GridDetection.GetGridBounds(): (number, number)
	local mapConfig = MapConfig.GetConfig()
	return mapConfig.GridCornerA.X, mapConfig.GridCornerB.X
end

return GridDetection
