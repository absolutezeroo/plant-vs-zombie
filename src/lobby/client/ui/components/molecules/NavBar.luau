--!strict
--[[
	NavBar.luau - Navigation bar for lobby zones
	
	Molecule containing navigation buttons for Shop, Deck, Profile, Mutation Lab.
	Positioned at right side of screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local ToonPanel = require(Shared.ui.components.atoms.ToonPanel)

local Atoms = script.Parent.Parent.atoms
local NavButton = require(Atoms.NavButton)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed

export type NavBarProps = {
	Scope: Fusion.Scope<any>,
	ActiveView: any, -- Fusion.Value<string> ("Shop" | "Deck" | "Profile" | "Mutation")
	OnNavigate: (view: string) -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

-- Nav items configuration
local NAV_ITEMS = {
	{ Id = "Profile", Icon = "👤", Label = "Profil", Color = "Info" },
	{ Id = "Shop", Icon = "🛒", Label = "Shop", Color = "Gold" },
	{ Id = "Deck", Icon = "🃏", Label = "Deck", Color = "Action" },
	{ Id = "Mutation", Icon = "🧬", Label = "Labo", Color = "Purple" },
}

local function NavBar(props: NavBarProps): Frame
	local scope = props.Scope
	
	-- Calculate height based on content: 4 buttons × (60 + 18 label) + padding + gaps
	local BUTTON_HEIGHT = 60 + 18 -- icon + label
	local BUTTON_COUNT = #NAV_ITEMS
	local PADDING = 12 * 2 -- top + bottom
	local GAPS = 8 * (BUTTON_COUNT - 1)
	local TOTAL_HEIGHT = (BUTTON_HEIGHT * BUTTON_COUNT) + PADDING + GAPS + 4 -- +4 for shadow
	
	return New(scope, "Frame") {
		Name = "NavBar",
		Size = UDim2.fromOffset(80, TOTAL_HEIGHT),
		Position = props.Position or UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		
		[Children] = {
			ToonPanel({
				Scope = scope,
				Size = UDim2.new(1, 0, 1, 0),
				
				[Children] = {
					New(scope, "UIPadding") {
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 12),
						PaddingBottom = UDim.new(0, 12),
					},
					
					New(scope, "UIListLayout") {
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					},
					
					-- Nav buttons
					Fusion.ForValues(scope, NAV_ITEMS, function(use, itemScope, item)
						return NavButton({
							Scope = itemScope,
							Icon = item.Icon,
							Label = item.Label,
							Color = item.Color,
							IsActive = Computed(itemScope, function(useInner)
								return useInner(props.ActiveView) == item.Id
							end),
							OnClick = function()
								props.OnNavigate(item.Id)
							end,
							LayoutOrder = table.find(NAV_ITEMS, item) or 0,
						})
					end),
				},
			}),
		},
	}
end

return NavBar
