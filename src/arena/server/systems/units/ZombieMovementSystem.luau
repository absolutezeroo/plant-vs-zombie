--!strict
--[[
	ZombieMovementSystem.luau - Server-side zombie movement
	
	Priority: 150 (Simulation phase - after spawn)
	
	Moves zombies towards the house (left).
	Stops zombie when eating a plant.
	Checks for game over condition (zombie reaches house).
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - processes zombie movement
	- Dispose(): Clear tracking state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local Logger = require(Shared.utils.Logger)

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

-- Movement config
local MovementConfig = {
	HOUSE_X = -5,                    -- X position of house (game over line)
	BATCH_INTERVAL = 0.1,            -- Seconds between position broadcasts
	POSITION_TOLERANCE = 0.01,       -- Min movement to trigger update
}

-- State for batched position updates
local _lastBatchTime = 0
local _positionUpdates: {[number]: number} = {} -- entityId -> positionX
local _reachedHouse: {[number]: boolean} = {} -- Track zombies that reached house

local function ZombieMovementSystem(world)
	local currentTime = os.clock()
	local dt = 1/60 -- Approximate delta time
	
	-- Process all zombies
	for id, pos, movement, zombie in world:query(PositionComponent, MovementComponent, ZombieTypeComponent) do
		-- Skip if zombie has a target (eating)
		local target = world:get(id, TargetComponent)
		if target then
			continue
		end
		
		-- Skip if already reached house
		if _reachedHouse[id] then
			continue
		end
		
		-- Check for slow effect
		local slowMultiplier = 1.0
		local slow = world:get(id, SlowComponent)
		if slow then
			slowMultiplier = 1.0 - slow.SlowPercent
		end
		
		-- Apply velocity with slow modifier
		local newX = pos.X + movement.VelocityX * dt * slowMultiplier
		local newY = pos.Y + movement.VelocityY * dt * slowMultiplier
		local newZ = pos.Z + movement.VelocityZ * dt * slowMultiplier
		
		-- Check game over condition (zombie reached house)
		-- Use MapConfig to get base position and zombie direction
		local basePos = MapConfig.GetBasePosition()
		local zombieDir = MapConfig.GetZombieDirection()
		
		-- Check if zombie passed the base (direction-aware)
		-- If zombies go +X, check if newX >= basePos.X
		-- If zombies go -X, check if newX <= basePos.X
		local reachedBase = false
		if zombieDir.X > 0 then
			-- Zombies moving toward +X (right)
			reachedBase = newX >= basePos.X
		else
			-- Zombies moving toward -X (left) - original behavior
			reachedBase = newX <= basePos.X
		end
		
		if reachedBase then
			if not _reachedHouse[id] then
				Logger.Warn("ZombieMovement", `Zombie {id} reached the house!`)
				_reachedHouse[id] = true
				
				-- Deal damage to base
				BaseHealth.OnZombieReachedHouse()
				
				-- Despawn the zombie after dealing damage
				world:despawn(id)
				
				-- Broadcast zombie death
				Network.EntityDied.FireAll({
					EntityId = id,
				})
				continue
			end
			newX = basePos.X
		end
		
		-- Update position (immutable via Sift)
		world:insert(id, Sift.Dictionary.merge(pos, {
			X = newX,
			Y = newY,
			Z = newZ,
		}))
		
		-- Track for batch update
		_positionUpdates[id] = newX
	end
	
	-- Send batched position updates
	if currentTime - _lastBatchTime >= MovementConfig.BATCH_INTERVAL then
		local entityIds = {}
		local positionsX = {}
		
		for entityId, posX in _positionUpdates do
			table.insert(entityIds, entityId)
			table.insert(positionsX, posX)
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
	-- No initialization needed
end

local function Dispose()
	_lastBatchTime = 0
	table.clear(_positionUpdates)
	table.clear(_reachedHouse)
end

return {
	_name = "ZombieMovementSystem",
	priority = 150,
	system = ZombieMovementSystem,
	Init = Init,
	Dispose = Dispose,
}
