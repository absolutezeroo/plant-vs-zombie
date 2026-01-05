--!strict
--[[
	Safety System - Enforces entity cap and critical invariants
	
	Priority: 1 (runs very early)
	
	CRITICAL SYSTEM - This prevents crashes from entity overflow.
	Enforces ENTITY_CAP of 200 entities maximum.
	Logs warnings when approaching limits.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PerformanceConfig = require(Shared.config.PerformanceConfig)
local Tags = require(Shared.components.Tags)

local WARNING_THRESHOLD = 0.8 -- Warn at 80% capacity
local lastWarningTime = 0
local WARNING_COOLDOWN = 5 -- seconds between warnings

local function SafetySystem(world)
	local activeCount = 0
	local inactiveCount = 0
	
	-- Count entities by type
	for entityId in world do
		if world:get(entityId, Tags.InactiveTag) then
			inactiveCount = inactiveCount + 1
		else
			activeCount = activeCount + 1
		end
	end
	
	local totalCount = activeCount + inactiveCount
	local warningLimit = math.floor(PerformanceConfig.ENTITY_CAP * WARNING_THRESHOLD)
	
	-- Check for entity cap violations
	if activeCount > PerformanceConfig.ENTITY_CAP then
		Logger.Warn("SafetySystem", "CRITICAL: Active entity cap exceeded!", {
			ActiveCount = activeCount,
			Cap = PerformanceConfig.ENTITY_CAP,
		})
		
		-- Emergency: mark oldest entities as inactive
		-- This is a safety net, should never happen in normal gameplay
		local toDeactivate = activeCount - PerformanceConfig.ENTITY_CAP
		local deactivated = 0
		
		for entityId in world do
			if not world:get(entityId, Tags.InactiveTag) then
				world:insert(entityId, Tags.InactiveTag)
				deactivated = deactivated + 1
				if deactivated >= toDeactivate then
					break
				end
			end
		end
		
		Logger.Warn("SafetySystem", "Emergency deactivation", {
			Deactivated = deactivated,
		})
	elseif activeCount > warningLimit then
		-- Throttled warning
		local now = tick()
		if now - lastWarningTime >= WARNING_COOLDOWN then
			Logger.Warn("SafetySystem", "Approaching entity cap", {
				ActiveCount = activeCount,
				Cap = PerformanceConfig.ENTITY_CAP,
				Percent = math.floor((activeCount / PerformanceConfig.ENTITY_CAP) * 100),
			})
			lastWarningTime = now
		end
	end
end

return {
	system = SafetySystem,
	priority = 1,  -- Runs very early
}
