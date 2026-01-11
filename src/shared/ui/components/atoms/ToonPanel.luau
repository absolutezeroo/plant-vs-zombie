--!strict
--[[
	ToonPanel.luau - Generic container with "Toon Pop" style
	
	Atomic component providing a 3D cartoon panel effect.
	Features thick borders and offset shadow layer.
	
	Used as background for menus, inventory bars, dialogs, etc.
	
	SHARED component - used by both Arena and Lobby.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children

-- Constants
local SHADOW_OFFSET_Y = 4

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
	ToonPanel Component
	
	A stylized container with 3D shadow effect for "Toon Pop" aesthetic.
	Pass children via [Children] prop to render content inside.
	
	@param props ToonPanelProps
	@return Frame
]]
local function ToonPanel(props: ToonPanelProps): Frame
	local scope = props.Scope
	
	local size = props.Size or UDim2.new(0, 200, 0, 100)
	local position = props.Position or UDim2.new(0, 0, 0, 0)
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local layoutOrder = props.LayoutOrder or 0
	local zIndex = props.ZIndex or 1
	local automaticSize = props.AutomaticSize or Enum.AutomaticSize.None
	
	return New(scope, "Frame") {
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
			-- Shadow Layer (bottom, offset down)
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET_Y),
				BackgroundColor3 = Theme.Colors.Surface.Shadow,
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
				},
			},
			
			-- Main Layer (top, with stroke)
			New(scope, "Frame") {
				Name = "Main",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = Theme.Colors.Surface.Main,
				ZIndex = 2,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
					
					-- Thick cartoon outline
					New(scope, "UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = Theme.Layout.StrokeThickness,
					},
				},
			},
			
			-- Content Layer (children go here)
			New(scope, "Frame") {
				Name = "Content",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				ZIndex = 3,
				
				[Children] = props[Children],
			},
		},
	}
end

return ToonPanel
