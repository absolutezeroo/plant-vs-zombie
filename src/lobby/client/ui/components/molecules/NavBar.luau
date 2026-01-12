--!strict
--[[
	NavBar.luau - Navigation bar for lobby zones
	
	Vertical bar containing navigation buttons for Shop, Deck, Profile, etc.
	Uses Fusion 0.3 scope:Method() syntax.
	Responsive design using Scale-based sizing with AutomaticSize for content.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local Components = script.Parent.Parent
local NavButton = require(Components.atoms.NavButton)

-- Fusion primitives
local Children = Fusion.Children

-- Config (scale-based)
local PADDING_SCALE = 0.08 -- 8% padding inside
local GAP_PIXELS = 8 -- 8px gap between buttons

-- Navigation items configuration
local NAV_ITEMS = {
	{ Id = "Profile", Icon = "👤", Color = "Action" },
	{ Id = "Shop", Icon = "🛒", Color = "Gold" },
	{ Id = "Deck", Icon = "🃏", Color = "Purple" },
	{ Id = "Mutation", Icon = "🧬", Color = "Danger" },
	{ Id = "Unlocks", Icon = "🏆", Color = "Action" },
}

export type NavBarProps = {
	Scope: any,
	ActiveView: any?, -- Fusion Value<string>
	OnNavigate: ((viewId: string) -> ())?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

local function NavBar(props: NavBarProps): Frame
	local scope = props.Scope

	-- Create buttons manually (static list, no need for ForValues)
	local buttons = {}
	for i, item in ipairs(NAV_ITEMS) do
		local isActive = scope:Computed(function(use)
			if props.ActiveView == nil then
				return false
			end
			return use(props.ActiveView) == item.Id
		end)

		buttons[i] = NavButton({
			Scope = scope,
			Icon = item.Icon,
			Color = item.Color,
			OnClick = function()
				if props.OnNavigate then
					props.OnNavigate(item.Id)
				end
			end,
			IsActive = isActive,
			LayoutOrder = i,
		})
	end

	return scope:New("Frame")({
		Name = "NavBar",
		Size = UDim2.fromScale(0.06, 0.55), -- 6% width, 55% height of screen
		Position = props.Position or UDim2.fromScale(0.99, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(1, 0.5),
		BackgroundTransparency = 1,

		[Children] = {
			-- Keep proper aspect ratio for the whole bar
			scope:New("UIAspectRatioConstraint")({
				AspectRatio = 0.18, -- Width / Height ratio (narrow vertical bar)
				DominantAxis = Enum.DominantAxis.Height,
			}),
			-- Shadow
			scope:New("Frame")({
				Name = "Shadow",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, 0.01),
				BackgroundColor3 = Theme.Colors.Surface.Shadow :: Color3,
				ZIndex = 1,

				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.08, 0) }),
				},
			}),

			-- Main panel
			scope:New("Frame")({
				Name = "Main",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Surface.Main :: Color3,
				ZIndex = 2,

				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.08, 0) }),

					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					}),

					scope:New("UIPadding")({
						PaddingTop = UDim.new(PADDING_SCALE, 0),
						PaddingBottom = UDim.new(PADDING_SCALE, 0),
						PaddingLeft = UDim.new(PADDING_SCALE, 0),
						PaddingRight = UDim.new(PADDING_SCALE, 0),
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, GAP_PIXELS),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					-- Buttons
					buttons,
				},
			}),
		},
	})
end

return NavBar
