--!strict
--[[
	WinRateBanner.luau - Win rate display banner
	
	Atomic component showing win rate percentage with dynamic color.
	"Toon Pop" style with shadow effect.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Fusion primitives
local Children = Fusion.Children

-- Constants
local BANNER_HEIGHT = 60
local SHADOW_OFFSET = 4

export type WinRateBannerProps = {
	Scope: Fusion.Scope<any>,
	GamesWon: any, -- Fusion.Value<number>
	GamesPlayed: any, -- Fusion.Value<number>
	Size: UDim2?,
	LayoutOrder: number?,
}

local function WinRateBanner(props: WinRateBannerProps): Frame
	local scope = props.Scope
	local size = props.Size or UDim2.new(1, 0, 0, BANNER_HEIGHT + SHADOW_OFFSET)

	-- Calculate win rate (0-1)
	local winRate = scope:Computed(function(use)
		local won = use(props.GamesWon) or 0
		local played = use(props.GamesPlayed) or 0
		if played == 0 then
			return 0
		end
		return won / played
	end)

	-- Color based on rate
	local colorSet = scope:Computed(function(use)
		local rate = use(winRate)
		if rate >= 0.7 then
			return Theme.Colors.Action -- Green
		elseif rate >= 0.4 then
			return Theme.Colors.Warning -- Orange
		else
			return Theme.Colors.Danger -- Red
		end
	end)

	-- Display text
	local displayText = scope:Computed(function(use)
		local played = use(props.GamesPlayed) or 0
		if played == 0 then
			return "🎯 Win Rate: Play some games!"
		end
		local rate = math.floor(use(winRate) * 100)
		local emoji = if rate >= 70 then "🔥" elseif rate >= 40 then "👍" else "💪"
		return `{emoji} Win Rate: {rate}%`
	end)

	return scope:New("Frame")({
		Name = "WinRateBanner",
		Size = size,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		[Children] = {
			-- Shadow
			scope:New("Frame")({
				Name = "Shadow",
				Size = UDim2.new(1, 0, 0, BANNER_HEIGHT),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = scope:Computed(function(use)
					return use(colorSet).Shadow :: Color3
				end),
				ZIndex = 1,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Layout.CornerRadius,
					}),
				},
			}),

			-- Main banner
			scope:New("Frame")({
				Name = "Main",
				Size = UDim2.new(1, 0, 0, BANNER_HEIGHT),
				BackgroundColor3 = scope:Computed(function(use)
					return use(colorSet).Main :: Color3
				end),
				ZIndex = 2,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Layout.CornerRadius,
					}),

					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = Theme.Layout.StrokeThickness,
					}),

					-- Text
					scope:New("TextLabel")({
						Name = "Text",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = displayText,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 20,
						Font = Theme.Typography.Fonts.Title,
					}),
				},
			}),
		},
	})
end

return WinRateBanner
