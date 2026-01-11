--!strict
--[[
	ShopCard.luau - Plant card for shop display
	
	Atomic component showing plant info with buy button.
	"Toon Pop" style with shadow, hover effects, and owned/locked states.
	Uses PlantViewport for 3D plant model display.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local PlantData = require(Shared.data.PlantData)
local PlantViewport = require(Shared.ui.components.atoms.PlantViewport)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Constants
local CARD_WIDTH = 160
local CARD_HEIGHT = 220
local SHADOW_OFFSET = 4
local VIEWPORT_HEIGHT = 80 -- Height for 3D plant viewport

export type ShopCardProps = {
	Scope: Fusion.Scope<any>,
	PlantType: string,
	Cost: number, -- Coin cost to buy
	SunCost: number?, -- Sun cost in-game
	IsUnlocked: any, -- Fusion.Value<boolean>
	CanAfford: any, -- Fusion.Value<boolean>
	OnPurchase: () -> (),
	LayoutOrder: number?,
}

local function ShopCard(props: ShopCardProps): Frame
	local scope = props.Scope
	local plantStats = PlantData[props.PlantType]
	local sunCost = props.SunCost or (plantStats and plantStats.Cost) or 100
	
	-- Create 3D plant viewport
	local plantViewport = PlantViewport.CreateWithScope(scope, {
		PlantType = props.PlantType,
		Size = UDim2.new(1, -10, 0, VIEWPORT_HEIGHT),
		Position = UDim2.new(0.5, 0, 0, 25),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 3,
		CameraFOV = 30, -- Slightly narrower for larger plant
		CameraDistance = 1.8,
		CameraHeight = 0.15,
	})
	
	-- State
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	
	-- Animations
	local targetScale = Computed(scope, function(use)
		if use(isPressed) then return 0.95 end
		if use(isHovered) then return 1.03 end
		return 1
	end)
	local hoverScale = Spring(scope, targetScale, 35, 0.7)
	
	local targetOffset = Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	local pressOffset = Spring(scope, targetOffset, 40, 0.7)
	
	-- Border color based on state
	local borderColor = Computed(scope, function(use)
		if use(props.IsUnlocked) then
			return Theme.Colors.Action.Main
		end
		if use(isHovered) then
			return Theme.Colors.Gold.Main
		end
		return Theme.Colors.Surface.Stroke :: Color3
	end)
	
	return New(scope, "Frame") {
		Name = props.PlantType,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Scale container
			New(scope, "Frame") {
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				
				[Children] = {
					New(scope, "UIScale") { Scale = hoverScale },
					
					-- Shadow
					New(scope, "Frame") {
						Name = "Shadow",
						Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
						Position = UDim2.fromOffset(0, SHADOW_OFFSET),
						BackgroundColor3 = Theme.Colors.Surface.Shadow,
						ZIndex = 1,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
						},
					},
					
					-- Main card
					New(scope, "Frame") {
						Name = "Main",
						Size = Computed(scope, function(use)
							local offset = use(pressOffset)
							return UDim2.new(1, 0, 1, -SHADOW_OFFSET - offset)
						end),
						Position = Computed(scope, function(use)
							return UDim2.fromOffset(0, use(pressOffset))
						end),
						BackgroundColor3 = Theme.Colors.Surface.Main,
						ZIndex = 2,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
							
							New(scope, "UIStroke") {
								Color = borderColor,
								Thickness = Theme.Layout.StrokeThickness,
							},
							
							-- Owned badge (top)
							Computed(scope, function(use)
								if not use(props.IsUnlocked) then return nil end
								return New(scope, "Frame") {
									Name = "OwnedBadge",
									Size = UDim2.new(1, 0, 0, 26),
									BackgroundColor3 = Theme.Colors.Action.Main,
									ZIndex = 3,
									
									[Children] = {
										New(scope, "UICorner") {
											CornerRadius = Theme.Layout.CornerRadius,
										},
										-- Bottom cover
										New(scope, "Frame") {
											Size = UDim2.new(1, 0, 0, 12),
											Position = UDim2.new(0, 0, 1, -12),
											BackgroundColor3 = Theme.Colors.Action.Main,
										},
										New(scope, "TextLabel") {
											Size = UDim2.new(1, 0, 1, 0),
											BackgroundTransparency = 1,
											Text = "✓ OWNED",
											TextColor3 = Color3.new(1, 1, 1),
											TextSize = 12,
											Font = Theme.Typography.Fonts.Body,
										},
									},
								}
							end),
							
							-- 3D Plant viewport
							plantViewport,
							
							-- Plant name
							New(scope, "TextLabel") {
								Name = "PlantName",
								Size = UDim2.new(1, -12, 0, 22),
								Position = UDim2.new(0, 6, 0, 105), -- Below viewport
								BackgroundTransparency = 1,
								Text = props.PlantType,
								TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
								TextSize = 14,
								Font = Theme.Typography.Fonts.Title,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 2,
							},
							
							-- Category
							plantStats and New(scope, "TextLabel") {
								Name = "Category",
								Size = UDim2.new(1, 0, 0, 14),
								Position = UDim2.fromOffset(0, 126), -- Below name
								BackgroundTransparency = 1,
								Text = plantStats.Category or "",
								TextColor3 = Theme.Colors.Surface.Shadow,
								TextSize = 10,
								Font = Theme.Typography.Fonts.Body,
								ZIndex = 2,
							} or nil,
							
							-- Sun cost pill
							New(scope, "Frame") {
								Name = "SunCost",
								Size = UDim2.fromOffset(60, 22),
								Position = UDim2.new(0.5, 0, 0, 142), -- Below category
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Warning.Main,
								ZIndex = 3,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = UDim.new(0.5, 0),
									},
									New(scope, "TextLabel") {
										Size = UDim2.new(1, 0, 1, 0),
										BackgroundTransparency = 1,
										Text = `☀️ {sunCost}`,
										TextColor3 = Color3.fromRGB(80, 50, 20), -- Dark brown for better contrast
										TextSize = 11,
										Font = Enum.Font.GothamBold, -- More readable
									},
								},
							},
							
							-- Buy button / Owned indicator
							Computed(scope, function(use)
								if use(props.IsUnlocked) then
									-- Show "In Collection" for owned
									return New(scope, "Frame") {
										Name = "OwnedInfo",
										Size = UDim2.new(1, -16, 0, 36),
										Position = UDim2.new(0, 8, 1, -44),
										BackgroundColor3 = Theme.Colors.Action.Shadow,
										ZIndex = 3,
										
										[Children] = {
											New(scope, "UICorner") {
												CornerRadius = UDim.new(0, 8),
											},
											New(scope, "TextLabel") {
												Size = UDim2.new(1, 0, 1, 0),
												BackgroundTransparency = 1,
												Text = "✓ Collection",
												TextColor3 = Theme.Colors.Action.Main,
												TextSize = 12,
												Font = Theme.Typography.Fonts.Body,
											},
										},
									}
								end
								
								local canAfford = use(props.CanAfford)
								local bgColor = if canAfford then Theme.Colors.Gold.Main else Theme.Colors.Surface.Shadow
								-- Use dark brown text on gold for better contrast
								local textCol = if canAfford then Color3.fromRGB(80, 50, 20) else Theme.Colors.Surface.Main
								
								return New(scope, "TextButton") {
									Name = "BuyButton",
									Size = UDim2.new(1, -16, 0, 36),
									Position = UDim2.new(0, 8, 1, -44),
									BackgroundColor3 = bgColor,
									Text = `🪙 {props.Cost}`,
									TextColor3 = textCol,
									TextSize = 14,
									Font = Enum.Font.GothamBold, -- More readable than LuckiestGuy on colored bg
									AutoButtonColor = false,
									ZIndex = 10,
									
									[OnEvent("Activated")] = function()
										if peek(props.CanAfford) then
											props.OnPurchase()
										end
									end,
									
									[Children] = {
										New(scope, "UICorner") {
											CornerRadius = UDim.new(0, 8),
										},
										New(scope, "UIStroke") {
											Color = Theme.Colors.Surface.Stroke :: Color3,
											Thickness = 2,
										},
									},
								}
							end),
							
							-- Hover detector
							New(scope, "TextButton") {
								Name = "HoverDetector",
								Size = UDim2.new(1, 0, 1, -50),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 5,
								
								[OnEvent("MouseEnter")] = function()
									isHovered:set(true)
								end,
								
								[OnEvent("MouseLeave")] = function()
									isHovered:set(false)
									isPressed:set(false)
								end,
								
								[OnEvent("MouseButton1Down")] = function()
									isPressed:set(true)
								end,
								
								[OnEvent("MouseButton1Up")] = function()
									isPressed:set(false)
								end,
							},
						},
					},
				},
			},
		},
	}
end

return ShopCard
