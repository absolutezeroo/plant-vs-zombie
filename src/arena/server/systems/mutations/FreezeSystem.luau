--!strict
--[[
	FreezeSystem.luau - Handles freeze effects on zombies
	
	Priority: 355 (Combat processing - after CombatSystem)
	
	Two responsibilities:
	1. Query ProjectileHitEvent + FreezeEffectComponent to apply freezes
	2. Process zombies with FrozenComponent (expiration)
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - processes frozen entities
	- Dispose(): No cleanup needed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GameConstants = require(Shared.config.GameConstants)
local Logger = require(Shared.utils.Logger)
local ChanceUtils = require(Shared.utils.ChanceUtils)

-- Components
local FrozenComponent = Components.FrozenComponent
local FreezeEffectComponent = Components.FreezeEffectComponent
local SlowComponent = Components.SlowComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local ProjectileHitEvent = Components.ProjectileHitEvent

-- Helper: Try to freeze a zombie (with chance roll)
local function tryFreeze(world, zombieEntityId: number, freezeChance: number, freezeDuration: number, enhancedSlow: number?): boolean
	if not world:contains(zombieEntityId) then return false end
	
	-- Check if already frozen
	local existingFreeze = world:get(zombieEntityId, FrozenComponent)
	if existingFreeze then
		-- Refresh duration
		world:insert(zombieEntityId, FrozenComponent({
			RemainingDuration = math.max(existingFreeze.RemainingDuration, freezeDuration),
			AppliedAt = os.clock(),
		}))
		return true
	end
	
	-- Roll for freeze
	if ChanceUtils.Roll(freezeChance) then
		-- Freeze successful!
		world:insert(zombieEntityId, FrozenComponent({
			RemainingDuration = freezeDuration,
			AppliedAt = os.clock(),
		}))
		Logger.Debug("FreezeSystem", `Froze entity {zombieEntityId} for {freezeDuration}s`)
		return true
	else
		-- Apply enhanced slow if specified
		if enhancedSlow and enhancedSlow > 0 then
			local existingSlow = world:get(zombieEntityId, SlowComponent)
			local slowPercent = GameConstants.Combat.DEFAULT_SLOW_PERCENT + enhancedSlow -- Base slow + enhanced
			
			if existingSlow then
				local existingSlowPercent = existingSlow.SlowPercent :: number
				slowPercent = math.min(GameConstants.Combat.MAX_SLOW_PERCENT, existingSlowPercent + enhancedSlow)
			end
			
			world:insert(zombieEntityId, SlowComponent({
				SlowPercent = slowPercent,
				Duration = GameConstants.Combat.DEFAULT_SLOW_DURATION,
				AppliedAt = os.clock(),
			}))
		end
		return false
	end
end

-- System function
local function FreezeSystem(world)
	local currentTime = os.clock()
	
	-- 1. Process ProjectileHitEvents: apply freezes from plants with FreezeEffectComponent
	for _, hitEvent in world:query(ProjectileHitEvent) do
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local freezeEffect = world:get(sourcePlant, FreezeEffectComponent)
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
	for entityId, frozen, zombie in world:query(FrozenComponent, ZombieTypeComponent) do
		local elapsed = currentTime - frozen.AppliedAt
		
		if elapsed >= frozen.RemainingDuration then
			-- Freeze expired, remove component
			world:remove(entityId, FrozenComponent)
			Logger.Debug("FreezeSystem", `Freeze expired on entity {entityId}`)
		end
		-- While frozen, movement is handled by ZombieMovementSystem checking for FrozenComponent
	end
end

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	-- No state to clean up
end

return {
	_name = "FreezeSystem",
	priority = 355,
	system = FreezeSystem,
	Init = Init,
	Dispose = Dispose,
}
