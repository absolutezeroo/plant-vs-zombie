--!strict
--[[
	SunCounter.luau - Displays current sun amount with "Toon Pop" style
	
	Molecule component that shows the player's sun currency.
	Connects internally to SelectionState for reactive sun updates.
	
	Visual: Compact rounded container with sun icon + text
	Animation: Text "pops" (Spring scale) when sun amount increases
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Path: client/ui/components/molecules/SunCounter.luau
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local peek = Fusion.peek

-- Constants
local ICON_SIZE = 28
local CONTAINER_WIDTH = 90  -- Fixed width to prevent layout shifts
local CONTAINER_HEIGHT = 40
local CONTAINER_PADDING = 6

-- Colors
local Colors = {
	Background = Color3.fromRGB(80, 60, 40),     -- Dark brown
	Icon = Color3.fromRGB(255, 220, 50),         -- Sun yellow
	Text = Color3.fromRGB(255, 255, 255),        -- White text
	Stroke = Color3.fromRGB(50, 40, 30),         -- Dark stroke
}

export type SunCounterProps = {
	Scope: Fusion.Scope<any>,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

--[[
	SunCounter Component
	
	Displays the current sun amount in a compact container.
	Automatically subscribes to SelectionState.SunCount.
	
	@param props SunCounterProps
	@return Frame
]]
local function SunCounter(props: SunCounterProps): Frame
	local scope = props.Scope
	
	-- Track previous sun value for pop animation trigger
	local previousSun = Value(scope, peek(SelectionState.SunCount))
	local popScale = Value(scope, 1)
	
	-- Animate the pop scale with a spring
	local animatedScale = Spring(scope, popScale, 30, 0.6)
	
	-- Computed sun text (reacts to SelectionState.SunCount)
	local sunText = Computed(scope, function(use): string
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
	
	return New(scope, "Frame") {
		Name = "SunCounter",
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Size = UDim2.fromOffset(CONTAINER_WIDTH, CONTAINER_HEIGHT),
		BackgroundColor3 = Colors.Background,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Rounded corners
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 10),
			},
			
			-- Stroke
			New(scope, "UIStroke") {
				Color = Colors.Stroke,
				Thickness = 2,
			},
			
			-- Sun icon (left)
			New(scope, "TextLabel") {
				Name = "SunIcon",
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				Position = UDim2.new(0, CONTAINER_PADDING, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = "☀️",
				TextSize = 20,
				Font = Enum.Font.GothamBold,
			},
			
			-- Sun amount text
			New(scope, "TextLabel") {
				Name = "SunAmount",
				Size = UDim2.new(1, -ICON_SIZE - CONTAINER_PADDING * 2, 1, 0),
				Position = UDim2.new(0, ICON_SIZE + CONTAINER_PADDING, 0, 0),
				BackgroundTransparency = 1,
				Text = sunText,
				TextColor3 = Colors.Text,
				TextStrokeColor3 = Colors.Stroke,
				TextStrokeTransparency = 0.5,
				Font = Theme.Typography.Fonts.Title,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				
				[Children] = {
					-- Scale transform for pop animation
					New(scope, "UIScale") {
						Scale = animatedScale,
					},
				},
			},
		},
	}
end

return SunCounter
