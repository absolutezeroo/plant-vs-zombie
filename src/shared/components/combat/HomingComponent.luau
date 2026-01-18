--!strict
--[[
	HomingComponent.luau - Homing projectile tracking
	
	Applied to projectiles that track and follow their target.
	Used by Cattail's homing thorns.
	
	Projectiles with this component will curve towards their target
	instead of traveling in a straight line.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type HomingComponent = {
	TargetEntity: number, -- Entity ID of the zombie being tracked
	TurnSpeed: number, -- How fast the projectile can turn (radians/second)
	MaxLifetime: number, -- Maximum lifetime before despawn (even if target alive)
	SpawnTime: number, -- When the projectile was spawned
}

return Matter.component("HomingComponent", {
	TargetEntity = 0,
	TurnSpeed = 5,
	MaxLifetime = 5,
	SpawnTime = 0,
})
