--!strict
--[[
	SeedCard.luau - Plant card for Lobby deck preview
	
	Molecule component representing a plant in the deck bar.
	Shows plant image, cost badge, mutation icons, and state overlays.
	
	Uses shared PlantViewport atom for 3D model display.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local Theme = require(Shared.ui.design.Theme)
local PlantViewport = require(Shared.ui.components.atoms.PlantViewport)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local peek = Fusion.peek

-- Constants
local CARD_SIZE = 70
local SHADOW_OFFSET = 4
local MUTATION_ICON_SIZE = 16

-- Colors
local GOLD_BORDER = Color3.fromHex("#FFD700")

export type SeedCardProps = {
	Scope: Fusion.Scope<any>,
	PlantType: string,
	LayoutOrder: number?,
	EquippedMutations: any, -- Can be {string} or Computed<{string}>
	OnClick: () -> (),
}

--[[
	SeedCard Component (Lobby version)
	
	A clickable plant card with cost badge and mutation icons.
	Shows tooltip on click instead of selection.
	
	@param props SeedCardProps
	@return Frame
]]
local function SeedCard(props: SeedCardProps): Frame
	local scope = props.Scope
	local plantType = props.PlantType
	local equippedMutations = props.EquippedMutations
	local layoutOrder = props.LayoutOrder or 0
	
	-- Get plant stats
	local plantStats = PlantData.GetStats(plantType)
	local cost = if plantStats then plantStats.Cost else 100
	
	-- Create ViewportFrame using shared PlantViewport atom
	local viewportFrame = PlantViewport.CreateWithScope(scope, {
		PlantType = plantType,
		Size = UDim2.new(1, 0, 0.85, 0),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		CameraFOV = 35,
		CameraDistance = 1.5,
		CameraHeight = 0.2,
	})
	
	-- Internal state
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	
	-- Has mutations (for gold border) - reactive
	local hasMutations = Computed(scope, function(use)
		local mutations = use(equippedMutations)
		return mutations and #mutations > 0
	end)
	
	-- Border color based on mutations
	local borderColor = Computed(scope, function(use)
		if use(hasMutations) then
			return GOLD_BORDER
		end
		return Theme.Colors.Surface.Stroke :: Color3
	end)
	
	-- Border thickness
	local borderThickness = Theme.Layout.StrokeThickness
	
	-- Press animation
	local targetOffset = Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	local pressOffset = Spring(scope, targetOffset, 40, 0.7)
	
	-- Scale animation for hover
	local targetScale = Computed(scope, function(use)
		if use(isPressed) then return 0.95 end
		if use(isHovered) then return 1.05 end
		return 1
	end)
	local hoverScale = Spring(scope, targetScale, 35, 0.7)
	
	local cardColor = Theme.Colors.Surface.Main
	local shadowColor = Theme.Colors.Surface.Shadow
	
	-- Build mutation icons reactively
	local mutationIconsComputed = Computed(scope, function(use)
		local mutations = use(equippedMutations) or {}
		local icons: {any} = {}
		
		for i, mutationId in mutations do
			local mutation = MutationData.Get(mutationId)
			if mutation and i <= 3 then -- Max 3 icons
				table.insert(icons, New(scope, "TextLabel") {
					Name = `Mutation_{mutationId}`,
					Size = UDim2.fromOffset(MUTATION_ICON_SIZE, MUTATION_ICON_SIZE),
					BackgroundColor3 = mutation.Color,
					BackgroundTransparency = 0.3,
					Text = mutation.Icon or "?",
					TextSize = 12,
					Font = Enum.Font.GothamBold,
					TextColor3 = Color3.new(1, 1, 1),
					LayoutOrder = i,
					
					[Children] = {
						New(scope, "UICorner") {
							CornerRadius = UDim.new(0, 4),
						},
					},
				})
			end
		end
		
		return icons
	end)
	
	return New(scope, "Frame") {
		Name = `SeedCard_{plantType}`,
		Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		
		[Children] = {
			-- Scale container for hover animation
			New(scope, "Frame") {
				Size = UDim2.new(1, 0, 1, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundTransparency = 1,
				
				[Children] = {
					New(scope, "UIScale") { Scale = hoverScale },
					
					-- Aspect ratio constraint (square)
					New(scope, "UIAspectRatioConstraint") {
						AspectRatio = 1,
						AspectType = Enum.AspectType.ScaleWithParentSize,
					},
					
					-- Shadow Layer
					New(scope, "Frame") {
						Name = "Shadow",
						Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
						Position = UDim2.fromOffset(0, SHADOW_OFFSET),
						BackgroundColor3 = shadowColor,
						ZIndex = 1,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
						},
					},
					
					-- Surface Layer (interactive)
					New(scope, "TextButton") {
						Name = "Surface",
						Size = Computed(scope, function(use)
							local offset = use(pressOffset)
							return UDim2.new(1, 0, 1, -SHADOW_OFFSET - offset)
						end),
						Position = Computed(scope, function(use)
							return UDim2.fromOffset(0, use(pressOffset))
						end),
						BackgroundColor3 = cardColor,
						AutoButtonColor = false,
						Text = "",
						ZIndex = 2,
						
						[OnEvent("MouseButton1Down")] = function()
							isPressed:set(true)
						end,
						
						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							if peek(isHovered) then
								props.OnClick()
							end
						end,
						
						[OnEvent("MouseEnter")] = function()
							isHovered:set(true)
						end,
						
						[OnEvent("MouseLeave")] = function()
							isHovered:set(false)
							isPressed:set(false)
						end,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
							
							-- Dynamic border (gold for mutations)
							New(scope, "UIStroke") {
								Color = borderColor,
								Thickness = borderThickness,
							},
							
							-- 3D Plant Model Preview (created imperatively)
							viewportFrame,
							
							-- Mutation Icons (bottom-left row) - reactive frame
							Computed(scope, function(use)
								local icons = use(mutationIconsComputed)
								if #icons > 0 then
									return New(scope, "Frame") {
										Name = "MutationIcons",
										Size = UDim2.new(1, -4, 0, MUTATION_ICON_SIZE),
										Position = UDim2.new(0, 2, 1, -2),
										AnchorPoint = Vector2.new(0, 1),
										BackgroundTransparency = 1,
										ZIndex = 5,
										
										[Children] = {
											New(scope, "UIListLayout") {
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Left,
												VerticalAlignment = Enum.VerticalAlignment.Bottom,
												Padding = UDim.new(0, 2),
											},
											table.unpack(icons),
										},
									}
								else
									return nil
								end
							end),
						},
					},
				},
			},
		},
	}
end

return SeedCard
