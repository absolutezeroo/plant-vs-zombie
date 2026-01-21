--!strict
--[[
	MutationApplySystem.luau - Applies mutations to newly spawned plants
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 205 (Right after PlacementSystem at 200)
	
	Watches for new plants and applies mutation components based on
	the player's purchased mutations for that plant type.
	
	This system runs once per plant spawn and adds the appropriate
	mutation effect components (BurnEffect, ChainLightning, etc.)
	
	Uses MatterHooks.useAsync for non-blocking mutation loading operations.
	
	LIFECYCLE:
	- Init(): No init needed
	- OnStep(): Main loop (CANNOT yield) - applies mutations to new plants
	- Dispose(): No cleanup needed (MutationService handles cache)
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages:WaitForChild("MatterHooks"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local MutationData = require(Shared.data.MutationData)
local Logger = require(Shared.utils.core.Logger)
local ECSUtils = require(Shared.utils.ecs.ECSUtils)

-- Server services
local Server = script.Parent.Parent.Parent
local MutationService = require(Server.services.MutationService)

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 205, -- Right after PlacementSystem (200)
})

-- ============================================================
-- SECTION 3: STATE (all mutable data)
-- ============================================================
-- No mutable state needed - MutationService handles cache
-- Hook state is managed by MatterHooks internally

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

-- Load mutations for a plant (wrapped for useAsync)
local function loadMutationsForPlant(userId: number, plantType: string): { string }
	-- Currently synchronous, but useAsync allows this to become async in future
	return MutationService.GetPlantMutations(userId, plantType)
end

-- Apply mutation components to a plant entity
local function applyMutationsToPlant(world, entityId: number, plantType: string, mutationIds: { string }, userId: number)
	-- Always add MutationsComponent to mark entity as processed
	world:insert(
		entityId,
		Components.MutationsComponent({
			MutationIds = mutationIds,
			OwnerId = userId,
		})
	)

	if #mutationIds == 0 then
		return
	end

	-- Get combined effects
	local effects = MutationData.CalculateCombinedEffects(mutationIds)

	-- Apply effect components based on mutations

	-- Fire: Burn on hit
	if effects.AddsBurnDamage then
		world:insert(
			entityId,
			Components.BurnEffectComponent({
				DamagePerSecond = effects.BurnDamagePerSecond or 5,
				Duration = effects.BurnDuration or 3,
			})
		)
		Logger.Debug("MutationApplySystem", `Applied BurnEffect to entity {entityId}`)
	end

	-- Ice: Freeze on hit
	if effects.AddsFreeze then
		world:insert(
			entityId,
			Components.FreezeEffectComponent({
				FreezeChance = effects.FreezeChance or 0.2,
				FreezeDuration = effects.FreezeDuration or 2,
				EnhancedSlow = effects.EnhancedSlow,
			})
		)
		Logger.Debug("MutationApplySystem", `Applied FreezeEffect to entity {entityId}`)
	end

	-- Electric: Chain lightning
	if effects.AddsChainLightning then
		world:insert(
			entityId,
			Components.ChainLightningComponent({
				ChainCount = effects.ChainCount or 2,
				ChainDamage = effects.ChainDamage or 0.5,
				ChainRange = effects.ChainRange or 8,
			})
		)
		Logger.Debug("MutationApplySystem", `Applied ChainLightning to entity {entityId}`)
	end

	-- Toxic: Poison cloud on death
	if effects.AddsPoisonCloud then
		world:insert(
			entityId,
			Components.PoisonCloudComponent({
				Radius = effects.PoisonRadius or 6,
				DamagePerSecond = effects.PoisonDamagePerSecond or 3,
				Duration = effects.PoisonDuration or 4,
			})
		)
		Logger.Debug("MutationApplySystem", `Applied PoisonCloud to entity {entityId}`)
	end

	-- Shadow: Lifesteal
	if effects.AddsLifesteal then
		world:insert(
			entityId,
			Components.LifestealComponent({
				Percent = effects.LifestealPercent or 0.15,
			})
		)
		Logger.Debug("MutationApplySystem", `Applied Lifesteal to entity {entityId}`)
	end

	-- Solar: Sun on kill
	if effects.AddsSunOnKill then
		world:insert(
			entityId,
			Components.SunOnKillComponent({
				SunAmount = effects.SunPerKill or 10,
			})
		)
		Logger.Debug("MutationApplySystem", `Applied SunOnKill to entity {entityId}`)
	end

	-- Reinforced: Damage reduction
	if effects.DamageReduction and effects.DamageReduction > 0 then
		world:insert(
			entityId,
			Components.DamageReductionComponent({
				Percent = effects.DamageReduction,
			})
		)
		Logger.Debug("MutationApplySystem", `Applied DamageReduction to entity {entityId}`)
	end

	-- Primal: Splash damage
	if effects.SplashDamage then
		world:insert(
			entityId,
			Components.SplashDamageComponent({
				Radius = effects.SplashRadius or 4,
				Percent = effects.SplashPercent or 0.3,
				Knockback = effects.Knockback,
			})
		)
		Logger.Debug("MutationApplySystem", `Applied SplashDamage to entity {entityId}`)
	end

	Logger.Info("MutationApplySystem", `Applied {#mutationIds} mutations to {plantType} (Entity {entityId})`)
end

-- ============================================================
-- SECTION 5: ONSTEP (main ECS loop)
-- ============================================================
local function MutationApplySystem(world)
	-- Watch for new plants being spawned
	for entityId, plantType, owner in
		world:query(Components.PlantTypeComponent, Components.OwnerComponent):without(Components.MutationsComponent)
	do
		-- Use useAsync for non-blocking mutation loading
		-- Discriminator is entityId to track each plant's loading state independently
		local ready = Hooks.useAsync(function()
			return loadMutationsForPlant(owner.PlayerId, plantType.PlantType)
		end, { entityId, owner.PlayerId, plantType.PlantType }, entityId)

		if ready.completed then
			if ready.result.success then
				local mutationIds = ready.result.value
				-- Apply mutations now that loading is complete
				applyMutationsToPlant(world, entityId, plantType.PlantType, mutationIds, owner.PlayerId)
			else
				-- Loading failed, apply empty mutations component to prevent retry loop
				Logger.Warn("MutationApplySystem", `Failed to load mutations for entity {entityId}: {ready.result.error}`)
				world:insert(
					entityId,
					Components.MutationsComponent({
						MutationIds = {},
						OwnerId = owner.PlayerId,
					})
				)
			end
		end
		-- If not completed, continue waiting (hook will track state)
	end
end

-- ============================================================
-- SECTION 7: MODULE EXPORT
-- ============================================================
return {
	priority = CONFIG.PRIORITY,
	system = MutationApplySystem,
}
