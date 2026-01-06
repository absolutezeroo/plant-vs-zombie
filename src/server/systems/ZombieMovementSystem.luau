--!strict
--[[
	ZombieMovementSystem.luau - Server-side zombie movement
	
	Priority: 150 (Simulation phase - after spawn)
	
	Moves zombies towards the house (left).
	Stops zombie when eating a plant.
	Checks for game over condition (zombie reaches house).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = Shared.components
local GridConfig = require(Shared.config.GridConfig)
local Logger = require(Shared.utils.Logger)

-- Network
local Server = script.Parent.Parent
local Network = require(Server.network.generated)
local BaseHealth = require(Server.modules.BaseHealth)

-- Components
local PositionComponent = require(Components.PositionComponent)
local MovementComponent = require(Components.MovementComponent)
local ZombieTypeComponent = require(Components.ZombieTypeComponent)
local TargetComponent = require(Components.TargetComponent)

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
		
		-- Apply velocity
		local newX = pos.X + movement.VelocityX * dt
		local newY = pos.Y + movement.VelocityY * dt
		local newZ = pos.Z + movement.VelocityZ * dt
		
		-- Check game over condition
		if newX <= MovementConfig.HOUSE_X then
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
			newX = MovementConfig.HOUSE_X
		end
		
		-- Update position
		world:insert(id, PositionComponent({
			X = newX,
			Y = newY,
			Z = newZ
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

return {
	system = ZombieMovementSystem,
	priority = 150,
}
