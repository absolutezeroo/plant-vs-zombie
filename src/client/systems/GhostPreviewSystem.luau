--!strict
--[[
	GhostPreviewSystem.luau - Client-side plant placement preview
	
	Priority: 50 (Input phase)
	
	Shows a semi-transparent preview of the selected plant at cursor position.
	- Green = valid placement (cell empty, can afford)
	- Red = invalid placement (cell occupied, can't afford, out of bounds)
	
	Uses mouse/touch position raycasted onto the grid plane.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)
local GridUtils = require(Shared.utils.GridUtils)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

local Client = script.Parent.Parent
local SelectionState = require(Client.modules.SelectionState)
local Network = require(Client.network.generated)

-- Request ID counter
local _requestId = 0

-- Ghost visual state
local _ghostPart: Part? = nil
local _currentCell: {Column: number, Lane: number}? = nil
local _isValid = false

-- Colors
local VALID_COLOR = Color3.fromRGB(100, 255, 100)   -- Green
local INVALID_COLOR = Color3.fromRGB(255, 100, 100) -- Red
local GHOST_TRANSPARENCY = 0.5
local GHOST_SIZE = Vector3.new(4, 4, 4)

local function createGhostPart(): Part
	local part = Instance.new("Part")
	part.Name = "PlantGhost"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = GHOST_SIZE
	part.Transparency = GHOST_TRANSPARENCY
	part.Color = VALID_COLOR
	part.Parent = Workspace
	return part
end

local function updateGhostVisibility(visible: boolean)
	if _ghostPart then
		_ghostPart.Transparency = visible and GHOST_TRANSPARENCY or 1
	end
end

local function updateGhostPosition(column: number, lane: number, valid: boolean)
	if not _ghostPart then
		_ghostPart = createGhostPart()
	end
	
	local worldPos = GridUtils.GridToWorld(column, lane)
	_ghostPart.Position = worldPos + Vector3.new(0, 2, 0) -- Raise above ground
	_ghostPart.Color = valid and VALID_COLOR or INVALID_COLOR
	_ghostPart.Transparency = GHOST_TRANSPARENCY
	
	_currentCell = { Column = column, Lane = lane }
	_isValid = valid
end

local function hideGhost()
	if _ghostPart then
		_ghostPart.Transparency = 1
	end
	_currentCell = nil
	_isValid = false
end

local function getMouseWorldPosition(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	
	-- Raycast to grid plane (Y = 0)
	local gridY = GridConfig.GRID_ORIGIN_Y
	if ray.Direction.Y >= 0 then
		return nil -- Looking up, no intersection
	end
	
	local t = (gridY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	
	return ray.Origin + ray.Direction * t
end

-- Check if placement would be valid
local function checkPlacementValid(column: number, lane: number, plantType: string): boolean
	-- Check bounds
	if not GridUtils.IsValidCell(column, lane) then
		return false
	end
	
	-- Check if can afford
	local stats = PlantData[plantType]
	if not stats then
		return false
	end
	
	if not SelectionState.CanAfford(stats.Cost) then
		return false
	end
	
	-- Check cooldown
	if SelectionState.IsOnCooldown(plantType) then
		return false
	end
	
	-- Note: Cell occupancy check requires server state
	-- For now, client optimistically assumes empty (server validates)
	-- In future, we'd sync occupied cells from server
	
	return true
end

local function GhostPreviewSystem(world)
	local selectedPlant = Fusion.peek(SelectionState.SelectedPlant)
	
	-- No plant selected, hide ghost
	if not selectedPlant then
		hideGhost()
		return
	end
	
	-- Get mouse world position
	local worldPos = getMouseWorldPosition()
	if not worldPos then
		hideGhost()
		return
	end
	
	-- Convert to grid coordinates
	local column, lane = GridUtils.WorldToGrid(worldPos)
	if not column or not lane then
		hideGhost()
		return
	end
	
	-- Check validity
	local isValid = checkPlacementValid(column, lane, selectedPlant)
	
	-- Update ghost visual
	updateGhostPosition(column, lane, isValid)
end

-- Handle click/tap to place
local function handlePlacement()
	local selectedPlant = Fusion.peek(SelectionState.SelectedPlant)
	if not selectedPlant or not _currentCell or not _isValid then
		return
	end
	
	local stats = PlantData[selectedPlant]
	if not stats then
		return
	end
	
	Logger.Info("GhostPreview", `Placement requested: {selectedPlant} at ({_currentCell.Column}, {_currentCell.Lane})`)
	
	-- Optimistic update: deduct sun, start cooldown
	SelectionState.DeductSun(stats.Cost)
	SelectionState.StartCooldown(selectedPlant, stats.Cooldown)
	SelectionState.Select(nil) -- Deselect after placement
	
	-- Send PlacePlant request to server via Zap
	_requestId = (_requestId + 1) % 65535
	
	local plantTypeEnum = ({
		Peashooter = "Peashooter",
		Sunflower = "Sunflower",
		WallNut = "WallNut",
		SnowPea = "SnowPea",
		CherryBomb = "CherryBomb",
		PotatoMine = "PotatoMine"
	})[selectedPlant] or "Peashooter"
	
	Network.PlacePlantRequest.Fire({
		RequestId = _requestId,
		PlantType = plantTypeEnum :: any,
		Lane = _currentCell.Lane :: any,
		Column = _currentCell.Column :: any,
	})
	
	hideGhost()
end

-- Connect input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 
		or input.UserInputType == Enum.UserInputType.Touch then
		handlePlacement()
	end
end)

-- Right-click or ESC to cancel selection
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton2
		or input.KeyCode == Enum.KeyCode.Escape then
		SelectionState.Select(nil)
		hideGhost()
	end
end)

return {
	system = GhostPreviewSystem,
	priority = 50, -- Input phase
}
