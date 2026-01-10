--!strict
--[[
	GridConfig.lua - Sacred grid constants
	
	WARNING: These values are IMMUTABLE. Changing them breaks:
	- Muscle memory (players develop precise tap accuracy)
	- Balance (all wave budgets calibrated for 45 plant slots)
	- Mobile optimization (9×5 @ 6 studs fits iPhone landscape perfectly)
	
	DO NOT MODIFY without full game retest.
]]

local GridConfig = {
	-- Sacred Constants (DO NOT CHANGE)
	CELL_SIZE = 6,        -- Studs per grid cell
	GRID_COLUMNS = 9,     -- 9 columns (X-axis)
	GRID_LANES = 5,       -- 5 rows/lanes (Y-axis)
	
	-- Derived Constants
	GRID_WIDTH = 9 * 6,   -- 54 studs total width
	GRID_HEIGHT = 5 * 6,  -- 30 studs total height
	
	-- Grid World Position (center of lawn)
	GRID_ORIGIN_X = 0,    -- World X offset
	GRID_ORIGIN_Z = 0,    -- World Z offset (Y in grid = Z in world)
	GRID_ORIGIN_Y = 1,    -- Ground level (top of ground Part)
	
	-- Maximum plants (full grid occupation)
	MAX_PLANTS = 9 * 5,   -- 45 plants maximum
}

return table.freeze(GridConfig)
