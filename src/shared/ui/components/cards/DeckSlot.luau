--!strict
--[[
	DeckSlot.luau - Single slot in the deck bar (Fusion 0.3)
	
	A single deck slot that displays a plant or an empty placeholder.
	Features:
	- Press animation (scale-based)
	- Mutation badge display
	- Hover remove overlay
	- Toon Pop styling
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local MutationData = require(Shared.data.MutationData)
local PlantViewport = require(Shared.ui.components.cards.PlantViewport)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

-- Colors (Toon Pop)
local GOLD_BORDER = Color3.fromHex("#FFD700")
local GREEN_SELECTED = Color3.fromHex("#4CAF50")

export type DeckSlotProps = {
	Scope: Fusion.Scope<any>,
	Index: number,
	PlantType: string?,
	Mutations: { string }?,
	OnRemove: () -> (),
	Size: UDim2?, -- Default: UDim2.fromScale(0.12, 1)
}

local function DeckSlot(props: DeckSlotProps): Frame
	local scope = props.Scope
	local hasPlant = props.PlantType ~= nil
	local hasMutations = props.Mutations and #props.Mutations > 0
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)

	-- Press animation (scale-based)
	local pressScale = scope:Spring(
		scope:Computed(function(use)
			return if use(isPressed) then 0.92 else 1
		end),
		40,
		0.7
	)

	-- Border color based on state
	local borderColor = if hasMutations
		then GOLD_BORDER
		elseif hasPlant then GREEN_SELECTED
		else Theme.Colors.Surface.Stroke

	-- Create viewport for plant
	local plantViewport: ViewportFrame? = nil
	if hasPlant then
		plantViewport = PlantViewport.CreateWithScope(scope, {
			PlantType = props.PlantType :: string,
			Size = UDim2.fromScale(0.9, 0.5),
			Position = UDim2.fromScale(0.5, 0.38),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
			CameraFOV = 35,
			CameraDistance = 1.4,
			CameraHeight = 0.12,
		})
	end

	return scope:New("Frame")({
		Name = "Slot" .. props.Index,
		Size = props.Size or UDim2.fromScale(0.12, 1), -- Width will be constrained by aspect ratio
		BackgroundTransparency = 1,

		[Children] = {
			-- Maintain square aspect ratio
			scope:New("UIAspectRatioConstraint")({
				AspectRatio = 0.8,
				DominantAxis = Enum.DominantAxis.Height,
			}),

			-- Scale wrapper for press animation
			scope:New("Frame")({
				Name = "ScaleWrapper",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = scope:Computed(function(use)
					local s = use(pressScale)
					return UDim2.fromScale(s, s)
				end),
				BackgroundTransparency = 1,

				[Children] = {
					-- Shadow
					scope:New("Frame")({
						Name = "Shadow",
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.fromScale(0, 0.06),
						BackgroundColor3 = if hasPlant
							then (if hasMutations then Color3.fromHex("#B8860B") else Color3.fromHex("#357A38"))
							else Theme.Colors.Surface.Shadow,
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.12, 0),
							}),
						},
					}),

					-- Main slot
					scope:New("Frame")({
						Name = "Main",
						Size = UDim2.fromScale(1, 1),
						ClipsDescendants = true,
						BackgroundColor3 = scope:Computed(function(use)
							if hasPlant and use(isHovered) then
								return Theme.Colors.Danger.Main
							end
							return Theme.Colors.Surface.Main
						end),
						ZIndex = 2,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.12, 0),
							}),

							scope:New("UIStroke")({
								Color = borderColor,
								Thickness = if hasMutations then 3 else Theme.Layout.StrokeThickness,
							}),

							-- Slot number badge (top-left)
							scope:New("Frame")({
								Size = UDim2.fromScale(0.3, 0.22),
								Position = UDim2.fromScale(0.05, 0.05),
								BackgroundColor3 = Theme.Colors.Surface.Stroke,
								ZIndex = 5,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0.5, 0),
									}),
									scope:New("UIAspectRatioConstraint")({
										AspectRatio = 1,
									}),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = tostring(props.Index),
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										Font = Enum.Font.GothamBold,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MinTextSize = 6,
												MaxTextSize = 14,
											}),
										},
									}),
								},
							}),

							-- Mutation badge (top-right)
							if hasMutations
								then scope:New("Frame")({
									Size = UDim2.fromScale(0.3, 0.22),
									Position = UDim2.fromScale(0.95, 0.05),
									AnchorPoint = Vector2.new(1, 0),
									BackgroundColor3 = GOLD_BORDER,
									ZIndex = 6,

									[Children] = {
										scope:New("UICorner")({
											CornerRadius = UDim.new(0.5, 0),
										}),
										scope:New("UIAspectRatioConstraint")({
											AspectRatio = 1,
										}),
										scope:New("TextLabel")({
											Size = UDim2.fromScale(1, 1),
											BackgroundTransparency = 1,
											Text = if props.Mutations
												then (MutationData.Get(props.Mutations[1]) or { Icon = "✨" }).Icon
												else "✨",
											TextScaled = true,

											[Children] = {
												scope:New("UITextSizeConstraint")({
													MinTextSize = 6,
													MaxTextSize = 12,
												}),
											},
										}),
									},
								})
								else nil,

							-- Plant viewport or empty plus
							if hasPlant
								then plantViewport
								else scope:New("TextLabel")({
									Size = UDim2.fromScale(0.8, 0.5),
									Position = UDim2.fromScale(0.5, 0.4),
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Text = "+",
									TextColor3 = Theme.Colors.Surface.Shadow,
									TextScaled = true,
									Font = Theme.Typography.Fonts.Title,

									[Children] = {
										scope:New("UITextSizeConstraint")({
											MinTextSize = 14,
											MaxTextSize = 32,
										}),
									},
								}),

							-- Plant name label
							if hasPlant
								then scope:New("TextLabel")({
									Size = UDim2.fromScale(0.9, 0.15),
									Position = UDim2.fromScale(0.5, 0.88),
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Text = props.PlantType :: string,
									TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
									TextScaled = true,
									Font = Enum.Font.GothamBold,
									TextTruncate = Enum.TextTruncate.AtEnd,
									ZIndex = 4,

									[Children] = {
										scope:New("UITextSizeConstraint")({
											MinTextSize = 6,
											MaxTextSize = 10,
										}),
									},
								})
								else nil,

							-- Remove overlay on hover
							scope:Computed(function(use)
								if hasPlant and use(isHovered) then
									return scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "✕",
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										Font = Enum.Font.GothamBold,
										ZIndex = 10,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MinTextSize = 16,
												MaxTextSize = 32,
											}),
										},
									})
								end
								return nil :: any
							end),

							-- Click handler
							scope:New("TextButton")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 15,

								[OnEvent("MouseButton1Down")] = function()
									if hasPlant then
										isPressed:set(true)
									end
								end,

								[OnEvent("MouseButton1Up")] = function()
									isPressed:set(false)
									if hasPlant then
										props.OnRemove()
									end
								end,

								[OnEvent("MouseEnter")] = function()
									isHovered:set(true)
								end,

								[OnEvent("MouseLeave")] = function()
									isHovered:set(false)
									isPressed:set(false)
								end,
							}),
						},
					}),
				},
			}),
		},
	})
end

return DeckSlot
