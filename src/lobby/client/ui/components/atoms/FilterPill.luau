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
local Children = Fusion.Children
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
	local isPressed = scope:Value(false)
	
	-- Animation
	local targetOffset = scope:Computed(function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	local pressOffset = scope:Spring(targetOffset, 40, 0.7)
	
	-- Colors based on active state
	local mainColor = scope:Computed(function(use)
		return if use(props.IsActive) then Theme.Colors.Warning.Main else Theme.Colors.Surface.Main
	end)
	
	local shadowColor = scope:Computed(function(use)
		return if use(props.IsActive) then Theme.Colors.Warning.Shadow else Theme.Colors.Surface.Shadow
	end)
	
	local textColor = scope:Computed(function(use)
		return if use(props.IsActive) then Theme.Colors.Surface.Stroke :: Color3 else Theme.Colors.Surface.Stroke :: Color3
	end)
	
	return scope:New("Frame") {
		Name = "FilterPill",
		Size = UDim2.fromOffset(width, PILL_HEIGHT + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Shadow
			scope:New("Frame") {
				Name = "Shadow",
				Size = UDim2.fromOffset(width, PILL_HEIGHT),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = shadowColor,
				ZIndex = 1,
				
				[Children] = {
					scope:New("UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
				},
			},
			
			-- Main button
			scope:New("TextButton") {
				Name = "Main",
				Size = scope:Computed(function(use)
					local offset = use(pressOffset)
					return UDim2.fromOffset(width, PILL_HEIGHT - offset)
				end),
				Position = scope:Computed(function(use)
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
					scope:New("UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
					
					scope:New("UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					},
				},
			},
		},
	}
end

return FilterPill
