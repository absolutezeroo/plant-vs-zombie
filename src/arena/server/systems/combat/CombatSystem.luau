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
	- Spawns ProjectileHitEvent for mutation systems to process
]]

--------------------------------------------------------------------------------
-- [1] IMPORTS
--------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local GameConstants = require(Shared.config.GameConstants)
local ZombieData = require(Shared.data.ZombieData)
local PlantData = require(Shared.data.PlantData)
local Types = require(Shared.Types)
local EntityPool = require(Shared.utils.EntityPool)
local ChanceUtils = require(Shared.utils.ChanceUtils)
local ECSUtils = require(Shared.utils.ECSUtils)
local LaneCache = require(Shared.utils.LaneCache)

type MatterWorld = Types.MatterWorld

local Network = require(Shared.network.generated.server)

--------------------------------------------------------------------------------
-- [2] CONFIG (frozen constants from GameConstants)
--------------------------------------------------------------------------------
local CONFIG = table.freeze({
	PROJECTILE_HIT_RADIUS = GameConstants.Combat.PROJECTILE_HIT_RADIUS,
	ZOMBIE_BITE_RANGE = GameConstants.Combat.ZOMBIE_BITE_RANGE,
	ZOMBIE_BITE_INTERVAL = GameConstants.Combat.ZOMBIE_BITE_INTERVAL,
	MULTI_DIR_RADIUS_MULT = 1.5, -- Multiplier for multi-directional projectiles
})

--------------------------------------------------------------------------------
-- [3] STATE (mutable runtime state)
--------------------------------------------------------------------------------
local State = {
	ZombieAttackTimes = {} :: { [number]: number },
	FrameStats = {
		projectileHits = 0,
		splashHits = 0,
		stunsApplied = 0,
		stunsExpired = 0,
		slowsApplied = 0,
		slowsExpired = 0,
		thawsApplied = 0,
		zombieBites = 0,
		plantsDestroyed = 0,
	},
	CachedGridOrigin = Vector3.zero,
	CachedCellWidth = 6,
	CachedZombieDir = Vector3.new(-1, 0, 0),
	IsInitialized = false,
}

--------------------------------------------------------------------------------
-- [4] PRIVATE HELPERS
--------------------------------------------------------------------------------
local function resetFrameStats()
	State.FrameStats.projectileHits = 0
	State.FrameStats.splashHits = 0
	State.FrameStats.stunsApplied = 0
	State.FrameStats.stunsExpired = 0
	State.FrameStats.slowsApplied = 0
	State.FrameStats.slowsExpired = 0
	State.FrameStats.thawsApplied = 0
	State.FrameStats.zombieBites = 0
	State.FrameStats.plantsDestroyed = 0
end

-- Logging removed (was _frameStats debug log)

-- Apply damage to an entity (returns true if killed)
local function applyDamage(world: MatterWorld, entityId: number, damage: number, piercesShields: boolean?): boolean
	local health = world:get(entityId, Components.HealthComponent)

	if not health then
		return false
	end

	-- Check if zombie has shield and projectile doesn't pierce
	local zombie = world:get(entityId, Components.ZombieTypeComponent)

	if zombie and not piercesShields then
		local zombieStats = ZombieData[zombie.ZombieType]
		if zombieStats and zombieStats.HasShield then
			-- Shield absorbs ALL damage until destroyed (blocks projectiles)
			-- Projectiles with PiercesShields bypass this entirely
			-- Shield health is tracked separately from zombie health

			-- Get current shield health from component or initialize from data
			local shield = world:get(entityId, Components.ShieldComponent)

			if not shield then
				-- First hit: initialize shield from ZombieData
				shield = { Current = zombieStats.ShieldHealth or 0, Max = zombieStats.ShieldHealth or 0 }
				world:insert(entityId, Components.ShieldComponent(shield))
			end

			if shield.Current > 0 then
				-- Shield absorbs damage
				local remainingDamage = math.max(0, damage - shield.Current)
				local newShieldHealth = math.max(0, shield.Current - damage)

				world:insert(
					entityId,
					Components.ShieldComponent({
						Current = newShieldHealth,
						Max = shield.Max,
					})
				)

				if newShieldHealth <= 0 then
					-- Broadcast shield destroyed event
					Network.EntityDamaged.FireAll({
						EntityId = entityId,
						NewHealth = health.Current, -- Health unchanged
						DamageAmount = 0, -- Shield took all damage
						ShieldDestroyed = true,
					})
				end

				-- If shield absorbed all damage, no health damage
				if remainingDamage <= 0 then
					return false -- Not dead
				end

				-- Overflow damage goes to health
				damage = remainingDamage
			end
		end
	end

	-- Apply damage using ECSUtils (handles clamping and returns actual damage)
	local actualDamage, isDead = ECSUtils.DamageEntity(world, entityId, damage, Components)

	-- Broadcast damage event
	local newHealth = world:get(entityId, Components.HealthComponent)
	Network.EntityDamaged.FireAll({
		EntityId = entityId,
		NewHealth = newHealth and newHealth.Current or 0,
		DamageAmount = actualDamage,
	})

	return isDead
end

-- Apply splash damage to zombies near impact point
-- OPTIMIZED: Uses LaneCache for O(lane_range) instead of O(all_zombies)
local function applySplashDamage(
	world: MatterWorld,
	impactX: number,
	impactZ: number,
	splash: any,
	proj: any,
	impactLane: number?
)
	local hitCount = 0

	-- Calculate lane radius from splash radius
	local laneRadius = math.ceil(splash.SplashRadius / GridConfig.CELL_SIZE)
	local centerLane = impactLane or 3

	-- O(lane_range) lookup instead of O(N) world:query
	local zombiesInRange = LaneCache.GetEntitiesInLaneRange(centerLane, laneRadius)

	for _, zombieId in zombiesInRange do
		local zombiePos = LaneCache.GetPosition(zombieId)
		if not zombiePos then
			continue
		end

		local dx = zombiePos.X - impactX
		local dz = zombiePos.Z - impactZ
		local distance = math.sqrt(dx * dx + dz * dz)

		if distance <= splash.SplashRadius then
			local killed = applyDamage(world, zombieId, splash.SplashDamage, proj.PiercesShields)
			hitCount += 1

			-- Apply slow if frozen splash
			if proj.IsFrozen and not killed and proj.SlowPercent then
				world:insert(
					zombieId,
					Components.SlowComponent({
						SlowPercent = proj.SlowPercent,
						Duration = proj.SlowDuration,
						AppliedAt = os.clock(),
					})
				)
				State.FrameStats.slowsApplied += 1
			end
		end
	end

	State.FrameStats.splashHits += hitCount
end

-- Try to apply stun effect (butter from Kernel-pult)
local function tryApplyStun(world: MatterWorld, zombieId: number, proj: any): boolean
	if not proj.CanStun or proj.StunChance <= 0 then
		return false
	end

	-- Roll for stun chance
	if ChanceUtils.Roll(proj.StunChance) then
		world:insert(
			zombieId,
			Components.StunComponent({
				Duration = proj.StunDuration,
				AppliedAt = os.clock(),
			})
		)
		State.FrameStats.stunsApplied += 1
		return true
	end

	return false
end

-- Find plant at grid position (ignores traps - zombies walk over them)
-- OPTIMIZED: Uses LaneCache for O(1) lookup instead of O(P) world:query
local function findPlantAtPosition(world: MatterWorld, column: number, lane: number): number?
	local plantId = LaneCache.GetPlantAt(column, lane)
	
	if not plantId then
		return nil
	end
	
	-- Validate entity still exists (could have been despawned this frame)
	if not world:contains(plantId) then
		return nil
	end
	
	-- Get plant type to check if it's a trap
	local plant = world:get(plantId, Components.PlantTypeComponent)
	if not plant then
		return nil
	end
	
	-- Skip traps - zombies don't stop to eat them (e.g., Spikeweed)
	local plantStats = PlantData[plant.PlantType]
	if plantStats and plantStats.IsTrap then
		return nil
	end
	
	return plantId
end

-- Get grid column from world X position (uses cached values from Init)
local function getColumnFromX(x: number): number
	local origin = State.CachedGridOrigin
	local cellW = State.CachedCellWidth
	local localX = x - origin.X
	return math.floor(localX / cellW) + 1
end

-- Get grid lane from world Z position (uses cached values from Init)
local function getLaneFromZ(z: number): number
	local origin = State.CachedGridOrigin
	local cellW = State.CachedCellWidth
	local localZ = z - origin.Z
	local lane = math.floor(localZ / cellW) + 1
	return math.clamp(lane, 1, GridConfig.GRID_LANES)
end

--------------------------------------------------------------------------------
-- [5] ONSTEP (main loop - CANNOT yield)
--------------------------------------------------------------------------------
local function OnStep(world: MatterWorld)
	local currentTime = os.clock()

	-- Reset frame stats at start of combat processing
	resetFrameStats()
	
	-- Refresh cached MapConfig values (may change after loadmap)
	if MapConfig.IsInitialized() then
		State.CachedGridOrigin = MapConfig.GetGridOrigin()
		State.CachedCellWidth = MapConfig.GetCellSize()
		State.CachedZombieDir = MapConfig.GetZombieDirection()
	end

	-- Process stun effect expiration
	for zombieId, stun in world:query(Components.StunComponent) do
		if currentTime - stun.AppliedAt >= stun.Duration then
			world:remove(zombieId, Components.StunComponent)
			State.FrameStats.stunsExpired += 1
		end
	end

	-- Process projectile-zombie collisions
	for projId, projPos, proj in world:query(Components.PositionComponent, Components.ProjectileComponent) do
		local hitZombie = false
		local hitZombieId = nil

		-- Check for multi-directional projectiles (Starfruit)
		local isMultiDir = proj.DirectionZ and proj.DirectionZ ~= 0

		-- Check if projectile can hit flying zombies
		local canHitFlying = proj.CanHitFlying or false

		-- Get zombies to check based on projectile type
		local zombiesToCheck: { number }
		if isMultiDir then
			-- Multi-directional: check nearby lanes (±1 lane radius)
			zombiesToCheck = LaneCache.GetEntitiesInLaneRange(proj.Lane or 3, 1)
		else
			-- Normal: only check same lane (O(1) lookup)
			zombiesToCheck = LaneCache.GetEntitiesInLane(proj.Lane)
		end

		for _, zombieId in zombiesToCheck do
			-- Check if entity still exists (could have been killed by another projectile)
			if not world:contains(zombieId) then
				continue
			end

			-- Skip hypnotized zombies (allies) - projectiles pass through them
			if LaneCache.IsHypnotized(zombieId) then
				continue
			end

			-- Get zombie components (already filtered by lane)
			local zombiePos = world:get(zombieId, Components.PositionComponent)
			local zombie = world:get(zombieId, Components.ZombieTypeComponent)

			if not zombiePos or not zombie then
				continue
			end

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
				inRange = distance <= CONFIG.PROJECTILE_HIT_RADIUS * CONFIG.MULTI_DIR_RADIUS_MULT
			else
				-- Normal: check X distance only (lane already filtered)
				local distance = math.abs(projPos.X - zombiePos.X)
				inRange = distance <= CONFIG.PROJECTILE_HIT_RADIUS
			end

			if inRange then
				-- Check if fire pea thaws frozen zombies
				local enhanced = world:get(projId, Components.EnhancedProjectileComponent)
				if enhanced and enhanced.IsFirePea and enhanced.ThawsFrozen then
					-- Remove slow from zombie
					if world:get(zombieId, Components.SlowComponent) then
						world:remove(zombieId, Components.SlowComponent)
						State.FrameStats.thawsApplied += 1
					end
				end

				-- Calculate damage (with fire multiplier if applicable)
				local damage = proj.Damage
				if enhanced and enhanced.DamageMultiplier then
					damage = math.floor(damage * enhanced.DamageMultiplier)
				end

				-- Apply damage
				local killed = applyDamage(world, zombieId, damage, proj.PiercesShields)

				-- Spawn ProjectileHitEvent for mutation systems to process
				if proj.SourceEntity then
					world:spawn(Components.ProjectileHitEvent({
						SourcePlant = proj.SourceEntity,
						TargetZombie = zombieId,
						Damage = damage,
						PositionX = zombiePos.X,
						PositionY = zombiePos.Y,
						PositionZ = zombiePos.Z,
						Lane = zombie.Lane, -- For optimized AoE lookups
						WasKill = killed,
					}))
				end

				-- Apply slow effect if frozen projectile (and not fire pea)
				if proj.IsFrozen and not killed and proj.SlowPercent and proj.SlowDuration then
					if not (enhanced and enhanced.IsFirePea) then
						world:insert(
							zombieId,
							Components.SlowComponent({
								SlowPercent = proj.SlowPercent,
								Duration = proj.SlowDuration,
								AppliedAt = currentTime,
							})
						)
						State.FrameStats.slowsApplied += 1
					end
				end

				-- Try to apply stun (Kernel-pult butter)
				if not killed then
					tryApplyStun(world, zombieId, proj)
				end

				State.FrameStats.projectileHits += 1

				hitZombie = true
				hitZombieId = zombieId
				break
			end
		end

		if hitZombie then
			-- Check for splash damage (Melon-pult, Winter Melon)
			local splash = world:get(projId, Components.SplashComponent)
			if splash and splash.SplashRadius > 0 then
				applySplashDamage(world, projPos.X, projPos.Z, splash, proj, proj.Lane)
			end

			-- Notify client of impact for VFX
			local enhanced = world:get(projId, Components.EnhancedProjectileComponent)
			Network.ProjectileHit.FireAll({
				EntityId = projId,
				PositionX = projPos.X,
				PositionY = projPos.Y,
				PositionZ = projPos.Z,
				Variant = nil, -- TODO: Could send variant for variant-specific VFX
				IsFrozen = proj.IsFrozen,
				IsEnhanced = if enhanced then enhanced.IsFirePea else false,
			})

			-- Release projectile back to pool
			EntityPool.SafeDespawn(projId, world)
		end
	end

	-- Process slow effect expiration
	for zombieId, slow in world:query(Components.SlowComponent) do
		if currentTime - slow.AppliedAt >= slow.Duration then
			world:remove(zombieId, Components.SlowComponent)
			State.FrameStats.slowsExpired += 1
		end
	end

	-- Skip stunned zombies from attacking
	-- Process zombie eating plants (or hypnotized zombies attacking other zombies)
	for zombieId, zombiePos, zombie, zombieHealth in
		world:query(Components.PositionComponent, Components.ZombieTypeComponent, Components.HealthComponent)
	do
		-- Skip stunned zombies
		local stun = world:get(zombieId, Components.StunComponent)
		if stun then
			continue
		end

		local stats = ZombieData[zombie.ZombieType]
		if not stats then
			continue
		end
		
		-- Check if this zombie is hypnotized
		local hypnotized = world:get(zombieId, Components.HypnotizedComponent)
		
		-- Hypnotized zombies attack other zombies instead of plants
		if hypnotized then
			-- Check for other zombies in bite range
			local target = world:get(zombieId, Components.TargetComponent)
			
			if target then
				-- Already attacking - check if target still exists
				if not world:contains(target.TargetEntity) then
					-- Target destroyed, resume moving (backward toward zombie spawns)
					local direction = State.CachedZombieDir
					world:remove(zombieId, Components.TargetComponent)
					world:insert(
						zombieId,
						Components.MovementComponent({
							VelocityX = -direction.X * stats.Speed,
							VelocityY = 0,
							VelocityZ = -direction.Z * stats.Speed,
						})
					)
					State.ZombieAttackTimes[zombieId] = nil
					continue
				end
				
				-- Attack the enemy zombie
				local lastAttack = State.ZombieAttackTimes[zombieId] or 0
				if currentTime - lastAttack >= stats.AttackSpeed then
					local killed = applyDamage(world, target.TargetEntity, stats.Damage)
					State.ZombieAttackTimes[zombieId] = currentTime
					State.FrameStats.zombieBites += 1
					
					if killed then
						-- Resume moving backward
						local direction = State.CachedZombieDir
						world:remove(zombieId, Components.TargetComponent)
						world:insert(
							zombieId,
							Components.MovementComponent({
								VelocityX = -direction.X * stats.Speed,
								VelocityY = 0,
								VelocityZ = -direction.Z * stats.Speed,
							})
						)
						State.ZombieAttackTimes[zombieId] = nil
					end
				end
			else
				-- Find enemy zombie to attack (non-hypnotized zombies)
				local lane = getLaneFromZ(zombiePos.Z)
				local zombiesInLane = LaneCache.GetEntitiesInLane(lane)
				
				for _, otherZombieId in zombiesInLane do
					if otherZombieId == zombieId then
						continue
					end
					
					-- Skip other hypnotized zombies (allies)
					local otherHypnotized = world:get(otherZombieId, Components.HypnotizedComponent)
					if otherHypnotized then
						continue
					end
					
					local otherPos = LaneCache.GetPosition(otherZombieId)
					if not otherPos then
						continue
					end
					
					-- Check if in bite range
					local dx = otherPos.X - zombiePos.X
					local dz = otherPos.Z - zombiePos.Z
					local dist = math.sqrt(dx * dx + dz * dz)
					
					if dist <= CONFIG.ZOMBIE_BITE_RANGE then
						-- Start attacking this zombie
						world:insert(zombieId, Components.TargetComponent({
							TargetEntity = otherZombieId,
							TargetType = "Zombie",
						}))
						world:insert(
							zombieId,
							Components.MovementComponent({
								VelocityX = 0,
								VelocityY = 0,
								VelocityZ = 0,
							})
						)
						break
					end
				end
			end
			continue -- Skip normal plant-eating logic for hypnotized zombies
		end

		-- Check if zombie has a target
		local target = world:get(zombieId, Components.TargetComponent)

		if target then
			-- Already eating - check if target still exists
			if not world:contains(target.TargetEntity) then
				-- Target destroyed, resume moving
				local direction = State.CachedZombieDir
				world:remove(zombieId, Components.TargetComponent)
				world:insert(
					zombieId,
					Components.MovementComponent({
						VelocityX = direction.X * stats.Speed,
						VelocityY = 0,
						VelocityZ = direction.Z * stats.Speed,
					})
				)
				State.ZombieAttackTimes[zombieId] = nil
				continue
			end

			-- Check attack timer
			local lastAttack = State.ZombieAttackTimes[zombieId] or 0
			if currentTime - lastAttack >= stats.AttackSpeed then
				-- Determine actual target (may be redirected to Pumpkin shell)
				local actualTarget = target.TargetEntity
				local shell = world:get(target.TargetEntity, Components.ShellComponent)
				
				-- If plant is protected by a shell (Pumpkin), damage the shell instead
				if shell and shell.ProtectedByShell then
					local pumpkinId = shell.ProtectedByShell
					if world:contains(pumpkinId) then
						actualTarget = pumpkinId
					end
				end
				
				-- Bite the actual target!
				local killed = applyDamage(world, actualTarget, stats.Damage)
				State.ZombieAttackTimes[zombieId] = currentTime
				State.FrameStats.zombieBites += 1

				if killed then
					-- Check if we killed a HypnoShroom (before Pumpkin check, as HypnoShroom may be protected)
					local killedPlant = world:get(actualTarget, Components.PlantTypeComponent)
					if killedPlant then
						local plantStats = PlantData[killedPlant.PlantType]
						if plantStats and plantStats.HypnotizesOnDeath then
							-- Hypnotize this zombie!
							local direction = State.CachedZombieDir
							
							-- Add HypnotizedComponent
							world:insert(zombieId, Components.HypnotizedComponent({
								HypnotizedAt = currentTime,
								OriginalSpeed = stats.Speed,
							}))
							
							-- Reverse movement direction (zombie now walks toward zombie spawns)
							world:remove(zombieId, Components.TargetComponent)
							world:insert(
								zombieId,
								Components.MovementComponent({
									VelocityX = -direction.X * stats.Speed,
									VelocityY = 0,
									VelocityZ = -direction.Z * stats.Speed,
								})
							)
							
							-- Broadcast hypnotization event
							Network.ZombieHypnotized.FireAll({
								ZombieId = zombieId,
							})
							
							State.ZombieAttackTimes[zombieId] = nil
							State.FrameStats.plantsDestroyed += 1
							continue
						end
					end
					
					-- Check if we killed a Pumpkin protecting a plant
					local killedShell = world:get(actualTarget, Components.ShellComponent)
					if killedShell and killedShell.ProtectsPlant then
						-- Pumpkin destroyed - inner plant is now exposed
						local innerPlantId = killedShell.ProtectsPlant
						if world:contains(innerPlantId) then
							-- Remove protection from inner plant
							world:remove(innerPlantId, Components.ShellComponent)
							-- Zombie continues eating the inner plant (don't resume moving)
							world:insert(zombieId, Components.TargetComponent({
								TargetEntity = innerPlantId,
								TargetType = "Plant",
							}))
							State.FrameStats.plantsDestroyed += 1
							-- Don't resume moving - continue eating inner plant
							continue
						end
					end
					
					-- Plant/Shell destroyed, resume moving
					local direction = State.CachedZombieDir
					world:remove(zombieId, Components.TargetComponent)
					world:insert(
						zombieId,
						Components.MovementComponent({
							VelocityX = direction.X * stats.Speed,
							VelocityY = 0,
							VelocityZ = direction.Z * stats.Speed,
						})
					)
					State.ZombieAttackTimes[zombieId] = nil
					State.FrameStats.plantsDestroyed += 1
				end
			end
		else
			-- No target - check if there's a plant in our path
			local column = getColumnFromX(zombiePos.X)
			local zombieDir = State.CachedZombieDir
			
			-- Flying zombies skip ground plants entirely (they fly over)
			if stats.IsFlying then
				-- Flying zombies don't eat plants, they fly past them
				continue
			end

			-- Check current column and columns ahead of zombie (in its movement direction)
			-- If zombie moves -X, check column and column-1; if +X, check column and column+1
			local colStep = if zombieDir.X < 0 then -1 else 1
			local startCol = column
			local endCol = math.clamp(column + colStep * 2, 1, GridConfig.GRID_COLUMNS)

			for checkCol = startCol, endCol, colStep do
				if checkCol < 1 or checkCol > GridConfig.GRID_COLUMNS then
					continue
				end

				local plantId = findPlantAtPosition(world, checkCol, zombie.Lane)
				if plantId then
					local plantPos = world:get(plantId, Components.PositionComponent)
					if plantPos then
						-- Use absolute distance for collision detection
						local absDistance = math.abs(zombiePos.X - plantPos.X)

						-- Check if zombie is within bite range of plant
						if absDistance <= CONFIG.ZOMBIE_BITE_RANGE then
							-- Check if zombie can vault over this plant (Pole Vaulter)
							if stats.CanJump and not world:get(zombieId, Components.VaultedComponent) then
								-- Check if plant blocks jumpers (TallNut, etc.)
								local plantComp = world:get(plantId, Components.PlantTypeComponent)
								local plantStats = if plantComp then PlantData[plantComp.PlantType] else nil
								local blocksJumpers = plantStats and plantStats.BlocksJumpers
								
								if not blocksJumpers then
									-- Vault over this plant!
									-- Mark as vaulted (can only vault once)
									world:insert(
										zombieId,
										Components.VaultedComponent({
											VaultedAt = currentTime,
										})
									)
									
									-- Calculate jump landing position (past the plant)
									local jumpDistance = CONFIG.ZOMBIE_BITE_RANGE * 3
									local vaultDir = State.CachedZombieDir
									local endX = zombiePos.X + (vaultDir.X * jumpDistance)
									local endZ = zombiePos.Z + (vaultDir.Z * jumpDistance)
									
									-- Send vault event to clients (for jump animation)
									Network.ZombieVaulted.FireAll({
										EntityId = zombieId,
										StartX = zombiePos.X,
										StartY = zombiePos.Y,
										StartZ = zombiePos.Z,
										EndX = endX,
										EndY = zombiePos.Y,
										EndZ = endZ,
									})
									
									-- Update server position (client will animate)
									world:insert(
										zombieId,
										Components.PositionComponent({
											X = endX,
											Y = zombiePos.Y,
											Z = endZ,
										})
									)
									
									-- Continue moving (don't stop to eat)
									world:insert(
										zombieId,
										Components.MovementComponent({
											VelocityX = vaultDir.X * stats.Speed,
											VelocityY = 0,
											VelocityZ = vaultDir.Z * stats.Speed,
										})
									)
									
									-- Skip eating this plant
									break
								end
								-- If blocked by TallNut, fall through to normal eating
							end
							
							-- Start eating!
							world:insert(
								zombieId,
								Components.TargetComponent({
									TargetEntity = plantId,
									TargetType = "Plant",
								})
							)

							-- Stop moving
							world:insert(
								zombieId,
								Components.MovementComponent({
									VelocityX = 0,
									VelocityY = 0,
									VelocityZ = 0,
								})
							)

							State.ZombieAttackTimes[zombieId] = currentTime
							break
						end
					end
				end
			end
			
			-- If no plant target yet, check for hypnotized zombies to attack
			local currentTarget = world:get(zombieId, Components.TargetComponent)
			if not currentTarget then
				local lane = zombie.Lane
				local zombiesInLane = LaneCache.GetEntitiesInLane(lane)
				
				for _, otherZombieId in zombiesInLane do
					if otherZombieId == zombieId then
						continue
					end
					
					-- Only attack hypnotized zombies (they're now allies of the player)
					local otherHypnotized = world:get(otherZombieId, Components.HypnotizedComponent)
					if not otherHypnotized then
						continue
					end
					
					local otherPos = LaneCache.GetPosition(otherZombieId)
					if not otherPos then
						continue
					end
					
					-- Check if hypnotized zombie is ahead of us (in our movement direction)
					local zombieDir = State.CachedZombieDir
					local isAhead = if zombieDir.X < 0 then otherPos.X < zombiePos.X else otherPos.X > zombiePos.X
					if not isAhead then
						continue
					end
					
					-- Check if in bite range
					local dx = otherPos.X - zombiePos.X
					local dz = otherPos.Z - zombiePos.Z
					local dist = math.sqrt(dx * dx + dz * dz)
					
					if dist <= CONFIG.ZOMBIE_BITE_RANGE then
						-- Start attacking this hypnotized zombie
						world:insert(zombieId, Components.TargetComponent({
							TargetEntity = otherZombieId,
							TargetType = "Zombie",
						}))
						world:insert(
							zombieId,
							Components.MovementComponent({
								VelocityX = 0,
								VelocityY = 0,
								VelocityZ = 0,
							})
						)
						State.ZombieAttackTimes[zombieId] = currentTime
						break
					end
				end
			end
		end
	end

	-- Clean up attack times for despawned zombies
	for zombieId in State.ZombieAttackTimes do
		if not world:contains(zombieId) then
			State.ZombieAttackTimes[zombieId] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- [6] INIT / DISPOSE
--------------------------------------------------------------------------------
local function Init(_world)
	if State.IsInitialized then
		return
	end

	-- Pre-cache MapConfig values to avoid yield in OnStep
	-- Note: MapConfig getters work regardless of init state
	State.CachedGridOrigin = MapConfig.GetGridOrigin()
	State.CachedCellWidth = MapConfig.GetCellSize()
	State.CachedZombieDir = MapConfig.GetZombieDirection()

	State.IsInitialized = true
end

local function Dispose()
	State.IsInitialized = false
	State.CachedGridOrigin = Vector3.zero
	State.CachedCellWidth = 6
	State.CachedZombieDir = Vector3.new(-1, 0, 0)
	table.clear(State.ZombieAttackTimes)
	resetFrameStats()
end

--------------------------------------------------------------------------------
-- [7] EXPORT
--------------------------------------------------------------------------------
return {
	priority = 170,
	system = OnStep,
	Init = Init,
	Dispose = Dispose,
}
