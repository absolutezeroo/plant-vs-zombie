--!strict
--[[
	ResultBanner.luau - Victory/Defeat banner with icon
	
	Molecule component showing the result status at top of screen.
	Features icon (trophy/skull) and animated text.
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
local Spring = Fusion.Spring

-- Constants
local BANNER_HEIGHT = 60

-- Colors
local Colors = {
	Victory = {
		Background = Color3.fromRGB(100, 180, 80),  -- Green
		Stroke = Color3.fromRGB(60, 120, 50),
	},
	Defeat = {
		Background = Color3.fromRGB(180, 60, 60),   -- Red
		Stroke = Color3.fromRGB(120, 40, 40),
	},
}

export type ResultBannerProps = {
	Scope: Fusion.Scope<any>,
	Victory: any, -- Fusion.Value<boolean>
	WaveReached: any?, -- Fusion.Value<number>
	LayoutOrder: number?,
}

--[[
	ResultBanner Component
	
	Displays Victory or Defeat banner with icon.
	
	@param props ResultBannerProps
	@return Frame
]]
local function ResultBanner(props: ResultBannerProps): Frame
	local scope = props.Scope
	
	-- Animated scale for entrance
	local targetScale = Computed(scope, function(use)
		return 1.0
	end)
	local animatedScale = Spring(scope, targetScale, 20, 0.6)
	
	-- Dynamic colors
	local bgColor = Computed(scope, function(use)
		return if use(props.Victory) then Colors.Victory.Background else Colors.Defeat.Background
	end)
	
	local strokeColor = Computed(scope, function(use)
		return if use(props.Victory) then Colors.Victory.Stroke else Colors.Defeat.Stroke
	end)
	
	-- Icon
	local icon = Computed(scope, function(use)
		return if use(props.Victory) then "🏆" else "💀"
	end)
	
	-- Title text
	local titleText = Computed(scope, function(use)
		return if use(props.Victory) then "VICTOIRE !" else "DÉFAITE..."
	end)
	
	-- Subtitle (wave reached)
	local subtitleText = Computed(scope, function(use)
		local wave = props.WaveReached and use(props.WaveReached) or 0
		if use(props.Victory) then
			return `Toutes les vagues complétées !`
		else
			return `Vague atteinte : {wave}`
		end
	end)
	
	return New(scope, "Frame") {
		Name = "ResultBanner",
		Size = UDim2.new(1, 0, 0, BANNER_HEIGHT),
		BackgroundColor3 = bgColor,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			New(scope, "UIScale") {
				Scale = animatedScale,
			},
			
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 12),
			},
			
			New(scope, "UIStroke") {
				Color = strokeColor,
				Thickness = 3,
			},
			
			-- Icon (left)
			New(scope, "TextLabel") {
				Name = "Icon",
				Size = UDim2.fromOffset(45, 45),
				Position = UDim2.new(0, 10, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = icon,
				TextScaled = true,
			},
			
			-- Title (center-left)
			New(scope, "TextLabel") {
				Name = "Title",
				Size = UDim2.new(0.6, 0, 0, 28),
				Position = UDim2.new(0, 65, 0, 8),
				BackgroundTransparency = 1,
				Text = titleText,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0.3,
				TextSize = 26,
				Font = Theme.Typography.Fonts.Title,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			
			-- Subtitle
			New(scope, "TextLabel") {
				Name = "Subtitle",
				Size = UDim2.new(0.6, 0, 0, 18),
				Position = UDim2.new(0, 65, 0, 36),
				BackgroundTransparency = 1,
				Text = subtitleText,
				TextColor3 = Color3.fromRGB(230, 230, 230),
				TextSize = 13,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		},
	}
end

return ResultBanner
