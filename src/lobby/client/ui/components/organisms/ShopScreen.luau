--!strict
--[[
	ShopScreen.luau - Plant shop overlay screen
	
	Organism displaying available plants for purchase.
	Uses "Toon Pop" design system with atomic components.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local ProgressionData = require(Shared.data.ProgressionData)
local ResponsiveUtils = require(Shared.ui.utils.ResponsiveUtils)

local Atoms = script.Parent.Parent.atoms
local FilterPill = require(Atoms.FilterPill)
local ShopCard = require(Atoms.ShopCard)
local ResourcePill = require(Atoms.ResourcePill)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent

-- Constants
local SHADOW_OFFSET = 4
local HEADER_HEIGHT = 70

-- Get sorted plants list
local function getSortedPlants(): {{PlantType: string, Info: ProgressionData.PlantUnlockInfo}}
	local plants = {}
	for plantType, info in pairs(ProgressionData.PlantUnlocks) do
		table.insert(plants, {PlantType = plantType, Info = info})
	end
	table.sort(plants, function(a, b) return a.Info.Order < b.Info.Order end)
	return plants
end

export type ShopScreenProps = {
	Scope: Fusion.Scope<any>,
	Coins: any, -- Fusion.Value<number>
	UnlockedPlants: any, -- Fusion.Value<{string}>
	OnClose: () -> (),
	OnPurchase: (plantType: string) -> (),
}

local function ShopScreen(props: ShopScreenProps): Frame
	local scope = props.Scope
	local sortedPlants = getSortedPlants()
	
	-- Filter state
	local selectedFilter = Value(scope, "All")
	
	-- Close button state
	local isClosePressed = Value(scope, false)
	local closeOffset = Spring(scope, Computed(scope, function(use)
		return if use(isClosePressed) then SHADOW_OFFSET else 0
	end), 40, 0.7)
	
	-- Filtered plants
	local filteredPlants = Computed(scope, function(use)
		local filter = use(selectedFilter)
		local unlocked = use(props.UnlockedPlants) or {}
		
		-- Build unlocked set
		local unlockedSet: {[string]: boolean} = {}
		for _, pt in ipairs(unlocked) do
			unlockedSet[pt] = true
		end
		
		local result = {}
		for _, plant in ipairs(sortedPlants) do
			local owned = unlockedSet[plant.PlantType] == true
			if filter == "All" or (filter == "Owned" and owned) or (filter == "Locked" and not owned) then
				table.insert(result, plant)
			end
		end
		return result
	end)
	
	return New(scope, "Frame") {
		Name = "ShopScreen",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		ZIndex = 100,
		
		[Children] = {
			-- Main panel
			New(scope, "Frame") {
				Name = "Panel",
				Size = Theme.Layout.OverlaySize,
				Position = Theme.Layout.OverlayPosition,
				AnchorPoint = Theme.Layout.OverlayAnchorPoint,
				BackgroundTransparency = 1,
				
				[Children] = {
					-- Responsive scaling
					ResponsiveUtils.CreateUIScale(scope),
					-- Header
					New(scope, "Frame") {
						Name = "Header",
						Size = UDim2.new(1, 0, 0, HEADER_HEIGHT + SHADOW_OFFSET),
						BackgroundTransparency = 1,
						
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
									
									-- Title
									New(scope, "TextLabel") {
										Name = "Title",
										Size = UDim2.fromOffset(200, 40),
										Position = UDim2.new(0.5, 0, 0.5, 0),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = "🛒 SHOP",
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextSize = 28,
										Font = Theme.Typography.Fonts.Title,
									},
									
									-- Coins display
									New(scope, "Frame") {
										Name = "CoinsContainer",
										Size = UDim2.fromOffset(100, 36),
										Position = UDim2.new(0, 20, 0.5, 0),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										
										[Children] = {
											ResourcePill({
												Scope = scope,
												Icon = Theme.Icons.Coin,
												Value = props.Coins,
												Color = "Gold",
												Width = 110,
											}),
										},
									},
									
									-- Close button
									New(scope, "Frame") {
										Name = "CloseContainer",
										Size = UDim2.fromOffset(50, 50 + SHADOW_OFFSET),
										Position = UDim2.new(1, -16, 0.5, 0),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										
										[Children] = {
											-- Shadow
											New(scope, "Frame") {
												Size = UDim2.fromOffset(50, 50),
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
												Size = Computed(scope, function(use)
													local offset = use(closeOffset)
													return UDim2.fromOffset(50, 50 - offset)
												end),
												Position = Computed(scope, function(use)
													return UDim2.fromOffset(0, use(closeOffset))
												end),
												BackgroundColor3 = Theme.Colors.Danger.Main,
												Text = Theme.Icons.Close,
												TextColor3 = Color3.new(1, 1, 1),
												TextSize = 22,
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
					
					-- Filters row
					New(scope, "Frame") {
						Name = "Filters",
						Size = UDim2.new(1, 0, 0, 50),
						Position = UDim2.fromOffset(0, HEADER_HEIGHT + SHADOW_OFFSET + 12),
						BackgroundTransparency = 1,
						
						[Children] = {
							New(scope, "UIListLayout") {
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 12),
							},
							
							FilterPill({
								Scope = scope,
								Text = "All",
								IsActive = Computed(scope, function(use)
									return use(selectedFilter) == "All"
								end),
								OnClick = function()
									selectedFilter:set("All")
								end,
								LayoutOrder = 1,
							}),
							
							FilterPill({
								Scope = scope,
								Text = "Owned",
								IsActive = Computed(scope, function(use)
									return use(selectedFilter) == "Owned"
								end),
								OnClick = function()
									selectedFilter:set("Owned")
								end,
								LayoutOrder = 2,
							}),
							
							FilterPill({
								Scope = scope,
								Text = "Locked",
								IsActive = Computed(scope, function(use)
									return use(selectedFilter) == "Locked"
								end),
								OnClick = function()
									selectedFilter:set("Locked")
								end,
								LayoutOrder = 3,
							}),
						},
					},
					
					-- Grid container
					New(scope, "Frame") {
						Name = "GridContainer",
						Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + SHADOW_OFFSET + 70)),
						Position = UDim2.fromOffset(0, HEADER_HEIGHT + SHADOW_OFFSET + 62),
						BackgroundTransparency = 1,
						
						[Children] = {
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
							
							-- Scrolling frame
							New(scope, "ScrollingFrame") {
								Name = "Grid",
								Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ScrollBarThickness = 8,
								ScrollBarImageColor3 = Theme.Colors.Surface.Shadow,
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								CanvasSize = UDim2.new(0, 0, 0, 0),
								ZIndex = 2,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									
									New(scope, "UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									New(scope, "UIPadding") {
										PaddingTop = UDim.new(0, 16),
										PaddingBottom = UDim.new(0, 20),
										PaddingLeft = UDim.new(0, 16),
										PaddingRight = UDim.new(0, 16),
									},
									
									New(scope, "UIGridLayout") {
										CellSize = UDim2.fromOffset(160, 224),
										CellPadding = UDim2.fromOffset(16, 16),
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										SortOrder = Enum.SortOrder.LayoutOrder,
									},
									
									-- Plant cards (reactive)
									Computed(scope, function(use)
										local plants = use(filteredPlants)
										local coins = use(props.Coins) or 0
										local unlocked = use(props.UnlockedPlants) or {}
										
										-- Build unlocked set
										local unlockedSet: {[string]: boolean} = {}
										for _, pt in ipairs(unlocked) do
											unlockedSet[pt] = true
										end
										
										local cards = {}
										for i, plant in ipairs(plants) do
											table.insert(cards, ShopCard({
												Scope = scope,
												PlantType = plant.PlantType,
												Cost = plant.Info.Cost,
												IsUnlocked = Value(scope, unlockedSet[plant.PlantType] == true),
												CanAfford = Value(scope, coins >= plant.Info.Cost),
												OnPurchase = function()
													props.OnPurchase(plant.PlantType)
												end,
												LayoutOrder = i,
											}))
										end
										return cards
									end),
								},
							},
						},
					},
				},
			},
		},
	}
end

return ShopScreen
