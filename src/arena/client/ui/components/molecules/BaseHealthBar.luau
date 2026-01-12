--!strict
--[[
	BaseHealthBar.luau - Visual health bar for the player's base (Responsive)
	
	Molecule component showing the base's remaining health.
	Features animated fill bar with damage flash effect.
	
	Subscribes to GameSignals.OnBaseHealthChanged for reactive updates.
	
	Fully responsive using Scale-based sizing.
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameSignals = require(Shared.signals.GameSignals)
local Theme = require(Shared.ui.design.Theme)
local ToonPanel = require(Shared.ui.components.atoms.ToonPanel)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local peek = Fusion.peek

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
	BaseHealthBar Component (Responsive)
	
	A horizontal health bar showing base health.
	Changes color based on health percentage.
	
	@param props BaseHealthBarProps
	@return Frame
]]
local function BaseHealthBar(props: BaseHealthBarProps): Frame
	local scope = props.Scope

	local position = props.Position or UDim2.fromScale(0, 0)
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local layoutOrder = props.LayoutOrder or 0
	local zIndex = props.ZIndex or 1

	-- Internal state
	local currentHealth = scope:Value(100)
	local maxHealth = scope:Value(100)
	local damageFlash = scope:Value(0)

	-- Health ratio (0 to 1)
	local healthRatio = scope:Computed(function(use)
		local current = use(currentHealth)
		local max = use(maxHealth)
		if max <= 0 then
			return 1
		end
		return math.clamp(current / max, 0, 1)
	end)

	-- Animated health with spring (slower than wave progress for dramatic effect)
	local animatedHealth = scope:Spring(healthRatio, 15, 0.7)

	-- Fill bar width
	local fillWidth = scope:Computed(function(use)
		local ratio = use(animatedHealth)
		return UDim2.fromScale(ratio, 1)
	end)

	-- Fill color based on health percentage
	local fillColor = scope:Computed(function(use)
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
	local flashTransparency = scope:Spring(damageFlash, 40, 1)

	-- Health text
	local healthText = scope:Computed(function(use)
		local current = use(currentHealth)
		local max = use(maxHealth)
		return `{current}/{max}`
	end)

	-- Setup signal listener with Trove for cleanup
	local trove = Trove.new()
	table.insert(scope, function()
		trove:Destroy()
	end)

	trove:Connect(
		GameSignals.OnBaseHealthChanged,
		function(data: { CurrentHealth: number, MaxHealth: number, DamageAmount: number? })
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
		end
	)

	return scope:New("Frame")({
		Name = "BaseHealthBar",
		Size = UDim2.fromScale(0.16, 0.04), -- 16% width, 4% height
		Position = position,
		AnchorPoint = anchorPoint,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		BackgroundTransparency = 1,

		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint")({
				MinSize = Vector2.new(160, 30),
				MaxSize = Vector2.new(300, 50),
			}),

			-- House icon
			scope:New("TextLabel")({
				Name = "HouseIcon",
				Size = UDim2.fromScale(0.15, 0.9),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme.Colors.Surface.Main,
				Text = "🏠",
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				ZIndex = 5,

				[Children] = {
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 1,
						DominantAxis = Enum.DominantAxis.Height,
					}),
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.2, 0),
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					}),
				},
			}),

			-- Health bar container
			ToonPanel({
				Scope = scope,
				Size = UDim2.fromScale(0.78, 0.65),
				Position = UDim2.fromScale(0.2, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = 1,

				[Children] = {
					-- Dark track background
					scope:New("Frame")({
						Name = "Track",
						Size = UDim2.fromScale(0.98, 0.85),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = TRACK_COLOR,
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.35, 0),
							}),
						},
					}),

					-- Fill bar (animated)
					scope:New("Frame")({
						Name = "Fill",
						Size = fillWidth,
						Position = UDim2.fromScale(0.01, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = fillColor,
						ClipsDescendants = true,
						ZIndex = 2,

						[Children] = {
							scope:New("UISizeConstraint")({
								MaxSize = Vector2.new(9999, 28),
							}),

							scope:New("UICorner")({
								CornerRadius = UDim.new(0.35, 0),
							}),

							-- Gradient for 3D effect
							scope:New("UIGradient")({
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
									ColorSequenceKeypoint.new(0.5, Color3.new(0.95, 0.95, 0.95)),
									ColorSequenceKeypoint.new(1, Color3.new(0.75, 0.75, 0.75)),
								}),
								Rotation = 90,
							}),
						},
					}),

					-- Damage flash overlay
					scope:New("Frame")({
						Name = "DamageFlash",
						Size = UDim2.fromScale(0.98, 0.85),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 0, 0),
						BackgroundTransparency = scope:Computed(function(use)
							return 1 - (use(flashTransparency) * 0.5)
						end),
						ZIndex = 3,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.35, 0),
							}),
						},
					}),

					-- Health text (centered)
					scope:New("TextLabel")({
						Name = "HealthText",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = healthText,
						TextColor3 = Color3.new(1, 1, 1),
						Font = Theme.Typography.Fonts.Body,
						TextScaled = true,
						ZIndex = 5,

						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 14,
								MinTextSize = 9,
							}),
							scope:New("UIStroke")({
								Color = Color3.new(0, 0, 0),
								Thickness = 1,
								Transparency = 0.3,
							}),
						},
					}),
				},
			}),
		},
	})
end

return BaseHealthBar
