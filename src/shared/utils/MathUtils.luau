--!strict
--[[
	MathUtils.lua - Common math utilities optimized for hot paths
	
	Local references to math functions for performance.
]]

-- Local references for hot path optimization
local math_floor = math.floor
local math_ceil = math.ceil
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp

local MathUtils = {}

--[[
	Convert world position to grid coordinates
	
	@param worldX - World X position (studs)
	@param worldZ - World Z position (studs)
	@param cellSize - Grid cell size (default 6 studs)
	@return column, row (1-indexed)
]]
function MathUtils.WorldToGrid(worldX: number, worldZ: number, cellSize: number?): (number, number)
	local size = cellSize or 6
	local column = math_floor(worldX / size) + 1
	local row = math_floor(worldZ / size) + 1
	return column, row
end

--[[
	Convert grid coordinates to world position (cell center)
	
	@param column - Grid column (1-indexed)
	@param row - Grid row (1-indexed)
	@param cellSize - Grid cell size (default 6 studs)
	@return worldX, worldZ
]]
function MathUtils.GridToWorld(column: number, row: number, cellSize: number?): (number, number)
	local size = cellSize or 6
	local worldX = (column - 0.5) * size
	local worldZ = (row - 0.5) * size
	return worldX, worldZ
end

--[[
	Check if grid coordinates are valid (within 9×5 grid)
	
	@param column - Grid column
	@param row - Grid row
	@param maxColumns - Maximum columns (default 9)
	@param maxRows - Maximum rows (default 5)
	@return true if valid
]]
function MathUtils.IsValidGridPosition(column: number, row: number, maxColumns: number?, maxRows: number?): boolean
	local cols = maxColumns or 9
	local rows = maxRows or 5
	return column >= 1 and column <= cols and row >= 1 and row <= rows
end

--[[
	Calculate distance between two points (2D, ignoring Y)
	
	@param x1, z1 - First point
	@param x2, z2 - Second point
	@return Distance in studs
]]
function MathUtils.Distance2D(x1: number, z1: number, x2: number, z2: number): number
	local dx = x2 - x1
	local dz = z2 - z1
	return math.sqrt(dx * dx + dz * dz)
end

--[[
	Calculate squared distance (avoids sqrt, faster for comparisons)
	
	@param x1, z1 - First point
	@param x2, z2 - Second point
	@return Squared distance
]]
function MathUtils.DistanceSquared2D(x1: number, z1: number, x2: number, z2: number): number
	local dx = x2 - x1
	local dz = z2 - z1
	return dx * dx + dz * dz
end

--[[
	Clamp value between min and max
]]
function MathUtils.Clamp(value: number, min: number, max: number): number
	return math_clamp(value, min, max)
end

--[[
	Linear interpolation
]]
function MathUtils.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--[[
	Quantize a value to fixed precision (for network optimization)
	
	@param value - Value to quantize
	@param step - Quantization step (e.g., 0.1 for 1 decimal place)
	@return Quantized value
]]
function MathUtils.Quantize(value: number, step: number): number
	return math_floor(value / step + 0.5) * step
end

return MathUtils
