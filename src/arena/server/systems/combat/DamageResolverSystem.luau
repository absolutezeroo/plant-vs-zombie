--!strict
--[[
	DamageResolverSystem.luau - Applies finalized damage to entities
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 175 (After damage modifiers, before entity death)
	
	PURPOSE:
	Processes all DamageIntent entities where ModifiersApplied == true
	and Resolved == false. Applies FinalAmount to target HealthComponent.
	
	Also handles:
	- Shell protection (redirects damage to Pumpkin)
	- Firing ServerEventBus.OnDamageDealt event
	- Spawning DamageEvent for VFX/Audio
	
	FLOW:
	1. CombatSystem spawns DamageIntent (P:170)
	2. DamageModifierSystem applies modifiers (P:172)
	3. THIS SYSTEM applies damage to Health (P:175)
	4. EntityDeathSystem handles death (P:180)
	
	LIFECYCLE:
	- Init(): N/A
	- OnStep(): Query DamageIntent, apply to Health
	- Dispose(): N/A
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.core.Logger)
local ECSUtils = require(Shared.utils.ecs.ECSUtils)

-- Server services
local Server = script.Parent.Parent.Parent
local ServerEventBus = require(Server.services.ServerEventBus)

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 175,
})

-- ============================================================
-- SECTION 3: STATE (all mutable data)
-- ============================================================
local State = {
	IsInitialized = false,
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

-- Get the actual damage target (handles shell protection)
local function getActualTarget(world: any, targetId: number): number
	if not world:contains(targetId) then
		return targetId
	end
	
	local shell = world:get(targetId, Components.ShellComponent)
	if shell and shell.ProtectedByShell then
		local shellEntity = shell.ProtectedByShell
		if world:contains(shellEntity) then
			-- Shell takes damage instead
			Logger.Debug("DamageResolverSystem", 
				`Redirecting damage from {targetId} to shell {shellEntity}`)
			return shellEntity
		end
	end
	
	return targetId
end

-- Apply damage to target
local function applyDamage(world: any, targetId: number, amount: number): (number, boolean)
	if not world:contains(targetId) then
		return 0, false
	end
	
	local health = world:get(targetId, Components.HealthComponent)
	if not health then
		return 0, false
	end
	
	-- Use ECSUtils for consistent damage application
	local actualDamage, isDead = ECSUtils.DamageEntity(world, targetId, amount, Components)
	
	return actualDamage, isDead
end

-- ============================================================
-- SECTION 5: LIFECYCLE: INIT
-- ============================================================
local function Init(_world)
	if State.IsInitialized then
		return
	end
	
	State.IsInitialized = true
	Logger.Debug("DamageResolverSystem", "Initialized")
end

-- ============================================================
-- SECTION 6: LIFECYCLE: DISPOSE
-- ============================================================
local function Dispose()
	State.IsInitialized = false
	Logger.Debug("DamageResolverSystem", "Disposed")
end

-- ============================================================
-- SECTION 7: ONSTEP (main ECS loop)
-- ============================================================
local function OnStep(world)
	-- Query all DamageIntent that have modifiers applied but not resolved
	for id, intent in world:query(Components.DamageIntent) do
		if intent.ModifiersApplied and not intent.Resolved then
			local targetId = intent.TargetId
			local sourceId = intent.SourceId
			local finalDamage = intent.FinalAmount
			
			-- Skip if damage is 0 (cancelled or fully absorbed)
			if finalDamage <= 0 then
				world:insert(id, Components.DamageIntent({
					TargetId = targetId,
					SourceId = sourceId,
					Amount = intent.Amount,
					FinalAmount = 0,
					DamageType = intent.DamageType,
					IsCritical = intent.IsCritical,
					Multiplier = intent.Multiplier,
					FlatBonus = intent.FlatBonus,
					SourcePlantType = intent.SourcePlantType,
					ModifiersApplied = true,
					Resolved = true,
				}))
				continue
			end
			
			-- Get actual target (may redirect to shell)
			local actualTarget = getActualTarget(world, targetId)
			
			-- Apply damage
			local actualDamage, wasKill = applyDamage(world, actualTarget, finalDamage)
			
			if actualDamage > 0 then
				-- Fire ServerEventBus event
				ServerEventBus.FireDamageDealt({
					SourceId = sourceId,
					TargetId = actualTarget,
					Amount = intent.Amount,
					FinalAmount = actualDamage,
					WasKill = wasKill,
					IsCritical = intent.IsCritical,
					DamageType = intent.DamageType,
				})
				
				-- Get position for DamageEvent
				local pos = world:get(actualTarget, Components.PositionComponent)
				local posX = if pos then pos.X else 0
				local posY = if pos then pos.Y else 0
				local posZ = if pos then pos.Z else 0
				
				-- Spawn DamageEvent for VFX/Audio systems
				world:spawn(Components.DamageEvent({
					Source = sourceId,
					Target = actualTarget,
					Amount = actualDamage,
					IsCritical = intent.IsCritical,
					PositionX = posX,
					PositionY = posY,
					PositionZ = posZ,
				}))
				
				if intent.IsCritical then
					Logger.Debug("DamageResolverSystem", 
						`💥 CRIT! {sourceId} dealt {actualDamage} damage to {actualTarget}`)
				end
			end
			
			-- Mark as resolved
			world:insert(id, Components.DamageIntent({
				TargetId = targetId,
				SourceId = sourceId,
				Amount = intent.Amount,
				FinalAmount = actualDamage,
				DamageType = intent.DamageType,
				IsCritical = intent.IsCritical,
				Multiplier = intent.Multiplier,
				FlatBonus = intent.FlatBonus,
				SourcePlantType = intent.SourcePlantType,
				ModifiersApplied = true,
				Resolved = true,
			}))
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
