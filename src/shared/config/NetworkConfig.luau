--!strict
--[[
	NetworkConfig.lua - Networking constraints for Zap replication
	
	Bandwidth constraints ensure smooth gameplay on mobile networks.
	Ghost timeout prevents indefinite pending entities on packet loss.
]]

local NetworkConfig = {
	-- Server Tick Rate
	TICK_RATE = 60,             -- Server heartbeat Hz (60 ticks/second)
	
	-- Bandwidth Limits (bytes/second)
	BANDWIDTH_CAP = 50000,      -- 50 KB/s average target
	BANDWIDTH_PEAK = 60000,     -- 60 KB/s absolute maximum
	
	-- Latency Tolerance
	MAX_LATENCY = 200,          -- Designed for up to 200ms latency
	
	-- Ghost Prediction
	GHOST_TIMEOUT = 5.0,        -- Seconds before ghost auto-rollback
	RECONCILE_BUFFER = 0.1,     -- Seconds of input buffer for rollback
	
	-- Replication Priority (lower = higher priority)
	PRIORITY_COMBAT = 1,        -- Combat events replicate first
	PRIORITY_MOVEMENT = 2,      -- Movement updates
	PRIORITY_COSMETIC = 3,      -- Visual-only updates
	
	-- Quantization
	POSITION_PRECISION = 0.1,   -- Position quantization step (studs)
}

return table.freeze(NetworkConfig)
