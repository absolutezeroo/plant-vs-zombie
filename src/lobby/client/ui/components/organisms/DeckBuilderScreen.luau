--!strict
--[[
	DeckBuilderScreen.luau - Deck building overlay screen (Toon Pop + Responsive)
	
	Organism for building and managing plant decks.
	Follows EXACT same "Toon Pop" design as ShopScreen:
	- Dark overlay background (50% black)
	- Centered panel (90% x 90%) with BackgroundTransparency = 1
	- Position-based layout (no UIListLayout for main sections)
	- Each section (Header, DeckBar, Grid) has its own Shadow + Main
	
	RESPONSIVE: Uses UDim2.fromScale() + UIAspectRatioConstraint + UITextSizeConstraint
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local PlantData = require(Shared.data.PlantData)
local ProgressionData = require(Shared.data.ProgressionData)
local MutationData = require(Shared.data.MutationData)
local PlantViewport = require(Shared.ui.components.atoms.PlantViewport)

-- Local atoms
local Atoms = script.Parent.Parent.atoms
local FilterPill = require(Atoms.FilterPill)
local DeckCard = require(Atoms.DeckCard)

-- Fusion primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Constants
local MAX_DECK_SIZE = 6

-- Colors (Toon Pop)
local GOLD_BORDER = Color3.fromHex("#FFD700")
local GREEN_SELECTED = Color3.fromHex("#4CAF50")

-- Get sorted plants from progression data
local function getSortedPlants(): { { PlantType: string, Order: number, Stats: any } }
	local plants = {}
	for plantType, info in ProgressionData.PlantUnlocks do
		local stats = PlantData.GetStats(plantType)
		if stats then
			table.insert(plants, { PlantType = plantType, Order = info.Order, Stats = stats })
		end
	end
	table.sort(plants, function(a, b)
		return a.Order < b.Order
	end)
	return plants
end

export type DeckBuilderScreenProps = {
	Scope: Fusion.Scope<any>,
	SelectedDeck: any, -- Value<{string}>
	PlayerData: any, -- Value<PlayerData>
	PlantMutations: any?, -- Value<{[string]: {string}}>
	OnBack: () -> (),
	OnPlay: () -> (),
	OnSaveDeck: (deck: { string }) -> (),
}

--------------------------------------------------------------------------------
-- DeckSlot Component - A single slot in the deck bar (Responsive)
--------------------------------------------------------------------------------
local function DeckSlot(
	scope: any,
	props: {
		Index: number,
		PlantType: string?,
		Mutations: { string }?,
		OnRemove: () -> (),
	}
): Frame
	local hasPlant = props.PlantType ~= nil
	local hasMutations = props.Mutations and #props.Mutations > 0
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	-- Press animation (scale-based)
	local pressScale = scope:Spring(
		scope:Computed(function(use)
			return if use(isPressed) then 0.92 else 1
		end),
		40,
		0.7
	)

	-- Border color based on state
	local borderColor = if hasMutations
		then GOLD_BORDER
		elseif hasPlant then GREEN_SELECTED
		else Theme.Colors.Surface.Stroke

	-- Create viewport for plant
	local plantViewport: ViewportFrame? = nil
	if hasPlant then
		plantViewport = PlantViewport.CreateWithScope(scope, {
			PlantType = props.PlantType :: string,
			Size = UDim2.fromScale(0.9, 0.5),
			Position = UDim2.fromScale(0.5, 0.38),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
			CameraFOV = 35,
			CameraDistance = 1.4,
			CameraHeight = 0.12,
		})
	end

	return scope:New("Frame")({
		Name = "Slot" .. props.Index,
		Size = UDim2.fromScale(0.12, 1), -- Width will be constrained by aspect ratio
		BackgroundTransparency = 1,

		[Children] = {
			-- Maintain square aspect ratio
			scope:New("UIAspectRatioConstraint")({
				AspectRatio = 0.8,
				DominantAxis = Enum.DominantAxis.Height,
			}),

			-- Scale wrapper for press animation
			scope:New("Frame")({
				Name = "ScaleWrapper",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = scope:Computed(function(use)
					local s = use(pressScale)
					return UDim2.fromScale(s, s)
				end),
				BackgroundTransparency = 1,

				[Children] = {
					-- Shadow
					scope:New("Frame")({
						Name = "Shadow",
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.fromScale(0, 0.06),
						BackgroundColor3 = if hasPlant
							then (if hasMutations then Color3.fromHex("#B8860B") else Color3.fromHex("#357A38"))
							else Theme.Colors.Surface.Shadow,
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.12, 0),
							}),
						},
					}),

					-- Main slot
					scope:New("Frame")({
						Name = "Main",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = scope:Computed(function(use)
							if hasPlant and use(isHovered) then
								return Theme.Colors.Danger.Main
							end
							return Theme.Colors.Surface.Main
						end),
						ZIndex = 2,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.12, 0),
							}),

							scope:New("UIStroke")({
								Color = borderColor,
								Thickness = if hasMutations then 3 else Theme.Layout.StrokeThickness,
							}),

							-- Slot number badge (top-left)
							scope:New("Frame")({
								Size = UDim2.fromScale(0.3, 0.22),
								Position = UDim2.fromScale(0.05, 0.05),
								BackgroundColor3 = Theme.Colors.Surface.Stroke,
								ZIndex = 5,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0.5, 0),
									}),
									scope:New("UIAspectRatioConstraint")({
										AspectRatio = 1,
									}),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = tostring(props.Index),
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										Font = Enum.Font.GothamBold,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MinTextSize = 6,
												MaxTextSize = 14,
											}),
										},
									}),
								},
							}),

							-- Mutation badge (top-right)
							hasMutations
									and scope:New("Frame")({
										Size = UDim2.fromScale(0.3, 0.22),
										Position = UDim2.fromScale(0.95, 0.05),
										AnchorPoint = Vector2.new(1, 0),
										BackgroundColor3 = GOLD_BORDER,
										ZIndex = 6,

										[Children] = {
											scope:New("UICorner")({
												CornerRadius = UDim.new(0.5, 0),
											}),
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 1,
											}),
											scope:New("TextLabel")({
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = if props.Mutations
													then (MutationData.Get(props.Mutations[1]) or { Icon = "✨" }).Icon
													else "✨",
												TextScaled = true,

												[Children] = {
													scope:New("UITextSizeConstraint")({
														MinTextSize = 6,
														MaxTextSize = 12,
													}),
												},
											}),
										},
									})
								or nil,

							-- Plant viewport or empty plus
							if hasPlant
								then plantViewport
								else scope:New("TextLabel")({
									Size = UDim2.fromScale(0.8, 0.5),
									Position = UDim2.fromScale(0.5, 0.4),
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Text = "+",
									TextColor3 = Theme.Colors.Surface.Shadow,
									TextScaled = true,
									Font = Theme.Typography.Fonts.Title,

									[Children] = {
										scope:New("UITextSizeConstraint")({
											MinTextSize = 14,
											MaxTextSize = 32,
										}),
									},
								}),

							-- Plant name label
							hasPlant
									and scope:New("TextLabel")({
										Size = UDim2.fromScale(0.9, 0.15),
										Position = UDim2.fromScale(0.5, 0.88),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = props.PlantType :: string,
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextScaled = true,
										Font = Enum.Font.GothamBold,
										TextTruncate = Enum.TextTruncate.AtEnd,
										ZIndex = 4,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MinTextSize = 6,
												MaxTextSize = 10,
											}),
										},
									})
								or nil,

							-- Remove overlay on hover
							scope:Computed(function(use)
								if hasPlant and use(isHovered) then
									return scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "✕",
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										Font = Enum.Font.GothamBold,
										ZIndex = 10,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MinTextSize = 16,
												MaxTextSize = 32,
											}),
										},
									})
								end
								return nil :: any
							end),

							-- Click handler
							scope:New("TextButton")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 15,

								[OnEvent("MouseButton1Down")] = function()
									if hasPlant then
										isPressed:set(true)
									end
								end,

								[OnEvent("MouseButton1Up")] = function()
									isPressed:set(false)
									if hasPlant then
										props.OnRemove()
									end
								end,

								[OnEvent("MouseEnter")] = function()
									isHovered:set(true)
								end,

								[OnEvent("MouseLeave")] = function()
									isHovered:set(false)
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

--------------------------------------------------------------------------------
-- DeckBuilderScreen Component (Responsive - Same structure as ShopScreen)
--------------------------------------------------------------------------------
local function DeckBuilderScreen(props: DeckBuilderScreenProps): Frame
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
		return UDim2.fromOffset(math.floor(140 * scale), math.floor(196 * scale))
	end)

	local gridCellPadding = scope:Computed(function(use)
		local size = use(viewportSize)
		local scale = math.clamp(size.Y / 1080, 0.6, 1.8)
		local padding = math.floor(12 * scale)
		return UDim2.fromOffset(padding, padding)
	end)

	-- Local deck state (mirrors SelectedDeck for local edits)
	local localDeck = scope:Value(Sift.Array.copy(peek(props.SelectedDeck) or {}))

	-- Filter state
	local selectedFilter = scope:Value("All")

	-- Close button animation
	local isClosePressed = scope:Value(false)
	local closeOffset = scope:Spring(
		scope:Computed(function(use)
			return if use(isClosePressed) then 4 else 0
		end),
		40,
		0.7
	)

	-- Unlocked plants set for fast lookup
	local unlockedSet = scope:Computed(function(use)
		local data = use(props.PlayerData)
		local set: { [string]: boolean } = {}
		if data and data.UnlockedPlants then
			for _, pt in data.UnlockedPlants do
				set[pt] = true
			end
		end
		return set
	end)

	-- Filtered plants based on selected category
	local filteredPlants = scope:Computed(function(use)
		local filter = use(selectedFilter)
		local result = {}
		for _, p in sortedPlants do
			if filter == "All" or p.Stats.Category == filter then
				table.insert(result, p)
			end
		end
		return result
	end)

	-- Toggle plant in/out of deck (auto-saves)
	local function togglePlant(plantType: string)
		local deck = peek(localDeck)
		local idx = table.find(deck, plantType)
		local newDeck
		if idx then
			-- Remove from deck
			newDeck = Sift.Array.filter(deck, function(p)
				return p ~= plantType
			end)
		elseif #deck < MAX_DECK_SIZE then
			-- Add to deck
			newDeck = Sift.Array.push(deck, plantType)
		else
			newDeck = deck
		end
		localDeck:set(newDeck)
		props.SelectedDeck:set(Sift.Array.copy(newDeck))
		props.OnSaveDeck(newDeck) -- Auto-save
	end

	-- Remove plant from specific slot (auto-saves)
	local function removePlant(index: number)
		local deck = peek(localDeck)
		if deck[index] then
			local newDeck = Sift.Array.removeIndex(deck, index)
			localDeck:set(newDeck)
			props.SelectedDeck:set(Sift.Array.copy(newDeck))
			props.OnSaveDeck(newDeck) -- Auto-save
		end
	end

	-- Filter categories
	local categories = { "All", "Attacker", "Producer", "Defender", "Special" }

	return scope:New("Frame")({
		Name = "DeckBuilderScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		ZIndex = 100,

		[Children] = {
			-- Main panel (centered, transparent like ShopScreen)
			scope:New("Frame")({
				Name = "Panel",
				Size = UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					-- ═══════════════════════════════════════════════
					-- HEADER (top 10%) - Same style as ShopScreen
					-- ═══════════════════════════════════════════════
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
										Text = "🌱 DECK BUILDER",
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

									-- Deck count pill (left side)
									scope:New("Frame")({
										Name = "DeckCount",
										Size = UDim2.fromScale(0.12, 0.55),
										Position = UDim2.fromScale(0.02, 0.5),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundColor3 = Theme.Colors.Action.Main,

										[Children] = {
											scope:New("UICorner")({
												CornerRadius = UDim.new(0.4, 0),
											}),
											scope:New("UIStroke")({
												Color = Theme.Colors.Action.Shadow,
												Thickness = 2,
											}),
											scope:New("TextLabel")({
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = scope:Computed(function(use)
													return `🌿 {#use(localDeck)}/{MAX_DECK_SIZE}`
												end),
												TextColor3 = Color3.new(1, 1, 1),
												TextScaled = true,
												Font = Enum.Font.GothamBold,

												[Children] = {
													scope:New("UITextSizeConstraint")({
														MinTextSize = 10,
														MaxTextSize = 16,
													}),
												},
											}),
										},
									}),

									-- Close button (right) - Same style as ShopScreen
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
													props.OnBack()
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

					-- ═══════════════════════════════════════════════
					-- DECK BAR (11% to 25% = 14% height)
					-- ═══════════════════════════════════════════════
					scope:New("Frame")({
						Name = "DeckBar",
						Size = UDim2.fromScale(1, 0.14),
						Position = UDim2.fromScale(0.5, 0.11),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

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

							-- Main bar
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

									scope:New("UIPadding")({
										PaddingTop = UDim.new(0.08, 0),
										PaddingBottom = UDim.new(0.08, 0),
										PaddingLeft = UDim.new(0.05, 0),
										PaddingRight = UDim.new(0.05, 0),
									}),

									-- Slots container (horizontally centered)
									scope:New("Frame")({
										Size = UDim2.fromScale(0.8, 1),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,

										[Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												VerticalAlignment = Enum.VerticalAlignment.Center,
												Padding = UDim.new(0.02, 0),
											}),

											-- Reactive slots
											scope:Computed(function(use)
												local deck = use(localDeck)
												local mutations = if props.PlantMutations
													then use(props.PlantMutations)
													else {}
												local slots = {}
												for i = 1, MAX_DECK_SIZE do
													local plantType = deck[i]
													table.insert(
														slots,
														DeckSlot(scope, {
															Index = i,
															PlantType = plantType,
															Mutations = if plantType then mutations[plantType] else nil,
															OnRemove = function()
																removePlant(i)
															end,
														})
													)
												end
												return slots
											end),
										},
									}),
								},
							}),
						},
					}),

					-- ═══════════════════════════════════════════════
					-- FILTERS ROW (26% to 32% = 6% height) - Transparent
					-- ═══════════════════════════════════════════════
					scope:New("Frame")({
						Name = "Filters",
						Size = UDim2.fromScale(1, 0.06),
						Position = UDim2.fromScale(0.5, 0.26),
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

							-- Filter pills
							(function()
								local pills = {}
								for i, cat in categories do
									table.insert(
										pills,
										FilterPill({
											Scope = scope,
											Text = cat,
											IsActive = scope:Computed(function(use)
												return use(selectedFilter) == cat
											end),
											OnClick = function()
												selectedFilter:set(cat)
											end,
											LayoutOrder = i,
										})
									)
								end
								return pills
							end)(),
						},
					}),

					-- ═══════════════════════════════════════════════
					-- GRID CONTAINER (33% to 100% = 67% height) - Same as ShopScreen
					-- ═══════════════════════════════════════════════
					scope:New("Frame")({
						Name = "GridContainer",
						Size = UDim2.fromScale(1, 0.67),
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

									-- Plant cards (reactive to filter and deck state)
									scope:Computed(function(use)
										local plants = use(filteredPlants)
										local unlocked = use(unlockedSet)
										local mutations = if props.PlantMutations
											then use(props.PlantMutations)
											else nil

										local cards = {}
										for i, p in plants do
											local isLocked = not unlocked[p.PlantType]
											local isInDeck = scope:Computed(function(use2)
												return table.find(use2(localDeck), p.PlantType) ~= nil
											end)
											local plantMutations = if mutations then mutations[p.PlantType] else nil

											table.insert(
												cards,
												DeckCard({
													Scope = scope,
													PlantType = p.PlantType,
													IsInDeck = isInDeck,
													IsLocked = isLocked,
													EquippedMutations = plantMutations,
													OnToggle = function()
														togglePlant(p.PlantType)
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

return DeckBuilderScreen
