--!strict
--[[
	SeedBank.luau - Horizontal plant deck bar with "Toon Pop" style (Lobby - Responsive)
	
	Organism component displaying the player's equipped plants.
	Uses ToonPanel as container and SeedCard for each plant.
	
	Handles click to show tooltip.
	Fully responsive using Scale-based sizing.
	
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ToonPanel = require(Shared.ui.components.atoms.ToonPanel)

local Molecules = script.Parent.Parent.molecules
local SeedCard = require(Molecules.SeedCard)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local peek = Fusion.peek

export type SeedBankProps = {
	Scope: Fusion.Scope<any>,
	EquippedPlants: any, -- Can be {string} or Fusion.Value<{string}>
	EquippedMutations: any, -- Fusion.Value<{[string]: {string}}>
	OnPlantClick: (plantType: string, mutations: {string}) -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	LayoutOrder: number?,
}

--[[
	SeedBank Component (Lobby - Responsive)
	
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
	local onPlantClick = props.OnPlantClick
	
	local position = props.Position or UDim2.fromScale(0.5, 0.98)
	local anchorPoint = props.AnchorPoint or Vector2.new(0.5, 1)
	local zIndex = props.ZIndex or 1
	local layoutOrder = props.LayoutOrder or 0
	
	-- Calculate panel width based on number of plants (reactive)
	local panelWidthScale = scope:Computed(function(use)
		local plants = use(equippedPlants)
		local cardCount = math.max(1, #plants)
		-- Each card takes ~5% of screen width, plus padding
		local cardWidth = 0.055
		local padding = 0.01
		local containerPadding = 0.02
		return (cardWidth * cardCount) + (padding * (cardCount - 1)) + containerPadding
	end)
	
	-- Build SeedCard array with reactive mutations using ForValues
	-- Fusion 0.3: scope:ForValues(input, function(use, scope, value))
	local seedCardsArray = scope:ForValues(equippedPlants, function(use, innerScope, plantType)
		-- Create a Computed that reactively extracts mutations for this specific plant
		local plantMutations = innerScope:Computed(function(use2)
			local allMutations = use2(equippedMutations)
			return allMutations[plantType] or {}
		end)
		
		-- Wrapper frame for each card slot
		return innerScope:New("Frame") {
			Name = `CardSlot_{plantType}`,
			Size = UDim2.fromScale(1, 1), -- Will be sized by UIGridLayout
			BackgroundTransparency = 1,
			
			[Children] = {
				SeedCard({
					Scope = innerScope,
					PlantType = plantType,
					EquippedMutations = plantMutations,
					OnClick = function()
						local mutations = peek(plantMutations)
						onPlantClick(plantType, mutations)
					end,
				}),
			},
		}
	end)
	
	return ToonPanel({
		Scope = scope,
		Size = scope:Computed(function(use)
			return UDim2.fromScale(use(panelWidthScale), 0.09)
		end),
		Position = position,
		AnchorPoint = anchorPoint,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
		
		[Children] = {
			-- Size constraints for panel
			scope:New("UISizeConstraint") {
				MinSize = Vector2.new(100, 60),
				MaxSize = Vector2.new(700, 120),
			},
			
			-- Padding inside panel (percentage-based)
			scope:New("UIPadding") {
				PaddingLeft = UDim.new(0.02, 0),
				PaddingRight = UDim.new(0.02, 0),
				PaddingTop = UDim.new(0.1, 0),
				PaddingBottom = UDim.new(0.1, 0),
			},
			
			-- Grid layout for cards (maintains aspect ratio)
			scope:New("UIGridLayout") {
				CellSize = UDim2.fromScale(0.15, 1), -- Cells sized relative to panel
				CellPadding = UDim2.fromScale(0.02, 0),
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			
			-- Seed cards (reactive array from ForValues)
			seedCardsArray,
		},
	})
end

return SeedBank
