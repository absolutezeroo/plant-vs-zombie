--!strict
--[[
	PlantFoodSystem.luau - Plant Food mechanics
	
	SYSTEM V3 ARCHITECTURE (Matter Hooks)
	
	Priority: 185 (After death system 180, before cleanup)
	
	Handles:
	- Processing Plant Food activation requests
	- Detecting glowing zombie deaths for charge collection
	- Executing Plant Food abilities on plants
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages:WaitForChild("MatterHooks"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local PlantData = require(Shared.data.PlantData)
local PlantFoodData = require(Shared.data.PlantFoodData)
local Logger = require(Shared.utils.core.Logger)
local EntityPool = require(Shared.utils.ecs.EntityPool)
local ECSUtils = require(Shared.utils.ecs.ECSUtils)
local LaneCache = require(Shared.utils.ecs.LaneCache)
local ValidationMiddleware = require(Shared.utils.combat.ValidationMiddleware)

-- Network
local Network = require(Shared.network.generated.server)

-- Server services
local Server = script.Parent.Parent.Parent

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 185,
})

-- ============================================================
-- SECTION 3: PRIVATE HELPERS
-- ============================================================

-- Execute Plant Food ability on a plant
local function executeAbility(
	world: any,
	plantId: number,
	plantType: string,
	player: Player,
	state: any,
	SunService: any
)
	local ability = PlantFoodData.GetAbility(plantType)
	if not ability then
		Logger.Warn("PlantFood", `No Plant Food ability defined for {plantType}`)
		return
	end

	local pos = world:get(plantId, Components.PositionComponent)
	if not pos then
		return
	end

	Logger.Info("PlantFood", `Executing {ability.Name} for {plantType}`)

	-- Instant Sun (Sunflower)
	if ability.InstantSun then
		SunService.AddSun(player, ability.InstantSun)
		SunService.BroadcastSunUpdate(player)
		Logger.Info("PlantFood", `{plantType} produced {ability.InstantSun} instant sun`)
	end

	-- Rapid Fire (Peashooter, Repeater, etc.) - Queue for time-based processing
	if ability.RapidFireShots and ability.ShotInterval then
		local shots = ability.RapidFireShots
		local interval = ability.ShotInterval
		
		-- Get plant's lane from PlantTypeComponent (plants use Lane, not GridPositionComponent.Row)
		local plantTypeComp = world:get(plantId, Components.PlantTypeComponent)
		local plantLane = plantTypeComp and plantTypeComp.Lane or 3 -- Default to middle lane

		-- Add to rapid fire queue (processed in OnStep, no task.wait)
		local queueId = state.RapidFireNextId
		state.RapidFireNextId = state.RapidFireNextId + 1
		
		state.RapidFireQueue[queueId] = {
			plantId = plantId,
			lane = plantLane,
			shotsRemaining = shots,
			nextShotTime = os.clock(), -- Fire first shot immediately
			interval = interval,
		}
		
		Logger.Info("PlantFood", `{plantType} rapid fire queued: {shots} shots`)
	end

	-- Freeze All (Snow Pea) - Using LaneCache for O(1) iteration
	if ability.FreezeAll and ability.FreezeDuration then
		local allZombies = LaneCache.GetAllZombies()
		
		for _, zombieId in allZombies do
			if not world:contains(zombieId) then
				continue
			end
			
			if not world:get(zombieId, Components.SlowComponent) then
				world:insert(
					zombieId,
					Components.SlowComponent({
						Multiplier = 0,
						Duration = ability.FreezeDuration,
						AppliedAt = os.clock(),
					})
				)
			end
		end
		Logger.Info("PlantFood", `Froze all zombies for {ability.FreezeDuration}s`)
	end

	-- Armor Boost (Wall-nut)
	if ability.ArmorBoost then
		if ECSUtils.BoostHealth(world, plantId, ability.ArmorBoost, Components) then
			Logger.Info("PlantFood", `{plantType} gained {ability.ArmorBoost} armor`)
		end
	end

	-- Instant Explode (CherryBomb, PotatoMine)
	-- OPTIMIZED: Uses LaneCache for O(lane_range) instead of O(all_zombies)
	if ability.InstantExplode then
		local radius = ability.ExplosionRadius or 9

		Network.ExplosionVFX.FireAll({
			PositionX = pos.X,
			PositionY = pos.Y,
			PositionZ = pos.Z,
			Radius = radius,
		})

		-- Get plant lane for optimized lookup
		local plantComp = world:get(plantId, Components.PlantTypeComponent)
		local centerLane = if plantComp then plantComp.Lane else 3
		local laneRadius = math.ceil(radius / GridConfig.CELL_SIZE)

		-- O(lane_range) lookup instead of O(N) world:query
		local zombiesInRange = LaneCache.GetEntitiesInLaneRange(centerLane, laneRadius)

		for _, zombieId in zombiesInRange do
			local zombiePos = LaneCache.GetPosition(zombieId)
			if not zombiePos then
				continue
			end

			local dx = zombiePos.X - pos.X
			local dz = zombiePos.Z - pos.Z
			local dist = math.sqrt(dx * dx + dz * dz)

			if dist <= radius then
				EntityPool.SafeDespawn(zombieId, world)
			end
		end

		EntityPool.SafeDespawn(plantId, world)
		Logger.Info("PlantFood", `{plantType} exploded with radius {radius}`)
	end
end

-- ============================================================
-- SECTION 4: SYSTEM FUNCTION (main ECS loop)
-- ============================================================
local function PlantFoodSystem(world)
	local currentTime = os.clock()

	-- State managed via Hooks.useMap (persistent across frames)
	-- Note: useMap returns { value: T }, so access via .value
	local stateWrapper = Hooks.useMap("PlantFoodState", {
		PendingRequests = {} :: { { player: Player, plantEntityId: number } },
		RapidFireQueue = {} :: {
			[number]: {
				plantId: number,
				lane: number,
				shotsRemaining: number,
				nextShotTime: number,
				interval: number,
			}
		},
		RapidFireNextId = 1,
		CachedZombieDir = Vector3.zero,
	})
	local state = stateWrapper.value

	-- Lazy load services via useMemo (empty deps = once)
	local PlantFoodService, SunService = Hooks.useMemo(function()
		return require(Server.services.PlantFoodService), require(Server.services.SunService)
	end, {})

	-- Setup network handler once via useMemo
	Hooks.useMemo(function()
		Network.PlantFoodRequest.SetCallback(function(player, data)
			table.insert(state.PendingRequests, {
				player = player,
				plantEntityId = data.PlantEntityId,
			})
		end)
		Logger.Debug("PlantFoodSystem", "Initialized network handler")
		return true
	end, {})

	-- Cache MapConfig values
	if MapConfig.IsInitialized() then
		state.CachedZombieDir = MapConfig.GetZombieDirection()
	end

	-- Process Rapid Fire queue (time-based, no task.wait)
	for queueId, rapidFire in state.RapidFireQueue do
		-- Check if plant still exists
		if not world:contains(rapidFire.plantId) then
			state.RapidFireQueue[queueId] = nil
			continue
		end

		-- Check if it's time to fire next shot
		if currentTime < rapidFire.nextShotTime then
			continue
		end

		-- Get current plant position
		local plantPos = world:get(rapidFire.plantId, Components.PositionComponent)
		if not plantPos then
			state.RapidFireQueue[queueId] = nil
			continue
		end

		-- Get zombie direction from cached value (plants shoot opposite direction)
		local zombieDir = state.CachedZombieDir
		local shootDirX = -zombieDir.X -- Opposite of zombie direction
		local shootDirZ = -zombieDir.Z

		-- Fire projectile with correct direction
		local spawnOffsetX = 2 * shootDirX
		local spawnOffsetZ = 2 * shootDirZ
		local spawnX = plantPos.X + spawnOffsetX
		local spawnZ = plantPos.Z + spawnOffsetZ
		
		local projId = EntityPool.Spawn(
			Components.ProjectileComponent({
				Damage = 20,
				Speed = 30,
				DirectionX = shootDirX,
				DirectionZ = shootDirZ,
				SpawnX = spawnX,
				Lane = rapidFire.lane,
				MaxRange = 100,
				SourceEntity = rapidFire.plantId,
			}),
			Components.PositionComponent({
				X = spawnX,
				Y = plantPos.Y + 2.5,
				Z = spawnZ,
			})
		)

		if projId then
			-- Network broadcast for client VFX
			Network.ProjectileSpawned.FireAll({
				EntityId = projId,
				Lane = rapidFire.lane,
				StartX = spawnX,
				Variant = "Pea",
				IsEnhanced = false,
				IsFrozen = false,
			})
		end

		-- Decrement shots remaining
		rapidFire.shotsRemaining = rapidFire.shotsRemaining - 1

		if rapidFire.shotsRemaining <= 0 then
			-- Finished rapid fire
			state.RapidFireQueue[queueId] = nil
		else
			-- Schedule next shot
			rapidFire.nextShotTime = currentTime + rapidFire.interval
		end
	end

	-- Process pending Plant Food activation requests
	for _, request in state.PendingRequests do
		local player = request.player
		local plantId = request.plantEntityId

		-- Validate plant exists
		local plant = world:get(plantId, Components.PlantTypeComponent)

		if not plant then
			Logger.Warn("PlantFood", `Invalid plant entity {plantId}`)
			continue
		end

		-- Run middleware validation hooks (God Mode integration)
		local allowed, middlewareReason = ValidationMiddleware.Validate("UsePlantFood", {
			Player = player,
			TargetEntity = plantId,
			PlantType = plant.PlantType,
			Column = plant.Column,
			Lane = plant.Lane,
		})
		if not allowed then
			Logger.Warn("PlantFood", `Plant Food blocked by middleware for {player.Name}: {middlewareReason}`)
			continue
		end

		-- Try to use a charge
		if not PlantFoodService.UseCharge(player) then
			Logger.Warn("PlantFood", `Player {player.Name} has no Plant Food charges`)
			continue
		end

		-- Execute the ability
		executeAbility(world, plantId, plant.PlantType, player, state, SunService)

		-- Broadcast activation event
		Network.PlantFoodActivated.FireAll({
			PlantEntityId = plantId,
			PlantType = plant.PlantType,
			OwnerId = player.UserId,
		})
	end

	-- Clear processed requests
	table.clear(state.PendingRequests)

	-- Handle glowing zombie deaths (grant Plant Food charges)
	for entityId, record in world:queryChanged(Components.HealthComponent) do
		-- Check if entity just died
		if record.new and record.new.Current <= 0 then
			-- Check if it was a glowing zombie
			local plantFood = world:get(entityId, Components.PlantFoodComponent)
			local zombie = world:get(entityId, Components.ZombieTypeComponent)

			if plantFood and zombie then
				-- Grant charge to all players (coop friendly)
				for _, player in Players:GetPlayers() do
					local newCharges = PlantFoodService.AddCharge(player)

					Network.PlantFoodCollected.FireAll({
						CollectorId = player.UserId,
						NewChargeCount = newCharges,
						ZombieEntityId = entityId,
					})
				end

				Logger.Info("PlantFood", `Glowing zombie killed, Plant Food collected!`)
			end
		end
	end
end

-- ============================================================
-- SECTION 5: EXPORT (V3 - priority + system only)
-- ============================================================
return {
	priority = CONFIG.PRIORITY,
	system = PlantFoodSystem,
}
