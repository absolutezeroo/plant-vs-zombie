--!strict
--[[
	SpecialPlantSystem.luau - Server-side special plant abilities
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 175 (Simulation phase - after projectiles, before combat)
	
	Handles:
	- CherryBomb/DoomShroom explosion (immediate area damage)
	- PotatoMine arming and detonation
	- Jalapeno lane-wide fire
	- IceShroom global freeze
	- Chomper instant-kill + chewing
	- Squash jump-and-squash
	- Explode-o-nut death explosion
	
	LIFECYCLE:
	- Init(): No init needed
	- OnStep(): Main loop (CANNOT yield) - processes special plants
	- Dispose(): Clear tracking state
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)
local LaneCache = require(Shared.utils.LaneCache)
local EntityPool = require(Shared.utils.EntityPool)
local ECSUtils = require(Shared.utils.ECSUtils)
local NetworkUtils = require(Shared.utils.NetworkUtils)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent
local GridService = require(Server.services.GridService)

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 175,

	-- Explosion defaults
	FUSE_TIME = 0.5,
	EXPLOSION_RADIUS = 9,

	-- Armed plant defaults
	ARM_DURATION = 15,
	TRIGGER_RADIUS = 2,

	-- Chomper defaults
	CHEW_DURATION = 42,
	CHOMP_RANGE = 6,

	-- Squash defaults
	JUMP_DURATION = 0.5,
	SQUASH_RANGE = 6,

	-- Freeze defaults
	FREEZE_DURATION = 4,

	-- CobCannon defaults
	COB_COOLDOWN = 30, -- Seconds between shots
	COB_FLIGHT_TIME = 1.5, -- Time for corn cob to reach target
})

-- ============================================================
-- SECTION 3: STATE (all mutable data)
-- ============================================================
local State = {
	-- Track plants with fuse timers
	FusePlants = {} :: { [number]: { explodeTime: number, plantType: string } },
	-- Track Squash jumping state
	SquashJumps = {} :: { [number]: { targetX: number, targetZ: number, startTime: number, startX: number, startZ: number } },
	-- Track CobCannon cooldowns
	CobCooldowns = {} :: { [number]: number }, -- entityId -> nextFireTime
	-- Track pending CobCannon explosions
	PendingCobExplosions = {} :: { [number]: { impactTime: number, targetX: number, targetZ: number, damage: number, splashRadius: number } },
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

-- Handle explosion for various plant types
local function handleExplosion(world: any, entityId: number, pos: any, plantType: string)
	local stats = PlantData[plantType]
	if not stats then
		return
	end

	local killCount = 0
	local currentTime = os.clock()

	if stats.FreezesAll then
		-- IceShroom: Freeze ALL zombies on screen (using LaneCache for O(1) iteration)
		local freezeDuration = stats.FreezeDuration or CONFIG.FREEZE_DURATION
		local allZombies = LaneCache.GetAllZombies()
		
		for _, zombieId in allZombies do
			if not world:contains(zombieId) then
				continue
			end
			
			-- Apply freeze (slow to 0%)
			world:insert(
				zombieId,
				Components.SlowComponent({
					SlowPercent = 1.0,
					Duration = freezeDuration,
					AppliedAt = currentTime,
				})
			)

			-- Stop movement
			world:insert(
				zombieId,
				Components.MovementComponent({
					VelocityX = 0,
					VelocityY = 0,
					VelocityZ = 0,
				})
			)

			-- Small damage
			ECSUtils.DamageEntity(world, zombieId, stats.Damage or 20, Components)
			killCount += 1
		end
		Logger.Info("SpecialPlant", `IceShroom {entityId} froze {killCount} zombies for {freezeDuration}s`)
	elseif stats.IsLaneWide then
		-- Jalapeno: Destroy entire lane
		local plant = world:get(entityId, Components.PlantTypeComponent)
		if plant then
			local zombiesInLane = LaneCache.GetEntitiesInLane(plant.Lane)

			for _, zombieId in zombiesInLane do
				if not world:contains(zombieId) then
					continue
				end

				if ECSUtils.KillEntity(world, zombieId, Components) then
					killCount += 1
				end
			end
		end
		Logger.Info("SpecialPlant", `Jalapeno {entityId} burned lane, killed {killCount} zombies`)

		-- Fire VFX for entire lane
		Network.ExplosionVFX.FireAll({
			PositionX = pos.X,
			PositionY = 1,
			PositionZ = pos.Z,
			Radius = GridConfig.GRID_COLUMNS * GridConfig.CELL_SIZE,
		})
	else
		-- Normal explosion (CherryBomb, DoomShroom)
		-- OPTIMIZED: Uses LaneCache for O(lane_range) instead of O(all_zombies)
		local explosionRadius = (stats.Range and stats.Range > 0) and stats.Range or CONFIG.EXPLOSION_RADIUS

		-- Get plant lane for optimized lookup
		local plantComp = world:get(entityId, Components.PlantTypeComponent)
		local centerLane = if plantComp then plantComp.Lane else 3
		local laneRadius = math.ceil(explosionRadius / GridConfig.CELL_SIZE)

		-- O(lane_range) lookup instead of O(N) world:query
		local zombiesInRange = LaneCache.GetEntitiesInLaneRange(centerLane, laneRadius)

		for _, zombieId in zombiesInRange do
			local zombiePos = LaneCache.GetPosition(zombieId)
			if not zombiePos then
				continue
			end

			local dx = zombiePos.X - pos.X
			local dz = zombiePos.Z - pos.Z
			local distance = math.sqrt(dx * dx + dz * dz)

			if distance <= explosionRadius then
				if ECSUtils.KillEntity(world, zombieId, Components) then
					killCount += 1
				end
			end
		end

		Logger.Info("SpecialPlant", `{plantType} {entityId} exploded! Killed {killCount} zombies`)

		-- Broadcast explosion VFX (DoomShroom uses crater VFX)
		Network.ExplosionVFX.FireAll({
			PositionX = pos.X,
			PositionY = 1,
			PositionZ = pos.Z,
			Radius = explosionRadius,
			IsCrater = stats.LeavesCrater or false,
		})
	end

	-- Handle grid cell: clear and optionally block (crater)
	local plant = world:get(entityId, Components.PlantTypeComponent)
	if plant then
		GridService.Clear(plant.Column, plant.Lane)
		
		-- DoomShroom leaves a crater that blocks planting
		if stats.LeavesCrater then
			GridService.BlockCell(plant.Column, plant.Lane)
			Logger.Info("SpecialPlant", `{plantType} left a crater at ({plant.Column}, {plant.Lane})`)
		end
	end

	-- Broadcast entity death
	NetworkUtils.BroadcastEntityDied(entityId)

	-- Release plant back to pool
	EntityPool.SafeDespawn(entityId, world)
end

-- Handle CobCannon explosion at target location
local function handleCobExplosion(world: any, explosionId: number, targetX: number, targetZ: number, damage: number, splashRadius: number)
	local killCount = 0

	-- Find zombies in splash radius across nearby lanes
	local targetLane = math.floor((targetZ / GridConfig.CELL_SIZE) + 0.5) -- Approximate lane
	targetLane = math.clamp(targetLane, 1, GridConfig.GRID_LANES)
	local laneRadius = math.ceil(splashRadius / GridConfig.CELL_SIZE)

	local zombiesInRange = LaneCache.GetEntitiesInLaneRange(targetLane, laneRadius)

	for _, zombieId in zombiesInRange do
		local zombiePos = LaneCache.GetPosition(zombieId)
		if not zombiePos then
			continue
		end

		local dx = zombiePos.X - targetX
		local dz = zombiePos.Z - targetZ
		local distance = math.sqrt(dx * dx + dz * dz)

		if distance <= splashRadius then
			-- CobCannon deals massive damage but might not instant-kill
			local _, isDead = ECSUtils.DamageEntity(world, zombieId, damage, Components)
			if isDead then
				killCount += 1
			end
		end
	end

	Logger.Info("SpecialPlant", `CobCannon explosion at ({targetX}, {targetZ}) killed {killCount} zombies`)

	-- Broadcast explosion VFX
	Network.ExplosionVFX.FireAll({
		PositionX = targetX,
		PositionY = 1,
		PositionZ = targetZ,
		Radius = splashRadius,
	})

	-- Clean up pending explosion
	State.PendingCobExplosions[explosionId] = nil
end

-- Explode PotatoMine: kill the triggering zombie
local function explodePotatoMine(world: any, mineId: number, minePos: any, triggeredByZombieId: number)
	Logger.Info("SpecialPlant", `PotatoMine {mineId} detonated by zombie {triggeredByZombieId}!`)

	-- Kill the zombie
	ECSUtils.KillEntity(world, triggeredByZombieId, Components)

	-- Clear grid cell
	local plant = world:get(mineId, Components.PlantTypeComponent)
	if plant then
		GridService.Clear(plant.Column, plant.Lane)
	end

	-- Broadcast explosion VFX
	Network.ExplosionVFX.FireAll({
		PositionX = minePos.X,
		PositionY = 1,
		PositionZ = minePos.Z,
		Radius = 6,
	})

	-- Broadcast entity death
	NetworkUtils.BroadcastEntityDied(mineId)

	-- Release mine back to pool
	EntityPool.SafeDespawn(mineId, world)
end

-- Find nearest zombie in range for Chomper/Squash
local function findNearestZombieInRange(world: any, plantPos: any, lane: number, range: number): (number?, any?)
	local nearestId = nil
	local nearestPos = nil
	local nearestDist = range + 1

	local zombiesInLane = LaneCache.GetEntitiesInLane(lane)

	for _, zombieId in zombiesInLane do
		if not world:contains(zombieId) then
			continue
		end

		local zombiePos = world:get(zombieId, Components.PositionComponent)
		if not zombiePos then
			continue
		end

		local distance = zombiePos.X - plantPos.X
		if distance > 0 and distance <= range and distance < nearestDist then
			nearestId = zombieId
			nearestPos = zombiePos
			nearestDist = distance
		end
	end

	return nearestId, nearestPos
end

-- ============================================================
-- SECTION 5: ONSTEP (main ECS loop)
-- ============================================================
local function OnStep(world)
	local currentTime = os.clock()

	-- Process pending CobCannon explosions
	for explosionId, explosion in State.PendingCobExplosions do
		if currentTime >= explosion.impactTime then
			handleCobExplosion(
				world,
				explosionId,
				explosion.targetX,
				explosion.targetZ,
				explosion.damage,
				explosion.splashRadius
			)
		end
	end

	-- Clean up CobCannon cooldowns for despawned entities
	for entityId in State.CobCooldowns do
		if not world:contains(entityId) then
			State.CobCooldowns[entityId] = nil
		end
	end

	-- React to SpawnEvent for new special plants
	for _, event in world:query(Components.SpawnEvent) do
		if event.EntityType ~= "Plant" then
			continue
		end

		local entityId = event.Target
		if not world:contains(entityId) then
			continue
		end

		local plant = world:get(entityId, Components.PlantTypeComponent)
		if not plant then
			continue
		end

		local stats = PlantData[plant.PlantType]
		if not stats then
			continue
		end

		-- Initialize special plant behaviors
		if stats.ExplodesOnPlace then
			local fuseTime = stats.FuseTime or CONFIG.FUSE_TIME
			State.FusePlants[entityId] = {
				explodeTime = currentTime + fuseTime,
				plantType = plant.PlantType,
			}
			Logger.Debug("SpecialPlant", `{plant.PlantType} {entityId} fuse started ({fuseTime}s)`)
		elseif stats.IsInstant and stats.RemovesFlying then
			-- Blover: Instantly kill all flying zombies
			local killCount = 0
			local allZombies = LaneCache.GetAllZombies()
			local ZombieData = require(Shared.data.ZombieData)
			
			for _, zombieId in allZombies do
				if not world:contains(zombieId) then
					continue
				end
				
				local zombie = world:get(zombieId, Components.ZombieTypeComponent)
				if not zombie then
					continue
				end
				
				local zombieStats = ZombieData[zombie.ZombieType]
				if zombieStats and zombieStats.IsFlying then
					if ECSUtils.KillEntity(world, zombieId, Components) then
						killCount += 1
					end
				end
			end
			
			Logger.Info("SpecialPlant", `Blover {entityId} blew away {killCount} flying zombies!`)
			
			-- Blover disappears after use
			GridService.Clear(plant.Column, plant.Lane)
			NetworkUtils.BroadcastEntityDied(entityId)
			EntityPool.SafeDespawn(entityId, world)
		elseif stats.NeedsArming then
			local armDuration = stats.ArmDuration or CONFIG.ARM_DURATION
			world:insert(
				entityId,
				Components.ArmedComponent({
					IsArmed = false,
					ArmTime = currentTime,
					ArmDuration = armDuration,
				})
			)
			Logger.Debug("SpecialPlant", `{plant.PlantType} {entityId} placed, arming in {armDuration}s`)
		end
	end

	-- Process fuse plants (CherryBomb, DoomShroom, IceShroom, Jalapeno)
	for entityId, fuseData in State.FusePlants do
		if currentTime >= fuseData.explodeTime then
			if world:contains(entityId) then
				local pos = world:get(entityId, Components.PositionComponent)
				if pos then
					handleExplosion(world, entityId, pos, fuseData.plantType)
				end
			end
			State.FusePlants[entityId] = nil
		end
	end

	-- Process armed plants (PotatoMine) triggering
	for mineId, pos, plant, armed in
		world:query(Components.PositionComponent, Components.PlantTypeComponent, Components.ArmedComponent)
	do
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.NeedsArming then
			continue
		end

		-- Check if still arming
		if not armed.IsArmed then
			if currentTime - armed.ArmTime >= armed.ArmDuration then
				-- Now armed!
				world:insert(
					mineId,
					Components.ArmedComponent({
						IsArmed = true,
						ArmTime = armed.ArmTime,
						ArmDuration = armed.ArmDuration,
					})
				)
				Logger.Debug("SpecialPlant", `{plant.PlantType} {mineId} is now armed!`)
			end
			continue
		end

		-- Armed mine - check for zombie contact
		local triggerRadius = stats.TriggerRadius or CONFIG.TRIGGER_RADIUS
		local zombiesInLane = LaneCache.GetEntitiesInLane(plant.Lane)

		for _, zombieId in zombiesInLane do
			if not world:contains(zombieId) then
				continue
			end

			local zombiePos = world:get(zombieId, Components.PositionComponent)
			if not zombiePos then
				continue
			end

			local distance = math.abs(zombiePos.X - pos.X)
			if distance <= triggerRadius then
				explodePotatoMine(world, mineId, pos, zombieId)
				break
			end
		end
	end

	-- Process Chomper chewing completion
	for plantId, pos, plant, chewing in
		world:query(Components.PositionComponent, Components.PlantTypeComponent, Components.ChewingComponent)
	do
		if currentTime - chewing.ChewStartTime >= chewing.ChewDuration then
			world:remove(plantId, Components.ChewingComponent)
			Logger.Debug("SpecialPlant", `Chomper {plantId} finished chewing`)
		end
	end

	-- Process Chomper looking for targets (when not chewing)
	for plantId, pos, plant in world:query(Components.PositionComponent, Components.PlantTypeComponent) do
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.IsInstantKill then
			continue
		end
		if stats.JumpsToTarget then
			continue
		end -- Squash handled separately

		-- Skip if already chewing
		if world:get(plantId, Components.ChewingComponent) then
			continue
		end

		local chompRange = stats.Range or CONFIG.CHOMP_RANGE
		local zombieId, zombiePos = findNearestZombieInRange(world, pos, plant.Lane, chompRange)

		if zombieId then
			-- Chomp! Instant kill
			ECSUtils.KillEntity(world, zombieId, Components)

			-- Start chewing
			local chewDuration = stats.ChewDuration or CONFIG.CHEW_DURATION
			world:insert(
				plantId,
				Components.ChewingComponent({
					ChewDuration = chewDuration,
					ChewStartTime = currentTime,
				})
			)

			Logger.Info("SpecialPlant", `Chomper {plantId} ate zombie {zombieId}, chewing for {chewDuration}s`)

			NetworkUtils.BroadcastEntityDied(zombieId)
		end
	end

	-- Process Squash jumping
	for plantId, jumpData in State.SquashJumps do
		if not world:contains(plantId) then
			State.SquashJumps[plantId] = nil
			continue
		end

		local jumpProgress = (currentTime - jumpData.startTime) / CONFIG.JUMP_DURATION

		if jumpProgress >= 1 then
			-- Landed! Kill zombie at target location
			local plant = world:get(plantId, Components.PlantTypeComponent)
			if plant then
				local zombiesInLane = LaneCache.GetEntitiesInLane(plant.Lane)

				for _, zombieId in zombiesInLane do
					if not world:contains(zombieId) then
						continue
					end

					local zombiePos = world:get(zombieId, Components.PositionComponent)
					if not zombiePos then
						continue
					end

					local dx = math.abs(zombiePos.X - jumpData.targetX)
					local dz = math.abs(zombiePos.Z - jumpData.targetZ)
					if dx < 3 and dz < 3 then
						if ECSUtils.KillEntity(world, zombieId, Components) then
							Logger.Info("SpecialPlant", `Squash {plantId} squashed zombie {zombieId}`)
							NetworkUtils.BroadcastEntityDied(zombieId)
							end
						break
					end
				end

				-- Squash dies after landing
				GridService.Clear(plant.Column, plant.Lane)
				NetworkUtils.BroadcastEntityDied(plantId)
				EntityPool.SafeDespawn(plantId, world)
			end
			State.SquashJumps[plantId] = nil
		else
			-- Update position during jump (arc motion)
			local arcHeight = math.sin(jumpProgress * math.pi) * 5
			local newX = jumpData.startX + (jumpData.targetX - jumpData.startX) * jumpProgress
			local newZ = jumpData.startZ + (jumpData.targetZ - jumpData.startZ) * jumpProgress

			world:insert(
				plantId,
				Components.PositionComponent({
					X = newX,
					Y = 2.5 + arcHeight,
					Z = newZ,
				})
			)
		end
	end

	-- Process Squash looking for targets
	for plantId, pos, plant in world:query(Components.PositionComponent, Components.PlantTypeComponent) do
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.JumpsToTarget then
			continue
		end

		-- Skip if already jumping
		if State.SquashJumps[plantId] then
			continue
		end

		local squashRange = stats.Range or CONFIG.SQUASH_RANGE
		local zombieId, zombiePos = findNearestZombieInRange(world, pos, plant.Lane, squashRange)

		if zombieId and zombiePos then
			State.SquashJumps[plantId] = {
				targetX = zombiePos.X,
				targetZ = zombiePos.Z,
				startTime = currentTime,
				startX = pos.X,
				startZ = pos.Z,
			}
			Logger.Debug("SpecialPlant", `Squash {plantId} jumping to zombie {zombieId}`)
		end
	end

	-- Cleanup tracking for despawned entities
	for entityId in State.FusePlants do
		if not world:contains(entityId) then
			State.FusePlants[entityId] = nil
		end
	end
end

-- ============================================================
-- SECTION 6: INIT / DISPOSE
-- ============================================================

-- Store world reference for network handlers
local _world: any = nil

local function Init(world)
	_world = world
	
	-- Listen for CobCannon fire requests
	Network.CobCannonFireRequest.SetCallback(function(player: Player, data)
		local plantId = data.PlantEntityId
		local targetLane = data.TargetLane
		local targetColumn = data.TargetColumn

		-- Validate plant exists and is a CobCannon
		if not _world:contains(plantId) then
			Logger.Warn("SpecialPlant", `CobCannon fire failed: plant {plantId} not found`)
			return
		end

		local plant = _world:get(plantId, Components.PlantTypeComponent)
		if not plant or plant.PlantType ~= "CobCannon" then
			Logger.Warn("SpecialPlant", `CobCannon fire failed: entity {plantId} is not a CobCannon`)
			return
		end

		-- Check cooldown
		local currentTime = os.clock()
		local nextFireTime = State.CobCooldowns[plantId] or 0
		if currentTime < nextFireTime then
			Logger.Debug("SpecialPlant", `CobCannon {plantId} on cooldown, {nextFireTime - currentTime}s remaining`)
			return
		end

		-- Get target world position
		local targetPos = MapConfig.GridToWorld(targetColumn, targetLane)
		local targetX = targetPos.X
		local targetZ = targetPos.Z

		-- Get stats
		local stats = PlantData.CobCannon
		local damage = stats.Damage or 1800
		local splashRadius = stats.SplashRadius or 9
		local cooldown = stats.Cooldown or CONFIG.COB_COOLDOWN
		local flightTime = CONFIG.COB_FLIGHT_TIME

		-- Set cooldown
		State.CobCooldowns[plantId] = currentTime + cooldown

		-- Schedule explosion
		local explosionId = plantId * 1000 + currentTime -- Unique ID
		State.PendingCobExplosions[explosionId] = {
			impactTime = currentTime + flightTime,
			targetX = targetX,
			targetZ = targetZ,
			damage = damage,
			splashRadius = splashRadius,
		}

		-- Broadcast to clients for VFX
		Network.CobCannonFired.FireAll({
			PlantEntityId = plantId,
			TargetX = targetX,
			TargetZ = targetZ,
			ImpactTime = flightTime,
		})

		Logger.Info("SpecialPlant", `Player {player.Name} fired CobCannon {plantId} at ({targetColumn}, {targetLane})`)
	end)
	
	Logger.Debug("SpecialPlantSystem", "Initialized")
end

local function Dispose()
	table.clear(State.FusePlants)
	table.clear(State.SquashJumps)
	table.clear(State.CobCooldowns)
	table.clear(State.PendingCobExplosions)
	_world = nil
	Logger.Debug("SpecialPlantSystem", "Disposed")
end

-- ============================================================
-- SECTION 7: MODULE EXPORT
-- ============================================================
return {
	priority = CONFIG.PRIORITY,
	system = OnStep,
	Init = Init,
	Dispose = Dispose,
}
