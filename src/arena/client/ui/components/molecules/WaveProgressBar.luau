--!strict
--[[
	WaveProgressBar.luau - Visual wave progress indicator with "Toon Pop" style (Responsive)
	
	Molecule component showing current wave progress.
	Features animated fill bar, zombie head indicator, and flag at end.
	
	Subscribes to GameSignals.OnWaveChanged for reactive updates.
	
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
local IconAssets = require(Shared.ui.design.IconAssets)
local ToonPanel = require(Shared.ui.components.base.ToonPanel)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local peek = Fusion.peek

-- Colors
local FILL_COLOR = Theme.Colors.Action.Main -- Green
local TRACK_COLOR = Color3.fromRGB(80, 60, 50) -- Dark brown track

export type WaveProgressBarProps = {
	Scope: Fusion.Scope<any>,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
}

--[[
	WaveProgressBar Component (Responsive)
	
	A horizontal progress bar showing wave advancement.
	Zombie head moves along the bar, flag marks the end.
	
	@param props WaveProgressBarProps
	@return Frame
]]
local function WaveProgressBar(props: WaveProgressBarProps): Frame
	local scope = props.Scope

	local position = props.Position or UDim2.fromScale(0, 0)
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local layoutOrder = props.LayoutOrder or 0
	local zIndex = props.ZIndex or 1

	-- Internal state
	local currentWave = scope:Value(0)
	local maxWaves = scope:Value(10) -- Default to 10 waves

	-- Progress ratio (0 to 1)
	local progressRatio = scope:Computed(function(use)
		local current = use(currentWave)
		local max = use(maxWaves)
		if max <= 0 then
			return 0
		end
		return math.clamp(current / max, 0, 1)
	end)

	-- Animated progress with spring
	local animatedProgress = scope:Spring(progressRatio, 20, 0.8)

	-- Fill bar width
	local fillWidth = scope:Computed(function(use)
		local progress = use(animatedProgress)
		return UDim2.fromScale(progress, 1)
	end)

	-- Wave text
	local waveText = scope:Computed(function(use)
		local current = use(currentWave)
		local max = use(maxWaves)
		return `{current}/{max}`
	end)

	-- Setup signal listener with Trove for cleanup
	local trove = Trove.new()
	table.insert(scope, function()
		trove:Destroy()
	end)

	trove:Connect(
		GameSignals.OnWaveChanged,
		function(data: { WaveNumber: number, MaxWaves: number?, IsPreparation: boolean? })
			currentWave:set(data.WaveNumber)
			if data.MaxWaves then
				maxWaves:set(data.MaxWaves)
			end
		end
	)

	return scope:New("Frame")({
		Name = "WaveProgressBar",
		Size = UDim2.fromScale(0.18, 0.045), -- 18% width, 4.5% height
		Position = position,
		AnchorPoint = anchorPoint,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		BackgroundTransparency = 1,

		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint")({
				MinSize = Vector2.new(180, 35),
				MaxSize = Vector2.new(350, 55),
			}),

			-- Track container (the bar itself)
			ToonPanel({
				Scope = scope,
				Size = UDim2.fromScale(0.75, 0.7),
				Position = UDim2.fromScale(0.12, 0.5),
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
								CornerRadius = UDim.new(0.4, 0),
							}),
						},
					}),

					-- Fill bar (animated)
					scope:New("Frame")({
						Name = "Fill",
						Size = fillWidth,
						Position = UDim2.fromScale(0.01, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = FILL_COLOR,
						ClipsDescendants = true,
						ZIndex = 2,

						[Children] = {
							scope:New("UISizeConstraint")({
								MaxSize = Vector2.new(9999, 30),
							}),

							scope:New("UICorner")({
								CornerRadius = UDim.new(0.4, 0),
							}),

							-- Gradient for 3D effect
							scope:New("UIGradient")({
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
									ColorSequenceKeypoint.new(0.5, Color3.new(0.95, 0.95, 0.95)),
									ColorSequenceKeypoint.new(1, Color3.new(0.8, 0.8, 0.8)),
								}),
								Rotation = 90,
							}),
						},
					}),

					-- Wave text (centered)
					scope:New("TextLabel")({
						Name = "WaveText",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = waveText,
						TextColor3 = Color3.new(1, 1, 1),
						Font = Theme.Typography.Fonts.Body,
						TextScaled = true,
						ZIndex = 5,

						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 16,
								MinTextSize = 10,
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

			-- Zombie icon (moves along bar)
			scope:New("Frame")({
				Name = "ZombieHead",
				Size = UDim2.fromScale(0.12, 0.9),
				Position = scope:Computed(function(use)
					local progress = use(animatedProgress)
					-- Move from 12% to 87% of the container
					local xPos = 0.12 + (progress * 0.75)
					return UDim2.fromScale(xPos, 0.5)
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(100, 180, 100), -- Zombie green
				ZIndex = 10,

				[Children] = {
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 1,
						DominantAxis = Enum.DominantAxis.Height,
					}),
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					}),
					-- Icon
					scope:New("ImageLabel")({
						Size = UDim2.fromScale(0.8, 0.8),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = IconAssets.Get("Zombie"),
						ScaleType = Enum.ScaleType.Fit,
						Visible = IconAssets.HasImage("Zombie"),
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = IconAssets.GetEmoji("Zombie"),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
						Visible = not IconAssets.HasImage("Zombie"),
					}),
				},
			}),

			-- Flag icon (image when available)
			scope:New("ImageLabel")({
				Name = "FlagIconImage",
				Size = UDim2.fromScale(0.12, 0.9),
				Position = UDim2.fromScale(0.92, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Colors.Danger.Main,
				Image = IconAssets.Get("Flag"),
				ZIndex = 5,
				Visible = IconAssets.HasImage("Flag"),

				[Children] = {
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 1,
						DominantAxis = Enum.DominantAxis.Height,
					}),
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					}),
				},
			}),
			-- Flag icon (emoji fallback)
			scope:New("TextLabel")({
				Name = "FlagIcon",
				Size = UDim2.fromScale(0.12, 0.9),
				Position = UDim2.fromScale(0.92, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Colors.Danger.Main,
				Text = IconAssets.GetEmoji("Flag"),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				ZIndex = 5,
				Visible = not IconAssets.HasImage("Flag"),

				[Children] = {
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 1,
						DominantAxis = Enum.DominantAxis.Height,
					}),
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					}),
				},
			}),
		},
	})
end

return WaveProgressBar
