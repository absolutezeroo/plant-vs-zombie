--!strict
--[[
	XPBar.luau - Experience progress bar
	
	Atomic component showing XP progress towards next level.
	"Toon Pop" style with colored fill and text overlay.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Fusion primitives
local Children = Fusion.Children

-- Constants
local BAR_HEIGHT = 28
local SHADOW_OFFSET = 3

export type XPBarProps = {
	Scope: Fusion.Scope<any>,
	XP: any, -- Fusion.Value<number>
	XPRequired: any, -- Fusion.Value<number>
	Size: UDim2?,
	Position: UDim2?,
	LayoutOrder: number?,
}

local function XPBar(props: XPBarProps): Frame
	local scope = props.Scope
	local size = props.Size or UDim2.new(1, 0, 0, BAR_HEIGHT + SHADOW_OFFSET)

	-- Progress 0-1
	local progress = scope:Computed(function(use)
		local current = use(props.XP) or 0
		local required = use(props.XPRequired) or 100
		if required <= 0 then
			return 0
		end
		return math.clamp(current / required, 0, 1)
	end)

	-- Display text
	local displayText = scope:Computed(function(use)
		local current = use(props.XP) or 0
		local required = use(props.XPRequired) or 100
		return `{current} / {required} XP`
	end)

	return scope:New("Frame")({
		Name = "XPBar",
		Size = size,
		Position = props.Position,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Children] = {
			-- Shadow
			scope:New("Frame")({
				Name = "Shadow",
				Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = Theme.Colors.Purple.Shadow,
				ZIndex = 1,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),
				},
			}),

			-- Background bar
			scope:New("Frame")({
				Name = "Background",
				Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
				BackgroundColor3 = Theme.Colors.Surface.Shadow,
				ZIndex = 2,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),

					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					}),

					-- Fill bar
					scope:New("Frame")({
						Name = "Fill",
						Size = scope:Computed(function(use)
							return UDim2.fromScale(use(progress), 1)
						end),
						BackgroundColor3 = Theme.Colors.Purple.Main,
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.5, 0),
							}),
						},
					}),

					-- Text overlay
					scope:New("TextLabel")({
						Name = "Text",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = displayText,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 14,
						Font = Theme.Typography.Fonts.Body,
						ZIndex = 2,
					}),
				},
			}),
		},
	})
end

return XPBar
