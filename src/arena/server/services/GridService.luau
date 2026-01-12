--!strict
--[[
	GridService.luau - Server-authoritative grid occupancy tracking (Singleton)
	
	Tracks which cells are occupied by plants.
	PHILOSOPHY: "Single source of truth" - only server modifies this.
	
	This is a Service (Singleton), not a utility module.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)

local GridService = {}

-- 2D array: _occupancy[column][lane] = entityId or nil
local _occupancy: { { number? } } = {}

-- Track plants per player: _playerPlantCount[PlayerId] = count
local _playerPlantCount: { [number]: number } = {}

-- Track entity ownership: _entityOwner[entityId] = PlayerId
local _entityOwner: { [number]: number } = {}

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
function GridService.IsOccupied(column: number, lane: number): boolean
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
function GridService.GetEntityAt(column: number, lane: number): number?
	if not _occupancy[column] then
		return nil
	end
	return _occupancy[column][lane]
end

-- Alias for GetEntityAt (backwards compatibility)
function GridService.GetEntity(column: number, lane: number): number?
	return GridService.GetEntityAt(column, lane)
end

--[[
	Mark a cell as occupied by an entity (SERVER ONLY)
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
	@param entityId number - Entity ID of the plant
	@param ownerId number? - Optional owner PlayerId for plant limit tracking
	@return boolean - True if successful, false if already occupied
]]
function GridService.Occupy(column: number, lane: number, entityId: number, ownerId: number?): boolean
	if GridService.IsOccupied(column, lane) then
		return false
	end

	if not _occupancy[column] then
		_occupancy[column] = {}
	end

	_occupancy[column][lane] = entityId

	-- Track ownership for plant limits
	if ownerId then
		_entityOwner[entityId] = ownerId
		_playerPlantCount[ownerId] = (_playerPlantCount[ownerId] or 0) + 1
	end

	return true
end

--[[
	Clear a cell (when plant is removed/destroyed)
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
]]
function GridService.Clear(column: number, lane: number)
	if _occupancy[column] then
		local entityId = _occupancy[column][lane]
		if entityId then
			-- Decrement owner's plant count
			local ownerId = _entityOwner[entityId]
			if ownerId then
				_playerPlantCount[ownerId] = math.max(0, (_playerPlantCount[ownerId] or 0) - 1)
				_entityOwner[entityId] = nil
			end
		end
		_occupancy[column][lane] = nil
	end
end

--[[
	Clear cell by entity ID (find and remove)
	
	@param entityId number - Entity ID to remove
	@return boolean - True if found and removed
]]
function GridService.ClearByEntity(entityId: number): boolean
	for column = 1, GridConfig.GRID_COLUMNS do
		for lane = 1, GridConfig.GRID_LANES do
			if _occupancy[column] and _occupancy[column][lane] == entityId then
				-- Decrement owner's plant count
				local ownerId = _entityOwner[entityId]
				if ownerId then
					_playerPlantCount[ownerId] = math.max(0, (_playerPlantCount[ownerId] or 0) - 1)
					_entityOwner[entityId] = nil
				end
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
function GridService.Reset()
	initGrid()
	-- Clear ownership tracking
	table.clear(_playerPlantCount)
	table.clear(_entityOwner)
end

--[[
	Get plant count for a specific player
	
	@param playerId number - Player's UserId
	@return number - Number of plants owned by this player
]]
function GridService.GetPlayerPlantCount(playerId: number): number
	return _playerPlantCount[playerId] or 0
end

--[[
	Clear a player's tracking data (when they leave)
	
	@param playerId number - Player's UserId
]]
function GridService.ClearPlayerData(playerId: number)
	_playerPlantCount[playerId] = nil
	-- Note: We don't clear _entityOwner here - entities remain until despawned
end

--[[
	Get count of occupied cells
	
	@return number - Number of plants on grid
]]
function GridService.GetPlantCount(): number
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
function GridService.GetAllOccupied(): { { Column: number, Lane: number, EntityId: number } }
	local occupied = {}
	for column = 1, GridConfig.GRID_COLUMNS do
		for lane = 1, GridConfig.GRID_LANES do
			local entityId = _occupancy[column] and _occupancy[column][lane]
			if entityId then
				occupied = Sift.Array.push(occupied, {
					Column = column,
					Lane = lane,
					EntityId = entityId,
				})
			end
		end
	end
	return occupied
end

return GridService
