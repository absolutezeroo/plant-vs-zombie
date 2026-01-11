--!strict
--[[
	DeckCard.luau - Plant card for deck builder selection
	
	Atom component for selecting/deselecting plants in deck builder.
	Uses PlantViewport for 3D plant display.
	"Toon Pop" style consistent with other lobby atoms.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local PlantViewport = require(Shared.ui.components.atoms.PlantViewport)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Constants
local CARD_WIDTH = 100
local CARD_HEIGHT = 130
local SHADOW_OFFSET = 4
local VIEWPORT_HEIGHT = 60
local MUTATION_ICON_SIZE = 20

-- Colors
local GOLD_BORDER = Color3.fromHex("#FFD700")
local GREEN_SELECTED = Color3.fromHex("#4CAF50")

export type DeckCardProps = {
	Scope: Fusion.Scope<any>,
	PlantType: string,
	IsInDeck: any, -- Fusion.Value<boolean> or Computed
	IsLocked: boolean?,
	EquippedMutations: {string}?,
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
	
	-- Create 3D plant viewport (only if not locked)
	local plantViewport: ViewportFrame? = nil
	if not isLocked then
		plantViewport = PlantViewport.CreateWithScope(scope, {
			PlantType = plantType,
			Size = UDim2.new(1, -8, 0, VIEWPORT_HEIGHT),
			Position = UDim2.new(0.5, 0, 0, 8),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 3,
			CameraFOV = 35,
			CameraDistance = 1.6,
			CameraHeight = 0.2,
		})
	end
	
	-- State
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	
	-- Animations
	local targetScale = Computed(scope, function(use)
		if isLocked then return 1 end
		if use(isPressed) then return 0.95 end
		if use(isHovered) then return 1.03 end
		return 1
	end)
	local hoverScale = Spring(scope, targetScale, 35, 0.7)
	
	local targetOffset = Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	local pressOffset = Spring(scope, targetOffset, 40, 0.7)
	
	-- Border color based on state
	local borderColor = Computed(scope, function(use)
		if isLocked then return Theme.Colors.Surface.Shadow end
		if use(props.IsInDeck) then return GREEN_SELECTED end
		if hasMutations then return GOLD_BORDER end
		if use(isHovered) then return Theme.Colors.Action.Main end
		return Theme.Colors.Surface.Stroke :: Color3
	end)
	
	-- Background color
	local bgColor = Computed(scope, function(use)
		if isLocked then return Color3.fromRGB(80, 80, 80) end
		if use(props.IsInDeck) then return Color3.fromRGB(200, 240, 200) end
		return Theme.Colors.Surface.Main
	end)
	
	-- Build mutation icons
	local mutationIcons: {any} = {}
	for i, mutType in mutations do
		if i > 3 then break end -- Max 3 visible
		local mutData = MutationData.Get(mutType)
		table.insert(mutationIcons, New(scope, "Frame") {
			Name = "MutationIcon" .. i,
			Size = UDim2.fromOffset(MUTATION_ICON_SIZE, MUTATION_ICON_SIZE),
			BackgroundColor3 = if mutData then mutData.Color else GOLD_BORDER,
			ZIndex = 6,
			
			[Children] = {
				New(scope, "UICorner") {
					CornerRadius = UDim.new(0.5, 0),
				},
				New(scope, "UIStroke") {
					Color = Color3.new(1, 1, 1),
					Thickness = 1,
				},
				New(scope, "TextLabel") {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = if mutData then mutData.Icon else "✨",
					TextSize = 12,
				},
			},
		})
	end
	
	return New(scope, "Frame") {
		Name = plantType,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Scale container
			New(scope, "Frame") {
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				
				[Children] = {
					New(scope, "UIScale") { Scale = hoverScale },
					
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
					
					-- Main card
					New(scope, "Frame") {
						Name = "Main",
						Size = Computed(scope, function(use)
							local offset = use(pressOffset)
							return UDim2.new(1, 0, 1, -SHADOW_OFFSET - offset)
						end),
						Position = Computed(scope, function(use)
							return UDim2.fromOffset(0, use(pressOffset))
						end),
						BackgroundColor3 = bgColor,
						ZIndex = 2,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
							
							New(scope, "UIStroke") {
								Color = borderColor,
								Thickness = Theme.Layout.StrokeThickness,
							},
							
							-- Lock overlay
							isLocked and New(scope, "Frame") {
								Name = "LockOverlay",
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundColor3 = Color3.new(0, 0, 0),
								BackgroundTransparency = 0.5,
								ZIndex = 10,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									New(scope, "TextLabel") {
										Size = UDim2.new(1, 0, 1, 0),
										BackgroundTransparency = 1,
										Text = "🔒",
										TextSize = 32,
									},
								},
							} or nil,
							
							-- Selected checkmark
							Computed(scope, function(use)
								if not use(props.IsInDeck) then return nil end
								return New(scope, "Frame") {
									Name = "SelectedBadge",
									Size = UDim2.fromOffset(24, 24),
									Position = UDim2.new(1, -6, 0, 6),
									AnchorPoint = Vector2.new(1, 0),
									BackgroundColor3 = GREEN_SELECTED,
									ZIndex = 8,
									
									[Children] = {
										New(scope, "UICorner") {
											CornerRadius = UDim.new(0.5, 0),
										},
										New(scope, "TextLabel") {
											Size = UDim2.new(1, 0, 1, 0),
											BackgroundTransparency = 1,
											Text = "✓",
											TextColor3 = Color3.new(1, 1, 1),
											TextSize = 14,
											Font = Enum.Font.GothamBold,
										},
									},
								}
							end),
							
							-- 3D Plant viewport
							plantViewport,
							
							-- Plant name
							New(scope, "TextLabel") {
								Name = "PlantName",
								Size = UDim2.new(1, -8, 0, 18),
								Position = UDim2.new(0, 4, 0, VIEWPORT_HEIGHT + 10),
								BackgroundTransparency = 1,
								Text = plantType,
								TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
								TextSize = 12,
								Font = Theme.Typography.Fonts.Title,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 3,
							},
							
							-- Sun cost pill
							New(scope, "Frame") {
								Name = "SunCost",
								Size = UDim2.fromOffset(50, 18),
								Position = UDim2.new(0.5, 0, 0, VIEWPORT_HEIGHT + 30),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Warning.Main,
								ZIndex = 4,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = UDim.new(0.5, 0),
									},
									New(scope, "TextLabel") {
										Size = UDim2.new(1, 0, 1, 0),
										BackgroundTransparency = 1,
										Text = `☀️ {sunCost}`,
										TextColor3 = Color3.fromRGB(80, 50, 20),
										TextSize = 10,
										Font = Enum.Font.GothamBold,
									},
								},
							},
							
							-- Mutation icons (bottom-left)
							hasMutations and New(scope, "Frame") {
								Name = "MutationIcons",
								Size = UDim2.fromOffset(#mutationIcons * (MUTATION_ICON_SIZE + 2), MUTATION_ICON_SIZE),
								Position = UDim2.new(0, 4, 1, -24),
								BackgroundTransparency = 1,
								ZIndex = 5,
								
								[Children] = {
									New(scope, "UIListLayout") {
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 2),
									},
									table.unpack(mutationIcons),
								},
							} or nil,
							
							-- Click handler
							New(scope, "TextButton") {
								Name = "ClickHandler",
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 20,
								
								[OnEvent("Activated")] = function()
									if not isLocked then
										props.OnToggle()
									end
								end,
								
								[OnEvent("MouseEnter")] = function()
									if not isLocked then isHovered:set(true) end
								end,
								
								[OnEvent("MouseLeave")] = function()
									isHovered:set(false)
									isPressed:set(false)
								end,
								
								[OnEvent("MouseButton1Down")] = function()
									if not isLocked then isPressed:set(true) end
								end,
								
								[OnEvent("MouseButton1Up")] = function()
									isPressed:set(false)
								end,
							},
						},
					},
				},
			},
		},
	}
end

return DeckCard
