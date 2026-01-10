--!strict
--[[
	ProjectileHitEvent.luau - Ephemeral event when projectile hits a zombie
	
	IMPORTANT: Events are ENTITIES, not attached to targets.
	Spawn with world:spawn(ProjectileHitEvent({...})) to create event entity.
	EventCleanupSystem despawns all events at Priority 400.
	
	Used by mutation systems to apply effects (Burn, Freeze, Chain, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type ProjectileHitEvent = {
	SourcePlant: number,     -- Entity ID of the plant that fired
	TargetZombie: number,    -- Entity ID of the zombie that was hit
	Damage: number,          -- Damage dealt by the projectile
	PositionX: number,       -- Impact position X
	PositionY: number,       -- Impact position Y
	PositionZ: number,       -- Impact position Z
	Lane: number,            -- Lane where the hit occurred (for optimized AoE lookups)
	WasKill: boolean,        -- True if this hit killed the zombie
}

return Matter.component("ProjectileHitEvent")
