--!strict
--[[
	StatCard.luau - Statistics display card
	
	Atomic component showing icon + label + value in a card.
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
local SHADOW_OFFSET = 4
local CARD_HEIGHT = 90

export type StatCardProps = {
	Scope: Fusion.Scope<any>,
	Icon: string,
	Label: string,
	Value: any, -- Fusion.Value<number> or Fusion.Computed<number>
	Color: string?, -- Theme color key: "Gold", "Action", "Danger", etc.
	Size: UDim2?,
	LayoutOrder: number?,
}

--[[
	Format large numbers for display (1000 → 1.0K)
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

local function StatCard(props: StatCardProps): Frame
	local scope = props.Scope
	local colorKey = props.Color or "Gold"
	local size = props.Size or UDim2.new(0.5, -8, 0, CARD_HEIGHT)
	
	local colorSet = (Theme.Colors :: any)[colorKey] or Theme.Colors.Gold
	
	local displayText = Computed(scope, function(use)
		local value = use(props.Value)
		return formatNumber(value)
	end)
	
	return New(scope, "Frame") {
		Name = "StatCard",
		Size = size,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Shadow
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = Theme.Colors.Surface.Shadow,
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
				},
			},
			
			-- Main card
			New(scope, "Frame") {
				Name = "Main",
				Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
				BackgroundColor3 = Theme.Colors.Surface.Main,
				ZIndex = 2,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
					
					New(scope, "UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = Theme.Layout.StrokeThickness,
					},
					
					-- Icon (top-left)
					New(scope, "TextLabel") {
						Name = "Icon",
						Size = UDim2.fromOffset(40, 40),
						Position = UDim2.fromOffset(12, 10),
						BackgroundTransparency = 1,
						Text = props.Icon,
						TextSize = 28,
					},
					
					-- Label (next to icon)
					New(scope, "TextLabel") {
						Name = "Label",
						Size = UDim2.new(1, -60, 0, 24),
						Position = UDim2.fromOffset(50, 18),
						BackgroundTransparency = 1,
						Text = props.Label,
						TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
						TextSize = 14,
						Font = Theme.Typography.Fonts.Body,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
					
					-- Value (big number, bottom)
					New(scope, "TextLabel") {
						Name = "Value",
						Size = UDim2.new(1, -20, 0, 32),
						Position = UDim2.new(0, 12, 1, -38),
						BackgroundTransparency = 1,
						Text = displayText,
						TextColor3 = colorSet.Main :: Color3,
						TextSize = 26,
						Font = Theme.Typography.Fonts.Title,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				},
			},
		},
	}
end

return StatCard
