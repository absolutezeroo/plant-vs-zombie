--!strict
--[[
	DamageModifierSystem.luau - Applies registered damage modifiers
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 172 (After combat detection, before damage resolution)
	
	PURPOSE:
	Processes all DamageIntent entities where ModifiersApplied == false.
	Runs each intent through DamageModifierRegistry to apply:
	- Damage reduction (armor, shields)
	- Damage amplification (vulnerability, rage)
	- Critical hits
	- Damage type resistances
	
	FLOW:
	1. CombatSystem spawns DamageIntent (P:170)
	2. THIS SYSTEM applies modifiers (P:172)
	3. DamageResolverSystem applies to Health (P:175)
	
	LIFECYCLE:
	- Init(): Register built-in modifiers from ECS components
	- OnStep(): Query DamageIntent, apply registry modifiers
	- Dispose(): Clear built-in modifier registrations
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.core.Logger)
local DamageModifierRegistry = require(Shared.utils.combat.DamageModifierRegistry)

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 172,
})

-- ============================================================
-- SECTION 3: STATE (all mutable data)
-- ============================================================
local State = {
	IsInitialized = false,
}

-- ============================================================
-- SECTION 4: BUILT-IN MODIFIERS
-- These modifiers read ECS components to modify damage
-- ============================================================

-- Damage Reduction from DamageReductionComponent (armor, shields)
local function damageReductionModifier(world: any, intent: any, _Components: any): any?
	local target = intent.TargetId
	if not world:contains(target) then
		return nil
	end
	
	local reduction = world:get(target, Components.DamageReductionComponent)
	if reduction and reduction.Reduction > 0 then
		-- Reduction is a percentage (0.0 to 1.0)
		local newMultiplier = intent.Multiplier * (1 - reduction.Reduction)
		Logger.Debug("DamageModifierSystem", 
			`Armor reduced damage by {reduction.Reduction * 100}% for entity {target}`)
		return { Multiplier = newMultiplier }
	end
	
	return nil
end

-- Rage Component critical hits
local function rageCriticalModifier(world: any, intent: any, _Components: any): any?
	local source = intent.SourceId
	if not world:contains(source) then
		return nil
	end
	
	local rage = world:get(source, Components.RageComponent)
	if rage then
		-- Rage grants crit chance and damage boost
		if rage.CritChance and rage.CritChance > 0 then
			if math.random() < rage.CritChance then
				local critMultiplier = rage.CritMultiplier or 2.0
				Logger.Debug("DamageModifierSystem", 
					`CRITICAL HIT from entity {source}! Damage x{critMultiplier}`)
				return { 
					IsCritical = true, 
					Multiplier = intent.Multiplier * critMultiplier,
				}
			end
		end
		
		-- Rage bonus damage even without crit
		if rage.DamageBoost and rage.DamageBoost > 0 then
			return {
				Multiplier = intent.Multiplier * (1 + rage.DamageBoost),
			}
		end
	end
	
	return nil
end

-- Shell/Pumpkin protection - damage goes to shell first
local function shellProtectionModifier(world: any, intent: any, _Components: any): any?
	local target = intent.TargetId
	if not world:contains(target) then
		return nil
	end
	
	local shell = world:get(target, Components.ShellComponent)
	if shell and shell.ProtectedByShell then
		-- If protected by a shell, the shell takes damage instead
		local shellEntity = shell.ProtectedByShell
		if world:contains(shellEntity) then
			-- Note: We don't modify here, just log
			-- The actual redirection happens in DamageResolverSystem
			Logger.Debug("DamageModifierSystem", 
				`Entity {target} is protected by shell {shellEntity}`)
		end
	end
	
	return nil
end

-- Frozen zombies take more damage from certain types
local function frozenVulnerabilityModifier(world: any, intent: any, _Components: any): any?
	local target = intent.TargetId
	if not world:contains(target) then
		return nil
	end
	
	local frozen = world:get(target, Components.FrozenComponent)
	if frozen then
		-- Frozen targets are vulnerable (25% more damage)
		return { Multiplier = intent.Multiplier * 1.25 }
	end
	
	return nil
end

-- ============================================================
-- SECTION 5: LIFECYCLE: INIT
-- ============================================================
local function Init(_world)
	if State.IsInitialized then
		return
	end
	
	-- Register built-in modifiers
	DamageModifierRegistry.Register("BuiltIn:DamageReduction", {
		Priority = 100, -- Early - armor applies first
		Callback = damageReductionModifier,
		Description = "Applies DamageReductionComponent armor",
	})
	
	DamageModifierRegistry.Register("BuiltIn:ShellProtection", {
		Priority = 150, -- After armor
		Callback = shellProtectionModifier,
		Description = "Logs shell/pumpkin protection",
	})
	
	DamageModifierRegistry.Register("BuiltIn:FrozenVulnerability", {
		Priority = 200, -- After shields
		Callback = frozenVulnerabilityModifier,
		Description = "Frozen targets take 25% more damage",
	})
	
	DamageModifierRegistry.Register("BuiltIn:RageCritical", {
		Priority = 300, -- After vulnerabilities
		Callback = rageCriticalModifier,
		Description = "RageComponent crit chance and damage boost",
	})
	
	State.IsInitialized = true
	Logger.Debug("DamageModifierSystem", 
		`Initialized with {DamageModifierRegistry.GetCount()} modifiers`)
end

-- ============================================================
-- SECTION 6: LIFECYCLE: DISPOSE
-- ============================================================
local function Dispose()
	-- Unregister built-in modifiers
	DamageModifierRegistry.Unregister("BuiltIn:DamageReduction")
	DamageModifierRegistry.Unregister("BuiltIn:ShellProtection")
	DamageModifierRegistry.Unregister("BuiltIn:FrozenVulnerability")
	DamageModifierRegistry.Unregister("BuiltIn:RageCritical")
	
	State.IsInitialized = false
	Logger.Debug("DamageModifierSystem", "Disposed")
end

-- ============================================================
-- SECTION 7: ONSTEP (main ECS loop)
-- ============================================================
local function OnStep(world)
	-- Query all DamageIntent that haven't had modifiers applied
	for id, intent in world:query(Components.DamageIntent) do
		if not intent.ModifiersApplied and not intent.Resolved then
			-- Build intent data for registry
			local intentData = {
				TargetId = intent.TargetId,
				SourceId = intent.SourceId,
				Amount = intent.Amount,
				FinalAmount = intent.FinalAmount,
				DamageType = intent.DamageType,
				IsCritical = intent.IsCritical,
				Multiplier = intent.Multiplier,
				FlatBonus = intent.FlatBonus,
				SourcePlantType = intent.SourcePlantType,
				ModifiersApplied = intent.ModifiersApplied,
				Resolved = intent.Resolved,
			}
			
			-- Apply all registered modifiers
			local modifiedIntent, shouldProceed = DamageModifierRegistry.ApplyModifiers(
				world, intentData, Components
			)
			
			if shouldProceed then
				-- Update the component with modified values
				world:insert(id, Components.DamageIntent({
					TargetId = intent.TargetId,
					SourceId = intent.SourceId,
					Amount = intent.Amount,
					FinalAmount = modifiedIntent.FinalAmount,
					DamageType = intent.DamageType,
					IsCritical = modifiedIntent.IsCritical,
					Multiplier = modifiedIntent.Multiplier,
					FlatBonus = modifiedIntent.FlatBonus,
					SourcePlantType = intent.SourcePlantType,
					ModifiersApplied = true,
					Resolved = false,
				}))
			else
				-- Damage was cancelled, mark as resolved (will be cleaned up)
				world:insert(id, Components.DamageIntent({
					TargetId = intent.TargetId,
					SourceId = intent.SourceId,
					Amount = intent.Amount,
					FinalAmount = 0,
					DamageType = intent.DamageType,
					IsCritical = false,
					Multiplier = 0,
					FlatBonus = 0,
					SourcePlantType = intent.SourcePlantType,
					ModifiersApplied = true,
					Resolved = true, -- Skip resolution
				}))
			end
		end
	end
end

-- ============================================================
-- SECTION 8: EXPORT
-- ============================================================
return {
	priority = CONFIG.PRIORITY,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
