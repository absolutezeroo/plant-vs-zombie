--!strict
--[[
	ProjectileSpawnSystem.luau - Server-side projectile spawning logic
	
	Priority: 160 (Simulation phase - after zombie movement)
	
	Handles:
	- Peashooters firing peas at zombies in their lane
	- Multi-shot plants (Repeater, GatlingPea)
	- Three-lane plants (Threepeater)
	- Backwards shooters (SplitPea)
	- Multi-direction plants (Starfruit)
	- Catapult plants (lobbing projectiles)
	- Short-range mushrooms (PuffShroom, SeaShroom, FumeShroom)
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
local PlantData = require(Shared.data.PlantData)
local LaneCache = require(Shared.utils.LaneCache)
local EntityPool = require(Shared.utils.EntityPool)
local GridDetection = require(Shared.utils.GridDetection)

local Network = require(Shared.network.generated.server)

--------------------------------------------------------------------------------
-- [2] CONFIG (frozen constants)
--------------------------------------------------------------------------------
local CONFIG = table.freeze({
	-- Projectile defaults
	SPEED = 15,
	FIRE_INTERVAL = 0.67,
	MAX_RANGE = 100,
	DAMAGE = 20,
	SLOW_PERCENT = GameConstants.Combat.DEFAULT_SLOW_PERCENT,
	SLOW_DURATION = GameConstants.Combat.DEFAULT_SLOW_DURATION,
	SHOT_DELAY = 0.1,
	CATAPULT_SPEED = 10,
	SPAWN_OFFSET_X = 2,
	SPAWN_OFFSET_Y = 2.5,
	SHOOT_RANGE = 54,
})

--------------------------------------------------------------------------------
-- [3] STATE (mutable runtime state)
--------------------------------------------------------------------------------
local State = {
	PlantFireTimes = {} :: { [number]: number },
	PendingMultiShots = {} :: {
		[number]: {
			shotsRemaining: number,
			nextShotTime: number,
			lane: number,
			startX: number,
			plantType: string,
			direction: number,
		},
	},
	CachedZombieDir = Vector3.zero,
	IsInitialized = false,
}

--------------------------------------------------------------------------------
-- [4] PRIVATE HELPERS
--------------------------------------------------------------------------------
-- Check if there are zombies in the lane within shoot range
-- Uses LaneCache for O(1) lane lookup + O(lane_size) direction check
local function hasZombiesInLane(
	_world: any,
	lane: number,
	plantX: number,
	plantZ: number,
	checkBehind: boolean?,
	customRange: number?
): boolean
	local zombieDir = State.CachedZombieDir
	local shootRange = customRange or CONFIG.SHOOT_RANGE
	return LaneCache.HasZombiesInDirection(
		lane,
		plantX,
		plantZ,
		{ X = zombieDir.X, Z = zombieDir.Z },
		checkBehind,
		shootRange
	)
end

-- Check if plant can shoot (not sleeping, not hiding, not chewing)
local function canPlantShoot(world: any, plantId: number): boolean
	-- Check if sleeping (mushrooms during day)
	local sleeping = world:get(plantId, Components.SleepingComponent)
	if sleeping and sleeping.IsSleeping then
		return false
	end

	-- Check if hiding (ScaredyShroom)
	local hiding = world:get(plantId, Components.HidingComponent)
	if hiding and hiding.IsHiding then
		return false
	end

	-- Check if chewing (Chomper)
	local chewing = world:get(plantId, Components.ChewingComponent)
	if chewing then
		return false
	end

	return true
end

-- Spawn a projectile (data-driven from PlantData)
local function spawnProjectile(
	world: any,
	plantId: number,
	lane: number,
	startX: number,
	plantType: string,
	direction: number?
)
	-- Get the direction plants should shoot (opposite of zombie direction)
	local zombieDir = State.CachedZombieDir
	-- Plants shoot in the opposite direction (toward zombie spawns)
	local forwardDirX = -zombieDir.X
	local forwardDirZ = -zombieDir.Z

	local dir = direction or 1 -- 1 = forward (toward zombies), -1 = backward (toward base)
	local laneCenter = MapConfig.GridToWorld(1, lane) -- Safe: MapConfig initialized at bootstrap
	local z = laneCenter.Z

	-- Read stats from PlantData (data-driven)
	local stats = PlantData[plantType]
	local damage = (stats and stats.Damage) or CONFIG.DAMAGE
	local isFrozen = (stats and stats.IsFrozen) or false
	local slowPercent = (stats and stats.SlowPercent) or CONFIG.SLOW_PERCENT
	local slowDuration = (stats and stats.SlowDuration) or CONFIG.SLOW_DURATION
	local isCatapult = (stats and stats.IsCatapult) or false
	local hasSplash = (stats and stats.HasSplash) or false
	local splashRadius = (stats and stats.SplashRadius) or 0
	local piercesShields = (stats and stats.PiercesShields) or false
	local canStun = (stats and stats.CanStun) or false
	local stunChance = (stats and stats.StunChance) or 0
	local stunDuration = (stats and stats.StunDuration) or 0
	local range = (stats and stats.Range) or 0 -- Short-range plants only (PuffShroom, FumeShroom)
	local canHitFlying = (stats and stats.CanHitFlying) or false

	-- Projectile spawn offset (data-driven with defaults)
	local spawnOffset = (stats and stats.ProjectileSpawnOffset) or nil
	local offsetX = if spawnOffset then spawnOffset.X else CONFIG.SPAWN_OFFSET_X
	local offsetY = if spawnOffset then spawnOffset.Y else CONFIG.SPAWN_OFFSET_Y

	local speed = if isCatapult then CONFIG.CATAPULT_SPEED else CONFIG.SPEED

	-- Calculate actual projectile direction (using forward direction from MapConfig)
	local actualDirX = forwardDirX * dir
	local actualDirZ = forwardDirZ * dir

	local entityId = EntityPool.Spawn(
		Components.PositionComponent({
			X = startX + (offsetX * actualDirX), -- Offset in shooting direction
			Y = offsetY, -- Height from config
			Z = z + (offsetX * actualDirZ), -- Also offset Z if needed
		}),
		Components.ProjectileComponent({
			Damage = damage,
			Speed = speed, -- Always positive, direction is in DirectionX/Z
			DirectionX = actualDirX,
			DirectionZ = actualDirZ,
			SourceEntity = plantId,
			Lane = lane,
			SpawnX = startX,
			IsFrozen = isFrozen,
			SlowPercent = if isFrozen then slowPercent else nil,
			SlowDuration = if isFrozen then slowDuration else nil,
			IsCatapult = isCatapult,
			PiercesShields = piercesShields,
			CanStun = canStun,
			StunChance = stunChance,
			StunDuration = stunDuration,
			MaxRange = if range > 0 then range else CONFIG.MAX_RANGE,
			CanHitFlying = canHitFlying,
		})
	)

	if not entityId then
		return nil
	end

	-- Add splash component if needed
	if hasSplash and splashRadius > 0 then
		world:insert(
			entityId,
			Components.SplashComponent({
				SplashRadius = splashRadius,
				SplashDamage = math.floor(damage * 0.5), -- Splash does 50% damage
			})
		)
	end

	-- Determine projectile variant for client VFX (DATA-DRIVEN)
	local plantStats = PlantData.GetStatsRaw(plantType)
	local variant: string = (plantStats and plantStats.ProjectileVariant) or "Pea"

	-- Handle special cases
	if isFrozen and variant == "Pea" then
		variant = "FrozenPea"
	elseif plantStats and plantStats.IsCatapult and plantStats.StunProjectileVariant and canStun then
		-- KernelPult throws Butter when stun procs
		variant = plantStats.StunProjectileVariant :: string
	end

	-- Broadcast to clients
	Network.ProjectileSpawned.FireAll({
		EntityId = entityId,
		Lane = lane :: any,
		StartX = startX + (2 * dir),
		TargetEntityId = nil, -- Non-homing
		Variant = variant :: any,
		IsFrozen = isFrozen,
		IsEnhanced = false, -- Will be set by EnhancementSystem if passes through Torchwood
	})

	return entityId
end

-- Fire all lanes for Threepeater (center + adjacent lanes)
local function fireThreeLanes(world: any, plantId: number, centerLane: number, startX: number, plantType: string)
	-- Fire center lane
	spawnProjectile(world, plantId, centerLane, startX, plantType, 1)

	-- Fire upper lane (if exists)
	if centerLane > 1 then
		spawnProjectile(world, plantId, centerLane - 1, startX, plantType, 1)
	end

	-- Fire lower lane (if exists)
	if centerLane < GridConfig.GRID_LANES then
		spawnProjectile(world, plantId, centerLane + 1, startX, plantType, 1)
	end
end

-- Fire in multiple directions for Starfruit
local function fireMultiDirection(world: any, plantId: number, lane: number, startX: number, plantType: string)
	-- STARFRUIT: 5 directions on a GRID
	-- Forward (→), Up (⬆), Down (⬇), BackUp (↖), BackDown (↙)

	local stats = PlantData[plantType]
	local damage = (stats and stats.Damage) or CONFIG.DAMAGE
	local spawnOffset = (stats and stats.ProjectileSpawnOffset) or nil
	local offsetX = if spawnOffset then spawnOffset.X else CONFIG.SPAWN_OFFSET_X
	local offsetY = if spawnOffset then spawnOffset.Y else CONFIG.SPAWN_OFFSET_Y

	-- Zombie direction (they go toward -X typically)
	local zombieDir = State.CachedZombieDir
	local forwardSign = if zombieDir.X < 0 then 1 else -1 -- Toward zombies

	-- Adjacent lanes
	local laneUp = lane - 1
	local laneDown = lane + 1

	-- Check which directions have zombies
	-- Forward: zombies ahead in same lane
	local hasForward = hasZombiesInLane(world, lane, startX, 0, false)

	-- Up/Down: zombies in adjacent lane but ONLY if on the grid
	local hasUp = GridDetection.HasZombiesOnGrid(laneUp)
	local hasDown = GridDetection.HasZombiesOnGrid(laneDown)

	-- BackUp/BackDown: zombies behind in adjacent lanes AND on the grid
	local hasBackUp = GridDetection.HasZombiesBehindOnGrid(laneUp, startX)
	local hasBackDown = GridDetection.HasZombiesBehindOnGrid(laneDown, startX)

	-- Spawn position
	local laneCenter = MapConfig.GridToWorld(1, lane)
	local plantZ = laneCenter.Z
	local _laneSpacing = MapConfig.GetCellSize()

	-- 5 directions with parameters
	-- dx = X direction (1 = toward zombies, -1 = toward base)
	-- targetLane = which lane the projectile travels through
	local directions = {
		{ fire = hasForward, dx = forwardSign, dz = 0, targetLane = lane, name = "Forward" },
		{ fire = hasUp, dx = 0, dz = -1, targetLane = laneUp, name = "Up" },
		{ fire = hasDown, dx = 0, dz = 1, targetLane = laneDown, name = "Down" },
		{ fire = hasBackUp, dx = -forwardSign, dz = -1, targetLane = laneUp, name = "BackUp" },
		{ fire = hasBackDown, dx = -forwardSign, dz = 1, targetLane = laneDown, name = "BackDown" },
	}

	for _, dir in directions do
		if not dir.fire then
			continue
		end

		-- Normalize diagonals
		local mag = math.sqrt(dir.dx * dir.dx + dir.dz * dir.dz)
		local normDx = if mag > 0 then dir.dx / mag else dir.dx
		local normDz = if mag > 0 then dir.dz / mag else dir.dz

		local entityId = EntityPool.Spawn(
			Components.PositionComponent({
				X = startX,
				Y = offsetY,
				Z = plantZ,
			}),
			Components.ProjectileComponent({
				Damage = damage,
				Speed = CONFIG.SPEED,
				SourceEntity = plantId,
				Lane = dir.targetLane,
				SpawnX = startX,
				SpawnZ = plantZ,
				DirectionX = normDx,
				DirectionZ = normDz,
				MaxRange = CONFIG.MAX_RANGE,
			})
		)

		if not entityId then
			continue
		end

		-- Send plant's lane for visual spawn position, not target lane
		Network.ProjectileSpawned.FireAll({
			EntityId = entityId,
			Lane = lane :: any, -- Plant's lane (for correct Z position)
			StartX = startX,
			TargetEntityId = nil,
			Variant = "Star" :: any,
			IsFrozen = false,
			IsEnhanced = false,
			DirectionX = normDx,
			DirectionZ = normDz,
		})
	end
end

--------------------------------------------------------------------------------
-- [5] ONSTEP (main loop - CANNOT yield)
--------------------------------------------------------------------------------
local function OnStep(world)
	local currentTime = os.clock()

	-- EVENT-DRIVEN CLEANUP: Clean up state for dead plants before main logic
	-- This runs BEFORE shooting logic to prevent errors from stale state
	for _, deathEvent in world:query(Components.DeathEvent) do
		if deathEvent.EntityType == "Plant" then
			local plantId = deathEvent.Target
			State.PlantFireTimes[plantId] = nil
			State.PendingMultiShots[plantId] = nil
		end
	end

	-- Process pending multi-shots (Repeater, GatlingPea, etc.)
	for plantId, shotData in State.PendingMultiShots do
		if currentTime >= shotData.nextShotTime then
			if world:contains(plantId) and canPlantShoot(world, plantId) then
				spawnProjectile(world, plantId, shotData.lane, shotData.startX, shotData.plantType, shotData.direction)
			end

			shotData.shotsRemaining -= 1
			if shotData.shotsRemaining <= 0 then
				State.PendingMultiShots[plantId] = nil
			else
				local stats = PlantData[shotData.plantType]
				local shotDelay = (stats and stats.ShotDelay) or CONFIG.SHOT_DELAY
				shotData.nextShotTime = currentTime + shotDelay
			end
		end
	end

	-- Process plants that can shoot
	for plantId, pos, plant in world:query(Components.PositionComponent, Components.PlantTypeComponent) do
		-- Get plant stats and check if this plant type can shoot
		local plantType = plant.PlantType
		local stats = PlantData[plantType]

		if not stats or not stats.CanShoot then
			continue
		end

		-- Check if plant can currently shoot
		if not canPlantShoot(world, plantId) then
			continue
		end

		-- Check fire cooldown (use AttackSpeed from PlantData if available)
		local fireInterval = if stats.AttackSpeed > 0 then (1 / stats.AttackSpeed) else CONFIG.FIRE_INTERVAL
		local lastFire = State.PlantFireTimes[plantId] or 0
		if currentTime - lastFire < fireInterval then
			continue
		end

		-- Check if zombies in lane (or any lane for multi-direction)
		local hasTargets = false
		if stats.ShootsMultiDirection then
			-- Starfruit: will check directions in fireMultiDirection
			-- Just need at least one zombie anywhere to attempt firing (O(1) check)
			hasTargets = LaneCache.GetTotalCount() > 0
		elseif stats.IsThreeLane then
			-- Threepeater checks 3 lanes (O(1) per lane with GridDetection)
			local minLane = math.max(1, plant.Lane - 1)
			local maxLane = math.min(GridConfig.GRID_LANES, plant.Lane + 1)
			for checkLane = minLane, maxLane do
				if GridDetection.HasZombiesOnGrid(checkLane) or hasZombiesInLane(world, checkLane, pos.X, pos.Z, false) then
					hasTargets = true
					break
				end
			end
		else
			-- Normal: check forward
			hasTargets = hasZombiesInLane(world, plant.Lane, pos.X, pos.Z, false)
			-- SplitPea: also check behind
			if stats.ShootsBehind and not hasTargets then
				hasTargets = hasZombiesInLane(world, plant.Lane, pos.X, pos.Z, true)
			end
		end

		if not hasTargets then
			continue
		end

		-- Range check for short-range mushrooms
		if stats.Range and stats.Range > 0 then
			local hasInRange = false
			local zombieDir = State.CachedZombieDir

			-- O(1) lane lookup instead of O(N) world:query
			local zombiesInLane = LaneCache.GetEntitiesInLane(plant.Lane)

			for _, zombieId in zombiesInLane do
				local zombiePos = LaneCache.GetPosition(zombieId)
				if not zombiePos then
					continue
				end

				-- Calculate distance in the direction zombies come from
				local dx = zombiePos.X - pos.X
				local dz = zombiePos.Z - pos.Z
				-- Dot product with zombie direction (negative = in front of plant)
				local dotProduct = dx * zombieDir.X + dz * zombieDir.Z
				local distance = -dotProduct -- Distance in the "forward" direction

				if distance > 0 and distance <= stats.Range then
					hasInRange = true
					break
				end
			end
			if not hasInRange then
				continue
			end
		end

		State.PlantFireTimes[plantId] = currentTime

		-- Fire based on plant type behavior
		if stats.ShootsMultiDirection then
			-- Starfruit: 5 directions
			fireMultiDirection(world, plantId, plant.Lane, pos.X, plantType)
		elseif stats.IsThreeLane then
			-- Threepeater: 3 lanes
			fireThreeLanes(world, plantId, plant.Lane, pos.X, plantType)
		else
			-- Normal forward shot
			spawnProjectile(world, plantId, plant.Lane, pos.X, plantType, 1)

			-- SplitPea: also fire backward
			if stats.ShootsBehind then
				spawnProjectile(world, plantId, plant.Lane, pos.X, plantType, -1)
				-- SplitPea fires 2 peas backward
				State.PendingMultiShots[plantId] = {
					shotsRemaining = 1,
					nextShotTime = currentTime + (stats.ShotDelay or CONFIG.SHOT_DELAY),
					lane = plant.Lane,
					startX = pos.X,
					plantType = plantType,
					direction = -1,
				}
			end

			-- Multi-shot plants (Repeater fires 2, GatlingPea fires 4)
			if stats.IsRepeater then
				local totalShots = (stats.ShotsPerBurst or 2) - 1 -- -1 because we already fired one
				if totalShots > 0 then
					State.PendingMultiShots[plantId] = {
						shotsRemaining = totalShots,
						nextShotTime = currentTime + (stats.ShotDelay or CONFIG.SHOT_DELAY),
						lane = plant.Lane,
						startX = pos.X,
						plantType = plantType,
						direction = 1,
					}
				end
			end
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
	State.CachedZombieDir = MapConfig.GetZombieDirection()

	State.IsInitialized = true
end

local function Dispose()
	State.IsInitialized = false
	State.CachedZombieDir = Vector3.zero
	table.clear(State.PlantFireTimes)
	table.clear(State.PendingMultiShots)
end

--------------------------------------------------------------------------------
-- [7] EXPORT
--------------------------------------------------------------------------------
return {
	priority = 160,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
