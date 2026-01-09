--!strict
--[[
	EntityDeathSystem.luau - Server-side entity death handling
	
	Priority: 180 (Simulation phase - after combat)
	
	Handles:
	- Detecting entities with 0 health
	- Broadcasting EntityDied events
	- Cleaning up grid occupancy for plants
	- Spawning coins for zombie kills
	- Despawning dead entities
	
	LIFECYCLE:
	- Init(): Setup player listener (CAN yield)
	- system(): Main loop (CANNOT yield) - processes entity deaths
	- Dispose(): Cleanup player connection and session stats
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)
local ProgressionData = require(Shared.data.ProgressionData)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent
local GridService = require(Server.services.GridService)

-- Components (via index module)
local HealthComponent = Components.HealthComponent
local PlantTypeComponent = Components.PlantTypeComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local PositionComponent = Components.PositionComponent

-- Player data service (lazy load to avoid circular deps)
local _playerDataService: any = nil
local function getPlayerDataService()
	if not _playerDataService then
		_playerDataService = require(Server.services.PlayerDataService)
	end
	return _playerDataService
end

-- Session zombie kill tracking (for end-game stats)
local _sessionStats: {[Player]: {ZombiesKilled: number, CoinsEarned: number}} = {}

-- Trove for cleanup
local _trove = Trove.new()

local function getSessionStats(player: Player)
	if not _sessionStats[player] then
		_sessionStats[player] = {ZombiesKilled = 0, CoinsEarned = 0}
	end
	return _sessionStats[player]
end

-- API for external access to session stats
local API = {}

function API.GetSessionStats(player: Player): {ZombiesKilled: number, CoinsEarned: number}
	return getSessionStats(player)
end

function API.ResetSessionStats(player: Player)
	_sessionStats[player] = {ZombiesKilled = 0, CoinsEarned = 0}
end

function API.ResetAllSessionStats()
	table.clear(_sessionStats)
end

local function EntityDeathSystem(world)
	-- Check all entities with health
	for id, health in world:query(HealthComponent) do
		if health.Current <= 0 then
			-- Entity is dead
			
			-- Check if it's a plant (need to clear grid)
			local plant = world:get(id, PlantTypeComponent)
			if plant then
				GridService.Clear(plant.Column, plant.Lane)
				Logger.Info("EntityDeath", `Plant {id} ({plant.PlantType}) died at ({plant.Column}, {plant.Lane})`)
			end
			
			-- Check if it's a zombie (need to drop coins)
			local zombie = world:get(id, ZombieTypeComponent)
			if zombie then
				Logger.Info("EntityDeath", `Zombie {id} ({zombie.ZombieType}) died in lane {zombie.Lane}`)
				
				-- Calculate coin reward
				local coinValue = ProgressionData.ZombieCoinRewards[zombie.ZombieType] or 5
				
				-- Get zombie position for coin spawn location
				local pos = world:get(id, PositionComponent)
				local posX = if pos then pos.X else 0
				local posZ = if pos then pos.Z else 0
				
				-- Award coins to all players (multiplayer fairness)
				-- In a competitive mode, we'd track who dealt damage
				local PlayerDataService = getPlayerDataService()
				for _, player in Players:GetPlayers() do
					PlayerDataService.AddCoins(player, coinValue)
					PlayerDataService.IncrementStat(player, "ZombiesKilled", 1)
					
					-- Track session stats
					local stats = getSessionStats(player)
					stats.ZombiesKilled += 1
					stats.CoinsEarned += coinValue
					
					-- Notify client for VFX
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
			
			-- Despawn the entity
			world:despawn(id)
		end
	end
end

-- Clean up when players leave
local function onPlayerRemoving(player)
	_sessionStats[player] = nil
end

local function setupListeners()
	_trove:Connect(Players.PlayerRemoving, onPlayerRemoving)
end

local function Init(_world)
	setupListeners()
end

local function Dispose()
	_trove:Destroy()
	_trove = Trove.new()
	table.clear(_sessionStats)
end

return {
	_name = "EntityDeathSystem",
	priority = 180,
	system = EntityDeathSystem,
	Init = Init,
	Dispose = Dispose,
	API = API,
}
