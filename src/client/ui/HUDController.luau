--!strict
--[[
	HUD Controller - Main game HUD using Fusion
	
	Manages:
	- Sun counter display
	- Plant selection bar (CardDeck)
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
local PlantData = require(Shared.data.PlantData)

-- UI Components
local CardDeck = require(script.Parent.CardDeck)

-- Client modules
local Client = script.Parent.Parent
local SelectionState = require(Client.modules.SelectionState)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local Computed = Fusion.Computed
local OnEvent = Fusion.OnEvent

local HUDController = {}
HUDController.__index = HUDController

function HUDController.new()
	local self = setmetatable({}, HUDController)
	
	-- Use shared selection state
	self._scope = Fusion.scoped({})
	self._waveNumber = Value(self._scope, 0)
	self._baseHealth = Value(self._scope, 1000)
	self._baseMaxHealth = Value(self._scope, 1000)
	self._gameOver = Value(self._scope, false)
	self._victory = Value(self._scope, false)
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
	
	-- Callback for card selection
	local function onCardSelect(plantType: string)
		local currentSelection = Fusion.peek(SelectionState.SelectedPlant)
		
		-- Toggle selection
		if currentSelection == plantType then
			SelectionState.Select(nil)
			Logger.Debug("HUDController", "Deselected plant")
		else
			-- Check if on cooldown
			if SelectionState.IsOnCooldown(plantType) then
				Logger.Debug("HUDController", `{plantType} is on cooldown`)
				return
			end
			
			-- Check if can afford
			local stats = PlantData[plantType]
			if stats and not SelectionState.CanAfford(stats.Cost) then
				Logger.Debug("HUDController", `Cannot afford {plantType}`)
				return
			end
			
			SelectionState.Select(plantType)
			Logger.Debug("HUDController", `Selected {plantType}`)
		end
	end
	
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
							return `☀️ {use(SelectionState.SunCount)}`
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
			
			-- Base Health Bar (top-right)
			New(self._scope, "Frame")({
				Name = "HealthBar",
				Position = UDim2.new(1, -20, 0, 20),
				AnchorPoint = Vector2.new(1, 0),
				Size = UDim2.fromOffset(200, 30),
				BackgroundColor3 = Color3.fromRGB(60, 60, 60),
				BackgroundTransparency = 0.3,
				
				[Children] = {
					New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 6) }),
					
					-- Health fill bar
					New(self._scope, "Frame")({
						Name = "Fill",
						Position = UDim2.fromOffset(2, 2),
						Size = Computed(self._scope, function(use)
							local health = use(self._baseHealth)
							local maxHealth = use(self._baseMaxHealth)
							local ratio = math.clamp(health / maxHealth, 0, 1)
							return UDim2.new(ratio, -4, 1, -4)
						end),
						BackgroundColor3 = Computed(self._scope, function(use)
							local health = use(self._baseHealth)
							local maxHealth = use(self._baseMaxHealth)
							local ratio = health / maxHealth
							if ratio > 0.5 then
								return Color3.fromRGB(80, 200, 80)
							elseif ratio > 0.25 then
								return Color3.fromRGB(200, 200, 80)
							else
								return Color3.fromRGB(200, 80, 80)
							end
						end),
						
						[Children] = {
							New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 4) }),
						},
					}),
					
					-- Health text
					New(self._scope, "TextLabel")({
						Name = "HealthText",
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromScale(0.9, 0.8),
						BackgroundTransparency = 1,
						Text = Computed(self._scope, function(use)
							return `🏠 {use(self._baseHealth)}/{use(self._baseMaxHealth)}`
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
					}),
				},
			}),
			
			-- Game Over Overlay
			New(self._scope, "Frame")({
				Name = "GameOverOverlay",
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = Computed(self._scope, function(use)
					return if use(self._gameOver) then 0.5 else 1
				end),
				Visible = Computed(self._scope, function(use)
					return use(self._gameOver)
				end),
				ZIndex = 100,
				
				[Children] = {
					-- Game Over text
					New(self._scope, "TextLabel")({
						Name = "GameOverText",
						Position = UDim2.fromScale(0.5, 0.4),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(400, 80),
						BackgroundTransparency = 1,
						Text = Computed(self._scope, function(use)
							return if use(self._victory) then "🏆 VICTORY!" else "💀 DEFEAT"
						end),
						TextColor3 = Computed(self._scope, function(use)
							return if use(self._victory) 
								then Color3.fromRGB(255, 215, 0) 
								else Color3.fromRGB(200, 50, 50)
						end),
						TextScaled = true,
						Font = Enum.Font.GothamBlack,
					}),
					
					-- Wave reached text
					New(self._scope, "TextLabel")({
						Name = "WaveReachedText",
						Position = UDim2.fromScale(0.5, 0.55),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(300, 40),
						BackgroundTransparency = 1,
						Text = Computed(self._scope, function(use)
							local wave = use(self._waveNumber)
							return if use(self._victory) 
								then "All waves completed!" 
								else `Reached Wave {wave}`
						end),
						TextColor3 = Color3.fromRGB(200, 200, 200),
						TextScaled = true,
						Font = Enum.Font.GothamMedium,
					}),
				},
			}),
			
			-- Card Deck (bottom-center)
			CardDeck({
				Scope = self._scope,
				SelectedPlant = SelectionState.SelectedPlant,
				SunCount = SelectionState.SunCount,
				Cooldowns = SelectionState.Cooldowns,
				OnSelect = onCardSelect,
			}),
		},
	})
	
	self._mounted = true
	Logger.Info("HUDController", "HUD mounted with CardDeck")
end

function HUDController:Unmount()
	if not self._mounted then
		return
	end
	
	Fusion.doCleanup(self._scope)
	self._mounted = false
	Logger.Info("HUDController", "HUD unmounted")
end

function HUDController:SetWaveNumber(wave: number)
	self._waveNumber:set(wave)
end

function HUDController:SetBaseHealth(current: number, max: number)
	self._baseHealth:set(current)
	self._baseMaxHealth:set(max)
end

function HUDController:SetGameOver(victory: boolean, waveReached: number)
	self._gameOver:set(true)
	self._victory:set(victory)
	self._waveNumber:set(waveReached)
	Logger.Info("HUDController", `Game over: {if victory then "VICTORY" else "DEFEAT"} at wave {waveReached}`)
end

return HUDController
