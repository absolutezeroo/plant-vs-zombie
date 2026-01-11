--!strict
--[[
	HUDController.luau - Main client UI entry point
	
	Initializes and mounts the GameHUD ScreenGui.
	Assembles atomic UI components into the game HUD layout.
	
	LAYOUT:
	- Top-Left: SunCounter (sun currency display)
	- Top-Center: SeedBank (plant selection deck)
	- Bottom-Center: ReadyButton (start wave, visible during preparation)
	- Bottom-Right: WaveProgressBar (wave progress indicator)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local Network = require(Shared.network.generated.client)

-- Client references (controllers is inside client)
local Client = script.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)
local PlayerDataClient = require(Modules.PlayerDataClient)

-- UI Components
local UI = Client:WaitForChild("ui")
local Design = UI:WaitForChild("design")
local Theme = require(Design.Theme)

local Components = UI:WaitForChild("components")
local SunCounter = require(Components.molecules.SunCounter)
local CoinCounter = require(Components.molecules.CoinCounter)
local SeedBank = require(Components.organisms.SeedBank)
local WaveProgressBar = require(Components.molecules.WaveProgressBar)
local BaseHealthBar = require(Components.molecules.BaseHealthBar)
local ToonButton = require(Components.atoms.ToonButton)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- ============================================================
-- MODULE
-- ============================================================
local HUDController = {}
HUDController.__index = HUDController

-- State
local _trove = Trove.new()
local _scope: any = nil
local _screenGui: ScreenGui? = nil
local _initialized = false

-- Reactive state for countdown displays (exposed for init.client.luau compatibility)
local _waveNumber: any = nil
local _preparationPhase: any = nil
local _preparationTime: any = nil
local _intermissionTime: any = nil
local _gameStarted: any = nil -- True once GameStarted event is received

-- ============================================================
-- PRIVATE FUNCTIONS
-- ============================================================

--[[
	Get the player's equipped plants from PlayerDataClient.
	Falls back to default deck if unavailable.
]]
local function getEquippedPlants(): {string}
	local deck = PlayerDataClient.GetDeck()
	if deck and #deck > 0 then
		return deck
	end
	-- Fallback default deck
	return {"Sunflower", "Peashooter", "WallNut"}
end

--[[
	Handle plant selection from SeedBank.
]]
local function onPlantSelect(plantType: string)
	Logger.Debug("HUDController", `Plant selected: {plantType}`)
	SelectionState.Select(plantType)
end

--[[
	Handle Ready button click - sends StartWaveRequest to server.
]]
local function onReadyClick(preparationPhase: any)
	Logger.Info("HUDController", "Ready button clicked - starting wave")
	preparationPhase:set(false)
	
	Network.StartWaveRequest.Fire({
		RequestId = math.random(1, 65535),
	})
end

--[[
	Build the HUD layout using atomic components.
]]
local function buildHUD(scope: any, preparationPhase: any, preparationTime: any, intermissionTime: any): ScreenGui
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		error("HUDController: No LocalPlayer found")
	end
	
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	
	-- Get reactive player data (both deck and mutations are reactive now)
	local equippedPlants = PlayerDataClient.GetDeckValue()
	local equippedMutations = PlayerDataClient.GetMutationsValue()
	
	Logger.Debug("HUDController", `Building HUD with reactive deck and mutations`)
	
	-- Ready button text with countdown
	local readyButtonText = Computed(scope, function(use)
		local timeLeft = math.floor(use(preparationTime))
		if timeLeft > 0 then
			return `🌻 READY! ({timeLeft}s)`
		end
		return "🌻 READY!"
	end)
	
	-- Intermission indicator text
	local intermissionText = Computed(scope, function(use)
		local timeLeft = math.floor(use(intermissionTime))
		return `🎉 WAVE COMPLETE! Next in {timeLeft}s`
	end)
	
	-- Create ScreenGui
	local screenGui = New(scope, "ScreenGui") {
		Name = "GameHUD",
		Parent = playerGui,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		
		[Children] = {
			-- Top-Center: SunCounter + SeedBank in horizontal layout
			New(scope, "Frame") {
				Name = "TopBar",
				Size = UDim2.new(0, 0, 0, 90), -- Height for seedbank
				Position = UDim2.new(0.5, 0, 0, 10),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				
				[Children] = {
					New(scope, "UIListLayout") {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					
					-- Sun Counter (left)
					SunCounter({
						Scope = scope,
						LayoutOrder = 1,
					}),
					
					-- Seed Bank (center)
					SeedBank({
						Scope = scope,
						EquippedPlants = equippedPlants,
						EquippedMutations = equippedMutations,
						OnPlantSelect = onPlantSelect,
						ZIndex = 5,
						LayoutOrder = 2,
					}),
					
					-- Coin Counter (right)
					CoinCounter({
						Scope = scope,
						LayoutOrder = 3,
					}),
				},
			},
			
			-- Bottom-Center: Ready Button (visible during preparation phase AND game has started)
			ToonButton({
				Scope = scope,
				Text = readyButtonText,
				Size = UDim2.fromOffset(240, 56),
				Position = UDim2.new(0.5, 0, 1, -100),
				AnchorPoint = Vector2.new(0.5, 1),
				Color = "Action", -- Orange/Green action color
				OnClick = function()
					onReadyClick(preparationPhase)
				end,
				Visible = Computed(scope, function(use)
					return use(_gameStarted) and use(preparationPhase)
				end),
				ZIndex = 10,
			}),
			
			-- Intermission Indicator (visible between waves)
			New(scope, "Frame") {
				Name = "IntermissionIndicator",
				Size = UDim2.fromOffset(320, 60),
				Position = UDim2.new(0.5, 0, 0.35, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Colors.Info.Main,
				Visible = Computed(scope, function(use)
					return use(intermissionTime) > 0 and not use(preparationPhase)
				end),
				ZIndex = 15,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
					New(scope, "UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = Theme.Layout.StrokeThickness,
					},
					New(scope, "TextLabel") {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = intermissionText,
						TextColor3 = Color3.new(1, 1, 1),
						Font = Theme.Typography.Fonts.Title,
						TextSize = 22,
						TextStrokeTransparency = 0,
						TextStrokeColor3 = Theme.Colors.Surface.Stroke :: Color3,
					},
				},
			},
			
			-- Bottom-Right: Wave Progress Bar
			WaveProgressBar({
				Scope = scope,
				Position = UDim2.new(1, -20, 1, -60),
				AnchorPoint = Vector2.new(1, 1),
				ZIndex = 5,
			}),
			
			-- Bottom-Left: Base Health Bar
			BaseHealthBar({
				Scope = scope,
				Position = UDim2.new(0, 20, 1, -60),
				AnchorPoint = Vector2.new(0, 1),
				ZIndex = 5,
			}),
		},
	}
	
	return screenGui :: ScreenGui
end

-- ============================================================
-- PUBLIC API
-- ============================================================

--[[
	Create a new HUD controller instance.
	Compatibility wrapper for init.client.luau.
]]
function HUDController.new()
	local self = setmetatable({}, HUDController)
	
	-- Create Fusion scope
	_scope = Fusion.scoped({})
	
	-- Initialize reactive state
	_waveNumber = Value(_scope, 0)
	_preparationPhase = Value(_scope, true)
	_preparationTime = Value(_scope, 0)
	_intermissionTime = Value(_scope, 0)
	_gameStarted = Value(_scope, false) -- Will be set true when GameStarted event received
	
	-- Expose for countdown loop in init.client.luau
	self._waveNumber = _waveNumber
	self._preparationPhase = _preparationPhase
	self._preparationTime = _preparationTime
	self._intermissionTime = _intermissionTime
	self._gameStarted = _gameStarted
	
	Logger.Debug("HUDController", "Created new HUD controller")
	return self
end

--[[
	Mount the HUD to PlayerGui.
]]
function HUDController:Mount()
	if _initialized then
		Logger.Warn("HUDController", "Already mounted")
		return
	end
	
	-- Build and mount HUD with reactive state for Ready button and Intermission
	_screenGui = buildHUD(_scope, _preparationPhase, _preparationTime, _intermissionTime)
	
	-- Store in trove for cleanup
	if _screenGui then
		_trove:Add(_screenGui)
	end
	
	_initialized = true
	Logger.Info("HUDController", "HUD mounted")
end

--[[
	Unmount the HUD.
]]
function HUDController:Unmount()
	if not _initialized then
		return
	end
	
	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end
	
	_initialized = false
	Logger.Info("HUDController", "HUD unmounted")
end

--[[
	Set preparation time display.
]]
function HUDController:SetPreparationTime(time: number)
	if _preparationTime then
		_preparationTime:set(time)
	end
end

--[[
	Set intermission time display.
]]
function HUDController:SetIntermissionTime(time: number)
	if _intermissionTime then
		_intermissionTime:set(time)
	end
end

--[[
	Set game started state (called when GameStarted event is received).
	This controls the Ready button visibility in Studio debug mode.
]]
function HUDController:SetGameStarted(started: boolean)
	if _gameStarted then
		_gameStarted:set(started)
	end
end

--[[
	Initialize the HUD Controller (static method).
	Creates and mounts the GameHUD ScreenGui.
]]
function HUDController.Initialize()
	if _initialized then
		Logger.Warn("HUDController", "Already initialized")
		return
	end
	
	-- Create Fusion scope
	_scope = Fusion.scoped({})
	
	-- Initialize reactive state
	_waveNumber = Value(_scope, 0)
	_preparationPhase = Value(_scope, true)
	_preparationTime = Value(_scope, 0)
	_intermissionTime = Value(_scope, 0)
	
	-- Build and mount HUD
	_screenGui = buildHUD(_scope)
	
	-- Store in trove for cleanup
	if _screenGui then
		_trove:Add(_screenGui)
	end
	
	_initialized = true
	Logger.Info("HUDController", "Initialized - GameHUD mounted")
end

--[[
	Refresh the SeedBank with updated plant/mutation data.
	Call this after player data syncs from server.
]]
function HUDController.RefreshDeck()
	if not _initialized or not _scope then
		return
	end
	
	-- For now, log that refresh was requested
	-- Full implementation would rebuild the SeedBank or use reactive props
	Logger.Debug("HUDController", "Deck refresh requested")
end

--[[
	Show/Hide the HUD.
]]
function HUDController.SetVisible(visible: boolean)
	if _screenGui then
		_screenGui.Enabled = visible
	end
end

--[[
	Get the ScreenGui reference.
]]
function HUDController.GetScreenGui(): ScreenGui?
	return _screenGui
end

--[[
	Dispose of the HUD Controller.
	Cleans up all UI and connections.
]]
function HUDController.Dispose()
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
	
	Logger.Info("HUDController", "Disposed")
end

return HUDController
