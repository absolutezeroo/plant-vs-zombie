--!strict
--[[
	FilterBar.luau - Horizontal filter pills container (Fusion 0.3)
	
	Reusable filter bar with responsive scaling.
	Uses FilterPill components for each category option.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Children = Fusion.Children

export type FilterOption = {
	Text: string,
	Value: string?, -- If not provided, uses Text as value
}

export type FilterBarProps = {
	Scope: Fusion.Scope<any>,
	Options: { FilterOption } | { string }, -- Can be array of strings or FilterOption objects
	SelectedValue: any, -- Fusion.Value<string> or Fusion.Computed<string>
	OnSelect: (value: string) -> (),
	FilterPillComponent: any, -- The FilterPill component to use
	Size: UDim2?, -- Default: UDim2.fromScale(1, 0.06)
	Position: UDim2?, -- Default: UDim2.fromScale(0.5, 0.11)
	AnchorPoint: Vector2?, -- Default: Vector2.new(0.5, 0)
	ViewportSize: any?, -- Fusion.Value<Vector2> for responsive scaling
	Padding: UDim?, -- Default: UDim.new(0.02, 0)
}

local function FilterBar(props: FilterBarProps): Frame
	local scope = props.Scope
	local FilterPill = props.FilterPillComponent

	-- Build options list
	local options: { FilterOption } = {}
	for _, opt in props.Options do
		if type(opt) == "string" then
			table.insert(options, { Text = opt, Value = opt })
		else
			table.insert(options, opt :: FilterOption)
		end
	end

	-- Build filter pills
	local pills: { Frame } = {}
	for i, option in options do
		local value = option.Value or option.Text
		table.insert(
			pills,
			FilterPill({
				Scope = scope,
				Text = option.Text,
				IsActive = scope:Computed(function(use)
					return use(props.SelectedValue) == value
				end),
				OnClick = function()
					props.OnSelect(value)
				end,
				LayoutOrder = i,
			})
		)
	end

	return scope:New("Frame")({
		Name = "FilterBar",
		Size = props.Size or UDim2.fromScale(1, 0.06),
		Position = props.Position or UDim2.fromScale(0.5, 0.11),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		BackgroundTransparency = 1,

		[Children] = {
			-- Responsive scale (if ViewportSize provided)
			if props.ViewportSize
				then scope:New("UIScale")({
					Scale = scope:Computed(function(use)
						local size = use(props.ViewportSize)
						return math.clamp(size.Y / 1080, 0.6, 1.5)
					end),
				})
				else nil,

			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = props.Padding or UDim.new(0.02, 0),
			}),

			-- Filter pills
			table.unpack(pills),
		},
	})
end

return FilterBar
