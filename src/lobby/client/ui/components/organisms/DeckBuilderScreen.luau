--!strict
--[[
	DeckBuilderScreen.luau - Deck building overlay screen (Toon Pop + Responsive)
	
	Organism for building and managing plant decks.
	Uses modular layout components for consistent design.
	
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

-- Layout components
local ScreenOverlay = require(Shared.ui.components.layout.ScreenOverlay)
local ScreenHeader = require(Shared.ui.components.layout.ScreenHeader)
local ScrollableGrid = require(Shared.ui.components.layout.ScrollableGrid)

-- Indicator components
local FilterBar = require(Shared.ui.components.indicators.FilterBar)
local FilterPill = require(Shared.ui.components.indicators.FilterPill)

-- Card components
local DeckBar = require(Shared.ui.components.cards.DeckBar)
local DeckCard = require(Shared.ui.components.cards.DeckCard)

-- Fusion primitives
local Children = Fusion.Children
local peek = Fusion.peek
local ForValues = Fusion.ForValues

-- Constants
local MAX_DECK_SIZE = 6

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

	-- Filter categories
	local categories = { "All", "Attacker", "Producer", "Defender", "Special" }

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

	-- Build deck count pill for header
	local deckCountPill = scope:New("Frame")({
		Name = "DeckCount",
		Size = UDim2.fromScale(1, 0.9),
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
	})

	-- Build grid cards using ForValues for proper lifecycle management
	local gridCards = ForValues(scope, filteredPlants, function(use, innerScope, plantInfo)
		local unlocked = use(unlockedSet)
		local mutations = if props.PlantMutations then use(props.PlantMutations) else nil
		
		local isLocked = not unlocked[plantInfo.PlantType]
		local plantMutations = if mutations then mutations[plantInfo.PlantType] else nil

		return DeckCard({
			Scope = innerScope,
			PlantType = plantInfo.PlantType,
			Deck = localDeck,
			IsLocked = isLocked,
			EquippedMutations = plantMutations,
			OnToggle = function()
				togglePlant(plantInfo.PlantType)
			end,
			LayoutOrder = plantInfo.Order,
		})
	end)

	return ScreenOverlay({
		Scope = scope,
		Name = "DeckBuilderScreen",

		[Children] = {
			-- Header (top 10%)
			ScreenHeader({
				Scope = scope,
				Title = "🌱 DECK BUILDER",
				OnClose = props.OnBack,
				LeftContent = { deckCountPill },
			}),

			-- Deck Bar (11% to 25% = 14% height)
			DeckBar({
				Scope = scope,
				Deck = localDeck,
				PlantMutations = props.PlantMutations,
				OnRemovePlant = removePlant,
				Position = UDim2.fromScale(0.5, 0.11),
			}),

			-- Filters row (26% to 32% = 6% height)
			FilterBar({
				Scope = scope,
				Options = categories,
				SelectedValue = selectedFilter,
				OnSelect = function(value)
					selectedFilter:set(value)
				end,
				FilterPillComponent = FilterPill,
				Position = UDim2.fromScale(0.5, 0.26),
				ViewportSize = viewportSize,
			}),

			-- Grid container (33% to 100% = 67% height)
			ScrollableGrid({
				Scope = scope,
				Size = UDim2.fromScale(1, 0.67),
				Position = UDim2.fromScale(0.5, 1),
				AnchorPoint = Vector2.new(0.5, 1),
				CellSize = gridCellSize,
				CellPadding = gridCellPadding,
				Children = gridCards,
			}),
		},
	})
end

return DeckBuilderScreen
