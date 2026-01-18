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
local IconAssets = require(Shared.ui.design.IconAssets)
local Icon = require(Shared.ui.components.base.Icon)

-- Fusion primitives
local Children = Fusion.Children

-- Constants
local PILL_HEIGHT = 36
local SHADOW_OFFSET = 3

export type ResourcePillProps = {
	Scope: Fusion.Scope<any>,
	IconName: IconAssets.IconName, -- Changed from Icon: string
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

	local displayText = scope:Computed(function(use)
		local value = use(props.Value)
		return formatNumber(value)
	end)

	return scope:New("Frame")({
		Name = "ResourcePill",
		Size = UDim2.fromOffset(width, PILL_HEIGHT + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Children] = {
			-- Shadow
			scope:New("Frame")({
				Name = "Shadow",
				Size = UDim2.fromOffset(width, PILL_HEIGHT),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = colorSet.Shadow :: Color3,
				ZIndex = 1,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),
				},
			}),

			-- Main pill
			scope:New("Frame")({
				Name = "Main",
				Size = UDim2.fromOffset(width, PILL_HEIGHT),
				BackgroundColor3 = colorSet.Main :: Color3,
				ZIndex = 2,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),

					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					}),

					-- Icon
					Icon(scope, {
						Name = props.IconName,
						Size = UDim2.fromOffset(24, 24),
						Position = UDim2.fromOffset(6, 6),
					}),

					-- Value
					scope:New("TextLabel")({
						Name = "Value",
						Size = UDim2.new(1, -40, 1, 0),
						Position = UDim2.fromOffset(32, 0),
						BackgroundTransparency = 1,
						Text = displayText,
						TextColor3 = Color3.fromRGB(80, 50, 20),
						TextSize = 16,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),
				},
			}),
		},
	})
end

return ResourcePill
