--!strict
--[[
	HUD Controller - Main game HUD using Fusion
	
	Manages:
	- Sun counter display
	- Plant selection bar
	- Wave indicator
	- Game state overlays
	
	All UI is reactive via Fusion Value/Computed objects.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local Computed = Fusion.Computed
local OnEvent = Fusion.OnEvent

-- Types
export type HUDController = {
	Mount: (self: HUDController) -> (),
	Unmount: (self: HUDController) -> (),
	SetSunCount: (self: HUDController, count: number) -> (),
	SetWaveNumber: (self: HUDController, wave: number) -> (),
	SetSelectedPlant: (self: HUDController, plantType: string?) -> (),
}

local HUDController = {} :: HUDController
HUDController.__index = HUDController

function HUDController.new(): HUDController
	local self = setmetatable({}, HUDController)
	
	-- Reactive state
	self._scope = Fusion.scoped({})
	self._sunCount = Value(self._scope, 50)
	self._waveNumber = Value(self._scope, 0)
	self._selectedPlant = Value(self._scope, nil :: string?)
	self._mounted = false
	self._gui = nil :: ScreenGui?
	
	Logger.Debug("HUDController", "Created new HUD controller")
	
	return self
end

function HUDController:Mount()
	if self._mounted then
		Logger.Warn("HUDController", "Already mounted")
		return
	end
	
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	
	-- Create the main ScreenGui
	self._gui = New(self._scope, "ScreenGui")({
		Name = "GameHUD",
		Parent = PlayerGui,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		
		[Children] = {
			-- Sun Counter (top-left)
			New(self._scope, "Frame")({
				Name = "SunCounter",
				Position = UDim2.fromOffset(20, 20),
				Size = UDim2.fromOffset(120, 50),
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				BackgroundTransparency = 0.3,
				
				[Children] = {
					New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
					New(self._scope, "TextLabel")({
						Name = "SunText",
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromScale(0.9, 0.8),
						BackgroundTransparency = 1,
						Text = Computed(self._scope, function(use)
							return `☀️ {use(self._sunCount)}`
						end),
						TextColor3 = Color3.fromRGB(255, 220, 50),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
					}),
				},
			}),
			
			-- Wave Indicator (top-center)
			New(self._scope, "TextLabel")({
				Name = "WaveIndicator",
				Position = UDim2.new(0.5, 0, 0, 20),
				AnchorPoint = Vector2.new(0.5, 0),
				Size = UDim2.fromOffset(200, 40),
				BackgroundTransparency = 1,
				Text = Computed(self._scope, function(use)
					local wave = use(self._waveNumber)
					if wave == 0 then
						return "Prepare Your Defenses!"
					else
						return `Wave {wave}`
					end
				end),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
			}),
			
			-- Placeholder for plant bar (will be expanded later)
			New(self._scope, "Frame")({
				Name = "PlantBar",
				Position = UDim2.new(0.5, 0, 1, -80),
				AnchorPoint = Vector2.new(0.5, 1),
				Size = UDim2.fromOffset(400, 70),
				BackgroundColor3 = Color3.fromRGB(30, 30, 30),
				BackgroundTransparency = 0.3,
				
				[Children] = {
					New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
					New(self._scope, "TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "🌱 Plant Bar (MVP placeholder)",
						TextColor3 = Color3.fromRGB(200, 200, 200),
						TextScaled = true,
						Font = Enum.Font.Gotham,
					}),
				},
			}),
		},
	})
	
	self._mounted = true
	Logger.Info("HUDController", "HUD mounted")
end

function HUDController:Unmount()
	if not self._mounted then
		return
	end
	
	Fusion.doCleanup(self._scope)
	self._mounted = false
	Logger.Info("HUDController", "HUD unmounted")
end

function HUDController:SetSunCount(count: number)
	Fusion.peek(self._sunCount)  -- Access current for debug
	self._sunCount:set(count)
end

function HUDController:SetWaveNumber(wave: number)
	self._waveNumber:set(wave)
end

function HUDController:SetSelectedPlant(plantType: string?)
	self._selectedPlant:set(plantType)
end

return HUDController
