--!strict
--[[
	Components Index - Central registry for all ECS components
	
	Domain-Driven Organization:
	├── core/       Core components (position, health, movement, ownership)
	├── combat/     Combat components (armed, projectile, slow, target)
	├── units/      Unit type components (plant, zombie, ghost)
	├── economy/    Economy components (sun, coin)
	├── events/     Event components (damage, death, spawn)
	
	Usage:
		local Components = require(Shared.components)
		local HealthComponent = Components.HealthComponent
		-- or
		local PositionComponent = require(Components.PositionComponent)
]]

local Components = script

-- Expose subfolders for direct access
local Core = Components.core
local Combat = Components.combat
local Units = Components.units
local Economy = Components.economy
local Events = Components.events

return {
	-- Core components
	GridPositionComponent = require(Core.GridPositionComponent),
	HealthComponent = require(Core.HealthComponent),
	MovementComponent = require(Core.MovementComponent),
	OwnerComponent = require(Core.OwnerComponent),
	PositionComponent = require(Core.PositionComponent),
	Tags = require(Core.Tags),
	
	-- Combat components
	ArmedComponent = require(Combat.ArmedComponent),
	ProjectileComponent = require(Combat.ProjectileComponent),
	SlowComponent = require(Combat.SlowComponent),
	TargetComponent = require(Combat.TargetComponent),
	
	-- Unit type components
	GhostComponent = require(Units.GhostComponent),
	PlantTypeComponent = require(Units.PlantTypeComponent),
	ZombieTypeComponent = require(Units.ZombieTypeComponent),
	
	-- Economy components
	CoinComponent = require(Economy.CoinComponent),
	SunComponent = require(Economy.SunComponent),
	
	-- Event components
	DamageEvent = require(Events.DamageEvent),
	DeathEvent = require(Events.DeathEvent),
	SpawnEvent = require(Events.SpawnEvent),
}
