--!strict
--[[
	DeathEvent.lua - Ephemeral death event component
	
	Spawned when entity health reaches 0.
	VFXSystem reads for death animations, AudioSystem for death sounds.
	EventCleanupSystem despawns at Priority 400.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("DeathEvent", {
	Target = 0, -- Entity ID of dying entity
	EntityType = "", -- "Plant", "Zombie", "Projectile"
	PositionX = 0, -- Last known X position for VFX
	PositionY = 0, -- Last known Y position for VFX
	PositionZ = 0, -- Last known Z position for VFX
})
