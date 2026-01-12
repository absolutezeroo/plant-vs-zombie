--!strict
--[[
	StarRating.luau - Animated star rating display (Responsive)
	
	Molecule component showing 1-3 stars with reveal animation.
	Stars appear sequentially with pop effect.
	
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

export type StarRatingProps = {
	Scope: Fusion.Scope<any>,
	StarCount: any, -- Fusion.Value<number> (0-3)
	Visible: any?, -- Fusion.Value<boolean>
	LayoutOrder: number?,
}

-- Individual animated star (responsive)
local function AnimatedStar(scope: Fusion.Scope<any>, index: number, starCount: any): Frame
	-- State for this star (1=empty, 2=filled)
	local starState = scope:Computed(function(use)
		local count = use(starCount)
		if count >= index then
			return 2 -- Filled
		else
			return 1 -- Empty
		end
	end)
	
	-- Scale animation
	local targetScale = scope:Computed(function(use)
		local state = use(starState)
		return if state == 2 then 1.0 else 0.8
	end)
	local animatedScale = scope:Spring(targetScale, 25, 0.5)
	
	return scope:New("Frame") {
		Name = `Star{index}`,
		Size = UDim2.fromScale(0.28, 0.8), -- Responsive within parent
		BackgroundTransparency = 1,
		LayoutOrder = index,
		
		[Children] = {
			-- Keep square aspect ratio
			scope:New("UIAspectRatioConstraint") {
				AspectRatio = 1,
				DominantAxis = Enum.DominantAxis.Height,
			},
			
			scope:New("UIScale") {
				Scale = animatedScale,
			},
			
			scope:New("TextLabel") {
				Name = "StarIcon",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					local state = use(starState)
					return if state == 2 then "⭐" else "☆"
				end),
				TextColor3 = scope:Computed(function(use)
					local state = use(starState)
					return if state == 2 
						then Color3.fromRGB(255, 215, 0) 
						else Color3.fromRGB(150, 150, 150)
				end),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
			},
		},
	}
end

--[[
	StarRating Component (Responsive)
	
	Displays 3 stars that fill based on rating.
	Uses Scale-based sizing for responsive layout.
	
	@param props StarRatingProps
	@return Frame
]]
local function StarRating(props: StarRatingProps): Frame
	local scope = props.Scope
	local visible = props.Visible or scope:Value(true)
	
	return scope:New("Frame") {
		Name = "StarRating",
		Size = UDim2.fromScale(1, 0.15), -- 15% of parent height
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = scope:Computed(function(use)
			return use(visible)
		end),
		
		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint") {
				MinSize = Vector2.new(120, 40),
				MaxSize = Vector2.new(300, 70),
			},
			
			-- Center layout with responsive padding
			scope:New("UIListLayout") {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.03, 0), -- 3% padding between stars
			},
			
			-- 3 Stars
			AnimatedStar(scope, 1, props.StarCount),
			AnimatedStar(scope, 2, props.StarCount),
			AnimatedStar(scope, 3, props.StarCount),
		},
	}
end

return StarRating
