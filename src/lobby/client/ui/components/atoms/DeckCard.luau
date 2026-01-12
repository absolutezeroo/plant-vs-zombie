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
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Constants
local SHADOW_OFFSET_SCALE = 0.03
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
			Size = UDim2.new(1, -8, 0.45, 0),
			Position = UDim2.new(0.5, 0, 0.05, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 3,
			CameraFOV = 35,
			CameraDistance = 1.6,
			CameraHeight = 0.2,
		})
	end
	
	-- State
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)
	
	-- Animations
	local targetScale = scope:Computed(function(use)
		if isLocked then return 1 end
		if use(isPressed) then return 0.95 end
		if use(isHovered) then return 1.03 end
		return 1
	end)
	local hoverScale = scope:Spring(targetScale, 35, 0.7)
	
	local targetOffset = scope:Computed(function(use)
		return if use(isPressed) then SHADOW_OFFSET_SCALE else 0
	end)
	local pressOffset = scope:Spring(targetOffset, 40, 0.7)
	
	-- Border color based on state
	local borderColor = scope:Computed(function(use)
		if isLocked then return Theme.Colors.Surface.Shadow end
		if use(props.IsInDeck) then return GREEN_SELECTED end
		if hasMutations then return GOLD_BORDER end
		if use(isHovered) then return Theme.Colors.Action.Main end
		return Theme.Colors.Surface.Stroke :: Color3
	end)
	
	-- Background color
	local bgColor = scope:Computed(function(use)
		if isLocked then return Color3.fromRGB(80, 80, 80) end
		if use(props.IsInDeck) then return Color3.fromRGB(200, 240, 200) end
		return Theme.Colors.Surface.Main
	end)
	
	-- Build mutation icons
	local mutationIcons: {any} = {}
	for i, mutType in mutations do
		if i > 3 then break end -- Max 3 visible
		local mutData = MutationData.Get(mutType)
		table.insert(mutationIcons, scope:New("Frame") {
			Name = "MutationIcon" .. i,
			Size = UDim2.fromOffset(MUTATION_ICON_SIZE, MUTATION_ICON_SIZE),
			BackgroundColor3 = if mutData then mutData.Color else GOLD_BORDER,
			ZIndex = 6,
			
			[Children] = {
				scope:New("UICorner") {
					CornerRadius = UDim.new(0.5, 0),
				},
				scope:New("UIStroke") {
					Color = Color3.new(1, 1, 1),
					Thickness = 1,
				},
				scope:New("TextLabel") {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = if mutData then mutData.Icon else "✨",
					TextSize = 12,
				},
			},
		})
	end
	
	return scope:New("Frame") {
		Name = plantType,
		Size = UDim2.fromScale(1, 1), -- Fill grid cell
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Scale container
			scope:New("Frame") {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				
				[Children] = {
					scope:New("UIScale") { Scale = hoverScale },
					
					-- Shadow
					scope:New("Frame") {
						Name = "Shadow",
						Size = UDim2.fromScale(1, 0.97),
						Position = UDim2.fromScale(0, 0.03),
						BackgroundColor3 = Theme.Colors.Surface.Shadow,
						ZIndex = 1,
						
						[Children] = {
							scope:New("UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
						},
					},
					
					-- Main card
					scope:New("Frame") {
						Name = "Main",
						Size = scope:Computed(function(use)
							local offset = use(pressOffset)
							return UDim2.fromScale(1, 0.97 - offset)
						end),
						Position = scope:Computed(function(use)
							return UDim2.fromScale(0, use(pressOffset))
						end),
						BackgroundColor3 = bgColor,
						ZIndex = 2,
						
						[Children] = {
							scope:New("UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
							
							scope:New("UIStroke") {
								Color = borderColor,
								Thickness = Theme.Layout.StrokeThickness,
							},
							
							-- Lock overlay
							isLocked and scope:New("Frame") {
								Name = "LockOverlay",
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundColor3 = Color3.new(0, 0, 0),
								BackgroundTransparency = 0.5,
								ZIndex = 10,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									scope:New("TextLabel") {
										Size = UDim2.new(1, 0, 1, 0),
										BackgroundTransparency = 1,
										Text = "🔒",
										TextSize = 32,
									},
								},
							} or nil,
							
							-- Selected checkmark
							scope:Computed(function(use)
								if not use(props.IsInDeck) then return nil end
								return scope:New("Frame") {
									Name = "SelectedBadge",
									Size = UDim2.fromOffset(24, 24),
									Position = UDim2.new(1, -6, 0, 6),
									AnchorPoint = Vector2.new(1, 0),
									BackgroundColor3 = GREEN_SELECTED,
									ZIndex = 8,
									
									[Children] = {
										scope:New("UICorner") {
											CornerRadius = UDim.new(0.5, 0),
										},
										scope:New("TextLabel") {
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
							scope:New("TextLabel") {
								Name = "PlantName",
								Size = UDim2.new(1, -8, 0.12, 0),
								Position = UDim2.fromScale(0.02, 0.52),
								BackgroundTransparency = 1,
								Text = plantType,
								TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
								TextScaled = true,
								Font = Theme.Typography.Fonts.Title,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 3,
								
								[Children] = {
									scope:New("UITextSizeConstraint") {
										MaxTextSize = 14,
										MinTextSize = 8,
									},
								},
							},
							
							-- Sun cost pill
							scope:New("Frame") {
								Name = "SunCost",
								Size = UDim2.fromScale(0.5, 0.12),
								Position = UDim2.fromScale(0.5, 0.66),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Warning.Main,
								ZIndex = 4,
								
								[Children] = {
									scope:New("UICorner") {
										CornerRadius = UDim.new(0.5, 0),
									},
									scope:New("TextLabel") {
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
							hasMutations and scope:New("Frame") {
								Name = "MutationIcons",
								Size = UDim2.fromOffset(#mutationIcons * (MUTATION_ICON_SIZE + 2), MUTATION_ICON_SIZE),
								Position = UDim2.new(0, 4, 1, -24),
								BackgroundTransparency = 1,
								ZIndex = 5,
								
								[Children] = {
									scope:New("UIListLayout") {
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 2),
									},
									table.unpack(mutationIcons),
								},
							} or nil,
							
							-- Click handler
							scope:New("TextButton") {
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
