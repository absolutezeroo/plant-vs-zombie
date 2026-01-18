--!strict
--[[
	ShopScreen.luau - Plant shop overlay screen (Fusion 0.3 Responsive)
	
	Organism displaying available plants for purchase.
	Uses modular layout components for consistent design.
	
	Fully responsive using Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionData = require(Shared.data.ProgressionData)

-- Layout components
local ScreenOverlay = require(Shared.ui.components.layout.ScreenOverlay)
local ScreenHeader = require(Shared.ui.components.layout.ScreenHeader)
local ScrollableGrid = require(Shared.ui.components.layout.ScrollableGrid)

-- Indicator components
local FilterBar = require(Shared.ui.components.indicators.FilterBar)
local FilterPill = require(Shared.ui.components.indicators.FilterPill)
local ResourcePill = require(Shared.ui.components.indicators.ResourcePill)

-- Card components
local ShopCard = require(Shared.ui.components.cards.ShopCard)

-- Fusion primitives
local Children = Fusion.Children

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
	Scope: Fusion.Scope<any>,
	Coins: any, -- Fusion.Value<number>
	UnlockedPlants: any, -- Fusion.Value<{string}>
	OnClose: () -> (),
	OnPurchase: (plantType: string) -> (),
}

local function ShopScreen(props: ShopScreenProps): Frame
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

	-- Build grid cards
	local gridCards = scope:Computed(function(use)
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
	end)

	return ScreenOverlay({
		Scope = scope,
		Name = "ShopScreen",

		[Children] = {
			-- Header (top 10%)
			ScreenHeader({
				Scope = scope,
				Title = "SHOP",
				OnClose = props.OnClose,
				LeftContent = {
					ResourcePill({
						Scope = scope,
						IconName = "Coin",
						Value = props.Coins,
						Color = "Gold",
						Width = 110,
					}),
				},
			}),

			-- Filters row (6% height)
			FilterBar({
				Scope = scope,
				Options = { "All", "Owned", "Locked" },
				SelectedValue = selectedFilter,
				OnSelect = function(value)
					selectedFilter:set(value)
				end,
				FilterPillComponent = FilterPill,
				Position = UDim2.fromScale(0.5, 0.11),
				ViewportSize = viewportSize,
			}),

			-- Grid container (bottom 82%)
			ScrollableGrid({
				Scope = scope,
				Size = UDim2.fromScale(1, 0.82),
				Position = UDim2.fromScale(0.5, 1),
				AnchorPoint = Vector2.new(0.5, 1),
				CellSize = gridCellSize,
				CellPadding = gridCellPadding,
				Children = gridCards,
			}),
		},
	})
end

return ShopScreen
