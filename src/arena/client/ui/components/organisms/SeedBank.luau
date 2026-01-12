--!strict
--[[
	SeedBank.luau - Horizontal plant deck bar with "Toon Pop" style (Arena - Responsive)
	
	Organism component displaying the player's equipped plants.
	Uses ToonPanel as container and SeedCard for each plant.
	
	Handles plant selection and passes mutation data to cards.
	Fully responsive using Scale-based sizing.
	
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ToonPanel = require(Shared.ui.components.atoms.ToonPanel)

-- Path: client/ui/components/organisms/SeedBank.luau
local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

local Molecules = script.Parent.Parent.molecules
local SeedCard = require(Molecules.SeedCard)
local ShovelButton = require(Molecules.ShovelButton)

-- Fusion 0.3 primitives
local Children = Fusion.Children

export type SeedBankProps = {
	Scope: Fusion.Scope<any>,
	EquippedPlants: any, -- Can be {string} or Fusion.Value<{string}>
	EquippedMutations: any, -- Fusion.Value<{[string]: {string}}>
	OnPlantSelect: (plantType: string) -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,	
	LayoutOrder: number?,
}

--[[
	SeedBank Component (Arena - Responsive)
	
	A horizontal bar containing SeedCards for equipped plants.
	Wrapped in a ToonPanel for consistent styling.
	
	Uses percentage-based sizing that scales with viewport.
	
	@param props SeedBankProps
	@return Frame
]]
local function SeedBank(props: SeedBankProps): Frame
	local scope = props.Scope
	local equippedPlants = props.EquippedPlants
	local equippedMutations = props.EquippedMutations
	local onPlantSelect = props.OnPlantSelect
	
	local position = props.Position or UDim2.fromScale(0.5, 0.02)
	local anchorPoint = props.AnchorPoint or Vector2.new(0.5, 0)
	local zIndex = props.ZIndex or 1
	local layoutOrder = props.LayoutOrder or 0
	
	-- Constants for layout
	local CARD_PIXEL_SIZE = 108 -- Square card size in pixels (panel height 120 - padding 12)
	local GAP_PIXELS = 6 -- Gap between cards
	local PADDING_PIXELS = 16 -- Total horizontal padding (8 each side)
	
	-- Calculate number of elements (reactive)
	local cardCount = scope:Computed(function(use)
		local plants = use(equippedPlants)
		return #plants + 1 -- +1 for shovel button
	end)
	
	-- Panel width in pixels = padding + (cards * size) + ((cards-1) * gap)
	local panelWidthPixels = scope:Computed(function(use)
		local count = use(cardCount)
		return PADDING_PIXELS + (CARD_PIXEL_SIZE * count) + (GAP_PIXELS * (count - 1))
	end)
	
	-- Build SeedCard array with reactive mutations using ForValues
	-- ForValues processor receives (use, innerScope, value) - innerScope has same methods as parent
	local seedCardsArray = scope:ForValues(equippedPlants, function(use, innerScope, plantType)
		-- Get layout order from the current plants array
		local currentPlants = use(equippedPlants)
		local index = table.find(currentPlants, plantType) or 0
		
		-- Create a Computed that reactively extracts mutations for this specific plant
		local plantMutations = innerScope:Computed(function(use2)
			local allMutations = use2(equippedMutations)
			return allMutations[plantType] or {}
		end)
		
		-- Wrapper frame for each card slot (square, full height)
		return innerScope:New("Frame") {
			Name = `CardSlot_{plantType}`,
			Size = UDim2.fromScale(1, 1), -- Full size, aspect handled by SeedCard
			BackgroundTransparency = 1,
			LayoutOrder = index,
			
			[Children] = {
				-- Force square size based on height
				innerScope:New("UIAspectRatioConstraint") {
					AspectRatio = 1,
					DominantAxis = Enum.DominantAxis.Height,
				},
				
				SeedCard({
					Scope = innerScope,
					PlantType = plantType,
					LayoutOrder = index,
					EquippedMutations = plantMutations,
					OnClick = function()
						onPlantSelect(plantType)
					end,
				}),
			},
		}
	end)
	
	return ToonPanel({
		Scope = scope,
		Size = scope:Computed(function(use)
			return UDim2.new(0, use(panelWidthPixels), 1, 0) -- Pixel width, full height
		end),
		Position = position,
		AnchorPoint = anchorPoint,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
		
		[Children] = {
			-- Size constraints for panel
			scope:New("UISizeConstraint") {
				MinSize = Vector2.new(150, 80),
				MaxSize = Vector2.new(900, 120),
			},
			
			-- Padding inside panel (fixed pixels for consistency)
			scope:New("UIPadding") {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},
			
			-- List layout for cards (simpler than grid)
			scope:New("UIListLayout") {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6), -- 6px gap between cards
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			
			-- Seed cards
			seedCardsArray,
			
			-- Shovel button slot (square, full height)
			scope:New("Frame") {
				Name = "ShovelSlot",
				Size = UDim2.fromScale(1, 1), -- Full size, aspect handled by content
				BackgroundTransparency = 1,
				LayoutOrder = 999, -- Always last
				
				[Children] = {
					-- Force square size based on height
					scope:New("UIAspectRatioConstraint") {
						AspectRatio = 1,
						DominantAxis = Enum.DominantAxis.Height,
					},
					
					ShovelButton({
						Scope = scope,
						LayoutOrder = 999,
					}),
				},
			},
		},
	})
end

return SeedBank
