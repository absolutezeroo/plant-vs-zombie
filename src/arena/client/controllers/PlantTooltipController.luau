--!strict
--[[
	PlantTooltipController.luau - Manages plant tooltip display on click
	
	Handles:
	- Click detection on placed plants (when not in placement/shovel mode)
	- Showing/hiding the PlantTooltip component
	- Getting plant data from entity attributes
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PlantData = require(Shared.data.PlantData)

-- Client modules
local Client = script.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

-- Systems (for data access)
local Systems = Client:WaitForChild("systems")
local PlantRenderSystem = require(Systems.rendering.PlantRenderSystem)

-- UI Components
local UI = Client:WaitForChild("ui")
local Components = UI:WaitForChild("components")
local PlantTooltip = require(Components.molecules.PlantTooltip)

-- Fusion primitives
local New = Fusion.New
local peek = Fusion.peek

-- ============================================================
-- MODULE
-- ============================================================
local PlantTooltipController = {}

-- State
local _trove = Trove.new()
local _scope: any = nil
local _screenGui: ScreenGui? = nil
local _initialized = false

-- Reactive state for tooltip
local _tooltipVisible: any = nil
local _tooltipPosition: any = nil
local _selectedPlantType: any = nil
local _selectedMutations: any = nil
local _selectedEntityId: any = nil

-- ============================================================
-- PRIVATE FUNCTIONS
-- ============================================================

--[[
	Find plant model under mouse cursor
]]
local function getPlantUnderCursor(): Model?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {}

	local rayResult = Workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)

	if rayResult and rayResult.Instance then
		local current: Instance? = rayResult.Instance
		while current and current ~= Workspace do
			if current:IsA("Model") and current:GetAttribute("EntityId") then
				local entityId = current:GetAttribute("EntityId")
				if entityId and typeof(entityId) == "number" then
					-- Check if it's a plant (not zombie)
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
	Show tooltip for a plant
]]
local function showTooltip(plantModel: Model)
	if not _initialized then
		return
	end

	local entityId = plantModel:GetAttribute("EntityId") :: number?
	local plantType: string = plantModel:GetAttribute("PlantType") :: string? or plantModel.Name

	-- Get mutations from PlantRenderSystem cache (cleaner than model attributes)
	local mutationList: { string } = {}
	if entityId then
		mutationList = PlantRenderSystem.getMutations(entityId)
	end

	-- Remove "Plant_" prefix if present
	if string.find(plantType, "^Plant_") then
		plantType = string.sub(plantType, 7)
	end

	Logger.Debug("PlantTooltipController", `Showing tooltip for {plantType} (Entity #{entityId})`)

	-- Update reactive state
	_selectedPlantType:set(plantType)
	_selectedMutations:set(mutationList)
	_selectedEntityId:set(entityId)

	-- Position tooltip at center of screen (could be improved to follow mouse)
	_tooltipPosition:set(UDim2.fromScale(0.5, 0.5))
	_tooltipVisible:set(true)
end

--[[
	Hide the tooltip
]]
local function hideTooltip()
	if not _initialized then
		return
	end
	_tooltipVisible:set(false)
end

--[[
	Handle mouse click for plant selection
]]
local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	-- Only handle left click
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	-- Don't show tooltip if in placement, shovel, or Plant Food mode
	local selectedPlant = peek(SelectionState.SelectedPlant)
	local shovelMode = peek(SelectionState.ShovelMode)
	local plantFoodMode = SelectionState.IsPlantFoodActive()

	if selectedPlant or shovelMode or plantFoodMode then
		return
	end

	-- Check if tooltip is already visible (clicking to close)
	if peek(_tooltipVisible) then
		hideTooltip()
		return
	end

	-- Find plant under cursor
	local plantModel = getPlantUnderCursor()
	if plantModel then
		showTooltip(plantModel)
	end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

--[[
	Initialize the PlantTooltipController
]]
function PlantTooltipController.Initialize()
	if _initialized then
		Logger.Warn("PlantTooltipController", "Already initialized")
		return
	end

	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		Logger.Error("PlantTooltipController", "No LocalPlayer found")
		return
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")

	-- Create Fusion scope with Fusion methods (required for scope:Computed, scope:Value, etc.)
	_scope = Fusion.scoped(Fusion)

	-- Initialize reactive state
	_tooltipVisible = _scope:Value(false)
	_tooltipPosition = _scope:Value(UDim2.fromScale(0.5, 0.5))
	_selectedPlantType = _scope:Value(nil :: string?)
	_selectedMutations = _scope:Value({} :: { string })
	_selectedEntityId = _scope:Value(nil :: number?)

	-- Create ScreenGui for tooltip
	local screenGui = New(_scope, "ScreenGui")({
		Name = "PlantTooltipGui",
		Parent = playerGui,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			-- Click-away background (darkens screen)
			New(_scope, "TextButton")({
				Name = "Backdrop",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = _scope:Computed(function(use)
					return use(_tooltipVisible) and 0.5 or 1
				end),
				Text = "",
				Visible = _tooltipVisible,
				ZIndex = 1,

				[Fusion.OnEvent("Activated")] = hideTooltip,
			}),

			-- The tooltip
			PlantTooltip({
				Scope = _scope,
				PlantType = _selectedPlantType,
				Mutations = _selectedMutations,
				EntityId = _selectedEntityId,
				Position = _tooltipPosition,
				Visible = _tooltipVisible,
				OnClose = hideTooltip,
			}),
		},
	})
	_screenGui = screenGui :: ScreenGui

	-- Connect input events
	_trove:Connect(UserInputService.InputBegan, onInputBegan)

	_initialized = true
	Logger.Info("PlantTooltipController", "Initialized")
end

--[[
	Show tooltip for a specific plant (can be called externally)
]]
function PlantTooltipController.ShowForPlant(plantModel: Model)
	showTooltip(plantModel)
end

--[[
	Hide the tooltip
]]
function PlantTooltipController.Hide()
	hideTooltip()
end

--[[
	Check if tooltip is currently visible
]]
function PlantTooltipController.IsVisible(): boolean
	return _initialized and peek(_tooltipVisible) or false
end

--[[
	Dispose of the controller
]]
function PlantTooltipController.Dispose()
	if not _initialized then
		return
	end

	_trove:Destroy()
	_trove = Trove.new()

	if _scope then
		Fusion.doCleanup(_scope)
		_scope = nil
	end

	_screenGui = nil
	_initialized = false

	Logger.Info("PlantTooltipController", "Disposed")
end

return PlantTooltipController
