--!strict
--[[
	HUD Controller - Arena Game HUD (Casual Theme)
	
	Modern Mobile Casual UI with glossy cartoon finish:
	- Sun counter + Resources (top-left squircle pills)
	- Wave indicator (top-center)
	- Base health bar (top-right)
	- Card deck with shovel (bottom)
	
	Design: Squircle shapes, vibrant colors, thick strokes, juicy animations
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PlantData = require(Shared.data.PlantData)
local GameSignals = require(Shared.signals.GameSignals)
local CasualTheme = require(Shared.ui.CasualTheme)

-- UI Components
local CardDeck = require(script.Parent.CardDeck)

-- Client modules
local Client = script.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)
local PlayerDataClient = require(Modules.PlayerDataClient)

-- Theme references
local Colors = CasualTheme.Colors
local Sizing = CasualTheme.Sizing
local Fonts = CasualTheme.Fonts

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local Computed = Fusion.Computed
local OnEvent = Fusion.OnEvent
local Spring = Fusion.Spring
local peek = Fusion.peek

-- Component builders from theme
local ResourcePill = CasualTheme.ResourcePill
local JuicyButton = CasualTheme.JuicyButton

local HUDController = {}
HUDController.__index = HUDController

function HUDController.new()
	local self = setmetatable({}, HUDController)
	
	-- Use shared selection state
	self._scope = Fusion.scoped({})
	self._trove = Trove.new()
	self._waveNumber = Value(self._scope, 0)
	self._baseHealth = Value(self._scope, 1000)
	self._baseMaxHealth = Value(self._scope, 1000)
	self._preparationPhase = Value(self._scope, true) -- Show Ready button during preparation
	self._preparationTime = Value(self._scope, 20) -- Countdown timer
	self._intermissionTime = Value(self._scope, 0) -- Intermission countdown
	self._teleportCountdown = Value(self._scope, 0) -- Teleport countdown
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
			-- TOP LEFT: Sun Counter (Large, prominent)
			-- ============================================
			New(self._scope, "Frame") {
				Name = "SunCounter",
				Position = UDim2.fromOffset(16, 16),
				Size = UDim2.fromOffset(130, 50),
				BackgroundColor3 = Colors.SunYellow,
				
				[Children] = {
					New(self._scope, "UICorner") { CornerRadius = UDim.new(0, Sizing.CornerRadiusMedium) },
					New(self._scope, "UIStroke") {
						Color = Colors.StrokeDark,
						Thickness = Sizing.StrokeThick,
					},
					New(self._scope, "UIGradient") {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 220)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 100)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 50)),
						}),
						Rotation = 90,
					},
					-- Sun icon
					New(self._scope, "TextLabel") {
						Size = UDim2.fromOffset(40, 50),
						Position = UDim2.fromOffset(5, 0),
						BackgroundTransparency = 1,
						Text = "☀️",
						TextSize = 30,
					},
					-- Sun count
					New(self._scope, "TextLabel") {
						Size = UDim2.new(1, -50, 1, 0),
						Position = UDim2.fromOffset(45, 0),
						BackgroundTransparency = 1,
						Text = Computed(self._scope, function(use)
							return tostring(use(SelectionState.SunCount))
						end),
						TextColor3 = Colors.TextWhite,
						TextSize = 26,
						Font = Fonts.Header,
						TextXAlignment = Enum.TextXAlignment.Center,
						
						[Children] = {
							New(self._scope, "UIStroke") {
								Color = Colors.StrokeDark,
								Thickness = 2,
							},
						},
					},
				},
			},
			
			-- ============================================
			-- TOP LEFT: Resources Row (Coins, Gems, Level)
			-- ============================================
			New(self._scope, "Frame") {
				Name = "ResourceBar",
				Position = UDim2.fromOffset(16, 72),
				Size = UDim2.fromOffset(260, 40),
				BackgroundTransparency = 1,
				
				[Children] = {
					New(self._scope, "UIListLayout") {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					},
					
					-- Coins pill
					ResourcePill(self._scope, {
						Icon = "💰",
						Value = PlayerDataClient.GetCoinsValue(),
						Color = Colors.CoinGold,
					}),
					
					-- Gems pill
					ResourcePill(self._scope, {
						Icon = "💎",
						Value = PlayerDataClient.GetGemsValue(),
						Color = Colors.GemPurple,
					}),
					
					-- Level badge
					New(self._scope, "Frame") {
						Name = "LevelBadge",
						Size = UDim2.fromOffset(70, 32),
						BackgroundColor3 = Colors.LevelBadgeBg,
						
						[Children] = {
							New(self._scope, "UICorner") { CornerRadius = UDim.new(0, 16) },
							New(self._scope, "UIStroke") {
								Color = Colors.StrokeDark,
								Thickness = Sizing.StrokeMedium,
							},
							New(self._scope, "UIGradient") {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
									ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 248, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 210, 230)),
								}),
								Rotation = 90,
							},
							New(self._scope, "TextLabel") {
								Size = UDim2.fromOffset(24, 32),
								Position = UDim2.fromOffset(4, 0),
								BackgroundTransparency = 1,
								Text = "⭐",
								TextSize = 16,
							},
							New(self._scope, "TextLabel") {
								Size = UDim2.new(1, -30, 1, 0),
								Position = UDim2.fromOffset(26, 0),
								BackgroundTransparency = 1,
								Text = Computed(self._scope, function(use)
									return "Lv" .. tostring(use(PlayerDataClient.GetLevelValue()))
								end),
								TextColor3 = Colors.TextWhite,
								TextSize = 14,
								Font = Fonts.Header,
								
								[Children] = {
									New(self._scope, "UIStroke") {
										Color = Colors.TextShadow,
										Thickness = 1,
									},
								},
							},
						},
					},
				},
			},
			
			-- ============================================
			-- TOP CENTER: Wave Banner (Casual Style)
			-- ============================================
			New(self._scope, "Frame") {
				Name = "WaveBanner",
				Position = UDim2.new(0.5, 0, 0, 16),
				Size = Computed(self._scope, function(use)
					local intermission = use(self._intermissionTime)
					return if intermission > 0 
						then UDim2.fromOffset(280, 50)
						else UDim2.fromOffset(180, 50)
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Colors.PrimaryGreen,
				
				[Children] = {
					New(self._scope, "UICorner") { CornerRadius = UDim.new(0, Sizing.CornerRadiusLarge) },
					New(self._scope, "UIStroke") {
						Color = Colors.StrokeDark,
						Thickness = Sizing.StrokeThick,
					},
					New(self._scope, "UIGradient") {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 255, 150)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 200, 100)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 150, 60)),
						}),
						Rotation = 90,
					},
					New(self._scope, "TextLabel") {
						Size = UDim2.new(1, -16, 1, 0),
						Position = UDim2.fromOffset(8, 0),
						BackgroundTransparency = 1,
						Text = Computed(self._scope, function(use)
							local wave = use(self._waveNumber)
							local intermission = use(self._intermissionTime)
							
							if intermission > 0 then
								return `⏸️ Next: {math.ceil(intermission)}s`
							elseif wave == 0 then
								return "🌱 GET READY!"
							else
								return `🧟 WAVE {wave}`
							end
						end),
						TextColor3 = Colors.TextWhite,
						TextSize = 22,
						Font = Fonts.Header,
						
						[Children] = {
							New(self._scope, "UIStroke") {
								Color = Colors.StrokeDark,
								Thickness = 2,
							},
						},
					},
				},
			},
			
			-- ============================================
			-- TOP RIGHT: Base Health Bar (Casual Style)
			-- ============================================
			New(self._scope, "Frame") {
				Name = "HealthPanel",
				Position = UDim2.new(1, -16, 0, 16),
				Size = UDim2.fromOffset(180, 45),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(60, 60, 70),
				
				[Children] = {
					New(self._scope, "UICorner") { CornerRadius = UDim.new(0, Sizing.CornerRadiusMedium) },
					New(self._scope, "UIStroke") {
						Color = Colors.StrokeDark,
						Thickness = Sizing.StrokeThick,
					},
					
					-- Heart icon
					New(self._scope, "TextLabel") {
						Size = UDim2.fromOffset(35, 45),
						Position = UDim2.fromOffset(5, 0),
						BackgroundTransparency = 1,
						Text = "❤️",
						TextSize = 24,
					},
					
					-- Health bar background
					New(self._scope, "Frame") {
						Name = "HealthBarBg",
						Position = UDim2.fromOffset(42, 10),
						Size = UDim2.new(1, -52, 0, 25),
						BackgroundColor3 = Color3.fromRGB(40, 40, 50),
						
						[Children] = {
							New(self._scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
							
							-- Health fill
							New(self._scope, "Frame") {
								Name = "Fill",
								Size = Computed(self._scope, function(use)
									local health = use(self._baseHealth)
									local maxHealth = use(self._baseMaxHealth)
									local ratio = math.clamp(health / maxHealth, 0, 1)
									return UDim2.new(ratio, 0, 1, 0)
								end),
								BackgroundColor3 = Computed(self._scope, function(use)
									local health = use(self._baseHealth)
									local maxHealth = use(self._baseMaxHealth)
									local ratio = health / maxHealth
									if ratio > 0.5 then
										return Colors.HealthGreen
									elseif ratio > 0.25 then
										return Colors.SunYellow
									else
										return Colors.HealthRed
									end
								end),
								
								[Children] = {
									New(self._scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
									New(self._scope, "UIGradient") {
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
											ColorSequenceKeypoint.new(0.3, Color3.fromRGB(220, 255, 220)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 220, 180)),
										}),
										Rotation = 90,
									},
								},
							},
							
							-- Health text
							New(self._scope, "TextLabel") {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = Computed(self._scope, function(use)
									return use(self._baseHealth) .. "/" .. use(self._baseMaxHealth)
								end),
								TextColor3 = Colors.TextWhite,
								TextSize = 14,
								Font = Fonts.Header,
								ZIndex = 2,
								
								[Children] = {
									New(self._scope, "UIStroke") {
										Color = Colors.StrokeDark,
										Thickness = 1,
									},
								},
							},
						},
					},
				},
			},
			
			-- ============================================
			-- READY BUTTON (Preparation Phase) - Juicy Style
			-- ============================================
			New(self._scope, "TextButton") {
				Name = "ReadyButton",
				Position = UDim2.new(0.5, 0, 1, -180),
				Size = UDim2.fromOffset(280, 60),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Colors.AccentOrange,
				Text = Computed(self._scope, function(use)
					local timeLeft = use(self._preparationTime)
					return `🌻 READY! ({timeLeft}s)`
				end),
				TextColor3 = Colors.TextWhite,
				TextSize = 24,
				Font = Fonts.Header,
				AutoButtonColor = false,
				Visible = self._preparationPhase,
				
				[OnEvent "Activated"] = function()
					Logger.Info("HUD", "Ready button clicked")
					self._preparationPhase:set(false)
					
					local Network = require(Shared.network.generated.client)
					Network.StartWaveRequest.Fire({
						RequestId = math.random(1, 65535),
					})
				end,
				
				[Children] = {
					New(self._scope, "UICorner") { CornerRadius = UDim.new(0, Sizing.CornerRadiusLarge) },
					New(self._scope, "UIStroke") {
						Color = Colors.StrokeDark,
						Thickness = Sizing.StrokeThick,
					},
					New(self._scope, "UIGradient") {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 150)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 180, 80)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 140, 40)),
						}),
						Rotation = 90,
					},
				},
			},
			
			-- ============================================
			-- INTERMISSION OVERLAY (Wave Complete!)
			-- ============================================
			New(self._scope, "Frame") {
				Name = "IntermissionIndicator",
				Position = UDim2.new(0.5, 0, 0.35, 0),
				Size = UDim2.fromOffset(340, 100),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Colors.PrimaryGreen,
				Visible = Computed(self._scope, function(use)
					return use(self._intermissionTime) > 0 and use(self._teleportCountdown) == 0
				end),
				
				[Children] = {
					New(self._scope, "UICorner") { CornerRadius = UDim.new(0, Sizing.CornerRadiusLarge) },
					New(self._scope, "UIStroke") {
						Color = Colors.StrokeDark,
						Thickness = Sizing.StrokeThick,
					},
					New(self._scope, "UIGradient") {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 255, 150)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 220, 100)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 60)),
						}),
						Rotation = 90,
					},
					
					-- "Wave Complete!" title
					New(self._scope, "TextLabel") {
						Size = UDim2.new(1, 0, 0.55, 0),
						Position = UDim2.fromOffset(0, 8),
						BackgroundTransparency = 1,
						Text = "🎉 Wave Complete!",
						TextColor3 = Colors.TextWhite,
						TextSize = 28,
						Font = Fonts.Header,
						
						[Children] = {
							New(self._scope, "UIStroke") {
								Color = Colors.StrokeDark,
								Thickness = 2,
							},
						},
					},
					
					-- Countdown text
					New(self._scope, "TextLabel") {
						Size = UDim2.new(1, 0, 0.4, 0),
						Position = UDim2.new(0, 0, 0.55, 0),
						BackgroundTransparency = 1,
						Text = Computed(self._scope, function(use)
							local timeLeft = use(self._intermissionTime)
							return `Next wave in {math.ceil(timeLeft)}s`
						end),
						TextColor3 = Colors.SunYellow,
						TextSize = 18,
						Font = Fonts.Body,
						
						[Children] = {
							New(self._scope, "UIStroke") {
								Color = Colors.StrokeDark,
								Thickness = 1,
							},
						},
					},
				},
			},
			
			-- ============================================
			-- TELEPORT COUNTDOWN (Returning to Lobby)
			-- ============================================
			New(self._scope, "Frame") {
				Name = "TeleportCountdown",
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.fromOffset(400, 120),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(50, 50, 60),
				Visible = Computed(self._scope, function(use)
					return use(self._teleportCountdown) > 0
				end),
				
				[Children] = {
					New(self._scope, "UICorner") { CornerRadius = UDim.new(0, Sizing.CornerRadiusLarge) },
					New(self._scope, "UIStroke") {
						Color = Colors.CoinGold,
						Thickness = Sizing.StrokeThick,
					},
					
					-- Title
					New(self._scope, "TextLabel") {
						Size = UDim2.new(1, 0, 0.45, 0),
						Position = UDim2.fromOffset(0, 15),
						BackgroundTransparency = 1,
						Text = "🏠 Returning to Lobby...",
						TextColor3 = Colors.CoinGold,
						TextSize = 24,
						Font = Fonts.Header,
						
						[Children] = {
							New(self._scope, "UIStroke") {
								Color = Colors.StrokeDark,
								Thickness = 2,
							},
						},
					},
					
					-- Countdown
					New(self._scope, "TextLabel") {
						Size = UDim2.new(1, 0, 0.4, 0),
						Position = UDim2.new(0, 0, 0.55, 0),
						BackgroundTransparency = 1,
						Text = Computed(self._scope, function(use)
							local time = use(self._teleportCountdown)
							return `Teleporting in {time}...`
						end),
						TextColor3 = Colors.TextWhite,
						TextSize = 28,
						Font = Fonts.Header,
						
						[Children] = {
							New(self._scope, "UIStroke") {
								Color = Colors.StrokeDark,
								Thickness = 2,
							},
						},
					},
				},
			},
			
			-- Card Deck (bottom-center) with Shovel
			CardDeck({
				Scope = self._scope,
				SelectedPlant = SelectionState.SelectedPlant,
				SunCount = SelectionState.SunCount,
				Cooldowns = SelectionState.Cooldowns,
				ShovelMode = SelectionState.ShovelMode,
				PlayerMutations = PlayerDataClient.GetMutationsValue(),
				OnSelect = onCardSelect,
				OnShovelToggle = function()
					SelectionState.ToggleShovel()
					Logger.Debug("HUDController", `Shovel mode: {peek(SelectionState.ShovelMode)}`)
				end,
			}),
		},
	})
	
	-- Connect to GameSignals (observer pattern)
	self:_setupSignalListeners()
	
	self._mounted = true
	Logger.Info("HUDController", "HUD mounted with CardDeck")
end

function HUDController:Unmount()
	if not self._mounted then
		return
	end
	
	self._trove:Destroy()
	Fusion.doCleanup(self._scope)
	self._mounted = false
	Logger.Info("HUDController", "HUD unmounted")
end

-- Private: Setup signal listeners for decoupled communication
function HUDController:_setupSignalListeners()
	-- Wave changed (from network or game state)
	self._trove:Connect(GameSignals.OnWaveChanged, function(data)
		self:SetWaveNumber(data.WaveNumber)
		if data.IsPreparation then
			self:StartPreparation()
		end
	end)
	
	-- Wave completed (triggers intermission)
	self._trove:Connect(GameSignals.OnWaveCompleted, function(data)
		self:SetIntermissionTime(data.IntermissionDuration or 30)
	end)
	
	-- Base health changed
	self._trove:Connect(GameSignals.OnBaseHealthChanged, function(data)
		self:SetBaseHealth(data.CurrentHealth, data.MaxHealth)
	end)
	
	-- Teleport countdown
	self._trove:Connect(GameSignals.OnTeleportCountdown, function(data)
		self:SetTeleportCountdown(data.TimeRemaining)
	end)
	
	-- Coin gained (show floating text)
	self._trove:Connect(GameSignals.OnCoinGained, function(data)
		self:ShowCoinGain(data.Amount, data.PositionX, data.PositionZ)
	end)
	
	Logger.Debug("HUDController", "Signal listeners connected")
end

function HUDController:SetWaveNumber(wave: number)
	self._waveNumber:set(wave)
	
	-- Hide preparation phase when first wave starts
	if wave > 0 then
		self._preparationPhase:set(false)
	end
end

function HUDController:SetPreparationTime(seconds: number)
	self._preparationTime:set(math.max(0, math.ceil(seconds)))
end

function HUDController:StartPreparation()
	self._preparationPhase:set(true)
	self._preparationTime:set(20)
end

function HUDController:SetIntermissionTime(seconds: number)
	self._intermissionTime:set(math.max(0, seconds))
end

function HUDController:SetTeleportCountdown(seconds: number)
	self._teleportCountdown:set(math.max(0, seconds))
end

function HUDController:SetBaseHealth(current: number, max: number)
	self._baseHealth:set(current)
	self._baseMaxHealth:set(max)
end

-- Show floating coin gain text (Casual Style)
function HUDController:ShowCoinGain(amount: number, worldX: number?, worldZ: number?)
	if not self._gui then
		return
	end
	
	-- Create floating text at coin counter location
	local floatingText = New(self._scope, "TextLabel")({
		Name = "CoinGain",
		Parent = self._gui,
		Position = UDim2.fromOffset(100, 90),
		Size = UDim2.fromOffset(80, 40),
		BackgroundTransparency = 1,
		Text = "+" .. tostring(amount),
		TextColor3 = Colors.CoinGold,
		TextScaled = true,
		Font = Fonts.Header,
		ZIndex = 50,
		
		[Children] = {
			New(self._scope, "UIStroke")({
				Color = Colors.StrokeDark,
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
			local yOffset = 90 - (progress * 50) -- Move up
			local alpha = 1 - progress -- Fade out
			
			floatingText.Position = UDim2.fromOffset(100, yOffset)
			floatingText.TextTransparency = 1 - alpha
			
			task.wait()
		end
		
		floatingText:Destroy()
	end)
end

return HUDController
