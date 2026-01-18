--!strict
--[[
	RewardRow.luau - Single reward display row (Responsive)
	
	Atom component showing icon + label + animated value.
	Used in result screens for coins, XP, gems, etc.
	
	SHARED component - used by both Arena and Lobby.
	
	Supports both emoji (legacy) and image assets via IconName prop.
	
	Uses Fusion 0.3 scope:Method() syntax.
	Fully responsive with Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local IconAssets = require(Shared.ui.design.IconAssets)
local Icon = require(Shared.ui.components.base.Icon)

-- Fusion 0.3 primitives
local Children = Fusion.Children

export type RewardRowProps = {
	Scope: Fusion.Scope<any>,
	Icon: string?, -- Legacy: emoji string (fallback if IconName not provided)
	IconName: IconAssets.IconName?, -- New: use IconAssets system
	Label: string,
	Value: any, -- Fusion.Value<number> or Fusion.Computed<number>
	Color: Color3?,
	LayoutOrder: number?,
	Prefix: string?,
	Suffix: string?,
	Visible: any?, -- Optional Fusion.Value<boolean> or Fusion.Computed<boolean>
}

--[[
	RewardRow Component (Responsive)
	
	Displays a single reward with icon, label and animated value.
	Uses Scale-based layout for responsive sizing.
	
	@param props RewardRowProps
	@return Frame
]]
local function RewardRow(props: RewardRowProps): Frame
	local scope = props.Scope
	local color = props.Color or Theme.Colors.Surface.Stroke
	local prefix = props.Prefix or ""
	local suffix = props.Suffix or ""

	local displayText = scope:Computed(function(use)
		local value = use(props.Value)
		return `{prefix}{value}{suffix}`
	end)

	-- Handle visibility (default true if not provided)
	local visible = if props.Visible then props.Visible else true

	return scope:New("Frame")({
		Name = `RewardRow_{props.Label}`,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = visible,

		[Children] = {
			-- Size constraint for min/max
			scope:New("UISizeConstraint")({
				MinSize = Vector2.new(150, 24),
				MaxSize = Vector2.new(400, 40),
			}),

			-- Icon (left, square aspect) - Image or emoji fallback
			scope:New("Frame")({
				Name = "IconContainer",
				Size = UDim2.fromScale(0.12, 0.9),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 1,
						DominantAxis = Enum.DominantAxis.Height,
					}),
					-- Use Icon component when IconName provided, otherwise emoji fallback
					if props.IconName then
						Icon(scope, {
							Name = props.IconName,
							Size = UDim2.fromScale(1, 1),
						})
					else
						scope:New("TextLabel")({
							Name = "Emoji",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = props.Icon or "?",
							TextScaled = true,
							Font = Enum.Font.GothamBold,

							[Children] = {
								scope:New("UITextSizeConstraint")({
									MaxTextSize = 22,
									MinTextSize = 14,
								}),
							},
						}),
				},
			}),

			-- Label (center-left)
			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(0.45, 1),
				Position = UDim2.fromScale(0.14, 0),
				BackgroundTransparency = 1,
				Text = props.Label,
				TextColor3 = Theme.Colors.Surface.Stroke,
				TextScaled = true,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						MaxTextSize = 16,
						MinTextSize = 10,
					}),
				},
			}),

			-- Value (right-aligned)
			scope:New("TextLabel")({
				Name = "Value",
				Size = UDim2.fromScale(0.38, 1),
				Position = UDim2.fromScale(1, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text = displayText,
				TextColor3 = color,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						MaxTextSize = 20,
						MinTextSize = 12,
					}),
				},
			}),
		},
	})
end

return RewardRow
