--!strict
--[[
	PlantTooltipController.luau - Manages plant tooltip display on click (Lobby version)
	
	Handles:
	- Showing/hiding the PlantTooltip component when clicking on deck cards
	- Displaying plant stats and mutations
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- UI Components
local Client = script.Parent.Parent
local UI = Client:WaitForChild("ui")
local Components = UI:WaitForChild("components")
local PlantTooltip = require(Components.molecules.PlantTooltip)

-- Fusion primitives
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

-- ============================================================
-- PRIVATE FUNCTIONS
-- ============================================================

--[[
	Hide the tooltip
]]
local function hideTooltip()
	if not _initialized then
		return
	end
	_tooltipVisible:set(false)
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

	-- Create Fusion scope
	_scope = Fusion.scoped(Fusion)

	-- Initialize reactive state (using scope:Value() syntax)
	_tooltipVisible = _scope:Value(false)
	_tooltipPosition = _scope:Value(UDim2.fromScale(0.5, 0.5))
	_selectedPlantType = _scope:Value(nil :: string?)
	_selectedMutations = _scope:Value({} :: { string })

	-- Create ScreenGui for tooltip
	local screenGui = _scope:New("ScreenGui")({
		Name = "PlantTooltipGui",
		Parent = playerGui,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			-- Click-away background (darkens screen)
			_scope:New("TextButton")({
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
				Position = _tooltipPosition,
				Visible = _tooltipVisible,
				OnClose = hideTooltip,
			}),
		},
	})
	_screenGui = screenGui :: ScreenGui

	_initialized = true
	Logger.Info("PlantTooltipController", "Initialized")
end

--[[
	Show tooltip for a specific plant type with mutations
]]
function PlantTooltipController.ShowForPlant(plantType: string, mutations: { string }?)
	if not _initialized then
		Logger.Warn("PlantTooltipController", "Not initialized")
		return
	end

	Logger.Debug("PlantTooltipController", `Showing tooltip for {plantType}`)

	-- Update reactive state
	_selectedPlantType:set(plantType)
	_selectedMutations:set(mutations or {})

	-- Position tooltip at center of screen
	_tooltipPosition:set(UDim2.fromScale(0.5, 0.5))
	_tooltipVisible:set(true)
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
