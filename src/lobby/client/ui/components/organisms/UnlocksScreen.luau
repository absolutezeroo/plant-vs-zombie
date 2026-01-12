--!nonstrict
--[[
	UnlocksScreen.luau - Level Unlocks progression screen (Fusion 0.3 Responsive)
	
	Shows what rewards players get at each level:
	- Coins/Gems rewards
	- Plant unlocks
	- Current progress indicator
	
	Fully responsive using Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local ProgressionData = require(Shared.data.ProgressionData)
local PlantViewport = require(Shared.ui.components.atoms.PlantViewport)

-- Fusion 0.3 scope-based primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

export type UnlocksScreenProps = {
	Scope: any, -- Fusion scope
	PlayerLevel: any, -- Fusion.Value<number>
	OnClose: () -> (),
}

--------------------------------------------------------------------------------
-- LevelRow Component - A single level reward row (Responsive)
--------------------------------------------------------------------------------
local function LevelRow(scope: any, props: {
	Level: number,
	Coins: number?,
	Gems: number?,
	PlantType: string?,
	IsUnlocked: boolean,
	IsCurrent: boolean,
	LayoutOrder: number,
})
	local hasPlant = props.PlantType ~= nil
	local hasGems = props.Gems and props.Gems > 0
	
	-- Row background color based on state
	local bgColor = if props.IsCurrent then Theme.Colors.Action.Main
		elseif props.IsUnlocked then Theme.Colors.Surface.Main
		else Color3.fromHex("#E0D5C0")
	
	local shadowColor = if props.IsCurrent then Theme.Colors.Action.Shadow
		elseif props.IsUnlocked then Theme.Colors.Surface.Shadow
		else Color3.fromHex("#B8A88A")
	
	-- Create plant viewport if there's a plant
	local plantViewport: ViewportFrame? = nil
	if hasPlant then
		plantViewport = PlantViewport.CreateWithScope(scope, {
			PlantType = props.PlantType :: string,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
			CameraFOV = 40,
			CameraDistance = 1.3,
			CameraHeight = 0.1,
		})
	end
	
	return scope:New("Frame") {
		Name = "Level" .. props.Level,
		Size = UDim2.new(1, 0, 0, 84), -- Fixed height for rows in scrolling list
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		
		[Children] = {
			-- Shadow
			scope:New("Frame") {
				Name = "Shadow",
				Size = UDim2.new(1, 0, 0, 80),
				Position = UDim2.fromOffset(0, 4),
				BackgroundColor3 = shadowColor,
				ZIndex = 1,
				
				[Children] = {
					scope:New("UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
				},
			},
			
			-- Main row
			scope:New("Frame") {
				Name = "Main",
				Size = UDim2.new(1, 0, 0, 80),
				BackgroundColor3 = bgColor,
				ZIndex = 2,
				
				[Children] = {
					scope:New("UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
					
					scope:New("UIStroke") {
						Color = if props.IsCurrent 
							then Color3.fromHex("#FFD700")
							else Theme.Colors.Surface.Stroke :: Color3,
						Thickness = if props.IsCurrent then 4 else Theme.Layout.StrokeThickness,
					},
					
					scope:New("UIPadding") {
						PaddingLeft = UDim.new(0.02, 0),
						PaddingRight = UDim.new(0.02, 0),
					},
					
					-- Level badge (left) - Square with aspect ratio
					scope:New("Frame") {
						Name = "LevelBadge",
						Size = UDim2.fromScale(0.08, 0.7),
						Position = UDim2.fromScale(0, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = if props.IsCurrent then Color3.fromHex("#FFD700")
							elseif props.IsUnlocked then Theme.Colors.Action.Main
							else Theme.Colors.Surface.Shadow,
						
						[Children] = {
							scope:New("UIAspectRatioConstraint") {
								AspectRatio = 1,
								AspectType = Enum.AspectType.ScaleWithParentSize,
								DominantAxis = Enum.DominantAxis.Height,
							},
							scope:New("UICorner") {
								CornerRadius = UDim.new(0.5, 0),
							},
							scope:New("UIStroke") {
								Color = Theme.Colors.Surface.Stroke :: Color3,
								Thickness = 2,
							},
							scope:New("TextLabel") {
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = tostring(props.Level),
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								Font = Theme.Typography.Fonts.Title,
								
								[Children] = {
									scope:New("UITextSizeConstraint") {
										MaxTextSize = 24,
										MinTextSize = 12,
									},
								},
							},
						},
					},
					
					-- Rewards container (center)
					scope:New("Frame") {
						Name = "Rewards",
						Size = UDim2.fromScale(0.7, 0.8),
						Position = UDim2.fromScale(0.12, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						
						[Children] = {
							scope:New("UIListLayout") {
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								Padding = UDim.new(0.02, 0),
							},
							
							-- Coins reward
							props.Coins and scope:New("Frame") {
								Name = "Coins",
								Size = UDim2.fromScale(0.2, 0.7),
								BackgroundColor3 = Theme.Colors.Gold.Main,
								LayoutOrder = 1,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = UDim.new(0.5, 0),
									},
									scope:New("UIStroke") {
										Color = Theme.Colors.Gold.Shadow,
										Thickness = 2,
									},
									scope:New("TextLabel") {
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = `💰 +{props.Coins}`,
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Body,
										
										[Children] = {
											scope:New("UITextSizeConstraint") {
												MaxTextSize = 16,
												MinTextSize = 10,
											},
										},
									},
								},
							} or nil,
							
							-- Gems reward
							hasGems and scope:New("Frame") {
								Name = "Gems",
								Size = UDim2.fromScale(0.18, 0.7),
								BackgroundColor3 = Theme.Colors.Purple.Main,
								LayoutOrder = 2,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = UDim.new(0.5, 0),
									},
									scope:New("UIStroke") {
										Color = Theme.Colors.Purple.Shadow,
										Thickness = 2,
									},
									scope:New("TextLabel") {
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = `💎 +{props.Gems}`,
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										Font = Theme.Typography.Fonts.Body,
										
										[Children] = {
											scope:New("UITextSizeConstraint") {
												MaxTextSize = 16,
												MinTextSize = 10,
											},
										},
									},
								},
							} or nil,
							
							-- Plant unlock
							hasPlant and scope:New("Frame") {
								Name = "PlantReward",
								Size = UDim2.fromScale(0.35, 0.9),
								BackgroundColor3 = Theme.Colors.Action.Main,
								LayoutOrder = 3,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									scope:New("UIStroke") {
										Color = Theme.Colors.Action.Shadow,
										Thickness = 2,
									},
									
									-- Plant viewport container (square)
									scope:New("Frame") {
										Name = "ViewportContainer",
										Size = UDim2.fromScale(0.35, 0.9),
										Position = UDim2.fromScale(0.05, 0.5),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										
										[Children] = {
											scope:New("UIAspectRatioConstraint") {
												AspectRatio = 1,
												DominantAxis = Enum.DominantAxis.Height,
											},
											plantViewport,
										},
									},
									
									-- Plant name
									scope:New("TextLabel") {
										Size = UDim2.fromScale(0.55, 1),
										Position = UDim2.fromScale(0.42, 0.5),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										Text = `🌱 {props.PlantType}`,
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										Font = Theme.Typography.Fonts.Body,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextTruncate = Enum.TextTruncate.AtEnd,
										
										[Children] = {
											scope:New("UITextSizeConstraint") {
												MaxTextSize = 14,
												MinTextSize = 8,
											},
										},
									},
								},
							} or nil,
						},
					},
					
					-- Status icon (right) - Square
					scope:New("Frame") {
						Name = "StatusContainer",
						Size = UDim2.fromScale(0.08, 0.6),
						Position = UDim2.fromScale(0.98, 0.5),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						
						[Children] = {
							scope:New("UIAspectRatioConstraint") {
								AspectRatio = 1,
								DominantAxis = Enum.DominantAxis.Height,
							},
							scope:New("TextLabel") {
								Name = "Status",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = if props.IsCurrent then "👉"
									elseif props.IsUnlocked then "✅"
									else "🔒",
								TextScaled = true,
								
								[Children] = {
									scope:New("UITextSizeConstraint") {
										MaxTextSize = 28,
										MinTextSize = 16,
									},
								},
							},
						},
					},
				},
			},
		},
	}
end

--------------------------------------------------------------------------------
-- UnlocksScreen Component (Fully Responsive)
--------------------------------------------------------------------------------
local function UnlocksScreen(props: UnlocksScreenProps)
	local scope = props.Scope
	
	-- Close button animation
	local isClosePressed = scope:Value(false)
	local closeOffset = scope:Spring(scope:Computed(function(use)
		return if use(isClosePressed) then 4 else 0
	end), 40, 0.7)
	
	-- Get all levels with rewards (sorted)
	local levelRewardsData = {}
	for level, rewards in pairs(ProgressionData.LevelRewards) do
		table.insert(levelRewardsData, {
			Level = level,
			Coins = rewards.Coins,
			Gems = rewards.Gems,
			PlantType = rewards.UnlockPlant,
		})
	end
	table.sort(levelRewardsData, function(a, b) return a.Level < b.Level end)
	
	-- Create static level rows
	local function createLevelRows(): {any}
		local rows = {}
		for i, reward in ipairs(levelRewardsData) do
			table.insert(rows, LevelRow(scope, {
				Level = reward.Level,
				Coins = reward.Coins,
				Gems = reward.Gems,
				PlantType = reward.PlantType,
				IsUnlocked = peek(props.PlayerLevel) >= reward.Level,
				IsCurrent = peek(props.PlayerLevel) == reward.Level,
				LayoutOrder = i,
			}))
		end
		return rows
	end
	
	return scope:New("Frame") {
		Name = "UnlocksScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		ZIndex = 100,
		
		[Children] = {
			-- Main panel (centered)
			scope:New("Frame") {
				Name = "Panel",
				Size = UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				
				[Children] = {
					-- Header (top 10%)
					scope:New("Frame") {
						Name = "Header",
						Size = UDim2.fromScale(1, 0.1),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- Shadow
							scope:New("Frame") {
								Name = "Shadow",
								Size = UDim2.fromScale(1, 0.9),
								Position = UDim2.fromScale(0.5, 0.1),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
							
							-- Main header
							scope:New("Frame") {
								Name = "Main",
								Size = UDim2.fromScale(1, 0.9),
								Position = UDim2.fromScale(0.5, 0),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ZIndex = 2,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									
									scope:New("UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									-- Title (centered)
									scope:New("TextLabel") {
										Name = "Title",
										Size = UDim2.fromScale(0.5, 0.6),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = "🏆 LEVEL REWARDS",
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Title,
										
										[Children] = {
											scope:New("UITextSizeConstraint") {
												MaxTextSize = 32,
												MinTextSize = 16,
											},
										},
									},
									
									-- Current level indicator (left)
									scope:New("Frame") {
										Name = "LevelIndicator",
										Size = UDim2.fromScale(0.12, 0.6),
										Position = UDim2.fromScale(0.02, 0.5),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundColor3 = Theme.Colors.Action.Main,
										
										[Children] = {
											scope:New("UICorner") {
												CornerRadius = Theme.Layout.CornerRadius,
											},
											scope:New("UIStroke") {
												Color = Theme.Colors.Action.Shadow,
												Thickness = 2,
											},
											scope:New("TextLabel") {
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = scope:Computed(function(use)
													return `Lvl {use(props.PlayerLevel)}`
												end),
												TextColor3 = Color3.new(1, 1, 1),
												TextScaled = true,
												Font = Theme.Typography.Fonts.Title,
												
												[Children] = {
													scope:New("UITextSizeConstraint") {
														MaxTextSize = 20,
														MinTextSize = 12,
													},
												},
											},
										},
									},
									
									-- Close button (right) - Square
									scope:New("Frame") {
										Name = "CloseContainer",
										Size = UDim2.fromScale(0.08, 0.75),
										Position = UDim2.fromScale(0.98, 0.5),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										
										[Children] = {
											scope:New("UIAspectRatioConstraint") {
												AspectRatio = 1,
												DominantAxis = Enum.DominantAxis.Height,
											},
											
											-- Shadow
											scope:New("Frame") {
												Size = UDim2.fromScale(1, 0.9),
												Position = UDim2.fromScale(0.5, 0.1),
												AnchorPoint = Vector2.new(0.5, 0),
												BackgroundColor3 = Theme.Colors.Danger.Shadow,
												ZIndex = 1,
												
												[Children] = {
													scope:New("UICorner") {
														CornerRadius = Theme.Layout.CornerRadius,
													},
												},
											},
											
											-- Button
											scope:New("TextButton") {
												Size = scope:Computed(function(use)
													local offset = use(closeOffset)
													return UDim2.fromScale(1, 0.9 - offset * 0.01)
												end),
												Position = scope:Computed(function(use)
													return UDim2.fromScale(0.5, use(closeOffset) * 0.01)
												end),
												AnchorPoint = Vector2.new(0.5, 0),
												BackgroundColor3 = Theme.Colors.Danger.Main,
												Text = Theme.Icons.Close,
												TextColor3 = Color3.new(1, 1, 1),
												TextScaled = true,
												Font = Theme.Typography.Fonts.Title,
												AutoButtonColor = false,
												ZIndex = 2,
												
												[OnEvent("MouseButton1Down")] = function()
													isClosePressed:set(true)
												end,
												
												[OnEvent("MouseButton1Up")] = function()
													isClosePressed:set(false)
													props.OnClose()
												end,
												
												[OnEvent("MouseLeave")] = function()
													isClosePressed:set(false)
												end,
												
												[Children] = {
													scope:New("UICorner") {
														CornerRadius = Theme.Layout.CornerRadius,
													},
													scope:New("UIStroke") {
														Color = Theme.Colors.Surface.Stroke :: Color3,
														Thickness = 2,
													},
													scope:New("UITextSizeConstraint") {
														MaxTextSize = 24,
														MinTextSize = 14,
													},
												},
											},
										},
									},
								},
							},
						},
					},
					
					-- Scrollable list (bottom 88%)
					scope:New("Frame") {
						Name = "ListContainer",
						Size = UDim2.fromScale(1, 0.88),
						Position = UDim2.fromScale(0.5, 1),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- Shadow
							scope:New("Frame") {
								Name = "Shadow",
								Size = UDim2.fromScale(1, 0.99),
								Position = UDim2.fromScale(0.5, 0.01),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
							
							-- Scrolling frame
							scope:New("ScrollingFrame") {
								Name = "List",
								Size = UDim2.fromScale(1, 0.99),
								Position = UDim2.fromScale(0.5, 0),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ScrollBarThickness = 8,
								ScrollBarImageColor3 = Theme.Colors.Surface.Shadow,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								CanvasSize = UDim2.new(0, 0, 0, 0),
								ZIndex = 2,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									
									scope:New("UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									scope:New("UIPadding") {
										PaddingTop = UDim.new(0.02, 0),
										PaddingBottom = UDim.new(0.03, 0),
										PaddingLeft = UDim.new(0.02, 0),
										PaddingRight = UDim.new(0.02, 0),
									},
									
									scope:New("UIListLayout") {
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 8),
									},
									
									-- Level rows
									createLevelRows(),
								},
							},
						},
					},
				},
			},
		},
	}
end

return UnlocksScreen
