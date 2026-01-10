--!strict
--[[
	PerformanceMonitorSystem.luau - Tracks frame time budget
	
	Priority: 500 (runs after cleanup)
	
	Monitors frame time to ensure we stay under 15ms budget.
	CRITICAL FOR MOBILE-FIRST: Frame budget is non-negotiable.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PerformanceConfig = require(Shared.config.PerformanceConfig)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	SPIKE_THRESHOLD = PerformanceConfig.FRAME_BUDGET_TOTAL * 1.5, -- 22.5ms is a spike
	LOG_INTERVAL = 60, -- Log summary every 60 seconds
})

-- 3. STATE
local State = {
	IsInitialized = false,
	Trove = nil :: any,
	FrameStartTime = 0,
	SpikeCount = 0,
	FrameCount = 0,
	TotalFrameTime = 0,
	LastLogTime = 0,
}

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then return end
	State.IsInitialized = true
	
	State.Trove = Trove.new()
	
	-- Hook into frame start to measure time
	State.Trove:Connect(RunService.Heartbeat, function()
		State.FrameStartTime = tick()
	end)
end

-- 5. DISPOSE
local function Dispose()
	if State.Trove then
		State.Trove:Clean()
		State.Trove = nil
	end
	State.IsInitialized = false
	State.FrameStartTime = 0
	State.SpikeCount = 0
	State.FrameCount = 0
	State.TotalFrameTime = 0
	State.LastLogTime = 0
end

-- 6. MAIN LOOP
local function OnStep(_world)
	if State.FrameStartTime == 0 then
		return
	end
	
	local frameTime = (tick() - State.FrameStartTime) * 1000 -- Convert to ms
	State.FrameCount = State.FrameCount + 1
	State.TotalFrameTime = State.TotalFrameTime + frameTime
	
	-- Detect frame spikes
	if frameTime > PerformanceConfig.FRAME_BUDGET_TOTAL then
		if frameTime > CONFIG.SPIKE_THRESHOLD then
			State.SpikeCount = State.SpikeCount + 1
			Logger.Warn("PerformanceMonitor", "Frame spike detected", {
				FrameTimeMs = string.format("%.2f", frameTime),
				Budget = PerformanceConfig.FRAME_BUDGET_TOTAL,
			})
		end
	end
	
	-- Periodic summary
	local now = tick()
	if now - State.LastLogTime >= CONFIG.LOG_INTERVAL then
		local avgFrameTime = State.TotalFrameTime / math.max(1, State.FrameCount)
		
		Logger.Performance("PerformanceMonitor", "Frame time summary", {
			AvgFrameTimeMs = string.format("%.2f", avgFrameTime),
			SpikeCount = State.SpikeCount,
			FrameCount = State.FrameCount,
			UnderBudget = avgFrameTime < PerformanceConfig.FRAME_BUDGET_TOTAL,
		})
		
		-- Reset counters
		State.SpikeCount = 0
		State.FrameCount = 0
		State.TotalFrameTime = 0
		State.LastLogTime = now
	end
end

-- 7. EXPORT
return {
	priority = 500,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
