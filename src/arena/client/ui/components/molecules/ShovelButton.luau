--!strict
--[[
	ShovelButton.luau - Shovel tool toggle button (Arena - Responsive)
	
	Molecule component for the shovel tool that removes planted plants.
	Toggles shovel mode when clicked via SelectionState.
	
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Path: client/ui/components/molecules/ShovelButton.luau
local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Shovel icon as text (can be replaced with image)
local SHOVEL_ICON = "🔨" -- Or use ImageLabel with shovel image

export type ShovelButtonProps = {
	Scope: Fusion.Scope<any>,
	LayoutOrder: number?,
}

--[[
	ShovelButton Component (Arena - Responsive)
	
	A toggleable button that activates shovel mode for removing plants.
	Highlights when active, animated press effect.
	
	@param props ShovelButtonProps
	@return Frame
]]
local function ShovelButton(props: ShovelButtonProps): Frame
	local scope = props.Scope
	local layoutOrder = props.LayoutOrder or 999
	
	-- Internal state
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)
	
	-- Reactive: Is shovel mode active?
	local isShovelActive = scope:Computed(function(use)
		return use(SelectionState.ShovelMode)
	end)
	
	-- Border color based on active state
	local borderColor = scope:Computed(function(use)
		if use(isShovelActive) then
			return Color3.fromHex("#FF6B35") -- Orange when active
		end
		return Theme.Colors.Surface.Stroke :: Color3
	end)
	
	-- Border thickness when active
	local borderThickness = scope:Computed(function(use)
		if use(isShovelActive) then
			return 4
		end
		return Theme.Layout.StrokeThickness
	end)
	
	-- Press animation (as percentage)
	local pressOffset = scope:Spring(scope:Computed(function(use)
		return if use(isPressed) then 0.06 else 0
	end), 40, 0.7)
	
	-- Scale animation for hover
	local hoverScale = scope:Spring(scope:Computed(function(use)
		if use(isPressed) then return 0.95 end
		if use(isHovered) then return 1.05 end
		return 1
	end), 35, 0.7)
	
	-- Card background color
	local cardColor = scope:Computed(function(use)
		if use(isShovelActive) then
			return Color3.fromRGB(255, 200, 150) -- Light orange when active
		end
		return Theme.Colors.Surface.Main
	end)
	
	local shadowColor = Theme.Colors.Surface.Shadow
	
	-- Toggle shovel mode
	local function toggleShovel()
		SelectionState.ToggleShovel()
	end
	
	return scope:New("Frame") {
		Name = "ShovelButton",
		Size = UDim2.fromScale(1, 1), -- Size determined by parent grid
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		
		[Children] = {
			-- Aspect ratio constraint (square)
			scope:New("UIAspectRatioConstraint") {
				AspectRatio = 1,
			},
			
			-- Scale container for hover animation
			scope:New("Frame") {
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				
				[Children] = {
					scope:New("UIScale") { Scale = hoverScale },
					
					-- Shadow Layer (6% offset)
					scope:New("Frame") {
						Name = "Shadow",
						Size = UDim2.fromScale(1, 0.94),
						Position = UDim2.fromScale(0, 0.06),
						BackgroundColor3 = shadowColor,
						ZIndex = 1,
						
						[Children] = {
							scope:New("UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
						},
					},
					
					-- Surface Layer (interactive)
					scope:New("TextButton") {
						Name = "Surface",
						Size = scope:Computed(function(use)
							local offset = use(pressOffset)
							return UDim2.fromScale(1, 0.94 - offset)
						end),
						Position = scope:Computed(function(use)
							return UDim2.fromScale(0, use(pressOffset))
						end),
						BackgroundColor3 = cardColor,
						AutoButtonColor = false,
						Text = "",
						ZIndex = 2,
						
						[OnEvent("MouseButton1Down")] = function()
							isPressed:set(true)
						end,
						
						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							if peek(isHovered) then
								toggleShovel()
							end
						end,
						
						[OnEvent("MouseEnter")] = function()
							isHovered:set(true)
						end,
						
						[OnEvent("MouseLeave")] = function()
							isHovered:set(false)
							isPressed:set(false)
						end,
						
						[Children] = {
							scope:New("UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
							
							-- Dynamic border (orange when active)
							scope:New("UIStroke") {
								Color = borderColor,
								Thickness = borderThickness,
							},
							
							-- Shovel Icon
							scope:New("TextLabel") {
								Name = "ShovelIcon",
								Size = UDim2.fromScale(0.7, 0.7),
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Text = SHOVEL_ICON,
								TextScaled = true,
								Font = Enum.Font.GothamBold,
								TextColor3 = scope:Computed(function(use)
									return if use(isShovelActive)
										then Color3.fromHex("#FF6B35")
										else Color3.new(0.3, 0.3, 0.3)
								end),
								ZIndex = 3,
								
								[Children] = {
									scope:New("UITextSizeConstraint") {
										MaxTextSize = 40,
										MinTextSize = 12,
									},
								},
							},
							
							-- "Active" indicator label
							scope:Computed(function(use)
								if use(isShovelActive) then
									return scope:New("TextLabel") {
										Name = "ActiveLabel",
										Size = UDim2.fromScale(1, 0.2),
										Position = UDim2.fromScale(0.5, 0.95),
										AnchorPoint = Vector2.new(0.5, 1),
										BackgroundTransparency = 1,
										Text = "ACTIVE",
										TextScaled = true,
										Font = Enum.Font.GothamBold,
										TextColor3 = Color3.fromHex("#FF6B35"),
										ZIndex = 4,
										
										[Children] = {
											scope:New("UITextSizeConstraint") {
												MaxTextSize = 10,
												MinTextSize = 6,
											},
										},
									}
								else
									return nil
								end
							end),
						},
					},
				},
			},
		},
	}
end

return ShovelButton
