--!strict
--[[
	DeckBar.luau - Horizontal bar with deck slots (Fusion 0.3)
	
	Displays 6 deck slots in a Toon Pop styled container.
	Features:
	- Shadow + Main frame pattern
	- Horizontally centered slots
	- Reactive to deck changes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local CardsComponents = Shared.ui.components.cards
local DeckSlot = require(CardsComponents.DeckSlot)

local Children = Fusion.Children

-- Constants
local MAX_DECK_SIZE = 6

export type DeckBarProps = {
	Scope: Fusion.Scope<any>,
	Deck: any, -- Fusion.Value<{string}> or Fusion.Computed<{string}>
	PlantMutations: any?, -- Fusion.Value<{[string]: {string}}> or nil
	OnRemovePlant: (index: number) -> (),
	Size: UDim2?, -- Default: UDim2.fromScale(1, 0.14)
	Position: UDim2?, -- Default: UDim2.fromScale(0.5, 0.11)
	AnchorPoint: Vector2?, -- Default: Vector2.new(0.5, 0)
	ShadowOffset: number?, -- Default: 0.05 (5% of height)
}

local function DeckBar(props: DeckBarProps): Frame
	local scope = props.Scope
	local shadowOffset = props.ShadowOffset or 0.05

	return scope:New("Frame")({
		Name = "DeckBar",
		Size = props.Size or UDim2.fromScale(1, 0.14),
		Position = props.Position or UDim2.fromScale(0.5, 0.11),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		BackgroundTransparency = 1,

		[Children] = {
			-- Shadow
			scope:New("Frame")({
				Name = "Shadow",
				Size = UDim2.fromScale(1, 1 - shadowOffset),
				Position = UDim2.fromScale(0.5, shadowOffset),
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
				Size = UDim2.fromScale(1, 1 - shadowOffset),
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
						Name = "SlotsContainer",
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
								local deck = use(props.Deck)
								local mutations = if props.PlantMutations
									then use(props.PlantMutations)
									else {}
								local slots = {}
								for i = 1, MAX_DECK_SIZE do
									local plantType = deck[i]
									table.insert(
										slots,
										DeckSlot({
											Scope = scope,
											Index = i,
											PlantType = plantType,
											Mutations = if plantType then mutations[plantType] else nil,
											OnRemove = function()
												props.OnRemovePlant(i)
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
	})
end

return DeckBar
