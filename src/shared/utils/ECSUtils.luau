--!strict
--[[
	ECSUtils.luau - Entity Component System utility functions
	
	Consolidates common ECS patterns to reduce code duplication:
	- Health manipulation (damage, heal, modify)
	- Entity type identification (IsPlant, IsZombie, IsAlive)
	- Status effect application with refresh strategies
	
	PHILOSOPHY:
	- Functions are pure helpers, they don't store state
	- All functions take world + components as parameters for decoupling
	- Uses Sift for immutable component updates
	
	USAGE:
	local ECSUtils = require(Shared.utils.ECSUtils)
	local died = ECSUtils.DamageEntity(world, zombieId, 50, Components)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sift = require(Packages:WaitForChild("Sift"))

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
	Apply damage to an entity
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param damage number - Damage amount (positive)
	@param Components ComponentRegistry - Component registry with HealthComponent
	@return (number, boolean) - (actualDamage, isDead)
]]
function ECSUtils.DamageEntity(
	world: any,
	entityId: number,
	damage: number,
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
	local actualDamage = math.min(damage, currentHealth)
	local newHealth = math.max(0, currentHealth - damage)
	
	world:insert(entityId, HealthComponent({
		Current = newHealth,
		Max = maxHealth,
	}))
	
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
function ECSUtils.HealEntity(
	world: any,
	entityId: number,
	healAmount: number,
	Components: ComponentRegistry
): number
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
		world:insert(entityId, HealthComponent({
			Current = newHealth,
			Max = maxHealth,
		}))
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
	
	world:insert(entityId, HealthComponent({
		Current = newHealth,
		Max = maxHealth,
	}))
	
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
	if not world:contains(entityId) then return end
	
	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then return end
	
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
	
	world:insert(entityId, HealthComponent({
		Current = newCurrent,
		Max = newMax,
	}))
end

--[[
	Instantly kill an entity by setting health to 0
	
	@param world any - Matter World instance
	@param entityId number - Target entity ID
	@param Components ComponentRegistry - Component registry with HealthComponent
	@return boolean - True if entity was killed (had health > 0)
]]
function ECSUtils.KillEntity(
	world: any,
	entityId: number,
	Components: ComponentRegistry
): boolean
	if not world:contains(entityId) then
		return false
	end
	
	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then
		return false
	end
	
	local wasAlive = (health.Current :: number) > 0
	
	world:insert(entityId, HealthComponent({
		Current = 0,
		Max = health.Max :: number,
	}))
	
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
function ECSUtils.BoostHealth(
	world: any,
	entityId: number,
	bonusHealth: number,
	Components: ComponentRegistry
): boolean
	if not world:contains(entityId) then
		return false
	end
	
	local HealthComponent = Components.HealthComponent
	local health = world:get(entityId, HealthComponent)
	if not health then
		return false
	end
	
	world:insert(entityId, HealthComponent({
		Current = (health.Current :: number) + bonusHealth,
		Max = (health.Max :: number) + bonusHealth,
	}))
	
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
function ECSUtils.ScaleHealth(
	world: any,
	entityId: number,
	multiplier: number,
	Components: ComponentRegistry
): boolean
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
	
	world:insert(entityId, HealthComponent({
		Current = newCurrent,
		Max = newMax,
	}))
	
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
	newData: {[string]: any},
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
function ECSUtils.GetOrDefault<T>(
	world: any,
	entityId: number,
	Component: any,
	defaultValue: T
): T
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
function ECSUtils.HasAllComponents(world: any, entityId: number, components: {any}): boolean
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
function ECSUtils.HasAnyComponent(world: any, entityId: number, components: {any}): boolean
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

return ECSUtils
