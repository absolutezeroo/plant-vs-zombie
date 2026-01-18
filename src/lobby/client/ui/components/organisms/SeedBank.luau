--!strict
--[[
	SeedBank.luau - Lobby deck preview bar (Toon Pop + Responsive)
	
	Displays the player's equipped plants in a stylish horizontal bar.
	Uses DeckSlot for consistent visual style with DeckBuilder.
	
	Features:
	- Shadow + Main frame pattern (Toon Pop depth)
	- Gradient background accent
	- Reactive to deck changes
	- Click to show plant tooltip
	
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local PlantViewport = require(Shared.ui.components.cards.PlantViewport)
local MutationData = require(Shared.data.MutationData)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Colors
local GOLD_BORDER = Color3.fromHex("#FFD700")
local SLOT_BG = Color3.fromRGB(60, 70, 80)
local SLOT_SHADOW = Color3.fromRGB(35, 40, 50)

export type SeedBankProps = {
	Scope: Fusion.Scope<any>,
	EquippedPlants: any, -- Can be {string} or Fusion.Value<{string}>
	EquippedMutations: any, -- Fusion.Value<{[string]: {string}}>
	OnPlantClick: (plantType: string, mutations: { string }) -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
}

-- Individual seed slot component (inline for simplicity)
local function SeedSlot(
	scope: Fusion.Scope<any>,
	plantType: string,
	mutations: { string },
	onClick: () -> ()
): Frame
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)
	local hasMutations = #mutations > 0

	-- Press animation
	local pressScale = scope:Spring(
		scope:Computed(function(use)
			return if use(isPressed) then 0.9 else 1
		end),
		45,
		0.6
	)

	-- Hover scale
	local hoverScale = scope:Spring(
		scope:Computed(function(use)
			if use(isHovered) and not use(isPressed) then
				return 1.08
			end
			return 1
		end),
		40,
		0.7
	)

	-- Combined scale
	local combinedScale = scope:Computed(function(use)
		return use(pressScale) * use(hoverScale)
	end)

	-- Border color
	local borderColor = if hasMutations then GOLD_BORDER else Theme.Colors.Surface.Stroke

	-- Build mutation icons
	local mutationIcons: { any } = {}
	for i, mutId in mutations do
		if i > 3 then break end
		local mutData = MutationData.Get(mutId)
		if mutData then
			table.insert(mutationIcons, scope:New("Frame")({
				Name = "Mut" .. i,
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = mutData.Color,
				LayoutOrder = i,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.3, 0),
					}),
					scope:New("UIStroke")({
						Color = Color3.new(1, 1, 1),
						Thickness = 1,
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = mutData.Icon or "✨",
						TextSize = 10,
						Font = Enum.Font.GothamBold,
					}),
				},
			}))
		end
	end

	return scope:New("Frame")({
		Name = "Slot_" .. plantType,
		Size = UDim2.fromOffset(80, 100),
		BackgroundTransparency = 1,

		[Children] = {
			-- Scale wrapper
			scope:New("Frame")({
				Name = "ScaleWrapper",
				Size = scope:Computed(function(use)
					local s = use(combinedScale)
					return UDim2.fromScale(s, s)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					-- Shadow
					scope:New("Frame")({
						Name = "Shadow",
						Size = UDim2.fromScale(1, 0.92),
						Position = UDim2.fromScale(0.5, 0.08),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = if hasMutations 
							then Color3.fromHex("#B8860B") 
							else SLOT_SHADOW,
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.15, 0),
							}),
						},
					}),

					-- Main card
					scope:New("TextButton")({
						Name = "Main",
						Size = UDim2.fromScale(1, 0.92),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = SLOT_BG,
						AutoButtonColor = false,
						Text = "",
						ClipsDescendants = true,
						ZIndex = 2,

						[OnEvent("MouseButton1Down")] = function()
							isPressed:set(true)
						end,

						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							if peek(isHovered) then
								onClick()
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
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.15, 0),
							}),

							scope:New("UIStroke")({
								Color = borderColor,
								Thickness = if hasMutations then 3 else 2,
							}),

							-- Gradient overlay for depth
							scope:New("UIGradient")({
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
									ColorSequenceKeypoint.new(0.5, Color3.new(0.9, 0.9, 0.9)),
									ColorSequenceKeypoint.new(1, Color3.new(0.75, 0.75, 0.75)),
								}),
								Rotation = 90,
							}),

							-- 3D Plant viewport
							PlantViewport.CreateWithScope(scope, {
								PlantType = plantType,
								Size = UDim2.fromScale(0.95, 0.7),
								Position = UDim2.fromScale(0.5, 0.35),
								AnchorPoint = Vector2.new(0.5, 0.5),
								ZIndex = 3,
								CameraFOV = 30,
								CameraDistance = 1.4,
								CameraHeight = 0.15,
							}),

							-- Plant name
							scope:New("TextLabel")({
								Name = "PlantName",
								Size = UDim2.new(1, -8, 0, 14),
								Position = UDim2.new(0.5, 0, 1, -18),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundTransparency = 1,
								Text = plantType,
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 11,
								Font = Enum.Font.GothamBold,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 4,
							}),

							-- Mutation icons row (bottom-left)
							#mutationIcons > 0 and scope:New("Frame")({
								Name = "Mutations",
								Size = UDim2.fromOffset(#mutationIcons * 18, 16),
								Position = UDim2.fromOffset(4, 4),
								BackgroundTransparency = 1,
								ZIndex = 5,

								[Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 2),
									}),
									table.unpack(mutationIcons),
								},
							}) or nil,
						},
					}),
				},
			}),
		},
	})
end

local function SeedBank(props: SeedBankProps): Frame
	local scope = props.Scope
	local equippedPlants = props.EquippedPlants
	local equippedMutations = props.EquippedMutations

	-- Build slots using ForValues for proper lifecycle
	local slotsArray = scope:ForValues(equippedPlants, function(use, innerScope, plantType)
		local mutations = use(equippedMutations)
		local plantMutations = mutations[plantType] or {}

		return SeedSlot(innerScope, plantType, plantMutations, function()
			props.OnPlantClick(plantType, plantMutations)
		end)
	end)

	-- Calculate width based on deck size
	local barWidth = scope:Computed(function(use)
		local plants = use(equippedPlants)
		local count = math.max(1, #plants)
		-- 80px per slot + 8px gap + 24px padding
		return 24 + (count * 80) + ((count - 1) * 8)
	end)

	return scope:New("Frame")({
		Name = "SeedBank",
		Size = scope:Computed(function(use)
			return UDim2.fromOffset(use(barWidth), 130)
		end),
		Position = props.Position or UDim2.fromScale(0.5, 0.98),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex or 1,

		[Children] = {
			-- Shadow layer (Toon Pop depth)
			scope:New("Frame")({
				Name = "Shadow",
				Size = UDim2.new(1, 0, 1, -8),
				Position = UDim2.fromOffset(0, 8),
				BackgroundColor3 = Theme.Colors.Surface.Shadow,
				ZIndex = 1,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 16),
					}),
				},
			}),

			-- Main bar
			scope:New("Frame")({
				Name = "Main",
				Size = UDim2.new(1, 0, 1, -8),
				BackgroundColor3 = Theme.Colors.Surface.Main,
				ZIndex = 2,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 16),
					}),

					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 3,
					}),

					-- Inner gradient for depth
					scope:New("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
							ColorSequenceKeypoint.new(1, Color3.new(0.9, 0.9, 0.9)),
						}),
						Rotation = 90,
					}),

					-- Padding
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
					}),

					-- Slots layout
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
					}),

					-- Reactive slots
					slotsArray,
				},
			}),
		},
	})
end

return SeedBank
