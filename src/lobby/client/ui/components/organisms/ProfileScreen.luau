--!strict
--[[
	ProfileScreen.luau - Player profile overlay screen
	
	Organism displaying player stats, level progress, and win rate.
	Uses "Toon Pop" design system with atomic components.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local Atoms = script.Parent.Parent.atoms
local AvatarFrame = require(Atoms.AvatarFrame)
local LevelBadge = require(Atoms.LevelBadge)
local ResourcePill = require(Atoms.ResourcePill)
local StatCard = require(Atoms.StatCard)
local XPBar = require(Atoms.XPBar)
local WinRateBanner = require(Atoms.WinRateBanner)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent

-- Constants
local SHADOW_OFFSET = 4
local PANEL_WIDTH = 400
local HEADER_HEIGHT = 120

-- Get dynamic title based on level
local function getTitleForLevel(level: number): string
	if level >= 50 then return "🌟 Legendary Guardian"
	elseif level >= 40 then return "👑 Master Gardener"
	elseif level >= 30 then return "⚔️ Zombie Slayer"
	elseif level >= 20 then return "🛡️ Plant Defender"
	elseif level >= 10 then return "🌿 Garden Keeper"
	elseif level >= 5 then return "🌱 Sprout Tender"
	else return "🌰 Novice Gardener"
	end
end

export type ProfileScreenProps = {
	Scope: Fusion.Scope<any>,
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

local function ProfileScreen(props: ProfileScreenProps): Frame
	local scope = props.Scope
	local player = Players.LocalPlayer
	
	-- Animation states
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	
	-- Press animation for close button
	local targetOffset = Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	local pressOffset = Spring(scope, targetOffset, 40, 0.7)
	
	-- Dynamic title
	local title = Computed(scope, function(use)
		return getTitleForLevel(use(props.Level))
	end)
	
	return New(scope, "Frame") {
		Name = "ProfileScreen",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		ZIndex = 100,
		
		[Children] = {
			-- Center panel
			New(scope, "Frame") {
				Name = "Panel",
				Size = UDim2.fromOffset(PANEL_WIDTH, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				
				[Children] = {
					New(scope, "UIListLayout") {
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 0),
					},
					
					-- Header Card
					New(scope, "Frame") {
						Name = "Header",
						Size = UDim2.new(1, 0, 0, HEADER_HEIGHT + SHADOW_OFFSET),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						
						[Children] = {
							-- Shadow
							New(scope, "Frame") {
								Name = "Shadow",
								Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
								Position = UDim2.fromOffset(0, SHADOW_OFFSET),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
							
							-- Main header
							New(scope, "Frame") {
								Name = "Main",
								Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ZIndex = 2,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									
									New(scope, "UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									-- Avatar
									AvatarFrame({
										Scope = scope,
										Size = 80,
										Position = UDim2.fromOffset(20, 20),
										BorderColor = Theme.Colors.Info.Main,
									}),
									
									-- Level badge (overlapping avatar)
									LevelBadge({
										Scope = scope,
										Level = props.Level,
										Size = 36,
										Position = UDim2.fromOffset(70, 60),
									}),
									
									-- Player name
									New(scope, "TextLabel") {
										Name = "Name",
										Size = UDim2.fromOffset(180, 28),
										Position = UDim2.fromOffset(115, 18),
										BackgroundTransparency = 1,
										Text = player.DisplayName,
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextSize = 22,
										Font = Theme.Typography.Fonts.Title,
										TextXAlignment = Enum.TextXAlignment.Left,
									},
									
									-- Title
									New(scope, "TextLabel") {
										Name = "Title",
										Size = UDim2.fromOffset(180, 20),
										Position = UDim2.fromOffset(115, 46),
										BackgroundTransparency = 1,
										Text = title,
										TextColor3 = Theme.Colors.Action.Main,
										TextSize = 14,
										Font = Theme.Typography.Fonts.Body,
										TextXAlignment = Enum.TextXAlignment.Left,
									},
									
									-- Resources row
									New(scope, "Frame") {
										Name = "Resources",
										Size = UDim2.fromOffset(200, 40),
										Position = UDim2.fromOffset(115, 72),
										BackgroundTransparency = 1,
										
										[Children] = {
											New(scope, "UIListLayout") {
												FillDirection = Enum.FillDirection.Horizontal,
												Padding = UDim.new(0, 8),
											},
											
											ResourcePill({
												Scope = scope,
												Icon = Theme.Icons.Coin,
												Value = props.Coins,
												Color = "Gold",
												Width = 90,
												LayoutOrder = 1,
											}),
											
											ResourcePill({
												Scope = scope,
												Icon = Theme.Icons.Gem,
												Value = props.Gems,
												Color = "Purple",
												Width = 90,
												LayoutOrder = 2,
											}),
										},
									},
									
									-- Close button
									New(scope, "Frame") {
										Name = "CloseButtonContainer",
										Size = UDim2.fromOffset(44, 44 + SHADOW_OFFSET),
										Position = UDim2.new(1, -12, 0, 12),
										AnchorPoint = Vector2.new(1, 0),
										BackgroundTransparency = 1,
										
										[Children] = {
											-- Shadow
											New(scope, "Frame") {
												Name = "Shadow",
												Size = UDim2.fromOffset(44, 44),
												Position = UDim2.fromOffset(0, SHADOW_OFFSET),
												BackgroundColor3 = Theme.Colors.Danger.Shadow,
												ZIndex = 1,
												
												[Children] = {
													New(scope, "UICorner") {
														CornerRadius = Theme.Layout.CornerRadius,
													},
												},
											},
											
											-- Button
											New(scope, "TextButton") {
												Name = "CloseButton",
												Size = Computed(scope, function(use)
													local offset = use(pressOffset)
													return UDim2.fromOffset(44, 44 - offset)
												end),
												Position = Computed(scope, function(use)
													return UDim2.fromOffset(0, use(pressOffset))
												end),
												BackgroundColor3 = Theme.Colors.Danger.Main,
												Text = Theme.Icons.Close,
												TextColor3 = Color3.new(1, 1, 1),
												TextSize = 20,
												Font = Theme.Typography.Fonts.Title,
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
													New(scope, "UICorner") {
														CornerRadius = Theme.Layout.CornerRadius,
													},
													
													New(scope, "UIStroke") {
														Color = Theme.Colors.Surface.Stroke :: Color3,
														Thickness = 2,
													},
												},
											},
										},
									},
								},
							},
						},
					},
					
					-- Spacer
					New(scope, "Frame") {
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						LayoutOrder = 2,
					},
					
					-- Level & XP Card
					New(scope, "Frame") {
						Name = "LevelCard",
						Size = UDim2.new(1, 0, 0, 100 + SHADOW_OFFSET),
						BackgroundTransparency = 1,
						LayoutOrder = 3,
						
						[Children] = {
							-- Shadow
							New(scope, "Frame") {
								Name = "Shadow",
								Size = UDim2.new(1, 0, 0, 100),
								Position = UDim2.fromOffset(0, SHADOW_OFFSET),
								BackgroundColor3 = Theme.Colors.Action.Shadow,
								ZIndex = 1,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
							
							-- Main
							New(scope, "Frame") {
								Name = "Main",
								Size = UDim2.new(1, 0, 0, 100),
								BackgroundColor3 = Theme.Colors.Action.Main,
								ZIndex = 2,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									
									New(scope, "UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									-- Large level badge
									LevelBadge({
										Scope = scope,
										Level = props.Level,
										Size = 60,
										Position = UDim2.fromOffset(20, 20),
									}),
									
									-- LEVEL label
									New(scope, "TextLabel") {
										Name = "LevelLabel",
										Size = UDim2.fromOffset(100, 20),
										Position = UDim2.fromOffset(95, 18),
										BackgroundTransparency = 1,
										Text = "LEVEL",
										TextColor3 = Color3.new(1, 1, 1),
										TextSize = 12,
										Font = Theme.Typography.Fonts.Body,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextTransparency = 0.3,
									},
									
									-- XP Bar
									New(scope, "Frame") {
										Name = "XPBarContainer",
										Size = UDim2.new(1, -110, 0, 32),
										Position = UDim2.fromOffset(95, 40),
										BackgroundTransparency = 1,
										
										[Children] = {
											XPBar({
												Scope = scope,
												XP = props.XP,
												XPRequired = props.XPRequired,
												Size = UDim2.new(1, 0, 1, 0),
											}),
										},
									},
								},
							},
						},
					},
					
					-- Spacer
					New(scope, "Frame") {
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						LayoutOrder = 4,
					},
					
					-- Stats Grid (2x2)
					New(scope, "Frame") {
						Name = "StatsGrid",
						Size = UDim2.new(1, 0, 0, 200),
						BackgroundTransparency = 1,
						LayoutOrder = 5,
						
						[Children] = {
							-- Row 1
							New(scope, "Frame") {
								Name = "Row1",
								Size = UDim2.new(1, 0, 0, 94),
								BackgroundTransparency = 1,
								
								[Children] = {
									New(scope, "UIListLayout") {
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 16),
									},
									
									StatCard({
										Scope = scope,
										Icon = "🎮",
										Label = "Games",
										Value = props.GamesPlayed,
										Color = "Info",
										LayoutOrder = 1,
									}),
									
									StatCard({
										Scope = scope,
										Icon = "🏆",
										Label = "Wins",
										Value = props.GamesWon,
										Color = "Gold",
										LayoutOrder = 2,
									}),
								},
							},
							
							-- Row 2
							New(scope, "Frame") {
								Name = "Row2",
								Size = UDim2.new(1, 0, 0, 94),
								Position = UDim2.fromOffset(0, 106),
								BackgroundTransparency = 1,
								
								[Children] = {
									New(scope, "UIListLayout") {
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 16),
									},
									
									StatCard({
										Scope = scope,
										Icon = "💀",
										Label = "Kills",
										Value = props.ZombiesKilled,
										Color = "Danger",
										LayoutOrder = 1,
									}),
									
									StatCard({
										Scope = scope,
										Icon = "🌱",
										Label = "Plants",
										Value = props.PlantsPlaced,
										Color = "Action",
										LayoutOrder = 2,
									}),
								},
							},
						},
					},
					
					-- Spacer
					New(scope, "Frame") {
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						LayoutOrder = 6,
					},
					
					-- Win Rate Banner
					WinRateBanner({
						Scope = scope,
						GamesWon = props.GamesWon,
						GamesPlayed = props.GamesPlayed,
						LayoutOrder = 7,
					}),
				},
			},
		},
	}
end

return ProfileScreen
