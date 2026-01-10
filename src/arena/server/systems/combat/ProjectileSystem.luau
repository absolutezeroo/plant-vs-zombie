--!strict
--[[
	ProjectileSystem.luau - Server-side projectile spawning and movement
	
	Priority: 160 (Simulation phase - after zombie movement)
	
	Handles:
	- Peashooters firing peas at zombies in their lane
	- Multi-shot plants (Repeater, GatlingPea)
	- Three-lane plants (Threepeater)
	- Backwards shooters (SplitPea)
	- Multi-direction plants (Starfruit)
	- Catapult plants (lobbing projectiles)
	- Projectile movement
	- Short-range mushrooms (PuffShroom, SeaShroom, FumeShroom)
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - manages projectiles
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
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)
local LaneCache = require(Shared.utils.LaneCache)

-- Network
local Network = require(Shared.network.generated.server)

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local PlantTypeComponent = Components.PlantTypeComponent
local ProjectileComponent = Components.ProjectileComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local SplashComponent = Components.SplashComponent
local SleepingComponent = Components.SleepingComponent
local HidingComponent = Components.HidingComponent
local ChewingComponent = Components.ChewingComponent

-- Projectile config defaults (used when PlantData doesn't specify)
local ProjectileDefaults = {
	SPEED = 15,              -- Studs per second (global)
	FIRE_INTERVAL = 0.67,    -- Seconds between shots (1.5 attacks/sec)
	MAX_RANGE = 100,         -- Max distance before despawn (global)
	DAMAGE = 20,             -- Base pea damage
	SLOW_PERCENT = 0.5,      -- Default slow (50%)
	SLOW_DURATION = 3,       -- Default slow duration
	SHOT_DELAY = 0.1,        -- Default delay for multi-shot plants
	CATAPULT_SPEED = 10,     -- Slower for arcing projectiles
	SPAWN_OFFSET_X = 2,      -- Default X offset from plant center
	SPAWN_OFFSET_Y = 2.5,    -- Default Y (height) of projectile spawn
}

-- Track last fire time per plant
local _plantFireTimes: {[number]: number} = {}
-- Track pending multi-shot plants: { plantId -> { shotsRemaining, nextShotTime, lane, startX, plantType } }
local _pendingMultiShots: {[number]: {shotsRemaining: number, nextShotTime: number, lane: number, startX: number, plantType: string, direction: number}} = {}

-- Check if there are zombies in the lane (optionally behind plant for SplitPea)
-- Uses LaneCache for O(1) lane lookup + O(lane_size) direction check
-- Uses MapConfig.GetZombieDirection() to determine "in front" vs "behind"
local function hasZombiesInLane(_world: any, lane: number, plantX: number, plantZ: number, checkBehind: boolean?): boolean
	local zombieDir = MapConfig.GetZombieDirection()
	-- Convert Vector3 to table format expected by LaneCache
	return LaneCache.HasZombiesInDirection(lane, plantX, plantZ, {X = zombieDir.X, Z = zombieDir.Z}, checkBehind)
end

-- Check if plant can shoot (not sleeping, not hiding, not chewing)
local function canPlantShoot(world: any, plantId: number): boolean
	-- Check if sleeping (mushrooms during day)
	local sleeping = world:get(plantId, SleepingComponent)
	if sleeping and sleeping.IsSleeping then
		return false
	end
	
	-- Check if hiding (ScaredyShroom)
	local hiding = world:get(plantId, HidingComponent)
	if hiding and hiding.IsHiding then
		return false
	end
	
	-- Check if chewing (Chomper)
	local chewing = world:get(plantId, ChewingComponent)
	if chewing then
		return false
	end
	
	return true
end

-- Spawn a projectile (data-driven from PlantData)
local function spawnProjectile(world: any, plantId: number, lane: number, startX: number, plantType: string, direction: number?)
	-- Get the direction plants should shoot (opposite of zombie direction)
	local zombieDir = MapConfig.GetZombieDirection()
	-- Plants shoot in the opposite direction (toward zombie spawns)
	local forwardDirX = -zombieDir.X
	local forwardDirZ = -zombieDir.Z
	
	local dir = direction or 1 -- 1 = forward (toward zombies), -1 = backward (toward base)
	local laneCenter = MapConfig.GridToWorld(1, lane)
	local z = laneCenter.Z
	
	-- Read stats from PlantData (data-driven)
	local stats = PlantData[plantType]
	local damage = (stats and stats.Damage) or ProjectileDefaults.DAMAGE
	local isFrozen = (stats and stats.IsFrozen) or false
	local slowPercent = (stats and stats.SlowPercent) or ProjectileDefaults.SLOW_PERCENT
	local slowDuration = (stats and stats.SlowDuration) or ProjectileDefaults.SLOW_DURATION
	local isCatapult = (stats and stats.IsCatapult) or false
	local hasSplash = (stats and stats.HasSplash) or false
	local splashRadius = (stats and stats.SplashRadius) or 0
	local piercesShields = (stats and stats.PiercesShields) or false
	local canStun = (stats and stats.CanStun) or false
	local stunChance = (stats and stats.StunChance) or 0
	local stunDuration = (stats and stats.StunDuration) or 0
	local range = (stats and stats.Range) or 0 -- 0 = unlimited
	local canHitFlying = (stats and stats.CanHitFlying) or false
	
	-- Projectile spawn offset (data-driven with defaults)
	local spawnOffset = (stats and stats.ProjectileSpawnOffset) or nil
	local offsetX = if spawnOffset then spawnOffset.X else ProjectileDefaults.SPAWN_OFFSET_X
	local offsetY = if spawnOffset then spawnOffset.Y else ProjectileDefaults.SPAWN_OFFSET_Y
	
	local speed = if isCatapult then ProjectileDefaults.CATAPULT_SPEED else ProjectileDefaults.SPEED
	
	-- Calculate actual projectile direction (using forward direction from MapConfig)
	local actualDirX = forwardDirX * dir
	local actualDirZ = forwardDirZ * dir
	
	local entityId = world:spawn(
		PositionComponent({
			X = startX + (offsetX * actualDirX), -- Offset in shooting direction
			Y = offsetY,                         -- Height from config
			Z = z + (offsetX * actualDirZ)       -- Also offset Z if needed
		}),
		ProjectileComponent({
			Damage = damage,
			Speed = speed,  -- Always positive, direction is in DirectionX/Z
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
			MaxRange = if range > 0 then range else ProjectileDefaults.MAX_RANGE,
			CanHitFlying = canHitFlying,
		})
	)
	
	-- Add splash component if needed
	if hasSplash and splashRadius > 0 then
		world:insert(entityId, SplashComponent({
			SplashRadius = splashRadius,
			SplashDamage = math.floor(damage * 0.5), -- Splash does 50% damage
		}))
	end
	
	-- Determine projectile variant for client VFX
	local variant = "Pea"
	if isFrozen then
		variant = "FrozenPea"
	elseif isCatapult then
		if plantType == "CabbagePult" then
			variant = "Cabbage"
		elseif plantType == "KernelPult" then
			variant = if canStun then "Butter" else "Kernel"
		elseif plantType == "MelonPult" or plantType == "WinterMelon" then
			variant = "Melon"
		end
	elseif plantType:find("Shroom") then
		if plantType == "FumeShroom" or plantType == "GloomShroom" then
			variant = "Fume"
		else
			variant = "Spore"
		end
	elseif plantType == "Starfruit" then
		variant = "Star"
	elseif plantType == "Cactus" then
		variant = "Spike"
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
	
	Logger.Debug("Projectile", `Threepeater {plantId} fired in 3 lanes`)
end

-- Fire in multiple directions for Starfruit
local function fireMultiDirection(world: any, plantId: number, lane: number, startX: number, plantType: string)
	-- Starfruit fires 5 stars in relative directions
	-- "Forward" = toward zombie spawns, "Backward" = toward base
	local laneCenter = MapConfig.GridToWorld(1, lane)
	local z = laneCenter.Z
	
	local stats = PlantData[plantType]
	local damage = (stats and stats.Damage) or ProjectileDefaults.DAMAGE
	
	-- Projectile spawn offset (data-driven with defaults)
	local spawnOffset = (stats and stats.ProjectileSpawnOffset) or nil
	local offsetX = if spawnOffset then spawnOffset.X else ProjectileDefaults.SPAWN_OFFSET_X
	local offsetY = if spawnOffset then spawnOffset.Y else ProjectileDefaults.SPAWN_OFFSET_Y
	
	-- Get forward direction (opposite of zombie movement)
	local zombieDir = MapConfig.GetZombieDirection()
	local fwdX, fwdZ = -zombieDir.X, -zombieDir.Z
	-- Perpendicular direction (for "up/down" relative to forward)
	local perpX, perpZ = -fwdZ, fwdX
	
	-- 5 directions relative to forward
	local directions = {
		{dx = fwdX, dz = fwdZ},                             -- Forward
		{dx = -fwdX, dz = -fwdZ},                           -- Backward
		{dx = fwdX + perpX, dz = fwdZ + perpZ},             -- Forward-Up diagonal
		{dx = fwdX - perpX, dz = fwdZ - perpZ},             -- Forward-Down diagonal
		{dx = -fwdX + perpX, dz = -fwdZ + perpZ},           -- Backward-Up diagonal
	}
	
	for _, dir in directions do
		-- Normalize direction
		local mag = math.sqrt(dir.dx * dir.dx + dir.dz * dir.dz)
		local normDx = if mag > 0 then dir.dx / mag else dir.dx
		local normDz = if mag > 0 then dir.dz / mag else dir.dz
		
		local entityId = world:spawn(
			PositionComponent({
				X = startX + normDx * offsetX,
				Y = offsetY,
				Z = z + normDz * offsetX
			}),
			ProjectileComponent({
				Damage = damage,
				Speed = ProjectileDefaults.SPEED,
				SourceEntity = plantId,
				Lane = lane,
				SpawnX = startX,
				DirectionX = normDx,
				DirectionZ = normDz,
				MaxRange = ProjectileDefaults.MAX_RANGE,
			})
		)
		
		Network.ProjectileSpawned.FireAll({
			EntityId = entityId,
			Lane = lane :: any,
			StartX = startX + normDx * offsetX,
			TargetEntityId = nil,
			Variant = "Star" :: any,
			IsFrozen = false,
			IsEnhanced = false,
		})
	end
	
	Logger.Debug("Projectile", `Starfruit {plantId} fired 5 stars`)
end

local function ProjectileSystem(world)
	local currentTime = os.clock()
	local dt = 1/60
	
	-- Process pending multi-shots (Repeater, GatlingPea, etc.)
	for plantId, shotData in _pendingMultiShots do
		if currentTime >= shotData.nextShotTime then
			if world:contains(plantId) and canPlantShoot(world, plantId) then
				spawnProjectile(world, plantId, shotData.lane, shotData.startX, shotData.plantType, shotData.direction)
				Logger.Debug("Projectile", `{shotData.plantType} {plantId} fired shot (remaining: {shotData.shotsRemaining - 1})`)
			end
			
			shotData.shotsRemaining -= 1
			if shotData.shotsRemaining <= 0 then
				_pendingMultiShots[plantId] = nil
			else
				local stats = PlantData[shotData.plantType]
				local shotDelay = (stats and stats.ShotDelay) or ProjectileDefaults.SHOT_DELAY
				shotData.nextShotTime = currentTime + shotDelay
			end
		end
	end
	
	-- Process plants that can shoot
	for plantId, pos, plant in world:query(PositionComponent, PlantTypeComponent) do
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
		local fireInterval = if stats.AttackSpeed > 0 then (1 / stats.AttackSpeed) else ProjectileDefaults.FIRE_INTERVAL
		local lastFire = _plantFireTimes[plantId] or 0
		if currentTime - lastFire < fireInterval then
			continue
		end
		
		-- Check if zombies in lane (or any lane for multi-direction)
		local hasTargets = false
		if stats.ShootsMultiDirection then
			-- Starfruit shoots regardless of zombie position
			hasTargets = true
			for _, zombie in world:query(ZombieTypeComponent) do
				hasTargets = true
				break
			end
		elseif stats.IsThreeLane then
			-- Threepeater checks 3 lanes
			for checkLane = math.max(1, plant.Lane - 1), math.min(GridConfig.GRID_LANES, plant.Lane + 1) do
				if hasZombiesInLane(world, checkLane, pos.X, pos.Z, false) then
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
		
		-- Range check for short-range mushrooms (PuffShroom, SeaShroom, etc.)
		if stats.Range and stats.Range > 0 then
			local hasInRange = false
			local zombieDir = MapConfig.GetZombieDirection()
			
			for _, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
				if zombie.Lane == plant.Lane then
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
			end
			if not hasInRange then
				continue
			end
		end
		
		_plantFireTimes[plantId] = currentTime
		
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
				_pendingMultiShots[plantId] = {
					shotsRemaining = 1,
					nextShotTime = currentTime + (stats.ShotDelay or ProjectileDefaults.SHOT_DELAY),
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
					_pendingMultiShots[plantId] = {
						shotsRemaining = totalShots,
						nextShotTime = currentTime + (stats.ShotDelay or ProjectileDefaults.SHOT_DELAY),
						lane = plant.Lane,
						startX = pos.X,
						plantType = plantType,
						direction = 1,
					}
				end
			end
		end
		
		Logger.Debug("Projectile", `{plantType} {plantId} fired in lane {plant.Lane}`)
	end
	
	-- Move projectiles
	for projId, pos, proj in world:query(PositionComponent, ProjectileComponent) do
		-- Handle multi-directional projectiles (Starfruit)
		local dx = proj.DirectionX or 1
		local dz = proj.DirectionZ or 0
		
		local newX = pos.X + (proj.Speed * dx) * dt
		local newZ = pos.Z + (proj.Speed * dz) * dt
		
		-- Check max range
		local distanceTraveled = math.sqrt((newX - proj.SpawnX)^2 + (newZ - pos.Z)^2)
		local maxRange = proj.MaxRange or ProjectileDefaults.MAX_RANGE
		
		if distanceTraveled > maxRange then
			world:despawn(projId)
			continue
		end
		
		-- Check out of bounds (using MapConfig for dynamic grid bounds)
		local config = MapConfig.GetConfig()
		local minX = config.GridCornerA.X - 10
		local maxX = config.GridCornerB.X + 10

		if newX < minX or newX > maxX then
			world:despawn(projId)
			continue
		end
		
		-- Update position using component constructor
		world:insert(projId, PositionComponent({
			X = newX,
			Y = pos.Y,
			Z = newZ,
		}))
	end
	
	-- Clean up fire times for despawned plants
	for plantId in _plantFireTimes do
		if not world:contains(plantId) then
			_plantFireTimes[plantId] = nil
			_pendingMultiShots[plantId] = nil
		end
	end
end

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	table.clear(_plantFireTimes)
	table.clear(_pendingMultiShots)
end

return {
	_name = "ProjectileSystem",
	priority = 160,
	system = ProjectileSystem,
	Init = Init,
	Dispose = Dispose,
}
