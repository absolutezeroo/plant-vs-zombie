--!strict
--[[
	LevelBadge.luau - Player level display badge
	
	Atomic component showing player level with XP progress bar.
	Star-shaped or rounded badge with level number.
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

-- Constants
local BADGE_SIZE = 50
local SHADOW_OFFSET = 3

export type LevelBadgeProps = {
	Scope: Fusion.Scope<any>,
	Level: any, -- Fusion.Value<number>
	XP: any?, -- Fusion.Value<number> (current XP)
	XPRequired: any?, -- Fusion.Value<number> (XP needed for next level)
	Size: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

local function LevelBadge(props: LevelBadgeProps): Frame
	local scope = props.Scope
	local size = props.Size or BADGE_SIZE
	
	local levelText = Computed(scope, function(use)
		return tostring(use(props.Level))
	end)
	
	-- XP progress (0-1)
	local xpProgress = Computed(scope, function(use)
		if not props.XP or not props.XPRequired then
			return 0
		end
		local current = use(props.XP)
		local required = use(props.XPRequired)
		if required <= 0 then return 0 end
		return math.clamp(current / required, 0, 1)
	end)
	
	return New(scope, "Frame") {
		Name = "LevelBadge",
		Size = UDim2.fromOffset(size, size + SHADOW_OFFSET),
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundTransparency = 1,
		
		[Children] = {
			-- Shadow
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.fromOffset(size, size),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = Theme.Colors.Warning.Shadow,
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0, 10),
					},
				},
			},
			
			-- Main badge
			New(scope, "Frame") {
				Name = "Main",
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = Theme.Colors.Warning.Main,
				ZIndex = 2,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0, 10),
					},
					
					New(scope, "UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					},
					
					-- Star icon (top)
					New(scope, "TextLabel") {
						Name = "Star",
						Size = UDim2.fromOffset(20, 20),
						Position = UDim2.new(0.5, 0, 0, 2),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = "⭐",
						TextSize = 14,
					},
					
					-- Level number
					New(scope, "TextLabel") {
						Name = "Level",
						Size = UDim2.new(1, 0, 0.6, 0),
						Position = UDim2.fromScale(0.5, 0.55),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = levelText,
						TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
						TextSize = 22,
						Font = Theme.Typography.Fonts.Title,
					},
					
					-- XP progress bar (bottom)
					props.XP and New(scope, "Frame") {
						Name = "XPBar",
						Size = UDim2.new(0.8, 0, 0, 4),
						Position = UDim2.new(0.5, 0, 1, -8),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(100, 80, 50),
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0.5, 0),
							},
							
							-- Fill
							New(scope, "Frame") {
								Name = "Fill",
								Size = Computed(scope, function(use)
									return UDim2.new(use(xpProgress), 0, 1, 0)
								end),
								BackgroundColor3 = Theme.Colors.Action.Main,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = UDim.new(0.5, 0),
									},
								},
							},
						},
					} or nil,
				},
			},
		},
	}
end

return LevelBadge
