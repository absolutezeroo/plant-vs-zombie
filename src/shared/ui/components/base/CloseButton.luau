--!strict
--[[
	CloseButton.luau - Animated close button with shadow (Fusion 0.3)
	
	Reusable Toon Pop styled close button with press animation.
	Used in screen headers for dismissing modals.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local BaseComponents = Shared.ui.components.base
local Icon = require(BaseComponents.Icon)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

export type CloseButtonProps = {
	Scope: Fusion.Scope<any>,
	OnClick: () -> (),
	Size: UDim2?, -- Default: UDim2.fromScale(1, 1)
	Position: UDim2?, -- Default: UDim2.fromScale(0.5, 0.5)
	AnchorPoint: Vector2?, -- Default: Vector2.new(0.5, 0.5)
	ZIndex: number?, -- Default: 1
	UseIcon: boolean?, -- Use Icon component instead of emoji (default: true)
}

local function CloseButton(props: CloseButtonProps): Frame
	local scope = props.Scope
	local useIcon = if props.UseIcon == nil then true else props.UseIcon

	-- Press state
	local isPressed = scope:Value(false)
	local pressOffset = scope:Spring(
		scope:Computed(function(use)
			return if use(isPressed) then 4 else 0
		end),
		40,
		0.7
	)

	return scope:New("Frame")({
		Name = "CloseButton",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex or 1,

		[Children] = {
			-- Maintain square aspect ratio
			scope:New("UIAspectRatioConstraint")({
				AspectRatio = 1,
				DominantAxis = Enum.DominantAxis.Height,
			}),

			-- Shadow
			scope:New("Frame")({
				Name = "Shadow",
				Size = UDim2.fromScale(1, 0.9),
				Position = UDim2.fromScale(0.5, 0.1),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.Colors.Danger.Shadow,
				ZIndex = 1,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Layout.CornerRadius,
					}),
				},
			}),

			-- Button
			scope:New("TextButton")({
				Name = "Button",
				Size = scope:Computed(function(use)
					local offset = use(pressOffset)
					return UDim2.fromScale(1, 0.9 - offset * 0.01)
				end),
				Position = scope:Computed(function(use)
					return UDim2.fromScale(0.5, use(pressOffset) * 0.01)
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.Colors.Danger.Main,
				Text = if useIcon then "" else Theme.Icons.Close,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = not useIcon,
				Font = Theme.Typography.Fonts.Title,
				AutoButtonColor = false,
				ZIndex = 2,

				[OnEvent("MouseButton1Down")] = function()
					isPressed:set(true)
				end,

				[OnEvent("MouseButton1Up")] = function()
					isPressed:set(false)
					props.OnClick()
				end,

				[OnEvent("MouseLeave")] = function()
					isPressed:set(false)
				end,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Layout.CornerRadius,
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					}),
					if useIcon
						then Icon(scope, {
							Name = "Close",
							Size = UDim2.fromScale(0.6, 0.6),
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
						})
						else scope:New("UITextSizeConstraint")({
							MaxTextSize = 24,
							MinTextSize = 14,
						}),
				},
			}),
		},
	})
end

return CloseButton
