--!strict
--[[
	Event Cleanup System - Cleans up ephemeral event entities
	
	Priority: 400 (Cleanup phase)
	
	Events in Matter ECS are entities with event components.
	This system removes all event entities at the end of each frame.
	"Events exist for exactly one frame"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Import event components
local DamageEvent = require(Shared.components.events.DamageEvent)
local DeathEvent = require(Shared.components.events.DeathEvent)
local SpawnEvent = require(Shared.components.events.SpawnEvent)

local function EventCleanupSystem(world)
	-- Query for all event entities and despawn them
	-- Events only exist for one frame
	
	-- Clean DamageEvents
	for entityId in world:query(DamageEvent) do
		world:despawn(entityId)
	end
	
	-- Clean DeathEvents
	for entityId in world:query(DeathEvent) do
		world:despawn(entityId)
	end
	
	-- Clean SpawnEvents
	for entityId in world:query(SpawnEvent) do
		world:despawn(entityId)
	end
end

return {
	system = EventCleanupSystem,
	priority = 400,  -- Cleanup phase
}
