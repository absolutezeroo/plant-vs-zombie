--!nonstrict
--[[
	ShopScreen.luau - Plant shop overlay screen (Fusion 0.3 Responsive)
	
	Organism displaying available plants for purchase.
	Uses "Toon Pop" design system with atomic components.
	
	Fully responsive using Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local ProgressionData = require(Shared.data.ProgressionData)

local Atoms = script.Parent.Parent.atoms
local FilterPill = require(Atoms.FilterPill)
local ShopCard = require(Atoms.ShopCard)
local ResourcePill = require(Atoms.ResourcePill)

-- Fusion 0.3 scope-based primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Get sorted plants list
local function getSortedPlants(): { { PlantType: string, Info: ProgressionData.PlantUnlockInfo } }
	local plants = {}
	for plantType, info in pairs(ProgressionData.PlantUnlocks) do
		table.insert(plants, { PlantType = plantType, Info = info })
	end
	table.sort(plants, function(a, b)
		return a.Info.Order < b.Info.Order
	end)
	return plants
end

export type ShopScreenProps = {
	Scope: any, -- Fusion scope
	Coins: any, -- Fusion.Value<number>
	UnlockedPlants: any, -- Fusion.Value<{string}>
	OnClose: () -> (),
	OnPurchase: (plantType: string) -> (),
}

local function ShopScreen(props: ShopScreenProps)
	local scope = props.Scope
	local sortedPlants = getSortedPlants()

	-- Viewport-based responsive sizing
	local camera = workspace.CurrentCamera
	local viewportSize = scope:Value(camera and camera.ViewportSize or Vector2.new(1920, 1080))
	if camera then
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewportSize:set(camera.ViewportSize)
		end)
		table.insert(scope, connection)
	end

	-- Responsive cell size for grid (scales with viewport, ref 1080p)
	local gridCellSize = scope:Computed(function(use)
		local size = use(viewportSize)
		local scale = math.clamp(size.Y / 1080, 0.6, 1.8)
		return UDim2.fromOffset(math.floor(160 * scale), math.floor(224 * scale))
	end)

	local gridCellPadding = scope:Computed(function(use)
		local size = use(viewportSize)
		local scale = math.clamp(size.Y / 1080, 0.6, 1.8)
		local padding = math.floor(16 * scale)
		return UDim2.fromOffset(padding, padding)
	end)

	-- Filter state
	local selectedFilter = scope:Value("All")

	-- Close button state
	local isClosePressed = scope:Value(false)
	local closeOffset = scope:Spring(
		scope:Computed(function(use)
			return if use(isClosePressed) then 4 else 0
		end),
		40,
		0.7
	)

	-- Filtered plants
	local filteredPlants = scope:Computed(function(use)
		local filter = use(selectedFilter)
		local unlocked = use(props.UnlockedPlants) or {}

		-- Build unlocked set
		local unlockedSet: { [string]: boolean } = {}
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

	return scope:New("Frame")({
		Name = "ShopScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		ZIndex = 100,

		[Children] = {
			-- Main panel (centered)
			scope:New("Frame")({
				Name = "Panel",
				Size = UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					-- Header (top 10%)
					scope:New("Frame")({
						Name = "Header",
						Size = UDim2.fromScale(1, 0.1),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Children] = {
							-- Shadow
							scope:New("Frame")({
								Name = "Shadow",
								Size = UDim2.fromScale(1, 0.9),
								Position = UDim2.fromScale(0.5, 0.1),
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
								Size = UDim2.fromScale(1, 0.9),
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

									-- Title (centered)
									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.fromScale(0.3, 0.6),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = "🛒 SHOP",
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Title,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MaxTextSize = 32,
												MinTextSize = 16,
											}),
										},
									}),

									-- Coins display (left)
									scope:New("Frame")({
										Name = "CoinsContainer",
										Size = UDim2.fromScale(0.15, 0.6),
										Position = UDim2.fromScale(0.02, 0.5),
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
									}),

									-- Close button (right) - Square
									scope:New("Frame")({
										Name = "CloseContainer",
										Size = UDim2.fromScale(0.08, 0.75),
										Position = UDim2.fromScale(0.98, 0.5),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,

										[Children] = {
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 1,
												DominantAxis = Enum.DominantAxis.Height,
											}),

											-- Shadow
											scope:New("Frame")({
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
													scope:New("UICorner")({
														CornerRadius = Theme.Layout.CornerRadius,
													}),
													scope:New("UIStroke")({
														Color = Theme.Colors.Surface.Stroke :: Color3,
														Thickness = 2,
													}),
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 24,
														MinTextSize = 14,
													}),
												},
											}),
										},
									}),
								},
							}),
						},
					}),

					-- Filters row (6% height)
					scope:New("Frame")({
						Name = "Filters",
						Size = UDim2.fromScale(1, 0.06),
						Position = UDim2.fromScale(0.5, 0.11),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Children] = {
							-- Responsive scale for filter pills
							scope:New("UIScale")({
								Scale = scope:Computed(function(use)
									local size = use(viewportSize)
									return math.clamp(size.Y / 1080, 0.6, 1.5)
								end),
							}),

							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0.02, 0),
							}),

							FilterPill({
								Scope = scope,
								Text = "All",
								IsActive = scope:Computed(function(use)
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
								IsActive = scope:Computed(function(use)
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
								IsActive = scope:Computed(function(use)
									return use(selectedFilter) == "Locked"
								end),
								OnClick = function()
									selectedFilter:set("Locked")
								end,
								LayoutOrder = 3,
							}),
						},
					}),

					-- Grid container (bottom 82%)
					scope:New("Frame")({
						Name = "GridContainer",
						Size = UDim2.fromScale(1, 0.82),
						Position = UDim2.fromScale(0.5, 1),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,

						[Children] = {
							-- Shadow
							scope:New("Frame")({
								Name = "Shadow",
								Size = UDim2.fromScale(1, 0.99),
								Position = UDim2.fromScale(0.5, 0.01),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Layout.CornerRadius,
									}),
								},
							}),

							-- Scrolling frame
							scope:New("ScrollingFrame")({
								Name = "Grid",
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
									scope:New("UICorner")({
										CornerRadius = Theme.Layout.CornerRadius,
									}),

									scope:New("UIStroke")({
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									}),

									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 12),
										PaddingBottom = UDim.new(0, 20),
										PaddingLeft = UDim.new(0, 12),
										PaddingRight = UDim.new(0, 12),
									}),

									scope:New("UIGridLayout")({
										CellSize = gridCellSize,
										CellPadding = gridCellPadding,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									-- Plant cards (reactive)
									scope:Computed(function(use)
										local plants = use(filteredPlants)
										local coins = use(props.Coins) or 0
										local unlocked = use(props.UnlockedPlants) or {}

										-- Build unlocked set
										local unlockedSet: { [string]: boolean } = {}
										for _, pt in ipairs(unlocked) do
											unlockedSet[pt] = true
										end

										local cards = {}
										for i, plant in ipairs(plants) do
											table.insert(
												cards,
												ShopCard({
													Scope = scope,
													PlantType = plant.PlantType,
													Cost = plant.Info.Cost,
													IsUnlocked = scope:Value(unlockedSet[plant.PlantType] == true),
													CanAfford = scope:Value(coins >= plant.Info.Cost),
													OnPurchase = function()
														props.OnPurchase(plant.PlantType)
													end,
													LayoutOrder = i,
												})
											)
										end
										return cards
									end),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return ShopScreen
