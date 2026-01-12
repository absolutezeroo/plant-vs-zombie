--!strict
--[[
	ToonPanel.luau - Generic container with "Toon Pop" style (Responsive)
	
	Atomic component providing a 3D cartoon panel effect.
	Features thick borders and offset shadow layer.
	
	Used as background for menus, inventory bars, dialogs, etc.
	
	SHARED component - used by both Arena and Lobby.
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Fusion 0.3 primitives
local Children = Fusion.Children

-- Constants (shadow uses Scale for responsiveness)
local SHADOW_OFFSET_SCALE = 0.08 -- 8% of component height

export type ToonPanelProps = {
	Scope: Fusion.Scope<any>,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	AutomaticSize: Enum.AutomaticSize?,
	Visible: (Fusion.Value<boolean> | boolean)?,
	[typeof(Children)]: Fusion.Child?,
}

--[[
	ToonPanel Component (Responsive)
	
	A stylized container with 3D shadow effect for "Toon Pop" aesthetic.
	Pass children via [Children] prop to render content inside.
	Shadow offset uses Scale for responsive sizing.
	
	@param props ToonPanelProps
	@return Frame
]]
local function ToonPanel(props: ToonPanelProps): Frame
	local scope = props.Scope

	local size = props.Size or UDim2.fromScale(0.2, 0.1)
	local position = props.Position or UDim2.new(0, 0, 0, 0)
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local layoutOrder = props.LayoutOrder or 0
	local zIndex = props.ZIndex or 1
	local automaticSize = props.AutomaticSize or Enum.AutomaticSize.None

	-- For AutomaticSize to work, sub-frames need proper sizing
	local useAutoWidth = automaticSize == Enum.AutomaticSize.X or automaticSize == Enum.AutomaticSize.XY
	local subFrameSize = UDim2.fromScale(1, 1)

	return scope:New("Frame")({
		Name = "ToonPanel",
		Size = size,
		Position = position,
		AnchorPoint = anchorPoint,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		AutomaticSize = automaticSize,
		BackgroundTransparency = 1,
		Visible = if props.Visible ~= nil then props.Visible else true,

		[Children] = {
			-- Shadow Layer (bottom, offset down using Scale)
			scope:New("Frame")({
				Name = "Shadow",
				Size = subFrameSize,
				AutomaticSize = if useAutoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
				Position = UDim2.fromScale(0, SHADOW_OFFSET_SCALE),
				BackgroundColor3 = Theme.Colors.Surface.Shadow,
				ZIndex = 1,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Layout.CornerRadius,
					}),
				},
			}),

			-- Main Layer (top, with stroke)
			scope:New("Frame")({
				Name = "Main",
				Size = subFrameSize,
				AutomaticSize = if useAutoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
				BackgroundColor3 = Theme.Colors.Surface.Main,
				ZIndex = 2,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Layout.CornerRadius,
					}),

					-- Thick cartoon outline
					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = Theme.Layout.StrokeThickness,
					}),
				},
			}),

			-- Content Layer (children go here)
			scope:New("Frame")({
				Name = "Content",
				Size = subFrameSize,
				AutomaticSize = if useAutoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
				BackgroundTransparency = 1,
				ZIndex = 3,

				[Children] = props[Children],
			}),
		},
	})
end

return ToonPanel
