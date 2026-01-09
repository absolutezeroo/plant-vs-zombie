--!strict
--[[
	CombatSystem.luau - Server-side combat logic
	
	Priority: 170 (Simulation phase - after projectiles)
	
	Handles:
	- Projectile-Zombie collision detection
	- Splash damage (Melon-pult, Winter Melon)
	- Stun effects (Kernel-pult butter)
	- Shield piercing (Fume-shroom)
	- Zombie eating plants
	- Damage application
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - processes combat
	- Dispose(): Clear attack tracking state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local ZombieData = require(Shared.data.ZombieData)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)
local Types = require(Shared.Types)

-- Type alias for world parameter
type MatterWorld = Types.MatterWorld

-- Network
local Network = require(Shared.network.generated.server)

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local PlantTypeComponent = Components.PlantTypeComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local ProjectileComponent = Components.ProjectileComponent
local TargetComponent = Components.TargetComponent
local MovementComponent = Components.MovementComponent
local SlowComponent = Components.SlowComponent
local SplashComponent = Components.SplashComponent
local StunComponent = Components.StunComponent
local EnhancedProjectileComponent = Components.EnhancedProjectileComponent

-- Combat config
local CombatConfig = {
	PROJECTILE_HIT_RADIUS = 2,   -- Studs
	ZOMBIE_BITE_RANGE = 3,       -- How close zombie must be to start eating
	ZOMBIE_BITE_INTERVAL = 1.0,  -- Seconds between bites
}

-- Track zombie attack timers
local _zombieAttackTimes: {[number]: number} = {}

-- Combat stats aggregator (logged once per frame, not per entity)
local _frameStats = {
	projectileHits = 0,
	splashHits = 0,
	stunsApplied = 0,
	stunsExpired = 0,
	slowsApplied = 0,
	slowsExpired = 0,
	thawsApplied = 0,
	zombieBites = 0,
	plantsDestroyed = 0,
}

local function resetFrameStats()
	_frameStats.projectileHits = 0
	_frameStats.splashHits = 0
	_frameStats.stunsApplied = 0
	_frameStats.stunsExpired = 0
	_frameStats.slowsApplied = 0
	_frameStats.slowsExpired = 0
	_frameStats.thawsApplied = 0
	_frameStats.zombieBites = 0
	_frameStats.plantsDestroyed = 0
end

local function logFrameStats()
	local hasActivity = _frameStats.projectileHits > 0 or _frameStats.zombieBites > 0 or _frameStats.stunsApplied > 0
	if hasActivity then
		Logger.Debug("Combat", `Frame: {_frameStats.projectileHits} hits, {_frameStats.splashHits} splash, {_frameStats.stunsApplied} stuns, {_frameStats.slowsApplied} slows, {_frameStats.zombieBites} bites`)
	end
end

-- Apply damage to an entity (returns true if killed)
local function applyDamage(world: MatterWorld, entityId: number, damage: number, piercesShields: boolean?): boolean
	local health = world:get(entityId, HealthComponent)
	if not health then
		return false
	end
	
	-- Check if zombie has shield and projectile doesn't pierce
	local zombie = world:get(entityId, ZombieTypeComponent)
	if zombie and not piercesShields then
		local zombieStats = ZombieData[zombie.ZombieType]
		if zombieStats and zombieStats.HasShield and zombieStats.ShieldHealth then
			-- TODO: Implement shield damage reduction
			-- For now, shields just reduce damage by 50%
			damage = math.floor(damage * 0.5)
		end
	end
	
	local newHealth = math.max(0, health.Current - damage)
	
	-- Immutable component update via Sift
	world:insert(entityId, Sift.Dictionary.merge(health, {
		Current = newHealth,
	}))
	
	-- Broadcast damage event
	Network.EntityDamaged.FireAll({
		EntityId = entityId,
		NewHealth = newHealth,
		DamageAmount = damage,
	})
	
	return newHealth <= 0 -- Return true if dead
end

-- Apply splash damage to zombies near impact point
local function applySplashDamage(world: MatterWorld, impactX: number, impactZ: number, splash: any, proj: any)
	local hitCount = 0
	
	for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
		local dx = zombiePos.X - impactX
		local dz = zombiePos.Z - impactZ
		local distance = math.sqrt(dx * dx + dz * dz)
		
		if distance <= splash.SplashRadius then
			local killed = applyDamage(world, zombieId, splash.SplashDamage, proj.PiercesShields)
			hitCount += 1
			
			-- Apply slow if frozen splash
			if proj.IsFrozen and not killed and proj.SlowPercent then
				world:insert(zombieId, SlowComponent({
					SlowPercent = proj.SlowPercent,
					Duration = proj.SlowDuration,
					AppliedAt = os.clock(),
				}))
				_frameStats.slowsApplied += 1
			end
		end
	end
	
	_frameStats.splashHits += hitCount
end

-- Try to apply stun effect (butter from Kernel-pult)
local function tryApplyStun(world: MatterWorld, zombieId: number, proj: any): boolean
	if not proj.CanStun or proj.StunChance <= 0 then
		return false
	end
	
	-- Roll for stun chance
	if math.random() <= proj.StunChance then
		world:insert(zombieId, StunComponent({
			Duration = proj.StunDuration,
			AppliedAt = os.clock(),
		}))
		_frameStats.stunsApplied += 1
		return true
	end
	
	return false
end

-- Find plant at grid position
local function findPlantAtPosition(world: MatterWorld, column: number, lane: number): number?
	for id, plant in world:query(PlantTypeComponent) do
		if plant.Column == column and plant.Lane == lane then
			return id
		end
	end
	return nil
end

-- Get grid column from world X position
local function getColumnFromX(x: number): number
	local origin = MapConfig.GetGridOrigin()
	local cellW, _ = MapConfig.GetCellSize()
	local localX = x - origin.X
	return math.floor(localX / cellW) + 1
end

local function CombatSystem(world: MatterWorld)
	local currentTime = os.clock()
	
	-- Reset frame stats at start of combat processing
	resetFrameStats()
	
	-- Process stun effect expiration
	for zombieId, stun in world:query(StunComponent) do
		if currentTime - stun.AppliedAt >= stun.Duration then
			world:remove(zombieId, StunComponent)
			_frameStats.stunsExpired += 1
		end
	end
	
	-- Process projectile-zombie collisions
	for projId, projPos, proj in world:query(PositionComponent, ProjectileComponent) do
		local hitZombie = false
		local hitZombieId = nil
		
		-- Check for multi-directional projectiles (Starfruit)
		local isMultiDir = proj.DirectionZ and proj.DirectionZ ~= 0
		
		-- Check if projectile can hit flying zombies
		local canHitFlying = proj.CanHitFlying or false
		
		for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
			-- Check if zombie is flying and projectile can't hit flying
			local zombieStats = ZombieData[zombie.ZombieType]
			if zombieStats and zombieStats.IsFlying and not canHitFlying then
				continue -- Skip flying zombies for non-flying projectiles
			end
			
			local inRange = false
			
			if isMultiDir then
				-- Multi-directional: check 3D distance
				local dx = math.abs(projPos.X - zombiePos.X)
				local dz = math.abs(projPos.Z - zombiePos.Z)
				local distance = math.sqrt(dx * dx + dz * dz)
				inRange = distance <= CombatConfig.PROJECTILE_HIT_RADIUS * 1.5
			else
				-- Normal: check same lane and X distance
				if zombie.Lane ~= proj.Lane then
					continue
				end
				local distance = math.abs(projPos.X - zombiePos.X)
				inRange = distance <= CombatConfig.PROJECTILE_HIT_RADIUS
			end
			
			if inRange then
				-- Check if fire pea thaws frozen zombies
				local enhanced = world:get(projId, EnhancedProjectileComponent)
				if enhanced and enhanced.IsFirePea and enhanced.ThawsFrozen then
					-- Remove slow from zombie
					if world:get(zombieId, SlowComponent) then
						world:remove(zombieId, SlowComponent)
						_frameStats.thawsApplied += 1
					end
				end
				
				-- Calculate damage (with fire multiplier if applicable)
				local damage = proj.Damage
				if enhanced and enhanced.DamageMultiplier then
					damage = math.floor(damage * enhanced.DamageMultiplier)
				end
				
				-- Apply damage
				local killed = applyDamage(world, zombieId, damage, proj.PiercesShields)
				
				-- Apply slow effect if frozen projectile (and not fire pea)
				if proj.IsFrozen and not killed and proj.SlowPercent and proj.SlowDuration then
					if not (enhanced and enhanced.IsFirePea) then
						world:insert(zombieId, SlowComponent({
							SlowPercent = proj.SlowPercent,
							Duration = proj.SlowDuration,
							AppliedAt = currentTime,
						}))
						_frameStats.slowsApplied += 1
					end
				end
				
				-- Try to apply stun (Kernel-pult butter)
				if not killed then
					tryApplyStun(world, zombieId, proj)
				end
				
				_frameStats.projectileHits += 1
				
				hitZombie = true
				hitZombieId = zombieId
				break
			end
		end
		
		if hitZombie then
			-- Check for splash damage (Melon-pult, Winter Melon)
			local splash = world:get(projId, SplashComponent)
			if splash and splash.SplashRadius > 0 then
				applySplashDamage(world, projPos.X, projPos.Z, splash, proj)
			end
			
			-- Despawn projectile
			world:despawn(projId)
		end
	end
	
	-- Process slow effect expiration
	for zombieId, slow in world:query(SlowComponent) do
		if currentTime - slow.AppliedAt >= slow.Duration then
			world:remove(zombieId, SlowComponent)
			_frameStats.slowsExpired += 1
		end
	end
	
	-- Skip stunned zombies from attacking
	-- Process zombie eating plants
	for zombieId, zombiePos, zombie, zombieHealth in world:query(PositionComponent, ZombieTypeComponent, HealthComponent) do
		-- Skip stunned zombies
		local stun = world:get(zombieId, StunComponent)
		if stun then
			continue
		end
		
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
				local direction = MapConfig.GetZombieDirection()
				world:remove(zombieId, TargetComponent)
				world:insert(zombieId, MovementComponent({
					VelocityX = direction.X * stats.Speed,
					VelocityY = 0,
					VelocityZ = direction.Z * stats.Speed
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
				_frameStats.zombieBites += 1
				
				if killed then
					-- Plant destroyed, resume moving
					local direction = MapConfig.GetZombieDirection()
					world:remove(zombieId, TargetComponent)
					world:insert(zombieId, MovementComponent({
						VelocityX = direction.X * stats.Speed,
						VelocityY = 0,
						VelocityZ = direction.Z * stats.Speed
					}))
					_zombieAttackTimes[zombieId] = nil
					_frameStats.plantsDestroyed += 1
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
	
	-- Log aggregated frame stats (single log per frame, not per entity)
	logFrameStats()
end

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	table.clear(_zombieAttackTimes)
	resetFrameStats()
end

return {
	_name = "CombatSystem",
	priority = 170,
	system = CombatSystem,
	Init = Init,
	Dispose = Dispose,
}
