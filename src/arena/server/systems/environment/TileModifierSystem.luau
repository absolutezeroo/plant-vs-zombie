--!strict
--[[
	TileModifierSystem.luau - Process tile modifier effects
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 85 (Environment phase - before movement)
	
	Handles:
	- Expiring temporary modifiers
	- Applying damage to zombies on damaging tiles
	- Applying damage to plants on hazardous tiles
	- Applying speed modifiers to zombies
	
	LIFECYCLE:
	- Init(): Initialize service reference
	- OnStep(): Process modifiers (CANNOT yield)
	- Dispose(): Clear state
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local Logger = require(Shared.utils.Logger)
local LaneCache = require(Shared.utils.LaneCache)
local ECSUtils = require(Shared.utils.ECSUtils)

-- Server modules
local Server = script.Parent.Parent.Parent
local TileModifierService = require(Server.services.TileModifierService)

-- Network
local Network = require(Shared.network.generated.server)

-- ============================================================
-- SECTION 2: CONFIG
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 85,
	
	-- Damage tick rate (don't apply damage every frame)
	DAMAGE_TICK_INTERVAL = 0.5, -- Apply damage every 0.5 seconds
})

-- ============================================================
-- SECTION 3: STATE
-- ============================================================
local State = {
	IsInitialized = false,
	LastDamageTick = 0,
	-- Track which entities have been affected by speed modifiers
	SpeedModifiedZombies = {} :: { [number]: number }, -- entityId -> originalSpeed
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
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
-- SECTION 5: ONSTEP (main ECS loop)
-- ============================================================
local function OnStep(world, _deltaTime: number)
	local currentTime = os.clock()
	
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
	if currentTime - State.LastDamageTick >= CONFIG.DAMAGE_TICK_INTERVAL then
		State.LastDamageTick = currentTime
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
			for plantId, plant, pos in world:query(Components.PlantTypeComponent, Components.PositionComponent) do
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
				if not State.SpeedModifiedZombies[zombieId] then
					local movement = world:get(zombieId, Components.MovementComponent)
					if movement then
						State.SpeedModifiedZombies[zombieId] = movement.VelocityX
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
	for zombieId in State.SpeedModifiedZombies do
		if not zombiesWithModifier[zombieId] then
			-- Zombie left modified tile, remove from tracking
			State.SpeedModifiedZombies[zombieId] = nil
		end
	end
end

-- ============================================================
-- SECTION 6: INIT / DISPOSE
-- ============================================================

local function Init(_world)
	if State.IsInitialized then
		return
	end

	State.IsInitialized = true
	State.LastDamageTick = os.clock()
	
	Logger.Info("TileModifierSystem", "Initialized")
end

local function Dispose()
	table.clear(State.SpeedModifiedZombies)
	State.IsInitialized = false
	State.LastDamageTick = 0
	
	Logger.Debug("TileModifierSystem", "Disposed")
end

-- ============================================================
-- SECTION 7: EXPORT
-- ============================================================

return {
	priority = CONFIG.PRIORITY,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
