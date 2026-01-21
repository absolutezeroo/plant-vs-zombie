--!strict
--[[
	TileModifierSystem.luau - Process tile modifier effects
	
	SYSTEM V3 ARCHITECTURE (Matter Hooks)
	
	Priority: 85 (Environment phase - before movement)
	
	Handles:
	- Expiring temporary modifiers
	- Applying damage to zombies on damaging tiles
	- Applying damage to plants on hazardous tiles
	- Applying speed modifiers to zombies
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages:WaitForChild("MatterHooks"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local Logger = require(Shared.utils.core.Logger)
local LaneCache = require(Shared.utils.ecs.LaneCache)
local ECSUtils = require(Shared.utils.ecs.ECSUtils)

-- Server modules
local Server = script.Parent.Parent.Parent

-- ============================================================
-- SECTION 2: CONFIG
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 85,
	-- Damage tick rate (don't apply damage every frame)
	DAMAGE_TICK_INTERVAL = 0.5, -- Apply damage every 0.5 seconds
})

-- ============================================================
-- SECTION 3: PRIVATE HELPERS
-- ============================================================

-- Convert world position to grid position
local function worldToGrid(x: number, z: number): (number, number)
	local column = math.floor(x / GridConfig.CELL_SIZE) + 1
	local lane = math.floor(z / GridConfig.CELL_SIZE) + 1
	column = math.clamp(column, 1, GridConfig.GRID_COLUMNS)
	lane = math.clamp(lane, 1, GridConfig.GRID_LANES)
	return column, lane
end

-- ============================================================
-- SECTION 4: SYSTEM FUNCTION (main ECS loop)
-- ============================================================
local function TileModifierSystem(world)
	local currentTime = os.clock()

	-- State managed via Hooks.useMap (persistent across frames)
	-- Note: useMap returns { value: T }, so access via .value
	local stateWrapper = Hooks.useMap("TileModifierState", {
		LastDamageTick = 0,
		SpeedModifiedZombies = {} :: { [number]: number }, -- entityId -> originalSpeed
	})
	local state = stateWrapper.value

	-- Lazy load TileModifierService via useMemo (empty deps = once)
	local TileModifierService = Hooks.useMemo(function()
		return require(Server.services.TileModifierService)
	end, {})

	-- Process modifier expiration
	local expiredModifiers = {}

	for id, modifier in world:query(Components.TileModifierComponent) do
		-- Check expiration
		if modifier.Duration then
			local elapsed = currentTime - modifier.AppliedAt
			if elapsed >= modifier.Duration then
				table.insert(expiredModifiers, id)
			end
		end
	end

	-- Remove expired modifiers
	for _, entityId in expiredModifiers do
		TileModifierService.RemoveModifier(entityId)
	end

	-- Apply damage effects (throttled)
	if currentTime - state.LastDamageTick >= CONFIG.DAMAGE_TICK_INTERVAL then
		state.LastDamageTick = currentTime
		local damageInterval = CONFIG.DAMAGE_TICK_INTERVAL

		-- Collect all damaging tiles
		local damagingTiles: { [string]: number } = {} -- "col,lane" -> totalDPS
		local plantDamagingTiles: { [string]: number } = {}

		for _, modifier in world:query(Components.TileModifierComponent) do
			local key = `{modifier.Column},{modifier.Lane}`

			if modifier.DamagePerSecond > 0 then
				damagingTiles[key] = (damagingTiles[key] or 0) + modifier.DamagePerSecond
			end

			if modifier.PlantDamagePerSecond > 0 then
				plantDamagingTiles[key] = (plantDamagingTiles[key] or 0) + modifier.PlantDamagePerSecond
			end
		end

		-- Apply damage to zombies on damaging tiles
		for key, dps in damagingTiles do
			local col, lane = key:match("^(%d+),(%d+)$")
			local column = tonumber(col) or 0
			local laneNum = tonumber(lane) or 0

			local zombiesInLane = LaneCache.GetEntitiesInLane(laneNum)

			for _, zombieId in zombiesInLane do
				if not world:contains(zombieId) then
					continue
				end

				local zombiePos = world:get(zombieId, Components.PositionComponent)
				if not zombiePos then
					continue
				end

				local zCol, _ = worldToGrid(zombiePos.X, zombiePos.Z)
				if zCol == column then
					-- Apply scaled damage for tick interval
					local damage = dps * damageInterval
					ECSUtils.DamageEntity(world, zombieId, damage, Components)
				end
			end
		end

		-- Apply damage to plants on hazardous tiles
		for key, dps in plantDamagingTiles do
			local col, lane = key:match("^(%d+),(%d+)$")
			local column = tonumber(col) or 0
			local laneNum = tonumber(lane) or 0

			-- Find plants at this cell
			for plantId, plant, _pos in world:query(Components.PlantTypeComponent, Components.PositionComponent) do
				if plant.Column == column and plant.Lane == laneNum then
					local damage = dps * damageInterval
					ECSUtils.DamageEntity(world, plantId, damage, Components)
				end
			end
		end
	end

	-- Apply speed modifiers to zombies
	-- Build speed multiplier map
	local speedTiles: { [string]: number } = {} -- "col,lane" -> multiplier

	for _, modifier in world:query(Components.TileModifierComponent) do
		if modifier.SpeedMultiplier ~= 1.0 then
			local key = `{modifier.Column},{modifier.Lane}`
			-- Multiply all speed modifiers on same tile
			speedTiles[key] = (speedTiles[key] or 1.0) * modifier.SpeedMultiplier
		end
	end

	-- Track which zombies should have modified speed this frame
	local zombiesWithModifier: { [number]: boolean } = {}

	-- Apply speed modifiers to zombies on affected tiles
	for key, multiplier in speedTiles do
		local col, lane = key:match("^(%d+),(%d+)$")
		local column = tonumber(col) or 0
		local laneNum = tonumber(lane) or 0

		local zombiesInLane = LaneCache.GetEntitiesInLane(laneNum)

		for _, zombieId in zombiesInLane do
			if not world:contains(zombieId) then
				continue
			end

			local zombiePos = world:get(zombieId, Components.PositionComponent)
			if not zombiePos then
				continue
			end

			local zCol, _ = worldToGrid(zombiePos.X, zombiePos.Z)
			if zCol == column then
				zombiesWithModifier[zombieId] = true

				-- Store original speed if not already tracked
				if not state.SpeedModifiedZombies[zombieId] then
					local movement = world:get(zombieId, Components.MovementComponent)
					if movement then
						state.SpeedModifiedZombies[zombieId] = movement.VelocityX
					end
				end

				-- Apply modifier (handled by movement system reading from SlowComponent)
				-- We add a special "TileSpeedModifier" via SlowComponent
				local existingSlow = world:get(zombieId, Components.SlowComponent)
				local tileSlowPercent = 1 - multiplier -- Convert multiplier to slow percent

				if tileSlowPercent > 0 then
					-- Only apply if this is a slow (not a speed boost)
					if not existingSlow or existingSlow.SlowPercent < tileSlowPercent then
						world:insert(
							zombieId,
							Components.SlowComponent({
								SlowPercent = tileSlowPercent,
								Duration = 0.2, -- Short duration, reapplied each tick
								AppliedAt = currentTime,
							})
						)
					end
				end
			end
		end
	end

	-- Restore speed for zombies that left modified tiles
	for zombieId in state.SpeedModifiedZombies do
		if not zombiesWithModifier[zombieId] then
			-- Zombie left modified tile, remove from tracking
			state.SpeedModifiedZombies[zombieId] = nil
		end
	end
end

-- ============================================================
-- SECTION 5: EXPORT (V3 - priority + system only)
-- ============================================================
return {
	priority = CONFIG.PRIORITY,
	system = TileModifierSystem,
}
