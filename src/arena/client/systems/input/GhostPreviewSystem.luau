--!strict
--[[
	GhostPreviewSystem.luau - Client-side plant placement preview
	
	Priority: 50 (Input phase)
	
	Shows a semi-transparent preview of the REAL plant model at cursor position.
	- Green tint = valid placement (cell empty, can afford)
	- Red tint = invalid placement (cell occupied, can't afford, out of bounds)
	
	Uses the actual plant model from Assets for better visual feedback.
	
	LIFECYCLE:
	- Init(): Setup input handlers & network listeners (CAN yield)
	- system(): Update ghost position each frame (CANNOT yield)
	- Dispose(): Disconnect events, cleanup ghost visuals
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Use FindFirstChild to avoid yielding (modules should exist from init.client.luau)
local Packages = ReplicatedStorage:FindFirstChild("Packages")
assert(Packages, "GhostPreviewSystem: Packages folder not found")
local Fusion = require(Packages.Fusion)
local Trove = require(Packages.Trove)

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "GhostPreviewSystem: Shared folder not found")
local MapConfig = require(Shared.config.MapConfig)
local GridUtils = require(Shared.utils.grid.GridUtils)
local PlantData = require(Shared.data.PlantData)
local PlantFoodData = require(Shared.data.PlantFoodData)
local Logger = require(Shared.utils.core.Logger)

-- Client root (script.Parent.Parent.Parent since we're in systems/input/)
local Client = script.Parent.Parent.Parent
local Modules = Client:FindFirstChild("modules")
assert(Modules, "GhostPreviewSystem: modules folder not found")
local SelectionState = require(Modules.SelectionState)
local Network = require(Shared.network.generated.client)

-- Assets (optional - game works without visual previews)
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local PlantAssets = Assets and Assets:FindFirstChild("Plants")

-- Warn once if assets missing
if not PlantAssets then
	Logger.Warn("GhostPreview", "Plant assets not found - ghost previews disabled")
end

-- Audio service (lazy loaded for sound feedback)
local _audioService: any = nil

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
local _pendingPlacements: { [number]: { plantType: string, cost: number } } = {}

-- Trove for cleanup (connections, instances)
local _trove = Trove.new()

-- Ghost visual state
local _ghostModel: Model? = nil
local _ghostPlantType: string? = nil -- Track which plant type is currently shown
local _currentCell: { Column: number, Lane: number }? = nil
local _isValid = false
local _warnedPlantTypes: { [string]: boolean } = {} -- Track warned plant types to avoid spam

-- Shovel/PlantFood highlight state
local _highlightedPlant: Model? = nil
local _highlightMode: string? = nil -- "Shovel" or "PlantFood" or "PlantFoodInvalid"
local _originalPartData: { [BasePart]: { Color: Color3, Material: Enum.Material, Transparency: number } } = {}

-- Colors
local VALID_COLOR = Color3.fromRGB(100, 255, 100) -- Green
local INVALID_COLOR = Color3.fromRGB(255, 100, 100) -- Red
local SHOVEL_COLOR = Color3.fromRGB(255, 80, 80) -- Red for shovel target
local PLANTFOOD_VALID_COLOR = Color3.fromRGB(255, 215, 0) -- Gold for valid PlantFood target
local PLANTFOOD_INVALID_COLOR = Color3.fromRGB(100, 100, 100) -- Gray for invalid PlantFood target
local GHOST_TRANSPARENCY = 0.5
local SHOVEL_TRANSPARENCY = 0.3
local PLANTFOOD_TRANSPARENCY = 0.2

-- Cache grid Y to avoid calling MapConfig.GetConfig() every frame (it can yield)
local _cachedGridY: number? = nil
local _cachedZombieDir: Vector3? = nil
local DEFAULT_GRID_Y = 4.5
local DEFAULT_ZOMBIE_DIR = Vector3.new(-1, 0, 0)
local function getCachedGridY(): number
	if _cachedGridY then
		return _cachedGridY
	end
	-- Try to get from MapConfig if already initialized (non-blocking check)
	local config = MapConfig.GetConfigIfReady and MapConfig.GetConfigIfReady()
	if config then
		_cachedGridY = config.GridY
		return config.GridY
	end
	-- Fallback to default grid Y
	return DEFAULT_GRID_Y
end

-- Get cached zombie direction (non-blocking)
local function getCachedZombieDir(): Vector3
	if _cachedZombieDir then
		return _cachedZombieDir
	end
	-- Try to get from MapConfig if already initialized (non-blocking check)
	if MapConfig.IsInitialized and MapConfig.IsInitialized() then
		local dir = MapConfig.GetZombieDirection()
		_cachedZombieDir = dir
		return dir
	end
	-- Fallback to default direction (don't cache so we retry next frame)
	return DEFAULT_ZOMBIE_DIR
end

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
	if not _ghostModel then
		return
	end

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
	if not PlantAssets then
		return nil
	end

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
	if not ghost then
		return
	end

	local worldPos = GridUtils.GridToWorld(column, lane)

	-- Calculate rotation based on zombie direction (same as PlantRenderSystem)
	local zombieDir = getCachedZombieDir()
	local facingDir = Vector3.new(-zombieDir.X, 0, -zombieDir.Z)
	local facingCFrame = CFrame.lookAt(worldPos, worldPos + facingDir)
	-- Add -90° rotation to correct model orientation (same as PlantRenderSystem)
	ghost:PivotTo(facingCFrame * CFrame.Angles(0, math.rad(-90), 0))

	-- Update color based on validity
	updateGhostColor(valid)

	_currentCell = { Column = column, Lane = lane }
	_isValid = valid
end

local function hideGhost()
	if _ghostModel then
		-- Move off-screen instead of destroying (for reuse)
		_ghostModel:PivotTo(CFrame.new(0, -1000, 0))
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

--[[
	Restore original appearance of highlighted plant
]]
local function restoreHighlightedPlant()
	if _highlightedPlant then
		for part, data in _originalPartData do
			if part and part.Parent then
				part.Color = data.Color
				part.Material = data.Material
				part.Transparency = data.Transparency
			end
		end
		_highlightedPlant = nil
		_highlightMode = nil
		table.clear(_originalPartData)
	end
end

--[[
	Apply highlight effect to a plant model with specified color
]]
local function applyHighlight(plantModel: Model, color: Color3, transparency: number, mode: string)
	-- If same plant and same mode, do nothing
	if _highlightedPlant == plantModel and _highlightMode == mode then
		return
	end

	-- Restore previous highlight
	restoreHighlightedPlant()

	-- Save original appearance and apply highlight
	_highlightedPlant = plantModel
	_highlightMode = mode
	for _, descendant in plantModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
			-- Save original
			_originalPartData[descendant] = {
				Color = descendant.Color,
				Material = descendant.Material,
				Transparency = descendant.Transparency,
			}
			-- Apply highlight
			descendant.Color = color
			descendant.Material = Enum.Material.Neon
			descendant.Transparency = transparency
		end
	end
end

--[[
	Apply shovel highlight effect to a plant model
]]
local function applyShovelHighlight(plantModel: Model)
	applyHighlight(plantModel, SHOVEL_COLOR, SHOVEL_TRANSPARENCY, "Shovel")
end

--[[
	Apply PlantFood highlight effect to a plant model
	Gold = valid (has PlantFood ability), Gray = invalid (no ability)
]]
local function applyPlantFoodHighlight(plantModel: Model, hasAbility: boolean)
	if hasAbility then
		applyHighlight(plantModel, PLANTFOOD_VALID_COLOR, PLANTFOOD_TRANSPARENCY, "PlantFood")
	else
		applyHighlight(plantModel, PLANTFOOD_INVALID_COLOR, PLANTFOOD_TRANSPARENCY, "PlantFoodInvalid")
	end
end

--[[
	Find plant model under cursor for shovel mode
]]
local function getPlantUnderCursor(): Model?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	-- Raycast all objects (plants are in Workspace root with EntityId attribute)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {} -- Hit everything

	local rayResult = Workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)

	if rayResult and rayResult.Instance then
		-- Find the plant model (parent with EntityId attribute)
		local current: Instance? = rayResult.Instance
		while current and current ~= Workspace do
			if current:IsA("Model") and current:GetAttribute("EntityId") then
				-- Verify it's a plant (not a zombie or other entity)
				local entityId = current:GetAttribute("EntityId")
				if entityId and typeof(entityId) == "number" then
					-- Check if name starts with Plant_ or matches plant types
					local name = current.Name
					if name:find("^Plant_") or PlantData[name] then
						return current :: Model
					end
				end
			end
			current = current.Parent
		end
	end

	return nil
end

--[[
	Update shovel preview - highlight plant under cursor
]]
local function updateShovelPreview()
	local plantModel = getPlantUnderCursor()

	if plantModel then
		applyShovelHighlight(plantModel)
	else
		restoreHighlightedPlant()
	end
end

--[[
	Update PlantFood preview - highlight plant under cursor
	Gold = has PlantFood ability, Gray = no ability defined
]]
local function updatePlantFoodPreview()
	local plantModel = getPlantUnderCursor()

	if plantModel then
		local plantType = plantModel:GetAttribute("PlantType")
		local hasAbility = false
		
		if plantType and typeof(plantType) == "string" then
			hasAbility = PlantFoodData.GetAbility(plantType) ~= nil
		end
		
		applyPlantFoodHighlight(plantModel, hasAbility)
	else
		restoreHighlightedPlant()
	end
end

local function getMouseWorldPosition(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	-- Raycast to grid plane (Y = actual grid height from MapConfig)
	local gridY = getCachedGridY()
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
	-- In shovel mode, show red highlight on targeted plant
	if SelectionState.IsShovelActive() then
		hideGhost()
		updateShovelPreview()
		return
	end

	-- In PlantFood mode, show gold/gray highlight on targeted plant
	if SelectionState.IsPlantFoodActive() then
		hideGhost()
		updatePlantFoodPreview()
		return
	end

	-- Not in special mode, restore any highlighted plant
	restoreHighlightedPlant()

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

-- Handle shovel click - find plant at clicked position and send removal request
local function handleShovel()
	if not SelectionState.IsShovelActive() then
		return
	end

	-- Get mouse world position
	local worldPos = getMouseWorldPosition()
	if not worldPos then
		return
	end

	-- Convert to grid coordinates
	local column, lane = GridUtils.WorldToGrid(worldPos)
	if not column or not lane or not GridUtils.IsValidCell(column, lane) then
		Logger.Debug("GhostPreview", "Shovel: clicked outside grid")
		return
	end

	-- Find plant model under cursor (reuse the same logic as preview)
	local plantModel = getPlantUnderCursor()

	if plantModel then
		local entityId = plantModel:GetAttribute("EntityId")
		if entityId and typeof(entityId) == "number" then
			Logger.Info("GhostPreview", `Shovel: removing plant entity {entityId}`)

			-- Clear highlight state (plant will be destroyed by server)
			_highlightedPlant = nil
			table.clear(_originalPartData)

			-- Send shovel request to server
			_requestId = (_requestId + 1) % 65535
			Network.ShovelPlantRequest.Fire({
				RequestId = _requestId,
				PlantEntityId = entityId,
			})

			-- Play shovel sound
			local audio = getAudioService()
			if audio and audio.PlayShovel then
				audio.PlayShovel()
			elseif audio and audio.PlayPlantPlaced then
				audio.PlayPlantPlaced() -- Fallback
			end

			-- Deactivate shovel mode after use
			SelectionState.DeactivateShovel()
			return
		end
	end

	-- No plant found at click location - play error sound
	Logger.Debug("GhostPreview", `Shovel: no plant found at grid ({column}, {lane})`)
	local audio = getAudioService()
	if audio and audio.PlayError then
		audio.PlayError()
	end
end

-- Handle Plant Food mode click - raycast at click moment for accuracy
local function handlePlantFood()
	if not SelectionState.IsPlantFoodActive() then
		return
	end

	-- Check if player has charges
	if not SelectionState.HasPlantFoodCharges() then
		Logger.Debug("GhostPreview", "PlantFood: no charges available")
		local audio = getAudioService()
		if audio and audio.PlayError then
			audio.PlayError()
		end
		return
	end

	-- Do fresh raycast at click moment (more accurate than stale _highlightedPlant)
	local plantModel = getPlantUnderCursor()
	
	-- Debug: compare with highlighted plant
	local highlightedId = if _highlightedPlant then _highlightedPlant:GetAttribute("EntityId") else nil
	local raycastId = if plantModel then plantModel:GetAttribute("EntityId") else nil
	Logger.Debug("GhostPreview", `PlantFood click: highlighted={highlightedId or "nil"}, raycast={raycastId or "nil"}`)

	if plantModel then
		local entityId = plantModel:GetAttribute("EntityId")
		local plantType = plantModel:GetAttribute("PlantType")
		
		if entityId and typeof(entityId) == "number" and plantType and typeof(plantType) == "string" then
			-- Check if plant has a PlantFood ability
			local ability = PlantFoodData.GetAbility(plantType)
			if not ability then
				Logger.Debug("GhostPreview", `PlantFood: {plantType} has no PlantFood ability`)
				local audio = getAudioService()
				if audio and audio.PlayError then
					audio.PlayError()
				end
				return
			end
			
			Logger.Info("GhostPreview", `PlantFood: activating {ability.Name} on plant entity {entityId} ({plantType})`)

			-- Optimistic update: use charge
			SelectionState.UsePlantFoodCharge()

			-- Send Plant Food request to server
			_requestId = (_requestId + 1) % 65535
			Network.PlantFoodRequest.Fire({
				PlantEntityId = entityId,
			})

			-- Play activation sound
			local audio = getAudioService()
			if audio and audio.PlayPlantPlaced then
				audio.PlayPlantPlaced() -- Use plant sound as placeholder
			end

			-- Deactivate Plant Food mode after use
			SelectionState.DeactivatePlantFood()
			return
		end
	end

	-- No plant found at click location - play error sound
	Logger.Debug("GhostPreview", "PlantFood: no plant found at cursor (raycast missed)")
	local audio = getAudioService()
	if audio and audio.PlayError then
		audio.PlayError()
	end
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
	if audio then
		audio.PlayPlantPlaced()
	end

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

	-- Map selected plant name to network enum
	-- The PlantType enum in Zap accepts string keys directly
	local plantTypeEnum = selectedPlant

	Network.PlacePlantRequest.Fire({
		RequestId = _requestId,
		PlantType = plantTypeEnum :: any,
		Lane = _currentCell.Lane :: any,
		Column = _currentCell.Column :: any,
	})

	hideGhost()
end

--[[
	Setup input handlers and network listeners (called during Init phase)
]]
local function setupListeners()
	-- Left-click / touch to place or shovel or Plant Food
	_trove:Connect(UserInputService.InputBegan, function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			-- Check modes in priority order: Shovel > PlantFood > Placement
			if SelectionState.IsShovelActive() then
				handleShovel()
			elseif SelectionState.IsPlantFoodActive() then
				handlePlantFood()
			else
				handlePlacement()
			end
		end
	end)

	-- Right-click or ESC to cancel selection, shovel mode, or Plant Food mode
	_trove:Connect(UserInputService.InputBegan, function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
			SelectionState.Select(nil)
			SelectionState.DeactivateShovel()
			SelectionState.DeactivatePlantFood()
			destroyGhost() -- Fully destroy when canceling
			restoreHighlightedPlant() -- Restore any highlighted plant
		end
	end)

	-- Handle placement response from server - refund on failure
	_trove:Add(Network.RequestResponse.On(function(data)
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
	end))
end

--[[
	Init - Setup input handlers and network listeners (CAN yield)
]]
local function Init(_world)
	-- Pre-cache MapConfig values if already synced from server
	if MapConfig.IsInitialized and MapConfig.IsInitialized() then
		_cachedZombieDir = MapConfig.GetZombieDirection()
		local config = MapConfig.GetConfigIfReady()
		if config and config.GridY > 0 then
			_cachedGridY = config.GridY
		end
	else
		-- Will use defaults until MapConfigSync arrives
		Logger.Debug("GhostPreview", "MapConfig not yet synced, using defaults")
	end

	-- Listen for MapConfigSync to update cached values when server sends config
	_trove:Add(Network.MapConfigSync.On(function(data)
		Logger.Debug("GhostPreview", `MapConfigSync received, updating cache: GridY={data.GridY}`)
		_cachedGridY = data.GridY
		_cachedZombieDir = Vector3.new(data.ZombieDirectionX, 0, data.ZombieDirectionZ).Unit
	end))

	setupListeners()
	Logger.Debug("GhostPreview", "Initialized")
end

--[[
	Dispose - Cleanup ghost visuals and connections
]]
local function Dispose()
	-- Trove handles all connection cleanup
	_trove:Destroy()
	_trove = Trove.new() -- Reset for potential reuse

	-- Cleanup ghost visuals
	destroyGhost()
	restoreHighlightedPlant()
	table.clear(_pendingPlacements)

	Logger.Debug("GhostPreview", "Disposed")
end

return {
	_name = "GhostPreviewSystem",
	priority = 50,
	system = GhostPreviewSystem,
	Init = Init,
	Dispose = Dispose,
}
