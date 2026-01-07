--!strict
--[[
	MapConfig.luau - Runtime map configuration from Workspace
	
	Reads visual markers placed in Studio to configure:
	- Grid bounds (from 2 corner Attachments)
	- Zombie spawn points (from lane Attachments)
	- Base/house position
	
	Expected Workspace structure:
	
	📁 ArenaMap (Model)
	├── 📍 GridBounds (Part - invisible, CanCollide=false)
	│   ├── 🔗 CornerA (Attachment) - Top-left corner of grid (Column 1, Lane 1)
	│   └── 🔗 CornerB (Attachment) - Bottom-right corner (Column 9, Lane 5)
	│
	├── 📁 ZombieSpawns (Folder)
	│   ├── 🔗 Lane1 (Attachment on Part) - Spawn point for lane 1
	│   ├── 🔗 Lane2 (Attachment)
	│   ├── 🔗 Lane3 (Attachment)
	│   ├── 🔗 Lane4 (Attachment)
	│   └── 🔗 Lane5 (Attachment)
	│
	└── 📍 BasePosition (Part with Attachment) - House/base to defend
	
	If ArenaMap is not found, falls back to GridConfig defaults.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)
local Logger = require(Shared.utils.Logger)

-- Cached configuration
local _isInitialized = false
local _config = {
	-- Grid bounds (world positions)
	GridCornerA = Vector3.zero,  -- Top-left (min X, min Z)
	GridCornerB = Vector3.zero,  -- Bottom-right (max X, max Z)
	GridOrigin = Vector3.zero,   -- Calculated origin (same as CornerA)
	GridY = 0,                   -- Ground level
	
	-- Calculated from corners
	CellWidth = GridConfig.CELL_SIZE,   -- X size per cell
	CellDepth = GridConfig.CELL_SIZE,   -- Z size per cell
	GridWidth = GridConfig.GRID_WIDTH,  -- Total X span
	GridDepth = GridConfig.GRID_HEIGHT, -- Total Z span
	
	-- Zombie spawn positions (per lane)
	ZombieSpawns = {} :: {[number]: Vector3},  -- Lane -> spawn position
	
	-- Base position
	BasePosition = Vector3.zero,
	
	-- Direction zombies walk (normalized)
	ZombieDirection = Vector3.new(-1, 0, 0),  -- Default: left
	
	-- Are we using visual config or defaults?
	UsingVisualConfig = false,
}

export type MapConfigType = typeof(_config)

local MapConfig = {}

--[[
	Initialize configuration from Workspace
	Call this at server start before any grid operations
]]
function MapConfig.Initialize()
	if _isInitialized then
		Logger.Warn("MapConfig", "Already initialized")
		return
	end
	
	-- Use WaitForChild with timeout to handle streaming/load order
	local arenaMap = Workspace:WaitForChild("ArenaMap", 10)
	
	if not arenaMap then
		Logger.Info("MapConfig", "ArenaMap not found after WaitForChild, using GridConfig defaults")
		MapConfig._UseDefaults()
		_isInitialized = true
		return
	end
	
	Logger.Info("MapConfig", "Found ArenaMap, reading visual configuration...")
	
	-- Read grid bounds
	local success = MapConfig._ReadGridBounds(arenaMap)
	if not success then
		Logger.Warn("MapConfig", "Failed to read grid bounds, using defaults")
		MapConfig._UseDefaults()
		_isInitialized = true
		return
	end
	
	-- Read zombie spawns
	MapConfig._ReadZombieSpawns(arenaMap)
	
	-- Read base position
	MapConfig._ReadBasePosition(arenaMap)
	
	-- Calculate zombie direction
	MapConfig._CalculateZombieDirection()
	
	_config.UsingVisualConfig = true
	_isInitialized = true
	
	Logger.Info("MapConfig", `Initialized from visual config:`)
	Logger.Info("MapConfig", `  Grid: {_config.GridCornerA} to {_config.GridCornerB}`)
	Logger.Info("MapConfig", `  Cell size: {_config.CellWidth}x{_config.CellDepth}`)
	Logger.Info("MapConfig", `  Zombie lanes: {#_config.ZombieSpawns}`)
	Logger.Info("MapConfig", `  Direction: {_config.ZombieDirection}`)
end

-- Read grid bounds from CornerA and CornerB attachments
function MapConfig._ReadGridBounds(arenaMap: Instance): boolean
	-- Use WaitForChild with timeout to handle streaming
	local gridBounds = arenaMap:WaitForChild("GridBounds", 5)
	
	-- DEBUG: Log what we find
	if gridBounds then
		Logger.Debug("MapConfig", `GridBounds found: {gridBounds.ClassName}, IsBasePart={gridBounds:IsA("BasePart")}`)
	else
		Logger.Warn("MapConfig", "GridBounds is nil after WaitForChild - listing ArenaMap children:")
		for _, child in pairs(arenaMap:GetChildren()) do
			Logger.Warn("MapConfig", `  Child: {child.Name} ({child.ClassName})`)
		end
	end
	
	if not gridBounds or not gridBounds:IsA("BasePart") then
		Logger.Warn("MapConfig", "GridBounds Part not found in ArenaMap")
		return false
	end
	
	local cornerA = gridBounds:FindFirstChild("CornerA")
	local cornerB = gridBounds:FindFirstChild("CornerB")
	
	if not cornerA or not cornerA:IsA("Attachment") then
		Logger.Warn("MapConfig", "CornerA Attachment not found in GridBounds")
		return false
	end
	
	if not cornerB or not cornerB:IsA("Attachment") then
		Logger.Warn("MapConfig", "CornerB Attachment not found in GridBounds")
		return false
	end
	
	-- Get world positions
	local posA = cornerA.WorldPosition
	local posB = cornerB.WorldPosition
	
	-- Ensure CornerA is min and CornerB is max
	_config.GridCornerA = Vector3.new(
		math.min(posA.X, posB.X),
		math.min(posA.Y, posB.Y),
		math.min(posA.Z, posB.Z)
	)
	_config.GridCornerB = Vector3.new(
		math.max(posA.X, posB.X),
		math.max(posA.Y, posB.Y),
		math.max(posA.Z, posB.Z)
	)
	
	_config.GridOrigin = _config.GridCornerA
	_config.GridY = (_config.GridCornerA.Y + _config.GridCornerB.Y) / 2
	
	-- Calculate grid dimensions
	_config.GridWidth = _config.GridCornerB.X - _config.GridCornerA.X
	_config.GridDepth = _config.GridCornerB.Z - _config.GridCornerA.Z
	
	-- Calculate cell sizes (divide by column/lane count from GridConfig)
	_config.CellWidth = _config.GridWidth / GridConfig.GRID_COLUMNS
	_config.CellDepth = _config.GridDepth / GridConfig.GRID_LANES
	
	return true
end

-- Read zombie spawn positions from ZombieSpawns folder
-- Supports:
--   1. Part with Attachment inside -> uses Attachment.WorldPosition
--   2. Part alone -> uses Part.Position (center)
--   3. Attachment alone -> uses Attachment.WorldPosition
function MapConfig._ReadZombieSpawns(arenaMap: Instance)
	-- Use WaitForChild with timeout to handle streaming
	local spawnsFolder = arenaMap:WaitForChild("ZombieSpawns", 5)
	if not spawnsFolder then
		Logger.Warn("MapConfig", "ZombieSpawns folder not found, generating from grid edge")
		MapConfig._GenerateDefaultSpawns()
		return
	end
	
	-- Look for Lane1, Lane2, etc.
	for lane = 1, GridConfig.GRID_LANES do
		local laneName = "Lane" .. lane
		local laneMarker = spawnsFolder:FindFirstChild(laneName)
		
		if laneMarker then
			if laneMarker:IsA("Attachment") then
				-- Direct Attachment
				_config.ZombieSpawns[lane] = laneMarker.WorldPosition
				Logger.Debug("MapConfig", `  {laneName}: Attachment at {laneMarker.WorldPosition}`)
			elseif laneMarker:IsA("BasePart") then
				-- Part - check for child Attachment first
				local attachment = laneMarker:FindFirstChildOfClass("Attachment")
				if attachment then
					_config.ZombieSpawns[lane] = attachment.WorldPosition
					Logger.Debug("MapConfig", `  {laneName}: Part+Attachment at {attachment.WorldPosition}`)
				else
					-- Use Part center
					_config.ZombieSpawns[lane] = laneMarker.Position
					Logger.Debug("MapConfig", `  {laneName}: Part center at {laneMarker.Position}`)
				end
			else
				-- Unknown type, use default
				_config.ZombieSpawns[lane] = MapConfig._GetDefaultSpawnForLane(lane)
				Logger.Warn("MapConfig", `  {laneName}: Unknown type {laneMarker.ClassName}, using default`)
			end
		else
			_config.ZombieSpawns[lane] = MapConfig._GetDefaultSpawnForLane(lane)
			Logger.Debug("MapConfig", `  {laneName}: Not found, using default`)
		end
	end
	
	Logger.Info("MapConfig", `Read {#_config.ZombieSpawns} zombie spawn points`)
end

-- Generate spawn positions at right edge of grid + offset
function MapConfig._GenerateDefaultSpawns()
	for lane = 1, GridConfig.GRID_LANES do
		_config.ZombieSpawns[lane] = MapConfig._GetDefaultSpawnForLane(lane)
	end
end

function MapConfig._GetDefaultSpawnForLane(lane: number): Vector3
	local spawnOffset = 10 -- Spawn 10 studs past grid edge
	local x = _config.GridCornerB.X + spawnOffset
	local y = _config.GridY
	local z = _config.GridCornerA.Z + (lane - 0.5) * _config.CellDepth
	return Vector3.new(x, y, z)
end

-- Read base/house position
-- Supports: Attachment (direct or in Part), Part, or auto-deduce from spawns
function MapConfig._ReadBasePosition(arenaMap: Instance)
	-- Use WaitForChild with timeout to handle streaming
	local basePart = arenaMap:WaitForChild("BasePosition", 5)
	
	if basePart then
		if basePart:IsA("Attachment") then
			-- Direct Attachment - check if parent is a BasePart for proper WorldPosition
			if basePart.Parent:IsA("BasePart") then
				_config.BasePosition = basePart.WorldPosition
				Logger.Info("MapConfig", `BasePosition from Attachment: {_config.BasePosition}`)
			else
				-- Attachment without proper Part parent - use Position as world pos
				_config.BasePosition = basePart.Position
				Logger.Warn("MapConfig", `BasePosition Attachment has no Part parent, using Position: {_config.BasePosition}`)
			end
		elseif basePart:IsA("BasePart") then
			-- Part - check for child Attachment first
			local attachment = basePart:FindFirstChildOfClass("Attachment")
			if attachment then
				_config.BasePosition = attachment.WorldPosition
				Logger.Info("MapConfig", `BasePosition from Part+Attachment: {_config.BasePosition}`)
			else
				_config.BasePosition = basePart.Position
				Logger.Info("MapConfig", `BasePosition from Part center: {_config.BasePosition}`)
			end
		else
			MapConfig._DeduceBaseFromSpawns()
		end
	else
		MapConfig._DeduceBaseFromSpawns()
	end
	
	Logger.Debug("MapConfig", `Final base position: {_config.BasePosition}`)
end

-- Deduce base position: opposite side of grid from zombie spawns
function MapConfig._DeduceBaseFromSpawns()
	-- If we have spawns, base is on the opposite side of the grid
	if #_config.ZombieSpawns > 0 then
		local middleSpawn = _config.ZombieSpawns[3] or _config.ZombieSpawns[1]
		local gridCenterX = (_config.GridCornerA.X + _config.GridCornerB.X) / 2
		local gridCenterZ = (_config.GridCornerA.Z + _config.GridCornerB.Z) / 2
		
		-- Determine which edge the spawns are on (compare to grid center)
		local spawnOffsetX = middleSpawn.X - gridCenterX
		local spawnOffsetZ = middleSpawn.Z - gridCenterZ
		
		-- Base is on the opposite side
		if math.abs(spawnOffsetX) > math.abs(spawnOffsetZ) then
			-- Spawns are on X edge, base on opposite X edge
			if spawnOffsetX > 0 then
				-- Spawns on right (max X), base on left (min X)
				_config.BasePosition = Vector3.new(_config.GridCornerA.X - 5, _config.GridY, gridCenterZ)
			else
				-- Spawns on left (min X), base on right (max X)
				_config.BasePosition = Vector3.new(_config.GridCornerB.X + 5, _config.GridY, gridCenterZ)
			end
		else
			-- Spawns are on Z edge, base on opposite Z edge
			if spawnOffsetZ > 0 then
				_config.BasePosition = Vector3.new(gridCenterX, _config.GridY, _config.GridCornerA.Z - 5)
			else
				_config.BasePosition = Vector3.new(gridCenterX, _config.GridY, _config.GridCornerB.Z + 5)
			end
		end
		
		Logger.Info("MapConfig", `Deduced base position from spawns: {_config.BasePosition}`)
	else
		-- Fallback: left of grid
		_config.BasePosition = Vector3.new(_config.GridCornerA.X - 5, _config.GridY, (_config.GridCornerA.Z + _config.GridCornerB.Z) / 2)
	end
end

-- Calculate direction zombies should walk (from spawn to base)
function MapConfig._CalculateZombieDirection()
	if #_config.ZombieSpawns == 0 then
		_config.ZombieDirection = Vector3.new(-1, 0, 0)
		return
	end
	
	-- Use lane 3 (middle) spawn as reference
	local middleSpawn = _config.ZombieSpawns[3] or _config.ZombieSpawns[1]
	local directionToBase = (_config.BasePosition - middleSpawn)
	directionToBase = Vector3.new(directionToBase.X, 0, directionToBase.Z) -- Flatten Y
	
	if directionToBase.Magnitude > 0.01 then
		_config.ZombieDirection = directionToBase.Unit
	else
		_config.ZombieDirection = Vector3.new(-1, 0, 0)
	end
end

-- Use GridConfig defaults when no visual config found
function MapConfig._UseDefaults()
	_config.GridCornerA = Vector3.new(GridConfig.GRID_ORIGIN_X, GridConfig.GRID_ORIGIN_Y, GridConfig.GRID_ORIGIN_Z)
	_config.GridCornerB = Vector3.new(
		GridConfig.GRID_ORIGIN_X + GridConfig.GRID_WIDTH,
		GridConfig.GRID_ORIGIN_Y,
		GridConfig.GRID_ORIGIN_Z + GridConfig.GRID_HEIGHT
	)
	_config.GridOrigin = _config.GridCornerA
	_config.GridY = GridConfig.GRID_ORIGIN_Y
	_config.GridWidth = GridConfig.GRID_WIDTH
	_config.GridDepth = GridConfig.GRID_HEIGHT
	_config.CellWidth = GridConfig.CELL_SIZE
	_config.CellDepth = GridConfig.CELL_SIZE
	_config.ZombieDirection = Vector3.new(-1, 0, 0)
	_config.BasePosition = Vector3.new(GridConfig.GRID_ORIGIN_X - 5, GridConfig.GRID_ORIGIN_Y, GridConfig.GRID_ORIGIN_Z + GridConfig.GRID_HEIGHT / 2)
	
	MapConfig._GenerateDefaultSpawns()
	_config.UsingVisualConfig = false
end

--[[
	PUBLIC API
]]

-- Get grid to world position conversion
function MapConfig.GridToWorld(column: number, lane: number): Vector3
	if not _isInitialized then
		MapConfig.Initialize()
	end
	
	local x = _config.GridOrigin.X + (column - 0.5) * _config.CellWidth
	local y = _config.GridY
	local z = _config.GridOrigin.Z + (lane - 0.5) * _config.CellDepth
	
	return Vector3.new(x, y, z)
end

-- Get world to grid coordinate conversion
function MapConfig.WorldToGrid(position: Vector3): (number?, number?)
	if not _isInitialized then
		MapConfig.Initialize()
	end
	
	local relativeX = position.X - _config.GridOrigin.X
	local relativeZ = position.Z - _config.GridOrigin.Z
	
	-- Check bounds
	if relativeX < 0 or relativeX >= _config.GridWidth then
		return nil, nil
	end
	if relativeZ < 0 or relativeZ >= _config.GridDepth then
		return nil, nil
	end
	
	local column = math.floor(relativeX / _config.CellWidth) + 1
	local lane = math.floor(relativeZ / _config.CellDepth) + 1
	
	return column, lane
end

-- Get zombie spawn position for a lane
function MapConfig.GetZombieSpawn(lane: number): Vector3
	if not _isInitialized then
		MapConfig.Initialize()
	end
	
	return _config.ZombieSpawns[lane] or MapConfig._GetDefaultSpawnForLane(lane)
end

-- Get zombie movement direction
function MapConfig.GetZombieDirection(): Vector3
	if not _isInitialized then
		MapConfig.Initialize()
	end
	return _config.ZombieDirection
end

-- Get base position
function MapConfig.GetBasePosition(): Vector3
	if not _isInitialized then
		MapConfig.Initialize()
	end
	return _config.BasePosition
end

-- Get cell dimensions
function MapConfig.GetCellSize(): (number, number)
	if not _isInitialized then
		MapConfig.Initialize()
	end
	return _config.CellWidth, _config.CellDepth
end

-- Get grid origin
function MapConfig.GetGridOrigin(): Vector3
	if not _isInitialized then
		MapConfig.Initialize()
	end
	return _config.GridOrigin
end

-- Get full config (read-only)
function MapConfig.GetConfig(): MapConfigType
	if not _isInitialized then
		MapConfig.Initialize()
	end
	return _config
end

-- Check if using visual config
function MapConfig.IsUsingVisualConfig(): boolean
	return _config.UsingVisualConfig
end

-- Force re-read (for hot-reload during development)
function MapConfig.Reload()
	_isInitialized = false
	MapConfig.Initialize()
end

return MapConfig
