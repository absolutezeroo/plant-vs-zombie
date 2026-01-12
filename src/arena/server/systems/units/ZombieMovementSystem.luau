--!strict
--[[
	ZombieMovementSystem.luau - Server-side zombie movement
	
	Priority: 150 (Simulation phase - after spawn)
	
	Moves zombies towards the house using frame-rate independent movement.
	Stops zombie when eating a plant.
	Checks for game over condition (zombie reaches house).
	
	CRITICAL: Uses Matter.useDeltaTime() for lag-independent movement.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local EntityPool = require(Shared.utils.EntityPool)

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

-- 3. STATE
local State = {
	IsInitialized = false,
	LastBatchTime = 0,
	PositionUpdates = {} :: { [number]: number },
	ReachedHouse = {} :: { [number]: boolean },
	CachedConfig = nil :: MapConfig.MapConfigType?,
	CachedBasePos = Vector3.zero,
	CachedZombieDir = Vector3.zero,
}

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end

	-- Pre-cache MapConfig to avoid yield in OnStep
	-- MapConfig.Initialize() is called during server bootstrap
	if MapConfig.IsInitialized() then
		State.CachedConfig = MapConfig.GetConfigIfReady()
	else
		-- Fallback: force init (should not happen if bootstrap is correct)
		State.CachedConfig = MapConfig.GetConfig()
	end

	-- Cache frequently used values
	State.CachedBasePos = MapConfig.GetBasePosition()
	State.CachedZombieDir = MapConfig.GetZombieDirection()

	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	State.IsInitialized = false
	State.LastBatchTime = 0
	State.CachedConfig = nil
	State.CachedBasePos = Vector3.zero
	State.CachedZombieDir = Vector3.zero
	table.clear(State.PositionUpdates)
	table.clear(State.ReachedHouse)
end

-- Helper: Convert world X position to grid column
local function worldXToGridColumn(worldX: number): number?
	local config = State.CachedConfig
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

-- 6. MAIN LOOP
local function OnStep(world)
	local currentTime = os.clock()

	-- CRITICAL: Use Matter's deltaTime for frame-rate independence
	local dt = Matter.useDeltaTime()
	dt = math.clamp(dt, CONFIG.MIN_DT, CONFIG.MAX_DT)

	-- Get base position and zombie direction from cache (set in Init)
	local basePos = State.CachedBasePos
	local zombieDir = State.CachedZombieDir

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
		if State.ReachedHouse[id] then
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

		-- Check if zombie reached the base (direction-aware)
		local reachedBase = false
		if zombieDir.X > 0 then
			reachedBase = newX >= basePos.X
		elseif zombieDir.X < 0 then
			reachedBase = newX <= basePos.X
		end

		if reachedBase then
			if not State.ReachedHouse[id] then
				State.ReachedHouse[id] = true

				-- Deal damage to base
				BaseHealth.OnZombieReachedHouse()

				-- Release zombie back to pool
				if EntityPool.IsPooledEntity(id) then
					EntityPool.Despawn(id)
				else
					world:despawn(id)
				end

				-- Broadcast zombie death
				Network.EntityDied.FireAll({
					EntityId = id,
				})
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
			local newColumn = worldXToGridColumn(newX)
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
		State.PositionUpdates[id] = newX
	end

	-- Send batched position updates to clients (throttled)
	if currentTime - State.LastBatchTime >= CONFIG.BATCH_INTERVAL then
		local entityIds = {}
		local positionsX = {}

		for entityId, posX in State.PositionUpdates do
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

		table.clear(State.PositionUpdates)
		State.LastBatchTime = currentTime
	end

	-- Clean up tracking for despawned zombies
	for id in State.ReachedHouse do
		if not world:contains(id) then
			State.ReachedHouse[id] = nil
		end
	end
end

-- 7. EXPORT
return {
	priority = 150,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
