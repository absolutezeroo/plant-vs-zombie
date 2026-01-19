--!strict
--[[
	DeathExplosionEvent.luau - Ephemeral explosion on death event
	
	Applied when a zombie should explode on death (e.g., Jack-in-the-Box).
	Combat system processes this to deal area damage to plants.
	
	Processed by: DeathExplosionSystem or SpecialPlantSystem
	Cleanup: EventCleanupSystem at Priority 400
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("DeathExplosionEvent", {
	Radius = 3, -- Explosion radius in studs
	Damage = 100, -- Damage to deal
	DamagesPlants = true, -- Whether this damages plants (true) or zombies (false)
	TriggerTime = 0, -- When explosion was triggered (os.clock())
	Processed = false, -- Set to true after explosion is handled
})
