--!strict
--[[
	ShovelButton.luau - Shovel tool button for removing plants
	
	Molecule component in the SeedBank for removing placed plants.
	Styled to match SeedCard with "Toon Pop" appearance.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Path: client/ui/components/molecules/ShovelButton.luau
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Spring = Fusion.Spring
local peek = Fusion.peek

-- Constants
local CARD_SIZE = 70
local SHADOW_OFFSET = 4
local ICON_SIZE = 40

-- Colors
local Colors = {
	Background = Color3.fromRGB(180, 140, 100),      -- Brown/tan
	BackgroundActive = Color3.fromRGB(220, 100, 80), -- Red-ish when active
	Shadow = Color3.fromRGB(120, 90, 60),
	ShadowActive = Color3.fromRGB(160, 60, 50),
	Stroke = Color3.fromRGB(80, 60, 40),
	Icon = Color3.fromRGB(60, 50, 40),
}

export type ShovelButtonProps = {
	Scope: Fusion.Scope<any>,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

--[[
	ShovelButton Component
	
	A button to toggle shovel mode for removing plants.
	Styled to match SeedCard appearance.
	
	@param props ShovelButtonProps
	@return Frame
]]
local function ShovelButton(props: ShovelButtonProps): Frame
	local scope = props.Scope
	local layoutOrder = props.LayoutOrder or 999 -- Last by default
	local onClick = props.OnClick
	
	-- Reactive: is shovel mode active?
	local isActive = Computed(scope, function(use)
		return use(SelectionState.ShovelMode)
	end)
	
	-- Hover state
	local isHovered = Fusion.Value(scope, false)
	
	-- Animated scale for hover/press
	local targetScale = Computed(scope, function(use)
		local active = use(isActive)
		local hovered = use(isHovered)
		if active then return 0.95 end
		if hovered then return 1.05 end
		return 1
	end)
	local animatedScale = Spring(scope, targetScale, 40, 0.6)
	
	-- Background color (changes when active)
	local bgColor = Computed(scope, function(use)
		return use(isActive) and Colors.BackgroundActive or Colors.Background
	end)
	
	local shadowColor = Computed(scope, function(use)
		return use(isActive) and Colors.ShadowActive or Colors.Shadow
	end)
	
	return New(scope, "Frame") {
		Name = "ShovelButton",
		Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		
		[Children] = {
			-- Scale container
			New(scope, "UIScale") {
				Scale = animatedScale,
			},
			
			-- Shadow layer
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = shadowColor,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0, 12),
					},
				},
			},
			
			-- Main button
			New(scope, "TextButton") {
				Name = "Button",
				Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = bgColor,
				AutoButtonColor = false,
				Text = "",
				
				[OnEvent("Activated")] = function()
					if onClick then
						onClick()
					else
						SelectionState.ToggleShovel()
					end
				end,
				
				[OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,
				
				[OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0, 12),
					},
					
					New(scope, "UIStroke") {
						Color = Colors.Stroke,
						Thickness = 3,
					},
					
					-- Shovel icon (emoji for now, could be ImageLabel)
					New(scope, "TextLabel") {
						Name = "Icon",
						Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
						Position = UDim2.new(0.5, 0, 0.5, -4),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = "🔨",
						TextSize = 32,
						Font = Enum.Font.GothamBold,
					},
					
					-- "SHOVEL" label at bottom
					New(scope, "TextLabel") {
						Name = "Label",
						Size = UDim2.new(1, 0, 0, 14),
						Position = UDim2.new(0, 0, 1, -16),
						BackgroundTransparency = 1,
						Text = "Pelle",
						TextColor3 = Colors.Icon,
						TextSize = 10,
						Font = Theme.Typography.Fonts.Title,
						TextXAlignment = Enum.TextXAlignment.Center,
					},
					
					-- Active indicator glow
					Computed(scope, function(use)
						if not use(isActive) then return nil end
						return New(scope, "UIStroke") {
							Name = "ActiveGlow",
							Color = Color3.fromRGB(255, 100, 80),
							Thickness = 4,
							Transparency = 0.3,
						}
					end),
				},
			},
		},
	}
end

return ShovelButton
