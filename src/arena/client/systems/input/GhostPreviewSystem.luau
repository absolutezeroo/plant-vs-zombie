--!strict
--[[
	GhostPreviewSystem.luau - Client-side plant placement preview
	
	Priority: 50 (Input phase)
	
	Shows a semi-transparent preview of the REAL plant model at cursor position.
	- Green tint = valid placement (cell empty, can afford)
	- Red tint = invalid placement (cell occupied, can't afford, out of bounds)
	
	Uses the actual plant model from Assets for better visual feedback.
	Uses MatterHooks.useContextAction for mobile-first input handling.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Packages
local Packages = ReplicatedStorage:FindFirstChild("Packages")
assert(Packages, "GhostPreviewSystem: Packages folder not found")
local Fusion = require(Packages.Fusion)
local Trove = require(Packages.Trove)
local Hooks = require(Packages.MatterHooks)

-- Shared
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "GhostPreviewSystem: Shared folder not found")
local MapConfig = require(Shared.config.MapConfig)
local GridUtils = require(Shared.utils.grid.GridUtils)
local PlantData = require(Shared.data.PlantData)
local PlantFoodData = require(Shared.data.PlantFoodData)
local Logger = require(Shared.utils.core.Logger)

-- Client modules
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

--------------------------------------------------------------------------------
-- CONFIGURATION (Immutable)
--------------------------------------------------------------------------------
local CONFIG = table.freeze({
	-- Colors
	VALID_COLOR = Color3.fromRGB(100, 255, 100), -- Green
	INVALID_COLOR = Color3.fromRGB(255, 100, 100), -- Red
	SHOVEL_COLOR = Color3.fromRGB(255, 80, 80), -- Red for shovel target
	PLANTFOOD_VALID_COLOR = Color3.fromRGB(255, 215, 0), -- Gold for valid PlantFood target
	PLANTFOOD_INVALID_COLOR = Color3.fromRGB(100, 100, 100), -- Gray for invalid PlantFood target

	-- Transparency
	GHOST_TRANSPARENCY = 0.5,
	SHOVEL_TRANSPARENCY = 0.3,
	PLANTFOOD_TRANSPARENCY = 0.2,

	-- Grid defaults (used before MapConfig syncs)
	DEFAULT_GRID_Y = 4.5,
	DEFAULT_ZOMBIE_DIR = Vector3.new(-1, 0, 0),
})

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------
type GhostState = {
	-- Ghost visual
	GhostModel: Model?,
	GhostPlantType: string?,
	CurrentCell: { Column: number, Lane: number }?,
	IsValid: boolean,
	WarnedPlantTypes: { [string]: boolean },

	-- Highlight state
	HighlightedPlant: Model?,
	HighlightMode: string?, -- "Shovel" or "PlantFood" or "PlantFoodInvalid"
	OriginalPartData: { [BasePart]: { Color: Color3, Material: Enum.Material, Transparency: number } },

	-- Cached MapConfig values (avoid yield in system loop)
	CachedGridY: number?,
	CachedZombieDir: Vector3?,

	-- Network
	RequestId: number,
	PendingPlacements: { [number]: { plantType: string, cost: number } },

	-- Services (lazy loaded)
	AudioService: any?,
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS (Pure, no state access)
--------------------------------------------------------------------------------

-- Audio service (lazy loaded for sound feedback)
local function getAudioService(state: GhostState): any?
	if not state.AudioService then
		local success, result = pcall(function()
			return require(Modules.AudioService)
		end)
		if success then
			state.AudioService = result
		end
	end
	return state.AudioService
end

local function getCachedGridY(state: GhostState): number
	if state.CachedGridY then
		return state.CachedGridY
	end
	-- Try to get from MapConfig if already initialized (non-blocking check)
	local config = MapConfig.GetConfigIfReady and MapConfig.GetConfigIfReady()
	if config then
		state.CachedGridY = config.GridY
		return config.GridY
	end
	return CONFIG.DEFAULT_GRID_Y
end

local function getCachedZombieDir(state: GhostState): Vector3
	if state.CachedZombieDir then
		return state.CachedZombieDir
	end
	-- Try to get from MapConfig if already initialized (non-blocking check)
	if MapConfig.IsInitialized and MapConfig.IsInitialized() then
		local dir = MapConfig.GetZombieDirection()
		state.CachedZombieDir = dir
		return dir
	end
	return CONFIG.DEFAULT_ZOMBIE_DIR
end

--[[
	Apply ghost effect to all parts in a model (transparent + tinted)
]]
local function applyGhostEffect(model: Model, color: Color3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = CONFIG.GHOST_TRANSPARENCY
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
local function updateGhostColor(state: GhostState, valid: boolean)
	if not state.GhostModel then
		return
	end

	local color = if valid then CONFIG.VALID_COLOR else CONFIG.INVALID_COLOR
	for _, descendant in state.GhostModel:GetDescendants() do
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
	applyGhostEffect(ghost, CONFIG.VALID_COLOR)

	ghost.Parent = Workspace
	return ghost
end

--[[
	Ensure we have the correct ghost model for the selected plant
]]
local function ensureGhostModel(state: GhostState, plantType: string): Model?
	-- If wrong plant type, destroy old ghost
	if state.GhostModel and state.GhostPlantType ~= plantType then
		state.GhostModel:Destroy()
		state.GhostModel = nil
		state.GhostPlantType = nil
	end

	-- Create if needed
	if not state.GhostModel then
		-- Skip if assets not available
		if not PlantAssets then
			return nil
		end

		state.GhostModel = createGhostModel(plantType)
		state.GhostPlantType = plantType

		if not state.GhostModel then
			-- Only warn once per plant type
			if not state.WarnedPlantTypes[plantType] then
				Logger.Warn("GhostPreview", `Could not create ghost for {plantType}`)
				state.WarnedPlantTypes[plantType] = true
			end
		end
	end

	return state.GhostModel
end

local function updateGhostPosition(state: GhostState, column: number, lane: number, valid: boolean, plantType: string)
	local ghost = ensureGhostModel(state, plantType)
	if not ghost then
		return
	end

	local worldPos = GridUtils.GridToWorld(column, lane)

	-- Calculate rotation based on zombie direction (same as PlantRenderSystem)
	local zombieDir = getCachedZombieDir(state)
	local facingDir = Vector3.new(-zombieDir.X, 0, -zombieDir.Z)
	local facingCFrame = CFrame.lookAt(worldPos, worldPos + facingDir)
	-- Add -90° rotation to correct model orientation (same as PlantRenderSystem)
	ghost:PivotTo(facingCFrame * CFrame.Angles(0, math.rad(-90), 0))

	-- Update color based on validity
	updateGhostColor(state, valid)

	state.CurrentCell = { Column = column, Lane = lane }
	state.IsValid = valid
end

local function hideGhost(state: GhostState)
	if state.GhostModel then
		-- Move off-screen instead of destroying (for reuse)
		state.GhostModel:PivotTo(CFrame.new(0, -1000, 0))
	end
	state.CurrentCell = nil
	state.IsValid = false
end

local function destroyGhost(state: GhostState)
	if state.GhostModel then
		state.GhostModel:Destroy()
		state.GhostModel = nil
		state.GhostPlantType = nil
	end
	state.CurrentCell = nil
	state.IsValid = false
end

--[[
	Restore original appearance of highlighted plant
]]
local function restoreHighlightedPlant(state: GhostState)
	if state.HighlightedPlant then
		for part, data in state.OriginalPartData do
			if part and part.Parent then
				part.Color = data.Color
				part.Material = data.Material
				part.Transparency = data.Transparency
			end
		end
		state.HighlightedPlant = nil
		state.HighlightMode = nil
		table.clear(state.OriginalPartData)
	end
end

--[[
	Apply highlight effect to a plant model with specified color
]]
local function applyHighlight(state: GhostState, plantModel: Model, color: Color3, transparency: number, mode: string)
	-- If same plant and same mode, do nothing
	if state.HighlightedPlant == plantModel and state.HighlightMode == mode then
		return
	end

	-- Restore previous highlight
	restoreHighlightedPlant(state)

	-- Save original appearance and apply highlight
	state.HighlightedPlant = plantModel
	state.HighlightMode = mode
	for _, descendant in plantModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
			-- Save original
			state.OriginalPartData[descendant] = {
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
local function applyShovelHighlight(state: GhostState, plantModel: Model)
	applyHighlight(state, plantModel, CONFIG.SHOVEL_COLOR, CONFIG.SHOVEL_TRANSPARENCY, "Shovel")
end

--[[
	Apply PlantFood highlight effect to a plant model
	Gold = valid (has PlantFood ability), Gray = invalid (no ability)
]]
local function applyPlantFoodHighlight(state: GhostState, plantModel: Model, hasAbility: boolean)
	if hasAbility then
		applyHighlight(state, plantModel, CONFIG.PLANTFOOD_VALID_COLOR, CONFIG.PLANTFOOD_TRANSPARENCY, "PlantFood")
	else
		applyHighlight(state, plantModel, CONFIG.PLANTFOOD_INVALID_COLOR, CONFIG.PLANTFOOD_TRANSPARENCY, "PlantFoodInvalid")
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
local function updateShovelPreview(state: GhostState)
	local plantModel = getPlantUnderCursor()

	if plantModel then
		applyShovelHighlight(state, plantModel)
	else
		restoreHighlightedPlant(state)
	end
end

--[[
	Update PlantFood preview - highlight plant under cursor
	Gold = has PlantFood ability, Gray = no ability defined
]]
local function updatePlantFoodPreview(state: GhostState)
	local plantModel = getPlantUnderCursor()

	if plantModel then
		local plantType = plantModel:GetAttribute("PlantType")
		local hasAbility = false

		if plantType and typeof(plantType) == "string" then
			hasAbility = PlantFoodData.GetAbility(plantType) ~= nil
		end

		applyPlantFoodHighlight(state, plantModel, hasAbility)
	else
		restoreHighlightedPlant(state)
	end
end

local function getMouseWorldPosition(state: GhostState): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	-- Raycast to grid plane (Y = actual grid height from MapConfig)
	local gridY = getCachedGridY(state)
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

	return true
end

--------------------------------------------------------------------------------
-- INPUT HANDLERS
--------------------------------------------------------------------------------

-- Handle shovel click - find plant at clicked position and send removal request
local function handleShovel(state: GhostState)
	if not SelectionState.IsShovelActive() then
		return
	end

	-- Get mouse world position
	local worldPos = getMouseWorldPosition(state)
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
			state.HighlightedPlant = nil
			table.clear(state.OriginalPartData)

			-- Send shovel request to server
			state.RequestId = (state.RequestId + 1) % 65535
			Network.ShovelPlantRequest.Fire({
				RequestId = state.RequestId,
				PlantEntityId = entityId,
			})

			-- Play shovel sound
			local audio = getAudioService(state)
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
	local audio = getAudioService(state)
	if audio and audio.PlayError then
		audio.PlayError()
	end
end

-- Handle Plant Food mode click - raycast at click moment for accuracy
local function handlePlantFood(state: GhostState)
	if not SelectionState.IsPlantFoodActive() then
		return
	end

	-- Check if player has charges
	if not SelectionState.HasPlantFoodCharges() then
		Logger.Debug("GhostPreview", "PlantFood: no charges available")
		local audio = getAudioService(state)
		if audio and audio.PlayError then
			audio.PlayError()
		end
		return
	end

	-- Do fresh raycast at click moment (more accurate than stale _highlightedPlant)
	local plantModel = getPlantUnderCursor()

	-- Debug: compare with highlighted plant
	local highlightedId = if state.HighlightedPlant then state.HighlightedPlant:GetAttribute("EntityId") else nil
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
				local audio = getAudioService(state)
				if audio and audio.PlayError then
					audio.PlayError()
				end
				return
			end

			Logger.Info("GhostPreview", `PlantFood: activating {ability.Name} on plant entity {entityId} ({plantType})`)

			-- Optimistic update: use charge
			SelectionState.UsePlantFoodCharge()

			-- Send Plant Food request to server
			state.RequestId = (state.RequestId + 1) % 65535
			Network.PlantFoodRequest.Fire({
				PlantEntityId = entityId,
			})

			-- Play activation sound
			local audio = getAudioService(state)
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
	local audio = getAudioService(state)
	if audio and audio.PlayError then
		audio.PlayError()
	end
end

-- Handle click/tap to place
local function handlePlacement(state: GhostState)
	local selectedPlant = Fusion.peek(SelectionState.SelectedPlant)
	if not selectedPlant or not state.CurrentCell or not state.IsValid then
		return
	end

	local stats = PlantData[selectedPlant]
	if not stats then
		return
	end

	Logger.Info("GhostPreview", `Placement requested: {selectedPlant} at ({state.CurrentCell.Column}, {state.CurrentCell.Lane})`)

	-- Play placement effects
	local audio = getAudioService(state)
	if audio then
		audio.PlayPlantPlaced()
	end

	-- Optimistic update: deduct sun, start cooldown
	SelectionState.DeductSun(stats.Cost)
	SelectionState.StartCooldown(selectedPlant, stats.Cooldown)
	SelectionState.Select(nil) -- Deselect after placement

	-- Send PlacePlant request to server via Zap
	state.RequestId = (state.RequestId + 1) % 65535

	-- Track this request for potential refund
	state.PendingPlacements[state.RequestId] = {
		plantType = selectedPlant,
		cost = stats.Cost,
	}

	-- Map selected plant name to network enum
	local plantTypeEnum = selectedPlant

	Network.PlacePlantRequest.Fire({
		RequestId = state.RequestId,
		PlantType = plantTypeEnum :: any,
		Lane = state.CurrentCell.Lane :: any,
		Column = state.CurrentCell.Column :: any,
	})

	hideGhost(state)
end

-- Handle cancel (right-click or ESC)
local function handleCancel(state: GhostState)
	SelectionState.Select(nil)
	SelectionState.DeactivateShovel()
	SelectionState.DeactivatePlantFood()
	destroyGhost(state)
	restoreHighlightedPlant(state)
end

--------------------------------------------------------------------------------
-- SYSTEM FUNCTION
--------------------------------------------------------------------------------
local function GhostPreviewSystem(_world)
	-- State managed via Hooks.useMap
	local state = Hooks.useMap("GhostPreviewState", {
		-- Ghost visual
		GhostModel = nil :: Model?,
		GhostPlantType = nil :: string?,
		CurrentCell = nil :: { Column: number, Lane: number }?,
		IsValid = false,
		WarnedPlantTypes = {} :: { [string]: boolean },

		-- Highlight state
		HighlightedPlant = nil :: Model?,
		HighlightMode = nil :: string?,
		OriginalPartData = {} :: { [BasePart]: { Color: Color3, Material: Enum.Material, Transparency: number } },

		-- Cached MapConfig values
		CachedGridY = nil :: number?,
		CachedZombieDir = nil :: Vector3?,

		-- Network
		RequestId = 0,
		PendingPlacements = {} :: { [number]: { plantType: string, cost: number } },

		-- Services
		AudioService = nil :: any?,
	}).value :: GhostState

	-- Initialize network listeners once via useMemo
	Hooks.useMemo(function()
		local trove = Trove.new()

		-- Pre-cache MapConfig values if already synced from server
		if MapConfig.IsInitialized and MapConfig.IsInitialized() then
			state.CachedZombieDir = MapConfig.GetZombieDirection()
			local config = MapConfig.GetConfigIfReady()
			if config and config.GridY > 0 then
				state.CachedGridY = config.GridY
			end
		else
			Logger.Debug("GhostPreview", "MapConfig not yet synced, using defaults")
		end

		-- Listen for MapConfigSync to update cached values when server sends config
		trove:Add(Network.MapConfigSync.On(function(data)
			Logger.Debug("GhostPreview", `MapConfigSync received, updating cache: GridY={data.GridY}`)
			state.CachedGridY = data.GridY
			state.CachedZombieDir = Vector3.new(data.ZombieDirectionX, 0, data.ZombieDirectionZ).Unit
		end))

		-- Handle placement response from server - refund on failure
		trove:Add(Network.RequestResponse.On(function(data)
			local pending = state.PendingPlacements[data.RequestId]
			if not pending then
				return -- Not a placement request we're tracking
			end

			-- Remove from pending
			state.PendingPlacements[data.RequestId] = nil

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

		Logger.Debug("GhostPreview", "Initialized via useMemo")

		return trove
	end, {})

	-- Primary action (Left-click / Touch): Place, Shovel, or PlantFood
	Hooks.useContextAction(
		"GhostPreview_PrimaryAction",
		function(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end

			-- Check modes in priority order: Shovel > PlantFood > Placement
			if SelectionState.IsShovelActive() then
				handleShovel(state)
				return Enum.ContextActionResult.Sink
			elseif SelectionState.IsPlantFoodActive() then
				handlePlantFood(state)
				return Enum.ContextActionResult.Sink
			else
				-- Only sink if we have a plant selected
				local selectedPlant = Fusion.peek(SelectionState.SelectedPlant)
				if selectedPlant then
					handlePlacement(state)
					return Enum.ContextActionResult.Sink
				end
			end

			return Enum.ContextActionResult.Pass
		end,
		{
			createButton = false,
			inputTypes = {
				Enum.UserInputType.MouseButton1,
				Enum.UserInputType.Touch,
			},
		}
	)

	-- Cancel action (Right-click): Cancel selection/mode
	Hooks.useContextAction(
		"GhostPreview_CancelAction",
		function(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end

			-- Only handle if we have something active
			local selectedPlant = Fusion.peek(SelectionState.SelectedPlant)
			if selectedPlant or SelectionState.IsShovelActive() or SelectionState.IsPlantFoodActive() then
				handleCancel(state)
				return Enum.ContextActionResult.Sink
			end

			return Enum.ContextActionResult.Pass
		end,
		{
			createButton = false,
			inputTypes = {
				Enum.UserInputType.MouseButton2,
			},
		}
	)

	-- Escape key for cancel
	Hooks.useContextAction(
		"GhostPreview_EscapeAction",
		function(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end

			-- Only handle if we have something active
			local selectedPlant = Fusion.peek(SelectionState.SelectedPlant)
			if selectedPlant or SelectionState.IsShovelActive() or SelectionState.IsPlantFoodActive() then
				handleCancel(state)
				return Enum.ContextActionResult.Sink
			end

			return Enum.ContextActionResult.Pass
		end,
		{
			createButton = false,
			inputTypes = {
				Enum.KeyCode.Escape,
			},
		}
	)

	-- Update ghost/highlight each frame based on current mode
	if SelectionState.IsShovelActive() then
		hideGhost(state)
		updateShovelPreview(state)
		return
	end

	if SelectionState.IsPlantFoodActive() then
		hideGhost(state)
		updatePlantFoodPreview(state)
		return
	end

	-- Not in special mode, restore any highlighted plant
	restoreHighlightedPlant(state)

	local selectedPlant = Fusion.peek(SelectionState.SelectedPlant)

	-- No plant selected, hide ghost
	if not selectedPlant then
		hideGhost(state)
		return
	end

	-- Get mouse world position
	local worldPos = getMouseWorldPosition(state)
	if not worldPos then
		hideGhost(state)
		return
	end

	-- Convert to grid coordinates
	local column, lane = GridUtils.WorldToGrid(worldPos)
	if not column or not lane then
		hideGhost(state)
		return
	end

	-- Check validity
	local isValid = checkPlacementValid(column, lane, selectedPlant)

	-- Update ghost visual with the real plant model
	updateGhostPosition(state, column, lane, isValid, selectedPlant)
end

--------------------------------------------------------------------------------
-- EXPORT
--------------------------------------------------------------------------------
return {
	priority = 50,
	system = GhostPreviewSystem,
}
