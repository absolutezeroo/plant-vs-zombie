--!strict
--[[
	NavButton.luau - Navigation button for lobby zones
	
	Atomic component for navigating between Shop, Deck, Profile, etc.
	Icon in a rounded button with Toon Pop styling.
	Uses Fusion 0.3 scope:Method() syntax.
	Fully responsive using Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Fusion primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

-- Constants (scale-based)
local SHADOW_OFFSET_SCALE = 0.08 -- 8% of button height

export type NavButtonProps = {
	Scope: any,
	Icon: string,
	Label: string?,
	OnClick: () -> (),
	Color: string?, -- Theme color key
	IsActive: any?, -- Fusion.Value<boolean>
	LayoutOrder: number?,
}

local function NavButton(props: NavButtonProps): Frame
	local scope = props.Scope
	local colorKey = props.Color or "Action"
	local colorSet = (Theme.Colors :: any)[colorKey] or Theme.Colors.Action
	
	local isPressed = scope:Value(false)
	
	-- Press animation (scale-based offset)
	local pressOffset = scope:Spring(scope:Computed(function(use)
		return if use(isPressed) then SHADOW_OFFSET_SCALE else 0
	end), 40, 0.7)
	
	-- Active state glow
	local isActive = scope:Computed(function(use)
		if props.IsActive == nil then return false end
		return use(props.IsActive)
	end)
	
	-- Outer frame takes full width, with AspectRatio < 1 to create vertical gap
	return scope:New("Frame") {
		Name = `NavButton_{props.Label or "Button"}`,
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundTransparency = 1,
		
		[Children] = {
			-- AspectRatio < 1 means height > width, creating space between buttons
			scope:New("UIAspectRatioConstraint") {
				AspectRatio = 0.82, -- Creates ~18% vertical gap
				DominantAxis = Enum.DominantAxis.Width,
			},
			
			-- Inner container for the actual button (centered with margin)
			scope:New("Frame") {
				Name = "ButtonContainer",
				Size = UDim2.fromScale(1, 0.85), -- Button takes 85%, gap is 15%
				Position = UDim2.fromScale(0.5, 0.42),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				
				[Children] = {
					-- Inner button is square
					scope:New("UIAspectRatioConstraint") {
						AspectRatio = 1,
						DominantAxis = Enum.DominantAxis.Height,
					},
					
					-- Shadow
					scope:New("Frame") {
						Name = "Shadow",
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.fromScale(0, SHADOW_OFFSET_SCALE),
						BackgroundColor3 = colorSet.Shadow :: Color3,
						ZIndex = 1,
						
						[Children] = {
							scope:New("UICorner") {
								CornerRadius = UDim.new(0.22, 0),
							},
						},
					},
					
					-- Main button
					scope:New("Frame") {
						Name = "Main",
						Size = scope:Computed(function(use)
							local offset = use(pressOffset) :: number
							return UDim2.fromScale(1, 1 - offset)
						end),
						Position = scope:Computed(function(use)
							local offset = use(pressOffset) :: number
							return UDim2.fromScale(0, offset)
						end),
						BackgroundColor3 = colorSet.Main :: Color3,
						ZIndex = 2,
						
						[Children] = {
							scope:New("UICorner") {
								CornerRadius = UDim.new(0.22, 0),
							},
							
							scope:New("UIStroke") {
								Color = scope:Computed(function(use)
									return if use(isActive) then Color3.new(1, 1, 1) else Theme.Colors.Surface.Stroke :: Color3
								end),
								Thickness = scope:Computed(function(use)
									return if use(isActive) then 4 else 2
								end),
							},
							
							-- Icon
							scope:New("TextLabel") {
								Name = "Icon",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = props.Icon,
								TextScaled = true,
								
								[Children] = {
									scope:New("UIPadding") {
										PaddingTop = UDim.new(0.15, 0),
										PaddingBottom = UDim.new(0.15, 0),
										PaddingLeft = UDim.new(0.15, 0),
										PaddingRight = UDim.new(0.15, 0),
									},
									scope:New("UITextSizeConstraint") {
										MaxTextSize = 32,
										MinTextSize = 14,
									},
								},
							},
						},
					},
					
					-- Hit area
					scope:New("TextButton") {
						Name = "HitArea",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,
						
						[OnEvent("MouseButton1Down")] = function()
							isPressed:set(true)
						end,
						
						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							props.OnClick()
						end,
						
						[OnEvent("MouseLeave")] = function()
							isPressed:set(false)
						end,
					},
				},
			},
		},
	}
end

return NavButton
