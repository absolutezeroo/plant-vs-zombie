--!strict
--[[
	PlantCounter.luau - Displays current/max plant count with "Toon Pop" style (Responsive)
	
	Molecule component that shows the player's plant count vs limit.
	Connects internally to SelectionState for reactive updates.
	
	Visual: Compact rounded container with plant icon + text (e.g. "5/45")
	Animation: Text "pops" (Spring scale) when plant count changes
	
	Fully responsive using Scale-based sizing.
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Path: client/ui/components/molecules/PlantCounter.luau
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local IconAssets = require(Shared.ui.design.IconAssets)

local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local peek = Fusion.peek

-- Colors (green theme for plants)
local Colors = {
	Background = Color3.fromRGB(60, 100, 50), -- Forest green
	Icon = Color3.fromRGB(130, 220, 80), -- Bright plant green
	Text = Color3.fromRGB(255, 255, 255), -- White text
	TextWarning = Color3.fromRGB(255, 180, 80), -- Orange when near limit
	TextFull = Color3.fromRGB(255, 100, 100), -- Red when at limit
	Stroke = Color3.fromRGB(40, 60, 30), -- Dark green stroke
}

export type PlantCounterProps = {
	Scope: Fusion.Scope<any>,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

--[[
	PlantCounter Component (Responsive)
	
	Displays the current plant count / limit in a compact container.
	Automatically subscribes to SelectionState.PlantCount and PlantLimit.
	
	@param props PlantCounterProps
	@return Frame
]]
local function PlantCounter(props: PlantCounterProps): Frame
	local scope = props.Scope

	-- Track previous plant count for pop animation trigger
	local previousCount = scope:Value(peek(SelectionState.PlantCount))
	local popScale = scope:Value(1)

	-- Animate the pop scale with a spring
	local animatedScale = scope:Spring(popScale, 30, 0.6)

	-- Computed plant text (reacts to SelectionState.PlantCount and PlantLimit)
	local plantText = scope:Computed(function(use): string
		local current = use(SelectionState.PlantCount)
		local limit = use(SelectionState.PlantLimit)
		local prev = peek(previousCount)

		-- Trigger pop animation when count changes
		if current ~= prev then
			popScale:set(1.2)
			task.defer(function()
				popScale:set(1)
			end)
		end

		-- Update previous value
		previousCount:set(current)

		return `{current}/{limit}`
	end)

	-- Text color based on how close to limit
	local textColor = scope:Computed(function(use): Color3
		local current = use(SelectionState.PlantCount)
		local limit = use(SelectionState.PlantLimit)
		local ratio = current / math.max(limit, 1)

		if ratio >= 1 then
			return Colors.TextFull -- Red at limit
		elseif ratio >= 0.8 then
			return Colors.TextWarning -- Orange near limit
		end
		return Colors.Text -- White normal
	end)

	return scope:New("Frame")({
		Name = "PlantCounter",
		Position = props.Position or UDim2.fromScale(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Size = UDim2.fromScale(0.065, 1), -- 6.5% width of screen, full height of parent
		BackgroundColor3 = Colors.Background,
		LayoutOrder = props.LayoutOrder or 0,

		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint")({
				MinSize = Vector2.new(60, 32),
				MaxSize = Vector2.new(100, 50),
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

			-- Plant icon (left)
			scope:New("Frame")({
				Name = "PlantIcon",
				Size = UDim2.fromScale(0.35, 0.8),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					scope:New("ImageLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = IconAssets.Get("Plant"),
						ScaleType = Enum.ScaleType.Fit,
						Visible = IconAssets.HasImage("Plant"),
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = IconAssets.GetEmoji("Plant"),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
						Visible = not IconAssets.HasImage("Plant"),

						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 22,
								MinTextSize = 12,
							}),
						},
					}),
				},
			}),

			-- Plant count text
			scope:New("TextLabel")({
				Name = "PlantAmount",
				Size = UDim2.fromScale(0.55, 0.8),
				Position = UDim2.fromScale(0.4, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = plantText,
				TextColor3 = textColor,
				TextStrokeColor3 = Colors.Stroke,
				TextStrokeTransparency = 0.5,
				Font = Theme.Typography.Fonts.Title,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						MaxTextSize = 18,
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

return PlantCounter
