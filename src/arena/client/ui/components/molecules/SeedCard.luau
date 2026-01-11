--!strict
--[[
	SeedCard.luau - Plant selection card with "Toon Pop" style
	
	Molecule component representing a plant in the HUD deck.
	Shows plant image, cost badge, mutation icons, and state overlays.
	
	Reactively updates locked state based on sun affordability.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)

-- Assets
local Assets = ReplicatedStorage:WaitForChild("Assets")
local PlantModels = Assets:WaitForChild("Plants")

-- Path: client/ui/components/molecules/SeedCard.luau
local Theme = require(Shared.ui.design.Theme)

local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local peek = Fusion.peek

-- Constants
local CARD_SIZE = 70
local SHADOW_OFFSET = 4
local COST_BADGE_HEIGHT = 22
local MUTATION_ICON_SIZE = 16
local COOLDOWN_UPDATE_INTERVAL = 0.1

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
	Setup ViewportFrame with 3D plant model
]]
local function setupViewport(viewport: ViewportFrame, plantType: string)
	-- Clear previous content
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end
	
	-- Get plant model
	local modelTemplate = PlantModels:FindFirstChild(plantType)
	if not modelTemplate then
		return
	end
	
	-- Create WorldModel for proper rendering
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	
	-- Clone and add model
	local model = modelTemplate:Clone()
	model.Parent = worldModel
	
	-- Position model at origin, rotate 90° to face camera
	if model.PrimaryPart then
		model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	end
	
	-- Create camera
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35 -- Narrower FOV for larger appearance
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	
	-- Calculate framing based on model bounds
	local cframe, size = model:GetBoundingBox()
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = maxSize * 1.5 -- Closer to model
	
	-- Position camera directly in front of the plant (facing it)
	local modelCenter = cframe.Position
	camera.CFrame = CFrame.new(
		modelCenter + Vector3.new(0, distance * 0.2, distance), -- Front view with slight upward offset
		modelCenter
	)
end

--[[
	SeedCard Component
	
	A clickable plant card with cost badge, mutation icons, and state overlays.
	Automatically locks when player can't afford the plant.
	
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
	
	-- Create ViewportFrame imperatively for 3D plant preview
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name = "PlantPreview"
	viewportFrame.Size = UDim2.new(1, 0, 0.85, 0) -- Larger viewport
	viewportFrame.Position = UDim2.new(0.5, 0, 0.4, 0)
	viewportFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	viewportFrame.BackgroundTransparency = 1
	viewportFrame.Ambient = Color3.fromRGB(200, 200, 200)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightDirection = Vector3.new(-1, -1, -1)
	viewportFrame.ZIndex = 3
	
	-- Setup viewport with plant model (deferred to ensure it's parented)
	task.defer(function()
		setupViewport(viewportFrame, plantType)
	end)
	
	-- Cleanup viewport when scope is destroyed
	table.insert(scope, viewportFrame)
	
	-- Internal state
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	local cooldownRatio = Value(scope, 0) -- 0 = ready, 1 = full cooldown (animated)
	
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
	table.insert(scope, Fusion.Observer(scope, SelectionState.Cooldowns):onChange(function()
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
	end))
	
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
	local canAfford = Computed(scope, function(use)
		local sunCount = use(SelectionState.SunCount)
		return sunCount >= cost
	end)
	
	-- Reactive: Check if on cooldown (uses cooldownRatio for reactivity)
	local isOnCooldown = Computed(scope, function(use)
		return use(cooldownRatio) > 0
	end)
	
	-- Reactive: Is this card selected?
	local isSelected = Computed(scope, function(use)
		return use(SelectionState.SelectedPlant) == plantType
	end)
	
	-- Has mutations (for gold border) - reactive
	local hasMutations = Computed(scope, function(use)
		local mutations = use(equippedMutations)
		return #mutations > 0
	end)
	
	-- Border color based on mutations and selection
	local borderColor = Computed(scope, function(use)
		if use(isSelected) then
			return Color3.fromHex("#FFFF00") -- Bright yellow for selected
		end
		if use(hasMutations) then
			return GOLD_BORDER
		end
		return Theme.Colors.Surface.Stroke :: Color3
	end)
	
	-- Border thickness
	local borderThickness = Computed(scope, function(use)
		if use(isSelected) then
			return 4
		end
		return Theme.Layout.StrokeThickness
	end)
	
	-- Press animation
	local targetOffset = Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end)
	local pressOffset = Spring(scope, targetOffset, 40, 0.7)
	
	-- Scale animation for hover
	local targetScale = Computed(scope, function(use)
		if use(isPressed) then return 0.95 end
		if use(isHovered) then return 1.05 end
		return 1
	end)
	local hoverScale = Spring(scope, targetScale, 35, 0.7)
	
	-- Card background color
	local cardColor = Computed(scope, function(use)
		if not use(canAfford) then
			return Color3.fromRGB(100, 80, 70) -- Darkened when locked
		end
		return Theme.Colors.Surface.Main
	end)
	
	local shadowColor = Theme.Colors.Surface.Shadow
	
	-- Build mutation icons reactively
	local mutationIconsComputed = Computed(scope, function(use)
		local mutations = use(equippedMutations)
		local icons: {any} = {}
		
		for i, mutationId in mutations do
			local mutation = MutationData.Get(mutationId)
			if mutation and i <= 3 then -- Max 3 icons
				table.insert(icons, New(scope, "TextLabel") {
					Name = `Mutation_{mutationId}`,
					Size = UDim2.fromOffset(MUTATION_ICON_SIZE, MUTATION_ICON_SIZE),
					BackgroundColor3 = mutation.Color,
					BackgroundTransparency = 0.3,
					Text = mutation.Icon or "?",
					TextSize = 12,
					Font = Enum.Font.GothamBold,
					TextColor3 = Color3.new(1, 1, 1),
					LayoutOrder = i,
					
					[Children] = {
						New(scope, "UICorner") {
							CornerRadius = UDim.new(0, 4),
						},
					},
				})
			end
		end
		
		return icons
	end)
	
	return New(scope, "Frame") {
		Name = `SeedCard_{plantType}`,
		Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		
		[Children] = {
			-- Scale container for hover animation
			New(scope, "Frame") {
				Size = UDim2.new(1, 0, 1, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundTransparency = 1,
				
				[Children] = {
					New(scope, "UIScale") { Scale = hoverScale },
					
					-- Aspect ratio constraint (square)
					New(scope, "UIAspectRatioConstraint") {
						AspectRatio = 1,
						AspectType = Enum.AspectType.ScaleWithParentSize,
					},
					
					-- Shadow Layer
					New(scope, "Frame") {
						Name = "Shadow",
						Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
						Position = UDim2.fromOffset(0, SHADOW_OFFSET),
						BackgroundColor3 = shadowColor,
						ZIndex = 1,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
						},
					},
					
					-- Surface Layer (interactive)
					New(scope, "TextButton") {
						Name = "Surface",
						Size = Computed(scope, function(use)
							local offset = use(pressOffset)
							return UDim2.new(1, 0, 1, -SHADOW_OFFSET - offset)
						end),
						Position = Computed(scope, function(use)
							return UDim2.fromOffset(0, use(pressOffset))
						end),
						BackgroundColor3 = cardColor,
						AutoButtonColor = false,
						Text = "",
						ZIndex = 2,
						
						[OnEvent("MouseButton1Down")] = function()
							if not peek(canAfford) or peek(isOnCooldown) then return end
							isPressed:set(true)
						end,
						
						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							if not peek(canAfford) or peek(isOnCooldown) then return end
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
							New(scope, "UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
							
							-- Dynamic border (gold for mutations, yellow for selected)
							New(scope, "UIStroke") {
								Color = borderColor,
								Thickness = borderThickness,
							},
							
							-- 3D Plant Model Preview (created imperatively)
							viewportFrame,
							
							-- Cost Badge (bottom-right pill)
							New(scope, "Frame") {
								Name = "CostBadge",
								Size = UDim2.fromOffset(36, COST_BADGE_HEIGHT),
								Position = UDim2.new(1, -4, 1, -4),
								AnchorPoint = Vector2.new(1, 1),
								BackgroundColor3 = Computed(scope, function(use)
									return if use(canAfford) 
										then Color3.fromHex("#FFD700") -- Gold
										else Theme.Colors.Danger.Main
								end),
								ZIndex = 5,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = UDim.new(0.5, 0),
									},
									New(scope, "UIStroke") {
										Color = Color3.new(0, 0, 0),
										Thickness = 1,
										Transparency = 0.5,
									},
									New(scope, "TextLabel") {
										Size = UDim2.new(1, 0, 1, 0),
										BackgroundTransparency = 1,
										Text = tostring(cost),
										TextColor3 = Computed(scope, function(use)
											return if use(canAfford)
												then Color3.new(0, 0, 0)
												else Color3.new(1, 1, 1)
										end),
										Font = Theme.Typography.Fonts.Body,
										TextSize = 14,
										ZIndex = 6,
									},
								},
							},
							
							-- Mutation Icons (top-right row) - reactive frame
							Computed(scope, function(use)
								local icons = use(mutationIconsComputed)
								if #icons > 0 then
									return New(scope, "Frame") {
										Name = "MutationIcons",
										Size = UDim2.new(1, -4, 0, MUTATION_ICON_SIZE),
										Position = UDim2.new(1, -2, 0, 2),
										AnchorPoint = Vector2.new(1, 0),
										BackgroundTransparency = 1,
										ZIndex = 5,
										
										[Children] = {
											New(scope, "UIListLayout") {
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Right,
												VerticalAlignment = Enum.VerticalAlignment.Top,
												Padding = UDim.new(0, 2),
											},
											table.unpack(icons),
										},
									}
								else
									return nil
								end
							end),
							
							-- Cooldown Overlay (shrinks vertically from top, animated)
							New(scope, "Frame") {
								Name = "CooldownOverlay",
								Size = Computed(scope, function(use)
									local ratio = use(cooldownRatio)
									return UDim2.new(1, 0, ratio, 0)
								end),
								Position = UDim2.new(0, 0, 0, 0),
								BackgroundColor3 = COOLDOWN_OVERLAY,
								BackgroundTransparency = 0.4,
								ZIndex = 10,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
							
							-- Locked Overlay (when can't afford)
							New(scope, "Frame") {
								Name = "LockedOverlay",
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundColor3 = LOCKED_OVERLAY,
								BackgroundTransparency = Computed(scope, function(use)
									return if use(canAfford) then 1 else 0.5
								end),
								ZIndex = 9,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
						},
					},
				},
			},
		},
	}
end

return SeedCard
