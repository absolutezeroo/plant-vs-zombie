--!strict
--[[
	DeckBuilderScreen.luau - Deck building overlay screen (Toon Pop)
	
	Organism for building and managing plant decks.
	Follows the same "Toon Pop" design as ShopScreen:
	- Dark overlay background
	- Centered panel with header + shadows
	- 3D deck slots bar 
	- Filterable plant grid with DeckCard atoms
	- Play button with shadow press animation
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
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Constants
local SHADOW_OFFSET = 4
local HEADER_HEIGHT = 70
local DECK_BAR_HEIGHT = 100
local SLOT_SIZE = 68
local MAX_DECK_SIZE = 6

-- Colors
local GOLD_BORDER = Color3.fromHex("#FFD700")
local GREEN_SELECTED = Color3.fromHex("#4CAF50")

-- Get sorted plants from progression data
local function getSortedPlants(): {{PlantType: string, Order: number, Stats: any}}
	local plants = {}
	for plantType, info in ProgressionData.PlantUnlocks do
		local stats = PlantData.GetStats(plantType)
		if stats then
			table.insert(plants, {PlantType = plantType, Order = info.Order, Stats = stats})
		end
	end
	table.sort(plants, function(a, b) return a.Order < b.Order end)
	return plants
end

export type DeckBuilderScreenProps = {
	Scope: Fusion.Scope<any>,
	SelectedDeck: any, -- Value<{string}>
	PlayerData: any, -- Value<PlayerData>
	PlantMutations: any?, -- Value<{[string]: {string}}>
	OnBack: () -> (),
	OnPlay: () -> (),
	OnSaveDeck: (deck: {string}) -> (),
}

--------------------------------------------------------------------------------
-- DeckSlot Component - A single slot in the deck bar
--------------------------------------------------------------------------------
local function DeckSlot(scope: any, props: {
	Index: number,
	PlantType: string?,
	Mutations: {string}?,
	OnRemove: () -> (),
}): Frame
	local hasPlant = props.PlantType ~= nil
	local hasMutations = props.Mutations and #props.Mutations > 0
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	
	-- Create viewport for plant
	local plantViewport: ViewportFrame? = nil
	if hasPlant then
		plantViewport = PlantViewport.CreateWithScope(scope, {
			PlantType = props.PlantType :: string,
			Size = UDim2.new(1, -12, 0, 42),
			Position = UDim2.new(0.5, 0, 0, 18),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 3,
			CameraFOV = 38,
			CameraDistance = 1.5,
			CameraHeight = 0.15,
		})
	end
	
	-- Press animation
	local pressOffset = Spring(scope, Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end), 40, 0.7)
	
	-- Border color based on state
	local borderColor = if hasMutations 
		then GOLD_BORDER
		elseif hasPlant then GREEN_SELECTED 
		else Theme.Colors.Surface.Stroke
	
	return New(scope, "Frame") {
		Name = "Slot" .. props.Index,
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE + SHADOW_OFFSET + 12),
		BackgroundTransparency = 1,
		
		[Children] = {
			-- Shadow
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = if hasPlant 
					then (if hasMutations then Color3.fromHex("#B8860B") else Color3.fromHex("#357A38"))
					else Theme.Colors.Surface.Shadow,
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
				},
			},
			
			-- Main slot
			New(scope, "Frame") {
				Name = "Main",
				Size = Computed(scope, function(use)
					local offset = use(pressOffset)
					return UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE - offset)
				end),
				Position = Computed(scope, function(use)
					return UDim2.fromOffset(0, use(pressOffset))
				end),
				BackgroundColor3 = Computed(scope, function(use)
					if hasPlant and use(isHovered) then
						return Theme.Colors.Danger.Main
					end
					return Theme.Colors.Surface.Main
				end),
				ZIndex = 2,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
					
					New(scope, "UIStroke") {
						Color = borderColor,
						Thickness = if hasMutations then 3 else Theme.Layout.StrokeThickness,
					},
					
					-- Slot number badge (top-left)
					New(scope, "Frame") {
						Size = UDim2.fromOffset(18, 18),
						Position = UDim2.fromOffset(3, 3),
						BackgroundColor3 = Theme.Colors.Surface.Stroke,
						ZIndex = 5,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0.5, 0),
							},
							New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = tostring(props.Index),
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 10,
								Font = Enum.Font.GothamBold,
							},
						},
					},
					
					-- Mutation badge (top-right)
					hasMutations and New(scope, "Frame") {
						Size = UDim2.fromOffset(18, 18),
						Position = UDim2.new(1, -3, 0, 3),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundColor3 = GOLD_BORDER,
						ZIndex = 6,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0.5, 0),
							},
							New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = if props.Mutations then 
									(MutationData.Get(props.Mutations[1]) or {Icon = "✨"}).Icon
									else "✨",
								TextSize = 10,
							},
						},
					} or nil,
					
					-- Plant viewport or empty plus
					if hasPlant then plantViewport else New(scope, "TextLabel") {
						Size = UDim2.new(1, 0, 0, 36),
						Position = UDim2.fromOffset(0, 16),
						BackgroundTransparency = 1,
						Text = "+",
						TextColor3 = Theme.Colors.Surface.Shadow,
						TextSize = 26,
						Font = Theme.Typography.Fonts.Title,
					},
					
					-- Plant name label
					hasPlant and New(scope, "TextLabel") {
						Size = UDim2.new(1, -4, 0, 12),
						Position = UDim2.new(0, 2, 1, -14),
						BackgroundTransparency = 1,
						Text = props.PlantType :: string,
						TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
						TextSize = 8,
						Font = Enum.Font.GothamBold,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 4,
					} or nil,
					
					-- Remove overlay on hover
					Computed(scope, function(use)
						if hasPlant and use(isHovered) then
							return New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = "✕",
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 26,
								Font = Enum.Font.GothamBold,
								ZIndex = 10,
							}
						end
						return nil :: any
					end),
					
					-- Click handler
					New(scope, "TextButton") {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 15,
						
						[OnEvent("MouseButton1Down")] = function()
							if hasPlant then isPressed:set(true) end
						end,
						
						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							if hasPlant then props.OnRemove() end
						end,
						
						[OnEvent("MouseEnter")] = function()
							isHovered:set(true)
						end,
						
						[OnEvent("MouseLeave")] = function()
							isHovered:set(false)
							isPressed:set(false)
						end,
					},
				},
			},
		},
	}
end

--------------------------------------------------------------------------------
-- DeckBuilderScreen Component
--------------------------------------------------------------------------------
local function DeckBuilderScreen(props: DeckBuilderScreenProps): Frame
	local scope = props.Scope
	local sortedPlants = getSortedPlants()
	
	-- Local deck state (mirrors SelectedDeck for local edits)
	local localDeck = Value(scope, Sift.Array.copy(peek(props.SelectedDeck) or {}))
	
	-- Filter state
	local selectedFilter = Value(scope, "All")
	
	-- Close button animation
	local isClosePressed = Value(scope, false)
	local closeOffset = Spring(scope, Computed(scope, function(use)
		return if use(isClosePressed) then SHADOW_OFFSET else 0
	end), 40, 0.7)
	

	
	-- Unlocked plants set for fast lookup
	local unlockedSet = Computed(scope, function(use)
		local data = use(props.PlayerData)
		local set: {[string]: boolean} = {}
		if data and data.UnlockedPlants then
			for _, pt in data.UnlockedPlants do
				set[pt] = true
			end
		end
		return set
	end)
	
	-- Filtered plants based on selected category
	local filteredPlants = Computed(scope, function(use)
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
			newDeck = Sift.Array.filter(deck, function(p) return p ~= plantType end)
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
	
	return New(scope, "Frame") {
		Name = "DeckBuilderScreen",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		ZIndex = 100,
		
		[Children] = {
			-- Main panel (centered)
			New(scope, "Frame") {
				Name = "Panel",
				Size = Theme.Layout.OverlaySize,
				Position = Theme.Layout.OverlayPosition,
				AnchorPoint = Theme.Layout.OverlayAnchorPoint,
				BackgroundTransparency = 1,
				
				[Children] = {
					-- ========================================
					-- HEADER
					-- ========================================
					New(scope, "Frame") {
						Name = "Header",
						Size = UDim2.new(1, 0, 0, HEADER_HEIGHT + SHADOW_OFFSET),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- Shadow layer
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
							
							-- Main header layer
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
										Size = UDim2.fromOffset(250, 40),
										Position = UDim2.new(0.5, 0, 0.5, 0),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = "🌱 DECK BUILDER",
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextSize = 26,
										Font = Theme.Typography.Fonts.Title,
									},
									
									-- Deck count pill (left side)
									New(scope, "Frame") {
										Name = "DeckCount",
										Size = UDim2.fromOffset(100, 36),
										Position = UDim2.new(0, 20, 0.5, 0),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundColor3 = Theme.Colors.Action.Main,
										
										[Children] = {
											New(scope, "UICorner") {
												CornerRadius = UDim.new(0, 18),
											},
											New(scope, "UIStroke") {
												Color = Theme.Colors.Action.Shadow,
												Thickness = 2,
											},
											New(scope, "TextLabel") {
												Size = UDim2.new(1, 0, 1, 0),
												BackgroundTransparency = 1,
												Text = Computed(scope, function(use)
													return `🌿 {#use(localDeck)}/{MAX_DECK_SIZE}`
												end),
												TextColor3 = Color3.new(1, 1, 1),
												TextSize = 16,
												Font = Enum.Font.GothamBold,
											},
										},
									},
									
									-- Close button container
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
													props.OnBack()
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
					
					-- ========================================
					-- DECK SLOTS BAR
					-- ========================================
					New(scope, "Frame") {
						Name = "DeckBar",
						Size = UDim2.new(1, 0, 0, DECK_BAR_HEIGHT + SHADOW_OFFSET),
						Position = UDim2.fromOffset(0, HEADER_HEIGHT + SHADOW_OFFSET + 10),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- Shadow
							New(scope, "Frame") {
								Name = "Shadow",
								Size = UDim2.new(1, 0, 0, DECK_BAR_HEIGHT),
								Position = UDim2.fromOffset(0, SHADOW_OFFSET),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
							
							-- Main bar
							New(scope, "Frame") {
								Name = "Main",
								Size = UDim2.new(1, 0, 0, DECK_BAR_HEIGHT),
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
									
									-- Slots container (horizontally centered)
									New(scope, "Frame") {
										Size = UDim2.new(1, 0, 1, -8),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										
										[Children] = {
											New(scope, "UIListLayout") {
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												VerticalAlignment = Enum.VerticalAlignment.Center,
												Padding = UDim.new(0, 10),
											},
											
											-- Reactive slots
											Computed(scope, function(use)
												local deck = use(localDeck)
												local mutations = if props.PlantMutations then use(props.PlantMutations) else {}
												local slots = {}
												for i = 1, MAX_DECK_SIZE do
													local plantType = deck[i]
													table.insert(slots, DeckSlot(scope, {
														Index = i,
														PlantType = plantType,
														Mutations = if plantType then mutations[plantType] else nil,
														OnRemove = function() removePlant(i) end,
													}))
												end
												return slots
											end),
										},
									},
								},
							},
						},
					},
					
					-- ========================================
					-- FILTERS ROW
					-- ========================================
					New(scope, "Frame") {
						Name = "Filters",
						Size = UDim2.new(1, 0, 0, 50),
						Position = UDim2.fromOffset(0, HEADER_HEIGHT + DECK_BAR_HEIGHT + SHADOW_OFFSET * 2 + 20),
						BackgroundTransparency = 1,
						
						[Children] = {
							New(scope, "UIListLayout") {
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 10),
							},
							
							-- Filter pills
							(function()
								local pills = {}
								for i, cat in categories do
									table.insert(pills, FilterPill({
										Scope = scope,
										Text = cat,
										IsActive = Computed(scope, function(use)
											return use(selectedFilter) == cat
										end),
										OnClick = function()
											selectedFilter:set(cat)
										end,
										LayoutOrder = i,
									}))
								end
								return pills
							end)(),
						},
					},
					
					-- ========================================
					-- PLANTS GRID
					-- ========================================
					New(scope, "Frame") {
						Name = "GridContainer",
						Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + DECK_BAR_HEIGHT + SHADOW_OFFSET * 3 + 80)),
						Position = UDim2.fromOffset(0, HEADER_HEIGHT + DECK_BAR_HEIGHT + SHADOW_OFFSET * 2 + 70),
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
										CellSize = UDim2.fromOffset(100, 138),
										CellPadding = UDim2.fromOffset(12, 12),
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										SortOrder = Enum.SortOrder.LayoutOrder,
									},
									
									-- Plant cards (reactive to filter and deck state)
									Computed(scope, function(use)
										local plants = use(filteredPlants)
										local unlocked = use(unlockedSet)
										local mutations = if props.PlantMutations then use(props.PlantMutations) else {}
										
										local cards = {}
										for i, p in plants do
											local isLocked = not unlocked[p.PlantType]
											local isInDeck = Computed(scope, function(use2)
												return table.find(use2(localDeck), p.PlantType) ~= nil
											end)
											
											table.insert(cards, DeckCard({
												Scope = scope,
												PlantType = p.PlantType,
												IsInDeck = isInDeck,
												IsLocked = isLocked,
												EquippedMutations = mutations[p.PlantType],
												OnToggle = function()
													togglePlant(p.PlantType)
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

return DeckBuilderScreen
