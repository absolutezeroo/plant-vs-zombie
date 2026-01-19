--!strict
--[[
	FogSystem.luau - Server-side fog management
	
	Priority: 180 (Simulation phase - after combat)
	
	Handles:
	- Tracking fog zone state
	- Plantern illumination (removes fog in radius)
	- Blover instant fog clearing
	- Sending fog state to clients
	
	LIFECYCLE:
	- Init(): Subscribe to map/wave fog config
	- OnStep(): Update illuminated cells based on Plantern positions
	- Dispose(): Clear state
]]

--------------------------------------------------------------------------------
-- [1] IMPORTS
--------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.core.Logger)

local Network = require(Shared.network.generated.server)

--------------------------------------------------------------------------------
-- [2] CONFIG (frozen constants)
--------------------------------------------------------------------------------
local CONFIG = table.freeze({
	PRIORITY = 180,
	-- Default fog columns (columns 5-9 are typically foggy in night pool levels)
	DEFAULT_FOG_COLUMNS = { 5, 6, 7, 8, 9 },
	-- Plantern illumination radius in studs
	DEFAULT_FOG_RADIUS = 36,
})

--------------------------------------------------------------------------------
-- [3] STATE (mutable runtime state)
--------------------------------------------------------------------------------
local State = {
	-- Entity ID of the singleton fog zone entity (if any)
	FogZoneEntity = nil :: number?,
	-- Whether fog is currently active
	IsFogActive = false,
	-- Cached illuminated cells (rebuilt each frame)
	IlluminatedCells = {} :: { [string]: boolean },
	-- Last sent state (to avoid spamming network)
	LastSentState = nil :: string?,
	IsInitialized = false,
}

--------------------------------------------------------------------------------
-- [4] PRIVATE HELPERS
--------------------------------------------------------------------------------

-- Create a cell key from column and lane
local function cellKey(column: number, lane: number): string
	return `{column},{lane}`
end

-- Calculate which cells are illuminated by a Plantern at position
local function getIlluminatedCells(
	position: Vector3,
	fogRadius: number
): { [string]: boolean }
	local cells: { [string]: boolean } = {}
	local cellSize = MapConfig.GetCellSize()
	local radiusInCells = math.ceil(fogRadius / cellSize)

	-- Get the plant's grid position
	local plantCol, plantLane = MapConfig.WorldToGrid(position)
	if not plantCol or not plantLane then
		return cells -- Plant outside grid, no illumination
	end

	-- Illuminate cells in a circle around the plant
	for col = plantCol - radiusInCells, plantCol + radiusInCells do
		for lane = plantLane - radiusInCells, plantLane + radiusInCells do
			if col >= 1 and col <= GridConfig.GRID_COLUMNS and lane >= 1 and lane <= GridConfig.GRID_LANES then
				-- Check if within circular radius
				local dx = (col - plantCol) * cellSize
				local dz = (lane - plantLane) * cellSize
				if math.sqrt(dx * dx + dz * dz) <= fogRadius then
					cells[cellKey(col, lane)] = true
				end
			end
		end
	end

	return cells
end

--------------------------------------------------------------------------------
-- [5] ONSTEP (main loop - CANNOT yield)
--------------------------------------------------------------------------------
local function OnStep(world)
	-- Skip if no fog active
	if not State.IsFogActive then
		return
	end

	local newIlluminatedCells: { [string]: boolean } = {}

	-- Check for SpawnEvent to handle Blover instant fog clear
	for _, event in world:query(Components.SpawnEvent) do
		if event.EntityType ~= "Plant" then
			continue
		end

		local entityId = event.Target
		if not world:contains(entityId) then
			continue
		end

		local plant = world:get(entityId, Components.PlantTypeComponent)
		if not plant then
			continue
		end

		local stats = PlantData[plant.PlantType]
		if stats and stats.IsInstant and stats.RemovesFog then
			-- Blover: Instantly clear all fog
			State.IsFogActive = false
			Logger.Info("FogSystem", "Blover cleared all fog")

			-- Notify clients
			Network.FogCleared.FireAll({})

			return
		end
	end

	-- Collect illumination from all Plantern plants
	for plantId, pos in world:query(Components.PositionComponent, Components.PlantTypeComponent) do
		local plant = world:get(plantId, Components.PlantTypeComponent)
		if not plant then
			continue
		end
		
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.RemovesFog or stats.IsInstant then
			continue
		end

		-- Plantern-type plant: illuminates area
		local fogRadius = stats.FogRadius or CONFIG.DEFAULT_FOG_RADIUS
		local worldPos = Vector3.new(pos.X, 0, pos.Z)
		local illuminated = getIlluminatedCells(worldPos, fogRadius)

		for key, _ in illuminated do
			newIlluminatedCells[key] = true
		end
	end

	-- Check if illumination changed
	local stateKey = ""
	for key, _ in newIlluminatedCells do
		stateKey = stateKey .. key .. ";"
	end

	if stateKey ~= State.LastSentState then
		State.IlluminatedCells = newIlluminatedCells
		State.LastSentState = stateKey

		-- Convert to array for network
		local illuminatedArray: { string } = {}
		for key, _ in newIlluminatedCells do
			table.insert(illuminatedArray, key)
		end

		-- Notify clients of updated illumination
		Network.FogIlluminationUpdate.FireAll({
			IlluminatedCells = illuminatedArray,
		})
	end
end

--------------------------------------------------------------------------------
-- [6] INIT / DISPOSE
--------------------------------------------------------------------------------
local function Init(_world)
	if State.IsInitialized then
		return
	end

	-- Check if current map has fog (could be set by WaveManager or map config)
	-- For now, fog is disabled by default and must be enabled by map/wave
	State.IsFogActive = false

	State.IsInitialized = true
	Logger.Debug("FogSystem", "Initialized")
end

local function Dispose()
	State.FogZoneEntity = nil
	State.IsFogActive = false
	table.clear(State.IlluminatedCells)
	State.LastSentState = nil
	State.IsInitialized = false
	Logger.Debug("FogSystem", "Disposed")
end

-- Enable fog for current level (called by WaveManager or map loader)
-- If no foggyColumns provided, uses FogBounds from MapConfig if available
local function EnableFog(foggyColumns: { number }?)
	State.IsFogActive = true
	
	-- Check if map has FogBounds defined
	local hasFogBounds = MapConfig.HasFogBounds()
	local fogBoundsA, fogBoundsB = MapConfig.GetFogBounds()
	
	if hasFogBounds and fogBoundsA and fogBoundsB then
		-- Use FogBounds from map config
		Network.FogEnabled.FireAll({
			FoggyColumns = {}, -- Empty, using bounds instead
			UseFogBounds = true,
			FogBoundsAX = fogBoundsA.X,
			FogBoundsAY = fogBoundsA.Y,
			FogBoundsAZ = fogBoundsA.Z,
			FogBoundsBX = fogBoundsB.X,
			FogBoundsBY = fogBoundsB.Y,
			FogBoundsBZ = fogBoundsB.Z,
		})
		Logger.Info("FogSystem", `Fog enabled with bounds: {fogBoundsA} to {fogBoundsB}`)
	else
		-- Fallback to column-based fog
		local columns = foggyColumns or CONFIG.DEFAULT_FOG_COLUMNS
		Network.FogEnabled.FireAll({
			FoggyColumns = columns,
			UseFogBounds = false,
		})
		Logger.Info("FogSystem", `Fog enabled on columns: {table.concat(columns, ", ")}`)
	end
end

-- Enable fog using only FogBounds from MapConfig (no fallback)
local function EnableFogFromBounds(): boolean
	if not MapConfig.HasFogBounds() then
		Logger.Warn("FogSystem", "EnableFogFromBounds called but no FogBounds defined in map")
		return false
	end
	
	EnableFog(nil)
	return true
end

-- Disable fog
local function DisableFog()
	State.IsFogActive = false
	Network.FogCleared.FireAll({})
	Logger.Info("FogSystem", "Fog disabled")
end

--------------------------------------------------------------------------------
-- [7] EXPORT
--------------------------------------------------------------------------------
return {
	priority = CONFIG.PRIORITY,
	system = OnStep,
	Init = Init,
	Dispose = Dispose,
	-- Public API for WaveManager/MapLoader
	EnableFog = EnableFog,
	EnableFogFromBounds = EnableFogFromBounds,
	DisableFog = DisableFog,
	IsFogActive = function()
		return State.IsFogActive
	end,
}
