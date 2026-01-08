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
local PvZTheme = require(ReplicatedStorage.Shared.ui.PvZTheme)

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
			-- LEFT PANEL: Resources & Player Stats (PvZ Style)
			-- ============================================
			PvZTheme.WoodPanel(self._scope, {
				Name = "ResourcePanel",
				Position = UDim2.new(0, 15, 1, -200),
				Size = UDim2.fromOffset(160, 185),
				AnchorPoint = Vector2.new(0, 1),
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
				},
			}),
			
			-- ============================================
			-- TOP CENTER: Wave Banner (PvZ Style)
			-- ============================================
			PvZTheme.Banner(self._scope, {
				Name = "WaveBanner",
				Position = UDim2.new(0.5, 0, 0, 15),
				Size = Computed(self._scope, function(use)
					local intermission = use(self._intermissionTime)
					-- Wider banner during intermission to fit the text
					return if intermission > 0 
						then UDim2.fromOffset(350, 45)
						else UDim2.fromOffset(220, 45)
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				Text = Computed(self._scope, function(use)
					local wave = use(self._waveNumber)
					local intermission = use(self._intermissionTime)
					
					-- During intermission, show countdown
					if intermission > 0 then
						return `⏸️ Wave Complete! Next in {math.ceil(intermission)}s`
					elseif wave == 0 then
						return PvZTheme.Icons.Plant .. " GET READY!"
					else
						return PvZTheme.Icons.Wave .. " WAVE " .. tostring(wave)
					end
				end),
			}),
			
			-- ============================================
			-- READY BUTTON (Preparation Phase)
			-- ============================================
			New(self._scope, "TextButton") {
				Name = "ReadyButton",
				Position = UDim2.new(0.5, 0, 1, -180), -- Above CardDeck
				Size = UDim2.fromOffset(300, 60),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = PvZTheme.Colors.GrassGreen,
				Text = Computed(self._scope, function(use)
					local timeLeft = use(self._preparationTime)
					return `🌻 READY! ({timeLeft}s)`
				end),
				TextColor3 = PvZTheme.Colors.TextWhite,
				TextSize = 24,
				Font = Enum.Font.GothamBold,
				AutoButtonColor = true,
				Visible = self._preparationPhase,
				
				[OnEvent "Activated"] = function()
					Logger.Info("HUD", "Ready button clicked")
					self._preparationPhase:set(false)
					
					-- Send request to server
					local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
					local Network = require(Shared.network.generated.client)
					Network.StartWaveRequest.Fire({
						RequestId = math.random(1, 65535),
					})
				end,
				
				[Children] = {
					New(self._scope, "UICorner") {
						CornerRadius = UDim.new(0, 12),
					},
					New(self._scope, "UIStroke") {
						Color = PvZTheme.Colors.WoodDark,
						Thickness = 4,
					},
				},
			},
			
			-- ============================================
			-- INTERMISSION INDICATOR
			-- ============================================
			New(self._scope, "Frame") {
				Name = "IntermissionIndicator",
				Position = UDim2.new(0.5, 0, 0.3, 0),
				Size = UDim2.fromOffset(400, 80),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = PvZTheme.Colors.WoodBrown,
				Visible = Computed(self._scope, function(use)
					return use(self._intermissionTime) > 0 and use(self._teleportCountdown) == 0
				end),
				
				[Children] = {
					New(self._scope, "UICorner") {
						CornerRadius = UDim.new(0, 15),
					},
					New(self._scope, "UIStroke") {
						Color = PvZTheme.Colors.WoodDark,
						Thickness = 4,
					},
					PvZTheme.StrokedText(self._scope, {
						Name = "IntermissionText",
						Position = UDim2.new(0.5, 0, 0.5, -10),
						Size = UDim2.new(1, -20, 0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Text = "⏸️ Wave Complete!",
						TextColor3 = PvZTheme.Colors.CoinGold,
						TextSize = 26,
					}),
					PvZTheme.StrokedText(self._scope, {
						Name = "NextWaveText",
						Position = UDim2.new(0.5, 0, 0.5, 15),
						Size = UDim2.new(1, -20, 0.4, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Text = Computed(self._scope, function(use)
							local timeLeft = use(self._intermissionTime)
							return `Next wave in {math.ceil(timeLeft)}s`
						end),
						TextColor3 = PvZTheme.Colors.TextWhite,
						TextSize = 18,
					}),
				},
			},
			
			-- ============================================
			-- CENTER: Teleport Countdown
			-- ============================================
			New(self._scope, "Frame")({
				Name = "TeleportCountdown",
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.fromOffset(500, 120),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				BorderSizePixel = 0,
				Visible = Computed(self._scope, function(use)
					return use(self._teleportCountdown) > 0
				end),
				
				[Children] = {
					New(self._scope, "UICorner")({
						CornerRadius = UDim.new(0, 16),
					}),
					New(self._scope, "UIStroke")({
						Color = Color3.fromRGB(255, 215, 0),
						Thickness = 4,
					}),
					
					PvZTheme.StrokedText(self._scope, {
						Name = "Title",
						Position = UDim2.new(0.5, 0, 0.3, 0),
						Size = UDim2.new(0.9, 0, 0.3, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Text = "🏠 Returning to Lobby...",
						TextSize = 24,
						Font = Enum.Font.GothamBold,
						TextColor3 = Color3.fromRGB(255, 215, 0),
					}),
					
					PvZTheme.StrokedText(self._scope, {
						Name = "Countdown",
						Position = UDim2.new(0.5, 0, 0.7, 0),
						Size = UDim2.new(0.9, 0, 0.3, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Text = Computed(self._scope, function(use)
							local time = use(self._teleportCountdown)
							return `Teleporting in {time}...`
						end),
						TextSize = 28,
						Font = Enum.Font.GothamBold,
						TextColor3 = Color3.fromRGB(255, 255, 255),
					}),
				},
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
			
			-- Card Deck (bottom-center)
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
					Logger.Debug("HUDController", `Shovel mode: {Fusion.peek(SelectionState.ShovelMode)}`)
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

return HUDController
