--!strict
--[[
	EntityDeathSystem.luau - Server-side entity death handling
	
	Priority: 180 (Simulation phase - after combat)
	
	Handles:
	- Detecting entities with 0 health
	- Broadcasting EntityDied events
	- Cleaning up grid occupancy for plants
	- Spawning coins for zombie kills
	
	V2.0 Architecture:
	- Init(world): Initialize trove for cleanup
	- Dispose(): Clean up connections
	- OnStep(world): Process entity deaths via health query
]]

-- 1. IMPORTS
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local ProgressionData = require(Shared.data.ProgressionData)
local EntityPool = require(Shared.utils.EntityPool)
local Logger = require(Shared.utils.Logger)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent
local GridService = require(Server.services.GridService)
local PlantFoodService = require(Server.services.PlantFoodService)

-- 2. CONFIGURATION (no config needed for this system)
local CONFIG = table.freeze({
	DEFAULT_COIN_VALUE = 5,
})

-- 3. STATE
local State = {
	IsInitialized = false,
	Trove = nil :: any,
	PlayerDataService = nil :: any,
	StatsService = nil :: any,
}

-- 4. PRIVATE HELPERS

-- Helper: Get PlayerDataService (lazy load)
local function getPlayerDataService()
	if not State.PlayerDataService then
		State.PlayerDataService = require(Server.services.PlayerDataService)
	end
	return State.PlayerDataService
end

-- Helper: Get StatsService (lazy load)
local function getStatsService()
	if not State.StatsService then
		State.StatsService = require(Server.services.StatsService)
	end
	return State.StatsService
end

-- 5. LIFECYCLE: INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end
	State.IsInitialized = true

	State.Trove = Trove.new()
end

-- 6. LIFECYCLE: DISPOSE
local function Dispose()
	if State.Trove then
		State.Trove:Destroy()
		State.Trove = Trove.new()
	end
	State.IsInitialized = false
	State.PlayerDataService = nil
	State.StatsService = nil
end

-- 7. MAIN LOOP
local function OnStep(world)
	-- Check all entities with health
	for id, health in world:query(Components.HealthComponent) do
		if health.Current <= 0 then
			-- Entity is dead

			-- Check if it's a plant (need to clear grid - also auto-decrements owner's plant count)
			local plant = world:get(id, Components.PlantTypeComponent)
			if plant then
				GridService.Clear(plant.Column, plant.Lane)
			end

			-- Check if it's a zombie (need to drop coins)
			local zombie = world:get(id, Components.ZombieTypeComponent)
			if zombie then
				-- Check if zombie was glowing (Plant Food carrier)
				local plantFood = world:get(id, Components.PlantFoodComponent)
				if plantFood and plantFood.IsGlowing then
					-- Award Plant Food charge to all players
					for _, player in Players:GetPlayers() do
						PlantFoodService.AddCharge(player, 1)
						Logger.Info("EntityDeath", `🌟 Player {player.Name} collected Plant Food from glowing zombie`)
					end
					
					-- Broadcast Plant Food collected VFX
					local pfPos = world:get(id, Components.PositionComponent)
					Network.PlantFoodCollected.FireAll({
						CollectorId = 0, -- All players collect
						NewChargeCount = 0, -- Individual updates sent via PlantFoodChargeUpdate
						ZombieEntityId = id,
					})
				end
				
				local coinValue = ProgressionData.ZombieCoinRewards[zombie.ZombieType] or CONFIG.DEFAULT_COIN_VALUE

				local pos = world:get(id, Components.PositionComponent)
				local posX = if pos then pos.X else 0
				local posY = if pos then pos.Y else 0
				local posZ = if pos then pos.Z else 0

				-- Spawn CoinDropEvent for VFX/Audio systems
				world:spawn(Components.CoinDropEvent({
					Amount = coinValue,
					PositionX = posX,
					PositionY = posY,
					PositionZ = posZ,
					SourceEntityId = id,
				}))

				-- Award coins to all players
				local PlayerDataService = getPlayerDataService()
				local StatsService = getStatsService()
				for _, player in Players:GetPlayers() do
					PlayerDataService.AddCoins(player, coinValue)
					PlayerDataService.IncrementStat(player, "ZombiesKilled", 1)

					-- Update session stats via StatsService
					StatsService.AddZombieKill(player, 1)
					StatsService.AddCoinsEarned(player, coinValue)

					Network.CoinGained.Fire(player, {
						Amount = coinValue,
						TotalCoins = PlayerDataService.GetCoins(player),
						SourceX = posX,
						SourceZ = posZ,
					})
				end
			end

			-- Broadcast death to all clients
			Network.EntityDied.FireAll({
				EntityId = id,
			})

			-- Spawn DeathEvent for other systems
			local deathPos = world:get(id, Components.PositionComponent)
			local entityType = if plant then "Plant" elseif zombie then "Zombie" else "Unknown"
			world:spawn(Components.DeathEvent({
				Target = id,
				EntityType = entityType,
				PositionX = if deathPos then deathPos.X else 0,
				PositionY = if deathPos then deathPos.Y else 0,
				PositionZ = if deathPos then deathPos.Z else 0,
			}))

			-- Release entity back to pool
			if EntityPool.IsPooledEntity(id) then
				EntityPool.Despawn(id)
			else
				world:despawn(id)
			end
		end
	end
end

-- 8. EXPORT
return {
	priority = 180,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
