--!strict
--[[
	ResultScreen.luau - Victory/Defeat results screen
	
	Organism component displaying end-game summary.
	Features:
	- Result banner (Victory/Defeat)
	- Star rating (victory only)
	- Animated reward counters
	- Teleport countdown
	- Return to lobby button
	
	Uses Atomic Design with ToonPanel, RewardRow, StarRating, ResultBanner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Design = script.Parent.Parent.Parent.design
local Theme = require(Design.Theme)

local Atoms = script.Parent.Parent.atoms
local ToonPanel = require(Atoms.ToonPanel)
local ToonButton = require(Atoms.ToonButton)
local RewardRow = require(Atoms.RewardRow)

local Molecules = script.Parent.Parent.molecules
local ResultBanner = require(Molecules.ResultBanner)
local StarRating = require(Molecules.StarRating)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Spring = Fusion.Spring

-- Constants
local PANEL_WIDTH = 380
local PANEL_HEIGHT = 420

-- Reward colors
local RewardColors = {
	Coins = Color3.fromRGB(255, 200, 50),    -- Gold
	XP = Color3.fromRGB(100, 200, 255),      -- Blue
	Gems = Color3.fromRGB(200, 100, 255),    -- Purple
	Zombies = Color3.fromRGB(200, 80, 80),   -- Red
}

export type ResultScreenProps = {
	Scope: Fusion.Scope<any>,
	Visible: any, -- Fusion.Value<boolean>
	Victory: any, -- Fusion.Value<boolean>
	WaveReached: any, -- Fusion.Value<number>
	StarCount: any, -- Fusion.Value<number>
	CoinsEarned: any, -- Fusion.Value<number>
	XPEarned: any, -- Fusion.Value<number>
	GemsEarned: any, -- Fusion.Value<number>
	ZombiesKilled: any, -- Fusion.Value<number>
	TeleportCountdown: any, -- Fusion.Value<number>
	OnReturnToLobby: (() -> ())?,
}

--[[
	ResultScreen Component
	
	Displays the end-game results with animations.
	
	@param props ResultScreenProps
	@return Frame
]]
local function ResultScreen(props: ResultScreenProps): Frame
	local scope = props.Scope
	
	-- Animated scale for panel entrance
	local targetScale = Computed(scope, function(use)
		return if use(props.Visible) then 1.0 else 0.8
	end)
	local animatedScale = Spring(scope, targetScale, 25, 0.6)
	
	-- Animated transparency for overlay
	local overlayTransparency = Computed(scope, function(use)
		return if use(props.Visible) then 0.4 else 1
	end)
	local animatedOverlay = Spring(scope, overlayTransparency, 20, 1)
	
	-- Countdown text
	local countdownText = Computed(scope, function(use)
		local seconds = use(props.TeleportCountdown)
		if seconds > 0 then
			return `Retour au lobby dans {seconds}s...`
		end
		return ""
	end)
	
	-- Show gems row only if > 0
	local showGems = Computed(scope, function(use)
		return use(props.GemsEarned) > 0
	end)
	
	return New(scope, "Frame") {
		Name = "ResultScreenContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = Computed(scope, function(use)
			return use(props.Visible)
		end),
		ZIndex = 100,
		
		[Children] = {
			-- Dark overlay
			New(scope, "Frame") {
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = animatedOverlay,
				ZIndex = 1,
			},
			
			-- Main panel (centered)
			New(scope, "Frame") {
				Name = "PanelContainer",
				Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 10,
				
				[Children] = {
					New(scope, "UIScale") {
						Scale = animatedScale,
					},
					
					ToonPanel({
						Scope = scope,
						Size = UDim2.fromScale(1, 1),
						
						[Children] = {
							-- Content padding
							New(scope, "UIPadding") {
								PaddingLeft = UDim.new(0, 16),
								PaddingRight = UDim.new(0, 16),
								PaddingTop = UDim.new(0, 16),
								PaddingBottom = UDim.new(0, 16),
							},
							
							-- Vertical layout
							New(scope, "UIListLayout") {
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 12),
							},
							
							-- 1. Result Banner
							ResultBanner({
								Scope = scope,
								Victory = props.Victory,
								WaveReached = props.WaveReached,
								LayoutOrder = 1,
							}),
							
							-- 2. Star Rating (victory only)
							StarRating({
								Scope = scope,
								StarCount = props.StarCount,
								Visible = props.Victory,
								LayoutOrder = 2,
							}),
							
							-- 3. Separator
							New(scope, "Frame") {
								Size = UDim2.new(1, 0, 0, 2),
								BackgroundColor3 = Theme.Colors.Surface.Stroke,
								BackgroundTransparency = 0.5,
								LayoutOrder = 3,
							},
							
							-- 4. Rewards section
							New(scope, "Frame") {
								Name = "Rewards",
								Size = UDim2.new(1, 0, 0, 140),
								BackgroundTransparency = 1,
								LayoutOrder = 4,
								
								[Children] = {
									New(scope, "UIListLayout") {
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 6),
									},
									
									-- Zombies killed
									RewardRow({
										Scope = scope,
										Icon = "💀",
										Label = "Zombies tués",
										Value = props.ZombiesKilled,
										Color = RewardColors.Zombies,
										LayoutOrder = 1,
									}),
									
									-- Coins earned
									RewardRow({
										Scope = scope,
										Icon = "🪙",
										Label = "Pièces gagnées",
										Value = props.CoinsEarned,
										Color = RewardColors.Coins,
										Prefix = "+",
										LayoutOrder = 2,
									}),
									
									-- XP earned
									RewardRow({
										Scope = scope,
										Icon = "⭐",
										Label = "Expérience",
										Value = props.XPEarned,
										Color = RewardColors.XP,
										Prefix = "+",
										Suffix = " XP",
										LayoutOrder = 3,
									}),
									
									-- Gems (always created, visibility controlled internally)
									RewardRow({
										Scope = scope,
										Icon = "💎",
										Label = "Gemmes",
										Value = props.GemsEarned,
										Color = RewardColors.Gems,
										Prefix = "+",
										LayoutOrder = 4,
										Visible = showGems,
									}),
								},
							},
							
							-- 5. Countdown text
							New(scope, "TextLabel") {
								Name = "Countdown",
								Size = UDim2.new(1, 0, 0, 24),
								BackgroundTransparency = 1,
								Text = countdownText,
								TextColor3 = Theme.Colors.Surface.Stroke,
								TextSize = 14,
								Font = Theme.Typography.Fonts.Body,
								TextXAlignment = Enum.TextXAlignment.Center,
								LayoutOrder = 5,
							},
							
							-- 6. Return button
							ToonButton({
								Scope = scope,
								Text = "Retour au Lobby",
								Size = UDim2.new(1, 0, 0, 48),
								Color = "Action",
								OnClick = props.OnReturnToLobby or function() end,
								LayoutOrder = 6,
							}),
						},
					}),
				},
			},
		},
	}
end

return ResultScreen
