--!strict
--[[
	FullStateSyncSystem.luau - Server-side state synchronization for late joiners
	
	Priority: 50 (Very early - before other systems)
	
	When a player joins, sends them all existing entities and game state.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent
local BaseHealth = require(Server.modules.BaseHealth)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	SYNC_DELAY = 0.5, -- Seconds to wait for client readiness
})

-- 3. STATE
local State = {
	IsInitialized = false,
	Trove = nil :: any,
	PendingSync = {} :: { [Player]: boolean },
	World = nil :: any,
}

-- Helper: Sync all state to a player
local function syncPlayer(player: Player, world: any)
	if not player or not player.Parent then
		return
	end

	-- Sync all plants
	for id, plant, pos in world:query(Components.PlantTypeComponent, Components.PositionComponent) do
		-- Get mutations if present
		local mutationsComp = world:get(id, Components.MutationsComponent)
		local mutations: { string } = {}
		if mutationsComp and mutationsComp.MutationIds then
			mutations = mutationsComp.MutationIds
		end

		Network.PlantSpawned.Fire(player, {
			EntityId = id,
			PlantType = plant.PlantType :: any,
			Column = plant.Column :: any,
			Lane = plant.Lane :: any,
			Mutations = mutations :: any,
		})
	end

	-- Sync all zombies
	for id, zombie, pos in world:query(Components.ZombieTypeComponent, Components.PositionComponent) do
		Network.ZombieSpawned.Fire(player, {
			EntityId = id,
			ZombieType = zombie.ZombieType :: any,
			Lane = zombie.Lane :: any,
			PositionX = pos.X,
		})
	end

	-- Sync all sun orbs
	for id, sun, pos in world:query(Components.SunComponent, Components.PositionComponent) do
		Network.SunSpawned.Fire(player, {
			EntityId = id,
			PositionX = pos.X,
			PositionY = pos.Y,
			PositionZ = pos.Z,
			Value = sun.Value,
			TargetY = sun.TargetY or pos.Y,
		})
	end

	-- Sync base health
	Network.BaseHealthUpdated.Fire(player, {
		CurrentHealth = BaseHealth.GetHealth(),
		MaxHealth = BaseHealth.GetMaxHealth(),
		DamageAmount = 0,
	})
end

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end
	State.IsInitialized = true

	State.Trove = Trove.new()

	State.Trove:Connect(Players.PlayerAdded, function(player: Player)
		State.PendingSync[player] = true
	end)

	State.Trove:Connect(Players.PlayerRemoving, function(player: Player)
		State.PendingSync[player] = nil
	end)
end

-- 5. DISPOSE
local function Dispose()
	if State.Trove then
		State.Trove:Clean()
		State.Trove = nil
	end
	State.IsInitialized = false
	table.clear(State.PendingSync)
	State.World = nil
end

-- 6. MAIN LOOP
local function OnStep(world)
	State.World = world

	-- Process pending syncs (with small delay for client readiness)
	for player, _ in State.PendingSync do
		if player and player.Parent then
			task.delay(CONFIG.SYNC_DELAY, function()
				if player and player.Parent then
					syncPlayer(player, world)
				end
			end)
		end
		State.PendingSync[player] = nil
	end
end

-- 7. EXPORT
return {
	priority = 50,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
