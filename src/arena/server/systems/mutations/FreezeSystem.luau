--!strict
--[[
	FreezeSystem.luau - Handles freeze effects on zombies
	
	Priority: 355 (Combat processing)
	
	Handles:
	- Frozen zombies (completely stopped)
	- Removing freeze when duration expires
	
	FreezeEffect on plants/projectiles is processed when hitting zombies.
	
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
local Logger = require(Shared.utils.Logger)

-- Components
local FrozenComponent = Components.FrozenComponent
local SlowComponent = Components.SlowComponent
local MovementComponent = Components.MovementComponent
local ZombieTypeComponent = Components.ZombieTypeComponent

-- System function
local function FreezeSystem(world)
	local currentTime = os.clock()
	
	-- Process all frozen zombies
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

-- Module API
local API = {}

-- Attempt to freeze a zombie (with chance roll)
function API.TryFreeze(world, zombieEntityId: number, freezeChance: number, freezeDuration: number, enhancedSlow: number?): boolean
	-- Check if zombie exists
	if not world:contains(zombieEntityId) then return false end
	
	-- Check if already frozen
	local existingFreeze = world:get(zombieEntityId, FrozenComponent)
	if existingFreeze then
		-- Refresh duration (immutable via Sift)
		world:insert(zombieEntityId, Sift.Dictionary.merge(existingFreeze, {
			RemainingDuration = math.max(existingFreeze.RemainingDuration, freezeDuration),
			AppliedAt = os.clock(),
		}))
		return true
	end
	
	-- Roll for freeze
	local roll = math.random()
	if roll <= freezeChance then
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
			local slowPercent = 0.5 + enhancedSlow -- Base slow + enhanced
			
			if existingSlow then
				local existingSlowPercent = existingSlow.SlowPercent :: number
				slowPercent = math.min(0.9, existingSlowPercent + enhancedSlow)
			end
			
			world:insert(zombieEntityId, SlowComponent({
				SlowPercent = slowPercent,
				Duration = 3,
				AppliedAt = os.clock(),
			}))
		end
		return false
	end
end

-- Directly freeze a zombie (no chance roll)
function API.ApplyFreeze(world, zombieEntityId: number, duration: number)
	if not world:contains(zombieEntityId) then return end
	
	world:insert(zombieEntityId, FrozenComponent({
		RemainingDuration = duration,
		AppliedAt = os.clock(),
	}))
	Logger.Debug("FreezeSystem", `Applied freeze to entity {zombieEntityId} for {duration}s`)
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
	API = API,
}
