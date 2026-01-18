--!strict
--[[
	FogController.luau - Client-side fog management
	
	Listens to server fog events and manages:
	- Zombie visibility (hide zombies in fog, show in illuminated areas)
	- Local fog state tracking
	
	NOTE: The fog mesh visual is placed by the artist and NOT modified by this controller.
	      Only zombie visibility is controlled based on illumination.
	
	DEPENDENCIES:
	- FogEnabled, FogCleared, FogIlluminationUpdate events from server
	- MapConfig for FogBounds
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local Network = require(Shared.network.generated.client)
local MapConfig = require(Shared.config.MapConfig)

-- ============================================================
-- STATE
-- ============================================================
local _trove = Trove.new()
local _initialized = false

-- Fog state
local _fogActive = false
local _useFogBounds = false
local _fogBoundsA: Vector3? = nil
local _fogBoundsB: Vector3? = nil
local _foggyColumns: { [number]: boolean } = {} -- Column -> is foggy

-- Illumination state (cells lit by Plantern)
local _illuminatedCells: { [string]: boolean } = {} -- "col,lane" -> illuminated

-- ============================================================
-- PRIVATE HELPERS
-- ============================================================

-- Parse cell key "col,lane" to numbers
local function parseCellKey(key: string): (number, number)
	local col, lane = key:match("^(%d+),(%d+)$")
	return tonumber(col) or 0, tonumber(lane) or 0
end

-- Create cell key from column and lane
local function cellKey(column: number, lane: number): string
	return `{column},{lane}`
end

-- Check if a grid position is in the fog zone
local function isInFogZone(column: number, lane: number): boolean
	if not _fogActive then
		return false
	end
	
	if _useFogBounds then
		-- Convert grid to world position and check bounds
		local worldPos = MapConfig.GridToWorld(column, lane)
		return MapConfig.IsInFogZone(worldPos)
	else
		-- Column-based fog
		return _foggyColumns[column] == true
	end
end

-- Check if a grid position is illuminated (by Plantern)
local function isIlluminated(column: number, lane: number): boolean
	return _illuminatedCells[cellKey(column, lane)] == true
end

-- Check if a position should be visible (not in fog OR illuminated)
local function isPositionVisible(column: number, lane: number): boolean
	if not _fogActive then
		return true
	end
	
	-- If not in fog zone, visible
	if not isInFogZone(column, lane) then
		return true
	end
	
	-- If illuminated, visible
	if isIlluminated(column, lane) then
		return true
	end
	
	return false
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================

local function onFogEnabled(data: any)
	_fogActive = true
	
	-- Check if using bounds or columns
	_useFogBounds = data.UseFogBounds == true
	
	if _useFogBounds and data.FogBoundsAX then
		_fogBoundsA = Vector3.new(data.FogBoundsAX, data.FogBoundsAY, data.FogBoundsAZ)
		_fogBoundsB = Vector3.new(data.FogBoundsBX, data.FogBoundsBY, data.FogBoundsBZ)
		Logger.Info("FogController", `Fog enabled with bounds: {_fogBoundsA} to {_fogBoundsB}`)
	else
		-- Column-based fog
		table.clear(_foggyColumns)
		for _, col in data.FoggyColumns or {} do
			_foggyColumns[col] = true
		end
		Logger.Info("FogController", `Fog enabled on {#(data.FoggyColumns or {})} columns`)
	end
	
	-- Clear illumination on new fog
	table.clear(_illuminatedCells)
end

local function onFogCleared(_data: any)
	_fogActive = false
	_useFogBounds = false
	_fogBoundsA = nil
	_fogBoundsB = nil
	table.clear(_foggyColumns)
	table.clear(_illuminatedCells)
	
	Logger.Info("FogController", "Fog cleared")
end

local function onFogIlluminationUpdate(data: any)
	-- Update illuminated cells from server
	table.clear(_illuminatedCells)
	
	for _, cellKeyStr in data.IlluminatedCells or {} do
		_illuminatedCells[cellKeyStr] = true
	end
	
	Logger.Debug("FogController", `Illumination updated: {#(data.IlluminatedCells or {})} cells lit`)
end

-- ============================================================
-- PUBLIC API
-- ============================================================

local FogController = {}

--[[
	Initialize the fog controller
	Call this once at client start
]]
function FogController.Initialize()
	if _initialized then
		Logger.Warn("FogController", "Already initialized")
		return
	end
	
	-- Subscribe to fog events
	_trove:Add(Network.FogEnabled.On(onFogEnabled))
	_trove:Add(Network.FogCleared.On(onFogCleared))
	_trove:Add(Network.FogIlluminationUpdate.On(onFogIlluminationUpdate))
	
	-- Reset fog state when map unloads
	_trove:Add(Network.MapUnloading.On(function(_data)
		_fogActive = false
		_useFogBounds = false
		_fogBoundsA = nil
		_fogBoundsB = nil
		table.clear(_foggyColumns)
		table.clear(_illuminatedCells)
		Logger.Debug("FogController", "Reset fog state for map unload")
	end))
	
	_initialized = true
	Logger.Info("FogController", "Initialized")
end

--[[
	Cleanup the fog controller
]]
function FogController.Dispose()
	_trove:Clean()
	_fogActive = false
	table.clear(_foggyColumns)
	table.clear(_illuminatedCells)
	_initialized = false
	Logger.Debug("FogController", "Disposed")
end

--[[
	Check if fog is currently active
	@return boolean
]]
function FogController.IsFogActive(): boolean
	return _fogActive
end

--[[
	Check if a grid cell is visible (not in fog or illuminated)
	Use this for zombie visibility checks
	
	@param column - Grid column (1-9)
	@param lane - Grid lane (1-5)
	@return boolean - True if cell is visible to player
]]
function FogController.IsCellVisible(column: number, lane: number): boolean
	return isPositionVisible(column, lane)
end

--[[
	Check if a world position is visible
	Converts world position to grid and checks visibility
	
	@param position - World position
	@return boolean - True if position is visible
]]
function FogController.IsPositionVisible(position: Vector3): boolean
	if not _fogActive then
		return true
	end
	
	local col, lane = MapConfig.WorldToGrid(position)
	if not col or not lane then
		return true -- Outside grid bounds, consider visible
	end
	return isPositionVisible(col, lane)
end

return FogController
