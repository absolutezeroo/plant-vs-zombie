--!strict
--[[
	ZombieMovementSystem.luau - Server-side zombie movement
	
	Priority: 150 (Simulation phase - after spawn)
	
	Moves zombies towards the house using frame-rate independent movement.
	Stops zombie when eating a plant.
	Checks for game over condition (zombie reaches house).
	Updates GridPositionComponent as zombie moves through the grid.
	
	CRITICAL: Uses Matter.useDeltaTime() for lag-independent movement.
	Formula: NewPosition = OldPosition + (Velocity * dt)
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - processes zombie movement
	- Dispose(): Clear tracking state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local Logger = require(Shared.utils.Logger)
local EntityPool = require(Shared.utils.EntityPool)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent
local BaseHealth = require(Server.modules.BaseHealth)

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local MovementComponent = Components.MovementComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local TargetComponent = Components.TargetComponent
local SlowComponent = Components.SlowComponent
local StunComponent = Components.StunComponent
local GridPositionComponent = Components.GridPositionComponent

-- Movement config
local MovementConfig = {
	BATCH_INTERVAL = 0.1,            -- Seconds between position broadcasts
	MIN_DT = 1/120,                  -- Minimum deltaTime to prevent physics explosion
	MAX_DT = 1/15,                   -- Maximum deltaTime to prevent teleporting on lag spikes
}

-- State for batched position updates
local _lastBatchTime = 0
local _positionUpdates: {[number]: number} = {} -- entityId -> positionX
local _reachedHouse: {[number]: boolean} = {} -- Track zombies that reached house

--[[
	Convert world X position to grid column
	Returns the column (1-based) or nil if outside grid
]]
local function worldXToGridColumn(worldX: number): number?
	local config = MapConfig.GetConfig()
	local gridOriginX = config.GridCornerA.X
	local cellWidth = config.CellWidth or GridConfig.CELL_SIZE
	
	-- Calculate column (1-based)
	local column = math.floor((worldX - gridOriginX) / cellWidth) + 1
	
	-- Clamp to valid range
	if column < 1 then
		return 1
	elseif column > GridConfig.GRID_COLUMNS then
		return GridConfig.GRID_COLUMNS
	end
	
	return column
end

local function ZombieMovementSystem(world)
	local currentTime = os.clock()
	
	-- CRITICAL: Use Matter's deltaTime for frame-rate independence
	local dt = Matter.useDeltaTime()
	
	-- Clamp deltaTime to prevent physics issues
	dt = math.clamp(dt, MovementConfig.MIN_DT, MovementConfig.MAX_DT)
	
	-- Get base position and zombie direction once per frame
	local basePos = MapConfig.GetBasePosition()
	local zombieDir = MapConfig.GetZombieDirection()
	
	-- Process all zombies with movement
	for id, pos, movement, zombie in world:query(PositionComponent, MovementComponent, ZombieTypeComponent) do
		-- Skip if zombie has a target (eating a plant)
		local target = world:get(id, TargetComponent)
		if target then
			continue
		end
		
		-- Skip if stunned
		local stun = world:get(id, StunComponent)
		if stun then
			continue
		end
		
		-- Skip if already reached house
		if _reachedHouse[id] then
			continue
		end
		
		-- Calculate slow effect multiplier
		local speedMultiplier = 1.0
		local slow = world:get(id, SlowComponent)
		if slow then
			speedMultiplier = 1.0 - slow.SlowPercent
		end
		
		-- FRAME-RATE INDEPENDENT MOVEMENT
		-- Formula: NewPosition = OldPosition + (Velocity * dt * speedMultiplier)
		local newX = pos.X + (movement.VelocityX * dt * speedMultiplier)
		local newY = pos.Y + (movement.VelocityY * dt * speedMultiplier)
		local newZ = pos.Z + (movement.VelocityZ * dt * speedMultiplier)
		
		-- Check if zombie reached the base (direction-aware)
		local reachedBase = false
		if zombieDir.X > 0 then
			-- Zombies moving toward +X (right)
			reachedBase = newX >= basePos.X
		elseif zombieDir.X < 0 then
			-- Zombies moving toward -X (left)
			reachedBase = newX <= basePos.X
		end
		-- Note: If zombieDir.Z != 0, add Z-axis check here
		
		if reachedBase then
			if not _reachedHouse[id] then
				Logger.Warn("ZombieMovement", `Zombie {id} ({zombie.ZombieType}) reached the base!`)
				_reachedHouse[id] = true
				
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
		
		-- Update PositionComponent (data only, no Workspace touch)
		world:insert(id, PositionComponent({
			X = newX,
			Y = newY,
			Z = newZ,
		}))
		
		-- Update GridPositionComponent if zombie has one
		local gridPos = world:get(id, GridPositionComponent)
		if gridPos then
			local newColumn = worldXToGridColumn(newX)
			if newColumn and newColumn ~= gridPos.Column then
				world:insert(id, GridPositionComponent({
					Row = gridPos.Row,
					Column = newColumn,
				}))
			end
		end
		
		-- Track position for batched network update
		_positionUpdates[id] = newX
	end
	
	-- Send batched position updates to clients (throttled)
	if currentTime - _lastBatchTime >= MovementConfig.BATCH_INTERVAL then
		local entityIds = {}
		local positionsX = {}
		
		for entityId, posX in _positionUpdates do
			-- Only include zombies that still exist
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
		
		table.clear(_positionUpdates)
		_lastBatchTime = currentTime
	end
	
	-- Clean up tracking for despawned zombies
	for id in _reachedHouse do
		if not world:contains(id) then
			_reachedHouse[id] = nil
		end
	end
end

local function Init(_world)
	Logger.Debug("ZombieMovement", "Initialized with frame-rate independent movement")
end

local function Dispose()
	_lastBatchTime = 0
	table.clear(_positionUpdates)
	table.clear(_reachedHouse)
	Logger.Debug("ZombieMovement", "Disposed")
end

return {
	_name = "ZombieMovementSystem",
	priority = 150,
	system = ZombieMovementSystem,
	Init = Init,
	Dispose = Dispose,
}
