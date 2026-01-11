--!strict
--[[
	NavButton.luau - Navigation button for lobby zones
	
	Atomic component for navigating between Shop, Deck, Profile, etc.
	Icon + label in a rounded button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring

-- Constants
local BUTTON_SIZE = 60
local SHADOW_OFFSET = 4

export type NavButtonProps = {
	Scope: Fusion.Scope<any>,
	Icon: string,
	Label: string?,
	OnClick: () -> (),
	Color: string?, -- Theme color key
	IsActive: any?, -- Fusion.Value<boolean>
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

local function NavButton(props: NavButtonProps): Frame
	local scope = props.Scope
	local colorKey = props.Color or "Action"
	local colorSet = (Theme.Colors :: any)[colorKey] or Theme.Colors.Action
	
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	
	-- Press animation
	local targetOffset = Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	local pressOffset = Spring(scope, targetOffset, 40, 0.7)
	
	-- Active state glow
	local isActive = Computed(scope, function(use)
		if props.IsActive == nil then return false end
		return use(props.IsActive)
	end)
	
	return New(scope, "Frame") {
		Name = `NavButton_{props.Label or "Button"}`,
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE + SHADOW_OFFSET + (if props.Label then 18 else 0)),
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundTransparency = 1,
		
		[Children] = {
			-- Shadow
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = colorSet.Shadow :: Color3,
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0, 14),
					},
				},
			},
			
			-- Main button
			New(scope, "Frame") {
				Name = "Main",
				Size = Computed(scope, function(use)
					local offset = use(pressOffset)
					return UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE - offset)
				end),
				Position = Computed(scope, function(use)
					return UDim2.fromOffset(0, use(pressOffset))
				end),
				BackgroundColor3 = colorSet.Main :: Color3,
				ZIndex = 2,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0, 14),
					},
					
					New(scope, "UIStroke") {
						Color = Computed(scope, function(use)
							if use(isActive) then
								return Color3.fromRGB(255, 255, 255)
							end
							return Theme.Colors.Surface.Stroke :: Color3
						end),
						Thickness = Computed(scope, function(use)
							return if use(isActive) then 4 else 2
						end),
					},
					
					-- Icon
					New(scope, "TextLabel") {
						Name = "Icon",
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = props.Icon,
						TextSize = 28,
					},
				},
			},
			
			-- Label (optional, below button)
			props.Label and New(scope, "TextLabel") {
				Name = "Label",
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.new(0, 0, 1, -14),
				BackgroundTransparency = 1,
				Text = props.Label,
				TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
				TextSize = 11,
				Font = Theme.Typography.Fonts.Body,
				ZIndex = 3,
			} or nil,
			
			-- Hit area
			New(scope, "TextButton") {
				Name = "HitArea",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,
				
				[OnEvent("MouseButton1Down")] = function()
					isPressed:set(true)
				end,
				
				[OnEvent("MouseButton1Up")] = function()
					isPressed:set(false)
				end,
				
				[OnEvent("MouseLeave")] = function()
					isPressed:set(false)
				end,
				
				[OnEvent("Activated")] = function()
					props.OnClick()
				end,
			},
		},
	}
end

return NavButton
