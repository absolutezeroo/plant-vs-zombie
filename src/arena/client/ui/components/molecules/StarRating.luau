--!strict
--[[
	StarRating.luau - Animated star rating display
	
	Molecule component showing 1-3 stars with reveal animation.
	Stars appear sequentially with pop effect.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

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
local STAR_SIZE = 50
local STAR_SPACING = 10

export type StarRatingProps = {
	Scope: Fusion.Scope<any>,
	StarCount: any, -- Fusion.Value<number> (0-3)
	Visible: any?, -- Fusion.Value<boolean>
	LayoutOrder: number?,
}

-- Individual animated star
local function AnimatedStar(scope: any, index: number, starCount: any): Frame
	-- State for this star (0=hidden, 1=empty, 2=filled)
	local starState = Computed(scope, function(use)
		local count = use(starCount)
		if count >= index then
			return 2 -- Filled
		else
			return 1 -- Empty
		end
	end)
	
	-- Scale animation
	local targetScale = Computed(scope, function(use)
		local state = use(starState)
		return if state == 2 then 1.0 else 0.8
	end)
	local animatedScale = Spring(scope, targetScale, 25, 0.5)
	
	return New(scope, "Frame") {
		Name = `Star{index}`,
		Size = UDim2.fromOffset(STAR_SIZE, STAR_SIZE),
		BackgroundTransparency = 1,
		LayoutOrder = index,
		
		[Children] = {
			New(scope, "UIScale") {
				Scale = animatedScale,
			},
			
			New(scope, "TextLabel") {
				Name = "StarIcon",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = Computed(scope, function(use)
					local state = use(starState)
					return if state == 2 then "⭐" else "☆"
				end),
				TextColor3 = Computed(scope, function(use)
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
	StarRating Component
	
	Displays 3 stars that fill based on rating.
	
	@param props StarRatingProps
	@return Frame
]]
local function StarRating(props: StarRatingProps): Frame
	local scope = props.Scope
	local visible = props.Visible or Value(scope, true)
	
	return New(scope, "Frame") {
		Name = "StarRating",
		Size = UDim2.new(1, 0, 0, STAR_SIZE + 10),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = Computed(scope, function(use)
			return use(visible)
		end),
		
		[Children] = {
			-- Center layout
			New(scope, "UIListLayout") {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, STAR_SPACING),
			},
			
			-- 3 Stars
			AnimatedStar(scope, 1, props.StarCount),
			AnimatedStar(scope, 2, props.StarCount),
			AnimatedStar(scope, 3, props.StarCount),
		},
	}
end

return StarRating
