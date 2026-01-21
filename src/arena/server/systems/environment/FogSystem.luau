--!strict
--[[
	FogSystem.luau - Server-side fog management
	
	SYSTEM V3 ARCHITECTURE (Matter Hooks)
	
	Priority: 180 (Simulation phase - after combat)
	
	Handles:
	- Tracking fog zone state
	- Plantern illumination (removes fog in radius)
	- Blover instant fog clearing
	- Sending fog state to clients
	
	NOTE: Public API (EnableFog, DisableFog) moved to FogService.
	This system only handles ECS logic.
]]

--------------------------------------------------------------------------------
-- [1] IMPORTS
--------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages:WaitForChild("MatterHooks"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.core.Logger)

local Network = require(Shared.network.generated.server)

-- Server services
local Server = script.Parent.Parent.Parent

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
-- [3] PRIVATE HELPERS
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
-- [4] SYSTEM FUNCTION (main loop - CANNOT yield)
--------------------------------------------------------------------------------
local function FogSystem(world)
	-- State managed via Hooks.useMap (persistent across frames)
	-- Note: useMap returns { value: T }, so access via .value
	local stateWrapper = Hooks.useMap("FogSystemState", {
		IsFogActive = false,
		IlluminatedCells = {} :: { [string]: boolean },
		LastSentState = nil :: string?,
	})
	local state = stateWrapper.value

	-- Lazy load FogService via useMemo (empty deps = once)
	local FogService = Hooks.useMemo(function()
		return require(Server.services.FogService)
	end, {})

	-- Sync fog state from FogService (source of truth for fog activation)
	state.IsFogActive = FogService.IsFogActive()

	-- Skip if no fog active
	if not state.IsFogActive then
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
			FogService.DisableFog()
			Logger.Info("FogSystem", "Blover cleared all fog")
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

	if stateKey ~= state.LastSentState then
		state.IlluminatedCells = newIlluminatedCells
		state.LastSentState = stateKey

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
-- [5] EXPORT (V3 - priority + system only)
--------------------------------------------------------------------------------
return {
	priority = CONFIG.PRIORITY,
	system = FogSystem,
}
