--!strict
--[[
	MutationApplySystem.luau - Applies mutations to newly spawned plants
	
	Priority: 205 (Right after PlacementSystem at 200)
	
	Watches for new plants and applies mutation components based on
	the player's purchased mutations for that plant type.
	
	This system runs once per plant spawn and adds the appropriate
	mutation effect components (BurnEffect, ChainLightning, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local MutationData = require(Shared.data.MutationData)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

-- Component references
local PlantTypeComponent = Components.PlantTypeComponent
local OwnerComponent = Components.OwnerComponent
local HealthComponent = Components.HealthComponent
local MutationsComponent = Components.MutationsComponent

-- Mutation effect components
local BurnEffectComponent = Components.BurnEffectComponent
local FreezeEffectComponent = Components.FreezeEffectComponent
local ChainLightningComponent = Components.ChainLightningComponent
local PoisonCloudComponent = Components.PoisonCloudComponent
local LifestealComponent = Components.LifestealComponent
local SunOnKillComponent = Components.SunOnKillComponent
local DamageReductionComponent = Components.DamageReductionComponent
local SplashDamageComponent = Components.SplashDamageComponent

-- Server reference for PlayerDataService
local Server = script.Parent.Parent.Parent
local PlayerDataService = require(Server.services.PlayerDataService)

-- Cache for player mutations (refreshed when player joins arena)
local playerMutationsCache: {[number]: {[string]: {string}}} = {} -- [UserId] -> [PlantType] -> {mutations}

-- Module API for external use
local API = {}

-- Load player mutations into cache
function API.LoadPlayerMutations(userId: number, mutations: {[string]: {string}})
	playerMutationsCache[userId] = mutations
	Logger.Info("MutationApplySystem", `Loaded mutations for user {userId}`)
end

-- Clear player mutations on leave
function API.ClearPlayerMutations(userId: number)
	playerMutationsCache[userId] = nil
end

-- Get mutations for a player's plant
local function getPlayerMutations(userId: number, plantType: string): {string}
	local playerMutations = playerMutationsCache[userId]
	if not playerMutations then return {} end
	return playerMutations[plantType] or {}
end

-- Apply mutation components to a plant entity
local function applyMutationsToPlant(world, entityId: number, plantType: string, userId: number)
	local mutationIds = getPlayerMutations(userId, plantType)
	if #mutationIds == 0 then return end
	
	-- Get combined effects
	local effects = MutationData.CalculateCombinedEffects(mutationIds)
	
	-- Apply stat modifiers to existing components
	local health = world:get(entityId, HealthComponent)
	if health and effects.HealthBonus and effects.HealthBonus ~= 1 then
		local healthMax = health.Max :: number
		local healthCurrent = health.Current :: number
		local newMax = math.floor(healthMax * effects.HealthBonus)
		local newCurrent = math.floor(healthCurrent * effects.HealthBonus)
		world:insert(entityId, HealthComponent({
			Current = newCurrent,
			Max = newMax,
		}))
	end
	
	-- Track mutations on the entity
	world:insert(entityId, MutationsComponent({
		MutationIds = mutationIds,
		OwnerId = userId,
	}))
	
	-- Apply effect components based on mutations
	
	-- Fire: Burn on hit
	if effects.AddsBurnDamage then
		world:insert(entityId, BurnEffectComponent({
			DamagePerSecond = effects.BurnDamagePerSecond or 5,
			Duration = effects.BurnDuration or 3,
		}))
		Logger.Debug("MutationApplySystem", `Applied BurnEffect to entity {entityId}`)
	end
	
	-- Ice: Freeze on hit
	if effects.AddsFreeze then
		world:insert(entityId, FreezeEffectComponent({
			FreezeChance = effects.FreezeChance or 0.2,
			FreezeDuration = effects.FreezeDuration or 2,
			EnhancedSlow = effects.EnhancedSlow,
		}))
		Logger.Debug("MutationApplySystem", `Applied FreezeEffect to entity {entityId}`)
	end
	
	-- Electric: Chain lightning
	if effects.AddsChainLightning then
		world:insert(entityId, ChainLightningComponent({
			ChainCount = effects.ChainCount or 2,
			ChainDamage = effects.ChainDamage or 0.5,
			ChainRange = effects.ChainRange or 8,
		}))
		Logger.Debug("MutationApplySystem", `Applied ChainLightning to entity {entityId}`)
	end
	
	-- Toxic: Poison cloud on death
	if effects.AddsPoisonCloud then
		world:insert(entityId, PoisonCloudComponent({
			Radius = effects.PoisonRadius or 6,
			DamagePerSecond = effects.PoisonDamagePerSecond or 3,
			Duration = effects.PoisonDuration or 4,
		}))
		Logger.Debug("MutationApplySystem", `Applied PoisonCloud to entity {entityId}`)
	end
	
	-- Shadow: Lifesteal
	if effects.AddsLifesteal then
		world:insert(entityId, LifestealComponent({
			Percent = effects.LifestealPercent or 0.15,
		}))
		Logger.Debug("MutationApplySystem", `Applied Lifesteal to entity {entityId}`)
	end
	
	-- Solar: Sun on kill
	if effects.AddsSunOnKill then
		world:insert(entityId, SunOnKillComponent({
			SunAmount = effects.SunPerKill or 10,
		}))
		Logger.Debug("MutationApplySystem", `Applied SunOnKill to entity {entityId}`)
	end
	
	-- Reinforced: Damage reduction
	if effects.DamageReduction and effects.DamageReduction > 0 then
		world:insert(entityId, DamageReductionComponent({
			Percent = effects.DamageReduction,
		}))
		Logger.Debug("MutationApplySystem", `Applied DamageReduction to entity {entityId}`)
	end
	
	-- Primal: Splash damage
	if effects.SplashDamage then
		world:insert(entityId, SplashDamageComponent({
			Radius = effects.SplashRadius or 4,
			Percent = effects.SplashPercent or 0.3,
			Knockback = effects.Knockback,
		}))
		Logger.Debug("MutationApplySystem", `Applied SplashDamage to entity {entityId}`)
	end
	
	Logger.Info("MutationApplySystem", `Applied {#mutationIds} mutations to {plantType} (Entity {entityId})`)
end

-- System function - runs each frame
local function MutationApplySystem(world)
	-- Watch for new plants being spawned
	for entityId, plantType, owner in world:query(PlantTypeComponent, OwnerComponent):without(MutationsComponent) do
		-- This plant was just spawned and doesn't have mutations applied yet
		applyMutationsToPlant(world, entityId, plantType.PlantType, owner.PlayerId)
	end
end

return {
	system = MutationApplySystem,
	priority = 205, -- Right after PlacementSystem (200)
	API = API,
}
