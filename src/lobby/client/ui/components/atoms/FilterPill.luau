--!strict
--[[
	FilterPill.luau - Filter toggle button
	
	Atomic component for filter selection (All/Owned/Locked).
	"Toon Pop" style with shadow and active state.
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
local Value = Fusion.Value
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent

-- Constants
local PILL_HEIGHT = 36
local SHADOW_OFFSET = 3

export type FilterPillProps = {
	Scope: Fusion.Scope<any>,
	Text: string,
	IsActive: any, -- Fusion.Value<boolean> or Fusion.Computed<boolean>
	OnClick: () -> (),
	Width: number?,
	LayoutOrder: number?,
}

local function FilterPill(props: FilterPillProps): Frame
	local scope = props.Scope
	local width = props.Width or 85
	
	-- Press state
	local isPressed = Value(scope, false)
	
	-- Animation
	local targetOffset = Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	local pressOffset = Spring(scope, targetOffset, 40, 0.7)
	
	-- Colors based on active state
	local mainColor = Computed(scope, function(use)
		return if use(props.IsActive) then Theme.Colors.Warning.Main else Theme.Colors.Surface.Main
	end)
	
	local shadowColor = Computed(scope, function(use)
		return if use(props.IsActive) then Theme.Colors.Warning.Shadow else Theme.Colors.Surface.Shadow
	end)
	
	local textColor = Computed(scope, function(use)
		return if use(props.IsActive) then Theme.Colors.Surface.Stroke :: Color3 else Theme.Colors.Surface.Stroke :: Color3
	end)
	
	return New(scope, "Frame") {
		Name = "FilterPill",
		Size = UDim2.fromOffset(width, PILL_HEIGHT + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Shadow
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.fromOffset(width, PILL_HEIGHT),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = shadowColor,
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
				},
			},
			
			-- Main button
			New(scope, "TextButton") {
				Name = "Main",
				Size = Computed(scope, function(use)
					local offset = use(pressOffset)
					return UDim2.fromOffset(width, PILL_HEIGHT - offset)
				end),
				Position = Computed(scope, function(use)
					return UDim2.fromOffset(0, use(pressOffset))
				end),
				BackgroundColor3 = mainColor,
				Text = props.Text,
				TextColor3 = textColor,
				TextSize = 14,
				Font = Theme.Typography.Fonts.Body,
				AutoButtonColor = false,
				ZIndex = 2,
				
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
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
					
					New(scope, "UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					},
				},
			},
		},
	}
end

return FilterPill
