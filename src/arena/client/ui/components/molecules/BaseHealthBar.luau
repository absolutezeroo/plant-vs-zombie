--!strict
--[[
	BaseHealthBar.luau - Visual health bar for the player's base (house)
	
	Molecule component showing the base's remaining health.
	Features animated fill bar with damage flash effect.
	
	Subscribes to GameSignals.OnBaseHealthChanged for reactive updates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameSignals = require(Shared.signals.GameSignals)

local Design = script.Parent.Parent.Parent.design
local Theme = require(Design.Theme)

local Atoms = script.Parent.Parent.atoms
local ToonPanel = require(Atoms.ToonPanel)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local peek = Fusion.peek

-- Constants
local BAR_HEIGHT = 20
local BAR_WIDTH = 200
local ICON_SIZE = 28
local FILL_CORNER_RADIUS = UDim.new(0, 6)

-- Colors
local FILL_COLOR_HEALTHY = Color3.fromRGB(80, 200, 80) -- Green when healthy
local FILL_COLOR_DAMAGED = Color3.fromRGB(255, 180, 50) -- Orange when damaged
local FILL_COLOR_CRITICAL = Color3.fromRGB(220, 60, 60) -- Red when critical
local TRACK_COLOR = Color3.fromRGB(60, 40, 40) -- Dark track

export type BaseHealthBarProps = {
	Scope: Fusion.Scope<any>,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
}

--[[
	BaseHealthBar Component
	
	A horizontal health bar showing base health.
	Changes color based on health percentage.
	
	@param props BaseHealthBarProps
	@return Frame
]]
local function BaseHealthBar(props: BaseHealthBarProps): Frame
	local scope = props.Scope
	
	local position = props.Position or UDim2.new(0, 0, 0, 0)
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local layoutOrder = props.LayoutOrder or 0
	local zIndex = props.ZIndex or 1
	
	-- Internal state
	local currentHealth = Value(scope, 100)
	local maxHealth = Value(scope, 100)
	local damageFlash = Value(scope, 0)
	
	-- Health ratio (0 to 1)
	local healthRatio = Computed(scope, function(use)
		local current = use(currentHealth)
		local max = use(maxHealth)
		if max <= 0 then return 1 end
		return math.clamp(current / max, 0, 1)
	end)
	
	-- Animated health with spring (slower than wave progress for dramatic effect)
	local animatedHealth = Spring(scope, healthRatio, 15, 0.7)
	
	-- Fill bar width
	local fillWidth = Computed(scope, function(use)
		local ratio = use(animatedHealth)
		return UDim2.new(ratio, 0, 1, 0)
	end)
	
	-- Fill color based on health percentage
	local fillColor = Computed(scope, function(use)
		local ratio = use(healthRatio)
		if ratio > 0.6 then
			return FILL_COLOR_HEALTHY
		elseif ratio > 0.3 then
			return FILL_COLOR_DAMAGED
		else
			return FILL_COLOR_CRITICAL
		end
	end)
	
	-- Flash transparency for damage indication
	local flashTransparency = Spring(scope, damageFlash, 40, 1)
	
	-- Health text
	local healthText = Computed(scope, function(use)
		local current = use(currentHealth)
		local max = use(maxHealth)
		return `{current}/{max}`
	end)
	
	-- Setup signal listener with Trove for cleanup
	local trove = Trove.new()
	table.insert(scope, function()
		trove:Destroy()
	end)
	
	trove:Connect(GameSignals.OnBaseHealthChanged, function(data: {CurrentHealth: number, MaxHealth: number, DamageAmount: number?})
		local previousHealth = peek(currentHealth)
		
		currentHealth:set(data.CurrentHealth)
		if data.MaxHealth then
			maxHealth:set(data.MaxHealth)
		end
		
		-- Trigger damage flash if health decreased
		if data.DamageAmount and data.DamageAmount > 0 then
			damageFlash:set(1)
			task.delay(0.1, function()
				damageFlash:set(0)
			end)
		end
	end)
	
	-- Total width including icon
	local totalWidth = BAR_WIDTH + ICON_SIZE + 12
	
	return New(scope, "Frame") {
		Name = "BaseHealthBar",
		Size = UDim2.fromOffset(totalWidth, ICON_SIZE + 8),
		Position = position,
		AnchorPoint = anchorPoint,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		BackgroundTransparency = 1,
		
		[Children] = {
			-- House icon
			New(scope, "TextLabel") {
				Name = "HouseIcon",
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme.Colors.Surface.Main,
				Text = "🏠",
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				ZIndex = 5,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0.2, 0),
					},
					New(scope, "UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					},
				},
			},
			
			-- Health bar container
			ToonPanel({
				Scope = scope,
				Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
				Position = UDim2.new(0, ICON_SIZE + 8, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = 1,
				
				[Children] = {
					-- Dark track background
					New(scope, "Frame") {
						Name = "Track",
						Size = UDim2.new(1, -4, 1, -4),
						Position = UDim2.new(0, 2, 0, 2),
						BackgroundColor3 = TRACK_COLOR,
						ZIndex = 1,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = FILL_CORNER_RADIUS,
							},
						},
					},
					
					-- Fill bar (animated)
					New(scope, "Frame") {
						Name = "Fill",
						Size = fillWidth,
						Position = UDim2.new(0, 2, 0, 2),
						BackgroundColor3 = fillColor,
						ClipsDescendants = true,
						ZIndex = 2,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = FILL_CORNER_RADIUS,
							},
							
							-- Gradient for 3D effect
							New(scope, "UIGradient") {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
									ColorSequenceKeypoint.new(0.5, Color3.new(0.95, 0.95, 0.95)),
									ColorSequenceKeypoint.new(1, Color3.new(0.75, 0.75, 0.75)),
								}),
								Rotation = 90,
							},
							
							-- Inner frame for proper sizing
							New(scope, "Frame") {
								Size = UDim2.new(0, BAR_WIDTH - 4, 1, -4),
								Position = UDim2.new(0, 0, 0, 0),
								BackgroundTransparency = 1,
							},
						},
					},
					
					-- Damage flash overlay
					New(scope, "Frame") {
						Name = "DamageFlash",
						Size = UDim2.new(1, -4, 1, -4),
						Position = UDim2.new(0, 2, 0, 2),
						BackgroundColor3 = Color3.fromRGB(255, 0, 0),
						BackgroundTransparency = Computed(scope, function(use)
							return 1 - (use(flashTransparency) * 0.5)
						end),
						ZIndex = 3,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = FILL_CORNER_RADIUS,
							},
						},
					},
					
					-- Health text (centered)
					New(scope, "TextLabel") {
						Name = "HealthText",
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = healthText,
						TextColor3 = Color3.new(1, 1, 1),
						Font = Theme.Typography.Fonts.Body,
						TextSize = 12,
						ZIndex = 5,
						
						[Children] = {
							New(scope, "UIStroke") {
								Color = Color3.new(0, 0, 0),
								Thickness = 1,
								Transparency = 0.3,
							},
						},
					},
				},
			}),
		},
	}
end

return BaseHealthBar
