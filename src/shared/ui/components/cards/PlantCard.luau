--!strict
--[[
	PlantCard.luau - Modular plant card component
	
	A highly configurable card component for displaying plants.
	Can be used in Shop, DeckBuilder, Collection, or anywhere else.
	
	Features (all optional):
	- 3D Plant viewport
	- Background effect image
	- Plant name
	- Sun cost pill
	- Category label
	- Action button (buy, select, etc.)
	- Badge indicators
	- Hover/Press animations
	- Lock overlay
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local PlantData = require(Shared.data.PlantData)
local PlantViewport = require(Shared.ui.components.cards.PlantViewport)
local Icon = require(Shared.ui.components.base.Icon)

-- Fusion primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Default constants
local DEFAULT_SHADOW_OFFSET = 4
local DEFAULT_VIEWPORT_HEIGHT = 80

--[[ 
	Configuration Types
]]

export type ViewportConfig = {
	Size: UDim2?, -- Full override for viewport size
	Position: UDim2?, -- Full override for viewport position
	Height: number?, -- Deprecated: use Size instead for offset mode
	CameraFOV: number?,
	CameraDistance: number?,
	CameraHeight: number?,
}

export type BackgroundConfig = {
	Image: string,
	ImageColor3: Color3?,
	ImageTransparency: number?,
	Size: UDim2?, -- Override size (default: slightly larger than viewport)
	Position: UDim2?, -- Override position
}

export type NameConfig = {
	Show: boolean?,
	Size: UDim2?,
	Position: UDim2?,
	TextSize: number?,
	TextScaled: boolean?, -- Use TextScaled instead of fixed TextSize
	TextColor3: Color3?,
}

export type SunCostConfig = {
	Show: boolean?,
	Value: number?, -- Override from PlantData
	Size: UDim2?,
	Position: UDim2?,
}

export type CategoryConfig = {
	Show: boolean?,
	Position: UDim2?,
}

export type ActionButtonConfig = {
	Show: boolean?,
	Text: string?,
	Icon: string?, -- Icon name
	BackgroundColor3: Color3 | any, -- Can be Fusion.Computed
	TextColor3: Color3 | any,
	OnActivated: () -> (),
	Disabled: any?, -- Fusion.Value<boolean>
}

export type BadgeConfig = {
	Show: boolean?,
	Text: string?,
	Icon: string?,
	BackgroundColor3: Color3?,
	TextColor3: Color3?,
	Position: UDim2?,
}

export type PlantCardProps = {
	Scope: Fusion.Scope<any>,
	PlantType: string,
	
	-- Size configuration
	Size: UDim2?, -- Card size (default: 160x220)
	ShadowOffset: number?, -- Shadow depth in pixels (default: 4) - for Offset mode
	ShadowOffsetScale: number?, -- Shadow depth as scale 0-1 (e.g. 0.03) - for Scale mode
	UseScale: boolean?, -- Use Scale-based layout instead of Offset (for responsive grids)
	
	-- Feature toggles
	ShowViewport: boolean?, -- Default: true
	ShowShadow: boolean?, -- Default: true
	ShowHoverAnimation: boolean?, -- Default: true
	IsLocked: boolean?, -- Shows lock overlay
	
	-- Modular configs (nil = hidden)
	Viewport: ViewportConfig?,
	Background: BackgroundConfig?,
	Name: NameConfig?,
	SunCost: SunCostConfig?,
	Category: CategoryConfig?,
	ActionButton: ActionButtonConfig?,
	TopBadge: BadgeConfig?,
	BottomBadge: BadgeConfig?,
	
	-- Styling
	BackgroundColor3: Color3 | any?, -- Main card bg (Fusion.Value/Computed supported)
	BorderColor: Color3 | any?, -- Border color (Fusion.Value/Computed supported)
	
	-- Events
	OnClick: (() -> ())?,
	OnHover: ((isHovered: boolean) -> ())?,
	
	-- Layout
	LayoutOrder: number?,
}

--[[
	Main Component
]]
local function PlantCard(props: PlantCardProps): Frame
	local scope = props.Scope
	local plantType = props.PlantType
	local plantStats = PlantData[plantType] or PlantData.GetStats(plantType)
	
	-- Resolve defaults
	local cardWidth = 160
	local cardHeight = 220
	if props.Size then
		-- Extract from UDim2 if provided as offset
		cardWidth = props.Size.X.Offset > 0 and props.Size.X.Offset or cardWidth
		cardHeight = props.Size.Y.Offset > 0 and props.Size.Y.Offset or cardHeight
	end
	
	-- Scale mode vs Offset mode
	local useScale = props.UseScale or false
	local shadowOffset = props.ShadowOffset or DEFAULT_SHADOW_OFFSET
	local shadowOffsetScale = props.ShadowOffsetScale or 0.03 -- 3% default for scale mode
	
	local viewportHeight = (props.Viewport and props.Viewport.Height) or DEFAULT_VIEWPORT_HEIGHT
	local showViewport = props.ShowViewport ~= false
	local showShadow = props.ShowShadow ~= false
	local showHoverAnim = props.ShowHoverAnimation ~= false
	local isLocked = props.IsLocked or false
	
	-- State
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)
	
	-- Animations (only if enabled)
	local hoverScale = scope:Value(1)
	local pressOffset = scope:Value(0)
	
	if showHoverAnim then
		local targetScale = scope:Computed(function(use)
			if isLocked then return 1 end
			if use(isPressed) then return 0.95 end
			if use(isHovered) then return 1.03 end
			return 1
		end)
		hoverScale = scope:Spring(targetScale, 35, 0.7)
		
		local targetOffset = scope:Computed(function(use)
			if useScale then
				return if use(isPressed) then shadowOffsetScale else 0
			else
				return if use(isPressed) then shadowOffset else 0
			end
		end)
		pressOffset = scope:Spring(targetOffset, 40, 0.7)
	end
	
	-- Border color (use provided or default)
	local borderColor = props.BorderColor or scope:Computed(function(use)
		if use(isHovered) and not isLocked then
			return Theme.Colors.Action.Main
		end
		return Theme.Colors.Surface.Stroke :: Color3
	end)
	
	-- Background color
	local bgColor = props.BackgroundColor3 or Theme.Colors.Surface.Main
	
	-- Build children array
	local cardChildren: { any } = {
		scope:New("UICorner")({
			CornerRadius = Theme.Layout.CornerRadius,
		}),
		
		scope:New("UIStroke")({
			Color = borderColor,
			Thickness = Theme.Layout.StrokeThickness,
		}),
	}
	
	-- Background effect (optional)
	if props.Background then
		local bg = props.Background
		table.insert(cardChildren, scope:New("ImageLabel")({
			Name = "PlantBg",
			Size = bg.Size or UDim2.new(1, 20, 0, viewportHeight + 30),
			Position = bg.Position or UDim2.new(0.5, 0, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = bg.Image,
			ImageColor3 = bg.ImageColor3 or Color3.new(1, 1, 1),
			ImageTransparency = bg.ImageTransparency or 0,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		}))
	end
	
	-- 3D Viewport (optional but default on)
	if showViewport and not isLocked then
		local vp = props.Viewport or {}
		local vpSize = vp.Size or UDim2.new(1, -10, 0, viewportHeight)
		local vpPos = vp.Position or UDim2.new(0.5, 0, 0, 25)
		
		table.insert(cardChildren, PlantViewport.CreateWithScope(scope, {
			PlantType = plantType,
			Size = vpSize,
			Position = vpPos,
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 4,
			CameraFOV = vp.CameraFOV or 30,
			CameraDistance = vp.CameraDistance or 1.8,
			CameraHeight = vp.CameraHeight or 0.15,
		}))
	end
	
	-- Plant name (optional)
	if props.Name and props.Name.Show ~= false then
		local nameConfig = props.Name
		local nameChildren: { any } = {}
		
		-- Add text size constraint if using TextScaled
		if nameConfig.TextScaled then
			table.insert(nameChildren, scope:New("UITextSizeConstraint")({
				MaxTextSize = nameConfig.TextSize or 14,
				MinTextSize = 8,
			}))
		end
		
		table.insert(cardChildren, scope:New("TextLabel")({
			Name = "PlantName",
			Size = nameConfig.Size or UDim2.new(1, -12, 0, 22),
			Position = nameConfig.Position or UDim2.fromOffset(6, viewportHeight + 25),
			BackgroundTransparency = 1,
			Text = plantType,
			TextColor3 = nameConfig.TextColor3 or Theme.Colors.Surface.Stroke :: Color3,
			TextSize = if nameConfig.TextScaled then nil else (nameConfig.TextSize or 14),
			TextScaled = nameConfig.TextScaled or false,
			Font = Theme.Typography.Fonts.Title,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 5,
			
			[Children] = #nameChildren > 0 and nameChildren or nil,
		}))
	end
	
	-- Category (optional)
	if props.Category and props.Category.Show ~= false and plantStats then
		local catConfig = props.Category
		table.insert(cardChildren, scope:New("TextLabel")({
			Name = "Category",
			Size = UDim2.new(1, 0, 0, 14),
			Position = catConfig.Position or UDim2.fromOffset(0, viewportHeight + 46),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Text = plantStats.Category or "",
			TextColor3 = Theme.Colors.Surface.Shadow,
			TextSize = 10,
			Font = Theme.Typography.Fonts.Body,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 5,
		}))
	end
	
	-- Sun cost pill (optional)
	if props.SunCost and props.SunCost.Show ~= false then
		local sunConfig = props.SunCost
		local sunValue = sunConfig.Value or (plantStats and plantStats.Cost) or 100
		table.insert(cardChildren, scope:New("Frame")({
			Name = "SunCost",
			Size = sunConfig.Size or UDim2.fromOffset(50, 20),
			Position = sunConfig.Position or UDim2.new(0.5, 0, 0, viewportHeight + 70),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Theme.Colors.Warning.Main,
			ZIndex = 6,
			
			[Children] = {
				scope:New("UICorner")({
					CornerRadius = UDim.new(0.5, 0),
				}),
				scope:New("TextLabel")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = `☀️ {sunValue}`,
					TextColor3 = Color3.fromRGB(80, 50, 20),
					TextSize = 11,
					Font = Enum.Font.GothamBold,
				}),
			},
		}))
	end
	
	-- Top badge (optional, supports reactive Computed<BadgeConfig?>)
	if props.TopBadge then
		-- Resolve badge config (may be Computed or static table)
		local badgeVisible = scope:Computed(function(use)
			local badge = if typeof(props.TopBadge) == "table" and (props.TopBadge :: any).get 
				then use(props.TopBadge) 
				else props.TopBadge
			return badge ~= nil and badge.Show ~= false
		end)
		
		local badgeBgColor = scope:Computed(function(use)
			local badge = if typeof(props.TopBadge) == "table" and (props.TopBadge :: any).get 
				then use(props.TopBadge) 
				else props.TopBadge
			return if badge then (badge.BackgroundColor3 or Theme.Colors.Action.Main) else Theme.Colors.Action.Main
		end)
		
		local badgeIcon = scope:Computed(function(use)
			local badge = if typeof(props.TopBadge) == "table" and (props.TopBadge :: any).get 
				then use(props.TopBadge) 
				else props.TopBadge
			return if badge then badge.Icon else nil
		end)
		
		table.insert(cardChildren, scope:New("Frame")({
			Name = "TopBadge",
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.new(1, -6, 0, 6),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = badgeBgColor,
			Visible = badgeVisible,
			ZIndex = 8,
			
			[Children] = {
				scope:New("UICorner")({
					CornerRadius = UDim.new(0.5, 0),
				}),
				scope:New("TextLabel")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "✓",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					Visible = scope:Computed(function(use)
						return use(badgeIcon) == "Check"
					end),
				}),
			},
		}))
	end
	
	-- Bottom badge / info (optional)
	if props.BottomBadge and props.BottomBadge.Show ~= false then
		local badge = props.BottomBadge
		table.insert(cardChildren, scope:New("Frame")({
			Name = "BottomBadge",
			Size = UDim2.new(1, -16, 0, 28),
			Position = badge.Position or UDim2.new(0, 8, 1, -36),
			BackgroundColor3 = badge.BackgroundColor3 or Theme.Colors.Action.Shadow,
			ZIndex = 7,
			
			[Children] = {
				scope:New("UICorner")({
					CornerRadius = UDim.new(0, 8),
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 4),
				}),
				badge.Icon and Icon(scope, {
					Name = badge.Icon,
					Size = UDim2.fromOffset(14, 14),
					Color = badge.TextColor3 or Theme.Colors.Action.Main,
				}) or nil,
				badge.Text and scope:New("TextLabel")({
					Size = UDim2.fromOffset(60, 18),
					BackgroundTransparency = 1,
					Text = badge.Text,
					TextColor3 = badge.TextColor3 or Theme.Colors.Action.Main,
					TextSize = 11,
					Font = Theme.Typography.Fonts.Body,
					TextXAlignment = Enum.TextXAlignment.Left,
				}) or nil,
			},
		}))
	end
	
	-- Action button (optional)
	if props.ActionButton and props.ActionButton.Show ~= false then
		local btn = props.ActionButton
		local isDisabled = btn.Disabled or scope:Value(false)
		
		table.insert(cardChildren, scope:New("TextButton")({
			Name = "ActionButton",
			Size = UDim2.new(1, -16, 0, 36),
			Position = UDim2.new(0, 8, 1, -44),
			BackgroundColor3 = btn.BackgroundColor3,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 10,
			
			[OnEvent("Activated")] = function()
				if not peek(isDisabled) then
					btn.OnActivated()
				end
			end,
			
			[Children] = {
				scope:New("UICorner")({
					CornerRadius = UDim.new(0, 8),
				}),
				scope:New("UIStroke")({
					Color = Theme.Colors.Surface.Stroke :: Color3,
					Thickness = 2,
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 4),
				}),
				btn.Icon and Icon(scope, {
					Name = btn.Icon,
					Size = UDim2.fromOffset(18, 18),
				}) or nil,
				btn.Text and scope:New("TextLabel")({
					Name = "ButtonText",
					Size = UDim2.fromOffset(50, 20),
					BackgroundTransparency = 1,
					Text = btn.Text,
					TextColor3 = btn.TextColor3,
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}) or nil,
			},
		}))
	end
	
	-- Lock overlay (if locked)
	if isLocked then
		table.insert(cardChildren, scope:New("Frame")({
			Name = "LockOverlay",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			ZIndex = 20,
			
			[Children] = {
				scope:New("UICorner")({
					CornerRadius = Theme.Layout.CornerRadius,
				}),
				scope:New("Frame")({
					Size = UDim2.fromOffset(32, 32),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					[Children] = {
						Icon(scope, {
							Name = "Lock",
							Size = UDim2.fromScale(1, 1),
						}),
					},
				}),
			},
		}))
	end
	
	-- Click/Hover handler
	table.insert(cardChildren, scope:New("TextButton")({
		Name = "ClickHandler",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 15,
		
		[OnEvent("Activated")] = function()
			if not isLocked and props.OnClick then
				props.OnClick()
			end
		end,
		
		[OnEvent("MouseEnter")] = function()
			if not isLocked then
				isHovered:set(true)
				if props.OnHover then
					props.OnHover(true)
				end
			end
		end,
		
		[OnEvent("MouseLeave")] = function()
			isHovered:set(false)
			isPressed:set(false)
			if props.OnHover then
				props.OnHover(false)
			end
		end,
		
		[OnEvent("MouseButton1Down")] = function()
			if not isLocked then
				isPressed:set(true)
			end
		end,
		
		[OnEvent("MouseButton1Up")] = function()
			isPressed:set(false)
		end,
	}))
	
	-- Build the card structure
	-- Shadow and Main sizing depends on mode (Scale vs Offset)
	local shadowSize, shadowPos, mainSize, mainPos
	
	if useScale then
		-- Scale mode: use percentages
		shadowSize = UDim2.fromScale(1, 1 - shadowOffsetScale)
		shadowPos = UDim2.fromScale(0, shadowOffsetScale)
		mainSize = scope:Computed(function(use)
			local offset = use(pressOffset)
			return UDim2.fromScale(1, 1 - shadowOffsetScale - offset)
		end)
		mainPos = scope:Computed(function(use)
			return UDim2.fromScale(0, use(pressOffset))
		end)
	else
		-- Offset mode: use pixels
		shadowSize = UDim2.new(1, 0, 1, -shadowOffset)
		shadowPos = UDim2.fromOffset(0, shadowOffset)
		mainSize = scope:Computed(function(use)
			local offset = use(pressOffset)
			return UDim2.new(1, 0, 1, -shadowOffset - offset)
		end)
		mainPos = scope:Computed(function(use)
			return UDim2.fromOffset(0, use(pressOffset))
		end)
	end
	
	return scope:New("Frame")({
		Name = plantType,
		Size = props.Size or UDim2.fromOffset(cardWidth, cardHeight + shadowOffset),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Scale container for hover animation
			scope:New("Frame")({
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				
				[Children] = {
					scope:New("UIScale")({ Scale = hoverScale }),
					
					-- Shadow (optional)
					showShadow and scope:New("Frame")({
						Name = "Shadow",
						Size = shadowSize,
						Position = shadowPos,
						BackgroundColor3 = Theme.Colors.Surface.Shadow,
						ZIndex = 1,
						
						[Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Layout.CornerRadius,
							}),
						},
					}) or nil,
					
					-- Main card
					scope:New("Frame")({
						Name = "Main",
						Size = mainSize,
						Position = mainPos,
						BackgroundColor3 = bgColor,
						ClipsDescendants = true,
						ZIndex = 2,
						
						[Children] = cardChildren,
					}),
				},
			}),
		},
	})
end

return PlantCard
