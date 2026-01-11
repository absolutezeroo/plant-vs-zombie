--!strict
--[[
	RewardRow.luau - Single reward display row
	
	Atom component showing icon + label + animated value.
	Used in result screens for coins, XP, gems, etc.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed

export type RewardRowProps = {
	Scope: Fusion.Scope<any>,
	Icon: string,
	Label: string,
	Value: any, -- Fusion.Value<number> or Fusion.Computed<number>
	Color: Color3?,
	LayoutOrder: number?,
	Prefix: string?,
	Suffix: string?,
	Visible: any?, -- Optional Fusion.Value<boolean> or Fusion.Computed<boolean>
}

--[[
	RewardRow Component
	
	Displays a single reward with icon, label and animated value.
	
	@param props RewardRowProps
	@return Frame
]]
local function RewardRow(props: RewardRowProps): Frame
	local scope = props.Scope
	local color = props.Color or Theme.Colors.Surface.Stroke
	local prefix = props.Prefix or ""
	local suffix = props.Suffix or ""
	
	local displayText = Computed(scope, function(use)
		local value = use(props.Value)
		return `{prefix}{value}{suffix}`
	end)
	
	-- Handle visibility (default true if not provided)
	local visible = if props.Visible then props.Visible else true
	
	return New(scope, "Frame") {
		Name = `RewardRow_{props.Label}`,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = visible,
		
		[Children] = {
			-- Icon
			New(scope, "TextLabel") {
				Name = "Icon",
				Size = UDim2.fromOffset(28, 28),
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = props.Icon,
				TextSize = 22,
				Font = Enum.Font.GothamBold,
			},
			
			-- Label
			New(scope, "TextLabel") {
				Name = "Label",
				Size = UDim2.new(0.5, -40, 1, 0),
				Position = UDim2.new(0, 36, 0, 0),
				BackgroundTransparency = 1,
				Text = props.Label,
				TextColor3 = Theme.Colors.Surface.Stroke,
				TextSize = 16,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			
			-- Value
			New(scope, "TextLabel") {
				Name = "Value",
				Size = UDim2.new(0.5, 0, 1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text = displayText,
				TextColor3 = color,
				TextSize = 20,
				Font = Enum.Font.GothamBold, -- More readable than LuckiestGuy for numbers
				TextXAlignment = Enum.TextXAlignment.Right,
			},
		},
	}
end

return RewardRow
