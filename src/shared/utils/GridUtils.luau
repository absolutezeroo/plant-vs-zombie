--!strict
--[[
	GridUtils.luau - Grid coordinate conversion and utilities
	
	Handles conversion between:
	- Grid coordinates (Column 1-9, Lane 1-5)
	- World coordinates (Studs in 3D space)
	
	Uses MapConfig for dynamic grid positions (from Workspace Attachments).
	Falls back to GridConfig defaults if no visual config is present.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)

local GridUtils = {}

--[[
	Convert grid coordinates to world position (center of cell)
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
	@return Vector3 - World position at center of cell
]]
function GridUtils.GridToWorld(column: number, lane: number): Vector3
	-- Delegate to MapConfig (which handles visual config or defaults)
	return MapConfig.GridToWorld(column, lane)
end

--[[
	Convert world position to grid coordinates
	
	@param position Vector3 - World position
	@return (number, number)? - Column and Lane (1-indexed) or nil if outside grid
]]
function GridUtils.WorldToGrid(position: Vector3): (number?, number?)
	-- Delegate to MapConfig
	return MapConfig.WorldToGrid(position)
end

--[[
	Check if grid coordinates are valid
	
	@param column number - Column index
	@param lane number - Lane index
	@return boolean - True if within grid bounds
]]
function GridUtils.IsValidCell(column: number, lane: number): boolean
	return column >= 1 and column <= GridConfig.GRID_COLUMNS and lane >= 1 and lane <= GridConfig.GRID_LANES
end

--[[
	Get corner positions of a grid cell (for visualization)
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
	@return { TopLeft: Vector3, TopRight: Vector3, BottomLeft: Vector3, BottomRight: Vector3 }
]]
function GridUtils.GetCellCorners(
	column: number,
	lane: number
): {
	TopLeft: Vector3,
	TopRight: Vector3,
	BottomLeft: Vector3,
	BottomRight: Vector3,
}
	local config = MapConfig.GetConfig()
	local cellW, cellD = MapConfig.GetCellSize()
	local origin = MapConfig.GetGridOrigin()

	local baseX = origin.X + (column - 1) * cellW
	local baseZ = origin.Z + (lane - 1) * cellD
	local y = config.GridY + 0.1 -- Slightly above ground

	return {
		TopLeft = Vector3.new(baseX, y, baseZ),
		TopRight = Vector3.new(baseX + cellW, y, baseZ),
		BottomLeft = Vector3.new(baseX, y, baseZ + cellD),
		BottomRight = Vector3.new(baseX + cellW, y, baseZ + cellD),
	}
end

--[[
	Get all cell centers for iteration
	
	@return {{Column: number, Lane: number, Position: Vector3}}
]]
function GridUtils.GetAllCellCenters(): { { Column: number, Lane: number, Position: Vector3 } }
	local cells = {}
	for column = 1, GridConfig.GRID_COLUMNS do
		for lane = 1, GridConfig.GRID_LANES do
			cells = Sift.Array.push(cells, {
				Column = column,
				Lane = lane,
				Position = GridUtils.GridToWorld(column, lane),
			})
		end
	end
	return cells
end

return GridUtils
