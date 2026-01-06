--!strict
--[[
	GridUtils.luau - Grid coordinate conversion and utilities
	
	Handles conversion between:
	- Grid coordinates (Column 1-9, Lane 1-5)
	- World coordinates (Studs in 3D space)
	
	Grid origin is at world (0, 0, 0), grid extends in +X and +Z directions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)

local GridUtils = {}

--[[
	Convert grid coordinates to world position (center of cell)
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
	@return Vector3 - World position at center of cell
]]
function GridUtils.GridToWorld(column: number, lane: number): Vector3
	-- Grid starts at origin, cells are 6 studs
	-- Column 1 = X offset 0, Column 9 = X offset 48
	local x = GridConfig.GRID_ORIGIN_X + (column - 1) * GridConfig.CELL_SIZE + GridConfig.CELL_SIZE / 2
	local y = GridConfig.GRID_ORIGIN_Y
	local z = GridConfig.GRID_ORIGIN_Z + (lane - 1) * GridConfig.CELL_SIZE + GridConfig.CELL_SIZE / 2
	
	return Vector3.new(x, y, z)
end

--[[
	Convert world position to grid coordinates
	
	@param position Vector3 - World position
	@return (number, number)? - Column and Lane (1-indexed) or nil if outside grid
]]
function GridUtils.WorldToGrid(position: Vector3): (number?, number?)
	local relativeX = position.X - GridConfig.GRID_ORIGIN_X
	local relativeZ = position.Z - GridConfig.GRID_ORIGIN_Z
	
	-- Check bounds
	if relativeX < 0 or relativeX >= GridConfig.GRID_WIDTH then
		return nil, nil
	end
	if relativeZ < 0 or relativeZ >= GridConfig.GRID_HEIGHT then
		return nil, nil
	end
	
	-- Convert to 1-indexed grid coords
	local column = math.floor(relativeX / GridConfig.CELL_SIZE) + 1
	local lane = math.floor(relativeZ / GridConfig.CELL_SIZE) + 1
	
	return column, lane
end

--[[
	Check if grid coordinates are valid
	
	@param column number - Column index
	@param lane number - Lane index
	@return boolean - True if within grid bounds
]]
function GridUtils.IsValidCell(column: number, lane: number): boolean
	return column >= 1 and column <= GridConfig.GRID_COLUMNS
		and lane >= 1 and lane <= GridConfig.GRID_LANES
end

--[[
	Get corner positions of a grid cell (for visualization)
	
	@param column number - Column index (1-9)
	@param lane number - Lane index (1-5)
	@return { TopLeft: Vector3, TopRight: Vector3, BottomLeft: Vector3, BottomRight: Vector3 }
]]
function GridUtils.GetCellCorners(column: number, lane: number): {
	TopLeft: Vector3,
	TopRight: Vector3,
	BottomLeft: Vector3,
	BottomRight: Vector3,
}
	local baseX = GridConfig.GRID_ORIGIN_X + (column - 1) * GridConfig.CELL_SIZE
	local baseZ = GridConfig.GRID_ORIGIN_Z + (lane - 1) * GridConfig.CELL_SIZE
	local y = GridConfig.GRID_ORIGIN_Y + 0.1 -- Slightly above ground
	
	return {
		TopLeft = Vector3.new(baseX, y, baseZ),
		TopRight = Vector3.new(baseX + GridConfig.CELL_SIZE, y, baseZ),
		BottomLeft = Vector3.new(baseX, y, baseZ + GridConfig.CELL_SIZE),
		BottomRight = Vector3.new(baseX + GridConfig.CELL_SIZE, y, baseZ + GridConfig.CELL_SIZE),
	}
end

--[[
	Get all cell centers for iteration
	
	@return {{Column: number, Lane: number, Position: Vector3}}
]]
function GridUtils.GetAllCellCenters(): {{Column: number, Lane: number, Position: Vector3}}
	local cells = {}
	for column = 1, GridConfig.GRID_COLUMNS do
		for lane = 1, GridConfig.GRID_LANES do
			table.insert(cells, {
				Column = column,
				Lane = lane,
				Position = GridUtils.GridToWorld(column, lane),
			})
		end
	end
	return cells
end

return GridUtils
