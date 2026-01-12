--!strict
--[[
	SpawnEvent.lua - Ephemeral spawn event component
	
	Used to notify presentation systems of entity creation.
	VFXSystem spawns visual model, AudioSystem plays spawn sound.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("SpawnEvent", {
	Target = 0, -- Entity ID of spawned entity
	EntityType = "", -- "Plant", "Zombie", "Projectile"
	PositionX = 0, -- Spawn X position for VFX
	PositionY = 0, -- Spawn Y position for VFX
	PositionZ = 0, -- Spawn Z position for VFX
})
