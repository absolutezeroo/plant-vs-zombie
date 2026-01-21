--!strict
--[[
	EventCleanupSystem.luau - Cleans up ephemeral event entities
	
	Priority: 400 (Cleanup phase - LAST)
	
	Events in Matter ECS are entities with event components.
	This system removes all event entities at the end of each frame.
	"Events exist for exactly one frame"
	
	V3 Architecture: Matter Hooks pattern
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	-- List of all ephemeral event components to clean up each frame
	EVENT_COMPONENTS = {
		Components.DamageEvent,
		Components.DamageIntent,
		Components.DeathEvent,
		Components.SpawnEvent,
		Components.ProjectileHitEvent,
		Components.WaveStateEvent,
		Components.CoinDropEvent,
		Components.PlantActionEvent,
	},
})

-- 3. SYSTEM FUNCTION
local function EventCleanupSystem(world)
	-- Query for all event entities and despawn them
	-- Events only exist for one frame
	for _, eventComponent in CONFIG.EVENT_COMPONENTS do
		for entityId in world:query(eventComponent) do
			world:despawn(entityId)
		end
	end
end

-- 4. EXPORT
return {
	priority = 400,
	system = EventCleanupSystem,
}
