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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

-- Network (script.Parent.Parent.Parent = server root, since we're in systems/combat/)
local Server = script.Parent.Parent.Parent
local Network = require(Server.network.generated)

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
local function hasZombiesInLane(world: any, lane: number, plantX: number, checkBehind: boolean?): boolean
	for id, pos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
		if zombie.Lane == lane then
			if checkBehind then
				if pos.X < plantX then return true end
			else
				if pos.X > plantX then return true end
			end
		end
	end
	return false
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
	local dir = direction or 1 -- 1 = forward, -1 = backward
	local z = (lane - 1) * GridConfig.CELL_SIZE + GridConfig.CELL_SIZE / 2 + GridConfig.GRID_ORIGIN_Z
	
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
	
	local entityId = world:spawn(
		PositionComponent({
			X = startX + (offsetX * dir), -- Offset from plant center (direction-aware)
			Y = offsetY,                  -- Height from config
			Z = z
		}),
		ProjectileComponent({
			Damage = damage,
			Speed = speed * dir,  -- Negative speed for backward
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
	
	-- Broadcast to clients
	Network.ProjectileSpawned.FireAll({
		EntityId = entityId,
		Lane = lane :: any,
		StartX = startX + (2 * dir),
		TargetEntityId = nil, -- Non-homing
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
	-- Starfruit fires 5 stars: up-left, up-right, right, down-right, down-left
	-- Simplified: we fire in current lane + adjacent lanes in both directions
	local z = (lane - 1) * GridConfig.CELL_SIZE + GridConfig.CELL_SIZE / 2 + GridConfig.GRID_ORIGIN_Z
	
	local stats = PlantData[plantType]
	local damage = (stats and stats.Damage) or ProjectileDefaults.DAMAGE
	
	-- Projectile spawn offset (data-driven with defaults)
	local spawnOffset = (stats and stats.ProjectileSpawnOffset) or nil
	local offsetX = if spawnOffset then spawnOffset.X else ProjectileDefaults.SPAWN_OFFSET_X
	local offsetY = if spawnOffset then spawnOffset.Y else ProjectileDefaults.SPAWN_OFFSET_Y
	
	local directions = {
		{dx = 1, dz = 0},    -- Right
		{dx = -1, dz = 0},   -- Left
		{dx = 1, dz = -1},   -- Up-Right (diagonal)
		{dx = 1, dz = 1},    -- Down-Right (diagonal)
		{dx = -1, dz = -1},  -- Up-Left (diagonal)
	}
	
	for _, dir in directions do
		local entityId = world:spawn(
			PositionComponent({
				X = startX + dir.dx * offsetX,
				Y = offsetY,
				Z = z + dir.dz * offsetX
			}),
			ProjectileComponent({
				Damage = damage,
				Speed = ProjectileDefaults.SPEED,
				SourceEntity = plantId,
				Lane = lane,
				SpawnX = startX,
				DirectionX = dir.dx,
				DirectionZ = dir.dz,
				MaxRange = ProjectileDefaults.MAX_RANGE,
			})
		)
		
		Network.ProjectileSpawned.FireAll({
			EntityId = entityId,
			Lane = lane :: any,
			StartX = startX + dir.dx * offsetX,
			TargetEntityId = nil,
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
				if hasZombiesInLane(world, checkLane, pos.X, false) then
					hasTargets = true
					break
				end
			end
		else
			-- Normal: check forward
			hasTargets = hasZombiesInLane(world, plant.Lane, pos.X, false)
			-- SplitPea: also check behind
			if stats.ShootsBehind and not hasTargets then
				hasTargets = hasZombiesInLane(world, plant.Lane, pos.X, true)
			end
		end
		
		if not hasTargets then
			continue
		end
		
		-- Range check for short-range mushrooms (PuffShroom, SeaShroom, etc.)
		if stats.Range and stats.Range > 0 then
			local hasInRange = false
			for _, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
				if zombie.Lane == plant.Lane then
					local distance = zombiePos.X - pos.X
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
		
		-- Check out of bounds
		if newX < GridConfig.GRID_ORIGIN_X - 10 or newX > GridConfig.GRID_ORIGIN_X + (GridConfig.GRID_COLUMNS + 2) * GridConfig.CELL_SIZE then
			world:despawn(projId)
			continue
		end
		
		-- Update position
		world:insert(projId, PositionComponent({
			X = newX,
			Y = pos.Y,
			Z = newZ
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

return {
	system = ProjectileSystem,
	priority = 160,
}
