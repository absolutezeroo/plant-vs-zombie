--!strict
--[[
	GhostPreviewSystem.luau - Client-side plant placement preview
	
	Priority: 50 (Input phase)
	
	Shows a semi-transparent preview of the REAL plant model at cursor position.
	- Green tint = valid placement (cell empty, can afford)
	- Red tint = invalid placement (cell occupied, can't afford, out of bounds)
	
	Uses the actual plant model from Assets for better visual feedback.
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

-- Client root (script.Parent.Parent.Parent since we're in systems/input/)
local Client = script.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)
local Network = require(Client.network.generated)

-- Assets (optional - game works without visual previews)
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local PlantAssets = Assets and Assets:FindFirstChild("Plants")

-- Warn once if assets missing
if not PlantAssets then
	Logger.Warn("GhostPreview", "Plant assets not found - ghost previews disabled")
end

-- VFX/Audio services (lazy loaded)
local _vfxService: any = nil
local _audioService: any = nil

local function getVFXService()
	if not _vfxService then
		local success, result = pcall(function()
			return require(Modules.VFXService)
		end)
		if success then
			_vfxService = result
		end
	end
	return _vfxService
end

local function getAudioService()
	if not _audioService then
		local success, result = pcall(function()
			return require(Modules.AudioService)
		end)
		if success then
			_audioService = result
		end
	end
	return _audioService
end

-- Request ID counter
local _requestId = 0

-- Track pending placement requests for refund on failure
-- { [requestId]: { plantType: string, cost: number } }
local _pendingPlacements: {[number]: {plantType: string, cost: number}} = {}

-- Ghost visual state
local _ghostModel: Model? = nil
local _ghostPlantType: string? = nil  -- Track which plant type is currently shown
local _currentCell: {Column: number, Lane: number}? = nil
local _isValid = false
local _warnedPlantTypes: {[string]: boolean} = {} -- Track warned plant types to avoid spam

-- Colors
local VALID_COLOR = Color3.fromRGB(100, 255, 100)   -- Green
local INVALID_COLOR = Color3.fromRGB(255, 100, 100) -- Red
local GHOST_TRANSPARENCY = 0.5

--[[
	Apply ghost effect to all parts in a model (transparent + tinted)
]]
local function applyGhostEffect(model: Model, color: Color3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = GHOST_TRANSPARENCY
			descendant.Color = color
			descendant.Material = Enum.Material.Neon
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		end
	end
	-- Also apply to PrimaryPart if exists
	if model.PrimaryPart then
		model.PrimaryPart.Transparency = 1 -- Root is always invisible
	end
end

--[[
	Update ghost color based on validity
]]
local function updateGhostColor(valid: boolean)
	if not _ghostModel then return end
	
	local color = if valid then VALID_COLOR else INVALID_COLOR
	for _, descendant in _ghostModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
			descendant.Color = color
		end
	end
end

--[[
	Create ghost model from plant assets
]]
local function createGhostModel(plantType: string): Model?
	if not PlantAssets then return nil end
	
	local template = PlantAssets:FindFirstChild(plantType)
	if not template or not template:IsA("Model") then
		return nil
	end
	
	local ghost = template:Clone()
	ghost.Name = "PlantGhost_" .. plantType
	
	-- Apply ghost effect (transparent green)
	applyGhostEffect(ghost, VALID_COLOR)
	
	ghost.Parent = Workspace
	return ghost
end

--[[
	Ensure we have the correct ghost model for the selected plant
]]
local function ensureGhostModel(plantType: string): Model?
	-- If wrong plant type, destroy old ghost
	if _ghostModel and _ghostPlantType ~= plantType then
		_ghostModel:Destroy()
		_ghostModel = nil
		_ghostPlantType = nil
	end
	
	-- Create if needed
	if not _ghostModel then
		-- Skip if assets not available
		if not PlantAssets then
			return nil
		end
		
		_ghostModel = createGhostModel(plantType)
		_ghostPlantType = plantType
		
		if not _ghostModel then
			-- Only warn once per plant type
			if not _warnedPlantTypes[plantType] then
				Logger.Warn("GhostPreview", `Could not create ghost for {plantType}`)
				_warnedPlantTypes[plantType] = true
			end
		end
	end
	
	return _ghostModel
end

local function updateGhostPosition(column: number, lane: number, valid: boolean, plantType: string)
	local ghost = ensureGhostModel(plantType)
	if not ghost then return end
	
	local worldPos = GridUtils.GridToWorld(column, lane)
	
	-- Position using PrimaryPart with 180° rotation (same as PlantRenderSystem)
	if ghost.PrimaryPart then
		local facingRotation = CFrame.Angles(0, math.rad(180), 0)
		ghost:SetPrimaryPartCFrame(CFrame.new(worldPos) * facingRotation)
	end
	
	-- Update color based on validity
	updateGhostColor(valid)
	
	_currentCell = { Column = column, Lane = lane }
	_isValid = valid
end

local function hideGhost()
	if _ghostModel then
		-- Move off-screen instead of destroying (for reuse)
		if _ghostModel.PrimaryPart then
			_ghostModel:SetPrimaryPartCFrame(CFrame.new(0, -1000, 0))
		end
	end
	_currentCell = nil
	_isValid = false
end

local function destroyGhost()
	if _ghostModel then
		_ghostModel:Destroy()
		_ghostModel = nil
		_ghostPlantType = nil
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
	
	-- Update ghost visual with the real plant model
	updateGhostPosition(column, lane, isValid, selectedPlant)
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
	
	-- Play placement effects
	local audio = getAudioService()
	if audio then audio.PlayPlantPlaced() end
	
	-- Optimistic update: deduct sun, start cooldown
	SelectionState.DeductSun(stats.Cost)
	SelectionState.StartCooldown(selectedPlant, stats.Cooldown)
	SelectionState.Select(nil) -- Deselect after placement
	
	-- Send PlacePlant request to server via Zap
	_requestId = (_requestId + 1) % 65535
	
	-- Track this request for potential refund
	_pendingPlacements[_requestId] = {
		plantType = selectedPlant,
		cost = stats.Cost,
	}
	
	local plantTypeEnum = ({
		Peashooter = "Peashooter",
		Sunflower = "Sunflower",
		WallNut = "WallNut",
		SnowPea = "SnowPea",
		CherryBomb = "CherryBomb",
		PotatoMine = "PotatoMine",
		Repeater = "Repeater",
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
		destroyGhost() -- Fully destroy when canceling
	end
end)

-- Handle placement response from server - refund on failure
Network.RequestResponse.On(function(data)
	local pending = _pendingPlacements[data.RequestId]
	if not pending then
		return -- Not a placement request we're tracking
	end
	
	-- Remove from pending
	_pendingPlacements[data.RequestId] = nil
	
	if not data.Success then
		-- Refund the sun!
		SelectionState.AddSun(pending.cost)
		-- Cancel the cooldown
		SelectionState.CancelCooldown(pending.plantType)
		
		Logger.Warn("GhostPreview", `Placement failed (error {data.ErrorCode}), refunded {pending.cost} sun`)
	else
		Logger.Debug("GhostPreview", `Placement confirmed for {pending.plantType}`)
	end
end)

return {
	system = GhostPreviewSystem,
	priority = 50, -- Input phase
}
