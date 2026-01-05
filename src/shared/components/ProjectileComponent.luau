--!strict
--[[
	ProjectileComponent.lua - Projectile entity data
	
	Projectiles travel from source plant toward target.
	Hit detection handled by ProjectileSystem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("ProjectileComponent", {
	Damage = 20,         -- Damage on hit
	Speed = 30,          -- Movement speed (studs/second)
	SourcePlant = 0,     -- Entity ID of firing plant
	DamageType = "Normal", -- "Normal", "Ice", "Explosive"
})
