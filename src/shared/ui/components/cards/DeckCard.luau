--!strict
--[[
	DeckCard.luau - Plant card for deck builder selection
	
	Wrapper around PlantCard for deck builder specific functionality.
	Uses Scale mode for responsive grid layouts.
	Handles: selection state, mutations display, locked state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local PlantCard = require(Shared.ui.components.cards.PlantCard)

-- Fusion primitives
local Children = Fusion.Children

-- Constants
local MUTATION_ICON_SIZE = 18

-- Colors
local GOLD_BORDER = Color3.fromHex("#FFD700")
local GREEN_SELECTED = Color3.fromHex("#4CAF50")

export type DeckCardProps = {
	Scope: Fusion.Scope<any>,
	PlantType: string,
	Deck: any, -- Fusion.Value<{string}> - the current deck array
	IsLocked: boolean?,
	EquippedMutations: { string }?,
	OnToggle: () -> (),
	LayoutOrder: number?,
}

local function DeckCard(props: DeckCardProps): Frame
	local scope = props.Scope
	local plantType = props.PlantType
	local isLocked = props.IsLocked or false
	local mutations = props.EquippedMutations or {}
	local hasMutations = #mutations > 0

	-- Get plant stats
	local plantStats = PlantData.GetStats(plantType)
	local sunCost = if plantStats then plantStats.Cost else 100

	-- Compute isInDeck from deck array
	local isInDeck = scope:Computed(function(use)
		local deck = use(props.Deck)
		return table.find(deck, plantType) ~= nil
	end)

	-- Border color based on state
	local borderColor = scope:Computed(function(use)
		if isLocked then
			return Theme.Colors.Surface.Shadow
		end
		if use(isInDeck) then
			return GREEN_SELECTED
		end
		if hasMutations then
			return GOLD_BORDER
		end
		return Theme.Colors.Surface.Stroke :: Color3
	end)

	-- Background color based on state
	local bgColor = scope:Computed(function(use)
		if isLocked then
			return Color3.fromRGB(80, 80, 80)
		end
		if use(isInDeck) then
			return Color3.fromRGB(200, 240, 200)
		end
		return Theme.Colors.Surface.Main
	end)

	-- Build mutation icons overlay
	local mutationOverlay = nil
	if hasMutations then
		local mutationIcons: { any } = {}
		for i, mutType in mutations do
			if i > 3 then break end -- Max 3 visible
			local mutData = MutationData.Get(mutType)
			table.insert(mutationIcons, scope:New("Frame")({
				Name = "MutationIcon" .. i,
				Size = UDim2.fromOffset(MUTATION_ICON_SIZE, MUTATION_ICON_SIZE),
				BackgroundColor3 = if mutData then mutData.Color else GOLD_BORDER,
				ZIndex = 6,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),
					scope:New("UIStroke")({
						Color = Color3.new(1, 1, 1),
						Thickness = 1,
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = if mutData then mutData.Icon else "✨",
						TextSize = 10,
						Font = Enum.Font.GothamBold,
					}),
				},
			}))
		end

		mutationOverlay = scope:New("Frame")({
			Name = "MutationIcons",
			Size = UDim2.fromOffset(#mutationIcons * (MUTATION_ICON_SIZE + 2), MUTATION_ICON_SIZE),
			Position = UDim2.new(0, 4, 1, -24),
			BackgroundTransparency = 1,
			ZIndex = 25,

			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 2),
				}),
				table.unpack(mutationIcons),
			},
		})
	end

	-- Use PlantCard with Scale mode
	local card = PlantCard({
		Scope = scope,
		PlantType = plantType,
		Size = UDim2.fromScale(1, 1), -- Fill grid cell
		UseScale = true, -- Use Scale-based layout
		ShadowOffsetScale = 0.03,
		IsLocked = isLocked,
		
		-- Styling
		BackgroundColor3 = bgColor,
		BorderColor = borderColor,
		
		-- Viewport with Scale sizing
		Viewport = {
			Size = UDim2.new(1, -8, 0.45, 0),
			Position = UDim2.fromScale(0.5, 0.05),
			CameraFOV = 35,
			CameraDistance = 1.6,
			CameraHeight = 0.2,
		},
		
		-- Name with Scale sizing
		Name = {
			Show = true,
			Size = UDim2.new(1, -8, 0.12, 0),
			Position = UDim2.fromScale(0.02, 0.52),
			TextScaled = true,
			TextSize = 14, -- Max text size for constraint
		},
		
		-- Category below name
		Category = {
			Show = true,
			Position = UDim2.fromScale(0.5, 0.66),
		},
		
		-- Sun cost below category
		SunCost = {
			Show = true,
			Value = sunCost,
			Size = UDim2.fromScale(0.5, 0.12),
			Position = UDim2.fromScale(0.5, 0.80),
		},
		
		-- Selected badge (reactive - shows when in deck)
		TopBadge = scope:Computed(function(use)
			if use(isInDeck) then
				return {
					Show = true,
					Icon = "Check",
					BackgroundColor3 = GREEN_SELECTED,
				}
			end
			return nil
		end),
		
		-- Events
		OnClick = function()
			if not isLocked then
				props.OnToggle()
			end
		end,
		
		LayoutOrder = props.LayoutOrder,
	})

	-- If we have mutations, wrap the card with overlay
	if mutationOverlay then
		return scope:New("Frame")({
			Name = plantType,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder or 0,

			[Children] = {
				card,
				mutationOverlay,
			},
		})
	end

	return card
end

return DeckCard
