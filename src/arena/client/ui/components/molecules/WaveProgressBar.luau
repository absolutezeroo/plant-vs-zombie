--!strict
--[[
	WaveProgressBar.luau - Visual wave progress indicator with "Toon Pop" style
	
	Molecule component showing current wave progress.
	Features animated fill bar, zombie head indicator, and flag at end.
	
	Subscribes to GameSignals.OnWaveChanged for reactive updates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameSignals = require(Shared.signals.GameSignals)
local Theme = require(Shared.ui.design.Theme)

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
local BAR_HEIGHT = 24
local BAR_WIDTH = 250
local ICON_SIZE = 32
local FILL_CORNER_RADIUS = UDim.new(0, 8)

-- Asset IDs (placeholders - replace with actual assets)
local ZOMBIE_HEAD_ICON = "rbxassetid://6764432293" -- TODO: Replace with zombie head
local FLAG_ICON = "rbxassetid://6764432293" -- TODO: Replace with finish flag

-- Colors
local FILL_COLOR = Theme.Colors.Action.Main -- Green
local FILL_SHADOW_COLOR = Theme.Colors.Action.Shadow -- DarkGreen
local TRACK_COLOR = Color3.fromRGB(80, 60, 50) -- Dark brown track

export type WaveProgressBarProps = {
	Scope: Fusion.Scope<any>,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
}

--[[
	WaveProgressBar Component
	
	A horizontal progress bar showing wave advancement.
	Zombie head moves along the bar, flag marks the end.
	
	@param props WaveProgressBarProps
	@return Frame
]]
local function WaveProgressBar(props: WaveProgressBarProps): Frame
	local scope = props.Scope
	
	local position = props.Position or UDim2.new(0, 0, 0, 0)
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local layoutOrder = props.LayoutOrder or 0
	local zIndex = props.ZIndex or 1
	
	-- Internal state
	local currentWave = Value(scope, 0)
	local maxWaves = Value(scope, 10) -- Default to 10 waves
	
	-- Progress ratio (0 to 1)
	local progressRatio = Computed(scope, function(use)
		local current = use(currentWave)
		local max = use(maxWaves)
		if max <= 0 then return 0 end
		return math.clamp(current / max, 0, 1)
	end)
	
	-- Animated progress with spring
	local animatedProgress = Spring(scope, progressRatio, 20, 0.8)
	
	-- Fill bar width
	local fillWidth = Computed(scope, function(use)
		local progress = use(animatedProgress)
		return UDim2.new(progress, 0, 1, 0)
	end)
	
	-- Zombie head position (moves along the bar)
	local headPosition = Computed(scope, function(use)
		local progress = use(animatedProgress)
		-- Position from left edge to right edge, accounting for icon size
		return UDim2.new(progress, -ICON_SIZE / 2, 0.5, 0)
	end)
	
	-- Wave text
	local waveText = Computed(scope, function(use)
		local current = use(currentWave)
		local max = use(maxWaves)
		return `{current}/{max}`
	end)
	
	-- Setup signal listener with Trove for cleanup
	local trove = Trove.new()
	table.insert(scope, function()
		trove:Destroy()
	end)
	
	trove:Connect(GameSignals.OnWaveChanged, function(data: {WaveNumber: number, MaxWaves: number?, IsPreparation: boolean?})
		currentWave:set(data.WaveNumber)
		if data.MaxWaves then
			maxWaves:set(data.MaxWaves)
		end
	end)
	
	-- Total width including icons
	local totalWidth = BAR_WIDTH + ICON_SIZE * 2
	
	return New(scope, "Frame") {
		Name = "WaveProgressBar",
		Size = UDim2.fromOffset(totalWidth, ICON_SIZE + 8),
		Position = position,
		AnchorPoint = anchorPoint,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		BackgroundTransparency = 1,
		
		[Children] = {
			-- Track container (the bar itself)
			ToonPanel({
				Scope = scope,
				Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
				Position = UDim2.new(0, ICON_SIZE / 2, 0.5, 0),
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
						BackgroundColor3 = FILL_COLOR,
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
									ColorSequenceKeypoint.new(1, Color3.new(0.8, 0.8, 0.8)),
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
					
					-- Wave text (centered)
					New(scope, "TextLabel") {
						Name = "WaveText",
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = waveText,
						TextColor3 = Color3.new(1, 1, 1),
						Font = Theme.Typography.Fonts.Body,
						TextSize = 14,
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
			
			-- Zombie emoji (moves along bar) - temporary for testing
			New(scope, "TextLabel") {
				Name = "ZombieHead",
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				Position = Computed(scope, function(use)
					local progress = use(animatedProgress)
					local xOffset = ICON_SIZE / 2 + (progress * BAR_WIDTH)
					return UDim2.new(0, xOffset, 0.5, 0)
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(100, 180, 100), -- Zombie green
				Text = "🧟",
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				ZIndex = 10,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
					New(scope, "UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					},
				},
			},
			
			-- Flag emoji (end of bar) - temporary for testing
			New(scope, "TextLabel") {
				Name = "FlagIcon",
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				Position = UDim2.new(0, ICON_SIZE / 2 + BAR_WIDTH, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Colors.Danger.Main,
				Text = "🚩",
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				ZIndex = 5,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
					New(scope, "UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = 2,
					},
				},
			},
		},
	}
end

return WaveProgressBar
