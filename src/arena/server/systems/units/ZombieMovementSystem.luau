--!strict
--[[
	ZombieMovementSystem.luau - Server-side zombie movement
	
	Priority: 150 (Simulation phase - after spawn)
	
	Moves zombies towards the house using frame-rate independent movement.
	Stops zombie when eating a plant.
	Checks for game over condition (zombie reaches house).
	
	CRITICAL: Uses Matter.useDeltaTime() for lag-independent movement.

	V3 Architecture: Matter Hooks pattern
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Hooks = require(Packages.MatterHooks)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local EntityPool = require(Shared.utils.ecs.EntityPool)
local NetworkUtils = require(Shared.utils.network.NetworkUtils)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent
local BaseHealth = require(Server.modules.BaseHealth)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	BATCH_INTERVAL = 0.1, -- Seconds between position broadcasts
	MIN_DT = 1 / 120, -- Minimum deltaTime to prevent physics explosion
	MAX_DT = 1 / 15, -- Maximum deltaTime to prevent teleporting on lag spikes
})

-- 3. HELPER TYPES
type ZombieMovementState = {
	LastBatchTime: number,
	PositionUpdates: { [number]: number },
	ReachedHouse: { [number]: boolean },
}

-- Helper: Convert world X position to grid column
local function worldXToGridColumn(worldX: number, cachedConfig: MapConfig.MapConfigType?): number?
	local config = cachedConfig
	if not config then
		return nil
	end

	local gridOriginX = config.GridCornerA.X
	local cellWidth = config.CellWidth or GridConfig.CELL_SIZE

	local column = math.floor((worldX - gridOriginX) / cellWidth) + 1

	if column < 1 then
		return 1
	elseif column > GridConfig.GRID_COLUMNS then
		return GridConfig.GRID_COLUMNS
	end

	return column
end

-- 4. SYSTEM FUNCTION
local function ZombieMovementSystem(world)
	local currentTime = os.clock()

	-- State managed via Hooks.useMap
	local state = Hooks.useMap("ZombieMovementState", {
		LastBatchTime = 0,
		PositionUpdates = {} :: { [number]: number },
		ReachedHouse = {} :: { [number]: boolean },
	})

	-- Cache MapConfig values via useMemo (refreshed when map changes)
	local cachedConfig, cachedBasePos, cachedZombieDir = Hooks.useMemo(function()
		if MapConfig.IsInitialized() then
			return MapConfig.GetConfigIfReady(), MapConfig.GetBasePosition(), MapConfig.GetZombieDirection()
		end
		return nil, Vector3.zero, Vector3.zero
	end, { MapConfig.IsInitialized() })

	-- CRITICAL: Use Matter's deltaTime for frame-rate independence
	local dt = Matter.useDeltaTime()
	dt = math.clamp(dt, CONFIG.MIN_DT, CONFIG.MAX_DT)

	-- Get base position and zombie direction from cache
	local basePos = cachedBasePos
	local zombieDir = cachedZombieDir

	-- Process all zombies with movement
	for id, pos, movement, zombie in
		world:query(Components.PositionComponent, Components.MovementComponent, Components.ZombieTypeComponent)
	do
		-- Skip if zombie has a target (eating a plant)
		local target = world:get(id, Components.TargetComponent)
		if target then
			continue
		end

		-- Skip if stunned
		local stun = world:get(id, Components.StunComponent)
		if stun then
			continue
		end

		-- Skip if already reached house
		if state.value.ReachedHouse[id] then
			continue
		end

		-- Calculate slow effect multiplier
		local speedMultiplier = 1.0
		local slow = world:get(id, Components.SlowComponent)
		if slow then
			speedMultiplier = 1.0 - slow.SlowPercent
		end

		-- FRAME-RATE INDEPENDENT MOVEMENT
		local newX = pos.X + (movement.VelocityX * dt * speedMultiplier)
		local newY = pos.Y + (movement.VelocityY * dt * speedMultiplier)
		local newZ = pos.Z + (movement.VelocityZ * dt * speedMultiplier)

		-- Check if hypnotized zombie reached zombie spawn (they walk backwards)
		local hypnotized = world:get(id, Components.HypnotizedComponent)
		if hypnotized then
			-- Hypnotized zombies despawn when reaching the zombie spawn area (opposite side)
			local gridPos = world:get(id, Components.GridPositionComponent)
			local lane = gridPos and gridPos.Row or 3 -- Default to middle lane
			local spawnPos = MapConfig.GetZombieSpawn(lane)

			-- Check if zombie reached spawn area (reverse direction check)
			local reachedSpawn = false
			if zombieDir.X > 0 then
				-- Normal zombies go positive X, hypnotized go negative
				reachedSpawn = newX <= spawnPos.X
			elseif zombieDir.X < 0 then
				-- Normal zombies go negative X, hypnotized go positive
				reachedSpawn = newX >= spawnPos.X
			end

			if reachedSpawn then
				-- Despawn without dealing damage to base
				EntityPool.SafeDespawn(id, world)
				NetworkUtils.BroadcastEntityDied(id)
				continue
			end
		end

		-- Check if zombie reached the base (direction-aware)
		local reachedBase = false
		if zombieDir.X > 0 then
			reachedBase = newX >= basePos.X
		elseif zombieDir.X < 0 then
			reachedBase = newX <= basePos.X
		end

		if reachedBase then
			if not state.value.ReachedHouse[id] then
				state.value.ReachedHouse[id] = true

				-- Deal damage to base
				BaseHealth.OnZombieReachedHouse()

				-- Release zombie back to pool
				EntityPool.SafeDespawn(id, world)

				-- Broadcast zombie death
				NetworkUtils.BroadcastEntityDied(id)
			end
			continue
		end

		-- Update PositionComponent
		world:insert(
			id,
			Components.PositionComponent({
				X = newX,
				Y = newY,
				Z = newZ,
			})
		)

		-- Update GridPositionComponent if zombie has one
		local gridPos = world:get(id, Components.GridPositionComponent)
		if gridPos then
			local newColumn = worldXToGridColumn(newX, cachedConfig)
			if newColumn and newColumn ~= gridPos.Column then
				world:insert(
					id,
					Components.GridPositionComponent({
						Row = gridPos.Row,
						Column = newColumn,
					})
				)
			end
		end

		-- Track position for batched network update
		state.value.PositionUpdates[id] = newX
	end

	-- Send batched position updates to clients (throttled)
	if currentTime - state.value.LastBatchTime >= CONFIG.BATCH_INTERVAL then
		local entityIds = {}
		local positionsX = {}

		for entityId, posX in state.value.PositionUpdates do
			if world:contains(entityId) then
				table.insert(entityIds, entityId)
				table.insert(positionsX, posX)
			end
		end

		if #entityIds > 0 then
			Network.ZombiePositionBatch.FireAll({
				EntityIds = entityIds :: any,
				PositionsX = positionsX :: any,
			})
		end

		table.clear(state.value.PositionUpdates)
		state.value.LastBatchTime = currentTime
	end

	-- Clean up tracking for despawned zombies
	for id in state.value.ReachedHouse do
		if not world:contains(id) then
			state.value.ReachedHouse[id] = nil
		end
	end
end

-- 5. EXPORT
return {
	priority = 150,
	system = ZombieMovementSystem,
}
