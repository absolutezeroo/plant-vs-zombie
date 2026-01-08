--!strict
--[[
	PlantFoodSystem.luau - Plant Food mechanics
	
	Priority: 185 (After death system 180, before cleanup)
	
	Handles:
	- Tracking glowing zombies that drop Plant Food
	- Collecting Plant Food charges when glowing zombies die
	- Activating Plant Food abilities on plants
	- Managing player charge counts (max 3)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local PlantData = require(Shared.data.PlantData)
local PlantFoodData = require(Shared.data.PlantFoodData)
local Logger = require(Shared.utils.Logger)
local Types = require(Shared.Types)

-- Type alias for world parameter
type MatterWorld = Types.MatterWorld

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent

-- Components
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local PlantTypeComponent = Components.PlantTypeComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local PlantFoodComponent = Components.PlantFoodComponent
local OwnerComponent = Components.OwnerComponent
local ProjectileComponent = Components.ProjectileComponent

-- Configuration
local Config = {
	MAX_CHARGES = 3,
	GLOWING_ZOMBIE_CHANCE = 0.15,  -- 15% chance for zombie to be glowing
	GUARANTEED_PER_WAVE = 1,       -- At least 1 glowing per wave
}

-- Player charge storage
local _playerCharges: {[number]: number} = {}  -- UserId -> charge count

-- Track glowing zombies spawned this wave (for guaranteed spawns)
local _glowingSpawnedThisWave = 0

-- Module API for external access
local PlantFoodSystem = {}
PlantFoodSystem.priority = 185
PlantFoodSystem.API = {}

-- ============================================
-- API Functions (for other systems)
-- ============================================

function PlantFoodSystem.API.GetCharges(player: Player): number
	return _playerCharges[player.UserId] or 0
end

function PlantFoodSystem.API.AddCharge(player: Player, amount: number?): number
	local userId = player.UserId
	local current = _playerCharges[userId] or 0
	local newCount = math.min(current + (amount or 1), Config.MAX_CHARGES)
	_playerCharges[userId] = newCount
	
	-- Notify client
	Network.PlantFoodChargeUpdate.Fire(player, {
		ChargeCount = newCount,
	})
	
	Logger.Info("PlantFood", `Player {player.Name} gained charge: {current} -> {newCount}`)
	return newCount
end

function PlantFoodSystem.API.UseCharge(player: Player): boolean
	local userId = player.UserId
	local current = _playerCharges[userId] or 0
	
	if current <= 0 then
		return false
	end
	
	_playerCharges[userId] = current - 1
	
	-- Notify client
	Network.PlantFoodChargeUpdate.Fire(player, {
		ChargeCount = current - 1,
	})
	
	Logger.Info("PlantFood", `Player {player.Name} used charge: {current} -> {current - 1}`)
	return true
end

function PlantFoodSystem.API.ShouldZombieBeGlowing(): boolean
	-- First zombie each wave is guaranteed to be glowing
	if _glowingSpawnedThisWave < Config.GUARANTEED_PER_WAVE then
		_glowingSpawnedThisWave += 1
		return true
	end
	
	-- Random chance for additional glowing zombies
	return math.random() < Config.GLOWING_ZOMBIE_CHANCE
end

function PlantFoodSystem.API.ResetWaveTracking()
	_glowingSpawnedThisWave = 0
end

-- ============================================
-- Plant Food Ability Execution
-- ============================================

local function executeAbility(world: MatterWorld, plantId: number, plantType: string, player: Player)
	local ability = PlantFoodData.GetAbility(plantType)
	if not ability then
		Logger.Warn("PlantFood", `No Plant Food ability defined for {plantType}`)
		return
	end
	
	local pos = world:get(plantId, PositionComponent)
	if not pos then return end
	
	Logger.Info("PlantFood", `Executing {ability.Name} for {plantType}`)
	
	-- Instant Sun (Sunflower)
	if ability.InstantSun then
		-- Award sun to player
		local PlayerDataService = require(Server.services.PlayerDataService)
		PlayerDataService.AddSun(player, ability.InstantSun)
		Logger.Info("PlantFood", `{plantType} produced {ability.InstantSun} instant sun`)
	end
	
	-- Rapid Fire (Peashooter, Repeater, etc.)
	if ability.RapidFireShots and ability.ShotInterval then
		-- Schedule rapid fire shots
		local shots = ability.RapidFireShots
		local interval = ability.ShotInterval
		
		task.spawn(function()
			for i = 1, shots do
				-- Check if plant still exists
				if not world:contains(plantId) then break end
				
				-- Find nearest zombie in lane (same logic as ProjectileSystem)
				local plantPos = world:get(plantId, PositionComponent)
				if not plantPos then break end
				
				-- Create rapid-fire projectile
				world:spawn(
					ProjectileComponent({
						Damage = 20,
						Speed = 30,  -- Faster than normal
						SourcePlantId = plantId,
						OwnerId = player.UserId,
					}),
					PositionComponent({
						X = plantPos.X + 2,
						Y = plantPos.Y + 2.5,
						Z = plantPos.Z,
					})
				)
				
				task.wait(interval)
			end
		end)
	end
	
	-- Freeze All (Snow Pea)
	if ability.FreezeAll and ability.FreezeDuration then
		-- Apply slow to all zombies
		local SlowComponent = Components.SlowComponent
		for zombieId, _ in world:query(ZombieTypeComponent) do
			if not world:get(zombieId, SlowComponent) then
				world:insert(zombieId, SlowComponent({
					Multiplier = 0,  -- Complete freeze
					Duration = ability.FreezeDuration,
					AppliedAt = os.clock(),
				}))
			end
		end
		Logger.Info("PlantFood", `Froze all zombies for {ability.FreezeDuration}s`)
	end
	
	-- Armor Boost (Wall-nut)
	if ability.ArmorBoost then
		local health = world:get(plantId, HealthComponent)
		if health then
			world:insert(plantId, HealthComponent({
				Current = health.Current + ability.ArmorBoost,
				Max = health.Max + ability.ArmorBoost,
			}))
			Logger.Info("PlantFood", `{plantType} gained {ability.ArmorBoost} armor`)
		end
	end
	
	-- Instant Explode (CherryBomb, PotatoMine)
	if ability.InstantExplode then
		local radius = ability.ExplosionRadius or 9
		
		-- Trigger explosion at plant position
		Network.ExplosionVFX.FireAll({
			PositionX = pos.X,
			PositionY = pos.Y,
			PositionZ = pos.Z,
			Radius = radius,
		})
		
		-- Damage all zombies in radius
		for zombieId, zombiePos in world:query(PositionComponent, ZombieTypeComponent) do
			local dx = zombiePos.X - pos.X
			local dz = zombiePos.Z - pos.Z
			local dist = math.sqrt(dx * dx + dz * dz)
			
			if dist <= radius then
				world:despawn(zombieId)
			end
		end
		
		-- Remove the plant after explosion
		world:despawn(plantId)
		Logger.Info("PlantFood", `{plantType} exploded with radius {radius}`)
	end
end

-- ============================================
-- Network Handler
-- ============================================

local function handlePlantFoodRequest(player: Player, data: {PlantEntityId: number})
	local PlayerDataService = require(Server.services.PlayerDataService)
	
	-- Get the world from the loop (need to access global state)
	-- This is handled by the system function below
	Logger.Info("PlantFood", `Player {player.Name} requested Plant Food on entity {data.PlantEntityId}`)
end

-- Store pending requests for the system to process
local _pendingRequests: {{player: Player, plantEntityId: number}} = {}

Network.PlantFoodRequest.SetCallback(function(player, data)
	table.insert(_pendingRequests, {
		player = player,
		plantEntityId = data.PlantEntityId,
	})
end)

-- ============================================
-- Main System Function
-- ============================================

function PlantFoodSystem.system(world: MatterWorld)
	-- Process pending Plant Food activation requests
	for _, request in _pendingRequests do
		local player = request.player
		local plantId = request.plantEntityId
		
		-- Validate plant exists and belongs to player
		local plant = world:get(plantId, PlantTypeComponent)
		local owner = world:get(plantId, OwnerComponent)
		
		if not plant then
			Logger.Warn("PlantFood", `Invalid plant entity {plantId}`)
			continue
		end
		
		-- Check if player owns the plant (or allow any player for coop)
		-- For MVP, allow any player to use Plant Food on any plant
		
		-- Try to use a charge
		if not PlantFoodSystem.API.UseCharge(player) then
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
	table.clear(_pendingRequests)
	
	-- Handle glowing zombie deaths (grant Plant Food charges)
	for entityId, record in world:queryChanged(HealthComponent) do
		-- Check if entity just died
		if record.new and record.new.Current <= 0 then
			-- Check if it was a glowing zombie
			local plantFood = world:get(entityId, PlantFoodComponent)
			local zombie = world:get(entityId, ZombieTypeComponent)
			
			if plantFood and zombie then
				-- Grant charge to all players (coop friendly)
				-- In competitive mode, could grant to killer only
				for _, player in Players:GetPlayers() do
					local newCharges = PlantFoodSystem.API.AddCharge(player)
					
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

-- Initialize charges for new players
Players.PlayerAdded:Connect(function(player)
	_playerCharges[player.UserId] = 0
	
	Network.PlantFoodChargeUpdate.Fire(player, {
		ChargeCount = 0,
	})
end)

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	_playerCharges[player.UserId] = nil
end)

return PlantFoodSystem
