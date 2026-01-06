--!strict
--[[
	ProjectileComponent.luau - Projectile entity data
	
	Projectiles travel from source plant toward target.
	Hit detection handled by CombatSystem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type ProjectileComponent = {
	Damage: number,         -- Damage on hit
	Speed: number,          -- Movement speed (studs/second)
	SourceEntity: number,   -- Entity ID of firing plant
	Lane: number,           -- Lane the projectile travels in
	SpawnX: number,         -- X position when spawned (for max range check)
	IsFrozen: boolean?,     -- True for SnowPea projectiles (applies slow)
	SlowPercent: number?,   -- Slow amount (0.5 = 50% slower)
	SlowDuration: number?,  -- How long the slow lasts
}

return Matter.component("Projectile")
