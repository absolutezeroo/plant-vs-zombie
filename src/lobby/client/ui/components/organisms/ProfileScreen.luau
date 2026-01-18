--!nonstrict
--[[
	ProfileScreen.luau - Player profile overlay screen (Fusion 0.3 Responsive)
	
	Organism displaying player stats, level progress, and win rate.
	Uses "Toon Pop" design system with atomic components.
	
	Fully responsive using Scale-based sizing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local IconAssets = require(Shared.ui.design.IconAssets)

local Icon = require(Shared.ui.components.base.Icon)

-- Shared UI components
local LevelBadge = require(Shared.ui.components.indicators.LevelBadge)
local ResourcePill = require(Shared.ui.components.indicators.ResourcePill)
local StatCard = require(Shared.ui.components.cards.StatCard)
local XPBar = require(Shared.ui.components.indicators.XPBar)

-- Local atoms (lobby-specific)
local Atoms = script.Parent.Parent.atoms
local AvatarFrame = require(Atoms.AvatarFrame)
local WinRateBanner = require(Atoms.WinRateBanner)

-- Fusion 0.3 scope-based primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

-- Get dynamic title based on level
local function getTitleForLevel(level: number): string
	if level >= 50 then
		return "Legendary Guardian"
	elseif level >= 40 then
		return "Master Gardener"
	elseif level >= 30 then
		return "Zombie Slayer"
	elseif level >= 20 then
		return "Plant Defender"
	elseif level >= 10 then
		return "Garden Keeper"
	elseif level >= 5 then
		return "Sprout Tender"
	else
		return "Novice Gardener"
	end
end

export type ProfileScreenProps = {
	Scope: any, -- Fusion scope
	-- Player data values
	Level: any, -- Fusion.Value<number>
	XP: any, -- Fusion.Value<number>
	XPRequired: any, -- Fusion.Value<number>
	Coins: any, -- Fusion.Value<number>
	Gems: any, -- Fusion.Value<number>
	GamesPlayed: any, -- Fusion.Value<number>
	GamesWon: any, -- Fusion.Value<number>
	ZombiesKilled: any, -- Fusion.Value<number>
	PlantsPlaced: any, -- Fusion.Value<number>
	-- Callbacks
	OnClose: () -> (),
}

local function ProfileScreen(props: ProfileScreenProps)
	local scope = props.Scope
	local player = Players.LocalPlayer

	-- Animation states
	local isPressed = scope:Value(false)

	-- Press animation for close button
	local pressOffset = scope:Spring(
		scope:Computed(function(use)
			return if use(isPressed) then 4 else 0
		end),
		40,
		0.7
	)

	-- Dynamic title
	local title = scope:Computed(function(use)
		return getTitleForLevel(use(props.Level))
	end)

	return scope:New("Frame")({
		Name = "ProfileScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		ZIndex = 100,

		[Children] = {
			-- Center panel (responsive width, auto height)
			scope:New("Frame")({
				Name = "Panel",
				Size = UDim2.fromScale(0.35, 0.85),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					-- Constrain minimum/maximum width
					scope:New("UISizeConstraint")({
						MinSize = Vector2.new(320, 0),
						MaxSize = Vector2.new(500, 9999),
					}),

					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0.02, 0),
					}),

					-- Header Card (20% of panel)
					scope:New("Frame")({
						Name = "Header",
						Size = UDim2.fromScale(1, 0.18),
						BackgroundTransparency = 1,
						LayoutOrder = 1,

						[Children] = {
							-- Shadow
							scope:New("Frame")({
								Name = "Shadow",
								Size = UDim2.fromScale(1, 0.95),
								Position = UDim2.fromScale(0.5, 0.05),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Layout.CornerRadius,
									}),
								},
							}),

							-- Main header
							scope:New("Frame")({
								Name = "Main",
								Size = UDim2.fromScale(1, 0.95),
								Position = UDim2.fromScale(0.5, 0),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ZIndex = 2,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Layout.CornerRadius,
									}),

									scope:New("UIStroke")({
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									}),

									-- Avatar container (square)
									scope:New("Frame")({
										Name = "AvatarContainer",
										Size = UDim2.fromScale(0.22, 0.7),
										Position = UDim2.fromScale(0.05, 0.15),
										BackgroundTransparency = 1,

										[Children] = {
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 1,
												DominantAxis = Enum.DominantAxis.Height,
											}),
											AvatarFrame({
												Scope = scope,
												Size = 80,
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
												BorderColor = Theme.Colors.Info.Main,
											}),
										},
									}),

									-- Level badge (overlapping avatar)
									scope:New("Frame")({
										Name = "LevelBadgeContainer",
										Size = UDim2.fromScale(0.1, 0.35),
										Position = UDim2.fromScale(0.2, 0.6),
										BackgroundTransparency = 1,
										ZIndex = 3,

										[Children] = {
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 1,
												DominantAxis = Enum.DominantAxis.Height,
											}),
											LevelBadge({
												Scope = scope,
												Level = props.Level,
												Size = 36,
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
											}),
										},
									}),

									-- Player name
									scope:New("TextLabel")({
										Name = "Name",
										Size = UDim2.fromScale(0.5, 0.25),
										Position = UDim2.fromScale(0.3, 0.15),
										BackgroundTransparency = 1,
										Text = player.DisplayName,
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Title,
										TextXAlignment = Enum.TextXAlignment.Left,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MaxTextSize = 24,
												MinTextSize = 14,
											}),
										},
									}),

									-- Title
									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.fromScale(0.5, 0.18),
										Position = UDim2.fromScale(0.3, 0.4),
										BackgroundTransparency = 1,
										Text = title,
										TextColor3 = Theme.Colors.Action.Main,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Body,
										TextXAlignment = Enum.TextXAlignment.Left,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MaxTextSize = 16,
												MinTextSize = 10,
											}),
										},
									}),

									-- Resources row
									scope:New("Frame")({
										Name = "Resources",
										Size = UDim2.fromScale(0.55, 0.28),
										Position = UDim2.fromScale(0.3, 0.62),
										BackgroundTransparency = 1,

										[Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												Padding = UDim.new(0.05, 0),
											}),

											ResourcePill({
												Scope = scope,
												IconName = "Coin",
												Value = props.Coins,
												Color = "Gold",
												Width = 90,
												LayoutOrder = 1,
											}),

											ResourcePill({
												Scope = scope,
												IconName = "Gem",
												Value = props.Gems,
												Color = "Purple",
												Width = 90,
												LayoutOrder = 2,
											}),
										},
									}),

									-- Close button (square)
									scope:New("Frame")({
										Name = "CloseButtonContainer",
										Size = UDim2.fromScale(0.12, 0.4),
										Position = UDim2.fromScale(0.97, 0.1),
										AnchorPoint = Vector2.new(1, 0),
										BackgroundTransparency = 1,

										[Children] = {
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 1,
												DominantAxis = Enum.DominantAxis.Height,
											}),

											-- Shadow
											scope:New("Frame")({
												Name = "Shadow",
												Size = UDim2.fromScale(1, 0.9),
												Position = UDim2.fromScale(0.5, 0.1),
												AnchorPoint = Vector2.new(0.5, 0),
												BackgroundColor3 = Theme.Colors.Danger.Shadow,
												ZIndex = 1,

												[Children] = {
													scope:New("UICorner")({
														CornerRadius = Theme.Layout.CornerRadius,
													}),
												},
											}),

											-- Button
											scope:New("TextButton")({
												Name = "CloseButton",
												Size = scope:Computed(function(use)
													local offset = use(pressOffset)
													return UDim2.fromScale(1, 0.9 - offset * 0.01)
												end),
												Position = scope:Computed(function(use)
													return UDim2.fromScale(0.5, use(pressOffset) * 0.01)
												end),
												AnchorPoint = Vector2.new(0.5, 0),
												BackgroundColor3 = Theme.Colors.Danger.Main,
												Text = "",
												AutoButtonColor = false,
												ZIndex = 2,

												[OnEvent("MouseButton1Down")] = function()
													isPressed:set(true)
												end,

												[OnEvent("MouseButton1Up")] = function()
													isPressed:set(false)
													props.OnClose()
												end,

												[OnEvent("MouseLeave")] = function()
													isPressed:set(false)
												end,

												[Children] = {
													scope:New("UICorner")({
														CornerRadius = Theme.Layout.CornerRadius,
													}),
													scope:New("UIStroke")({
														Color = Theme.Colors.Surface.Stroke :: Color3,
														Thickness = 2,
													}),
													Icon(scope, {
														Name = "Close",
														Size = UDim2.fromScale(0.6, 0.6),
														Position = UDim2.fromScale(0.5, 0.5),
														AnchorPoint = Vector2.new(0.5, 0.5),
													}),
												},
											}),
										},
									}),
								},
							}),
						},
					}),

					-- Level & XP Card (15% of panel)
					scope:New("Frame")({
						Name = "LevelCard",
						Size = UDim2.fromScale(1, 0.15),
						BackgroundTransparency = 1,
						LayoutOrder = 2,

						[Children] = {
							-- Shadow
							scope:New("Frame")({
								Name = "Shadow",
								Size = UDim2.fromScale(1, 0.95),
								Position = UDim2.fromScale(0.5, 0.05),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Action.Shadow,
								ZIndex = 1,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Layout.CornerRadius,
									}),
								},
							}),

							-- Main
							scope:New("Frame")({
								Name = "Main",
								Size = UDim2.fromScale(1, 0.95),
								Position = UDim2.fromScale(0.5, 0),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Action.Main,
								ZIndex = 2,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Layout.CornerRadius,
									}),

									scope:New("UIStroke")({
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									}),

									-- Large level badge container (square)
									scope:New("Frame")({
										Name = "LevelBadgeContainer",
										Size = UDim2.fromScale(0.18, 0.7),
										Position = UDim2.fromScale(0.05, 0.15),
										BackgroundTransparency = 1,

										[Children] = {
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 1,
												DominantAxis = Enum.DominantAxis.Height,
											}),
											LevelBadge({
												Scope = scope,
												Level = props.Level,
												Size = 60,
												Position = UDim2.fromScale(0.5, 0.5),
												AnchorPoint = Vector2.new(0.5, 0.5),
											}),
										},
									}),

									-- LEVEL label
									scope:New("TextLabel")({
										Name = "LevelLabel",
										Size = UDim2.fromScale(0.3, 0.2),
										Position = UDim2.fromScale(0.25, 0.15),
										BackgroundTransparency = 1,
										Text = "LEVEL",
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										Font = Theme.Typography.Fonts.Body,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextTransparency = 0.3,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MaxTextSize = 14,
												MinTextSize = 8,
											}),
										},
									}),

									-- XP Bar container
									scope:New("Frame")({
										Name = "XPBarContainer",
										Size = UDim2.fromScale(0.7, 0.4),
										Position = UDim2.fromScale(0.25, 0.4),
										BackgroundTransparency = 1,

										[Children] = {
											XPBar({
												Scope = scope,
												XP = props.XP,
												XPRequired = props.XPRequired,
												Size = UDim2.fromScale(1, 1),
											}),
										},
									}),
								},
							}),
						},
					}),

					-- Stats Grid 2x2 (30% of panel)
					scope:New("Frame")({
						Name = "StatsGrid",
						Size = UDim2.fromScale(1, 0.32),
						BackgroundTransparency = 1,
						LayoutOrder = 3,

						[Children] = {
							scope:New("UIGridLayout")({
								CellSize = UDim2.fromScale(0.48, 0.48),
								CellPadding = UDim2.fromScale(0.04, 0.04),
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							StatCard({
								Scope = scope,
								IconName = "Play",
								Label = "Games",
								Value = props.GamesPlayed,
								Color = "Info",
								LayoutOrder = 1,
							}),

							StatCard({
								Scope = scope,
								IconName = "Trophy",
								Label = "Wins",
								Value = props.GamesWon,
								Color = "Gold",
								LayoutOrder = 2,
							}),

							StatCard({
								Scope = scope,
								IconName = "Skull",
								Label = "Kills",
								Value = props.ZombiesKilled,
								Color = "Danger",
								LayoutOrder = 3,
							}),

							StatCard({
								Scope = scope,
								IconName = "Plant",
								Label = "Plants",
								Value = props.PlantsPlaced,
								Color = "Action",
								LayoutOrder = 4,
							}),
						},
					}),

					-- Win Rate Banner (12% of panel)
					scope:New("Frame")({
						Name = "WinRateContainer",
						Size = UDim2.fromScale(1, 0.12),
						BackgroundTransparency = 1,
						LayoutOrder = 4,

						[Children] = {
							WinRateBanner({
								Scope = scope,
								GamesWon = props.GamesWon,
								GamesPlayed = props.GamesPlayed,
								Size = UDim2.fromScale(1, 1),
							}),
						},
					}),
				},
			}),
		},
	})
end

return ProfileScreen
