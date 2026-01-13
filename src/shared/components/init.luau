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
local Mutations = Components.mutations

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
	ChewingComponent = require(Combat.ChewingComponent),
	EnhancedProjectileComponent = require(Combat.EnhancedProjectileComponent),
	HidingComponent = require(Combat.HidingComponent),
	PlantFoodComponent = require(Combat.PlantFoodComponent),
	ProjectileComponent = require(Combat.ProjectileComponent),
	SlowComponent = require(Combat.SlowComponent),
	SplashComponent = require(Combat.SplashComponent),
	StunComponent = require(Combat.StunComponent),
	TargetComponent = require(Combat.TargetComponent),

	-- Unit type components
	GhostComponent = require(Units.GhostComponent),
	JumpingComponent = require(Units.JumpingComponent),
	PlantTypeComponent = require(Units.PlantTypeComponent),
	ShieldComponent = require(Units.ShieldComponent),
	SleepingComponent = require(Units.SleepingComponent),
	VaultedComponent = require(Units.VaultedComponent),
	ZombieTypeComponent = require(Units.ZombieTypeComponent),

	-- Economy components
	CoinComponent = require(Economy.CoinComponent),
	SunComponent = require(Economy.SunComponent),

	-- Event components
	DamageEvent = require(Events.DamageEvent),
	DeathEvent = require(Events.DeathEvent),
	SpawnEvent = require(Events.SpawnEvent),
	ProjectileHitEvent = require(Events.ProjectileHitEvent),
	WaveStateEvent = require(Events.WaveStateEvent),
	CoinDropEvent = require(Events.CoinDropEvent),
	PlantActionEvent = require(Events.PlantActionEvent),

	-- Mutation components
	BurnEffectComponent = require(Mutations.BurnEffectComponent),
	BurningComponent = require(Mutations.BurningComponent),
	FreezeEffectComponent = require(Mutations.FreezeEffectComponent),
	FrozenComponent = require(Mutations.FrozenComponent),
	ChainLightningComponent = require(Mutations.ChainLightningComponent),
	PoisonCloudComponent = require(Mutations.PoisonCloudComponent),
	PoisonedComponent = require(Mutations.PoisonedComponent),
	LifestealComponent = require(Mutations.LifestealComponent),
	SunOnKillComponent = require(Mutations.SunOnKillComponent),
	DamageReductionComponent = require(Mutations.DamageReductionComponent),
	SplashDamageComponent = require(Mutations.SplashDamageComponent),
	MutationsComponent = require(Mutations.MutationsComponent),
}
