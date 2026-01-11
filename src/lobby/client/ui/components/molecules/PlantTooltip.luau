--!strict
--[[
	PlantTooltip.luau - Displays detailed plant information on click
	
	Features:
	- 3D model preview using ViewportFrame
	- Plant stats (Health, Damage, Attack Speed, etc.)
	- Active mutations with effects
	- Toon Pop styling
	
	Copied from Arena PlantTooltip.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local Theme = require(Shared.ui.design.Theme)
local Logger = require(Shared.utils.Logger)

local SharedAtoms = Shared:WaitForChild("ui"):WaitForChild("components"):WaitForChild("atoms")
local ToonPanel = require(SharedAtoms.ToonPanel)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent
local Out = Fusion.Out
local peek = Fusion.peek
local ForValues = Fusion.ForValues
local Observer = Fusion.Observer

-- Types (use any to avoid Fusion generic issues)
type Scope = any
type UseFn = any

-- Constants
local TOOLTIP_WIDTH = 320
local TOOLTIP_HEIGHT = 400
local VIEWPORT_SIZE = 120
local STAT_ICON_SIZE = 20

-- Colors (from Theme or custom)
local Colors = {
	TextPrimary = Color3.fromRGB(80, 60, 40),     -- Dark brown (readable on beige)
	TextSecondary = Color3.fromRGB(120, 100, 80), -- Lighter brown
	TextMuted = Color3.fromRGB(150, 130, 110),    -- Muted brown
	Sun = Color3.fromRGB(255, 200, 50),           -- Sunny yellow
	Health = Color3.fromRGB(80, 200, 80),         -- Green
	Speed = Color3.fromRGB(100, 180, 255),        -- Light blue
	CloseButton = Color3.fromRGB(200, 180, 150),  -- Light tan
}

-- Asset folder for plant models
local Assets = ReplicatedStorage:WaitForChild("Assets")
local PlantModels = Assets:WaitForChild("Plants")

-- Stat icons (emoji fallbacks)
local STAT_ICONS = {
	Health = "❤️",
	Damage = "⚔️",
	AttackSpeed = "⚡",
	Range = "🎯",
	Cost = "☀️",
	Cooldown = "⏱️",
}

export type PlantTooltipProps = {
	Scope: any,
	PlantType: any,
	Mutations: any,
	Position: any,
	Visible: any,
	OnClose: () -> (),
}

--[[
	Creates a stat row with icon, label, and value
]]
local function StatRow(scope: Scope, icon: string, label: string, value: any, color: Color3?): Instance
	return New(scope, "Frame") {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		
		[Children] = {
			-- Icon (absolute positioned left)
			New(scope, "TextLabel") {
				Name = "Icon",
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = icon,
				TextSize = 14,
				Font = Enum.Font.GothamBold,
			},
			
			-- Label (absolute positioned after icon)
			New(scope, "TextLabel") {
				Name = "Label",
				Size = UDim2.new(0, 100, 1, 0),
				Position = UDim2.new(0, 26, 0, 0),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = Colors.TextSecondary,
				TextSize = 14,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			
			-- Value (absolute positioned right)
			New(scope, "TextLabel") {
				Name = "Value",
				Size = UDim2.new(0, 60, 1, 0),
				Position = UDim2.new(1, -60, 0, 0),
				BackgroundTransparency = 1,
				Text = value,
				TextColor3 = color or Colors.TextPrimary,
				TextSize = 14,
				Font = Enum.Font.GothamBold, -- More readable for numbers
				TextXAlignment = Enum.TextXAlignment.Right,
			},
		},
	}
end

--[[
	Creates a mutation badge
]]
local function MutationBadge(scope: Scope, mutationId: string): Instance
	local mutation = MutationData.Get(mutationId)
	if not mutation then
		return New(scope, "Frame") { Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 }
	end
	
	return New(scope, "Frame") {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = mutation.Color,
		BackgroundTransparency = 0.8,
		
		[Children] = {
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 6),
			},
			New(scope, "UIStroke") {
				Color = mutation.Color,
				Thickness = 1,
				Transparency = 0.5,
			},
			New(scope, "UIPadding") {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			},
			
			-- Icon + Name
			New(scope, "TextLabel") {
				Size = UDim2.new(1, 0, 0, 18),
				Position = UDim2.new(0, 0, 0, 2),
				BackgroundTransparency = 1,
				Text = `{mutation.Icon} {mutation.Name}`,
				TextColor3 = mutation.Color,
				TextSize = 14,
				Font = Theme.Typography.Fonts.Title,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			
			-- Description
			New(scope, "TextLabel") {
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.new(0, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = mutation.Description,
				TextColor3 = Colors.TextSecondary,
				TextSize = 11,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			},
		},
	}
end

--[[
	Setup ViewportFrame with 3D model and camera
]]
local function setupViewport(viewport: ViewportFrame, plantType: string)
	Logger.Info("PlantTooltip", `setupViewport called for {plantType}`)
	
	-- Clear previous
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end
	
	-- Get plant model
	local modelTemplate = PlantModels:FindFirstChild(plantType)
	if not modelTemplate then
		Logger.Warn("PlantTooltip", `Model not found in PlantModels: {plantType}`)
		return
	end
	
	Logger.Info("PlantTooltip", `Found model template: {modelTemplate.Name}`)
	
	-- Create WorldModel to hold the model (required for proper viewport rendering)
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	
	-- Clone and add to WorldModel
	local model = modelTemplate:Clone()
	model.Parent = worldModel
	
	-- Reset model position to origin and rotate 180° to face camera
	if model.PrimaryPart then
		model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0))
		Logger.Debug("PlantTooltip", `Model pivoted to origin with 180° rotation`)
	else
		Logger.Warn("PlantTooltip", `Model {plantType} has no PrimaryPart!`)
	end
	
	-- Create and position camera
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	
	-- Calculate model bounds for framing
	local cframe, size = model:GetBoundingBox()
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = maxSize * 2.5
	
	-- Position camera to look at model from front-right angle
	local modelCenter = cframe.Position
	camera.CFrame = CFrame.new(
		modelCenter + Vector3.new(distance * 0.6, distance * 0.4, distance * 0.8),
		modelCenter
	)
	
	Logger.Info("PlantTooltip", `Viewport setup complete for {plantType}`)
end

--[[
	PlantTooltip Component
	
	Displays detailed plant information when a plant is clicked.
	
	@param props PlantTooltipProps
	@return Instance
]]
local function PlantTooltip(props: PlantTooltipProps): Instance
	local scope = props.Scope
	
	-- Get plant stats reactively
	local plantStats = Computed(scope, function(use: UseFn)
		local plantType = use(props.PlantType)
		if not plantType then return nil end
		return PlantData.GetStats(plantType) :: PlantData.PlantStats?
	end)
	
	-- Plant name
	local plantName = Computed(scope, function(use: UseFn)
		local stats = use(plantStats)
		return stats and stats.Name or "Unknown Plant"
	end)
	
	-- Category with color
	local categoryInfo = Computed(scope, function(use: UseFn)
		local stats = use(plantStats)
		if not stats then return { text = "", color = Colors.TextSecondary } end
		
		local colors = {
			Attacker = Theme.Colors.Danger.Main,
			Defender = Theme.Colors.Info.Main,
			Producer = Theme.Colors.Action.Main,
			Special = Theme.Colors.Info.Main,
		}
		return {
			text = stats.Category or "",
			color = colors[stats.Category] or Colors.TextSecondary,
		}
	end)
	
	-- Animated scale for pop-in effect
	local targetScale = Computed(scope, function(use: UseFn)
		return use(props.Visible) and 1 or 0.8
	end)
	local animatedScale = Spring(scope, targetScale, 35, 0.7)
	
	-- Animated transparency
	local targetTransparency = Computed(scope, function(use: UseFn)
		return use(props.Visible) and 0 or 1
	end)
	local animatedTransparency = Spring(scope, targetTransparency, 30, 1)
	
	-- Create viewport directly for 3D preview
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name = "ModelPreview"
	viewportFrame.Size = UDim2.fromOffset(VIEWPORT_SIZE, VIEWPORT_SIZE)
	viewportFrame.Position = UDim2.new(0, 0, 0, 0)
	viewportFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	viewportFrame.BackgroundTransparency = 0.3
	viewportFrame.Ambient = Color3.fromRGB(200, 200, 200)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightDirection = Vector3.new(-1, -1, -1)
	
	-- Add corner and stroke to viewport
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = viewportFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Surface.Stroke :: Color3
	stroke.Thickness = 2
	stroke.Parent = viewportFrame
	
	-- Cleanup viewport when scope is destroyed
	table.insert(scope, viewportFrame)
	
	-- Update viewport when plant type changes (using Observer for side effects)
	local observer = Observer(scope, props.PlantType)
	observer:onBind(function()
		local plantType = peek(props.PlantType)
		if plantType then
			task.defer(function()
				setupViewport(viewportFrame, plantType)
			end)
		end
	end)
	
	return New(scope, "Frame") {
		Name = "PlantTooltip",
		Size = UDim2.fromOffset(TOOLTIP_WIDTH, TOOLTIP_HEIGHT),
		Position = props.Position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = Computed(scope, function(use)
			return use(animatedTransparency) < 0.99
		end),
		ZIndex = 100,
		
		[Children] = {
			-- Scale container
			New(scope, "UIScale") {
				Scale = animatedScale,
			},
			
			-- Main panel
			ToonPanel({
				Scope = scope,
				Size = UDim2.new(1, 0, 1, 0),
				
				[Children] = {
					-- Content container
					New(scope, "Frame") {
						Name = "Content",
						Size = UDim2.new(1, -20, 1, -20),
						Position = UDim2.new(0, 10, 0, 10),
						BackgroundTransparency = 1,
						
						[Children] = {
							New(scope, "UIListLayout") {
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 8),
							},
							
							-- Header: 3D Preview + Name
							New(scope, "Frame") {
								Name = "Header",
								Size = UDim2.new(1, 0, 0, VIEWPORT_SIZE),
								BackgroundTransparency = 1,
								LayoutOrder = 1,
								
								[Children] = {
									-- ViewportFrame for 3D model (created imperatively)
									viewportFrame,
									
									-- Name and category
									New(scope, "Frame") {
										Name = "NameContainer",
										Size = UDim2.new(1, -VIEWPORT_SIZE - 10, 0, VIEWPORT_SIZE),
										Position = UDim2.new(0, VIEWPORT_SIZE + 10, 0, 0),
										BackgroundTransparency = 1,
										
										[Children] = {
											-- Plant name
											New(scope, "TextLabel") {
												Name = "PlantName",
												Size = UDim2.new(1, 0, 0, 28),
												Position = UDim2.new(0, 0, 0, 10),
												BackgroundTransparency = 1,
												Text = plantName,
												TextColor3 = Colors.TextPrimary,
												TextSize = 20,
												Font = Theme.Typography.Fonts.Title,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Top,
											},
											
											-- Category badge
											New(scope, "TextLabel") {
												Name = "Category",
												Size = UDim2.new(1, 0, 0, 20),
												Position = UDim2.new(0, 0, 0, 40),
												BackgroundTransparency = 1,
												Text = Computed(scope, function(use)
													return use(categoryInfo).text
												end),
												TextColor3 = Computed(scope, function(use)
													return use(categoryInfo).color
												end),
												TextSize = 14,
												Font = Theme.Typography.Fonts.Body,
												TextXAlignment = Enum.TextXAlignment.Left,
											},
										},
									},
								},
							},
							
							-- Separator
							New(scope, "Frame") {
								Size = UDim2.new(1, 0, 0, 1),
								BackgroundColor3 = Theme.Colors.Surface.Stroke :: Color3,
								LayoutOrder = 2,
							},
							
							-- Stats section
							New(scope, "Frame") {
								Name = "Stats",
								Size = UDim2.new(1, 0, 0, 120),
								BackgroundTransparency = 1,
								LayoutOrder = 3,
								
								[Children] = {
									New(scope, "UIListLayout") {
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 4),
									},
									
									StatRow(scope, STAT_ICONS.Health, "Santé", Computed(scope, function(use)
										local stats = use(plantStats)
										return stats and tostring(stats.Health) or "-"
									end), Colors.Health),
									
									StatRow(scope, STAT_ICONS.Damage, "Dégâts", Computed(scope, function(use)
										local stats = use(plantStats)
										return stats and stats.Damage > 0 and tostring(stats.Damage) or "-"
									end), Theme.Colors.Danger.Main),
									
									StatRow(scope, STAT_ICONS.AttackSpeed, "Vitesse", Computed(scope, function(use)
										local stats = use(plantStats)
										return stats and stats.AttackSpeed > 0 and `{stats.AttackSpeed}/s` or "-"
									end), Colors.Speed),
									
									StatRow(scope, STAT_ICONS.Cost, "Coût", Computed(scope, function(use)
										local stats = use(plantStats)
										return stats and tostring(stats.Cost) or "-"
									end), Colors.Sun),
									
									StatRow(scope, STAT_ICONS.Cooldown, "Recharge", Computed(scope, function(use)
										local stats = use(plantStats)
										return stats and `{stats.Cooldown}s` or "-"
									end), nil),
								},
							},
							
							-- Separator
							New(scope, "Frame") {
								Size = UDim2.new(1, 0, 0, 1),
								BackgroundColor3 = Theme.Colors.Surface.Stroke :: Color3,
								LayoutOrder = 4,
							},
							
							-- Mutations section
							New(scope, "Frame") {
								Name = "Mutations",
								Size = UDim2.new(1, 0, 0, 90),
								BackgroundTransparency = 1,
								LayoutOrder = 5,
								
								[Children] = {
									New(scope, "UIListLayout") {
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 4),
									},
									
									-- Mutations header
									New(scope, "Frame") {
										Size = UDim2.new(1, 0, 0, 22),
										BackgroundTransparency = 1,
										LayoutOrder = 1,
										
										[Children] = {
											New(scope, "TextLabel") {
												Size = UDim2.fromOffset(22, 22),
												Position = UDim2.new(0, 0, 0, 0),
												BackgroundTransparency = 1,
												Text = "🧬",
												TextSize = 14,
												Font = Enum.Font.GothamBold,
											},
											New(scope, "TextLabel") {
												Size = UDim2.new(1, -26, 1, 0),
												Position = UDim2.new(0, 26, 0, 0),
												BackgroundTransparency = 1,
												Text = "Mutations",
												TextColor3 = Colors.TextPrimary,
												TextSize = 14,
												Font = Theme.Typography.Fonts.Title,
												TextXAlignment = Enum.TextXAlignment.Left,
											},
										},
									},
									
									-- Mutation badges container
									New(scope, "ScrollingFrame") {
										Size = UDim2.new(1, 0, 1, -26),
										BackgroundTransparency = 1,
										ScrollBarThickness = 4,
										CanvasSize = UDim2.new(0, 0, 0, 0),
										AutomaticCanvasSize = Enum.AutomaticSize.Y,
										ScrollingDirection = Enum.ScrollingDirection.Y,
										LayoutOrder = 2,
										
										[Children] = {
											New(scope, "UIListLayout") {
												SortOrder = Enum.SortOrder.LayoutOrder,
												Padding = UDim.new(0, 4),
											},
											
											-- No mutations placeholder
											New(scope, "TextLabel") {
												Size = UDim2.new(1, 0, 0, 20),
												BackgroundTransparency = 1,
												Text = "Aucune mutation",
												TextColor3 = Colors.TextMuted,
												TextSize = 12,
												Font = Theme.Typography.Fonts.Body,
												TextXAlignment = Enum.TextXAlignment.Center,
												Visible = Computed(scope, function(use)
													local mutations = use(props.Mutations) or {}
													return #mutations == 0
												end),
											},
											
											-- Dynamic mutation badges using ForValues
											ForValues(scope, Computed(scope, function(use)
												return use(props.Mutations) or {}
											end), function(use, innerScope, mutationId)
												return MutationBadge(innerScope, mutationId)
											end),
										},
									},
								},
							},
							
							-- Close button
							New(scope, "TextButton") {
								Name = "CloseButton",
								Size = UDim2.new(1, 0, 0, 32),
								BackgroundColor3 = Colors.CloseButton,
								Text = "Fermer",
								TextColor3 = Colors.TextPrimary,
								TextSize = 14,
								Font = Theme.Typography.Fonts.Title,
								LayoutOrder = 10,
								
								[OnEvent("Activated")] = props.OnClose,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = UDim.new(0, 6),
									},
									New(scope, "UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = 1,
									},
								},
							},
						},
					},
				},
			}),
		},
	}
end

return PlantTooltip
