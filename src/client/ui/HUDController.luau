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
local DeckBuilder = require(script.Parent.DeckBuilder)
local PvZTheme = require(script.Parent.PvZTheme)

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
	self._deckBuilderVisible = Value(self._scope, false) -- DeckBuilder visibility state
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
			-- ============================================
			-- LEFT PANEL: Resources & Player Stats (PvZ Style)
			-- ============================================
			PvZTheme.WoodPanel(self._scope, {
				Name = "ResourcePanel",
				Position = UDim2.fromOffset(15, 15),
				Size = UDim2.fromOffset(160, 220),
				children = {
					-- Sun Counter Row
					New(self._scope, "Frame")({
						Name = "SunRow",
						Position = UDim2.fromOffset(10, 10),
						Size = UDim2.new(1, -20, 0, 40),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						BackgroundTransparency = 0.5,
						
						[Children] = {
							New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
							New(self._scope, "TextLabel")({
								Name = "SunIcon",
								Position = UDim2.fromOffset(5, 0),
								Size = UDim2.new(0, 35, 1, 0),
								BackgroundTransparency = 1,
								Text = PvZTheme.Icons.Sun,
								TextScaled = true,
							}),
							PvZTheme.StrokedText(self._scope, {
								Name = "SunValue",
								Position = UDim2.new(0, 45, 0.5, 0),
								Size = UDim2.new(1, -50, 0.7, 0),
								AnchorPoint = Vector2.new(0, 0.5),
								Text = Computed(self._scope, function(use)
									return tostring(use(SelectionState.SunCount))
								end),
								TextColor3 = PvZTheme.Colors.SunYellow,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						},
					}),
					
					-- Coins Counter Row
					New(self._scope, "Frame")({
						Name = "CoinsRow",
						Position = UDim2.fromOffset(10, 55),
						Size = UDim2.new(1, -20, 0, 35),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						BackgroundTransparency = 0.5,
						
						[Children] = {
							New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
							New(self._scope, "TextLabel")({
								Name = "CoinIcon",
								Position = UDim2.fromOffset(5, 0),
								Size = UDim2.new(0, 30, 1, 0),
								BackgroundTransparency = 1,
								Text = PvZTheme.Icons.Coin,
								TextScaled = true,
							}),
							PvZTheme.StrokedText(self._scope, {
								Name = "CoinValue",
								Position = UDim2.new(0, 40, 0.5, 0),
								Size = UDim2.new(1, -45, 0.7, 0),
								AnchorPoint = Vector2.new(0, 0.5),
								Text = Computed(self._scope, function(use)
									return tostring(use(PlayerDataClient.GetCoinsValue()))
								end),
								TextColor3 = PvZTheme.Colors.CoinGold,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						},
					}),
					
					-- Gems Counter Row
					New(self._scope, "Frame")({
						Name = "GemsRow",
						Position = UDim2.fromOffset(10, 95),
						Size = UDim2.new(1, -20, 0, 35),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						BackgroundTransparency = 0.5,
						
						[Children] = {
							New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
							New(self._scope, "TextLabel")({
								Name = "GemIcon",
								Position = UDim2.fromOffset(5, 0),
								Size = UDim2.new(0, 30, 1, 0),
								BackgroundTransparency = 1,
								Text = PvZTheme.Icons.Gem,
								TextScaled = true,
							}),
							PvZTheme.StrokedText(self._scope, {
								Name = "GemValue",
								Position = UDim2.new(0, 40, 0.5, 0),
								Size = UDim2.new(1, -45, 0.7, 0),
								AnchorPoint = Vector2.new(0, 0.5),
								Text = Computed(self._scope, function(use)
									return tostring(use(PlayerDataClient.GetGemsValue()))
								end),
								TextColor3 = PvZTheme.Colors.GemCyan,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						},
					}),
					
					-- Level & XP Display
					New(self._scope, "Frame")({
						Name = "LevelSection",
						Position = UDim2.fromOffset(10, 135),
						Size = UDim2.new(1, -20, 0, 35),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						BackgroundTransparency = 0.5,
						
						[Children] = {
							New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
							New(self._scope, "TextLabel")({
								Name = "StarIcon",
								Position = UDim2.fromOffset(5, 0),
								Size = UDim2.new(0, 28, 1, 0),
								BackgroundTransparency = 1,
								Text = PvZTheme.Icons.Star,
								TextScaled = true,
							}),
							PvZTheme.StrokedText(self._scope, {
								Name = "LevelText",
								Position = UDim2.new(0, 38, 0.5, 0),
								Size = UDim2.new(0, 50, 0.6, 0),
								AnchorPoint = Vector2.new(0, 0.5),
								Text = Computed(self._scope, function(use)
									return "Lv." .. tostring(use(PlayerDataClient.GetLevelValue()))
								end),
								TextColor3 = PvZTheme.Colors.TextGold,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							-- XP Progress Bar
							PvZTheme.ProgressBar(self._scope, {
								Name = "XPBar",
								Position = UDim2.new(0, 90, 0.5, 0),
								Size = UDim2.new(1, -100, 0.4, 0),
								AnchorPoint = Vector2.new(0, 0.5),
								Progress = PlayerDataClient.GetLevelProgressValue(),
								FillColor = PvZTheme.Colors.XPPurple,
								BackgroundColor = Color3.fromRGB(60, 40, 60),
							}),
						},
					}),
					
					-- Shop Button (PvZ Style)
					PvZTheme.WoodButton(self._scope, {
						Name = "ShopButton",
						Position = UDim2.fromOffset(10, 178),
						Size = UDim2.new(0.5, -15, 0, 35),
						Text = PvZTheme.Icons.Shop,
						OnClick = function()
							self._shopVisible:set(true)
						end,
					}),
					
					-- Deck Builder Button
					PvZTheme.WoodButton(self._scope, {
						Name = "DeckButton",
						Position = UDim2.fromOffset(80, 178),
						Size = UDim2.new(0.5, -15, 0, 35),
						AnchorPoint = Vector2.new(0, 0),
						Text = PvZTheme.Icons.Plant,
						OnClick = function()
							self._deckBuilderVisible:set(true)
						end,
					}),
				},
			}),
			
			-- ============================================
			-- TOP CENTER: Wave Banner (PvZ Style)
			-- ============================================
			PvZTheme.Banner(self._scope, {
				Name = "WaveBanner",
				Position = UDim2.new(0.5, 0, 0, 15),
				Size = UDim2.fromOffset(220, 45),
				AnchorPoint = Vector2.new(0.5, 0),
				Text = Computed(self._scope, function(use)
					local wave = use(self._waveNumber)
					if wave == 0 then
						return PvZTheme.Icons.Plant .. " GET READY!"
					else
						return PvZTheme.Icons.Wave .. " WAVE " .. tostring(wave)
					end
				end),
			}),
			
			-- ============================================
			-- TOP RIGHT: Base Health (PvZ Style)
			-- ============================================
			PvZTheme.WoodPanel(self._scope, {
				Name = "HealthPanel",
				Position = UDim2.new(1, -15, 0, 15),
				Size = UDim2.fromOffset(200, 50),
				AnchorPoint = Vector2.new(1, 0),
				children = {
					-- Heart icon
					New(self._scope, "TextLabel")({
						Name = "HeartIcon",
						Position = UDim2.fromOffset(8, 0),
						Size = UDim2.new(0, 35, 1, 0),
						BackgroundTransparency = 1,
						Text = PvZTheme.Icons.Heart,
						TextScaled = true,
					}),
					
					-- Health bar container
					New(self._scope, "Frame")({
						Name = "HealthBarBG",
						Position = UDim2.new(0, 48, 0.5, 0),
						Size = UDim2.new(1, -58, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						
						[Children] = {
							New(self._scope, "UICorner")({ CornerRadius = UDim.new(1, 0) }),
							
							-- Health fill bar
							New(self._scope, "Frame")({
								Name = "Fill",
								Size = Computed(self._scope, function(use)
									local health = use(self._baseHealth)
									local maxHealth = use(self._baseMaxHealth)
									local ratio = math.clamp(health / maxHealth, 0, 1)
									return UDim2.fromScale(ratio, 1)
								end),
								BackgroundColor3 = Computed(self._scope, function(use)
									local health = use(self._baseHealth)
									local maxHealth = use(self._baseMaxHealth)
									local ratio = health / maxHealth
									if ratio > 0.5 then
										return PvZTheme.Colors.HealthGreen
									elseif ratio > 0.25 then
										return PvZTheme.Colors.SunYellow
									else
										return PvZTheme.Colors.HealthRed
									end
								end),
								
								[Children] = {
									New(self._scope, "UICorner")({ CornerRadius = UDim.new(1, 0) }),
								},
							}),
							
							-- Health text overlay
							PvZTheme.StrokedText(self._scope, {
								Name = "HealthText",
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.95, 0.9),
								AnchorPoint = Vector2.new(0.5, 0.5),
								Text = Computed(self._scope, function(use)
									return use(self._baseHealth) .. "/" .. use(self._baseMaxHealth)
								end),
								TextColor3 = PvZTheme.Colors.TextWhite,
								Font = Enum.Font.GothamBold,
							}),
						},
					}),
				},
			}),
			
			-- ============================================
			-- GAME OVER OVERLAY (PvZ Style)
			-- ============================================
			New(self._scope, "Frame")({
				Name = "GameOverOverlay",
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = Computed(self._scope, function(use)
					return if use(self._gameOver) then 0.4 else 1
				end),
				Visible = Computed(self._scope, function(use)
					return use(self._gameOver)
				end),
				ZIndex = 100,
				
				[Children] = {
					-- Victory/Defeat banner panel
					PvZTheme.WoodPanel(self._scope, {
						Name = "GameOverPanel",
						Position = UDim2.fromScale(0.5, 0.35),
						Size = UDim2.fromOffset(400, 100),
						AnchorPoint = Vector2.new(0.5, 0.5),
						children = {
							-- Trophy/Skull icon
							New(self._scope, "TextLabel")({
								Name = "ResultIcon",
								Position = UDim2.fromScale(0.5, 0.3),
								AnchorPoint = Vector2.new(0.5, 0.5),
								Size = UDim2.fromOffset(50, 50),
								BackgroundTransparency = 1,
								Text = Computed(self._scope, function(use)
									return if use(self._victory) then PvZTheme.Icons.Trophy else PvZTheme.Icons.Skull
								end),
								TextScaled = true,
							}),
							
							-- Game Over text
							PvZTheme.StrokedText(self._scope, {
								Name = "GameOverText",
								Position = UDim2.fromScale(0.5, 0.7),
								AnchorPoint = Vector2.new(0.5, 0.5),
								Size = UDim2.fromOffset(350, 45),
								Text = Computed(self._scope, function(use)
									return if use(self._victory) then "VICTORY!" else "DEFEAT..."
								end),
								TextColor3 = Computed(self._scope, function(use)
									return if use(self._victory) 
										then PvZTheme.Colors.Victory 
										else PvZTheme.Colors.Defeat
								end),
								Font = Enum.Font.GothamBlack,
							}),
						},
					}),
					
					-- Wave reached subtitle
					PvZTheme.StrokedText(self._scope, {
						Name = "WaveReachedText",
						Position = UDim2.fromScale(0.5, 0.48),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(300, 35),
						Text = Computed(self._scope, function(use)
							local wave = use(self._waveNumber)
							return if use(self._victory) 
								then "All waves completed!" 
								else "Reached Wave " .. tostring(wave)
						end),
						TextColor3 = PvZTheme.Colors.TextWhite,
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
			
			-- Deck Builder UI (overlay)
			DeckBuilder.Create(self._scope, {
				Visible = self._deckBuilderVisible,
				OnClose = function()
					self._deckBuilderVisible:set(false)
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

-- Show floating coin gain text (PvZ Style)
function HUDController:ShowCoinGain(amount: number, worldX: number?, worldZ: number?)
	if not self._gui then
		return
	end
	
	-- Play coin collect sound
	local audio = getAudioService()
	if audio then audio.PlayCoinCollect() end
	
	-- Create floating text at coin counter location with stroke
	local floatingText = New(self._scope, "TextLabel")({
		Name = "CoinGain",
		Parent = self._gui,
		Position = UDim2.fromOffset(140, 70),
		Size = UDim2.fromOffset(70, 35),
		BackgroundTransparency = 1,
		Text = "+" .. tostring(amount),
		TextColor3 = PvZTheme.Colors.CoinGold,
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		ZIndex = 50,
		
		[Children] = {
			New(self._scope, "UIStroke")({
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 2,
			}),
		},
	})
	
	-- Animate upward and fade out
	task.spawn(function()
		local startTime = tick()
		local duration = 1.2
		
		while tick() - startTime < duration do
			local progress = (tick() - startTime) / duration
			local yOffset = 70 - (progress * 50) -- Move up
			local alpha = 1 - progress -- Fade out
			
			floatingText.Position = UDim2.fromOffset(140, yOffset)
			floatingText.TextTransparency = 1 - alpha
			
			task.wait()
		end
		
		floatingText:Destroy()
	end)
end

-- Show end game rewards summary (PvZ Style)
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
	
	-- Create rewards summary panel with wood theme
	local rewardsPanel = PvZTheme.WoodPanel(self._scope, {
		Name = "RewardsSummary",
		Position = UDim2.fromScale(0.5, 0.68),
		Size = UDim2.fromOffset(320, 200),
		AnchorPoint = Vector2.new(0.5, 0.5),
		children = {
			-- Title banner
			New(self._scope, "Frame")({
				Name = "TitleBar",
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = PvZTheme.Colors.GrassGreen,
				
				[Children] = {
					New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
					PvZTheme.StrokedText(self._scope, {
						Name = "Title",
						Text = PvZTheme.Icons.Trophy .. " GAME SUMMARY",
						TextColor3 = PvZTheme.Colors.TextWhite,
					}),
				},
			}),
			
			-- Stats container
			New(self._scope, "Frame")({
				Position = UDim2.fromOffset(15, 50),
				Size = UDim2.new(1, -30, 0, 140),
				BackgroundTransparency = 1,
				
				[Children] = {
					New(self._scope, "UIListLayout")({
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					
					-- Zombies killed
					self:_createRewardRow(PvZTheme.Icons.Skull, "Zombies Killed", data.ZombiesKilled, PvZTheme.Colors.TextWhite, 1),
					
					-- Waves completed
					self:_createRewardRow(PvZTheme.Icons.Wave, "Waves Completed", data.WavesCompleted, PvZTheme.Colors.SkyBlue, 2),
					
					-- Coins earned
					self:_createRewardRow(PvZTheme.Icons.Coin, "Coins Earned", data.CoinsEarned - data.BonusCoins, PvZTheme.Colors.CoinGold, 3),
					
					-- Victory bonus (if any)
					if data.BonusCoins > 0 then self:_createRewardRow(PvZTheme.Icons.Trophy, "Victory Bonus", "+" .. tostring(data.BonusCoins), PvZTheme.Colors.Victory, 4) else nil,
					
					-- Total
					self:_createRewardRow(PvZTheme.Icons.Star, "TOTAL", data.CoinsEarned, PvZTheme.Colors.GrassGreen, 5, true),
				},
			}),
		},
	})
	
	rewardsPanel.Parent = self._gui
	rewardsPanel.ZIndex = 101
	
	-- Fade in animation
	rewardsPanel.BackgroundTransparency = 1
	task.spawn(function()
		for i = 1, 10 do
			rewardsPanel.BackgroundTransparency = 1 - (i / 10)
			task.wait(0.03)
		end
	end)
end

-- Helper to create reward stat rows
function HUDController:_createRewardRow(icon: string, label: string, value: any, color: Color3, order: number, isBold: boolean?): Frame
	return New(self._scope, "Frame")({
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		
		[Children] = {
			-- Icon
			New(self._scope, "TextLabel")({
				Size = UDim2.fromOffset(24, 24),
				BackgroundTransparency = 1,
				Text = icon,
				TextScaled = true,
			}),
			
			-- Label
			PvZTheme.StrokedText(self._scope, {
				Position = UDim2.fromOffset(28, 0),
				Size = UDim2.new(0.5, -30, 1, 0),
				AnchorPoint = Vector2.zero,
				Text = label,
				TextColor3 = PvZTheme.Colors.TextWhite,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = if isBold then Enum.Font.GothamBlack else Enum.Font.GothamMedium,
			}),
			
			-- Value
			PvZTheme.StrokedText(self._scope, {
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(0.4, 0, 1, 0),
				AnchorPoint = Vector2.new(1, 0),
				Text = tostring(value),
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Right,
				Font = if isBold then Enum.Font.GothamBlack else Enum.Font.GothamBold,
			}),
		},
	})
end

return HUDController
