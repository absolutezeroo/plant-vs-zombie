--!strict
--[[
	LifestealSystem.luau - Heals plants when they deal damage
	
	Priority: 370 (After damage processing)
	
	Queries ProjectileHitEvent + LifestealComponent to heal plants.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local ECSUtils = require(Shared.utils.ECSUtils)
local Logger = require(Shared.utils.Logger)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	-- Minimum heal amount to apply (prevents micro-heals)
	MIN_HEAL_AMOUNT = 1,
})

-- 3. STATE (minimal - this system is stateless)
local State = {
	IsInitialized = false,
}

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then return end
	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	State.IsInitialized = false
end

-- 6. MAIN LOOP
local function OnStep(world)
	-- Process ProjectileHitEvents: heal plants with LifestealComponent
	for _, hitEvent in world:query(Components.ProjectileHitEvent) do
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local lifesteal = world:get(sourcePlant, Components.LifestealComponent)
		if not lifesteal then continue end
		
		-- Calculate heal amount
		local lifestealPercent = lifesteal.Percent :: number
		local healAmount = math.floor(hitEvent.Damage * lifestealPercent)
		if healAmount < CONFIG.MIN_HEAL_AMOUNT then continue end
		
		-- Apply healing using ECSUtils
		Logger.Debug("Lifesteal", "Plant", sourcePlant, "healed for", healAmount, "HP")
		ECSUtils.HealEntity(world, sourcePlant, healAmount, Components)
	end
end

-- 7. EXPORT
return {
	priority = 370,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
