--!strict
--[[
	ResultScreen.luau - Victory/Defeat results screen (Responsive)
	
	Organism component displaying end-game summary.
	Features:
	- Result banner (Victory/Defeat)
	- Star rating (victory only)
	- Animated reward counters
	- Teleport countdown
	- Return to lobby button
	
	Uses Atomic Design with ToonPanel, RewardRow, StarRating, ResultBanner.
	
	Uses Fusion 0.3 scope:Method() syntax.
	Fully responsive with Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local ToonPanel = require(Shared.ui.components.base.ToonPanel)
local ToonButton = require(Shared.ui.components.base.ToonButton)
local RewardRow = require(Shared.ui.components.base.RewardRow)

local Molecules = script.Parent.Parent.molecules
local ResultBanner = require(Molecules.ResultBanner)
local StarRating = require(Molecules.StarRating)

-- Fusion 0.3 primitives
local Children = Fusion.Children

-- Reward colors
local RewardColors = {
	Coins = Color3.fromRGB(255, 200, 50), -- Gold
	XP = Color3.fromRGB(100, 200, 255), -- Blue
	Gems = Color3.fromRGB(200, 100, 255), -- Purple
	Zombies = Color3.fromRGB(200, 80, 80), -- Red
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
	ResultScreen Component (Responsive)
	
	Displays the end-game results with animations.
	Uses Scale-based sizing for responsive layout.
	
	@param props ResultScreenProps
	@return Frame
]]
local function ResultScreen(props: ResultScreenProps): Frame
	local scope = props.Scope

	-- Animated scale for panel entrance
	local targetScale = scope:Computed(function(use)
		return if use(props.Visible) then 1.0 else 0.8
	end)
	local animatedScale = scope:Spring(targetScale, 25, 0.6)

	-- Animated transparency for overlay
	local overlayTransparency = scope:Computed(function(use)
		return if use(props.Visible) then 0.4 else 1
	end)
	local animatedOverlay = scope:Spring(overlayTransparency, 20, 1)

	-- Countdown text
	local countdownText = scope:Computed(function(use)
		local seconds = use(props.TeleportCountdown)
		if seconds > 0 then
			return `Retour au lobby dans {seconds}s...`
		end
		return ""
	end)

	-- Show gems row only if > 0
	local showGems = scope:Computed(function(use)
		return use(props.GemsEarned) > 0
	end)

	return scope:New("Frame")({
		Name = "ResultScreenContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return use(props.Visible)
		end),
		ZIndex = 100,

		[Children] = {
			-- Dark overlay
			scope:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = animatedOverlay,
				ZIndex = 1,
			}),

			-- Main panel (centered, responsive)
			scope:New("Frame")({
				Name = "PanelContainer",
				Size = UDim2.fromScale(0.35, 0.6), -- 35% width, 60% height
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 10,

				[Children] = {
					-- Size constraints
					scope:New("UISizeConstraint")({
						MinSize = Vector2.new(320, 380),
						MaxSize = Vector2.new(450, 520),
					}),

					scope:New("UIScale")({
						Scale = animatedScale,
					}),

					ToonPanel({
						Scope = scope,
						Size = UDim2.fromScale(1, 1),

						[Children] = {
							-- Content padding (relative)
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0.04, 0),
								PaddingRight = UDim.new(0.04, 0),
								PaddingTop = UDim.new(0.04, 0),
								PaddingBottom = UDim.new(0.04, 0),
							}),

							-- Vertical layout
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0.025, 0), -- 2.5% padding
							}),

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
							scope:New("Frame")({
								Size = UDim2.fromScale(1, 0.005),
								BackgroundColor3 = Theme.Colors.Surface.Stroke,
								BackgroundTransparency = 0.5,
								LayoutOrder = 3,
							}),

							-- 4. Rewards section
							scope:New("Frame")({
								Name = "Rewards",
								Size = UDim2.fromScale(1, 0.35), -- 35% of panel
								BackgroundTransparency = 1,
								LayoutOrder = 4,

								[Children] = {
									scope:New("UIListLayout")({
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0.04, 0),
									}),

									-- Zombies killed
									RewardRow({
										Scope = scope,
										IconName = "Skull",
										Label = "Zombies tués",
										Value = props.ZombiesKilled,
										Color = RewardColors.Zombies,
										LayoutOrder = 1,
									}),

									-- Coins earned
									RewardRow({
										Scope = scope,
										IconName = "Coin",
										Label = "Pièces gagnées",
										Value = props.CoinsEarned,
										Color = RewardColors.Coins,
										Prefix = "+",
										LayoutOrder = 2,
									}),

									-- XP earned
									RewardRow({
										Scope = scope,
										IconName = "Star",
										Label = "Expérience",
										Value = props.XPEarned,
										Color = RewardColors.XP,
										Prefix = "+",
										Suffix = " XP",
										LayoutOrder = 3,
									}),

									-- Gems (visibility controlled internally)
									RewardRow({
										Scope = scope,
										IconName = "Gem",
										Label = "Gemmes",
										Value = props.GemsEarned,
										Color = RewardColors.Gems,
										Prefix = "+",
										LayoutOrder = 4,
										Visible = showGems,
									}),
								},
							}),

							-- 5. Countdown text (responsive)
							scope:New("TextLabel")({
								Name = "Countdown",
								Size = UDim2.fromScale(1, 0.06),
								BackgroundTransparency = 1,
								Text = countdownText,
								TextColor3 = Theme.Colors.Surface.Stroke,
								TextScaled = true,
								Font = Theme.Typography.Fonts.Body,
								TextXAlignment = Enum.TextXAlignment.Center,
								LayoutOrder = 5,

								[Children] = {
									scope:New("UITextSizeConstraint")({
										MaxTextSize = 14,
										MinTextSize = 10,
									}),
								},
							}),

							-- 6. Return button (responsive)
							ToonButton({
								Scope = scope,
								Text = "Retour au Lobby",
								Size = UDim2.fromScale(1, 0.12),
								Color = "Action",
								OnClick = props.OnReturnToLobby or function() end,
								LayoutOrder = 6,
							}),
						},
					}),
				},
			}),
		},
	})
end

return ResultScreen
