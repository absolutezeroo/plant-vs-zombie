--!strict
--[[
	FullStateSyncSystem.luau - Server-side state synchronization for late joiners
	
	Priority: 50 (Very early - before other systems)
	
	When a player joins, sends them all existing entities and game state.
	Uses MatterHooks.useAsync for non-blocking delayed sync operations.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))
local Matter = require(Packages:WaitForChild("Matter"))
local Hooks = require(Packages:WaitForChild("MatterHooks"))

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
	Trove = nil :: any,
	PendingSync = {} :: { [Player]: boolean },
	World = nil :: any,
}

-- Helper: Sync all state to a player
local function syncPlayer(player: Player, world: any)
	if not player or not player.Parent then
		return false
	end

	-- Sync all plants
	for id, plant, _pos in world:query(Components.PlantTypeComponent, Components.PositionComponent) do
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

	return true
end

-- 4. INIT
local function Init(_world)
	if State.Trove then
		return
	end

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
	table.clear(State.PendingSync)
	State.World = nil
end

-- 6. MAIN LOOP
local function OnStep(world)
	State.World = world

	-- Process pending syncs using useAsync for non-blocking delay
	for player, _ in State.PendingSync do
		if player and player.Parent then
			-- Use useAsync to handle the delayed sync without yielding
			local ready = Hooks.useAsync(function()
				-- Simulate delay by yielding in async context
				task.wait(CONFIG.SYNC_DELAY)
				return syncPlayer(player, world)
			end, {}, player) -- discriminator = player for unique tracking

			if ready.completed then
				-- Sync completed (success or failure), remove from pending
				State.PendingSync[player] = nil
			end
		else
			-- Player left, remove from pending
			State.PendingSync[player] = nil
		end
	end
end

-- 7. EXPORT
return {
	priority = 50,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
