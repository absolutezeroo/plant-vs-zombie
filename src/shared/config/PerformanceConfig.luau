--!strict
--[[
	PerformanceConfig.lua - Performance constraints and safety thresholds
	
	WARNING: These values ensure 60 FPS on iPhone 11. Changing them
	may cause performance degradation or crashes on mobile devices.
]]

local PerformanceConfig = {
	-- Entity Limits (HARD CAPS)
	ENTITY_CAP = 200,           -- Maximum active entities in Matter World
	ENTITY_TARGET = 150,        -- Target entities (25% safety margin)
	
	-- Entity Breakdown Budget
	MAX_ZOMBIES = 120,          -- Maximum zombie entities
	MAX_PLANTS = 45,            -- Maximum plant entities (full grid)
	MAX_PROJECTILES = 25,       -- Maximum projectile entities
	MAX_RESOURCES = 10,         -- Maximum resource entities (sun drops)
	
	-- Frame Budget (milliseconds)
	FRAME_BUDGET_TOTAL = 15,    -- 60 FPS = 16.67ms, target 15ms
	FRAME_BUDGET_INPUT = 1,     -- Input phase budget
	FRAME_BUDGET_SIMULATION = 10, -- Simulation phase budget
	FRAME_BUDGET_PRESENTATION = 3, -- Presentation phase budget
	FRAME_BUDGET_CLEANUP = 1,   -- Cleanup phase budget
	
	-- Memory Limits (MB)
	MEMORY_LIMIT = 600,         -- Absolute maximum RAM
	MEMORY_WARNING = 500,       -- 80% threshold, log warning
	MEMORY_EMERGENCY = 550,     -- Trigger emergency GC
	
	-- Monitoring Intervals
	MONITOR_INTERVAL = 10,      -- Seconds between performance logs
	MEMORY_POLL_INTERVAL = 10,  -- Seconds between memory checks
	
	-- LOD Thresholds (entity counts)
	LOD_LEVEL_1 = 50,           -- Reduce particle trails
	LOD_LEVEL_2 = 100,          -- Disable non-critical VFX
	LOD_LEVEL_3 = 150,          -- Emergency mode, disable all cosmetics
	
	-- Audio Channel Limits
	AUDIO_CHANNELS_NORMAL = 16, -- Normal audio channels
	AUDIO_CHANNELS_LOD1 = 8,    -- Reduced at 50+ entities
	AUDIO_CHANNELS_LOD2 = 4,    -- Minimal at 100+ entities
}

return table.freeze(PerformanceConfig)
