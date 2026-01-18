--!strict
--[[
	PlantFoodCounter.luau - Displays Plant Food charges with glowing effect
	
	Molecule component that shows 0-3 Plant Food charges.
	Click to activate Plant Food mode (then click a plant to boost).
	
	Visual: Green glowing orbs (filled = charge available)
	Animation: Pulse glow when charges change, shake when clicked
	
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Colors
local Colors = {
	Background = Color3.fromRGB(30, 50, 30), -- Dark green
	ChargeEmpty = Color3.fromRGB(50, 70, 50), -- Dim green
	ChargeFull = Color3.fromRGB(100, 255, 100), -- Bright green glow
	ChargeGlow = Color3.fromRGB(150, 255, 150), -- Glowing highlight
	ActiveBorder = Color3.fromRGB(255, 255, 100), -- Yellow when mode active
	Stroke = Color3.fromRGB(20, 40, 20), -- Dark stroke
}

export type PlantFoodCounterProps = {
	Scope: Fusion.Scope<any>,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

--[[
	Create a single charge orb
]]
local function ChargeOrb(scope: any, index: number, isFilled: any, isActive: any): Frame
	-- Pulse animation when filled
	local glowSize = scope:Spring(
		scope:Computed(function(use)
			return if use(isFilled) then 1.1 else 1.0
		end),
		25, 0.5
	)

	local orbColor = scope:Computed(function(use): Color3
		if use(isFilled) then
			return if use(isActive) then Colors.ChargeGlow else Colors.ChargeFull
		end
		return Colors.ChargeEmpty
	end)

	return scope:New("Frame")({
		Name = `Charge{index}`,
		Size = UDim2.fromScale(0.28, 0.7),
		BackgroundColor3 = orbColor,
		BackgroundTransparency = 0,

		[Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0.5, 0),
			}),

			scope:New("UIStroke")({
				Color = Colors.Stroke,
				Thickness = 1,
			}),

			-- Glow effect
			scope:New("UIScale")({
				Scale = glowSize,
			}),

			-- Inner highlight
			scope:New("Frame")({
				Name = "Highlight",
				Size = UDim2.fromScale(0.4, 0.4),
				Position = UDim2.fromScale(0.2, 0.15),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = scope:Computed(function(use)
					return if use(isFilled) then 0.6 else 0.9
				end),

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),
				},
			}),
		},
	})
end

--[[
	PlantFoodCounter Component
	
	Displays 3 charge orbs and toggles Plant Food mode on click.
	
	@param props PlantFoodCounterProps
	@return Frame
]]
local function PlantFoodCounter(props: PlantFoodCounterProps): Frame
	local scope = props.Scope

	-- Track charge count reactively
	local chargeCount = SelectionState.PlantFoodCharges
	local isActive = SelectionState.PlantFoodMode

	-- Border color changes when mode is active
	local borderColor = scope:Computed(function(use): Color3
		return if use(isActive) then Colors.ActiveBorder else Colors.Stroke
	end)

	local borderThickness = scope:Computed(function(use): number
		return if use(isActive) then 3 else 2
	end)

	-- Create charge orbs
	local chargeOrbs = {}
	for i = 1, 3 do
		local isFilled = scope:Computed(function(use)
			return use(chargeCount) >= i
		end)
		chargeOrbs[i] = ChargeOrb(scope, i, isFilled, isActive)
	end

	return scope:New("Frame")({
		Name = "PlantFoodCounter",
		Position = props.Position or UDim2.fromScale(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Size = UDim2.fromScale(0.07, 1), -- 7% width
		BackgroundColor3 = Colors.Background,
		LayoutOrder = props.LayoutOrder or 0,

		[OnEvent("InputBegan")] = function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 
				or input.UserInputType == Enum.UserInputType.Touch then
				SelectionState.TogglePlantFoodMode()
			end
		end,

		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint")({
				MinSize = Vector2.new(70, 32),
				MaxSize = Vector2.new(110, 50),
			}),

			-- Rounded corners
			scope:New("UICorner")({
				CornerRadius = UDim.new(0.3, 0),
			}),

			-- Animated border
			scope:New("UIStroke")({
				Color = borderColor,
				Thickness = borderThickness,
			}),

			-- Padding
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0.05, 0),
				PaddingRight = UDim.new(0.05, 0),
				PaddingTop = UDim.new(0.1, 0),
				PaddingBottom = UDim.new(0.1, 0),
			}),

			-- Horizontal layout for orbs
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.03, 0),
			}),

			-- Charge orbs
			chargeOrbs[1],
			chargeOrbs[2],
			chargeOrbs[3],
		},
	})
end

return PlantFoodCounter
