--!strict
--[[
	ToonButton.luau - Generic interactive button with "Toon Pop" style (Responsive)
	
	Atomic component providing a 3D tactile button effect.
	Features shadow layer that gets "covered" on press.
	
	Used for menus, cards, dialogs, and any interactive elements.
	
	SHARED component - used by both Arena and Lobby.
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
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Constants
local SHADOW_OFFSET_SCALE = 0.1 -- 10% of button height
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
	ToonButton Component (Responsive)
	
	A tactile 3D button with press animation.
	Surface layer moves down on press to create "click" effect.
	Uses Scale-based sizing for responsive layout.
	
	@param props ToonButtonProps
	@return Frame
]]
local function ToonButton(props: ToonButtonProps): Frame
	local scope = props.Scope
	
	-- Default values (Scale-based)
	local size = props.Size or UDim2.fromScale(0.15, 0.06)
	local position = props.Position or UDim2.new(0, 0, 0, 0)
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local layoutOrder = props.LayoutOrder or 0
	local zIndex = props.ZIndex or 1
	local colorKey = props.Color or "Action"
	
	-- Get color set from theme
	local colorSet = (Theme.Colors :: any)[colorKey] or Theme.Colors.Action
	
	-- Internal state
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)
	
	-- Compute disabled state (handle both Value and raw boolean)
	local isDisabled = scope:Computed(function(use)
		local disabled = props.Disabled
		if disabled == nil then
			return false
		end
		if type(disabled) == "boolean" then
			return disabled
		end
		return use(disabled :: Fusion.Value<boolean>)
	end)
	
	-- Press offset animation (0 = normal, SHADOW_OFFSET_SCALE = fully pressed)
	local targetOffset = scope:Computed(function(use)
		if use(isDisabled) then
			return 0
		end
		return if use(isPressed) then SHADOW_OFFSET_SCALE else 0
	end)
	
	local pressOffset = scope:Spring(targetOffset, PRESS_SPRING_SPEED, PRESS_SPRING_DAMPING)
	
	-- Surface Y position (animated, Scale-based)
	local surfacePosition = scope:Computed(function(use)
		return UDim2.fromScale(0, use(pressOffset))
	end)
	
	-- Surface size (shrinks slightly when pressed to match shadow)
	local surfaceSize = scope:Computed(function(use)
		local offset = use(pressOffset)
		return UDim2.fromScale(1, 1 - offset)
	end)
	
	-- Button colors with disabled state
	local mainColor = scope:Computed(function(use)
		if use(isDisabled) then
			return Color3.fromRGB(150, 150, 150)
		end
		return colorSet.Main :: Color3
	end)
	
	local shadowColor = scope:Computed(function(use)
		if use(isDisabled) then
			return Color3.fromRGB(100, 100, 100)
		end
		return colorSet.Shadow :: Color3
	end)
	
	local textColor = scope:Computed(function(use)
		if use(isDisabled) then
			return Color3.fromRGB(200, 200, 200)
		end
		return (colorSet.Text or Color3.new(1, 1, 1)) :: Color3
	end)
	
	return scope:New("Frame") {
		Name = "ToonButton",
		Size = size,
		Position = position,
		AnchorPoint = anchorPoint,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		BackgroundTransparency = 1,
		Visible = if props.Visible ~= nil then props.Visible else true,
		
		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint") {
				MinSize = Vector2.new(80, 30),
				MaxSize = Vector2.new(300, 60),
			},
			
			-- Shadow Layer (bottom, stationary, Scale-based)
			scope:New("Frame") {
				Name = "Shadow",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, SHADOW_OFFSET_SCALE),
				BackgroundColor3 = shadowColor,
				ZIndex = 1,
				
				[Children] = {
					scope:New("UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
				},
			},
			
			-- Surface Layer (top, animated)
			scope:New("Frame") {
				Name = "Surface",
				Size = surfaceSize,
				Position = surfacePosition,
				BackgroundColor3 = mainColor,
				ZIndex = 2,
				
				[Children] = {
					scope:New("UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
					
					scope:New("UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = Theme.Layout.StrokeThickness,
					},
					
					-- Text label (responsive)
					scope:New("TextLabel") {
						Name = "Label",
						Size = UDim2.new(1, -16, 1, 0),
						Position = UDim2.fromOffset(8, 0),
						BackgroundTransparency = 1,
						Text = props.Text or "",
						TextColor3 = textColor,
						TextScaled = true,
						Font = Theme.Typography.Fonts.Title,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						
						[Children] = {
							scope:New("UITextSizeConstraint") {
								MaxTextSize = 20,
								MinTextSize = 10,
							},
						},
					},
					
					-- Children content
					props[Children] and scope:New("Frame") {
						Name = "Content",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 2,
						[Children] = props[Children],
					} or nil,
				},
			},
			
			-- Invisible hit area
			scope:New("TextButton") {
				Name = "HitArea",
				Size = UDim2.fromScale(1, 1 + SHADOW_OFFSET_SCALE),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,
				
				[OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,
				
				[OnEvent("MouseLeave")] = function()
					isHovered:set(false)
					isPressed:set(false)
				end,
				
				[OnEvent("MouseButton1Down")] = function()
					if not peek(isDisabled) then
						isPressed:set(true)
					end
				end,
				
				[OnEvent("MouseButton1Up")] = function()
					isPressed:set(false)
				end,
				
				[OnEvent("Activated")] = function()
					if not peek(isDisabled) then
						props.OnClick()
					end
				end,
			},
		},
	}
end

return ToonButton
