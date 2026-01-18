--!strict
--[[
	ScreenOverlay.luau - Full-screen dark overlay container (Fusion 0.3)
	
	Reusable layout component for modal screens.
	Creates a dark semi-transparent background with a centered panel.
	
	Uses "Toon Pop" design system.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Children = Fusion.Children

export type ScreenOverlayProps = {
	Scope: Fusion.Scope<any>,
	Name: string?, -- Default: "ScreenOverlay"
	OverlayTransparency: number?, -- Default: 0.5
	PanelSize: UDim2?, -- Default: UDim2.fromScale(0.9, 0.9)
	ZIndex: number?, -- Default: 100
	-- Children passed via [Children] key
}

local function ScreenOverlay(props: ScreenOverlayProps): Frame
	local scope = props.Scope

	return scope:New("Frame")({
		Name = props.Name or "ScreenOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = props.OverlayTransparency or 0.5,
		ZIndex = props.ZIndex or 100,

		[Children] = {
			-- Centered panel (transparent container)
			scope:New("Frame")({
				Name = "Panel",
				Size = props.PanelSize or UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = props[Children],
			}),
		},
	})
end

return ScreenOverlay
