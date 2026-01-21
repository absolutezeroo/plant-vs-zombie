--!strict
--[[
	SafetySystem.luau - Enforces entity cap and critical invariants
	
	Priority: 1 (runs very early)
	
	CRITICAL SYSTEM - This prevents crashes from entity overflow.
	Enforces ENTITY_CAP of 200 entities maximum.
	
	V3 Architecture: Matter Hooks pattern
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages.MatterHooks)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)
local PerformanceConfig = require(Shared.config.PerformanceConfig)
local Components = require(Shared.components)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	WARNING_THRESHOLD = 0.8, -- Warn at 80% capacity
	WARNING_COOLDOWN = 5, -- Seconds between warnings
})

-- 3. SYSTEM FUNCTION
local function SafetySystem(world)
	-- State managed via Hooks.useMap
	local state = Hooks.useMap("SafetyState", { LastWarningTime = 0 })

	local activeCount = 0
	local inactiveCount = 0

	-- Count entities by type (skip InactiveTag - managed by EntityPool)
	for entityId in world do
		if world:get(entityId, Components.Tags.InactiveTag) then
			inactiveCount = inactiveCount + 1
		else
			activeCount = activeCount + 1
		end
	end

	local warningLimit = math.floor(PerformanceConfig.ENTITY_CAP * CONFIG.WARNING_THRESHOLD)

	-- Only warn, don't take action - EntityPool manages entity lifecycle
	if activeCount > PerformanceConfig.ENTITY_CAP then
		Logger.Warn("SafetySystem", "CRITICAL: Active entity cap exceeded!", {
			ActiveCount = activeCount,
			Cap = PerformanceConfig.ENTITY_CAP,
		})
	elseif activeCount > warningLimit then
		-- Throttled warning
		local now = tick()
		if now - state.value.LastWarningTime >= CONFIG.WARNING_COOLDOWN then
			Logger.Warn("SafetySystem", "Approaching entity cap", {
				ActiveCount = activeCount,
				Cap = PerformanceConfig.ENTITY_CAP,
				Percent = math.floor((activeCount / PerformanceConfig.ENTITY_CAP) * 100),
			})
			state.value.LastWarningTime = now
		end
	end
end

-- 4. EXPORT
return {
	priority = 1,
	system = SafetySystem,
}
