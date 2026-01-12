--!strict
--[[
	DamageEvent.lua - Ephemeral damage event component
	
	IMPORTANT: Events are ENTITIES, not attached to targets.
	Spawn with world:spawn(DamageEvent({...})) to create event entity.
	EventCleanupSystem despawns all events at Priority 400.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("DamageEvent", {
	Target = 0, -- Entity ID of damaged entity
	Amount = 0, -- Damage value
	DamageType = "Normal", -- "Normal", "Ice", "Explosive"
	Source = 0, -- Entity ID of attacker (for VFX direction)
})
