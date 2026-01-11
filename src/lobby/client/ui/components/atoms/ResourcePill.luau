--!strict
--[[
	ResourcePill.luau - Currency display pill (coins, gems, etc.)
	
	Atomic component showing icon + value in a rounded pill shape.
	"Toon Pop" style with shadow effect.
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

-- Constants
local PILL_HEIGHT = 36
local SHADOW_OFFSET = 3

export type ResourcePillProps = {
	Scope: Fusion.Scope<any>,
	Icon: string,
	Value: any, -- Fusion.Value<number> or Fusion.Computed<number>
	Color: string?, -- Theme color key: "Gold", "Purple", "Action", etc.
	Width: number?,
	LayoutOrder: number?,
}

--[[
	Format large numbers (1000 → 1.0K, 10000 → 10K)
]]
local function formatNumber(value: number): string
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 10000 then
		return string.format("%dK", math.floor(value / 1000))
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

local function ResourcePill(props: ResourcePillProps): Frame
	local scope = props.Scope
	local colorKey = props.Color or "Gold"
	local width = props.Width or 90
	
	local colorSet = (Theme.Colors :: any)[colorKey] or Theme.Colors.Gold
	
	local displayText = Computed(scope, function(use)
		local value = use(props.Value)
		return formatNumber(value)
	end)
	
	return New(scope, "Frame") {
		Name = "ResourcePill",
		Size = UDim2.fromOffset(width, PILL_HEIGHT + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Shadow
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.fromOffset(width, PILL_HEIGHT),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = colorSet.Shadow :: Color3,
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
				},
			},
			
			-- Main pill
			New(scope, "Frame") {
				Name = "Main",
				Size = UDim2.fromOffset(width, PILL_HEIGHT),
				BackgroundColor3 = colorSet.Main :: Color3,
				ZIndex = 2,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
					
					New(scope, "UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					},
					
					-- Icon
					New(scope, "TextLabel") {
						Name = "Icon",
						Size = UDim2.fromOffset(28, PILL_HEIGHT),
						Position = UDim2.fromOffset(6, 0),
						BackgroundTransparency = 1,
						Text = props.Icon,
						TextSize = 20,
					},
					
					-- Value
					New(scope, "TextLabel") {
						Name = "Value",
						Size = UDim2.new(1, -40, 1, 0),
						Position = UDim2.fromOffset(32, 0),
						BackgroundTransparency = 1,
						Text = displayText,
						TextColor3 = Color3.fromRGB(80, 50, 20), -- Dark brown for readability on colored backgrounds
						TextSize = 16,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
					},
				},
			},
		},
	}
end

return ResourcePill
