--!strict
--[[
	SeedBank.luau - Horizontal plant deck bar with "Toon Pop" style
	
	Organism component displaying the player's equipped plants.
	Uses ToonPanel as container and SeedCard for each plant.
	
	Handles plant selection and passes mutation data to cards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Path: client/ui/components/organisms/SeedBank.luau
local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

local Atoms = script.Parent.Parent.atoms
local ToonPanel = require(Atoms.ToonPanel)

local Molecules = script.Parent.Parent.molecules
local SeedCard = require(Molecules.SeedCard)
local ShovelButton = require(Molecules.ShovelButton)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local ForValues = Fusion.ForValues
local Computed = Fusion.Computed
local Value = Fusion.Value

-- Constants
local CARD_SIZE = 70
local CARD_PADDING = 5
local PANEL_PADDING = 10
local PANEL_HEIGHT = CARD_SIZE + PANEL_PADDING * 2 + 4 -- +4 for shadow

export type SeedBankProps = {
	Scope: Fusion.Scope<any>,
	EquippedPlants: any, -- Can be {string} or Fusion.Value<{string}>
	EquippedMutations: any, -- Fusion.Value<{[string]: {string}}>
	OnPlantSelect: (plantType: string) -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,	
	LayoutOrder: number?,}

--[[
	SeedBank Component
	
	A horizontal bar containing SeedCards for equipped plants.
	Wrapped in a ToonPanel for consistent styling.
	
	@param props SeedBankProps
	@return Frame
]]
local function SeedBank(props: SeedBankProps): Frame
	local scope = props.Scope
	local equippedPlants = props.EquippedPlants
	local equippedMutations = props.EquippedMutations
	local onPlantSelect = props.OnPlantSelect
	
	local position = props.Position or UDim2.new(0.5, 0, 0, 10)
	local anchorPoint = props.AnchorPoint or Vector2.new(0.5, 0)
	local zIndex = props.ZIndex or 1
	local layoutOrder = props.LayoutOrder or 0
	
	-- Calculate panel width based on number of plants + shovel button (reactive)
	local panelWidth = Computed(scope, function(use)
		local plants = use(equippedPlants)
		local cardCount = #plants + 1 -- +1 for shovel button
		return (CARD_SIZE * cardCount) + (CARD_PADDING * (cardCount - 1)) + (PANEL_PADDING * 2)
	end)
	
	-- Build SeedCard array with reactive mutations using ForValues
	local seedCardsArray = ForValues(scope, equippedPlants, function(use, scope, plantType, index)
		-- Create a Computed that reactively extracts mutations for this specific plant
		local plantMutations = Computed(scope, function(use)
			local allMutations = use(equippedMutations)
			return allMutations[plantType] or {}
		end)
		
		return SeedCard({
			Scope = scope,
			PlantType = plantType,
			LayoutOrder = index,
			EquippedMutations = plantMutations,
			OnClick = function()
				onPlantSelect(plantType)
			end,
		})
	end)
	
	return ToonPanel({
		Scope = scope,
		Size = Computed(scope, function(use)
			return UDim2.fromOffset(use(panelWidth), PANEL_HEIGHT)
		end),
		Position = position,
		AnchorPoint = anchorPoint,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
		
		[Children] = {
			-- Padding inside panel
			New(scope, "UIPadding") {
				PaddingLeft = UDim.new(0, PANEL_PADDING),
				PaddingRight = UDim.new(0, PANEL_PADDING),
				PaddingTop = UDim.new(0, PANEL_PADDING),
				PaddingBottom = UDim.new(0, PANEL_PADDING),
			},
			
			-- Horizontal layout for cards
			New(scope, "UIListLayout") {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, CARD_PADDING),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			
			-- Seed cards (reactive array from ForValues)
			seedCardsArray,
			
			-- Shovel button (at the end)
			ShovelButton({
				Scope = scope,
				LayoutOrder = 999, -- Always last
			}),
		},
	})
end

return SeedBank
