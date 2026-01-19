--!strict
--[[
	ECSUtils.luau - Entity Component System utility functions
	
	Consolidates common ECS patterns to reduce code duplication:
	- Health manipulation (damage, heal, modify)
	- Entity type identification (IsPlant, IsZombie, IsAlive)
	- Status effect application with refresh strategies
	- Zombie ability hooks integration
	
	PHILOSOPHY:
	- Functions are pure helpers, they don't store state
	- All functions take world + components as parameters for decoupling
	- Uses Sift for immutable component updates
	- Zombie hooks are executed on damage/kill for extensibility
	
	USAGE:
	local ECSUtils = require(Shared.utils.ecs.ECSUtils)
	local died = ECSUtils.DamageEntity(world, zombieId, 50, Components)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZombieAbilityData = require(Shared.data.ZombieAbilityData)

local ECSUtils = {}

-- Type definitions for better intellisense
export type ComponentRegistry = {
	HealthComponent: any,
	PlantTypeComponent: any,
	ZombieTypeComponent: any,
	[string]: any,
}

-- ============================================
-- Health Manipulation
-- ============================================

--[[
	Build ability context for zombie hooks
]]
local function buildZombieAbilityContext(
	world: any,
	entityId: number,
	zombieType: string,
	currentHealth: number,
	maxHealth: number,
	damageReceived: number?,
	damageSource: string?,
	killerEntityId: number?
): ZombieAbilityData.AbilityContext
	return {
		EntityId = entityId,
		World = world,
		ZombieType = zombieType,
		CurrentHealth = currentHealth,
		MaxHealth = maxHealth,
		DamageReceived = damageReceived,
		DamageSource = damageSource,
		KillerEntityId = killerEntityId,
	}
end

--[[
	Apply damage to an entity
	For zombies: executes OnDamaged and OnHalfHealth/OnQuarterHealth hooks
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param damage number - Damage amount (positive)
	@param Components ComponentRegistry - Component registry with HealthComponent
	@param damageSource string? - Optional damage source ("Projectile", "Explosion", etc.)
	@return (number, boolean) - (actualDamage, isDead)
]]
function ECSUtils.DamageEntity(
	world: any,
	entityId: number,
	damage: number,
	Components: ComponentRegistry,
	damageSource: string?
): (number, boolean)
	if not world:contains(entityId) then
		return 0, false
	end

	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then
		return 0, false
	end

	local currentHealth = health.Current :: number
	local maxHealth = health.Max :: number
	
	-- Check if this is a zombie and get type for ability hooks
	local zombieType: string? = nil
	local ZombieTypeComponent = Components.ZombieTypeComponent
	if ZombieTypeComponent then
		local zombie = world:get(entityId, ZombieTypeComponent)
		if zombie then
			zombieType = zombie.ZombieType
		end
	end
	
	-- Execute OnDamaged hook for zombies (can cancel damage)
	if zombieType then
		local ctx = buildZombieAbilityContext(
			world, entityId, zombieType,
			currentHealth, maxHealth,
			damage, damageSource, nil
		)
		local cancelled = ZombieAbilityData.ExecuteHook("OnDamaged", zombieType, ctx)
		if cancelled then
			return 0, false -- Damage was cancelled by ability
		end
	end
	
	local actualDamage = math.min(damage, currentHealth)
	local newHealth = math.max(0, currentHealth - damage)
	local previousHealthPercent = currentHealth / maxHealth
	local newHealthPercent = newHealth / maxHealth

	world:insert(
		entityId,
		HealthComponent({
			Current = newHealth,
			Max = maxHealth,
		})
	)
	
	-- Execute health threshold hooks for zombies
	if zombieType then
		local ctx = buildZombieAbilityContext(
			world, entityId, zombieType,
			newHealth, maxHealth,
			actualDamage, damageSource, nil
		)
		
		-- OnHalfHealth: triggered when crossing 50% threshold
		if previousHealthPercent > 0.5 and newHealthPercent <= 0.5 then
			ZombieAbilityData.ExecuteHook("OnHalfHealth", zombieType, ctx)
		end
		
		-- OnQuarterHealth: triggered when crossing 25% threshold
		if previousHealthPercent > 0.25 and newHealthPercent <= 0.25 then
			ZombieAbilityData.ExecuteHook("OnQuarterHealth", zombieType, ctx)
		end
	end

	return actualDamage, newHealth <= 0
end

--[[
	Heal an entity
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param healAmount number - Heal amount (positive)
	@param Components ComponentRegistry - Component registry with HealthComponent
	@return number - Actual amount healed
]]
function ECSUtils.HealEntity(world: any, entityId: number, healAmount: number, Components: ComponentRegistry): number
	if not world:contains(entityId) then
		return 0
	end

	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then
		return 0
	end

	local currentHealth = health.Current :: number
	local maxHealth = health.Max :: number
	local newHealth = math.min(maxHealth, currentHealth + healAmount)
	local actualHeal = newHealth - currentHealth

	if actualHeal > 0 then
		world:insert(
			entityId,
			HealthComponent({
				Current = newHealth,
				Max = maxHealth,
			})
		)
	end

	return actualHeal
end

--[[
	Modify health (can be positive or negative)
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param delta number - Health change (negative = damage, positive = heal)
	@param Components ComponentRegistry - Component registry with HealthComponent
	@return (number, boolean) - (newHealth, isDead)
]]
function ECSUtils.ModifyHealth(
	world: any,
	entityId: number,
	delta: number,
	Components: ComponentRegistry
): (number, boolean)
	if not world:contains(entityId) then
		return 0, false
	end

	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then
		return 0, false
	end

	local currentHealth = health.Current :: number
	local maxHealth = health.Max :: number
	local newHealth = math.clamp(currentHealth + delta, 0, maxHealth)

	world:insert(
		entityId,
		HealthComponent({
			Current = newHealth,
			Max = maxHealth,
		})
	)

	return newHealth, newHealth <= 0
end

--[[
	Set max health (and optionally adjust current proportionally)
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param newMax number - New max health value
	@param adjustCurrent boolean? - If true, scale current health proportionally
	@param Components ComponentRegistry - Component registry
]]
function ECSUtils.SetMaxHealth(
	world: any,
	entityId: number,
	newMax: number,
	adjustCurrent: boolean?,
	Components: ComponentRegistry
)
	if not world:contains(entityId) then
		return
	end

	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then
		return
	end

	local currentHealth = health.Current :: number
	local oldMax = health.Max :: number

	local newCurrent = currentHealth
	if adjustCurrent and oldMax > 0 then
		-- Scale current health proportionally
		newCurrent = math.floor(currentHealth * (newMax / oldMax))
	else
		-- Cap current at new max
		newCurrent = math.min(currentHealth, newMax)
	end

	world:insert(
		entityId,
		HealthComponent({
			Current = newCurrent,
			Max = newMax,
		})
	)
end

--[[
	Instantly kill an entity by setting health to 0
	For zombies: executes OnDeath hook (can trigger explosions, minion spawns, etc.)
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param Components ComponentRegistry - Component registry with HealthComponent
	@param killerEntityId number? - Optional entity that caused the kill
	@return boolean - True if entity was killed (had health > 0)
]]
function ECSUtils.KillEntity(
	world: any,
	entityId: number,
	Components: ComponentRegistry,
	killerEntityId: number?
): boolean
	if not world:contains(entityId) then
		return false
	end

	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then
		return false
	end

	local currentHealth = health.Current :: number
	local maxHealth = health.Max :: number
	local wasAlive = currentHealth > 0
	
	-- Check if this is a zombie for ability hooks
	local zombieType: string? = nil
	local ZombieTypeComponent = Components.ZombieTypeComponent
	if ZombieTypeComponent then
		local zombie = world:get(entityId, ZombieTypeComponent)
		if zombie then
			zombieType = zombie.ZombieType
		end
	end
	
	-- Check for InstantKill immunity (bosses)
	if zombieType and ZombieAbilityData.HasImmunity(zombieType, "InstantKill") then
		-- Boss is immune to instant kill - deal massive damage instead
		-- This allows abilities like Chomper to still hurt bosses
		return false
	end

	world:insert(
		entityId,
		HealthComponent({
			Current = 0,
			Max = maxHealth,
		})
	)
	
	-- Execute OnDeath hook for zombies
	if zombieType and wasAlive then
		local ctx = buildZombieAbilityContext(
			world, entityId, zombieType,
			0, maxHealth,
			currentHealth, "InstantKill", killerEntityId
		)
		ZombieAbilityData.ExecuteHook("OnDeath", zombieType, ctx)
	end

	return wasAlive
end

--[[
	Add or modify health (boost max and current together)
	Used for armor/health upgrades that increase both values
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param bonusHealth number - Amount to add to both current and max
	@param Components ComponentRegistry - Component registry with HealthComponent
	@return boolean - True if health was modified
]]
function ECSUtils.BoostHealth(world: any, entityId: number, bonusHealth: number, Components: ComponentRegistry): boolean
	if not world:contains(entityId) then
		return false
	end

	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then
		return false
	end

	world:insert(
		entityId,
		HealthComponent({
			Current = (health.Current :: number) + bonusHealth,
			Max = (health.Max :: number) + bonusHealth,
		})
	)

	return true
end

--[[
	Scale health by a multiplier (for mutations/buffs)
	Scales both current and max health proportionally
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param multiplier number - Health multiplier (e.g., 1.5 = 50% more)
	@param Components ComponentRegistry - Component registry with HealthComponent
	@return boolean - True if health was modified
]]
function ECSUtils.ScaleHealth(world: any, entityId: number, multiplier: number, Components: ComponentRegistry): boolean
	if not world:contains(entityId) then
		return false
	end

	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then
		return false
	end

	local newMax = math.floor((health.Max :: number) * multiplier)
	local newCurrent = math.floor((health.Current :: number) * multiplier)

	world:insert(
		entityId,
		HealthComponent({
			Current = newCurrent,
			Max = newMax,
		})
	)

	return true
end

-- ============================================
-- Entity Type Identification
-- ============================================

--[[
	Check if an entity is a plant
	
	@param world any - Matter World instance
	@param entityId number - Entity ID to check
	@param Components ComponentRegistry - Component registry
	@return boolean
]]
function ECSUtils.IsPlant(world: any, entityId: number, Components: ComponentRegistry): boolean
	if not world:contains(entityId) then
		return false
	end
	return world:get(entityId, Components.PlantTypeComponent) ~= nil
end

--[[
	Check if an entity is a zombie
	
	@param world any - Matter World instance
	@param entityId number - Entity ID to check
	@param Components ComponentRegistry - Component registry
	@return boolean
]]
function ECSUtils.IsZombie(world: any, entityId: number, Components: ComponentRegistry): boolean
	if not world:contains(entityId) then
		return false
	end
	return world:get(entityId, Components.ZombieTypeComponent) ~= nil
end

--[[
	Check if an entity is alive (has HealthComponent with Current > 0)
	
	@param world any - Matter World instance
	@param entityId number - Entity ID to check
	@param Components ComponentRegistry - Component registry
	@return boolean
]]
function ECSUtils.IsAlive(world: any, entityId: number, Components: ComponentRegistry): boolean
	if not world:contains(entityId) then
		return false
	end

	local health = world:get(entityId, Components.HealthComponent)
	if not health then
		return true -- Entities without health are considered "alive"
	end

	return (health.Current :: number) > 0
end

--[[
	Check if an entity exists in the world
	
	@param world any - Matter World instance
	@param entityId number - Entity ID to check
	@return boolean
]]
function ECSUtils.Exists(world: any, entityId: number): boolean
	return world:contains(entityId)
end

-- ============================================
-- Safe Component Access
-- ============================================

--[[
	Safely get a component from an entity
	
	Consolidates the common pattern:
	  if world:contains(id) then return world:get(id, Component) end
	
	@param world any - Matter World instance
	@param entityId number - Entity ID
	@param component any - Component type to get
	@return any? - Component data or nil if entity doesn't exist
]]
function ECSUtils.SafeGet(world: any, entityId: number, component: any): any?
	if not entityId or not world:contains(entityId) then
		return nil
	end
	return world:get(entityId, component)
end

--[[
	Safely get multiple components from an entity
	
	@param world any - Matter World instance
	@param entityId number - Entity ID
	@param ... any - Component types to get
	@return ...any? - Component data or nil values
]]
function ECSUtils.SafeGetMultiple(world: any, entityId: number, ...: any): ...any
	if not entityId or not world:contains(entityId) then
		return nil
	end
	return world:get(entityId, ...)
end

--[[
	Check if entity has a component
	
	@param world any - Matter World instance
	@param entityId number - Entity ID
	@param component any - Component type to check
	@return boolean - True if entity exists and has the component
]]
function ECSUtils.HasComponent(world: any, entityId: number, component: any): boolean
	if not entityId or not world:contains(entityId) then
		return false
	end
	return world:get(entityId, component) ~= nil
end

-- ============================================
-- Status Effect Application
-- ============================================

export type RefreshStrategy = "Longest" | "Strongest" | "Replace" | "Stack"

--[[
	Apply or refresh a status effect component
	
	Strategies:
	- "Longest": Keep the longer duration
	- "Strongest": Keep the stronger effect (compares first numeric field)
	- "Replace": Always replace with new effect
	- "Stack": Add durations together
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param Component any - Component type to apply
	@param newData table - New component data
	@param strategy RefreshStrategy - How to handle existing effect
	@param durationField string? - Field name for duration (default: "RemainingDuration")
	@param strengthField string? - Field name for strength comparison (default: first numeric field)
	@return boolean - True if effect was applied/refreshed
]]
function ECSUtils.ApplyOrRefreshEffect(
	world: any,
	entityId: number,
	Component: any,
	newData: { [string]: any },
	strategy: RefreshStrategy?,
	durationField: string?,
	strengthField: string?
): boolean
	if not world:contains(entityId) then
		return false
	end

	local strat = strategy or "Longest"
	local durField = durationField or "RemainingDuration"

	local existing = world:get(entityId, Component)

	if not existing then
		-- No existing effect, apply new one
		world:insert(entityId, Component(newData))
		return true
	end

	-- Handle based on strategy
	if strat == "Replace" then
		world:insert(entityId, Component(newData))
		return true
	elseif strat == "Longest" then
		local existingDuration = existing[durField] or 0
		local newDuration = newData[durField] or 0

		if newDuration > existingDuration then
			world:insert(entityId, Component(newData))
		else
			-- Keep existing but refresh timestamp if present
			local merged = Sift.Dictionary.merge(existing, {
				AppliedAt = newData.AppliedAt or existing.AppliedAt,
			})
			world:insert(entityId, Component(merged))
		end
		return true
	elseif strat == "Strongest" then
		-- Find strength field (first numeric field if not specified)
		local strField = strengthField
		if not strField then
			for key, value in newData do
				if type(value) == "number" and key ~= durField and key ~= "AppliedAt" then
					strField = key
					break
				end
			end
		end

		if strField then
			local existingStrength = existing[strField] or 0
			local newStrength = newData[strField] or 0

			if newStrength >= existingStrength then
				-- Use stronger effect with max duration
				local merged = Sift.Dictionary.merge(newData, {
					[durField] = math.max(existing[durField] or 0, newData[durField] or 0),
				})
				world:insert(entityId, Component(merged))
			end
		else
			world:insert(entityId, Component(newData))
		end
		return true
	elseif strat == "Stack" then
		local existingDuration = existing[durField] or 0
		local newDuration = newData[durField] or 0

		local merged = Sift.Dictionary.merge(newData, {
			[durField] = existingDuration + newDuration,
		})
		world:insert(entityId, Component(merged))
		return true
	end

	return false
end

-- ============================================
-- Component Helpers
-- ============================================

--[[
	Safely get a component value, returning a default if not found
	
	@param world any - Matter World instance
	@param entityId number - Entity ID
	@param Component any - Component type
	@param defaultValue T - Default value if not found
	@return T
]]
function ECSUtils.GetOrDefault<T>(world: any, entityId: number, Component: any, defaultValue: T): T
	if not world:contains(entityId) then
		return defaultValue
	end

	local component = world:get(entityId, Component)
	return if component then component else defaultValue
end

--[[
	Check if entity has all specified components
	
	@param world any - Matter World instance
	@param entityId number - Entity ID
	@param components {any} - Array of component types
	@return boolean
]]
function ECSUtils.HasAllComponents(world: any, entityId: number, components: { any }): boolean
	if not world:contains(entityId) then
		return false
	end

	for _, Component in components do
		if not world:get(entityId, Component) then
			return false
		end
	end

	return true
end

--[[
	Check if entity has any of the specified components
	
	@param world any - Matter World instance
	@param entityId number - Entity ID
	@param components {any} - Array of component types
	@return boolean
]]
function ECSUtils.HasAnyComponent(world: any, entityId: number, components: { any }): boolean
	if not world:contains(entityId) then
		return false
	end

	for _, Component in components do
		if world:get(entityId, Component) then
			return true
		end
	end

	return false
end

-- ============================================
-- Damage Intent System (In-Flight Modification)
-- ============================================

--[[
	Spawn a DamageIntent entity for in-flight damage modification.
	
	Use this instead of direct DamageEntity() when you want:
	- Damage modifiers (armor, rage, vulnerability) to apply
	- ServerEventBus.OnDamageDealt to fire with full context
	- Critical hit calculations
	
	The DamageIntent will be processed by:
	1. DamageModifierSystem (P:172) - applies modifiers
	2. DamageResolverSystem (P:175) - applies to health
	3. EventCleanupSystem (P:400) - cleans up
	
	@param world any - Matter World instance
	@param sourceId number - Entity dealing the damage
	@param targetId number - Entity receiving the damage
	@param amount number - Base damage amount
	@param Components ComponentRegistry - Component registry
	@param options table? - Optional configuration
		- DamageType: string ("Normal", "Fire", "Ice", "Poison", etc.)
		- SourcePlantType: string (for tracking)
	@return number - DamageIntent entity ID
]]
function ECSUtils.SpawnDamageIntent(
	world: any,
	sourceId: number,
	targetId: number,
	amount: number,
	Components: ComponentRegistry,
	options: { DamageType: string?, SourcePlantType: string? }?
): number
	local DamageIntent = Components.DamageIntent
	if not DamageIntent then
		-- Fallback: direct damage if DamageIntent not available
		ECSUtils.DamageEntity(world, targetId, amount, Components)
		return 0
	end
	
	local opts = options or {}
	
	local intentId = world:spawn(DamageIntent({
		TargetId = targetId,
		SourceId = sourceId,
		Amount = amount,
		FinalAmount = amount, -- Will be recalculated by DamageModifierSystem
		DamageType = opts.DamageType or "Normal",
		IsCritical = false, -- Will be set by modifiers
		Multiplier = 1.0,
		FlatBonus = 0,
		SourcePlantType = opts.SourcePlantType or "",
		ModifiersApplied = false,
		Resolved = false,
	}))
	
	return intentId
end

--[[
	Spawn multiple DamageIntent entities for splash damage.
	
	@param world any - Matter World instance
	@param sourceId number - Entity dealing the damage
	@param targets {number} - Array of target entity IDs
	@param amount number - Base damage amount per target
	@param Components ComponentRegistry - Component registry
	@param options table? - Optional configuration
	@return {number} - Array of DamageIntent entity IDs
]]
function ECSUtils.SpawnSplashDamageIntent(
	world: any,
	sourceId: number,
	targets: { number },
	amount: number,
	Components: ComponentRegistry,
	options: { DamageType: string?, SourcePlantType: string? }?
): { number }
	local intentIds = {}
	
	for _, targetId in targets do
		local intentId = ECSUtils.SpawnDamageIntent(
			world, sourceId, targetId, amount, Components, options
		)
		if intentId > 0 then
			table.insert(intentIds, intentId)
		end
	end
	
	return intentIds
end

return ECSUtils
