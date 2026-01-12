--!strict
--[[
	ResultBanner.luau - Victory/Defeat banner with icon (Responsive)
	
	Molecule component showing the result status at top of screen.
	Features icon (trophy/skull) and animated text.
	
	Uses Fusion 0.3 scope:Method() syntax.
	Fully responsive with Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Fusion 0.3 primitives
local Children = Fusion.Children

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
	ResultBanner Component (Responsive)
	
	Displays Victory or Defeat banner with icon.
	Uses Scale-based sizing for responsive layout.
	
	@param props ResultBannerProps
	@return Frame
]]
local function ResultBanner(props: ResultBannerProps): Frame
	local scope = props.Scope
	
	-- Animated scale for entrance
	local targetScale = scope:Computed(function()
		return 1.0
	end)
	local animatedScale = scope:Spring(targetScale, 20, 0.6)
	
	-- Dynamic colors
	local bgColor = scope:Computed(function(use)
		return if use(props.Victory) then Colors.Victory.Background else Colors.Defeat.Background
	end)
	
	local strokeColor = scope:Computed(function(use)
		return if use(props.Victory) then Colors.Victory.Stroke else Colors.Defeat.Stroke
	end)
	
	-- Icon
	local icon = scope:Computed(function(use)
		return if use(props.Victory) then "🏆" else "💀"
	end)
	
	-- Title text
	local titleText = scope:Computed(function(use)
		return if use(props.Victory) then "VICTOIRE !" else "DÉFAITE..."
	end)
	
	-- Subtitle (wave reached)
	local subtitleText = scope:Computed(function(use)
		local wave = props.WaveReached and use(props.WaveReached) or 0
		if use(props.Victory) then
			return `Toutes les vagues complétées !`
		else
			return `Vague atteinte : {wave}`
		end
	end)
	
	return scope:New("Frame") {
		Name = "ResultBanner",
		Size = UDim2.fromScale(1, 0.16), -- 16% of parent height
		BackgroundColor3 = bgColor,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint") {
				MinSize = Vector2.new(200, 50),
				MaxSize = Vector2.new(500, 80),
			},
			
			scope:New("UIScale") {
				Scale = animatedScale,
			},
			
			scope:New("UICorner") {
				CornerRadius = UDim.new(0.15, 0), -- Relative corner radius
			},
			
			scope:New("UIStroke") {
				Color = strokeColor,
				Thickness = 3,
			},
			
			-- Icon (left, square aspect)
			scope:New("TextLabel") {
				Name = "Icon",
				Size = UDim2.fromScale(0.12, 0.75),
				Position = UDim2.fromScale(0.03, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = icon,
				TextScaled = true,
				
				[Children] = {
					scope:New("UIAspectRatioConstraint") {
						AspectRatio = 1,
						DominantAxis = Enum.DominantAxis.Height,
					},
				},
			},
			
			-- Title (responsive)
			scope:New("TextLabel") {
				Name = "Title",
				Size = UDim2.fromScale(0.7, 0.5),
				Position = UDim2.fromScale(0.18, 0.12),
				BackgroundTransparency = 1,
				Text = titleText,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0.3,
				TextScaled = true,
				Font = Theme.Typography.Fonts.Title,
				TextXAlignment = Enum.TextXAlignment.Left,
				
				[Children] = {
					scope:New("UITextSizeConstraint") {
						MaxTextSize = 28,
						MinTextSize = 16,
					},
				},
			},
			
			-- Subtitle (responsive)
			scope:New("TextLabel") {
				Name = "Subtitle",
				Size = UDim2.fromScale(0.7, 0.3),
				Position = UDim2.fromScale(0.18, 0.62),
				BackgroundTransparency = 1,
				Text = subtitleText,
				TextColor3 = Color3.fromRGB(230, 230, 230),
				TextScaled = true,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
				
				[Children] = {
					scope:New("UITextSizeConstraint") {
						MaxTextSize = 14,
						MinTextSize = 10,
					},
				},
			},
		},
	}
end

return ResultBanner
