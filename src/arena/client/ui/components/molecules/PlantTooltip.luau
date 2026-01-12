--!strict
--[[
	PlantTooltip.luau - Displays detailed plant information on click (Responsive)
	
	Features:
	- 3D model preview using ViewportFrame
	- Plant stats (Health, Damage, Attack Speed, etc.)
	- Active mutations with effects
	- Toon Pop styling
	
	Uses Fusion 0.3 scope:Method() syntax.
	Fully responsive with Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local Logger = require(Shared.utils.Logger)
local Theme = require(Shared.ui.design.Theme)
local ToonPanel = require(Shared.ui.components.atoms.ToonPanel)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local ForValues = Fusion.ForValues
local Observer = Fusion.Observer

-- Types
type Scope = Fusion.Scope<any>

-- Colors
local Colors = {
	TextPrimary = Color3.fromRGB(80, 60, 40),
	TextSecondary = Color3.fromRGB(120, 100, 80),
	TextMuted = Color3.fromRGB(150, 130, 110),
	Sun = Color3.fromRGB(255, 200, 50),
	Health = Color3.fromRGB(80, 200, 80),
	Speed = Color3.fromRGB(100, 180, 255),
	CloseButton = Color3.fromRGB(200, 180, 150),
}

-- Asset folder for plant models
local Assets = ReplicatedStorage:WaitForChild("Assets")
local PlantModels = Assets:WaitForChild("Plants")

-- Stat icons
local STAT_ICONS = {
	Health = "❤️",
	Damage = "⚔️",
	AttackSpeed = "⚡",
	Range = "🎯",
	Cost = "☀️",
	Cooldown = "⏱️",
}

export type PlantTooltipProps = {
	Scope: Scope,
	PlantType: any,
	Mutations: any,
	EntityId: any,
	Position: any,
	Visible: any,
	OnClose: () -> (),
}

--[[
	Creates a responsive stat row
]]
local function StatRow(scope: Scope, icon: string, label: string, value: any, color: Color3?): Instance
	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 0.16), -- 16% of stats container
		BackgroundTransparency = 1,

		[Children] = {
			-- Icon
			scope:New("TextLabel")({
				Name = "Icon",
				Size = UDim2.fromScale(0.12, 1),
				Position = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				Text = icon,
				TextScaled = true,
				Font = Enum.Font.GothamBold,

				[Children] = {
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 1,
						DominantAxis = Enum.DominantAxis.Height,
					}),
				},
			}),

			-- Label
			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(0.5, 1),
				Position = UDim2.fromScale(0.14, 0),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = Colors.TextSecondary,
				TextScaled = true,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						MaxTextSize = 14,
						MinTextSize = 9,
					}),
				},
			}),

			-- Value
			scope:New("TextLabel")({
				Name = "Value",
				Size = UDim2.fromScale(0.3, 1),
				Position = UDim2.fromScale(1, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text = value,
				TextColor3 = color or Colors.TextPrimary,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						MaxTextSize = 14,
						MinTextSize = 9,
					}),
				},
			}),
		},
	})
end

--[[
	Creates a mutation badge
]]
local function MutationBadge(scope: Scope, mutationId: string): Instance
	local mutation = MutationData.Get(mutationId)
	if not mutation then
		return scope:New("Frame")({ Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 })
	end

	return scope:New("Frame")({
		Size = UDim2.new(1, 0, 0, 40), -- Fixed pixel height for AutomaticCanvasSize
		BackgroundColor3 = mutation.Color,
		BackgroundTransparency = 0.8,

		[Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 6),
			}),
			scope:New("UIStroke")({
				Color = mutation.Color,
				Thickness = 1,
				Transparency = 0.5,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0.03, 0),
				PaddingRight = UDim.new(0.03, 0),
			}),

			-- Icon + Name
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 0.5),
				Position = UDim2.fromScale(0, 0.05),
				BackgroundTransparency = 1,
				Text = `{mutation.Icon} {mutation.Name}`,
				TextColor3 = mutation.Color,
				TextScaled = true,
				Font = Theme.Typography.Fonts.Title,
				TextXAlignment = Enum.TextXAlignment.Left,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						MaxTextSize = 14,
						MinTextSize = 10,
					}),
				},
			}),

			-- Description
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 0.4),
				Position = UDim2.fromScale(0, 0.55),
				BackgroundTransparency = 1,
				Text = mutation.Description,
				TextColor3 = Colors.TextSecondary,
				TextScaled = true,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						MaxTextSize = 11,
						MinTextSize = 8,
					}),
				},
			}),
		},
	})
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
		Logger.Warn("PlantTooltip", `Model not found: {plantType}`)
		return
	end

	-- Create WorldModel
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	-- Clone and add to WorldModel
	local model = modelTemplate:Clone()
	model.Parent = worldModel

	-- Reset model position and rotate to face camera
	if model.PrimaryPart then
		model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0))
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

	-- Position camera
	local modelCenter = cframe.Position
	camera.CFrame = CFrame.new(modelCenter + Vector3.new(distance * 0.6, distance * 0.4, distance * 0.8), modelCenter)
end

--[[
	PlantTooltip Component (Responsive)
	
	Displays detailed plant information when a plant is clicked.
	Uses Scale-based sizing for responsive layout.
	
	@param props PlantTooltipProps
	@return Instance
]]
local function PlantTooltip(props: PlantTooltipProps): Instance
	local scope = props.Scope

	-- Get plant stats reactively
	local plantStats = scope:Computed(function(use)
		local plantType = use(props.PlantType)
		if not plantType then
			return nil
		end
		return PlantData.GetStats(plantType) :: PlantData.PlantStats?
	end)

	-- Plant name
	local plantName = scope:Computed(function(use)
		local stats = use(plantStats)
		return stats and stats.Name or "Unknown Plant"
	end)

	-- Category with color
	local categoryInfo = scope:Computed(function(use)
		local stats = use(plantStats)
		if not stats then
			return { text = "", color = Colors.TextSecondary }
		end

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
	local targetScale = scope:Computed(function(use)
		return use(props.Visible) and 1 or 0.8
	end)
	local animatedScale = scope:Spring(targetScale, 35, 0.7)

	-- Animated transparency
	local targetTransparency = scope:Computed(function(use)
		return use(props.Visible) and 0 or 1
	end)
	local animatedTransparency = scope:Spring(targetTransparency, 30, 1)

	-- Create viewport imperatively
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name = "ModelPreview"
	viewportFrame.Size = UDim2.fromScale(0.35, 0.9)
	viewportFrame.Position = UDim2.fromScale(0, 0.05)
	viewportFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	viewportFrame.BackgroundTransparency = 0.3
	viewportFrame.Ambient = Color3.fromRGB(200, 200, 200)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightDirection = Vector3.new(-1, -1, -1)

	-- Add corner and stroke
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.1, 0)
	corner.Parent = viewportFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Surface.Stroke :: Color3
	stroke.Thickness = 2
	stroke.Parent = viewportFrame

	-- Keep square aspect
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = viewportFrame

	-- Cleanup viewport when scope destroyed
	table.insert(scope, viewportFrame)

	-- Update viewport when plant type changes
	local observer = Observer(scope, props.PlantType)
	observer:onBind(function()
		local plantType = peek(props.PlantType)
		if plantType then
			task.defer(function()
				setupViewport(viewportFrame, plantType)
			end)
		end
	end)

	return scope:New("Frame")({
		Name = "PlantTooltip",
		Size = UDim2.fromScale(0.28, 0.55), -- 28% width, 55% height
		Position = props.Position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return use(animatedTransparency) < 0.99
		end),
		ZIndex = 100,

		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint")({
				MinSize = Vector2.new(280, 360),
				MaxSize = Vector2.new(400, 500),
			}),

			-- Scale container
			scope:New("UIScale")({
				Scale = animatedScale,
			}),

			-- Main panel
			ToonPanel({
				Scope = scope,
				Size = UDim2.fromScale(1, 1),

				[Children] = {
					-- Content container
					scope:New("Frame")({
						Name = "Content",
						Size = UDim2.fromScale(0.92, 0.95),
						Position = UDim2.fromScale(0.04, 0.025),
						BackgroundTransparency = 1,

						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0.02, 0),
							}),

							-- Header: 3D Preview + Name
							scope:New("Frame")({
								Name = "Header",
								Size = UDim2.fromScale(1, 0.28),
								BackgroundTransparency = 1,
								LayoutOrder = 1,

								[Children] = {
									-- ViewportFrame
									viewportFrame,

									-- Name and category
									scope:New("Frame")({
										Name = "NameContainer",
										Size = UDim2.fromScale(0.58, 1),
										Position = UDim2.fromScale(0.4, 0),
										BackgroundTransparency = 1,

										[Children] = {
											-- Plant name
											scope:New("TextLabel")({
												Name = "PlantName",
												Size = UDim2.fromScale(1, 0.35),
												Position = UDim2.fromScale(0, 0.1),
												BackgroundTransparency = 1,
												Text = plantName,
												TextColor3 = Colors.TextPrimary,
												TextScaled = true,
												Font = Theme.Typography.Fonts.Title,
												TextXAlignment = Enum.TextXAlignment.Left,

												[Children] = {
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 22,
														MinTextSize = 14,
													}),
												},
											}),

											-- Category badge
											scope:New("TextLabel")({
												Name = "Category",
												Size = UDim2.fromScale(1, 0.2),
												Position = UDim2.fromScale(0, 0.45),
												BackgroundTransparency = 1,
												Text = scope:Computed(function(use)
													return use(categoryInfo).text
												end),
												TextColor3 = scope:Computed(function(use)
													return use(categoryInfo).color
												end),
												TextScaled = true,
												Font = Theme.Typography.Fonts.Body,
												TextXAlignment = Enum.TextXAlignment.Left,

												[Children] = {
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 14,
														MinTextSize = 10,
													}),
												},
											}),

											-- Entity ID (debug)
											scope:New("TextLabel")({
												Name = "EntityId",
												Size = UDim2.fromScale(1, 0.15),
												Position = UDim2.fromScale(0, 0.7),
												BackgroundTransparency = 1,
												Text = scope:Computed(function(use)
													local id = use(props.EntityId)
													return id and `Entity #{id}` or ""
												end),
												TextColor3 = Colors.TextMuted,
												TextScaled = true,
												Font = Theme.Typography.Fonts.Body,
												TextXAlignment = Enum.TextXAlignment.Left,

												[Children] = {
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 11,
														MinTextSize = 8,
													}),
												},
											}),
										},
									}),
								},
							}),

							-- Separator
							scope:New("Frame")({
								Size = UDim2.fromScale(1, 0.003),
								BackgroundColor3 = Theme.Colors.Surface.Stroke :: Color3,
								LayoutOrder = 2,
							}),

							-- Stats section
							scope:New("Frame")({
								Name = "Stats",
								Size = UDim2.fromScale(1, 0.28),
								BackgroundTransparency = 1,
								LayoutOrder = 3,

								[Children] = {
									scope:New("UIListLayout")({
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0.02, 0),
									}),

									StatRow(
										scope,
										STAT_ICONS.Health,
										"Santé",
										scope:Computed(function(use)
											local stats = use(plantStats)
											return stats and tostring(stats.Health) or "-"
										end),
										Colors.Health
									),

									StatRow(
										scope,
										STAT_ICONS.Damage,
										"Dégâts",
										scope:Computed(function(use)
											local stats = use(plantStats)
											return stats and stats.Damage > 0 and tostring(stats.Damage) or "-"
										end),
										Theme.Colors.Danger.Main
									),

									StatRow(
										scope,
										STAT_ICONS.AttackSpeed,
										"Vitesse",
										scope:Computed(function(use)
											local stats = use(plantStats)
											return stats and stats.AttackSpeed > 0 and `{stats.AttackSpeed}/s` or "-"
										end),
										Colors.Speed
									),

									StatRow(
										scope,
										STAT_ICONS.Cost,
										"Coût",
										scope:Computed(function(use)
											local stats = use(plantStats)
											return stats and tostring(stats.Cost) or "-"
										end),
										Colors.Sun
									),

									StatRow(
										scope,
										STAT_ICONS.Cooldown,
										"Recharge",
										scope:Computed(function(use)
											local stats = use(plantStats)
											return stats and `{stats.Cooldown}s` or "-"
										end),
										nil
									),
								},
							}),

							-- Separator
							scope:New("Frame")({
								Size = UDim2.fromScale(1, 0.003),
								BackgroundColor3 = Theme.Colors.Surface.Stroke :: Color3,
								LayoutOrder = 4,
							}),

							-- Mutations section
							scope:New("Frame")({
								Name = "Mutations",
								Size = UDim2.fromScale(1, 0.22),
								BackgroundTransparency = 1,
								LayoutOrder = 5,

								[Children] = {
									scope:New("UIListLayout")({
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0.02, 0),
									}),

									-- Mutations header
									scope:New("Frame")({
										Size = UDim2.fromScale(1, 0.25),
										BackgroundTransparency = 1,
										LayoutOrder = 1,

										[Children] = {
											scope:New("TextLabel")({
												Size = UDim2.fromScale(0.12, 1),
												BackgroundTransparency = 1,
												Text = "🧬",
												TextScaled = true,
												Font = Enum.Font.GothamBold,
											}),
											scope:New("TextLabel")({
												Size = UDim2.fromScale(0.85, 1),
												Position = UDim2.fromScale(0.14, 0),
												BackgroundTransparency = 1,
												Text = "Mutations",
												TextColor3 = Colors.TextPrimary,
												TextScaled = true,
												Font = Theme.Typography.Fonts.Title,
												TextXAlignment = Enum.TextXAlignment.Left,

												[Children] = {
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 14,
														MinTextSize = 10,
													}),
												},
											}),
										},
									}),

									-- Mutation badges container
									scope:New("ScrollingFrame")({
										Size = UDim2.fromScale(1, 0.7),
										BackgroundTransparency = 1,
										ScrollBarThickness = 4,
										CanvasSize = UDim2.new(0, 0, 0, 0),
										AutomaticCanvasSize = Enum.AutomaticSize.Y,
										ScrollingDirection = Enum.ScrollingDirection.Y,
										LayoutOrder = 2,

										[Children] = {
											scope:New("UIPadding")({
												PaddingTop = UDim.new(0, 4),
												PaddingBottom = UDim.new(0, 8),
												PaddingLeft = UDim.new(0, 4),
												PaddingRight = UDim.new(0, 4),
											}),
											scope:New("UIListLayout")({
												SortOrder = Enum.SortOrder.LayoutOrder,
												Padding = UDim.new(0, 4),
											}),

											-- No mutations placeholder
											scope:New("TextLabel")({
												Size = UDim2.new(1, 0, 0, 24),
												BackgroundTransparency = 1,
												Text = "Aucune mutation",
												TextColor3 = Colors.TextMuted,
												TextScaled = true,
												Font = Theme.Typography.Fonts.Body,
												TextXAlignment = Enum.TextXAlignment.Center,
												Visible = scope:Computed(function(use)
													local mutations = use(props.Mutations) or {}
													return #mutations == 0
												end),

												[Children] = {
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 12,
														MinTextSize = 9,
													}),
												},
											}),

											-- Dynamic mutation badges
											ForValues(
												scope,
												scope:Computed(function(use)
													return use(props.Mutations) or {}
												end),
												function(use, innerScope, mutationId)
													return MutationBadge(innerScope, mutationId)
												end
											),
										},
									}),
								},
							}),

							-- Close button
							scope:New("TextButton")({
								Name = "CloseButton",
								Size = UDim2.fromScale(1, 0.08),
								BackgroundColor3 = Colors.CloseButton,
								Text = "Fermer",
								TextColor3 = Colors.TextPrimary,
								TextScaled = true,
								Font = Theme.Typography.Fonts.Title,
								LayoutOrder = 10,

								[OnEvent("Activated")] = props.OnClose,

								[Children] = {
									scope:New("UISizeConstraint")({
										MinSize = Vector2.new(100, 28),
										MaxSize = Vector2.new(300, 40),
									}),
									scope:New("UICorner")({
										CornerRadius = UDim.new(0.2, 0),
									}),
									scope:New("UIStroke")({
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = 1,
									}),
									scope:New("UITextSizeConstraint")({
										MaxTextSize = 14,
										MinTextSize = 10,
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return PlantTooltip
