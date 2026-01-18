--!strict
--[[
	ScreenHeader.luau - Reusable screen header with shadow (Fusion 0.3)
	
	Toon Pop styled header with:
	- Shadow + Main frame pattern
	- Centered title
	- Left/Right content slots
	- Optional integrated close button
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local BaseComponents = Shared.ui.components.base
local CloseButton = require(BaseComponents.CloseButton)

local Children = Fusion.Children

export type ScreenHeaderProps = {
	Scope: Fusion.Scope<any>,
	Title: string,
	Size: UDim2?, -- Default: UDim2.fromScale(1, 0.1)
	Position: UDim2?, -- Default: UDim2.fromScale(0.5, 0)
	AnchorPoint: Vector2?, -- Default: Vector2.new(0.5, 0)
	ShadowOffset: number?, -- Default: 0.1 (10% of height)
	LeftContent: any?, -- Content for left side (e.g., ResourcePill)
	RightContent: any?, -- Content for right side (overrides CloseButton if provided)
	ShowCloseButton: boolean?, -- Show built-in close button (default: true)
	OnClose: (() -> ())?, -- Required if ShowCloseButton is true
}

local function ScreenHeader(props: ScreenHeaderProps): Frame
	local scope = props.Scope
	local shadowOffset = props.ShadowOffset or 0.1
	local showCloseButton = if props.ShowCloseButton == nil then true else props.ShowCloseButton

	return scope:New("Frame")({
		Name = "Header",
		Size = props.Size or UDim2.fromScale(1, 0.1),
		Position = props.Position or UDim2.fromScale(0.5, 0),
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

			-- Main header
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

					-- Title (centered)
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.fromScale(0.3, 0.6),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = props.Title,
						TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
						TextScaled = true,
						Font = Theme.Typography.Fonts.Title,

						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 32,
								MinTextSize = 16,
							}),
						},
					}),

					-- Left content container
					scope:New("Frame")({
						Name = "LeftContent",
						Size = UDim2.fromScale(0.15, 0.6),
						Position = UDim2.fromScale(0.02, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,

						[Children] = props.LeftContent,
					}),

					-- Right content container (close button or custom)
					scope:New("Frame")({
						Name = "RightContent",
						Size = UDim2.fromScale(0.08, 0.75),
						Position = UDim2.fromScale(0.98, 0.5),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,

						[Children] = if props.RightContent
							then props.RightContent
							elseif showCloseButton and props.OnClose then CloseButton({
								Scope = scope,
								OnClick = props.OnClose,
								UseIcon = true,
							})
							else nil,
					}),
				},
			}),
		},
	})
end

return ScreenHeader
