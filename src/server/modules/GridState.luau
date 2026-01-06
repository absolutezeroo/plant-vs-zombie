--!strict
--[[
	GridState.luau - Server-authoritative grid occupancy tracking
	
	Tracks which cells are occupied by plants.
	PHILOSOPHY: "Single source of truth" - only server modifies this.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)

local GridState = {}

-- 2D array: _occupancy[column][lane] = entityId or nil
local _occupancy: {{number?}} = {}

-- Initialize empty grid
local function initGrid()
	for column = 1, GridConfig.GRID_COLUMNS do
		_occupancy[column] = {}
		for lane = 1, GridConfig.GRID_LANES do
			_occupancy[column][lane] = nil
		end
	end
end

initGrid()

--[[
	Check if a cell is occupied
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
	@return boolean - True if cell has a plant
]]
function GridState.IsOccupied(column: number, lane: number): boolean
	if not _occupancy[column] then
		return false
	end
	return _occupancy[column][lane] ~= nil
end

--[[
	Get the entity ID occupying a cell
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
	@return number? - Entity ID or nil if empty
]]
function GridState.GetEntityAt(column: number, lane: number): number?
	if not _occupancy[column] then
		return nil
	end
	return _occupancy[column][lane]
end

--[[
	Mark a cell as occupied by an entity (SERVER ONLY)
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
	@param entityId number - Entity ID of the plant
	@return boolean - True if successful, false if already occupied
]]
function GridState.Occupy(column: number, lane: number, entityId: number): boolean
	if GridState.IsOccupied(column, lane) then
		return false
	end
	
	if not _occupancy[column] then
		_occupancy[column] = {}
	end
	
	_occupancy[column][lane] = entityId
	return true
end

--[[
	Clear a cell (when plant is removed/destroyed)
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
]]
function GridState.Clear(column: number, lane: number)
	if _occupancy[column] then
		_occupancy[column][lane] = nil
	end
end

--[[
	Clear cell by entity ID (find and remove)
	
	@param entityId number - Entity ID to remove
	@return boolean - True if found and removed
]]
function GridState.ClearByEntity(entityId: number): boolean
	for column = 1, GridConfig.GRID_COLUMNS do
		for lane = 1, GridConfig.GRID_LANES do
			if _occupancy[column] and _occupancy[column][lane] == entityId then
				_occupancy[column][lane] = nil
				return true
			end
		end
	end
	return false
end

--[[
	Reset entire grid (for new game)
]]
function GridState.Reset()
	initGrid()
end

--[[
	Get count of occupied cells
	
	@return number - Number of plants on grid
]]
function GridState.GetPlantCount(): number
	local count = 0
	for column = 1, GridConfig.GRID_COLUMNS do
		for lane = 1, GridConfig.GRID_LANES do
			if _occupancy[column] and _occupancy[column][lane] then
				count = count + 1
			end
		end
	end
	return count
end

--[[
	Get all occupied cells (for debugging/serialization)
	
	@return {{Column: number, Lane: number, EntityId: number}}
]]
function GridState.GetAllOccupied(): {{Column: number, Lane: number, EntityId: number}}
	local occupied = {}
	for column = 1, GridConfig.GRID_COLUMNS do
		for lane = 1, GridConfig.GRID_LANES do
			local entityId = _occupancy[column] and _occupancy[column][lane]
			if entityId then
				table.insert(occupied, {
					Column = column,
					Lane = lane,
					EntityId = entityId,
				})
			end
		end
	end
	return occupied
end

return GridState
