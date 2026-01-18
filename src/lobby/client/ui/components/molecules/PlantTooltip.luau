--!strict
--[[
	PlantTooltip.luau - Displays detailed plant information on click
	
	Features:
	- 3D model preview using ViewportFrame
	- Plant stats (Health, Damage, Attack Speed, etc.)
	- Active mutations with effects
	- Toon Pop styling with Shadow + Main pattern
	
	Uses Fusion 0.3 scope:Method() syntax.
	Fully responsive using Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local Theme = require(Shared.ui.design.Theme)
local IconAssets = require(Shared.ui.design.IconAssets)
local Logger = require(Shared.utils.Logger)
local Icon = require(Shared.ui.components.base.Icon)

-- Fusion primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Asset folder for plant models
local Assets = ReplicatedStorage:WaitForChild("Assets")
local PlantModels = Assets:WaitForChild("Plants")

-- Stat icons (emoji)
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

--------------------------------------------------------------------------------
-- Setup ViewportFrame with 3D model and camera
--------------------------------------------------------------------------------
local function setupViewport(viewport: ViewportFrame, plantType: string)
	Logger.Debug("PlantTooltip", `setupViewport called for {plantType}`)

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

	-- Create WorldModel to hold the model
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	-- Clone and add to WorldModel
	local model = modelTemplate:Clone()
	model.Parent = worldModel

	-- Reset model position to origin and rotate 180° to face camera
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

	-- Position camera to look at model from front-right angle
	local modelCenter = cframe.Position
	camera.CFrame = CFrame.new(modelCenter + Vector3.new(distance * 0.6, distance * 0.4, distance * 0.8), modelCenter)
end

--------------------------------------------------------------------------------
-- StatRow - A single stat display row (Responsive)
--------------------------------------------------------------------------------
local function StatRow(
	scope: any,
	props: {
		Icon: string,
		Label: string,
		Value: any,
		Color: Color3?,
	}
): Frame
	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 0.18),
		BackgroundTransparency = 1,

		[Children] = {
			-- Icon
			scope:New("TextLabel")({
				Size = UDim2.fromScale(0.12, 1),
				BackgroundTransparency = 1,
				Text = props.Icon,
				TextScaled = true,

				[Children] = {
					scope:New("UITextSizeConstraint")({ MaxTextSize = 16, MinTextSize = 10 }),
				},
			}),

			-- Label
			scope:New("TextLabel")({
				Size = UDim2.fromScale(0.5, 1),
				Position = UDim2.fromScale(0.14, 0),
				BackgroundTransparency = 1,
				Text = props.Label,
				TextColor3 = Theme.Colors.Surface.Shadow,
				TextScaled = true,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,

				[Children] = {
					scope:New("UITextSizeConstraint")({ MaxTextSize = 14, MinTextSize = 9 }),
				},
			}),

			-- Value
			scope:New("TextLabel")({
				Size = UDim2.fromScale(0.32, 1),
				Position = UDim2.fromScale(0.68, 0),
				BackgroundTransparency = 1,
				Text = props.Value,
				TextColor3 = props.Color or Theme.Colors.Surface.Stroke :: Color3,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,

				[Children] = {
					scope:New("UITextSizeConstraint")({ MaxTextSize = 14, MinTextSize = 9 }),
				},
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- MutationBadge - Displays a mutation (Responsive)
--------------------------------------------------------------------------------
local function MutationBadge(scope: any, mutationId: string): Frame
	local mutation = MutationData.Get(mutationId)
	if not mutation then
		return scope:New("Frame")({ Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 })
	end

	local badgeColor = mutation.Color or Theme.Colors.Purple.Main
	-- Get IconName for the mutation type (e.g., "Fire", "Ice", "Electric")
	local iconName = mutation.Type or "Mutation"

	return scope:New("Frame")({
		Size = UDim2.new(1, 0, 0, 40), -- Fixed pixel height for AutomaticCanvasSize
		BackgroundColor3 = badgeColor,
		BackgroundTransparency = 0.8,

		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			scope:New("UIStroke")({
				Color = badgeColor,
				Thickness = 1,
				Transparency = 0.5,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0.03, 0),
				PaddingRight = UDim.new(0.03, 0),
			}),

			-- Icon + Name Row
			scope:New("Frame")({
				Name = "NameRow",
				Size = UDim2.fromScale(1, 0.55),
				Position = UDim2.fromScale(0, 0.05),
				BackgroundTransparency = 1,

				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 4),
					}),

					-- Mutation Type Icon
					Icon(scope, {
						Name = iconName,
						Size = UDim2.new(0, 16, 0, 16),
						LayoutOrder = 1,
					}),

					-- Mutation Name
					scope:New("TextLabel")({
						Size = UDim2.new(1, -20, 1, 0),
						BackgroundTransparency = 1,
						Text = mutation.Name,
						TextColor3 = badgeColor,
						TextScaled = true,
						Font = Theme.Typography.Fonts.Title,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2,

						[Children] = {
							scope:New("UITextSizeConstraint")({ MaxTextSize = 14, MinTextSize = 9 }),
						},
					}),
				},
			}),

			-- Description
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 0.38),
				Position = UDim2.fromScale(0, 0.55),
				BackgroundTransparency = 1,
				Text = mutation.Description or "",
				TextColor3 = Theme.Colors.Surface.Shadow,
				TextScaled = true,
				Font = Theme.Typography.Fonts.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,

				[Children] = {
					scope:New("UITextSizeConstraint")({ MaxTextSize = 11, MinTextSize = 8 }),
				},
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- PlantTooltip Component (Toon Pop + Responsive)
--------------------------------------------------------------------------------
local function PlantTooltip(props: PlantTooltipProps): Frame
	local scope = props.Scope

	-- Close button animation
	local isClosePressed = scope:Value(false)
	local closeOffset = scope:Spring(
		scope:Computed(function(use)
			return if use(isClosePressed) then 0.08 else 0
		end),
		40,
		0.7
	)

	-- Get plant stats reactively
	local plantStats = scope:Computed(function(use)
		local plantType = use(props.PlantType)
		if not plantType then
			return nil
		end
		return PlantData.GetStats(plantType)
	end)

	-- Plant name
	local plantName = scope:Computed(function(use)
		local stats = use(plantStats)
		return if stats then stats.Name else "Unknown Plant"
	end)

	-- Category info
	local categoryInfo = scope:Computed(function(use)
		local stats = use(plantStats)
		if not stats then
			return { text = "", color = Theme.Colors.Surface.Shadow }
		end

		local colors = {
			Attacker = Theme.Colors.Danger.Main,
			Defender = Theme.Colors.Info.Main,
			Producer = Theme.Colors.Action.Main,
			Special = Theme.Colors.Purple.Main,
		}
		return {
			text = stats.Category or "",
			color = colors[stats.Category] or Theme.Colors.Surface.Shadow,
		}
	end)

	-- Plant description
	local plantDescription = scope:Computed(function(use)
		local plantType = use(props.PlantType) or ""
		local data = PlantData[plantType]
		return if data then data.Description else ""
	end)

	-- Animated scale for pop-in effect
	local animatedScale = scope:Spring(
		scope:Computed(function(use)
			return if use(props.Visible) then 1 else 0.8
		end),
		35,
		0.7
	)

	-- Animated transparency
	local animatedTransparency = scope:Spring(
		scope:Computed(function(use)
			return if use(props.Visible) then 0 else 1
		end),
		30,
		1
	)

	-- Create viewport imperatively for 3D preview
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name = "ModelPreview"
	viewportFrame.Size = UDim2.fromScale(1, 1)
	viewportFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	viewportFrame.BackgroundTransparency = 0.3
	viewportFrame.Ambient = Color3.fromRGB(200, 200, 200)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightDirection = Vector3.new(-1, -1, -1)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Layout.CornerRadius
	corner.Parent = viewportFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Surface.Stroke :: Color3
	stroke.Thickness = 2
	stroke.Parent = viewportFrame

	-- Cleanup viewport when scope is destroyed
	table.insert(scope, viewportFrame)

	-- Update viewport when plant type changes
	local observer = Fusion.Observer(scope, props.PlantType)
	observer:onBind(function()
		local plantType = peek(props.PlantType)
		if plantType then
			task.defer(function()
				setupViewport(viewportFrame, plantType)
			end)
		end
	end)

	-- Build mutation badges
	local mutationBadges = scope:Computed(function(use)
		local mutations = use(props.Mutations) or {}
		local badges: { any } = {}
		for i, mutId in mutations :: { string } do
			table.insert(badges, MutationBadge(scope, mutId))
		end
		return badges
	end)

	return scope:New("Frame")({
		Name = "PlantTooltip",
		Size = UDim2.fromScale(0.22, 0.55),
		Position = props.Position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			local trans = use(animatedTransparency) :: number
			return trans < 0.99
		end),
		ZIndex = 100,

		[Children] = {
			-- Scale animation
			scope:New("UIScale")({
				Scale = animatedScale,
			}),

			-- Shadow
			scope:New("Frame")({
				Name = "Shadow",
				Size = UDim2.fromScale(1, 0.985),
				Position = UDim2.fromScale(0.5, 0.015),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.Colors.Surface.Shadow,
				ZIndex = 1,

				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				},
			}),

			-- Main panel
			scope:New("Frame")({
				Name = "Main",
				Size = UDim2.fromScale(1, 0.985),
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Theme.Colors.Surface.Main,
				ZIndex = 2,

				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIStroke")({
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = Theme.Layout.StrokeThickness,
					}),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0.025, 0),
						PaddingBottom = UDim.new(0.025, 0),
						PaddingLeft = UDim.new(0.04, 0),
						PaddingRight = UDim.new(0.04, 0),
					}),

					-- ═══════════════════════════════════════════════
					-- HEADER: 3D Preview + Name (top 28%)
					-- ═══════════════════════════════════════════════
					scope:New("Frame")({
						Name = "Header",
						Size = UDim2.fromScale(1, 0.28),
						BackgroundTransparency = 1,

						[Children] = {
							-- ViewportFrame container (left square)
							scope:New("Frame")({
								Name = "ViewportContainer",
								Size = UDim2.fromScale(0.4, 1),
								BackgroundTransparency = 1,

								[Children] = {
									scope:New("UIAspectRatioConstraint")({ AspectRatio = 1 }),
									viewportFrame,
								},
							}),

							-- Name + Category (right side)
							scope:New("Frame")({
								Name = "NameContainer",
								Size = UDim2.fromScale(0.55, 1),
								Position = UDim2.fromScale(0.45, 0),
								BackgroundTransparency = 1,

								[Children] = {
									-- Plant name
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 0.45),
										Position = UDim2.fromScale(0, 0.1),
										BackgroundTransparency = 1,
										Text = plantName,
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Title,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Top,

										[Children] = {
											scope:New("UITextSizeConstraint")({ MaxTextSize = 22, MinTextSize = 14 }),
										},
									}),

									-- Category badge
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 0.25),
										Position = UDim2.fromScale(0, 0.45),
										BackgroundTransparency = 1,
										Text = scope:Computed(function(use)
											local info = use(categoryInfo)
											return info.text
										end),
										TextColor3 = scope:Computed(function(use)
											local info = use(categoryInfo)
											return info.color
										end),
										TextScaled = true,
										Font = Theme.Typography.Fonts.Body,
										TextXAlignment = Enum.TextXAlignment.Left,

										[Children] = {
											scope:New("UITextSizeConstraint")({ MaxTextSize = 14, MinTextSize = 10 }),
										},
									}),

									-- Plant description
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 0.25),
										Position = UDim2.fromScale(0, 0.72),
										BackgroundTransparency = 1,
										Text = plantDescription,
										TextColor3 = Theme.Colors.Surface.Shadow,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Body,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextWrapped = true,

										[Children] = {
											scope:New("UITextSizeConstraint")({ MaxTextSize = 11, MinTextSize = 8 }),
										},
									}),
								},
							}),
						},
					}),

					-- Separator 1
					scope:New("Frame")({
						Size = UDim2.fromScale(1, 0.003),
						Position = UDim2.fromScale(0.5, 0.30),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Theme.Colors.Surface.Stroke :: Color3,
					}),

					-- ═══════════════════════════════════════════════
					-- STATS SECTION (30% to 58% = 28%)
					-- ═══════════════════════════════════════════════
					scope:New("Frame")({
						Name = "Stats",
						Size = UDim2.fromScale(1, 0.26),
						Position = UDim2.fromScale(0, 0.32),
						BackgroundTransparency = 1,

						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0.02, 0),
							}),

							StatRow(scope, {
								Icon = STAT_ICONS.Health,
								Label = "Santé",
								Value = scope:Computed(function(use)
									local stats = use(plantStats)
									return if stats then tostring(stats.Health) else "-"
								end),
								Color = Theme.Colors.Action.Main,
							}),

							StatRow(scope, {
								Icon = STAT_ICONS.Damage,
								Label = "Dégâts",
								Value = scope:Computed(function(use)
									local stats = use(plantStats)
									return if stats and stats.Damage > 0 then tostring(stats.Damage) else "-"
								end),
								Color = Theme.Colors.Danger.Main,
							}),

							StatRow(scope, {
								Icon = STAT_ICONS.AttackSpeed,
								Label = "Vitesse",
								Value = scope:Computed(function(use)
									local stats = use(plantStats)
									return if stats and stats.AttackSpeed > 0 then `{stats.AttackSpeed}/s` else "-"
								end),
								Color = Theme.Colors.Info.Main,
							}),

							StatRow(scope, {
								Icon = STAT_ICONS.Cost,
								Label = "Coût",
								Value = scope:Computed(function(use)
									local stats = use(plantStats)
									return if stats then tostring(stats.Cost) else "-"
								end),
								Color = Theme.Colors.Gold.Main,
							}),

							StatRow(scope, {
								Icon = STAT_ICONS.Cooldown,
								Label = "Recharge",
								Value = scope:Computed(function(use)
									local stats = use(plantStats)
									return if stats then `{stats.Cooldown}s` else "-"
								end),
								Color = nil,
							}),
						},
					}),

					-- Separator 2
					scope:New("Frame")({
						Size = UDim2.fromScale(1, 0.003),
						Position = UDim2.fromScale(0.5, 0.60),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Theme.Colors.Surface.Stroke :: Color3,
					}),

					-- ═══════════════════════════════════════════════
					-- MUTATIONS SECTION (62% to 88% = 26%)
					-- ═══════════════════════════════════════════════
					scope:New("Frame")({
						Name = "Mutations",
						Size = UDim2.fromScale(1, 0.26),
						Position = UDim2.fromScale(0, 0.62),
						BackgroundTransparency = 1,

						[Children] = {
							-- Header
							scope:New("Frame")({
								Size = UDim2.fromScale(1, 0.22),
								BackgroundTransparency = 1,

								[Children] = {
									-- Mutation icon (image when available)
									scope:New("ImageLabel")({
										Size = UDim2.fromScale(0.1, 1),
										BackgroundTransparency = 1,
										Image = IconAssets.Get("Mutation"),
										Visible = IconAssets.HasImage("Mutation"),
									}),
									-- Mutation icon (emoji fallback)
									scope:New("TextLabel")({
										Size = UDim2.fromScale(0.1, 1),
										BackgroundTransparency = 1,
										Text = IconAssets.GetEmoji("Mutation"),
										TextScaled = true,
										Visible = not IconAssets.HasImage("Mutation"),

										[Children] = {
											scope:New("UITextSizeConstraint")({ MaxTextSize = 16, MinTextSize = 10 }),
										},
									}),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(0.88, 1),
										Position = UDim2.fromScale(0.12, 0),
										BackgroundTransparency = 1,
										Text = "Mutations",
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Title,
										TextXAlignment = Enum.TextXAlignment.Left,

										[Children] = {
											scope:New("UITextSizeConstraint")({ MaxTextSize = 14, MinTextSize = 10 }),
										},
									}),
								},
							}),

							-- Mutations list
							scope:New("ScrollingFrame")({
								Size = UDim2.fromScale(1, 0.75),
								Position = UDim2.fromScale(0, 0.25),
								BackgroundTransparency = 1,
								ScrollBarThickness = 4,
								ScrollBarImageColor3 = Theme.Colors.Surface.Shadow,
								CanvasSize = UDim2.new(0, 0, 0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								ScrollingDirection = Enum.ScrollingDirection.Y,

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
										Size = UDim2.new(1, 0, 0, 24), -- Fixed pixel height
										BackgroundTransparency = 1,
										Text = "Aucune mutation",
										TextColor3 = Theme.Colors.Surface.Shadow,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Body,
										TextXAlignment = Enum.TextXAlignment.Center,
										Visible = scope:Computed(function(use)
											local mutations = use(props.Mutations) or {}
											return #mutations == 0
										end),

										[Children] = {
											scope:New("UITextSizeConstraint")({ MaxTextSize = 12, MinTextSize = 9 }),
										},
									}),

									-- Mutation badges
									mutationBadges,
								},
							}),
						},
					}),

					-- ═══════════════════════════════════════════════
					-- CLOSE BUTTON (bottom 10%)
					-- ═══════════════════════════════════════════════
					scope:New("Frame")({
						Name = "CloseContainer",
						Size = UDim2.fromScale(1, 0.09),
						Position = UDim2.fromScale(0.5, 0.91),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,

						[Children] = {
							-- Shadow
							scope:New("Frame")({
								Size = UDim2.fromScale(1, 0.85),
								Position = UDim2.fromScale(0, 0.15),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,

								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
								},
							}),

							-- Button
							scope:New("TextButton")({
								Size = scope:Computed(function(use)
									local offset = use(closeOffset) :: number
									return UDim2.fromScale(1, 0.85 - offset)
								end),
								Position = scope:Computed(function(use)
									local offset = use(closeOffset) :: number
									return UDim2.fromScale(0, offset)
								end),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								Text = "Close",
								TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
								TextScaled = true,
								Font = Theme.Typography.Fonts.Title,
								AutoButtonColor = false,
								ZIndex = 2,

								[OnEvent("MouseButton1Down")] = function()
									isClosePressed:set(true)
								end,

								[OnEvent("MouseButton1Up")] = function()
									isClosePressed:set(false)
									props.OnClose()
								end,

								[OnEvent("MouseLeave")] = function()
									isClosePressed:set(false)
								end,

								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
									scope:New("UITextSizeConstraint")({ MaxTextSize = 14, MinTextSize = 10 }),
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
