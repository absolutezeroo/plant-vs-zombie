--!strict
--[[
	PerformanceMonitorSystem.luau - Tracks frame time budget
	
	Priority: 500 (runs after cleanup)
	
	Monitors frame time to ensure we stay under 15ms budget.
	Logs warnings when frames take too long.
	
	CRITICAL FOR MOBILE-FIRST: Frame budget is non-negotiable.
	
	LIFECYCLE:
	- Init(): Setup RunService heartbeat connection (CAN yield)
	- system(): Main loop (CANNOT yield) - monitors performance
	- Dispose(): Cleanup heartbeat connection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PerformanceConfig = require(Shared.config.PerformanceConfig)

local frameStartTime = 0
local spikeCount = 0
local frameCount = 0
local totalFrameTime = 0

local SPIKE_THRESHOLD = PerformanceConfig.FRAME_BUDGET_TOTAL * 1.5 -- 22.5ms is a spike
local LOG_INTERVAL = 60 -- Log summary every 60 seconds
local lastLogTime = 0

-- Connections for cleanup
local _connections: {RBXScriptConnection} = {}

local function setupListeners()
	-- Hook into frame start to measure time
	table.insert(_connections, RunService.Heartbeat:Connect(function()
		frameStartTime = tick()
	end))
end

local function PerformanceMonitorSystem(world)
	if frameStartTime == 0 then
		return
	end
	
	local frameTime = (tick() - frameStartTime) * 1000 -- Convert to ms
	frameCount = frameCount + 1
	totalFrameTime = totalFrameTime + frameTime
	
	-- Detect frame spikes
	if frameTime > PerformanceConfig.FRAME_BUDGET_TOTAL then
		if frameTime > SPIKE_THRESHOLD then
			spikeCount = spikeCount + 1
			Logger.Warn("PerformanceMonitor", "Frame spike detected", {
				FrameTimeMs = string.format("%.2f", frameTime),
				Budget = PerformanceConfig.FRAME_BUDGET_TOTAL,
			})
		end
	end
	
	-- Periodic summary
	local now = tick()
	if now - lastLogTime >= LOG_INTERVAL then
		local avgFrameTime = totalFrameTime / math.max(1, frameCount)
		
		Logger.Performance("PerformanceMonitor", "Frame time summary", {
			AvgFrameTimeMs = string.format("%.2f", avgFrameTime),
			SpikeCount = spikeCount,
			FrameCount = frameCount,
			UnderBudget = avgFrameTime < PerformanceConfig.FRAME_BUDGET_TOTAL,
		})
		
		-- Reset counters
		spikeCount = 0
		frameCount = 0
		totalFrameTime = 0
		lastLogTime = now
	end
end

local function Init(_world)
	setupListeners()
	Logger.Debug("PerformanceMonitorSystem", "Initialized")
end

local function Dispose()
	for _, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)
	frameStartTime = 0
	spikeCount = 0
	frameCount = 0
	totalFrameTime = 0
	lastLogTime = 0
	Logger.Debug("PerformanceMonitorSystem", "Disposed")
end

return {
	_name = "PerformanceMonitorSystem",
	priority = 500,  -- After cleanup
	system = PerformanceMonitorSystem,
	Init = Init,
	Dispose = Dispose,
}
