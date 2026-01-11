--!strict
--[[
	ToonButton.luau - Generic interactive button with "Toon Pop" style
	
	Atomic component providing a 3D tactile button effect.
	Features shadow layer that gets "covered" on press.
	
	Used for menus, cards, dialogs, and any interactive elements.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Design = script.Parent.Parent.Parent.design
local Theme = require(Design.Theme)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring

-- Constants
local SHADOW_OFFSET = 4
local PRESS_SPRING_SPEED = 40
local PRESS_SPRING_DAMPING = 0.7

export type ToonButtonProps = {
	Scope: Fusion.Scope<any>,
	Text: (string | Fusion.Computed<string>)?,
	OnClick: () -> (),
	Color: string?, -- Keys from Theme.Colors (e.g., "Action", "Danger"). Default: "Action"
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	Visible: (Fusion.Value<boolean> | boolean)?,
	Disabled: (Fusion.Value<boolean> | boolean)?,
	[typeof(Children)]: Fusion.Child?,
}

--[[
	ToonButton Component
	
	A tactile 3D button with press animation.
	Surface layer moves down on press to create "click" effect.
	
	@param props ToonButtonProps
	@return Frame
]]
local function ToonButton(props: ToonButtonProps): Frame
	local scope = props.Scope
	
	-- Default values
	local size = props.Size or UDim2.fromOffset(150, Theme.Layout.ButtonHeight)
	local position = props.Position or UDim2.new(0, 0, 0, 0)
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local layoutOrder = props.LayoutOrder or 0
	local zIndex = props.ZIndex or 1
	local colorKey = props.Color or "Action"
	
	-- Get color set from theme
	local colorSet = (Theme.Colors :: any)[colorKey] or Theme.Colors.Action
	
	-- Internal state
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	
	-- Compute disabled state (handle both Value and raw boolean)
	local isDisabled = Computed(scope, function(use)
		local disabled = props.Disabled
		if disabled == nil then
			return false
		end
		if type(disabled) == "boolean" then
			return disabled
		end
		-- It's a Fusion.Value
		return use(disabled :: Fusion.Value<boolean>)
	end)
	
	-- Press offset animation (0 = normal, SHADOW_OFFSET = fully pressed)
	local targetOffset = Computed(scope, function(use)
		if use(isDisabled) then
			return 0
		end
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	
	local pressOffset = Spring(scope, targetOffset, PRESS_SPRING_SPEED, PRESS_SPRING_DAMPING)
	
	-- Surface Y position (animated)
	local surfacePosition = Computed(scope, function(use)
		return UDim2.fromOffset(0, use(pressOffset))
	end)
	
	-- Surface size (shrinks slightly when pressed to match shadow)
	local surfaceSize = Computed(scope, function(use)
		local offset = use(pressOffset)
		return UDim2.new(1, 0, 1, -offset)
	end)
	
	-- Button colors with disabled state
	local mainColor = Computed(scope, function(use)
		if use(isDisabled) then
			return Color3.fromRGB(150, 150, 150) -- Grayed out
		end
		return colorSet.Main :: Color3
	end)
	
	local shadowColor = Computed(scope, function(use)
		if use(isDisabled) then
			return Color3.fromRGB(100, 100, 100) -- Darker gray
		end
		return colorSet.Shadow :: Color3
	end)
	
	local textColor = Computed(scope, function(use)
		if use(isDisabled) then
			return Color3.fromRGB(200, 200, 200)
		end
		return (colorSet.Text or Color3.new(1, 1, 1)) :: Color3
	end)
	
	return New(scope, "Frame") {
		Name = "ToonButton",
		Size = size,
		Position = position,
		AnchorPoint = anchorPoint,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		BackgroundTransparency = 1, -- Container is transparent
		Visible = if props.Visible ~= nil then props.Visible else true,
		
		[Children] = {
			-- Shadow Layer (bottom, stationary)
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = shadowColor,
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
				},
			},
			
			-- Surface Layer (top, moves down on press)
			New(scope, "TextButton") {
				Name = "Surface",
				Size = surfaceSize,
				Position = surfacePosition,
				BackgroundColor3 = mainColor,
				AutoButtonColor = false,
				ZIndex = 2,
				Text = props.Text or "",
				TextColor3 = textColor,
				Font = Theme.Typography.Fonts.Title,
				TextSize = 20,
				
				[OnEvent("MouseButton1Down")] = function()
					if Fusion.peek(isDisabled) then return end
					isPressed:set(true)
				end,
				
				[OnEvent("MouseButton1Up")] = function()
					if Fusion.peek(isDisabled) then return end
					isPressed:set(false)
					-- Only fire click if still hovered (not dragged away)
					if Fusion.peek(isHovered) then
						props.OnClick()
					end
				end,
				
				[OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,
				
				[OnEvent("MouseLeave")] = function()
					isHovered:set(false)
					isPressed:set(false) -- Release press if mouse leaves
				end,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
					
					-- White/Light stroke around surface
					New(scope, "UIStroke") {
						Color = Color3.new(1, 1, 1),
						Thickness = 2,
						Transparency = 0.5,
					},
					
					-- Text stroke for better readability
					New(scope, "UIStroke") {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						Color = shadowColor,
						Thickness = 1,
						Transparency = 0.3,
					},
					
					-- Content container for custom children
					New(scope, "Frame") {
						Name = "Content",
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						ZIndex = 3,
						
						[Children] = props[Children],
					},
				},
			},
		},
	}
end

return ToonButton
