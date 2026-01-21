--!strict
--[[
	PerformanceMonitorSystem.luau - Tracks frame time budget
	
	Priority: 500 (runs after cleanup)
	
	Monitors frame time to ensure we stay under 15ms budget.
	CRITICAL FOR MOBILE-FIRST: Frame budget is non-negotiable.
	
	V3 Architecture: Matter Hooks pattern
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages.MatterHooks)
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)
local PerformanceConfig = require(Shared.config.PerformanceConfig)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	SPIKE_THRESHOLD = PerformanceConfig.FRAME_BUDGET_TOTAL * 1.5, -- 22.5ms is a spike
	LOG_INTERVAL = 60, -- Log summary every 60 seconds
})

-- 3. SYSTEM FUNCTION
local function PerformanceMonitorSystem(_world)
	-- State managed via Hooks.useMap
	local state = Hooks.useMap("PerfMonitorState", {
		FrameStartTime = 0,
		SpikeCount = 0,
		FrameCount = 0,
		TotalFrameTime = 0,
		LastLogTime = 0,
	})

	-- Initialize Heartbeat connection once via useMemo with empty deps
	local trove = Hooks.useMemo(function()
		local t = Trove.new()
		t:Connect(RunService.Heartbeat, function()
			state.value.FrameStartTime = tick()
		end)
		return t
	end, {})

	if state.value.FrameStartTime == 0 then
		return
	end

	local frameTime = (tick() - state.value.FrameStartTime) * 1000 -- Convert to ms
	state.value.FrameCount = state.value.FrameCount + 1
	state.value.TotalFrameTime = state.value.TotalFrameTime + frameTime

	-- Detect frame spikes
	if frameTime > PerformanceConfig.FRAME_BUDGET_TOTAL then
		if frameTime > CONFIG.SPIKE_THRESHOLD then
			state.value.SpikeCount = state.value.SpikeCount + 1
			Logger.Warn("PerformanceMonitor", "Frame spike detected", {
				FrameTimeMs = string.format("%.2f", frameTime),
				Budget = PerformanceConfig.FRAME_BUDGET_TOTAL,
			})
		end
	end

	-- Periodic summary
	local now = tick()
	if now - state.value.LastLogTime >= CONFIG.LOG_INTERVAL then
		local avgFrameTime = state.value.TotalFrameTime / math.max(1, state.value.FrameCount)

		Logger.Performance("PerformanceMonitor", "Frame time summary", {
			AvgFrameTimeMs = string.format("%.2f", avgFrameTime),
			SpikeCount = state.value.SpikeCount,
			FrameCount = state.value.FrameCount,
			UnderBudget = avgFrameTime < PerformanceConfig.FRAME_BUDGET_TOTAL,
		})

		-- Reset counters
		state.value.SpikeCount = 0
		state.value.FrameCount = 0
		state.value.TotalFrameTime = 0
		state.value.LastLogTime = now
	end
end

-- 4. EXPORT
return {
	priority = 500,
	system = PerformanceMonitorSystem,
}
