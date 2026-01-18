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
local IconAssets = require(Shared.ui.design.IconAssets)
local PlantData = require(Shared.data.PlantData)
local PlantViewport = require(Shared.ui.components.cards.PlantViewport)
local Icon = require(Shared.ui.components.base.Icon)

-- Fusion primitives
local Children = Fusion.Children
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

	-- State
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	-- Animations
	local targetScale = scope:Computed(function(use)
		if use(isPressed) then
			return 0.95
		end
		if use(isHovered) then
			return 1.03
		end
		return 1
	end)
	local hoverScale = scope:Spring(targetScale, 35, 0.7)

	local targetOffset = scope:Computed(function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	local pressOffset = scope:Spring(targetOffset, 40, 0.7)

	-- Border color based on state
	local borderColor = scope:Computed(function(use)
		if use(props.IsUnlocked) then
			return Theme.Colors.Action.Main
		end
		if use(isHovered) then
			return Theme.Colors.Gold.Main
		end
		return Theme.Colors.Surface.Stroke :: Color3
	end)

	return scope:New("Frame")({
		Name = props.PlantType,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Children] = {
			-- Scale container
			scope:New("Frame")({
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					scope:New("UIScale")({ Scale = hoverScale }),

					-- Shadow
					scope:New("Frame")({
						Name = "Shadow",
						Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
						Position = UDim2.fromOffset(0, SHADOW_OFFSET),
						BackgroundColor3 = Theme.Colors.Surface.Shadow,
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Layout.CornerRadius,
							}),
						},
					}),

					-- Main card
					scope:New("Frame")({
						Name = "Main",
						Size = scope:Computed(function(use)
							local offset = use(pressOffset)
							return UDim2.new(1, 0, 1, -SHADOW_OFFSET - offset)
						end),
						Position = scope:Computed(function(use)
							return UDim2.fromOffset(0, use(pressOffset))
						end),
						BackgroundColor3 = Theme.Colors.Surface.Main,
						ZIndex = 2,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Layout.CornerRadius,
							}),

							scope:New("UIStroke")({
								Color = borderColor,
								Thickness = Theme.Layout.StrokeThickness,
							}),

							-- Background effect behind plant
							scope:New("ImageLabel")({
								Name = "PlantBg",
								Size = UDim2.new(1, 20, 0, VIEWPORT_HEIGHT + 30),
								Position = UDim2.new(0.5, 0, 0, 10),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundTransparency = 1,
								Image = "rbxassetid://137482510225499",
								ImageTransparency = 0,
								ScaleType = Enum.ScaleType.Fit,
								ZIndex = 3,
							}),

							-- 3D Plant viewport (ZIndex = 4 to be on top of bg)
							PlantViewport.CreateWithScope(scope, {
								PlantType = props.PlantType,
								Size = UDim2.new(1, -10, 0, VIEWPORT_HEIGHT),
								Position = UDim2.new(0.5, 0, 0, 25),
								AnchorPoint = Vector2.new(0.5, 0),
								ZIndex = 4,
								CameraFOV = 30,
								CameraDistance = 1.8,
								CameraHeight = 0.15,
							}),

							-- Plant name
							scope:New("TextLabel")({
								Name = "PlantName",
								Size = UDim2.new(1, -12, 0, 22),
								Position = UDim2.fromOffset(6, 105), -- Below viewport
								BackgroundTransparency = 1,
								Text = props.PlantType,
								TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
								TextSize = 14,
								Font = Theme.Typography.Fonts.Title,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 2,
							}),

							-- Category
							plantStats
									and scope:New("TextLabel")({
										Name = "Category",
										Size = UDim2.new(1, 0, 0, 14),
										Position = UDim2.fromOffset(0, 126), -- Below name
										BackgroundTransparency = 1,
										Text = plantStats.Category or "",
										TextColor3 = Theme.Colors.Surface.Shadow,
										TextSize = 10,
										Font = Theme.Typography.Fonts.Body,
										ZIndex = 2,
									})
								or nil,

							-- Buy button / Owned indicator
							scope:Computed(function(use)
								if use(props.IsUnlocked) then
									-- Show "In Collection" for owned
									return scope:New("Frame")({
										Name = "OwnedInfo",
										Size = UDim2.new(1, -16, 0, 36),
										Position = UDim2.new(0, 8, 1, -44),
										BackgroundColor3 = Theme.Colors.Action.Shadow,
										ZIndex = 3,

										[Children] = {
											scope:New("UICorner")({
												CornerRadius = UDim.new(0, 8),
											}),
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												VerticalAlignment = Enum.VerticalAlignment.Center,
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												Padding = UDim.new(0, 4),
											}),
										Icon(scope, {
											Name = "Check",
											Size = UDim2.fromOffset(16, 16),
											Color = Theme.Colors.Action.Main,
											}),
											scope:New("TextLabel")({
												Size = UDim2.fromOffset(60, 20),
												BackgroundTransparency = 1,
												Text = "OWNED",
												TextColor3 = Theme.Colors.Action.Main,
												TextSize = 12,
												Font = Theme.Typography.Fonts.Body,
												TextXAlignment = Enum.TextXAlignment.Left,
											}),
										},
									})
								end

								local canAfford = use(props.CanAfford)
								local bgColor = if canAfford
									then Theme.Colors.Gold.Main
									else Theme.Colors.Surface.Shadow
								local textCol = if canAfford
									then Color3.fromRGB(80, 50, 20)
									else Theme.Colors.Surface.Main

								return scope:New("TextButton")({
									Name = "BuyButton",
									Size = UDim2.new(1, -16, 0, 36),
									Position = UDim2.new(0, 8, 1, -44),
									BackgroundColor3 = bgColor,
									Text = "",
									AutoButtonColor = false,
									ZIndex = 10,

									[OnEvent("Activated")] = function()
										if peek(props.CanAfford) then
											props.OnPurchase()
										end
									end,

									[Children] = {
										scope:New("UICorner")({
											CornerRadius = UDim.new(0, 8),
										}),
										scope:New("UIStroke")({
											Color = Theme.Colors.Surface.Stroke :: Color3,
											Thickness = 2,
										}),
										scope:New("UIListLayout")({
											FillDirection = Enum.FillDirection.Horizontal,
											VerticalAlignment = Enum.VerticalAlignment.Center,
											HorizontalAlignment = Enum.HorizontalAlignment.Center,
											Padding = UDim.new(0, 4),
										}),
									Icon(scope, {
										Name = "Coin",
										Size = UDim2.fromOffset(18, 18),
										}),
										scope:New("TextLabel")({
											Name = "PriceText",
											Size = UDim2.fromOffset(50, 20),
											BackgroundTransparency = 1,
											Text = tostring(props.Cost),
											TextColor3 = textCol,
											TextSize = 14,
											Font = Enum.Font.GothamBold,
											TextXAlignment = Enum.TextXAlignment.Left,
										}),
									},
								})
							end),

							-- Hover detector
							scope:New("TextButton")({
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
							}),
						},
					}),
				},
			}),
		},
	})
end

return ShopCard
