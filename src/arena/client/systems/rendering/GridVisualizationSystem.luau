--!strict
--[[
	GridVisualizationSystem.luau - Renders debug grid lines
	
	Priority: 350 (Presentation phase)
	
	Creates cyan debug lines showing the 9×5 grid.
	Listens for MapConfigSync and creates grid when config is received.
	Toggle with DEBUG_GRID_VISIBLE constant.
	
	V3 Architecture: Matter Hooks pattern
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Use FindFirstChild to avoid yielding (Shared should already exist from init.client.luau)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "GridVisualizationSystem: Shared folder not found - ensure init.client.luau loads first")

local Packages = ReplicatedStorage:FindFirstChild("Packages")
assert(Packages, "GridVisualizationSystem: Packages folder not found")
local Trove = require(Packages:WaitForChild("Trove"))
local Hooks = require(Packages.MatterHooks)

local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local Logger = require(Shared.utils.core.Logger)
local Network = require(Shared.network.generated.client)

-- Configuration
local DEBUG_GRID_VISIBLE = true
local GRID_COLOR = Color3.fromRGB(0, 255, 255) -- Cyan
local GRID_LINE_THICKNESS = 0.1
local GRID_LINE_HEIGHT = 0.05 -- Slightly above ground

-- State
local _gridFolder: Folder? = nil
local _trove = Trove.new()

local function createLine(from: Vector3, to: Vector3, parent: Instance): Part
	local distance = (to - from).Magnitude
	local midpoint = (from + to) / 2

	local line = Instance.new("Part")
	line.Name = "GridLine"
	line.Anchored = true
	line.CanCollide = false
	line.CanTouch = false
	line.CanQuery = false
	line.CastShadow = false
	line.Material = Enum.Material.Neon
	line.Color = GRID_COLOR
	line.Size = Vector3.new(distance, GRID_LINE_THICKNESS, GRID_LINE_THICKNESS)
	line.CFrame = CFrame.lookAt(midpoint, to) * CFrame.Angles(0, math.rad(90), 0)
	line.Parent = parent

	return line
end

local function createGrid()
	if not DEBUG_GRID_VISIBLE then
		return
	end

	if _gridFolder then
		_gridFolder:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "DebugGrid"
	folder.Parent = Workspace
	_gridFolder = folder

	-- Use MapConfig for dynamic grid bounds
	local config = MapConfig.GetConfig()
	local cellW, cellD = MapConfig.GetCellSize()
	local y = config.GridY + GRID_LINE_HEIGHT

	-- Log detailed config for debugging
	Logger.Info("GridVisualization", `=== GRID CONFIG ===`)
	Logger.Info("GridVisualization", `  UsingVisualConfig: {config.UsingVisualConfig}`)
	Logger.Info("GridVisualization", `  GridY: {config.GridY}`)
	Logger.Info("GridVisualization", `  GridCornerA: {config.GridCornerA}`)
	Logger.Info("GridVisualization", `  GridCornerB: {config.GridCornerB}`)
	Logger.Info("GridVisualization", `  Creating lines at Y={y}`)
	Logger.Info("GridVisualization", `===================`)

	-- Vertical lines (columns)
	for col = 0, GridConfig.GRID_COLUMNS do
		local x = config.GridCornerA.X + col * cellW
		local startZ = config.GridCornerA.Z
		local endZ = config.GridCornerB.Z

		createLine(Vector3.new(x, y, startZ), Vector3.new(x, y, endZ), folder)
	end

	-- Horizontal lines (lanes)
	for lane = 0, GridConfig.GRID_LANES do
		local z = config.GridCornerA.Z + lane * cellD
		local startX = config.GridCornerA.X
		local endX = config.GridCornerB.X

		createLine(Vector3.new(startX, y, z), Vector3.new(endX, y, z), folder)
	end

	Logger.Info("GridVisualization", "Grid created", {
		Columns = GridConfig.GRID_COLUMNS,
		Lanes = GridConfig.GRID_LANES,
		CellSize = cellW,
		GridY = y,
		UsingVisualConfig = config.UsingVisualConfig,
	})
end

local function destroyGrid()
	if _gridFolder then
		_gridFolder:Destroy()
		_gridFolder = nil
	end
end

--------------------------------------------------------------------------------
-- SYSTEM FUNCTION
--------------------------------------------------------------------------------
local function GridVisualizationSystem(_world: any)
	-- Initialize network listeners and grid once via useMemo
	Hooks.useMemo(function()
		-- Listen for MapConfigSync from server (event-driven, not polling!)
		_trove:Add(Network.MapConfigSync.On(function(data)
			Logger.Info("GridVisualization", `MapConfigSync received, creating grid`)
			-- MapConfig.ApplyFromServer is called by init.client.luau
			-- We just need to wait a frame for it to be applied
			task.defer(function()
				createGrid()
			end)
		end))

		-- IMPORTANT: Do NOT create grid if MapConfig was initialized locally
		-- We MUST wait for server's MapConfigSync to ensure correct GridY
		-- Only create grid when config comes from server (UsingVisualConfig + correct GridY)
		if MapConfig.IsInitialized() and MapConfig.IsUsingVisualConfig() then
			local config = MapConfig.GetConfig()
			-- Sanity check: GridY should be positive (above ground)
			if config.GridY > 0 then
				Logger.Info("GridVisualization", "MapConfig already synced from server, creating grid")
				createGrid()
			else
				Logger.Warn(
					"GridVisualization",
					`Skipping grid creation - suspicious GridY={config.GridY}, waiting for server sync`
				)
			end
		end

		Logger.Debug("GridVisualizationSystem", "Initialized with MapConfigSync listener")
		return true
	end, {})

	-- No per-frame updates needed
	-- Grid is static, created during initialization
end

--------------------------------------------------------------------------------
-- MODULE EXPORT
--------------------------------------------------------------------------------
return {
	priority = 350,
	system = GridVisualizationSystem,
}
