--!strict
--[[
	FullStateSyncSystem.luau - Server-side state synchronization for late joiners
	
	Priority: 50 (Very early - before other systems)
	
	When a player joins, sends them:
	- All existing plants
	- All existing zombies
	- All existing sun orbs
	- Current wave number
	- Base health
	- Game state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent
local BaseHealth = require(Server.modules.BaseHealth)

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local PlantTypeComponent = Components.PlantTypeComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local SunComponent = Components.SunComponent
local HealthComponent = Components.HealthComponent

-- Track players pending sync
local _pendingSync: {[Player]: boolean} = {}
local _world: any = nil

local function syncPlayer(player: Player, world: any)
	if not player or not player.Parent then
		return
	end
	
	Logger.Info("FullStateSync", `Syncing full state to {player.Name}`)
	
	-- Count entities for logging
	local plantCount = 0
	local zombieCount = 0
	local sunCount = 0
	
	-- Sync all plants
	for id, plant, pos in world:query(PlantTypeComponent, PositionComponent) do
		Network.PlantSpawned.Fire(player, {
			EntityId = id,
			PlantType = plant.PlantType :: any,
			Column = plant.Column :: any,
			Lane = plant.Lane :: any,
		})
		plantCount += 1
	end
	
	-- Sync all zombies
	for id, zombie, pos in world:query(ZombieTypeComponent, PositionComponent) do
		Network.ZombieSpawned.Fire(player, {
			EntityId = id,
			ZombieType = zombie.ZombieType :: any,
			Lane = zombie.Lane :: any,
			PositionX = pos.X,
		})
		zombieCount += 1
	end
	
	-- Sync all sun orbs
	for id, sun, pos in world:query(SunComponent, PositionComponent) do
		Network.SunSpawned.Fire(player, {
			EntityId = id,
			PositionX = pos.X,
			PositionY = pos.Y,
			PositionZ = pos.Z,
			Value = sun.Value,
			TargetY = sun.TargetY or pos.Y,
		})
		sunCount += 1
	end
	
	-- Sync base health
	Network.BaseHealthUpdated.Fire(player, {
		CurrentHealth = BaseHealth.GetHealth(),
		MaxHealth = BaseHealth.GetMaxHealth(),
		DamageAmount = 0,
	})
	
	Logger.Info("FullStateSync", `Synced to {player.Name}: {plantCount} plants, {zombieCount} zombies, {sunCount} sun`)
end

-- Handle player joining
local function onPlayerAdded(player: Player)
	-- Delay sync slightly to ensure client is ready
	_pendingSync[player] = true
end

local function onPlayerRemoving(player: Player)
	_pendingSync[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- System runs each frame to process pending syncs
local function FullStateSyncSystem(world)
	_world = world
	
	-- Process pending syncs (with small delay for client readiness)
	for player, _ in _pendingSync do
		if player and player.Parent then
			-- Check if player has been connected for at least 0.5 seconds
			-- This gives time for client to initialize
			task.delay(0.5, function()
				if player and player.Parent then
					syncPlayer(player, world)
				end
			end)
		end
		_pendingSync[player] = nil
	end
end

return {
	system = FullStateSyncSystem,
	priority = 50,
}
