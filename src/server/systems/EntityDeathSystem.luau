--!strict
--[[
	EntityDeathSystem.luau - Server-side entity death handling
	
	Priority: 180 (Simulation phase - after combat)
	
	Handles:
	- Detecting entities with 0 health
	- Broadcasting EntityDied events
	- Cleaning up grid occupancy for plants
	- Despawning dead entities
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = Shared.components
local Logger = require(Shared.utils.Logger)

-- Network
local Server = script.Parent.Parent
local Network = require(Server.network.generated)
local GridState = require(Server.modules.GridState)

-- Components
local HealthComponent = require(Components.HealthComponent)
local PlantTypeComponent = require(Components.PlantTypeComponent)
local ZombieTypeComponent = require(Components.ZombieTypeComponent)

local function EntityDeathSystem(world)
	-- Check all entities with health
	for id, health in world:query(HealthComponent) do
		if health.Current <= 0 then
			-- Entity is dead
			
			-- Check if it's a plant (need to clear grid)
			local plant = world:get(id, PlantTypeComponent)
			if plant then
				GridState.Clear(plant.Column, plant.Lane)
				Logger.Info("EntityDeath", `Plant {id} ({plant.PlantType}) died at ({plant.Column}, {plant.Lane})`)
			end
			
			-- Check if it's a zombie
			local zombie = world:get(id, ZombieTypeComponent)
			if zombie then
				Logger.Info("EntityDeath", `Zombie {id} ({zombie.ZombieType}) died in lane {zombie.Lane}`)
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

return {
	system = EntityDeathSystem,
	priority = 180,
}
