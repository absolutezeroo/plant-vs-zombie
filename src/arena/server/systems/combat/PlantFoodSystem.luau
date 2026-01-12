--!strict
--[[
	PlantFoodSystem.luau - Plant Food mechanics
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 185 (After death system 180, before cleanup)
	
	Handles:
	- Processing Plant Food activation requests
	- Detecting glowing zombie deaths for charge collection
	- Executing Plant Food abilities on plants
	
	LIFECYCLE:
	- Init(): Setup network handlers (CAN yield)
	- OnStep(): Main loop (CANNOT yield) - processes requests
	- Dispose(): Clear pending requests
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local PlantData = require(Shared.data.PlantData)
local PlantFoodData = require(Shared.data.PlantFoodData)
local Logger = require(Shared.utils.Logger)
local EntityPool = require(Shared.utils.EntityPool)
local ECSUtils = require(Shared.utils.ECSUtils)
local LaneCache = require(Shared.utils.LaneCache)

-- Network
local Network = require(Shared.network.generated.server)

-- Server services
local Server = script.Parent.Parent.Parent
local PlantFoodService = require(Server.services.PlantFoodService)

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 185,
})

-- ============================================================
-- SECTION 3: STATE (all mutable data)
-- ============================================================
local State = {
	PendingRequests = {} :: {{player: Player, plantEntityId: number}},
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

-- Execute Plant Food ability on a plant
local function executeAbility(world: any, plantId: number, plantType: string, player: Player)
	local ability = PlantFoodData.GetAbility(plantType)
	if not ability then
		Logger.Warn("PlantFood", `No Plant Food ability defined for {plantType}`)
		return
	end
	
	local pos = world:get(plantId, Components.PositionComponent)
	if not pos then return end
	
	Logger.Info("PlantFood", `Executing {ability.Name} for {plantType}`)
	
	-- Instant Sun (Sunflower)
	if ability.InstantSun then
		local SunService = require(Server.services.SunService)
		SunService.AddSun(player, ability.InstantSun)
		SunService.BroadcastSunUpdate(player)
		Logger.Info("PlantFood", `{plantType} produced {ability.InstantSun} instant sun`)
	end
	
	-- Rapid Fire (Peashooter, Repeater, etc.)
	if ability.RapidFireShots and ability.ShotInterval then
		local shots = ability.RapidFireShots
		local interval = ability.ShotInterval
		
		task.spawn(function()
			for i = 1, shots do
				if not world:contains(plantId) then break end
				
				local plantPos = world:get(plantId, Components.PositionComponent)
				if not plantPos then break end
				
				-- Create rapid-fire projectile
				local projId = EntityPool.Spawn(
					Components.ProjectileComponent({
						Damage = 20,
						Speed = 30,
						SourcePlantId = plantId,
						OwnerId = player.UserId,
					}),
					Components.PositionComponent({
						X = plantPos.X + 2,
						Y = plantPos.Y + 2.5,
						Z = plantPos.Z,
					})
				)
				
				if not projId then break end
				
				task.wait(interval)
			end
		end)
	end
	
	-- Freeze All (Snow Pea)
	if ability.FreezeAll and ability.FreezeDuration then
		for zombieId, _ in world:query(Components.ZombieTypeComponent) do
			if not world:get(zombieId, Components.SlowComponent) then
				world:insert(zombieId, Components.SlowComponent({
					Multiplier = 0,
					Duration = ability.FreezeDuration,
					AppliedAt = os.clock(),
				}))
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
			if not zombiePos then continue end
			
			local dx = zombiePos.X - pos.X
			local dz = zombiePos.Z - pos.Z
			local dist = math.sqrt(dx * dx + dz * dz)
			
			if dist <= radius then
				if EntityPool.IsPooledEntity(zombieId) then
					EntityPool.Despawn(zombieId)
				else
					world:despawn(zombieId)
				end
			end
		end
		
		if EntityPool.IsPooledEntity(plantId) then
			EntityPool.Despawn(plantId)
		else
			world:despawn(plantId)
		end
		Logger.Info("PlantFood", `{plantType} exploded with radius {radius}`)
	end
end

-- ============================================================
-- SECTION 5: ONSTEP (main ECS loop)
-- ============================================================
local function OnStep(world)
	-- Process pending Plant Food activation requests
	for _, request in State.PendingRequests do
		local player = request.player
		local plantId = request.plantEntityId
		
		-- Validate plant exists
		local plant = world:get(plantId, Components.PlantTypeComponent)
		
		if not plant then
			Logger.Warn("PlantFood", `Invalid plant entity {plantId}`)
			continue
		end
		
		-- Try to use a charge
		if not PlantFoodService.UseCharge(player) then
			Logger.Warn("PlantFood", `Player {player.Name} has no Plant Food charges`)
			continue
		end
		
		-- Execute the ability
		executeAbility(world, plantId, plant.PlantType, player)
		
		-- Broadcast activation event
		Network.PlantFoodActivated.FireAll({
			PlantEntityId = plantId,
			PlantType = plant.PlantType,
			OwnerId = player.UserId,
		})
	end
	
	-- Clear processed requests
	table.clear(State.PendingRequests)
	
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
-- SECTION 6: INIT / DISPOSE
-- ============================================================
local function Init(_world)
	-- Setup network handler for Plant Food requests
	Network.PlantFoodRequest.SetCallback(function(player, data)
		table.insert(State.PendingRequests, {
			player = player,
			plantEntityId = data.PlantEntityId,
		})
	end)
	
	Logger.Debug("PlantFoodSystem", "Initialized")
end

local function Dispose()
	table.clear(State.PendingRequests)
	Logger.Debug("PlantFoodSystem", "Disposed")
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
