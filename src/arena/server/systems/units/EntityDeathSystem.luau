--!strict
--[[
	EntityDeathSystem.luau - Server-side entity death handling
	
	Priority: 180 (Simulation phase - after combat)
	
	Handles:
	- Detecting entities with 0 health
	- Broadcasting EntityDied events
	- Cleaning up grid occupancy for plants
	- Spawning coins for zombie kills
	
	V3 Architecture: Matter Hooks pattern
]]

-- 1. IMPORTS
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages.MatterHooks)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)

-- Server services
local ServerEventBus = require(script.Parent.Parent.Parent.services.ServerEventBus)
local ProgressionData = require(Shared.data.ProgressionData)
local EntityPool = require(Shared.utils.ecs.EntityPool)
local Logger = require(Shared.utils.core.Logger)
local NetworkUtils = require(Shared.utils.network.NetworkUtils)

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

-- 3. PRIVATE HELPERS

-- Helper: Get services (lazy load via useMemo in system)
local function getServices()
	local PlayerDataService = require(Server.services.PlayerDataService)
	local StatsService = require(Server.services.StatsService)
	return PlayerDataService, StatsService
end

-- 4. SYSTEM FUNCTION
local function EntityDeathSystem(world)
	-- Lazy load services via useMemo (empty deps = once)
	local PlayerDataService, StatsService = Hooks.useMemo(function()
		return getServices()
	end, {})
	-- Check all entities with health
	for id, health in world:query(Components.HealthComponent) do
		if health.Current <= 0 then
			-- Entity is dead

			-- Check if it's a plant (need to clear grid - also auto-decrements owner's plant count)
			local plant = world:get(id, Components.PlantTypeComponent)
			if plant then
				-- Fire ServerEventBus event for plant death
				local plantDeathPos = world:get(id, Components.PositionComponent)
				ServerEventBus.FireEntityDied({
					EntityId = id,
					EntityType = "Plant",
					Position = {
						X = if plantDeathPos then plantDeathPos.X else 0,
						Y = if plantDeathPos then plantDeathPos.Y else 0,
						Z = if plantDeathPos then plantDeathPos.Z else 0,
					},
					PlantType = plant.PlantType,
					Lane = plant.Lane,
				})
				
				GridService.Clear(plant.Column, plant.Lane)
				
				-- Check if this plant was protected by a Pumpkin shell
				local shell = world:get(id, Components.ShellComponent)
				if shell then
					-- If this is a Pumpkin that was protecting another plant
					if shell.ProtectsPlant and world:contains(shell.ProtectsPlant) then
						-- Remove the protection from the inner plant
						world:remove(shell.ProtectsPlant, Components.ShellComponent)
					end
					
					-- If this plant was protected by a Pumpkin, destroy the Pumpkin too
					-- (inner plant died first somehow - e.g., explosive zombie)
					if shell.ProtectedByShell and world:contains(shell.ProtectedByShell) then
						-- Mark Pumpkin for death by zeroing health
						local pumpkinHealth = world:get(shell.ProtectedByShell, Components.HealthComponent)
						if pumpkinHealth and pumpkinHealth.Current > 0 then
							world:insert(shell.ProtectedByShell, Components.HealthComponent({
								Current = 0,
								Max = pumpkinHealth.Max,
							}))
						end
					end
				end
			end

			-- Check if it's a zombie (need to drop coins)
			local zombie = world:get(id, Components.ZombieTypeComponent)
			if zombie then
				-- Fire ServerEventBus event for zombie death
				local zombieDeathPos = world:get(id, Components.PositionComponent)
				ServerEventBus.FireEntityDied({
					EntityId = id,
					EntityType = "Zombie",
					Position = {
						X = if zombieDeathPos then zombieDeathPos.X else 0,
						Y = if zombieDeathPos then zombieDeathPos.Y else 0,
						Z = if zombieDeathPos then zombieDeathPos.Z else 0,
					},
					ZombieType = zombie.ZombieType,
					Lane = zombie.Lane,
				})
				
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
			NetworkUtils.BroadcastEntityDied(id)

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
			EntityPool.SafeDespawn(id, world)
		end
	end
end

-- 5. EXPORT
return {
	priority = 180,
	system = EntityDeathSystem,
}
