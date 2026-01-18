--!strict
--[[
	MutationScreen.luau - Mutation Lab (Toon Pop Cartoon Lab)
	
	A fun cartoon laboratory aesthetic:
	- Bubbly mutation capsules with bold colors
	- Classic Toon Pop shadow/main pattern
	- Playful badges and icons
	- No sci-fi neon - pure cartoon style
	
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local PlantViewport = require(Shared.ui.components.cards.PlantViewport)
local Icon = require(Shared.ui.components.base.Icon)

-- Layout components
local ScreenOverlay = require(Shared.ui.components.layout.ScreenOverlay)
local ScreenHeader = require(Shared.ui.components.layout.ScreenHeader)
local ScrollableGrid = require(Shared.ui.components.layout.ScrollableGrid)

-- Fusion primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Constants
local MAX_EQUIPPED_MUTATIONS = 3

-- Mutation type styling (cartoon colors)
local MUTATION_STYLES: { [string]: { Main: Color3, Shadow: Color3, Icon: string } } = {
	Fire = { Main = Color3.fromRGB(255, 100, 50), Shadow = Color3.fromRGB(180, 60, 30), Icon = "🔥" },
	Ice = { Main = Color3.fromRGB(100, 200, 255), Shadow = Color3.fromRGB(60, 140, 200), Icon = "❄️" },
	Electric = { Main = Color3.fromRGB(255, 220, 50), Shadow = Color3.fromRGB(200, 160, 30), Icon = "⚡" },
	Toxic = { Main = Color3.fromRGB(150, 230, 80), Shadow = Color3.fromRGB(100, 170, 50), Icon = "☠️" },
	Shadow = { Main = Color3.fromRGB(140, 100, 180), Shadow = Color3.fromRGB(90, 60, 130), Icon = "🌑" },
	Solar = { Main = Color3.fromRGB(255, 180, 50), Shadow = Color3.fromRGB(200, 130, 30), Icon = "☀️" },
	Reinforced = { Main = Color3.fromRGB(150, 180, 210), Shadow = Color3.fromRGB(100, 130, 160), Icon = "🛡️" },
	Primal = { Main = Color3.fromRGB(230, 100, 150), Shadow = Color3.fromRGB(170, 60, 110), Icon = "💥" },
	Swift = { Main = Color3.fromRGB(100, 220, 200), Shadow = Color3.fromRGB(60, 160, 150), Icon = "💨" },
	Damage = { Main = Color3.fromRGB(255, 80, 100), Shadow = Color3.fromRGB(180, 50, 70), Icon = "⚔️" },
	Health = { Main = Color3.fromRGB(255, 130, 170), Shadow = Color3.fromRGB(200, 90, 130), Icon = "❤️" },
	Range = { Main = Color3.fromRGB(100, 200, 130), Shadow = Color3.fromRGB(60, 150, 90), Icon = "🎯" },
}

local function getMutationStyle(mutationType: string): { Main: Color3, Shadow: Color3, Icon: string }
	return MUTATION_STYLES[mutationType] or { 
		Main = Theme.Colors.Purple.Main, 
		Shadow = Theme.Colors.Purple.Shadow, 
		Icon = "✨" 
	}
end

export type MutationScreenProps = {
	Scope: Fusion.Scope<any>,
	PlayerData: any,
	OwnedMutations: any,
	EquippedMutations: any,
	OnBack: () -> (),
	OnPurchaseMutation: (plantType: string, mutationType: string) -> (),
	OnEquipMutation: (plantType: string, mutationType: string) -> (),
	OnUnequipMutation: (plantType: string, mutationType: string) -> (),
}

--------------------------------------------------------------------------------
-- PlantCapsule - Toon Pop plant selector (bubble/capsule style)
--------------------------------------------------------------------------------
local function PlantCapsule(
	scope: Fusion.Scope<any>,
	plantType: string,
	isSelected: any,
	equippedCount: number,
	onSelect: () -> ()
): Frame
	local isPressed = scope:Value(false)
	local hasEquipped = equippedCount > 0

	local pressScale = scope:Spring(
		scope:Computed(function(use)
			return if use(isPressed) then 0.9 else 1
		end),
		40,
		0.7
	)

	return scope:New("Frame")({
		Name = "Capsule_" .. plantType,
		Size = UDim2.fromOffset(75, 95),
		BackgroundTransparency = 1,

		[Children] = {
			-- Scale wrapper
			scope:New("Frame")({
				Name = "ScaleWrapper",
				Size = scope:Computed(function(use)
					local s = use(pressScale)
					return UDim2.fromScale(s, s)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					-- Shadow
					scope:New("Frame")({
						Name = "Shadow",
						Size = UDim2.fromScale(1, 0.9),
						Position = UDim2.fromScale(0.5, 0.1),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = scope:Computed(function(use)
							if use(isSelected) then return Theme.Colors.Purple.Shadow end
							if hasEquipped then return Color3.fromRGB(100, 70, 130) end
							return Theme.Colors.Surface.Shadow
						end),
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
						},
					}),

					-- Main capsule
					scope:New("TextButton")({
						Name = "Main",
						Size = UDim2.fromScale(1, 0.9),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = scope:Computed(function(use)
							if use(isSelected) then return Theme.Colors.Purple.Main end
							if hasEquipped then return Color3.fromRGB(140, 100, 180) end
							return Theme.Colors.Surface.Main
						end),
						AutoButtonColor = false,
						Text = "",
						ZIndex = 2,

						[OnEvent("MouseButton1Down")] = function()
							isPressed:set(true)
						end,

						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							onSelect()
						end,

						[OnEvent("MouseLeave")] = function()
							isPressed:set(false)
						end,

						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),

							scope:New("UIStroke")({
								Color = scope:Computed(function(use)
									if use(isSelected) then return Color3.new(1, 1, 1) end
									return Theme.Colors.Surface.Stroke :: Color3
								end),
								Thickness = scope:Computed(function(use)
									return if use(isSelected) then 3 else 2
								end),
							}),

							-- Bubble highlight (top)
							scope:New("Frame")({
								Name = "BubbleHighlight",
								Size = UDim2.fromScale(0.5, 0.15),
								Position = UDim2.fromScale(0.3, 0.08),
								BackgroundColor3 = Color3.new(1, 1, 1),
								BackgroundTransparency = 0.7,
								ZIndex = 3,

								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
								},
							}),

							-- Plant viewport
							PlantViewport.CreateWithScope(scope, {
								PlantType = plantType,
								Size = UDim2.fromScale(0.85, 0.6),
								Position = UDim2.fromScale(0.5, 0.4),
								AnchorPoint = Vector2.new(0.5, 0.5),
								ZIndex = 3,
								CameraFOV = 35,
								CameraDistance = 1.4,
								CameraHeight = 0.1,
							}),

							-- Name tag
							scope:New("Frame")({
								Name = "NameTag",
								Size = UDim2.fromScale(0.9, 0.18),
								Position = UDim2.fromScale(0.5, 0.88),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = scope:Computed(function(use)
									if use(isSelected) then return Theme.Colors.Purple.Shadow end
									return Theme.Colors.Surface.Shadow
								end),
								ZIndex = 4,

								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }),

									scope:New("TextLabel")({
										Size = UDim2.fromScale(0.95, 1),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = plantType,
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										Font = Enum.Font.GothamBold,
										TextTruncate = Enum.TextTruncate.AtEnd,

										[Children] = {
											scope:New("UITextSizeConstraint")({ MaxTextSize = 10, MinTextSize = 7 }),
										},
									}),
								},
							}),

							-- Equipped badge (DNA bubble)
							hasEquipped and scope:New("Frame")({
								Name = "EquipBadge",
								Size = UDim2.fromOffset(24, 24),
								Position = UDim2.new(1, -2, 0, 2),
								AnchorPoint = Vector2.new(1, 0),
								BackgroundColor3 = Theme.Colors.Purple.Main,
								ZIndex = 10,

								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
									scope:New("UIStroke")({
										Color = Color3.new(1, 1, 1),
										Thickness = 2,
									}),
									scope:New("TextLabel")({
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "🧬" .. tostring(equippedCount),
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										Font = Enum.Font.GothamBold,

										[Children] = {
											scope:New("UITextSizeConstraint")({ MaxTextSize = 10, MinTextSize = 6 }),
										},
									}),
								},
							}) or nil,
						},
					}),
				},
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- MutationBubble - Toon Pop mutation card (bubbly potion style)
--------------------------------------------------------------------------------
local function MutationBubble(
	scope: Fusion.Scope<any>,
	mutationType: string,
	mutationData: any,
	isOwned: boolean,
	isEquipped: boolean,
	isLocked: boolean,
	isSelected: any,
	onSelect: () -> (),
	layoutOrder: number
): Frame
	local isPressed = scope:Value(false)
	local style = getMutationStyle(mutationType)

	local pressScale = scope:Spring(
		scope:Computed(function(use)
			if isLocked then return 0.95 end
			return if use(isPressed) then 0.88 else 1
		end),
		40,
		0.7
	)

	-- Card colors based on state
	local mainColor = if isEquipped then Theme.Colors.Purple.Main
		elseif isOwned then Theme.Colors.Action.Main
		elseif isLocked then Theme.Colors.Surface.Shadow
		else style.Main

	local shadowColor = if isEquipped then Theme.Colors.Purple.Shadow
		elseif isOwned then Theme.Colors.Action.Shadow
		elseif isLocked then Color3.fromRGB(80, 80, 80)
		else style.Shadow

	return scope:New("Frame")({
		Name = "Mutation_" .. mutationType,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,

		[Children] = {
			scope:New("UIAspectRatioConstraint")({ AspectRatio = 0.75 }),

			-- Scale wrapper
			scope:New("Frame")({
				Name = "ScaleWrapper",
				Size = scope:Computed(function(use)
					local s = use(pressScale)
					return UDim2.fromScale(s, s)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					-- Shadow (offset down-right for Toon Pop)
					scope:New("Frame")({
						Name = "Shadow",
						Size = UDim2.fromScale(1, 0.94),
						Position = UDim2.fromScale(0.5, 0.06),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = shadowColor,
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.15, 0) }),
						},
					}),

					-- Main card
					scope:New("TextButton")({
						Name = "Main",
						Size = UDim2.fromScale(1, 0.94),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = mainColor,
						AutoButtonColor = false,
						Text = "",
						ZIndex = 2,

						[OnEvent("MouseButton1Down")] = function()
							if not isLocked then isPressed:set(true) end
						end,

						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							if not isLocked then onSelect() end
						end,

						[OnEvent("MouseLeave")] = function()
							isPressed:set(false)
						end,

						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.15, 0) }),

							scope:New("UIStroke")({
								Color = scope:Computed(function(use)
									return if use(isSelected) then Theme.Colors.Gold.Main else Color3.new(1, 1, 1)
								end),
								Thickness = scope:Computed(function(use)
									return if use(isSelected) then 4 else 2
								end),
							}),

							-- Bubble shine (top-left)
							not isLocked and scope:New("Frame")({
								Name = "Shine",
								Size = UDim2.fromScale(0.35, 0.12),
								Position = UDim2.fromScale(0.2, 0.06),
								BackgroundColor3 = Color3.new(1, 1, 1),
								BackgroundTransparency = 0.6,
								ZIndex = 3,

								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
								},
							}) or nil,

							-- Icon bubble (potion flask style)
							scope:New("Frame")({
								Name = "IconBubble",
								Size = UDim2.fromScale(0.55, 0.35),
								Position = UDim2.fromScale(0.5, 0.22),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = if isLocked then Color3.fromRGB(100, 100, 100) else style.Main,
								ZIndex = 3,

								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
									scope:New("UIStroke")({
										Color = Color3.new(1, 1, 1),
										Thickness = 2,
									}),

									-- Emoji icon
									scope:New("TextLabel")({
										Size = UDim2.fromScale(0.75, 0.75),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = style.Icon,
										TextScaled = true,
									}),
								},
							}),

							-- Mutation name
							scope:New("TextLabel")({
								Name = "Name",
								Size = UDim2.fromScale(0.9, 0.12),
								Position = UDim2.fromScale(0.5, 0.48),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Text = mutationData.Name or mutationType,
								TextColor3 = if isLocked then Color3.fromRGB(180, 180, 180) else Color3.new(1, 1, 1),
								TextScaled = true,
								Font = Enum.Font.GothamBold,
								ZIndex = 3,

								[Children] = {
									scope:New("UITextSizeConstraint")({ MaxTextSize = 11, MinTextSize = 7 }),
								},
							}),

							-- Power stars (tier indicator)
							scope:New("Frame")({
								Name = "PowerStars",
								Size = UDim2.fromScale(0.7, 0.1),
								Position = UDim2.fromScale(0.5, 0.58),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								ZIndex = 3,

								[Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										Padding = UDim.new(0.02, 0),
									}),

									-- Generate stars
									(function()
										local stars = {}
										local tier = mutationData.Tier or 1
										for i = 1, 3 do
											local isFilled = i <= tier and not isLocked
											table.insert(stars, scope:New("TextLabel")({
												Size = UDim2.fromScale(0.28, 1),
												BackgroundTransparency = 1,
												Text = if isFilled then "⭐" else "☆",
												TextScaled = true,
												TextColor3 = if isFilled then Theme.Colors.Gold.Main else Color3.fromRGB(150, 150, 150),
												LayoutOrder = i,
											}))
										end
										return stars
									end)(),
								},
							}),

							-- Status badge
							scope:New("Frame")({
								Name = "StatusBadge",
								Size = UDim2.fromScale(0.85, 0.15),
								Position = UDim2.fromScale(0.5, 0.77),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = if isEquipped then Theme.Colors.Purple.Shadow
									elseif isOwned then Theme.Colors.Action.Shadow
									elseif isLocked then Color3.fromRGB(60, 60, 60)
									else Theme.Colors.Gold.Shadow,
								ZIndex = 3,

								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }),

									-- Status text or price
									if isEquipped or isOwned or isLocked then
										scope:New("TextLabel")({
											Size = UDim2.fromScale(1, 1),
											BackgroundTransparency = 1,
											Text = if isEquipped then "🧬 EQUIPPED"
												elseif isOwned then "✓ OWNED"
												else `🔒 Lv.{mutationData.RequiredLevel}`,
											TextColor3 = Color3.new(1, 1, 1),
											TextScaled = true,
											Font = Enum.Font.GothamBold,

											[Children] = {
												scope:New("UITextSizeConstraint")({ MaxTextSize = 10, MinTextSize = 6 }),
											},
										})
									else
										-- Price display
										scope:New("Frame")({
											Size = UDim2.fromScale(1, 1),
											BackgroundTransparency = 1,

											[Children] = {
												scope:New("UIListLayout")({
													FillDirection = Enum.FillDirection.Horizontal,
													VerticalAlignment = Enum.VerticalAlignment.Center,
													HorizontalAlignment = Enum.HorizontalAlignment.Center,
													Padding = UDim.new(0.03, 0),
												}),
												Icon(scope, {
													Name = "Coin",
													Size = UDim2.fromScale(0.2, 0.75),
													LayoutOrder = 1,
												}),
												scope:New("TextLabel")({
													Size = UDim2.fromScale(0.5, 1),
													BackgroundTransparency = 1,
													Text = tostring(mutationData.Cost),
													TextColor3 = Theme.Colors.Gold.Main,
													TextScaled = true,
													Font = Enum.Font.GothamBold,
													LayoutOrder = 2,

													[Children] = {
														scope:New("UITextSizeConstraint")({ MaxTextSize = 11, MinTextSize = 7 }),
													},
												}),
											},
										}),
								},
							}),

							-- Lock overlay
							isLocked and scope:New("Frame")({
								Name = "LockOverlay",
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = Color3.new(0, 0, 0),
								BackgroundTransparency = 0.5,
								ZIndex = 10,

								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.15, 0) }),
								},
							}) or nil,
						},
					}),
				},
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- MutationScreen - Toon Pop Cartoon Laboratory
--------------------------------------------------------------------------------
local function MutationScreen(props: MutationScreenProps): Frame
	local scope = props.Scope

	-- State
	local selectedPlant = scope:Value(nil :: string?)
	local selectedMutation = scope:Value(nil :: string?)

	-- Responsive sizing
	local camera = workspace.CurrentCamera
	local viewportSize = scope:Value(camera and camera.ViewportSize or Vector2.new(1920, 1080))
	if camera then
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewportSize:set(camera.ViewportSize)
		end)
		table.insert(scope, connection)
	end

	local gridCellSize = scope:Computed(function(use)
		local size = use(viewportSize)
		local scale = math.clamp(size.Y / 1080, 0.6, 1.5)
		return UDim2.fromOffset(math.floor(105 * scale), math.floor(140 * scale))
	end)

	local gridCellPadding = scope:Computed(function(use)
		local size = use(viewportSize)
		local scale = math.clamp(size.Y / 1080, 0.6, 1.5)
		return UDim2.fromOffset(math.floor(10 * scale), math.floor(10 * scale))
	end)

	-- Unlocked plants (sorted: equipped first)
	local unlockedPlants = scope:Computed(function(use)
		local data = use(props.PlayerData)
		if not data then return {} end

		local allEquipped = use(props.EquippedMutations) or {}
		local unlockedList = data.UnlockedPlants or {}
		local result: { { Type: string, EquippedCount: number } } = {}

		for _, plantType in unlockedList do
			local stats = PlantData.GetStats(plantType)
			if stats then
				local equipped = allEquipped[plantType] or {}
				table.insert(result, { Type = plantType, EquippedCount = #equipped })
			end
		end

		-- Sort: equipped first
		table.sort(result, function(a, b)
			if (a.EquippedCount > 0) ~= (b.EquippedCount > 0) then
				return a.EquippedCount > 0
			end
			return a.Type < b.Type
		end)

		-- Auto-select first plant
		local current = peek(selectedPlant)
		if not current and #result > 0 then
			task.defer(function()
				selectedPlant:set(result[1].Type)
			end)
		end

		return result
	end)

	-- Compatible mutations for selected plant
	local compatibleMutations = scope:Computed(function(use)
		local plantType = use(selectedPlant)
		if not plantType then return {} end

		local plantStats = PlantData[plantType]
		if not plantStats then return {} end

		local category = plantStats.Category
		local result: { { Type: string, Data: any } } = {}

		for mutationType, data in MutationData.GetAll() do
			if table.find(data.CompatibleCategories, category) then
				table.insert(result, { Type = mutationType, Data = data })
			end
		end

		table.sort(result, function(a, b)
			return a.Data.RequiredLevel < b.Data.RequiredLevel
		end)

		return result
	end)

	-- Equipped/Owned for selected plant
	local plantEquipped = scope:Computed(function(use)
		local plantType = use(selectedPlant)
		if not plantType then return {} end
		local allEquipped = use(props.EquippedMutations) or {}
		return allEquipped[plantType] or {}
	end)

	local plantOwned = scope:Computed(function(use)
		local plantType = use(selectedPlant)
		if not plantType then return {} end
		local allOwned = use(props.OwnedMutations) or {}
		return allOwned[plantType] or {}
	end)

	-- Player stats
	local playerCoins = scope:Computed(function(use)
		local data = use(props.PlayerData)
		return if data then data.Coins else 0
	end)

	local playerLevel = scope:Computed(function(use)
		local data = use(props.PlayerData)
		return if data then data.Level else 1
	end)

	-- Selected mutation state
	local isMutationOwned = scope:Computed(function(use)
		local mutation = use(selectedMutation)
		if not mutation then return false end
		local owned = use(plantOwned)
		return table.find(owned, mutation) ~= nil
	end)

	local isMutationEquipped = scope:Computed(function(use)
		local mutation = use(selectedMutation)
		if not mutation then return false end
		local equipped = use(plantEquipped)
		return table.find(equipped, mutation) ~= nil
	end)

	local canEquipMore = scope:Computed(function(use)
		local equipped = use(plantEquipped)
		return #equipped < MAX_EQUIPPED_MUTATIONS
	end)

	local canPurchase = scope:Computed(function(use)
		local mutation = use(selectedMutation)
		if not mutation then return false end
		if use(isMutationOwned) then return false end

		local data = MutationData.Get(mutation)
		if not data then return false end

		local level = use(playerLevel) :: number
		local coins = use(playerCoins) :: number
		return level >= data.RequiredLevel and coins >= data.Cost
	end)

	-- Action handler
	local function performAction()
		local plantType = peek(selectedPlant)
		local mutation = peek(selectedMutation)
		if not plantType or not mutation then return end

		if peek(isMutationEquipped) then
			props.OnUnequipMutation(plantType, mutation)
		elseif peek(isMutationOwned) then
			if peek(canEquipMore) then
				props.OnEquipMutation(plantType, mutation)
			end
		elseif peek(canPurchase) then
			props.OnPurchaseMutation(plantType, mutation)
		end
	end

	-- Action button state
	local actionButtonText = scope:Computed(function(use)
		local mutation = use(selectedMutation)
		if not mutation then return "SELECT A MUTATION" end

		if use(isMutationEquipped) then
			return "❌ UNEQUIP"
		elseif use(isMutationOwned) then
			if use(canEquipMore) then
				return "🧬 EQUIP"
			else
				return "🔒 SLOTS FULL"
			end
		elseif use(canPurchase) then
			local data = MutationData.Get(mutation)
			return `💰 BUY ({data and data.Cost or 0})`
		else
			return "🔒 LOCKED"
		end
	end)

	local actionButtonColors = scope:Computed(function(use)
		local mutation = use(selectedMutation)
		if not mutation then 
			return { Main = Theme.Colors.Surface.Main, Shadow = Theme.Colors.Surface.Shadow }
		end

		if use(isMutationEquipped) then
			return { Main = Theme.Colors.Danger.Main, Shadow = Theme.Colors.Danger.Shadow }
		elseif use(isMutationOwned) and use(canEquipMore) then
			return { Main = Theme.Colors.Purple.Main, Shadow = Theme.Colors.Purple.Shadow }
		elseif use(canPurchase) then
			return { Main = Theme.Colors.Action.Main, Shadow = Theme.Colors.Action.Shadow }
		else
			return { Main = Theme.Colors.Surface.Main, Shadow = Theme.Colors.Surface.Shadow }
		end
	end)

	-- Build plant bar
	local plantBar = scope:Computed(function(use)
		local plants = use(unlockedPlants)
		local cards = {}

		for _, p in plants do
			local isSelected = scope:Computed(function(use2)
				return use2(selectedPlant) == p.Type
			end)

			table.insert(cards, PlantCapsule(scope, p.Type, isSelected, p.EquippedCount, function()
				selectedPlant:set(p.Type)
				selectedMutation:set(nil)
			end))
		end

		return cards
	end)

	-- Build mutation grid
	local mutationCards = scope:Computed(function(use)
		local mutations = use(compatibleMutations)
		local owned = use(plantOwned)
		local equipped = use(plantEquipped)
		local level = use(playerLevel) :: number
		local cards = {}

		for i, m in mutations do
			local isOwned = table.find(owned, m.Type) ~= nil
			local isEquipped = table.find(equipped, m.Type) ~= nil
			local isLocked = level < m.Data.RequiredLevel

			local isSelected = scope:Computed(function(use2)
				return use2(selectedMutation) == m.Type
			end)

			table.insert(cards, MutationBubble(
				scope,
				m.Type,
				m.Data,
				isOwned,
				isEquipped,
				isLocked,
				isSelected,
				function()
					selectedMutation:set(m.Type)
				end,
				i
			))
		end

		return cards
	end)

	-- Lab status badge (equipped count)
	local labStatusBadge = scope:New("Frame")({
		Name = "LabStatus",
		Size = UDim2.fromScale(1, 0.85),
		BackgroundColor3 = Theme.Colors.Purple.Main,

		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }),
			scope:New("UIStroke")({
				Color = Color3.new(1, 1, 1),
				Thickness = 2,
			}),

			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					local equipped = use(plantEquipped)
					return `🧬 {#equipped}/{MAX_EQUIPPED_MUTATIONS}`
				end),
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Font = Enum.Font.GothamBold,

				[Children] = {
					scope:New("UITextSizeConstraint")({ MinTextSize = 10, MaxTextSize = 14 }),
				},
			}),
		},
	})

	return ScreenOverlay({
		Scope = scope,
		Name = "MutationScreen",

		[Children] = {
			-- Header
			ScreenHeader({
				Scope = scope,
				Title = "🧬 MUTATION LAB",
				OnClose = props.OnBack,
				LeftContent = { labStatusBadge },
			}),

			-- Plant capsule bar (11% - 23%)
			scope:New("Frame")({
				Name = "PlantBar",
				Size = UDim2.fromScale(1, 0.13),
				Position = UDim2.fromScale(0.5, 0.11),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,

				[Children] = {
					-- Shadow
					scope:New("Frame")({
						Name = "Shadow",
						Size = UDim2.new(1, 0, 1, -6),
						Position = UDim2.fromOffset(0, 6),
						BackgroundColor3 = Theme.Colors.Surface.Shadow,
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
						},
					}),

					-- Main bar
					scope:New("Frame")({
						Name = "Main",
						Size = UDim2.new(1, 0, 1, -6),
						BackgroundColor3 = Theme.Colors.Surface.Main,
						ClipsDescendants = true,
						ZIndex = 2,

						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
							scope:New("UIStroke")({
								Color = Theme.Colors.Surface.Stroke :: Color3,
								Thickness = Theme.Layout.StrokeThickness,
							}),

							-- Scrolling container
							scope:New("ScrollingFrame")({
								Size = UDim2.fromScale(1, 1),
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								ScrollBarThickness = 0,
								CanvasSize = UDim2.fromScale(0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.X,
								ScrollingDirection = Enum.ScrollingDirection.X,

								[Children] = {
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 10),
										PaddingRight = UDim.new(0, 10),
										PaddingTop = UDim.new(0, 4),
										PaddingBottom = UDim.new(0, 4),
									}),

									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, 8),
									}),

									plantBar,
								},
							}),
						},
					}),
				},
			}),

			-- Mutation grid (25% - 86%)
			ScrollableGrid({
				Scope = scope,
				Size = UDim2.fromScale(1, 0.61),
				Position = UDim2.fromScale(0.5, 0.25),
				AnchorPoint = Vector2.new(0.5, 0),
				CellSize = gridCellSize,
				CellPadding = gridCellPadding,
				Children = mutationCards,
			}),

			-- Action button (bottom 10%)
			scope:New("Frame")({
				Name = "ActionBar",
				Size = UDim2.fromScale(0.4, 0.08),
				Position = UDim2.fromScale(0.5, 0.935),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,

				[Children] = {
					-- Shadow
					scope:New("Frame")({
						Name = "Shadow",
						Size = UDim2.new(1, 0, 1, -4),
						Position = UDim2.fromOffset(0, 4),
						BackgroundColor3 = scope:Computed(function(use)
							return use(actionButtonColors).Shadow
						end),
						ZIndex = 1,

						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
						},
					}),

					-- Button
					scope:New("TextButton")({
						Name = "ActionButton",
						Size = UDim2.new(1, 0, 1, -4),
						BackgroundColor3 = scope:Computed(function(use)
							return use(actionButtonColors).Main
						end),
						AutoButtonColor = false,
						Text = actionButtonText,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
						ZIndex = 2,

						[OnEvent("MouseButton1Click")] = performAction,

						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
							scope:New("UIStroke")({
								Color = Color3.new(1, 1, 1),
								Thickness = 2,
							}),
							scope:New("UITextSizeConstraint")({ MinTextSize = 12, MaxTextSize = 18 }),
						},
					}),
				},
			}),
		},
	})
end

return MutationScreen
