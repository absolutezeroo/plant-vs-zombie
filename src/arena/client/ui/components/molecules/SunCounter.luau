--!strict
--[[
	SunCounter.luau - Displays current sun amount with "Toon Pop" style
	
	Molecule component that shows the player's sun currency.
	Connects internally to SelectionState for reactive sun updates.
	
	Visual: Rounded pill with sun icon + animated text
	Animation: Text "pops" (Spring scale) when sun amount increases
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Path: client/ui/components/molecules/SunCounter.luau
-- script.Parent = molecules, Parent.Parent = components, Parent.Parent.Parent = ui, Parent.Parent.Parent.Parent = client
local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

local Design = script.Parent.Parent.Parent.design
local Theme = require(Design.Theme)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local peek = Fusion.peek

-- Constants
local SUN_ICON_ID = "rbxassetid://6764432293" -- Default sun icon
local ICON_SIZE = 32
local CONTAINER_HEIGHT = 44
local CONTAINER_PADDING = 8
local TEXT_COLOR = Color3.fromHex("#FFD700") -- Golden yellow

export type SunCounterProps = {
	Scope: Fusion.Scope<any>,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

--[[
	SunCounter Component
	
	Displays the current sun amount in a pill-shaped container.
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
			popScale:set(1.25)
			task.defer(function()
				popScale:set(1)
			end)
		end
		
		-- Update previous value
		previousSun:set(current)
		
		return tostring(current)
	end)
	
	-- Container size computed based on text width (min width for small numbers)
	local containerWidth = Computed(scope, function(use): UDim
		local text = use(sunText)
		local charCount = #text
		-- Base width: icon + padding + text space
		local textWidth = math.max(30, charCount * 18)
		return UDim.new(0, ICON_SIZE + CONTAINER_PADDING * 3 + textWidth)
	end)
	
	return New(scope, "Frame") {
		Name = "SunCounter",
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Size = Computed(scope, function(use)
			return UDim2.new(use(containerWidth), UDim.new(0, CONTAINER_HEIGHT))
		end),
		BackgroundColor3 = Theme.Colors.Surface.Shadow,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Rounded corners (pill shape)
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, CONTAINER_HEIGHT / 2),
			},
			
			-- Thick cartoon outline
			New(scope, "UIStroke") {
				Color = Theme.Colors.Surface.Stroke :: Color3,
				Thickness = Theme.Layout.StrokeThickness,
			},
			
			-- Padding inside container
			New(scope, "UIPadding") {
				PaddingLeft = UDim.new(0, CONTAINER_PADDING),
				PaddingRight = UDim.new(0, CONTAINER_PADDING),
			},
			
			-- Horizontal layout
			New(scope, "UIListLayout") {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, CONTAINER_PADDING),
			},
			
			-- Sun emoji icon (temporary for testing)
			New(scope, "TextLabel") {
				Name = "SunIcon",
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				BackgroundTransparency = 1,
				Text = "☀️",
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextColor3 = TEXT_COLOR,
				LayoutOrder = 1,
			},
			
			-- Sun amount text with pop animation
			New(scope, "TextLabel") {
				Name = "SunAmount",
				Size = UDim2.new(1, -ICON_SIZE - CONTAINER_PADDING, 1, 0),
				BackgroundTransparency = 1,
				Text = sunText,
				TextColor3 = TEXT_COLOR,
				TextStrokeColor3 = Theme.Colors.Surface.Stroke :: Color3,
				TextStrokeTransparency = 0,
				Font = Theme.Typography.Fonts.Title,
				TextSize = 28,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
				
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
