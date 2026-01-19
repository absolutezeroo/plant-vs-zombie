--!strict
--[[
	ChanceUtils.luau - Centralized RNG and probability utilities
	
	Consolidates all random/chance logic to ensure:
	- Consistent probability APIs across codebase
	- Single source of truth for grid randomization
	- Testable RNG (can be seeded for unit tests)
	
	USAGE:
	local ChanceUtils = require(Shared.utils.core.ChanceUtils)
	if ChanceUtils.Roll(0.25) then -- 25% chance
		-- success
	end
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)

local ChanceUtils = {}

-- ============================================
-- Core Probability Functions
-- ============================================

--[[
	Roll a probability check
	
	@param chance number - Probability from 0.0 to 1.0 (e.g., 0.25 = 25%)
	@return boolean - True if roll succeeded
]]
function ChanceUtils.Roll(chance: number): boolean
	return math.random() <= chance
end

--[[
	Roll with explicit percentage (1-100 scale)
	
	@param percent number - Percentage from 0 to 100
	@return boolean - True if roll succeeded
]]
function ChanceUtils.RollPercent(percent: number): boolean
	return math.random() * 100 <= percent
end

-- ============================================
-- Grid Randomization
-- ============================================

--[[
	Get a random lane index (1 to GRID_LANES)
	
	@return number - Random lane (1-5 for standard 9×5 grid)
]]
function ChanceUtils.RandomLane(): number
	return math.random(1, GridConfig.GRID_LANES)
end

--[[
	Get a random column index (1 to GRID_COLUMNS)
	
	@return number - Random column (1-9 for standard 9×5 grid)
]]
function ChanceUtils.RandomColumn(): number
	return math.random(1, GridConfig.GRID_COLUMNS)
end

--[[
	Get a random grid cell (column, lane)
	
	@return (number, number) - Random column and lane
]]
function ChanceUtils.RandomGridCell(): (number, number)
	return math.random(1, GridConfig.GRID_COLUMNS), math.random(1, GridConfig.GRID_LANES)
end

-- ============================================
-- Directional Randomization
-- ============================================

--[[
	Get a random direction (-1 or 1)
	Useful for lane switching, knockback, etc.
	
	@return number - Either -1 or 1
]]
function ChanceUtils.RandomDirection(): number
	return if math.random() > 0.5 then 1 else -1
end

--[[
	Get random sign with custom bias
	
	@param positiveChance number - Chance of returning 1 (0.0 to 1.0)
	@return number - Either -1 or 1
]]
function ChanceUtils.RandomSign(positiveChance: number?): number
	local chance = positiveChance or 0.5
	return if math.random() <= chance then 1 else -1
end

-- ============================================
-- Audio/Visual Variation
-- ============================================

--[[
	Get a randomized pitch value for audio variation
	
	@param basePitch number - Base pitch (default 1.0)
	@param variance number - Maximum deviation (e.g., 0.2 means ±0.2)
	@return number - Randomized pitch
]]
function ChanceUtils.RandomPitch(basePitch: number?, variance: number?): number
	local base = basePitch or 1.0
	local var = variance or 0.1
	return base + (math.random() - 0.5) * 2 * var
end

--[[
	Get a random offset within a range (centered at 0)
	Useful for spawn position variation
	
	@param maxOffset number - Maximum offset magnitude
	@return number - Random value between -maxOffset and +maxOffset
]]
function ChanceUtils.RandomOffset(maxOffset: number): number
	return (math.random() - 0.5) * 2 * maxOffset
end

-- ============================================
-- Collection Selection
-- ============================================

--[[
	Pick a random element from an array
	
	@param array {T} - Array to pick from
	@return T? - Random element, or nil if array is empty
]]
function ChanceUtils.PickRandom<T>(array: { T }): T?
	local count = #array
	if count == 0 then
		return nil
	end
	return array[math.random(1, count)]
end

--[[
	Pick a random element using weighted probabilities
	
	@param items {{Item: T, Weight: number}} - Array of weighted items
	@return T? - Selected item, or nil if array is empty
	
	Example:
	local result = ChanceUtils.WeightedPick({
		{Item = "Common", Weight = 70},
		{Item = "Rare", Weight = 25},
		{Item = "Epic", Weight = 5},
	})
]]
function ChanceUtils.WeightedPick<T>(items: { { Item: T, Weight: number } }): T?
	if #items == 0 then
		return nil
	end

	-- Calculate total weight
	local totalWeight = 0
	for _, entry in items do
		totalWeight += entry.Weight
	end

	if totalWeight <= 0 then
		return nil
	end

	-- Roll and find matching item
	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, entry in items do
		cumulative += entry.Weight
		if roll <= cumulative then
			return entry.Item
		end
	end

	-- Fallback (shouldn't reach here)
	return items[#items].Item
end

--[[
	Shuffle an array in-place (Fisher-Yates algorithm)
	
	@param array {T} - Array to shuffle
	@return {T} - Same array, shuffled
]]
function ChanceUtils.Shuffle<T>(array: { T }): { T }
	for i = #array, 2, -1 do
		local j = math.random(1, i)
		array[i], array[j] = array[j], array[i]
	end
	return array
end

-- ============================================
-- Range Utilities
-- ============================================

--[[
	Get a random integer within a range (inclusive)
	
	@param min number - Minimum value
	@param max number - Maximum value
	@return number - Random integer between min and max
]]
function ChanceUtils.RandomInt(min: number, max: number): number
	return math.random(min, max)
end

--[[
	Get a random float within a range
	
	@param min number - Minimum value
	@param max number - Maximum value
	@return number - Random float between min and max
]]
function ChanceUtils.RandomFloat(min: number, max: number): number
	return min + math.random() * (max - min)
end

return ChanceUtils
