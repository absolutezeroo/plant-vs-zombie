--!strict
--[[
	CombatSystem.luau - Server-side combat logic
	
	Priority: 170 (Simulation phase - after projectiles)
	
	Handles:
	- Projectile-Zombie collision detection
	- Zombie eating plants
	- Damage application
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = Shared.components
local GridConfig = require(Shared.config.GridConfig)
local ZombieData = require(Shared.data.ZombieData)
local Logger = require(Shared.utils.Logger)

-- Network
local Server = script.Parent.Parent
local Network = require(Server.network.generated)

-- Components
local PositionComponent = require(Components.PositionComponent)
local HealthComponent = require(Components.HealthComponent)
local PlantTypeComponent = require(Components.PlantTypeComponent)
local ZombieTypeComponent = require(Components.ZombieTypeComponent)
local ProjectileComponent = require(Components.ProjectileComponent)
local TargetComponent = require(Components.TargetComponent)
local MovementComponent = require(Components.MovementComponent)

-- Combat config
local CombatConfig = {
	PROJECTILE_HIT_RADIUS = 2,   -- Studs
	ZOMBIE_BITE_RANGE = 3,       -- How close zombie must be to start eating
	ZOMBIE_BITE_INTERVAL = 1.0,  -- Seconds between bites
}

-- Track zombie attack timers
local _zombieAttackTimes: {[number]: number} = {}

-- Apply damage to an entity
local function applyDamage(world: any, entityId: number, damage: number): boolean
	local health = world:get(entityId, HealthComponent)
	if not health then
		return false
	end
	
	local newHealth = math.max(0, health.Current - damage)
	
	world:insert(entityId, HealthComponent({
		Current = newHealth,
		Max = health.Max
	}))
	
	-- Broadcast damage event
	Network.EntityDamaged.FireAll({
		EntityId = entityId,
		NewHealth = newHealth,
		DamageAmount = damage,
	})
	
	return newHealth <= 0 -- Return true if dead
end

-- Find plant at grid position
local function findPlantAtPosition(world: any, column: number, lane: number): number?
	for id, plant in world:query(PlantTypeComponent) do
		if plant.Column == column and plant.Lane == lane then
			return id
		end
	end
	return nil
end

-- Get grid column from world X position
local function getColumnFromX(x: number): number
	local localX = x - GridConfig.GRID_ORIGIN_X
	return math.floor(localX / GridConfig.CELL_SIZE) + 1
end

local function CombatSystem(world)
	local currentTime = os.clock()
	
	-- Process projectile-zombie collisions
	for projId, projPos, proj in world:query(PositionComponent, ProjectileComponent) do
		local hitZombie = false
		
		for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
			-- Check same lane
			if zombie.Lane ~= proj.Lane then
				continue
			end
			
			-- Check distance
			local distance = math.abs(projPos.X - zombiePos.X)
			if distance <= CombatConfig.PROJECTILE_HIT_RADIUS then
				-- Hit!
				local killed = applyDamage(world, zombieId, proj.Damage)
				
				Logger.Debug("Combat", `Pea hit zombie {zombieId} for {proj.Damage} damage (killed={killed})`)
				
				hitZombie = true
				break
			end
		end
		
		if hitZombie then
			-- Despawn projectile
			world:despawn(projId)
		end
	end
	
	-- Process zombie eating plants
	for zombieId, zombiePos, zombie, zombieHealth in world:query(PositionComponent, ZombieTypeComponent, HealthComponent) do
		local stats = ZombieData[zombie.ZombieType]
		if not stats then
			continue
		end
		
		-- Check if zombie has a target
		local target = world:get(zombieId, TargetComponent)
		
		if target then
			-- Already eating - check if target still exists
			if not world:contains(target.TargetEntity) then
				-- Target destroyed, resume moving
				world:remove(zombieId, TargetComponent)
				world:insert(zombieId, MovementComponent({
					VelocityX = -stats.Speed,
					VelocityY = 0,
					VelocityZ = 0
				}))
				_zombieAttackTimes[zombieId] = nil
				continue
			end
			
			-- Check attack timer
			local lastAttack = _zombieAttackTimes[zombieId] or 0
			if currentTime - lastAttack >= stats.AttackSpeed then
				-- Bite!
				local killed = applyDamage(world, target.TargetEntity, stats.Damage)
				_zombieAttackTimes[zombieId] = currentTime
				
				Logger.Debug("Combat", `Zombie {zombieId} bit plant {target.TargetEntity} for {stats.Damage} damage`)
				
				if killed then
					-- Plant destroyed, resume moving
					world:remove(zombieId, TargetComponent)
					world:insert(zombieId, MovementComponent({
						VelocityX = -stats.Speed,
						VelocityY = 0,
						VelocityZ = 0
					}))
					_zombieAttackTimes[zombieId] = nil
				end
			end
		else
			-- No target - check if there's a plant in our path
			local column = getColumnFromX(zombiePos.X)
			
			-- Check current and next column
			for checkCol = column, math.max(1, column - 1), -1 do
				if checkCol < 1 or checkCol > GridConfig.GRID_COLUMNS then
					continue
				end
				
				local plantId = findPlantAtPosition(world, checkCol, zombie.Lane)
				if plantId then
					local plantPos = world:get(plantId, PositionComponent)
					if plantPos then
						local distance = zombiePos.X - plantPos.X
						
						-- Close enough to start eating?
						if distance <= CombatConfig.ZOMBIE_BITE_RANGE and distance >= 0 then
							-- Start eating!
							world:insert(zombieId, TargetComponent({
								TargetEntity = plantId,
								TargetType = "Plant"
							}))
							
							-- Stop moving
							world:insert(zombieId, MovementComponent({
								VelocityX = 0,
								VelocityY = 0,
								VelocityZ = 0
							}))
							
							_zombieAttackTimes[zombieId] = currentTime
							
							Logger.Debug("Combat", `Zombie {zombieId} started eating plant {plantId}`)
							break
						end
					end
				end
			end
		end
	end
	
	-- Clean up attack times for despawned zombies
	for zombieId in _zombieAttackTimes do
		if not world:contains(zombieId) then
			_zombieAttackTimes[zombieId] = nil
		end
	end
end

return {
	system = CombatSystem,
	priority = 170,
}
