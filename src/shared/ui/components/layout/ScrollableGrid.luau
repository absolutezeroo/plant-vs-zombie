--!strict
--[[
	ScrollableGrid.luau - Shadow + ScrollingFrame + UIGridLayout container (Fusion 0.3)
	
	Reusable Toon Pop styled scrollable grid container.
	Features:
	- Shadow layer below main frame
	- Scrolling frame with grid layout
	- Configurable cell size and padding
	- Responsive sizing support
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local Children = Fusion.Children

export type ScrollableGridProps = {
	Scope: Fusion.Scope<any>,
	Size: UDim2?, -- Default: UDim2.fromScale(1, 0.82)
	Position: UDim2?, -- Default: UDim2.fromScale(0.5, 1)
	AnchorPoint: Vector2?, -- Default: Vector2.new(0.5, 1)
	ShadowOffset: number?, -- Default: 0.01 (1% of height)
	CellSize: any, -- Fusion.Value<UDim2> or UDim2
	CellPadding: any, -- Fusion.Value<UDim2> or UDim2
	Children: any?, -- Grid content (cards)
	Padding: {
		Top: UDim?,
		Bottom: UDim?,
		Left: UDim?,
		Right: UDim?,
	}?, -- Default padding for content
	ZIndex: number?, -- Default: 1
}

local function ScrollableGrid(props: ScrollableGridProps): Frame
	local scope = props.Scope
	local shadowOffset = props.ShadowOffset or 0.01

	-- Default padding values
	local padding = props.Padding or {}
	local paddingTop = padding.Top or UDim.new(0, 12)
	local paddingBottom = padding.Bottom or UDim.new(0, 20)
	local paddingLeft = padding.Left or UDim.new(0, 12)
	local paddingRight = padding.Right or UDim.new(0, 12)

	return scope:New("Frame")({
		Name = "GridContainer",
		Size = props.Size or UDim2.fromScale(1, 0.82),
		Position = props.Position or UDim2.fromScale(0.5, 1),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex or 1,

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

			-- Scrolling frame
			scope:New("ScrollingFrame")({
				Name = "Grid",
				Size = UDim2.fromScale(1, 1 - shadowOffset),
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.Colors.Surface.Main,
				ScrollBarThickness = 8,
				ScrollBarImageColor3 = Theme.Colors.Surface.Shadow,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(0, 0, 0, 0),
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
						PaddingTop = paddingTop,
						PaddingBottom = paddingBottom,
						PaddingLeft = paddingLeft,
						PaddingRight = paddingRight,
					}),

					scope:New("UIGridLayout")({
						CellSize = props.CellSize,
						CellPadding = props.CellPadding,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					-- Grid content (cards)
					props.Children,
				},
			}),
		},
	})
end

return ScrollableGrid
