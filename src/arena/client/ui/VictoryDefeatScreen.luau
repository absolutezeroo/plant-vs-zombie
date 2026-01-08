--!strict
--[[
	VictoryDefeatScreen.luau - Animated end-game results screen
	
	Features:
	- Victory/Defeat banner with entrance animation
	- Sequential star reveal (1-2-3 with delay and scale pop)
	- Animated counting for Coins, XP, Gems
	- Smooth transitions
	- Return to Lobby button
	
	Style: Plants vs Zombies classic look
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- UI Components
local PvZTheme = require(ReplicatedStorage.Shared.ui.PvZTheme)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local Computed = Fusion.Computed
local OnEvent = Fusion.OnEvent

-- Audio service (lazy loaded)
local _audioService: any = nil
local function getAudioService()
	if not _audioService then
		local Client = script.Parent.Parent
		local Modules = Client:WaitForChild("modules")
		local success, result = pcall(function()
			return require(Modules.AudioService)
		end)
		if success then
			_audioService = result
		end
	end
	return _audioService
end

export type RewardsData = {
	Victory: boolean,
	WaveReached: number,
	StarRating: number,
	CoinsEarned: number,
	XPEarned: number,
	GemsEarned: number,
	ZombiesKilled: number,
	BonusCoins: number,
	NewLevel: number?,
	LevelsGained: number?,
	IsFirstClear: boolean?,
	IsNewBest: boolean?,
}

local VictoryDefeatScreen = {}
VictoryDefeatScreen.__index = VictoryDefeatScreen

function VictoryDefeatScreen.new()
	local self = setmetatable({}, VictoryDefeatScreen)
	
	self._scope = Fusion.scoped({})
	
	-- Animation state
	self._visible = Value(self._scope, false)
	self._victory = Value(self._scope, false)
	self._waveReached = Value(self._scope, 0)
	
	-- Star animation states (0 = hidden, 1 = showing, 2 = golden)
	self._star1State = Value(self._scope, 0)
	self._star2State = Value(self._scope, 0)
	self._star3State = Value(self._scope, 0)
	self._targetStars = 0
	
	-- Animated counters (display value, animated)
	self._displayCoins = Value(self._scope, 0)
	self._displayXP = Value(self._scope, 0)
	self._displayGems = Value(self._scope, 0)
	self._displayZombies = Value(self._scope, 0)
	
	-- Target values (actual rewards)
	self._targetCoins = 0
	self._targetXP = 0
	self._targetGems = 0
	self._targetZombies = 0
	
	-- Bonus info
	self._bonusCoins = Value(self._scope, 0)
	self._newLevel = Value(self._scope, 0)
	self._levelsGained = Value(self._scope, 0)
	self._isFirstClear = Value(self._scope, false)
	self._isNewBest = Value(self._scope, false)
	
	-- Teleport countdown
	self._teleportCountdown = Value(self._scope, 0)
	
	-- Animation state
	self._animating = false
	self._gui = nil :: ScreenGui?
	
	return self
end

-- Animate a counter from current to target
function VictoryDefeatScreen:_animateCounter(valueObj: any, target: number, duration: number)
	local startValue = Fusion.peek(valueObj)
	local startTime = tick()
	
	task.spawn(function()
		while tick() - startTime < duration do
			local progress = (tick() - startTime) / duration
			-- Ease out quad
			local easedProgress = 1 - (1 - progress) * (1 - progress)
			local current = math.floor(startValue + (target - startValue) * easedProgress)
			valueObj:set(current)
			task.wait()
		end
		valueObj:set(target)
	end)
end

-- Animate stars appearing one by one
function VictoryDefeatScreen:_animateStars(count: number)
	local audio = getAudioService()
	
	-- Star 1
	task.delay(0.5, function()
		if count >= 1 then
			self._star1State:set(2) -- Golden
			if audio then audio.PlayStarEarned() end
		else
			self._star1State:set(1) -- Empty
		end
	end)
	
	-- Star 2
	task.delay(0.9, function()
		if count >= 2 then
			self._star2State:set(2)
			if audio then audio.PlayStarEarned() end
		else
			self._star2State:set(1)
		end
	end)
	
	-- Star 3
	task.delay(1.3, function()
		if count >= 3 then
			self._star3State:set(2)
			if audio then audio.PlayStarEarned() end
		else
			self._star3State:set(1)
		end
	end)
end

-- Show the screen with rewards data
function VictoryDefeatScreen:Show(data: RewardsData)
	if self._animating then return end
	self._animating = true
	
	Logger.Info("VictoryScreen", `Showing {if data.Victory then "VICTORY" else "DEFEAT"} screen`)
	
	-- Set static values
	self._victory:set(data.Victory)
	self._waveReached:set(data.WaveReached)
	self._bonusCoins:set(data.BonusCoins or 0)
	self._newLevel:set(data.NewLevel or 0)
	self._levelsGained:set(data.LevelsGained or 0)
	self._isFirstClear:set(data.IsFirstClear or false)
	self._isNewBest:set(data.IsNewBest or false)
	
	-- Store targets
	self._targetStars = data.StarRating
	self._targetCoins = data.CoinsEarned
	self._targetXP = data.XPEarned
	self._targetGems = data.GemsEarned
	self._targetZombies = data.ZombiesKilled
	
	-- Reset display values
	self._displayCoins:set(0)
	self._displayXP:set(0)
	self._displayGems:set(0)
	self._displayZombies:set(0)
	self._star1State:set(0)
	self._star2State:set(0)
	self._star3State:set(0)
	
	-- Show overlay
	self._visible:set(true)
	
	-- Play sound
	local audio = getAudioService()
	if audio then
		if data.Victory then
			audio.PlayVictory()
		else
			audio.PlayDefeat()
		end
	end
	
	-- Start animations sequence
	task.spawn(function()
		-- Wait for panel entrance
		task.wait(0.3)
		
		-- Animate stars (victory only)
		if data.Victory then
			self:_animateStars(data.StarRating)
		end
		
		-- Wait then animate counters
		task.wait(0.8)
		
		-- Zombies killed (fast)
		self:_animateCounter(self._displayZombies, data.ZombiesKilled, 0.5)
		
		task.wait(0.3)
		
		-- Coins (medium speed)
		self:_animateCounter(self._displayCoins, data.CoinsEarned, 0.8)
		if audio then audio.PlayCoinCount() end
		
		task.wait(0.4)
		
		-- XP
		self:_animateCounter(self._displayXP, data.XPEarned, 0.6)
		
		task.wait(0.3)
		
		-- Gems (if any)
		if data.GemsEarned > 0 then
			self:_animateCounter(self._displayGems, data.GemsEarned, 0.4)
		end
		
		self._animating = false
	end)
end

-- Hide the screen
function VictoryDefeatScreen:Hide()
	self._visible:set(false)
	self._animating = false
end

-- Update teleport countdown
function VictoryDefeatScreen:SetTeleportCountdown(seconds: number)
	self._teleportCountdown:set(seconds)
end

-- Create a single animated star
function VictoryDefeatScreen:_createStar(scope: any, stateValue: any, index: number): Frame
	return New(scope, "Frame")({
		Name = `Star{index}`,
		Size = UDim2.fromOffset(55, 55),
		BackgroundTransparency = 1,
		LayoutOrder = index,
		
		[Children] = {
			New(scope, "TextLabel")({
				Name = "StarIcon",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = Computed(scope, function(use)
					local state = use(stateValue)
					if state == 0 then return "" -- Hidden
					elseif state == 1 then return "☆" -- Empty
					else return "⭐" -- Golden
					end
				end),
				TextScaled = true,
				TextTransparency = Computed(scope, function(use)
					return if use(stateValue) == 0 then 1 else 0
				end),
			}),
		},
	})
end

-- Create reward row with animated value
function VictoryDefeatScreen:_createRewardRow(
	scope: any, 
	icon: string, 
	label: string, 
	valueObj: any, 
	color: Color3, 
	order: number,
	prefix: string?
): Frame
	return New(scope, "Frame")({
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		
		[Children] = {
			-- Icon
			New(scope, "TextLabel")({
				Size = UDim2.fromOffset(28, 28),
				Position = UDim2.fromOffset(0, 2),
				BackgroundTransparency = 1,
				Text = icon,
				TextScaled = true,
			}),
			
			-- Label
			PvZTheme.StrokedText(scope, {
				Position = UDim2.fromOffset(32, 0),
				Size = UDim2.new(0.5, -35, 1, 0),
				AnchorPoint = Vector2.zero,
				Text = label,
				TextColor3 = PvZTheme.Colors.TextWhite,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.GothamMedium,
			}),
			
			-- Animated Value
			PvZTheme.StrokedText(scope, {
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(0.4, 0, 1, 0),
				AnchorPoint = Vector2.new(1, 0),
				Text = Computed(scope, function(use)
					local val = use(valueObj)
					return (prefix or "") .. tostring(val)
				end),
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Right,
				Font = Enum.Font.GothamBold,
			}),
		},
	})
end

-- Mount the screen to PlayerGui
function VictoryDefeatScreen:Mount()
	local Players = game:GetService("Players")
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	
	self._gui = New(self._scope, "ScreenGui")({
		Name = "VictoryDefeatScreen",
		Parent = PlayerGui,
		ResetOnSpawn = false,
		DisplayOrder = 200, -- Above HUD
		IgnoreGuiInset = true,
		
		[Children] = {
			-- Dark overlay
			New(self._scope, "Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = Computed(self._scope, function(use)
					return if use(self._visible) then 0.5 else 1
				end),
				Visible = Computed(self._scope, function(use)
					return use(self._visible)
				end),
				ZIndex = 1,
			}),
			
			-- Main panel
			New(self._scope, "Frame")({
				Name = "MainPanel",
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(440, 420),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = PvZTheme.Colors.WoodBrown,
				Visible = Computed(self._scope, function(use)
					return use(self._visible)
				end),
				ZIndex = 10,
				
				[Children] = {
					New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 16) }),
					New(self._scope, "UIStroke")({
						Color = PvZTheme.Colors.WoodDark,
						Thickness = 4,
					}),
					
					-- ============================================
					-- TITLE BANNER
					-- ============================================
					New(self._scope, "Frame")({
						Name = "TitleBanner",
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.new(1, 0, 0, 65),
						BackgroundColor3 = Computed(self._scope, function(use)
							return if use(self._victory)
								then PvZTheme.Colors.GrassGreen
								else Color3.fromRGB(140, 45, 45)
						end),
						ZIndex = 11,
						
						[Children] = {
							New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 16) }),
							
							-- Trophy/Skull icon
							New(self._scope, "TextLabel")({
								Name = "ResultIcon",
								Position = UDim2.fromOffset(15, 7),
								Size = UDim2.fromOffset(50, 50),
								BackgroundTransparency = 1,
								Text = Computed(self._scope, function(use)
									return if use(self._victory) then "🏆" else "💀"
								end),
								TextScaled = true,
								ZIndex = 12,
							}),
							
							-- Victory/Defeat text
							PvZTheme.StrokedText(self._scope, {
								Name = "ResultText",
								Position = UDim2.fromOffset(75, 7),
								Size = UDim2.new(1, -90, 0, 50),
								AnchorPoint = Vector2.zero,
								Text = Computed(self._scope, function(use)
									return if use(self._victory) then "VICTORY!" else "DEFEAT..."
								end),
								TextColor3 = PvZTheme.Colors.TextWhite,
								TextXAlignment = Enum.TextXAlignment.Left,
								Font = Enum.Font.GothamBlack,
							}),
						},
					}),
					
					-- ============================================
					-- STAR RATING (Victory only)
					-- ============================================
					New(self._scope, "Frame")({
						Name = "StarContainer",
						Position = UDim2.fromOffset(0, 75),
						Size = UDim2.new(1, 0, 0, 60),
						BackgroundTransparency = 1,
						Visible = Computed(self._scope, function(use)
							return use(self._victory)
						end),
						ZIndex = 11,
						
						[Children] = {
							New(self._scope, "UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 15),
							}),
							
							self:_createStar(self._scope, self._star1State, 1),
							self:_createStar(self._scope, self._star2State, 2),
							self:_createStar(self._scope, self._star3State, 3),
						},
					}),
					
					-- Wave reached (Defeat only)
					PvZTheme.StrokedText(self._scope, {
						Name = "WaveReached",
						Position = UDim2.fromOffset(20, 85),
						Size = UDim2.new(1, -40, 0, 40),
						Visible = Computed(self._scope, function(use)
							return not use(self._victory)
						end),
						Text = Computed(self._scope, function(use)
							return "Reached Wave " .. tostring(use(self._waveReached))
						end),
						TextColor3 = PvZTheme.Colors.TextWhite,
						Font = Enum.Font.GothamMedium,
					}),
					
					-- ============================================
					-- REWARDS SECTION
					-- ============================================
					New(self._scope, "Frame")({
						Name = "RewardsSection",
						Position = UDim2.fromOffset(25, 145),
						Size = UDim2.new(1, -50, 0, 160),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						BackgroundTransparency = 0.5,
						ZIndex = 11,
						
						[Children] = {
							New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 10) }),
							New(self._scope, "UIPadding")({
								PaddingLeft = UDim.new(0, 12),
								PaddingRight = UDim.new(0, 12),
								PaddingTop = UDim.new(0, 8),
								PaddingBottom = UDim.new(0, 8),
							}),
							New(self._scope, "UIListLayout")({
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							
							-- Zombies killed
							self:_createRewardRow(self._scope, `{PvZTheme.Icons.Skull}`, "Zombies Killed", self._displayZombies, PvZTheme.Colors.TextWhite, 1, ""),
							
							-- Coins earned
							self:_createRewardRow(self._scope, `{PvZTheme.Icons.Coin}`, "Coins", self._displayCoins, PvZTheme.Colors.CoinGold, 2, "+"),
							
							-- XP earned
							self:_createRewardRow(self._scope, `{PvZTheme.Icons.Star}`, "XP", self._displayXP, PvZTheme.Colors.XPPurple, 3, "+"),
							
							-- Gems earned (visible only if > 0)
							New(self._scope, "Frame")({
								Size = UDim2.new(1, 0, 0, 32),
								BackgroundTransparency = 1,
								LayoutOrder = 4,
								Visible = Computed(self._scope, function(use)
									return use(self._displayGems) > 0 or self._targetGems > 0
								end),
								
								[Children] = {
									New(self._scope, "TextLabel")({
										Size = UDim2.fromOffset(28, 28),
										Position = UDim2.fromOffset(0, 2),
										BackgroundTransparency = 1,
										Text = "💎",
										TextScaled = true,
									}),
									PvZTheme.StrokedText(self._scope, {
										Position = UDim2.fromOffset(32, 0),
										Size = UDim2.new(0.5, -35, 1, 0),
										AnchorPoint = Vector2.zero,
										Text = "Gems",
										TextColor3 = PvZTheme.Colors.TextWhite,
										TextXAlignment = Enum.TextXAlignment.Left,
										Font = Enum.Font.GothamMedium,
									}),
									PvZTheme.StrokedText(self._scope, {
										Position = UDim2.new(1, 0, 0, 0),
										Size = UDim2.new(0.4, 0, 1, 0),
										AnchorPoint = Vector2.new(1, 0),
										Text = Computed(self._scope, function(use)
											return "+" .. tostring(use(self._displayGems))
										end),
										TextColor3 = PvZTheme.Colors.GemCyan,
										TextXAlignment = Enum.TextXAlignment.Right,
										Font = Enum.Font.GothamBold,
									}),
								},
							}),
							
							-- Level up notification
							New(self._scope, "Frame")({
								Size = UDim2.new(1, 0, 0, 32),
								BackgroundTransparency = 1,
								LayoutOrder = 5,
								Visible = Computed(self._scope, function(use)
									return use(self._levelsGained) > 0
								end),
								
								[Children] = {
									New(self._scope, "TextLabel")({
										Size = UDim2.fromOffset(28, 28),
										Position = UDim2.fromOffset(0, 2),
										BackgroundTransparency = 1,
										Text = "🎉",
										TextScaled = true,
									}),
									PvZTheme.StrokedText(self._scope, {
										Position = UDim2.fromOffset(32, 0),
										Size = UDim2.new(1, -35, 1, 0),
										AnchorPoint = Vector2.zero,
										Text = Computed(self._scope, function(use)
											local levels = use(self._levelsGained)
											local newLvl = use(self._newLevel)
											if levels == 1 then
												return `LEVEL UP! Now Level {newLvl}`
											else
												return `+{levels} LEVELS! Now Level {newLvl}`
											end
										end),
										TextColor3 = PvZTheme.Colors.Victory,
										TextXAlignment = Enum.TextXAlignment.Left,
										Font = Enum.Font.GothamBold,
									}),
								},
							}),
						},
					}),
					
					-- ============================================
					-- BADGES (First Clear, New Best)
					-- ============================================
					New(self._scope, "Frame")({
						Name = "BadgesRow",
						Position = UDim2.fromOffset(25, 315),
						Size = UDim2.new(1, -50, 0, 30),
						BackgroundTransparency = 1,
						ZIndex = 11,
						
						[Children] = {
							New(self._scope, "UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 15),
							}),
							
							-- First Clear badge
							New(self._scope, "TextLabel")({
								Size = UDim2.fromOffset(120, 28),
								BackgroundColor3 = Color3.fromRGB(255, 200, 50),
								BackgroundTransparency = 0.2,
								Text = "🌟 FIRST CLEAR!",
								TextColor3 = Color3.fromRGB(80, 50, 0),
								Font = Enum.Font.GothamBold,
								TextScaled = true,
								Visible = Computed(self._scope, function(use)
									return use(self._isFirstClear)
								end),
								[Children] = {
									New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 6) }),
									New(self._scope, "UIPadding")({
										PaddingLeft = UDim.new(0, 5),
										PaddingRight = UDim.new(0, 5),
									}),
								},
							}),
							
							-- New Best badge
							New(self._scope, "TextLabel")({
								Size = UDim2.fromOffset(100, 28),
								BackgroundColor3 = Color3.fromRGB(100, 200, 255),
								BackgroundTransparency = 0.2,
								Text = "⬆️ NEW BEST!",
								TextColor3 = Color3.fromRGB(0, 50, 100),
								Font = Enum.Font.GothamBold,
								TextScaled = true,
								Visible = Computed(self._scope, function(use)
									return use(self._isNewBest) and not use(self._isFirstClear)
								end),
								[Children] = {
									New(self._scope, "UICorner")({ CornerRadius = UDim.new(0, 6) }),
									New(self._scope, "UIPadding")({
										PaddingLeft = UDim.new(0, 5),
										PaddingRight = UDim.new(0, 5),
									}),
								},
							}),
						},
					}),
					
					-- ============================================
					-- TELEPORT COUNTDOWN
					-- ============================================
					New(self._scope, "Frame")({
						Name = "TeleportSection",
						Position = UDim2.fromOffset(25, 355),
						Size = UDim2.new(1, -50, 0, 50),
						BackgroundTransparency = 1,
						ZIndex = 11,
						
						[Children] = {
							PvZTheme.StrokedText(self._scope, {
								Name = "TeleportText",
								Size = UDim2.fromScale(1, 1),
								Text = Computed(self._scope, function(use)
									local countdown = use(self._teleportCountdown)
									if countdown > 0 then
										return `🏠 Returning to Lobby in {countdown}...`
									else
										return "🏠 Returning to Lobby..."
									end
								end),
								TextColor3 = PvZTheme.Colors.TextGold,
								Font = Enum.Font.GothamMedium,
							}),
						},
					}),
				},
			}),
		},
	})
	
	Logger.Info("VictoryScreen", "Mounted")
end

-- Cleanup
function VictoryDefeatScreen:Unmount()
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	Fusion.doCleanup(self._scope)
end

return VictoryDefeatScreen
