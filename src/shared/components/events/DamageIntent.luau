--!strict
--[[
	DamageIntent.luau - Ephemeral damage intent component for in-flight modification
	
	PURPOSE:
	Represents INTENT to deal damage, created before damage is actually applied.
	This enables modifiers to intercept and modify damage values before resolution.
	
	FLOW:
	1. CombatSystem spawns DamageIntent (instead of directly modifying HealthComponent)
	2. DamageModifierSystem (P:172) reads DamageIntent, applies registered modifiers
	3. DamageResolverSystem (P:175) applies final damage to HealthComponent
	4. EventCleanupSystem (P:400) despawns DamageIntent
	
	MODIFIABLE FIELDS:
	- Amount: Base damage (can be multiplied/reduced by modifiers)
	- IsCritical: Can be set true by crit-chance modifiers
	- DamageType: Can influence resistances (Fire, Ice, Poison, etc.)
	
	READ-ONLY CONTEXT:
	- SourceId: Who dealt the damage (for attribution)
	- TargetId: Who receives the damage
	- SourcePlantType: For tracking/analytics
	
	EXAMPLE MODIFIERS:
	- Armor: DamageReductionComponent reduces Amount
	- Vulnerability: MarkComponent increases Amount
	- Critical Hit: RageComponent may set IsCritical
	- Type Resistance: Ice zombies reduce Fire damage
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("DamageIntent", {
	-- Target entity receiving damage
	TargetId = 0,
	
	-- Source entity dealing damage (for attribution)
	SourceId = 0,
	
	-- Base damage amount (modifiable)
	Amount = 0,
	
	-- Final damage after modifiers (set by DamageModifierSystem)
	FinalAmount = 0,
	
	-- Damage type for resistance calculations
	DamageType = "Normal", -- "Normal", "Fire", "Ice", "Poison", "Explosion", "Lightning"
	
	-- Whether this is a critical hit
	IsCritical = false,
	
	-- Multiplier from modifiers (starts at 1.0)
	Multiplier = 1.0,
	
	-- Flat damage bonus from modifiers (added after multiplier)
	FlatBonus = 0,
	
	-- Source plant type (for tracking/analytics)
	SourcePlantType = "",
	
	-- Whether modifiers have been applied (set by DamageModifierSystem)
	ModifiersApplied = false,
	
	-- Whether damage has been resolved (set by DamageResolverSystem)
	Resolved = false,
})
