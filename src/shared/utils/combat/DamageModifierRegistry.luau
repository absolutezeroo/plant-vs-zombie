--!strict
--[[
	DamageModifierRegistry.luau - Registry for damage modifiers
	
	PURPOSE:
	Central registry for functions that modify damage in-flight.
	Each modifier can adjust the damage multiplier, add flat bonuses,
	or check conditions before damage is resolved.
	
	USAGE:
	```lua
	local DamageModifierRegistry = require(DamageModifierRegistry)
	
	-- Register a modifier (e.g., armor reduction)
	DamageModifierRegistry.Register("ArmorReduction", {
		Priority = 100, -- Lower priority runs first
		Callback = function(world, intent, Components)
			local target = intent.TargetId
			local reduction = world:get(target, Components.DamageReductionComponent)
			if reduction then
				return {
					Multiplier = intent.Multiplier * (1 - reduction.Reduction),
				}
			end
			return nil
		end,
	})
	
	-- Register a crit chance modifier
	DamageModifierRegistry.Register("RageCritical", {
		Priority = 200,
		Callback = function(world, intent, Components)
			local source = intent.SourceId
			local rage = world:get(source, Components.RageComponent)
			if rage and rage.CritChance > 0 then
				if math.random() < rage.CritChance then
					return { IsCritical = true, Multiplier = intent.Multiplier * 2 }
				end
			end
			return nil
		end,
	})
	```
	
	MODIFIER RETURN FORMAT:
	{
		Multiplier?: number,    -- New multiplier value (replaces, doesn't compound)
		FlatBonus?: number,     -- Flat damage to add
		IsCritical?: boolean,   -- Set critical flag
		Cancel?: boolean,       -- Completely cancel the damage
	}
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

-- ============================================
-- TYPE DEFINITIONS
-- ============================================

export type DamageIntentData = {
	TargetId: number,
	SourceId: number,
	Amount: number,
	FinalAmount: number,
	DamageType: string,
	IsCritical: boolean,
	Multiplier: number,
	FlatBonus: number,
	SourcePlantType: string,
	ModifiersApplied: boolean,
	Resolved: boolean,
}

export type ModifierResult = {
	Multiplier: number?,
	FlatBonus: number?,
	IsCritical: boolean?,
	Cancel: boolean?,
}

export type ModifierCallback = (world: any, intent: DamageIntentData, Components: any) -> ModifierResult?

export type ModifierConfig = {
	Priority: number, -- Lower runs first (0-1000)
	Callback: ModifierCallback,
	Description: string?, -- For debugging
	Enabled: boolean?, -- Can disable without unregistering
}

-- ============================================
-- STATE
-- ============================================

local _modifiers: { [string]: ModifierConfig } = {}
local _sortedModifiers: { { Name: string, Config: ModifierConfig } }? = nil -- Cached sorted list

-- ============================================
-- PRIVATE HELPERS
-- ============================================

-- Invalidate sorted cache when modifiers change
local function invalidateCache()
	_sortedModifiers = nil
end

-- Build sorted modifier list
local function getSortedModifiers(): { { Name: string, Config: ModifierConfig } }
	if _sortedModifiers then
		return _sortedModifiers
	end
	
	local sorted = {}
	for name, config in _modifiers do
		if config.Enabled ~= false then -- Default to enabled
			table.insert(sorted, { Name = name, Config = config })
		end
	end
	
	-- Sort by priority (ascending - lower runs first)
	table.sort(sorted, function(a, b)
		return a.Config.Priority < b.Config.Priority
	end)
	
	_sortedModifiers = sorted
	return sorted
end

-- ============================================
-- PUBLIC API
-- ============================================

local DamageModifierRegistry = {}

--[[
	Register a damage modifier.
	
	@param name string - Unique identifier for this modifier
	@param config ModifierConfig - Modifier configuration
	@return boolean - True if registered (false if name already exists)
]]
function DamageModifierRegistry.Register(name: string, config: ModifierConfig): boolean
	if _modifiers[name] then
		Logger.Warn("DamageModifierRegistry", `Modifier '{name}' already registered`)
		return false
	end
	
	if not config.Callback then
		Logger.Error("DamageModifierRegistry", `Modifier '{name}' missing Callback`)
		return false
	end
	
	if config.Priority == nil then
		config.Priority = 500 -- Default middle priority
	end
	
	if config.Enabled == nil then
		config.Enabled = true
	end
	
	_modifiers[name] = config
	invalidateCache()
	
	Logger.Debug("DamageModifierRegistry", `Registered modifier '{name}' (P:{config.Priority})`)
	return true
end

--[[
	Unregister a damage modifier.
	
	@param name string - Modifier identifier
	@return boolean - True if unregistered
]]
function DamageModifierRegistry.Unregister(name: string): boolean
	if not _modifiers[name] then
		return false
	end
	
	_modifiers[name] = nil
	invalidateCache()
	
	Logger.Debug("DamageModifierRegistry", `Unregistered modifier '{name}'`)
	return true
end

--[[
	Enable or disable a modifier without unregistering.
	
	@param name string - Modifier identifier
	@param enabled boolean - New enabled state
]]
function DamageModifierRegistry.SetEnabled(name: string, enabled: boolean)
	if _modifiers[name] then
		_modifiers[name].Enabled = enabled
		invalidateCache()
	end
end

--[[
	Apply all registered modifiers to a DamageIntent.
	Called by DamageModifierSystem.
	
	@param world any - ECS world
	@param intent DamageIntentData - The damage intent to modify
	@param Components table - Components module
	@return DamageIntentData - Modified intent (same table, mutated)
	@return boolean - True if damage should proceed (not cancelled)
]]
function DamageModifierRegistry.ApplyModifiers(
	world: any, 
	intent: DamageIntentData, 
	Components: any
): (DamageIntentData, boolean)
	local sorted = getSortedModifiers()
	
	for _, entry in sorted do
		local result = entry.Config.Callback(world, intent, Components)
		
		if result then
			-- Check for cancellation
			if result.Cancel then
				Logger.Debug("DamageModifierRegistry", 
					`Damage cancelled by modifier '{entry.Name}'`)
				return intent, false
			end
			
			-- Apply modifications
			if result.Multiplier ~= nil then
				intent.Multiplier = result.Multiplier
			end
			
			if result.FlatBonus ~= nil then
				intent.FlatBonus = intent.FlatBonus + result.FlatBonus
			end
			
			if result.IsCritical ~= nil then
				intent.IsCritical = result.IsCritical
			end
		end
	end
	
	-- Calculate final damage: (Amount * Multiplier) + FlatBonus
	intent.FinalAmount = math.floor(intent.Amount * intent.Multiplier + intent.FlatBonus)
	intent.FinalAmount = math.max(0, intent.FinalAmount) -- No negative damage
	intent.ModifiersApplied = true
	
	return intent, true
end

--[[
	Get all registered modifier names (for debugging).
	
	@return { string } - List of modifier names
]]
function DamageModifierRegistry.GetRegisteredModifiers(): { string }
	local names = {}
	for name in _modifiers do
		table.insert(names, name)
	end
	return names
end

--[[
	Get modifier count.
	
	@return number
]]
function DamageModifierRegistry.GetCount(): number
	local count = 0
	for _ in _modifiers do
		count += 1
	end
	return count
end

--[[
	Clear all registered modifiers (for testing or reset).
]]
function DamageModifierRegistry.ClearAll()
	table.clear(_modifiers)
	invalidateCache()
	Logger.Debug("DamageModifierRegistry", "All modifiers cleared")
end

return DamageModifierRegistry
