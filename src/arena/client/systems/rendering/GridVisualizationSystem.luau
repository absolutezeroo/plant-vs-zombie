--!strict
--[[
	GridVisualizationSystem.luau - Renders debug grid lines
	
	Priority: 350 (Presentation phase)
	
	Creates cyan debug lines showing the 9×5 grid.
	Only runs once on initialization, then cleans up.
	Toggle with DEBUG_GRID_VISIBLE constant.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local Logger = require(Shared.utils.Logger)

-- Configuration
local DEBUG_GRID_VISIBLE = true
local GRID_COLOR = Color3.fromRGB(0, 255, 255) -- Cyan
local GRID_LINE_THICKNESS = 0.1
local GRID_LINE_HEIGHT = 0.05 -- Slightly above ground

-- State
local _initialized = false
local _gridFolder: Folder? = nil

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
	
	-- Vertical lines (columns)
	for col = 0, GridConfig.GRID_COLUMNS do
		local x = config.GridCornerA.X + col * cellW
		local startZ = config.GridCornerA.Z
		local endZ = config.GridCornerB.Z
		
		createLine(
			Vector3.new(x, y, startZ),
			Vector3.new(x, y, endZ),
			folder
		)
	end
	
	-- Horizontal lines (lanes)
	for lane = 0, GridConfig.GRID_LANES do
		local z = config.GridCornerA.Z + lane * cellD
		local startX = config.GridCornerA.X
		local endX = config.GridCornerB.X
		
		createLine(
			Vector3.new(startX, y, z),
			Vector3.new(endX, y, z),
			folder
		)
	end
	
	Logger.Info("GridVisualization", "Grid created", {
		Columns = GridConfig.GRID_COLUMNS,
		Lanes = GridConfig.GRID_LANES,
		CellSize = cellW,
		UsingVisualConfig = config.UsingVisualConfig,
	})
end

local function destroyGrid()
	if _gridFolder then
		_gridFolder:Destroy()
		_gridFolder = nil
	end
end

local function GridVisualizationSystem(world)
	-- Only initialize once
	if _initialized then
		return
	end
	
	_initialized = true
	
	if DEBUG_GRID_VISIBLE then
		createGrid()
	end
end

-- Cleanup function for hot-reloading
local function cleanup()
	destroyGrid()
	_initialized = false
end

return {
	system = GridVisualizationSystem,
	priority = 350, -- Presentation phase
	cleanup = cleanup,
}
