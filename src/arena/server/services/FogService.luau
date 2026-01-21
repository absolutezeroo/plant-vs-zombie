--!strict
--[[
	FogService.luau - Server-side fog state management
	
	SERVICE ARCHITECTURE (holds state, provides public API)
	
	Manages fog activation state. Called by:
	- WaveManager/MapLoader to enable/disable fog
	- FogSystem to check fog state
	
	RULE: Systems should NOT have public APIs. Use Services instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared.config.MapConfig)
local Logger = require(Shared.utils.core.Logger)

local Network = require(Shared.network.generated.server)

-- ============================================================
-- STATE
-- ============================================================
local State = {
	IsFogActive = false,
	FoggyColumns = {} :: { number },
}

-- ============================================================
-- DEFAULT CONFIG
-- ============================================================
local DEFAULT_FOG_COLUMNS = { 5, 6, 7, 8, 9 }

-- ============================================================
-- PUBLIC API
-- ============================================================
local FogService = {}

-- Check if fog is currently active
function FogService.IsFogActive(): boolean
	return State.IsFogActive
end

-- Get current foggy columns
function FogService.GetFoggyColumns(): { number }
	return State.FoggyColumns
end

-- Enable fog for current level (called by WaveManager or map loader)
-- If no foggyColumns provided, uses FogBounds from MapConfig if available
function FogService.EnableFog(foggyColumns: { number }?)
	State.IsFogActive = true

	-- Check if map has FogBounds defined
	local hasFogBounds = MapConfig.HasFogBounds()
	local fogBoundsA, fogBoundsB = MapConfig.GetFogBounds()

	if hasFogBounds and fogBoundsA and fogBoundsB then
		-- Use FogBounds from map config
		State.FoggyColumns = {} -- Empty, using bounds instead
		Network.FogEnabled.FireAll({
			FoggyColumns = {},
			UseFogBounds = true,
			FogBoundsAX = fogBoundsA.X,
			FogBoundsAY = fogBoundsA.Y,
			FogBoundsAZ = fogBoundsA.Z,
			FogBoundsBX = fogBoundsB.X,
			FogBoundsBY = fogBoundsB.Y,
			FogBoundsBZ = fogBoundsB.Z,
		})
		Logger.Info("FogService", `Fog enabled with bounds: {fogBoundsA} to {fogBoundsB}`)
	else
		-- Fallback to column-based fog
		local columns = foggyColumns or DEFAULT_FOG_COLUMNS
		State.FoggyColumns = columns
		Network.FogEnabled.FireAll({
			FoggyColumns = columns,
			UseFogBounds = false,
		})
		Logger.Info("FogService", `Fog enabled on columns: {table.concat(columns, ", ")}`)
	end
end

-- Enable fog using only FogBounds from MapConfig (no fallback)
function FogService.EnableFogFromBounds(): boolean
	if not MapConfig.HasFogBounds() then
		Logger.Warn("FogService", "EnableFogFromBounds called but no FogBounds defined in map")
		return false
	end

	FogService.EnableFog(nil)
	return true
end

-- Disable fog
function FogService.DisableFog()
	State.IsFogActive = false
	State.FoggyColumns = {}
	Network.FogCleared.FireAll({})
	Logger.Info("FogService", "Fog disabled")
end

-- Reset state (for hot-reload or game reset)
function FogService.Dispose()
	State.IsFogActive = false
	State.FoggyColumns = {}
end

return FogService
