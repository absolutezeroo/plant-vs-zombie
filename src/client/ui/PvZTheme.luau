--!strict
--[[
	PvZTheme.luau - Plants vs Zombies visual theme system
	
	Provides consistent styling across all UI components:
	- Color palette (wood, grass, accent colors)
	- Reusable component builders (panels, buttons, text)
	- Icon mappings
	
	Style inspired by classic PvZ aesthetic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local PvZTheme = {}

-- ============================================
-- COLOR PALETTE
-- ============================================

PvZTheme.Colors = {
	-- Primary backgrounds
	WoodBrown = Color3.fromRGB(139, 90, 43),      -- Main panel background
	WoodDark = Color3.fromRGB(101, 67, 33),       -- Panel borders/shadows
	WoodLight = Color3.fromRGB(181, 137, 85),     -- Highlights
	
	-- Garden accents
	GrassGreen = Color3.fromRGB(76, 175, 80),     -- Positive/nature elements
	LeafGreen = Color3.fromRGB(56, 142, 60),      -- Darker green
	SkyBlue = Color3.fromRGB(135, 206, 235),      -- Sky/water elements
	
	-- Currency/resource colors
	SunYellow = Color3.fromRGB(255, 215, 0),      -- Sun currency
	CoinGold = Color3.fromRGB(255, 193, 7),       -- Coins
	GemCyan = Color3.fromRGB(0, 229, 255),        -- Gems
	XPPurple = Color3.fromRGB(156, 39, 176),      -- Experience
	
	-- UI states
	HealthRed = Color3.fromRGB(244, 67, 54),      -- Health/damage
	HealthGreen = Color3.fromRGB(76, 175, 80),    -- Full health
	Disabled = Color3.fromRGB(100, 100, 100),     -- Disabled elements
	
	-- Text colors
	TextWhite = Color3.fromRGB(255, 255, 255),
	TextDark = Color3.fromRGB(50, 30, 10),
	TextGold = Color3.fromRGB(255, 220, 100),
	
	-- Overlay
	OverlayDark = Color3.fromRGB(0, 0, 0),
	Victory = Color3.fromRGB(255, 215, 0),
	Defeat = Color3.fromRGB(139, 0, 0),
}

-- ============================================
-- ICONS (Emoji for now, can be replaced with ImageLabels)
-- ============================================

PvZTheme.Icons = {
	Sun = "☀️",
	Coin = "🪙",
	Gem = "💎",
	Star = "⭐",
	Heart = "❤️",
	Wave = "🌊",
	Shop = "🛒",
	Plant = "🌱",
	Zombie = "🧟",
	Trophy = "🏆",
	Skull = "💀",
	Lock = "🔒",
	Check = "✅",
	Arrow = "➤",
	PlantFood = "🌟",
}

-- ============================================
-- COMPONENT BUILDERS
-- ============================================

-- Create a wood-style panel frame
function PvZTheme.WoodPanel(scope: any, props: {
	Name: string?,
	Position: UDim2?,
	Size: UDim2,
	AnchorPoint: Vector2?,
	children: {any}?,
}): Frame
	return New(scope, "Frame")({
		Name = props.Name or "WoodPanel",
		Position = props.Position or UDim2.fromScale(0, 0),
		Size = props.Size,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = PvZTheme.Colors.WoodBrown,
		BorderSizePixel = 0,
		
		[Children] = {
			-- Corner rounding
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
			
			-- Border stroke
			New(scope, "UIStroke")({
				Color = PvZTheme.Colors.WoodDark,
				Thickness = 3,
			}),
			
			-- Inner gradient for depth
			New(scope, "UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
				}),
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.8),
					NumberSequenceKeypoint.new(1, 0.95),
				}),
			}),
			
			-- Children
			unpack(props.children or {}),
		},
	})
end

-- Create a grass-accent panel (for positive/action areas)
function PvZTheme.GrassPanel(scope: any, props: {
	Name: string?,
	Position: UDim2?,
	Size: UDim2,
	AnchorPoint: Vector2?,
	children: {any}?,
}): Frame
	return New(scope, "Frame")({
		Name = props.Name or "GrassPanel",
		Position = props.Position or UDim2.fromScale(0, 0),
		Size = props.Size,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = PvZTheme.Colors.GrassGreen,
		BorderSizePixel = 0,
		
		[Children] = {
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 10) }),
			New(scope, "UIStroke")({
				Color = PvZTheme.Colors.LeafGreen,
				Thickness = 2,
			}),
			unpack(props.children or {}),
		},
	})
end

-- Create PvZ-style text with stroke
function PvZTheme.StrokedText(scope: any, props: {
	Name: string?,
	Position: UDim2?,
	Size: UDim2?,
	AnchorPoint: Vector2?,
	Text: any, -- Can be string or Computed
	TextColor3: Color3?,
	Font: Enum.Font?,
	TextScaled: boolean?,
	TextXAlignment: Enum.TextXAlignment?,
}): TextLabel
	return New(scope, "TextLabel")({
		Name = props.Name or "StrokedText",
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromScale(1, 1),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = props.Text,
		TextColor3 = props.TextColor3 or PvZTheme.Colors.TextWhite,
		Font = props.Font or Enum.Font.GothamBold,
		TextScaled = if props.TextScaled ~= nil then props.TextScaled else true,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		
		[Children] = {
			-- Black stroke for readability
			New(scope, "UIStroke")({
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 2,
			}),
		},
	})
end

-- Create a wood-style button
function PvZTheme.WoodButton(scope: any, props: {
	Name: string?,
	Position: UDim2?,
	Size: UDim2,
	AnchorPoint: Vector2?,
	Text: string,
	TextColor3: Color3?,
	OnClick: () -> ()?,
	Disabled: any?, -- Can be boolean or Computed
}): TextButton
	return New(scope, "TextButton")({
		Name = props.Name or "WoodButton",
		Position = props.Position or UDim2.fromScale(0, 0),
		Size = props.Size,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = PvZTheme.Colors.GrassGreen,
		BorderSizePixel = 0,
		Text = props.Text,
		TextColor3 = props.TextColor3 or PvZTheme.Colors.TextWhite,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
		
		[OnEvent("Activated")] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,
		
		[Children] = {
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 10) }),
			New(scope, "UIStroke")({
				Color = PvZTheme.Colors.LeafGreen,
				Thickness = 3,
			}),
			New(scope, "UITextSizeConstraint")({
				MaxTextSize = 24,
			}),
			-- Text stroke
			New(scope, "TextLabel")({
				Name = "ButtonTextStroke",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = props.Text,
				TextColor3 = props.TextColor3 or PvZTheme.Colors.TextWhite,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
				ZIndex = 2,
				[Children] = {
					New(scope, "UIStroke")({
						Color = Color3.fromRGB(0, 0, 0),
						Thickness = 2,
					}),
					New(scope, "UITextSizeConstraint")({
						MaxTextSize = 24,
					}),
				},
			}),
		},
	})
end

-- Create a currency display row (icon + value)
function PvZTheme.CurrencyRow(scope: any, props: {
	Name: string?,
	Icon: string,
	Value: any, -- Computed or Value
	Color: Color3,
	Size: UDim2?,
}): Frame
	local Computed = Fusion.Computed
	
	return New(scope, "Frame")({
		Name = props.Name or "CurrencyRow",
		Size = props.Size or UDim2.new(1, 0, 0, 35),
		BackgroundTransparency = 1,
		
		[Children] = {
			-- Icon
			New(scope, "TextLabel")({
				Name = "Icon",
				Position = UDim2.fromOffset(5, 0),
				Size = UDim2.new(0, 30, 1, 0),
				BackgroundTransparency = 1,
				Text = props.Icon,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
			}),
			
			-- Value
			PvZTheme.StrokedText(scope, {
				Name = "Value",
				Position = UDim2.new(0, 40, 0.5, 0),
				Size = UDim2.new(1, -45, 0.8, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Text = Computed(scope, function(use)
					local val = use(props.Value)
					return tostring(val)
				end),
				TextColor3 = props.Color,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

-- Create a progress bar
function PvZTheme.ProgressBar(scope: any, props: {
	Name: string?,
	Position: UDim2?,
	Size: UDim2,
	AnchorPoint: Vector2?,
	Progress: any, -- Computed 0-1
	FillColor: Color3?,
	BackgroundColor: Color3?,
}): Frame
	local Computed = Fusion.Computed
	
	return New(scope, "Frame")({
		Name = props.Name or "ProgressBar",
		Position = props.Position or UDim2.fromScale(0, 0),
		Size = props.Size,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.BackgroundColor or PvZTheme.Colors.WoodDark,
		BorderSizePixel = 0,
		
		[Children] = {
			New(scope, "UICorner")({ CornerRadius = UDim.new(1, 0) }),
			
			-- Fill bar
			New(scope, "Frame")({
				Name = "Fill",
				Size = Computed(scope, function(use)
					local progress = use(props.Progress)
					return UDim2.fromScale(math.clamp(progress, 0, 1), 1)
				end),
				BackgroundColor3 = props.FillColor or PvZTheme.Colors.GrassGreen,
				BorderSizePixel = 0,
				
				[Children] = {
					New(scope, "UICorner")({ CornerRadius = UDim.new(1, 0) }),
				},
			}),
		},
	})
end

-- Create a banner-style header
function PvZTheme.Banner(scope: any, props: {
	Name: string?,
	Position: UDim2?,
	Size: UDim2,
	AnchorPoint: Vector2?,
	Text: any,
	TextColor3: Color3?,
}): Frame
	return New(scope, "Frame")({
		Name = props.Name or "Banner",
		Position = props.Position or UDim2.fromScale(0.5, 0),
		Size = props.Size,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		BackgroundColor3 = PvZTheme.Colors.WoodBrown,
		BorderSizePixel = 0,
		
		[Children] = {
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
			New(scope, "UIStroke")({
				Color = PvZTheme.Colors.WoodDark,
				Thickness = 3,
			}),
			
			PvZTheme.StrokedText(scope, {
				Name = "BannerText",
				Text = props.Text,
				TextColor3 = props.TextColor3 or PvZTheme.Colors.TextGold,
			}),
		},
	})
end

return PvZTheme
