--!strict
--[[
	SafetySystem.luau - Enforces entity cap and critical invariants
	
	Priority: 1 (runs very early)
	
	CRITICAL SYSTEM - This prevents crashes from entity overflow.
	Enforces ENTITY_CAP of 200 entities maximum.
	Logs warnings when approaching limits.
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - enforces entity cap
	- Dispose(): No cleanup needed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PerformanceConfig = require(Shared.config.PerformanceConfig)
local Components = require(Shared.components)
local Tags = Components.Tags

local WARNING_THRESHOLD = 0.8 -- Warn at 80% capacity
local lastWarningTime = 0
local WARNING_COOLDOWN = 5 -- seconds between warnings

local function SafetySystem(world)
	local activeCount = 0
	local inactiveCount = 0
	
	-- Count entities by type
	-- IMPORTANT: Skip entities with InactiveTag - those are managed by EntityPool
	for entityId in world do
		if world:get(entityId, Tags.InactiveTag) then
			inactiveCount = inactiveCount + 1
		else
			activeCount = activeCount + 1
		end
	end
	
	local warningLimit = math.floor(PerformanceConfig.ENTITY_CAP * WARNING_THRESHOLD)
	
	-- Only warn, don't take action - EntityPool manages entity lifecycle
	if activeCount > PerformanceConfig.ENTITY_CAP then
		Logger.Warn("SafetySystem", "CRITICAL: Active entity cap exceeded!", {
			ActiveCount = activeCount,
			Cap = PerformanceConfig.ENTITY_CAP,
		})
		-- NOTE: Removed emergency deactivation - it interferes with EntityPool
		-- EntityPool.Spawn() will return nil when exhausted, which is safer
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

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	lastWarningTime = 0
end

return {
	_name = "SafetySystem",
	priority = 1,  -- Runs very early
	system = SafetySystem,
	Init = Init,
	Dispose = Dispose,
}
