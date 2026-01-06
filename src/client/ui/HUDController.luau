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
local ShopUI = require(script.Parent.ShopUI)

-- Client modules
local Client = script.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)
local PlayerDataClient = require(Modules.PlayerDataClient)

-- VFX/Audio (lazy loaded)
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
	self._shopVisible = Value(self._scope, false) -- Shop visibility state
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
			-- Sun Counter (top-left, in-game currency)
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
			
			-- Coin Counter (below sun counter, persistent currency)
			New(self._scope, "Frame")({
				Name = "CoinCounter",
				Position = UDim2.fromOffset(20, 80),
				Size = UDim2.fromOffset(120, 40),
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				BackgroundTransparency = 0.3,
				
				[Children] = {
					New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
					New(self._scope, "TextLabel")({
						Name = "CoinText",
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromScale(0.9, 0.8),
						BackgroundTransparency = 1,
						Text = Computed(self._scope, function(use)
							return `🪙 {use(PlayerDataClient.GetCoinsValue())}`
						end),
						TextColor3 = Color3.fromRGB(255, 200, 50),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
					}),
				},
			}),
			
			-- Shop Button (below coin counter)
			New(self._scope, "TextButton")({
				Name = "ShopButton",
				Position = UDim2.fromOffset(20, 130),
				Size = UDim2.fromOffset(120, 40),
				BackgroundColor3 = Color3.fromRGB(80, 120, 180),
				BorderSizePixel = 0,
				Text = "🛒 Shop",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				
				[OnEvent("Activated")] = function()
					self._shopVisible:set(true)
				end,
				
				[Children] = {
					New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
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
			
			-- Shop UI (overlay)
			ShopUI({
				Scope = self._scope,
				Visible = self._shopVisible,
				OnClose = function()
					self._shopVisible:set(false)
				end,
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

-- Show floating coin gain text (simple version, can be enhanced with VFX later)
function HUDController:ShowCoinGain(amount: number, worldX: number?, worldZ: number?)
	if not self._gui then
		return
	end
	
	-- Play coin collect sound
	local audio = getAudioService()
	if audio then audio.PlayCoinCollect() end
	
	-- Create floating text at coin counter location
	local floatingText = New(self._scope, "TextLabel")({
		Name = "CoinGain",
		Parent = self._gui,
		Position = UDim2.fromOffset(150, 90), -- Near coin counter
		Size = UDim2.fromOffset(60, 30),
		BackgroundTransparency = 1,
		Text = `+{amount}`,
		TextColor3 = Color3.fromRGB(255, 215, 0),
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		ZIndex = 50,
	})
	
	-- Animate upward and fade out
	task.spawn(function()
		local startTime = tick()
		local duration = 1.0
		
		while tick() - startTime < duration do
			local progress = (tick() - startTime) / duration
			local yOffset = 90 - (progress * 40) -- Move up
			local alpha = 1 - progress -- Fade out
			
			floatingText.Position = UDim2.fromOffset(150, yOffset)
			floatingText.TextTransparency = 1 - alpha
			
			task.wait()
		end
		
		floatingText:Destroy()
	end)
end

-- Show end game rewards summary
function HUDController:ShowEndGameRewards(data: {
	Victory: boolean,
	CoinsEarned: number,
	ZombiesKilled: number,
	WavesCompleted: number,
	BonusCoins: number,
})
	if not self._gui then
		return
	end
	
	-- Create rewards summary panel that appears after game over text
	local rewardsPanel = New(self._scope, "Frame")({
		Name = "RewardsSummary",
		Parent = self._gui,
		Position = UDim2.fromScale(0.5, 0.65),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(300, 180),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.2,
		ZIndex = 101,
		
		[Children] = {
			New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
			
			-- Title
			New(self._scope, "TextLabel")({
				Position = UDim2.fromOffset(0, 10),
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = "📊 Game Summary",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
			}),
			
			-- Stats container
			New(self._scope, "Frame")({
				Position = UDim2.fromOffset(20, 50),
				Size = UDim2.new(1, -40, 0, 120),
				BackgroundTransparency = 1,
				
				[Children] = {
					New(self._scope, "UIListLayout")({
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					
					-- Zombies killed
					New(self._scope, "TextLabel")({
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						Text = `💀 Zombies Killed: {data.ZombiesKilled}`,
						TextColor3 = Color3.fromRGB(200, 200, 200),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextSize = 16,
						Font = Enum.Font.GothamMedium,
						LayoutOrder = 1,
					}),
					
					-- Waves completed
					New(self._scope, "TextLabel")({
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						Text = `🌊 Waves Completed: {data.WavesCompleted}`,
						TextColor3 = Color3.fromRGB(200, 200, 200),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextSize = 16,
						Font = Enum.Font.GothamMedium,
						LayoutOrder = 2,
					}),
					
					-- Coins earned
					New(self._scope, "TextLabel")({
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						Text = `🪙 Coins Earned: {data.CoinsEarned - data.BonusCoins}`,
						TextColor3 = Color3.fromRGB(255, 200, 50),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextSize = 16,
						Font = Enum.Font.GothamMedium,
						LayoutOrder = 3,
					}),
					
					-- Victory bonus
					if data.BonusCoins > 0 then New(self._scope, "TextLabel")({
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						Text = `🏆 Victory Bonus: +{data.BonusCoins}`,
						TextColor3 = Color3.fromRGB(255, 215, 0),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextSize = 16,
						Font = Enum.Font.GothamBold,
						LayoutOrder = 4,
					}) else nil,
					
					-- Total
					New(self._scope, "TextLabel")({
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundTransparency = 1,
						Text = `💰 Total: {data.CoinsEarned}`,
						TextColor3 = Color3.fromRGB(100, 255, 100),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextSize = 18,
						Font = Enum.Font.GothamBlack,
						LayoutOrder = 5,
					}),
				},
			}),
		},
	})
	
	-- Fade in animation
	rewardsPanel.BackgroundTransparency = 1
	task.spawn(function()
		for i = 1, 10 do
			rewardsPanel.BackgroundTransparency = 1 - (i / 10) * 0.8
			task.wait(0.03)
		end
	end)
end

return HUDController
