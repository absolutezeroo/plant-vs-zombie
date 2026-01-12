--!strict
--[[
	SeedCard.luau - Plant selection card with "Toon Pop" style (Arena - Responsive)
	
	Molecule component representing a plant in the HUD deck.
	Shows plant image, cost badge, mutation icons, and state overlays.
	
	Reactively updates locked state based on sun affordability.
	Fully responsive using Scale-based sizing.
	
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local Theme = require(Shared.ui.design.Theme)
local PlantViewport = require(Shared.ui.components.atoms.PlantViewport)

-- Path: client/ui/components/molecules/SeedCard.luau
local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

-- Fusion 0.3 primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Observer = Fusion.Observer
local peek = Fusion.peek

-- Colors
local GOLD_BORDER = Color3.fromHex("#FFD700")
local LOCKED_OVERLAY = Color3.fromRGB(0, 0, 0)
local COOLDOWN_OVERLAY = Color3.fromRGB(30, 30, 30)

export type SeedCardProps = {
	Scope: Fusion.Scope<any>,
	PlantType: string,
	LayoutOrder: number?,
	EquippedMutations: any, -- Can be {string} or Computed<{string}>
	OnClick: () -> (),
}

--[[
	SeedCard Component (Arena - Responsive)
	
	A clickable plant card with cost badge, mutation icons, and state overlays.
	Automatically locks when player can't afford the plant.
	Size is determined by parent container.
	
	@param props SeedCardProps
	@return Frame
]]
local function SeedCard(props: SeedCardProps): Frame
	local scope = props.Scope
	local plantType = props.PlantType
	local equippedMutations = props.EquippedMutations
	local layoutOrder = props.LayoutOrder or 0

	-- Get plant stats
	local plantStats = PlantData.GetStats(plantType)
	local cost = if plantStats then plantStats.Cost else 100

	-- Create ViewportFrame using shared PlantViewport atom
	local viewportFrame = PlantViewport.CreateWithScope(scope, {
		PlantType = plantType,
		Size = UDim2.fromScale(1, 0.85),
		Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		CameraFOV = 35,
		CameraDistance = 1.5,
		CameraHeight = 0.2,
	})

	-- Internal state
	local isHovered = scope:Value(false)
	local isPressed = scope:Value(false)
	local cooldownRatio = scope:Value(0) -- 0 = ready, 1 = full cooldown (animated)

	-- Cooldown update loop (updates the visual ratio every frame while on cooldown)
	local cooldownConnection: RBXScriptConnection? = nil

	local function updateCooldownRatio()
		local cooldowns = peek(SelectionState.Cooldowns)
		local cooldownEnd = cooldowns[plantType]
		if not cooldownEnd then
			cooldownRatio:set(0)
			return false -- No cooldown
		end

		local stats = PlantData.GetStats(plantType)
		local totalCooldown = if stats then stats.Cooldown else 5
		local remaining = math.max(0, cooldownEnd - tick())

		if remaining <= 0 then
			cooldownRatio:set(0)
			return false -- Cooldown finished
		end

		local ratio = remaining / totalCooldown
		cooldownRatio:set(ratio)
		return true -- Still on cooldown
	end

	-- Start cooldown loop when Cooldowns change
	table.insert(
		scope,
		Observer(scope, SelectionState.Cooldowns):onChange(function()
			-- Update immediately
			local stillOnCooldown = updateCooldownRatio()

			-- If on cooldown and no connection, start the update loop
			if stillOnCooldown and not cooldownConnection then
				cooldownConnection = RunService.Heartbeat:Connect(function()
					local stillActive = updateCooldownRatio()
					if not stillActive and cooldownConnection then
						cooldownConnection:Disconnect()
						cooldownConnection = nil
					end
				end)
			end
		end)
	)

	-- Cleanup connection when scope is destroyed
	table.insert(scope, function()
		if cooldownConnection then
			cooldownConnection:Disconnect()
			cooldownConnection = nil
		end
	end)

	-- Initial check
	updateCooldownRatio()

	-- Reactive: Check if player can afford this plant
	local canAfford = scope:Computed(function(use)
		local sunCount = use(SelectionState.SunCount)
		return sunCount >= cost
	end)

	-- Reactive: Check if on cooldown (uses cooldownRatio for reactivity)
	local isOnCooldown = scope:Computed(function(use)
		return use(cooldownRatio) > 0
	end)

	-- Reactive: Is this card selected?
	local isSelected = scope:Computed(function(use)
		return use(SelectionState.SelectedPlant) == plantType
	end)

	-- Has mutations (for gold border) - reactive
	local hasMutations = scope:Computed(function(use)
		local mutations = use(equippedMutations)
		return mutations and #mutations > 0
	end)

	-- Border color based on mutations and selection
	local borderColor = scope:Computed(function(use)
		if use(isSelected) then
			return Color3.fromHex("#FFFF00") -- Bright yellow for selected
		end
		if use(hasMutations) then
			return GOLD_BORDER
		end
		return Theme.Colors.Surface.Stroke :: Color3
	end)

	-- Border thickness
	local borderThickness = scope:Computed(function(use)
		if use(isSelected) then
			return 4
		end
		return Theme.Layout.StrokeThickness
	end)

	-- Press animation (as percentage)
	local pressOffset = scope:Spring(
		scope:Computed(function(use)
			return if use(isPressed) then 0.06 else 0
		end),
		40,
		0.7
	)

	-- Scale animation for hover
	local hoverScale = scope:Spring(
		scope:Computed(function(use)
			if use(isPressed) then
				return 0.95
			end
			if use(isHovered) then
				return 1.05
			end
			return 1
		end),
		35,
		0.7
	)

	-- Card background color
	local cardColor = scope:Computed(function(use)
		if not use(canAfford) then
			return Color3.fromRGB(100, 80, 70) -- Darkened when locked
		end
		return Theme.Colors.Surface.Main
	end)

	local shadowColor = Theme.Colors.Surface.Shadow

	-- Build mutation icons reactively
	local mutationIconsComputed = scope:Computed(function(use)
		local mutations = use(equippedMutations) or {}
		local icons: { any } = {}

		for i, mutationId in mutations do
			local mutation = MutationData.Get(mutationId)
			if mutation and i <= 3 then -- Max 3 icons
				table.insert(
					icons,
					scope:New("Frame")({
						Name = `Mutation_{mutationId}`,
						Size = UDim2.fromScale(0.28, 1), -- Relative to icon row
						BackgroundColor3 = mutation.Color,
						BackgroundTransparency = 0.3,
						LayoutOrder = i,

						[Children] = {
							scope:New("UIAspectRatioConstraint")({
								AspectRatio = 1,
							}),
							scope:New("UICorner")({
								CornerRadius = UDim.new(0.2, 0),
							}),
							scope:New("TextLabel")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = mutation.Icon or "?",
								TextScaled = true,
								Font = Enum.Font.GothamBold,
								TextColor3 = Color3.new(1, 1, 1),

								[Children] = {
									scope:New("UITextSizeConstraint")({
										MaxTextSize = 14,
										MinTextSize = 6,
									}),
								},
							}),
						},
					})
				)
			end
		end

		return icons
	end)

	return scope:New("Frame")({
		Name = `SeedCard_{plantType}`,
		Size = UDim2.fromScale(1, 1), -- Size determined by parent
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,

		[Children] = {
			-- Aspect ratio constraint (square)
			scope:New("UIAspectRatioConstraint")({
				AspectRatio = 1,
			}),

			-- Scale container for hover animation
			scope:New("Frame")({
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					scope:New("UIScale")({ Scale = hoverScale }),

					-- Shadow Layer (6% offset)
					scope:New("Frame")({
						Name = "Shadow",
						Size = UDim2.fromScale(1, 0.94),
						Position = UDim2.fromScale(0, 0.06),
						BackgroundColor3 = shadowColor,
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Layout.CornerRadius,
							}),
						},
					}),

					-- Surface Layer (interactive)
					scope:New("TextButton")({
						Name = "Surface",
						Size = scope:Computed(function(use)
							local offset = use(pressOffset)
							return UDim2.fromScale(1, 0.94 - offset)
						end),
						Position = scope:Computed(function(use)
							return UDim2.fromScale(0, use(pressOffset))
						end),
						BackgroundColor3 = cardColor,
						AutoButtonColor = false,
						Text = "",
						ZIndex = 2,

						[OnEvent("MouseButton1Down")] = function()
							if not peek(canAfford) or peek(isOnCooldown) then
								return
							end
							isPressed:set(true)
						end,

						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							if not peek(canAfford) or peek(isOnCooldown) then
								return
							end
							if peek(isHovered) then
								props.OnClick()
							end
						end,

						[OnEvent("MouseEnter")] = function()
							isHovered:set(true)
						end,

						[OnEvent("MouseLeave")] = function()
							isHovered:set(false)
							isPressed:set(false)
						end,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Layout.CornerRadius,
							}),

							-- Dynamic border (gold for mutations, yellow for selected)
							scope:New("UIStroke")({
								Color = borderColor,
								Thickness = borderThickness,
							}),

							-- 3D Plant Model Preview
							viewportFrame,

							-- Cost Badge (bottom-right pill)
							scope:New("Frame")({
								Name = "CostBadge",
								Size = UDim2.fromScale(0.5, 0.3),
								Position = UDim2.fromScale(0.95, 0.95),
								AnchorPoint = Vector2.new(1, 1),
								BackgroundColor3 = scope:Computed(function(use)
									return if use(canAfford)
										then Color3.fromHex("#FFD700") -- Gold
										else Theme.Colors.Danger.Main
								end),
								ZIndex = 5,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0.5, 0),
									}),
									scope:New("UIStroke")({
										Color = Color3.new(0, 0, 0),
										Thickness = 1,
										Transparency = 0.5,
									}),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = tostring(cost),
										TextColor3 = scope:Computed(function(use)
											return if use(canAfford) then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
										end),
										Font = Theme.Typography.Fonts.Body,
										TextScaled = true,
										ZIndex = 6,

										[Children] = {
											scope:New("UITextSizeConstraint")({
												MaxTextSize = 14,
												MinTextSize = 8,
											}),
										},
									}),
								},
							}),

							-- Mutation Icons (top-right row) - reactive frame
							scope:Computed(function(use)
								local icons = use(mutationIconsComputed)
								if #icons > 0 then
									return scope:New("Frame")({
										Name = "MutationIcons",
										Size = UDim2.fromScale(0.8, 0.22),
										Position = UDim2.fromScale(0.95, 0.05),
										AnchorPoint = Vector2.new(1, 0),
										BackgroundTransparency = 1,
										ZIndex = 5,

										[Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Right,
												VerticalAlignment = Enum.VerticalAlignment.Top,
												Padding = UDim.new(0.05, 0),
											}),
											table.unpack(icons),
										},
									})
								else
									return nil
								end
							end),

							-- Cooldown Overlay (shrinks vertically from top, animated)
							scope:New("Frame")({
								Name = "CooldownOverlay",
								Size = scope:Computed(function(use)
									local ratio = use(cooldownRatio)
									return UDim2.fromScale(1, ratio)
								end),
								Position = UDim2.fromScale(0, 0),
								BackgroundColor3 = COOLDOWN_OVERLAY,
								BackgroundTransparency = 0.4,
								ZIndex = 10,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Layout.CornerRadius,
									}),
								},
							}),

							-- Locked Overlay (when can't afford)
							scope:New("Frame")({
								Name = "LockedOverlay",
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = LOCKED_OVERLAY,
								BackgroundTransparency = scope:Computed(function(use)
									return if use(canAfford) then 1 else 0.5
								end),
								ZIndex = 9,

								[Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Layout.CornerRadius,
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

return SeedCard
