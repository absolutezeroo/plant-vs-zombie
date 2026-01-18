--!strict
--[[
	SunCounter.luau - Displays current sun amount with "Toon Pop" style (Responsive)
	
	Molecule component that shows the player's sun currency.
	Connects internally to SelectionState for reactive sun updates.
	
	Visual: Compact rounded container with sun icon + text
	Animation: Text "pops" (Spring scale) when sun amount increases
	
	Fully responsive using Scale-based sizing.
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Path: client/ui/components/molecules/SunCounter.luau
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local IconAssets = require(Shared.ui.design.IconAssets)

local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local peek = Fusion.peek

-- Colors
local Colors = {
	Background = Color3.fromRGB(80, 60, 40), -- Dark brown
	Icon = Color3.fromRGB(255, 220, 50), -- Sun yellow
	Text = Color3.fromRGB(255, 255, 255), -- White text
	Stroke = Color3.fromRGB(50, 40, 30), -- Dark stroke
}

export type SunCounterProps = {
	Scope: Fusion.Scope<any>,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

--[[
	SunCounter Component (Responsive)
	
	Displays the current sun amount in a compact container.
	Automatically subscribes to SelectionState.SunCount.
	
	@param props SunCounterProps
	@return Frame
]]
local function SunCounter(props: SunCounterProps): Frame
	local scope = props.Scope

	-- Track previous sun value for pop animation trigger
	local previousSun = scope:Value(peek(SelectionState.SunCount))
	local popScale = scope:Value(1)

	-- Animate the pop scale with a spring
	local animatedScale = scope:Spring(popScale, 30, 0.6)

	-- Computed sun text (reacts to SelectionState.SunCount)
	local sunText = scope:Computed(function(use): string
		local current = use(SelectionState.SunCount)
		local prev = peek(previousSun)

		-- Trigger pop animation when sun increases
		if current > prev then
			popScale:set(1.2)
			task.defer(function()
				popScale:set(1)
			end)
		end

		-- Update previous value
		previousSun:set(current)

		-- Format large numbers (1000+ becomes 1.0K, etc.)
		if current >= 10000 then
			return string.format("%.0fK", current / 1000)
		elseif current >= 1000 then
			return string.format("%.1fK", current / 1000)
		end
		return tostring(current)
	end)

	return scope:New("Frame")({
		Name = "SunCounter",
		Position = props.Position or UDim2.fromScale(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Size = UDim2.fromScale(0.08, 1), -- 8% width of screen, full height of parent
		BackgroundColor3 = Colors.Background,
		LayoutOrder = props.LayoutOrder or 0,

		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint")({
				MinSize = Vector2.new(70, 32),
				MaxSize = Vector2.new(120, 50),
			}),

			-- Rounded corners
			scope:New("UICorner")({
				CornerRadius = UDim.new(0.3, 0),
			}),

			-- Stroke
			scope:New("UIStroke")({
				Color = Colors.Stroke,
				Thickness = 2,
			}),

			-- Padding
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0.08, 0),
				PaddingRight = UDim.new(0.08, 0),
			}),

			-- Sun icon (left) - Uses ImageLabel with emoji fallback
			scope:New("Frame")({
				Name = "SunIcon",
				Size = UDim2.fromScale(0.35, 0.8),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					-- Image version (shown when asset is uploaded)
					scope:New("ImageLabel")({
						Name = "Image",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = IconAssets.Get("Sun"),
						ImageColor3 = Colors.Icon,
						ScaleType = Enum.ScaleType.Fit,
						Visible = IconAssets.HasImage("Sun"),
					}),
					-- Emoji fallback (shown when no image asset)
					scope:New("TextLabel")({
						Name = "Emoji",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = IconAssets.GetEmoji("Sun"),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
						Visible = not IconAssets.HasImage("Sun"),

						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 22,
								MinTextSize = 12,
							}),
						},
					}),
				},
			}),

			-- Sun amount text
			scope:New("TextLabel")({
				Name = "SunAmount",
				Size = UDim2.fromScale(0.55, 0.8),
				Position = UDim2.fromScale(0.4, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = sunText,
				TextColor3 = Colors.Text,
				TextStrokeColor3 = Colors.Stroke,
				TextStrokeTransparency = 0.5,
				Font = Theme.Typography.Fonts.Title,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						MaxTextSize = 20,
						MinTextSize = 10,
					}),
					-- Scale transform for pop animation
					scope:New("UIScale")({
						Scale = animatedScale,
					}),
				},
			}),
		},
	})
end

return SunCounter
