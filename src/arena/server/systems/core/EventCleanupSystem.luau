--!strict
--[[
	EventCleanupSystem.luau - Cleans up ephemeral event entities
	
	Priority: 400 (Cleanup phase - LAST)
	
	Events in Matter ECS are entities with event components.
	This system removes all event entities at the end of each frame.
	"Events exist for exactly one frame"
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
		Components.DeathEvent,
		Components.SpawnEvent,
		Components.ProjectileHitEvent,
		Components.WaveStateEvent,
		Components.CoinDropEvent,
		Components.PlantActionEvent,
	},
})

-- 3. STATE (minimal - this system is stateless)
local State = {
	IsInitialized = false,
}

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end
	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	State.IsInitialized = false
end

-- 6. MAIN LOOP
local function OnStep(world)
	-- Query for all event entities and despawn them
	-- Events only exist for one frame
	for _, eventComponent in CONFIG.EVENT_COMPONENTS do
		for entityId in world:query(eventComponent) do
			world:despawn(entityId)
		end
	end
end

-- 7. EXPORT
return {
	priority = 400,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
