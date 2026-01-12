--!strict
--[[
	SeedCard.luau - Plant card for Lobby deck preview (Responsive)
	
	Molecule component representing a plant in the deck bar.
	Shows plant image, cost badge, mutation icons, and state overlays.
	
	Uses shared PlantViewport atom for 3D model display.
	Fully responsive using Scale-based sizing.
	
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local Theme = require(Shared.ui.design.Theme)
local PlantViewport = require(Shared.ui.components.atoms.PlantViewport)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

export type SeedCardProps = {
	Scope: Fusion.Scope<any>,
	PlantType: string,
	LayoutOrder: number?,
	EquippedMutations: any, -- Can be {string} or Computed<{string}>
	OnClick: () -> (),
}

-- Colors
local GOLD_BORDER = Color3.fromHex("#FFD700")

--[[
	SeedCard Component (Lobby version - Responsive)
	
	A clickable plant card with cost badge and mutation icons.
	Shows tooltip on click instead of selection.
	Size is determined by parent container.
	
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
		Size = UDim2.fromScale(1, 0.85),
		Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		CameraFOV = 35,
		CameraDistance = 1.5,
		CameraHeight = 0.2,
	})
	
	-- Internal state
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)
	
	-- Has mutations (for gold border) - reactive
	local hasMutations = scope:Computed(function(use)
		local mutations = use(equippedMutations)
		return mutations and #mutations > 0
	end)
	
	-- Border color based on mutations
	local borderColor = scope:Computed(function(use)
		if use(hasMutations) then
			return GOLD_BORDER
		end
		return Theme.Colors.Surface.Stroke :: Color3
	end)
	
	-- Border thickness
	local borderThickness = Theme.Layout.StrokeThickness
	
	-- Press animation (shadow offset as percentage)
	local pressOffset = scope:Spring(scope:Computed(function(use)
		return if use(isPressed) then 0.06 else 0
	end), 40, 0.7)
	
	-- Scale animation for hover
	local hoverScale = scope:Spring(scope:Computed(function(use)
		if use(isPressed) then return 0.95 end
		if use(isHovered) then return 1.05 end
		return 1
	end), 35, 0.7)
	
	local cardColor = Theme.Colors.Surface.Main
	local shadowColor = Theme.Colors.Surface.Shadow
	
	-- Build mutation icons reactively
	local mutationIconsComputed = scope:Computed(function(use)
		local mutations = use(equippedMutations) or {}
		local icons: {any} = {}
		
		for i, mutationId in mutations do
			local mutation = MutationData.Get(mutationId)
			if mutation and i <= 3 then -- Max 3 icons
				table.insert(icons, scope:New("Frame") {
					Name = `Mutation_{mutationId}`,
					Size = UDim2.fromScale(0.22, 1), -- Relative to icon row
					BackgroundColor3 = mutation.Color,
					BackgroundTransparency = 0.3,
					LayoutOrder = i,
					
					[Children] = {
						scope:New("UIAspectRatioConstraint") {
							AspectRatio = 1,
						},
						scope:New("UICorner") {
							CornerRadius = UDim.new(0.2, 0),
						},
						scope:New("TextLabel") {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = mutation.Icon or "?",
							TextScaled = true,
							Font = Enum.Font.GothamBold,
							TextColor3 = Color3.new(1, 1, 1),
							
							[Children] = {
								scope:New("UITextSizeConstraint") {
									MaxTextSize = 14,
									MinTextSize = 6,
								},
							},
						},
					},
				})
			end
		end
		
		return icons
	end)
	
	return scope:New("Frame") {
		Name = `SeedCard_{plantType}`,
		Size = UDim2.fromScale(1, 1), -- Size determined by parent
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		
		[Children] = {
			-- Aspect ratio constraint (square)
			scope:New("UIAspectRatioConstraint") {
				AspectRatio = 1,
			},
			
			-- Scale container for hover animation
			scope:New("Frame") {
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				
				[Children] = {
					scope:New("UIScale") { Scale = hoverScale },
					
					-- Shadow Layer (6% offset)
					scope:New("Frame") {
						Name = "Shadow",
						Size = UDim2.fromScale(1, 0.94),
						Position = UDim2.fromScale(0, 0.06),
						BackgroundColor3 = shadowColor,
						ZIndex = 1,
						
						[Children] = {
							scope:New("UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
						},
					},
					
					-- Surface Layer (interactive)
					scope:New("TextButton") {
						Name = "Surface",
						Size = scope:Computed(function(use)
							local offset = use(pressOffset)
							return UDim2.fromScale(1, 0.94 - offset)
						end),
						Position = scope:Computed(function(use)
							return UDim2.fromScale(0, use(pressOffset))
						end),
						BackgroundColor3 = cardColor,
						AutoButtonColor = false,
						Text = "",
						ZIndex = 2,
						
						[OnEvent("MouseButton1Down")] = function()
							isHovered:set(true)
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
							scope:New("UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
							
							-- Dynamic border (gold for mutations)
							scope:New("UIStroke") {
								Color = borderColor,
								Thickness = borderThickness,
							},
							
							-- 3D Plant Model Preview
							viewportFrame,
							
							-- Cost Badge (bottom-right pill)
							scope:New("Frame") {
								Name = "CostBadge",
								Size = UDim2.fromScale(0.5, 0.3),
								Position = UDim2.fromScale(0.95, 0.95),
								AnchorPoint = Vector2.new(1, 1),
								BackgroundColor3 = Color3.fromHex("#FFD700"),
								ZIndex = 5,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = UDim.new(0.5, 0),
									},
									scope:New("UIStroke") {
										Color = Color3.new(0, 0, 0),
										Thickness = 1,
										Transparency = 0.5,
									},
									scope:New("TextLabel") {
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = tostring(cost),
										TextColor3 = Color3.new(0, 0, 0),
										Font = Theme.Typography.Fonts.Body,
										TextScaled = true,
										ZIndex = 6,
										
										[Children] = {
											scope:New("UITextSizeConstraint") {
												MaxTextSize = 14,
												MinTextSize = 8,
											},
										},
									},
								},
							},
							
							-- Mutation Icons (bottom-left row) - reactive frame
							scope:Computed(function(use)
								local icons = use(mutationIconsComputed)
								if #icons > 0 then
									return scope:New("Frame") {
										Name = "MutationIcons",
										Size = UDim2.fromScale(0.7, 0.22),
										Position = UDim2.fromScale(0.05, 0.95),
										AnchorPoint = Vector2.new(0, 1),
										BackgroundTransparency = 1,
										ZIndex = 5,
										
										[Children] = {
											scope:New("UIListLayout") {
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Left,
												VerticalAlignment = Enum.VerticalAlignment.Bottom,
												Padding = UDim.new(0.05, 0),
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
