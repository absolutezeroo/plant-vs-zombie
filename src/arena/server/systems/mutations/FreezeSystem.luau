--!strict
--[[
	FreezeSystem.luau - Handles freeze effects on zombies
	
	Priority: 355 (Combat processing - after CombatSystem)
	
	Two responsibilities:
	1. Query ProjectileHitEvent + FreezeEffectComponent to apply freezes
	2. Process zombies with FrozenComponent (expiration)
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GameConstants = require(Shared.config.GameConstants)
local ChanceUtils = require(Shared.utils.ChanceUtils)

-- Network for VFX events
local Network = require(Shared.network.generated.server)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	DEFAULT_SLOW_PERCENT = GameConstants.Combat.DEFAULT_SLOW_PERCENT,
	MAX_SLOW_PERCENT = GameConstants.Combat.MAX_SLOW_PERCENT,
	DEFAULT_SLOW_DURATION = GameConstants.Combat.DEFAULT_SLOW_DURATION,
})

-- 3. STATE (minimal - stateless system)
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

-- Helper: Try to freeze a zombie (with chance roll)
local function tryFreeze(world, zombieEntityId: number, freezeChance: number, freezeDuration: number, enhancedSlow: number?): boolean
	if not world:contains(zombieEntityId) then return false end
	
	-- Check if already frozen
	local existingFreeze = world:get(zombieEntityId, Components.FrozenComponent)
	if existingFreeze then
		-- Refresh duration
		world:insert(zombieEntityId, Components.FrozenComponent({
			RemainingDuration = math.max(existingFreeze.RemainingDuration, freezeDuration),
			AppliedAt = os.clock(),
		}))
		return true
	end
	
	-- Roll for freeze
	if ChanceUtils.Roll(freezeChance) then
		-- Freeze successful!
		world:insert(zombieEntityId, Components.FrozenComponent({
			RemainingDuration = freezeDuration,
			AppliedAt = os.clock(),
		}))
		
		-- Fire VFX event for freeze application
		local pos = world:get(zombieEntityId, Components.PositionComponent)
		if pos then
			Network.StatusApplied.FireAll({
				EntityId = zombieEntityId,
				StatusType = "Freeze",
				Duration = freezeDuration,
				PositionX = pos.X,
				PositionY = pos.Y,
				PositionZ = pos.Z,
			})
		end
		
		return true
	else
		-- Apply enhanced slow if specified
		if enhancedSlow and enhancedSlow > 0 then
			local existingSlow = world:get(zombieEntityId, Components.SlowComponent)
			local slowPercent = CONFIG.DEFAULT_SLOW_PERCENT + enhancedSlow
			
			if existingSlow then
				local existingSlowPercent = existingSlow.SlowPercent :: number
				slowPercent = math.min(CONFIG.MAX_SLOW_PERCENT, existingSlowPercent + enhancedSlow)
			end
			
			world:insert(zombieEntityId, Components.SlowComponent({
				SlowPercent = slowPercent,
				Duration = CONFIG.DEFAULT_SLOW_DURATION,
				AppliedAt = os.clock(),
			}))
		end
		return false
	end
end

-- 6. MAIN LOOP
local function OnStep(world)
	local currentTime = os.clock()
	
	-- 1. Process ProjectileHitEvents: apply freezes from plants with FreezeEffectComponent
	for _, hitEvent in world:query(Components.ProjectileHitEvent) do
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local freezeEffect = world:get(sourcePlant, Components.FreezeEffectComponent)
		if freezeEffect then
			tryFreeze(
				world,
				hitEvent.TargetZombie,
				freezeEffect.FreezeChance,
				freezeEffect.FreezeDuration,
				freezeEffect.EnhancedSlow
			)
		end
	end
	
	-- 2. Process all frozen zombies (expiration)
	for entityId, frozen in world:query(Components.FrozenComponent, Components.ZombieTypeComponent) do
		local elapsed = currentTime - frozen.AppliedAt
		
		if elapsed >= frozen.RemainingDuration then
			-- Freeze expired, remove component
			world:remove(entityId, Components.FrozenComponent)
		end
	end
end

-- 7. EXPORT
return {
	priority = 355,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
