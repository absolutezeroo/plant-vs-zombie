--!strict
--[[
	MutationScreen.luau - Mutation Lab (Toon Pop Style)
	
	Organism for managing plant mutations.
	Same visual style as ShopScreen and DeckBuilderScreen:
	- Dark overlay background
	- Centered panel with header + shadows
	- Plant selector bar with 3D viewports
	- Mutation grid with cards
	- Detail panel for selected mutation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local PlantViewport = require(Shared.ui.components.atoms.PlantViewport)
local ResponsiveUtils = require(Shared.ui.utils.ResponsiveUtils)

-- Local atoms
local Atoms = script.Parent.Parent.atoms
local ResourcePill = require(Atoms.ResourcePill)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Constants
local SHADOW_OFFSET = 4
local HEADER_HEIGHT = 70
local PLANT_BAR_HEIGHT = 100
local PLANT_CARD_SIZE = 80
local MAX_EQUIPPED_MUTATIONS = 3

-- Mutation icons
local MUTATION_ICONS: {[string]: string} = {
	Fire = "🔥", Ice = "❄️", Electric = "⚡", Toxic = "☠️",
	Shadow = "🌑", Solar = "☀️", Reinforced = "🛡️", Primal = "💥",
	Swift = "💨", Damage = "⚔️", Health = "❤️", Range = "🎯",
	Speed = "⚡", Inferno = "🔥", Frost = "❄️", Storm = "⚡",
	Plague = "☠️", Void = "🌑", Radiant = "☀️", Fortress = "🏰", Savage = "💥",
}

local function getMutationIcon(mutationType: string): string
	return MUTATION_ICONS[mutationType] or "✨"
end

-- Effect display names mapping
local EFFECT_LABELS: {[string]: string} = {
	DamageBonus = "Damage",
	HealthBonus = "Health",
	CooldownReduction = "Cooldown",
	AttackSpeedBonus = "Attack Speed",
	AddsBurnDamage = "Burn",
	BurnDamagePerSecond = "Burn DPS",
	BurnDuration = "Burn Duration",
	AddsFreeze = "Freeze",
	FreezeChance = "Freeze Chance",
	FreezeDuration = "Freeze Duration",
	EnhancedSlow = "Slow",
	AddsChainLightning = "Chain Lightning",
	ChainCount = "Chain Targets",
	ChainDamage = "Chain Damage",
	ChainRange = "Chain Range",
	AddsPoisonCloud = "Poison Cloud",
	PoisonRadius = "Poison Radius",
	PoisonDamagePerSecond = "Poison DPS",
	PoisonDuration = "Poison Duration",
	AddsLifesteal = "Lifesteal",
	LifestealPercent = "Lifesteal",
	AddsSunOnKill = "Sun on Kill",
	SunPerKill = "Sun/Kill",
	SunDropChance = "Sun Chance",
	ExtraHealth = "Bonus HP",
	DamageReduction = "Damage Reduction",
	SplashDamage = "Splash Damage",
	SplashRadius = "Splash Radius",
	SplashPercent = "Splash %",
	Knockback = "Knockback",
}

local function formatEffects(effects: any): string
	if not effects then return "• Enhances abilities" end
	
	local lines: {string} = {}
	for key, value in pairs(effects) do
		local label = EFFECT_LABELS[key] or key
		local displayValue: string
		
		if type(value) == "boolean" then
			if value then
				displayValue = "✓"
			else
				continue
			end
		elseif type(value) == "number" then
			-- Format percentages vs flat values
			if key:find("Bonus") or key:find("Percent") or key:find("Reduction") or key:find("Chance") then
				displayValue = string.format("+%d%%", math.floor((value - (if value > 1 then 1 else 0)) * 100))
			else
				displayValue = tostring(value)
			end
		else
			displayValue = tostring(value)
		end
		
		table.insert(lines, `• {label}: {displayValue}`)
	end
	
	if #lines == 0 then
		return "• Enhances abilities"
	end
	
	return table.concat(lines, "\n")
end

export type MutationScreenProps = {
	Scope: Fusion.Scope<any>,
	PlayerData: any,
	OwnedMutations: any, -- Value<{[string]: {string}}>
	EquippedMutations: any, -- Value<{[string]: {string}}>
	OnBack: () -> (),
	OnPurchaseMutation: (plantType: string, mutationType: string) -> (),
	OnEquipMutation: (plantType: string, mutationType: string) -> (),
	OnUnequipMutation: (plantType: string, mutationType: string) -> (),
}

--------------------------------------------------------------------------------
-- PlantCard - Selectable plant in the plant bar
--------------------------------------------------------------------------------
local function PlantCard(scope: any, props: {
	PlantType: string,
	IsSelected: any, -- Computed<boolean>
	EquippedCount: number,
	OnSelect: () -> (),
	LayoutOrder: number,
}): Frame
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	
	local pressOffset = Spring(scope, Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end), 40, 0.7)
	
	-- Create plant viewport
	local viewport = PlantViewport.CreateWithScope(scope, {
		PlantType = props.PlantType,
		Size = UDim2.new(1, -16, 1, -28),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 3,
		CameraFOV = 40,
		CameraDistance = 1.4,
		CameraHeight = 0.1,
	})
	
	return New(scope, "Frame") {
		Name = "PlantCard_" .. props.PlantType,
		Size = UDim2.fromOffset(PLANT_CARD_SIZE, PLANT_CARD_SIZE + SHADOW_OFFSET),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		
		[Children] = {
			-- Shadow
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.fromOffset(PLANT_CARD_SIZE, PLANT_CARD_SIZE),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = Computed(scope, function(use)
					return if use(props.IsSelected) 
						then Theme.Colors.Action.Shadow 
						else Theme.Colors.Surface.Shadow
				end),
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
				},
			},
			
			-- Main card
			New(scope, "Frame") {
				Name = "Main",
				Size = Computed(scope, function(use)
					local offset = use(pressOffset)
					return UDim2.fromOffset(PLANT_CARD_SIZE, PLANT_CARD_SIZE - offset)
				end),
				Position = Computed(scope, function(use)
					return UDim2.fromOffset(0, use(pressOffset))
				end),
				BackgroundColor3 = Computed(scope, function(use)
					return if use(props.IsSelected) 
						then Theme.Colors.Action.Main 
						else Theme.Colors.Surface.Main
				end),
				ZIndex = 2,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
					
					New(scope, "UIStroke") {
						Color = Computed(scope, function(use)
							return if use(props.IsSelected) 
								then Theme.Colors.Surface.Stroke :: Color3
								else Theme.Colors.Surface.Stroke :: Color3
						end),
						Thickness = Computed(scope, function(use)
							return if use(props.IsSelected) then 4 else Theme.Layout.StrokeThickness
						end),
					},
					
					-- Plant viewport
					viewport,
					
					-- Plant name
					New(scope, "TextLabel") {
						Size = UDim2.new(1, 0, 0, 16),
						Position = UDim2.new(0, 0, 1, -18),
						BackgroundTransparency = 1,
						Text = props.PlantType,
						TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
						TextSize = 10,
						Font = Enum.Font.GothamBold,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 4,
					},
					
					-- Equipped mutations badge
					props.EquippedCount > 0 and New(scope, "Frame") {
						Size = UDim2.fromOffset(22, 22),
						Position = UDim2.new(1, -4, 0, 4),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundColor3 = Theme.Colors.Purple.Main,
						ZIndex = 5,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0.5, 0),
							},
							New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = tostring(props.EquippedCount),
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 12,
								Font = Enum.Font.GothamBold,
							},
						},
					} or nil,
					
					-- Click handler
					New(scope, "TextButton") {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,
						
						[OnEvent("MouseButton1Down")] = function()
							isPressed:set(true)
						end,
						
						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							props.OnSelect()
						end,
						
						[OnEvent("MouseEnter")] = function()
							isHovered:set(true)
						end,
						
						[OnEvent("MouseLeave")] = function()
							isHovered:set(false)
							isPressed:set(false)
						end,
					},
				},
			},
		},
	}
end

--------------------------------------------------------------------------------
-- MutationCard - A mutation in the grid
--------------------------------------------------------------------------------
local function MutationCard(scope: any, props: {
	MutationType: string,
	MutationData: any,
	IsOwned: boolean,
	IsEquipped: boolean,
	IsLocked: boolean, -- Level too low
	IsSelected: any, -- Computed<boolean>
	OnSelect: () -> (),
	LayoutOrder: number,
}): Frame
	local isPressed = Value(scope, false)
	
	local pressOffset = Spring(scope, Computed(scope, function(use)
		return if use(isPressed) then SHADOW_OFFSET else 0
	end), 40, 0.7)
	
	-- Determine card color
	local cardColor = if props.IsEquipped then Theme.Colors.Purple.Main
		elseif props.IsOwned then Theme.Colors.Action.Main
		elseif props.IsLocked then Theme.Colors.Surface.Shadow
		else Theme.Colors.Surface.Main
	
	local shadowColor = if props.IsEquipped then Theme.Colors.Purple.Shadow
		elseif props.IsOwned then Theme.Colors.Action.Shadow
		elseif props.IsLocked then Color3.fromHex("#888888")
		else Theme.Colors.Surface.Shadow
	
	return New(scope, "Frame") {
		Name = "MutationCard_" .. props.MutationType,
		Size = UDim2.fromOffset(90, 110),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		
		[Children] = {
			-- Shadow
			New(scope, "Frame") {
				Name = "Shadow",
				Size = UDim2.fromOffset(90, 100),
				Position = UDim2.fromOffset(0, SHADOW_OFFSET),
				BackgroundColor3 = shadowColor,
				ZIndex = 1,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
				},
			},
			
			-- Main card
			New(scope, "Frame") {
				Name = "Main",
				Size = Computed(scope, function(use)
					local offset = use(pressOffset)
					return UDim2.fromOffset(90, 100 - offset)
				end),
				Position = Computed(scope, function(use)
					return UDim2.fromOffset(0, use(pressOffset))
				end),
				BackgroundColor3 = cardColor,
				ZIndex = 2,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = Theme.Layout.CornerRadius,
					},
					
					New(scope, "UIStroke") {
						Color = Computed(scope, function(use)
							return if use(props.IsSelected) 
								then Theme.Colors.Gold.Main 
								else Theme.Colors.Surface.Stroke :: Color3
						end),
						Thickness = Computed(scope, function(use)
							return if use(props.IsSelected) then 4 else Theme.Layout.StrokeThickness
						end),
					},
					
					-- Mutation icon
					New(scope, "TextLabel") {
						Size = UDim2.fromOffset(50, 50),
						Position = UDim2.new(0.5, 0, 0, 10),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = getMutationIcon(props.MutationType),
						TextSize = 36,
						ZIndex = 3,
					},
					
					-- Mutation name
					New(scope, "TextLabel") {
						Size = UDim2.new(1, -8, 0, 16),
						Position = UDim2.new(0.5, 0, 0, 62),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = props.MutationData.Name or props.MutationType,
						TextColor3 = if props.IsLocked 
							then Color3.fromHex("#888888") 
							else Theme.Colors.Surface.Stroke :: Color3,
						TextSize = 11,
						Font = Enum.Font.GothamBold,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 3,
					},
					
					-- Status badge
					New(scope, "Frame") {
						Size = UDim2.new(1, -8, 0, 16),
						Position = UDim2.new(0.5, 0, 1, -20),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = if props.IsEquipped then Theme.Colors.Purple.Shadow
							elseif props.IsOwned then Theme.Colors.Action.Shadow
							elseif props.IsLocked then Color3.fromHex("#666666")
							else Theme.Colors.Gold.Main,
						ZIndex = 3,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0, 8),
							},
							New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = if props.IsEquipped then "EQUIPPED"
									elseif props.IsOwned then "OWNED"
									elseif props.IsLocked then `Lv.{props.MutationData.RequiredLevel}`
									else `${Theme.Icons.Coin}{props.MutationData.Cost}`,
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 9,
								Font = Enum.Font.GothamBold,
							},
						},
					},
					
					-- Lock overlay
					props.IsLocked and New(scope, "Frame") {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundColor3 = Color3.new(0, 0, 0),
						BackgroundTransparency = 0.5,
						ZIndex = 8,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = Theme.Layout.CornerRadius,
							},
							New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = Theme.Icons.Lock,
								TextSize = 28,
							},
						},
					} or nil,
					
					-- Click handler
					New(scope, "TextButton") {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,
						
						[OnEvent("MouseButton1Down")] = function()
							if not props.IsLocked then
								isPressed:set(true)
							end
						end,
						
						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							if not props.IsLocked then
								props.OnSelect()
							end
						end,
						
						[OnEvent("MouseLeave")] = function()
							isPressed:set(false)
						end,
					},
				},
			},
		},
	}
end

--------------------------------------------------------------------------------
-- MutationScreen Component
--------------------------------------------------------------------------------
local function MutationScreen(props: MutationScreenProps): Frame
	local scope = props.Scope
	
	-- State
	local selectedPlant = Value(scope, nil :: string?)
	local selectedMutation = Value(scope, nil :: string?)
	
	-- Close button animation
	local isClosePressed = Value(scope, false)
	local closeOffset = Spring(scope, Computed(scope, function(use)
		return if use(isClosePressed) then SHADOW_OFFSET else 0
	end), 40, 0.7)
	
	-- Action button animation
	local isActionPressed = Value(scope, false)
	local actionOffset = Spring(scope, Computed(scope, function(use)
		return if use(isActionPressed) then SHADOW_OFFSET else 0
	end), 40, 0.7)
	
	-- Unlocked plants
	local unlockedPlants = Computed(scope, function(use)
		local data = use(props.PlayerData)
		if not data then return {} end
		
		local unlockedList = data.UnlockedPlants or {}
		local result: {{Type: string, Stats: any}} = {}
		
		for _, plantType in ipairs(unlockedList) do
			local stats = PlantData.GetStats(plantType)
			if stats then
				table.insert(result, {Type = plantType, Stats = stats})
			end
		end
		table.sort(result, function(a, b) return a.Type < b.Type end)
		
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
	local compatibleMutations = Computed(scope, function(use)
		local plantType = use(selectedPlant)
		if not plantType then return {} end
		
		local plantStats = PlantData[plantType]
		if not plantStats then return {} end
		
		local category = plantStats.Category
		local result: {{Type: string, Data: any}} = {}
		
		for mutationType, data in pairs(MutationData.GetAll()) do
			if table.find(data.CompatibleCategories, category) then
				table.insert(result, {Type = mutationType, Data = data})
			end
		end
		
		table.sort(result, function(a, b)
			return a.Data.RequiredLevel < b.Data.RequiredLevel
		end)
		
		return result
	end)
	
	-- Equipped mutations for selected plant
	local plantEquipped = Computed(scope, function(use)
		local plantType = use(selectedPlant)
		if not plantType then return {} end
		local allEquipped = use(props.EquippedMutations) or {}
		return allEquipped[plantType] or {}
	end)
	
	-- Owned mutations for selected plant
	local plantOwned = Computed(scope, function(use)
		local plantType = use(selectedPlant)
		if not plantType then return {} end
		local allOwned = use(props.OwnedMutations) or {}
		return allOwned[plantType] or {}
	end)
	
	-- Player data
	local playerCoins = Computed(scope, function(use)
		local data = use(props.PlayerData)
		return if data then data.Coins else 0
	end)
	
	local playerLevel = Computed(scope, function(use)
		local data = use(props.PlayerData)
		return if data then data.Level else 1
	end)
	
	-- Selected mutation info
	local selectedMutationData = Computed(scope, function(use)
		local mutation = use(selectedMutation)
		if not mutation then return nil end
		return MutationData.Get(mutation)
	end)
	
	local isMutationOwned = Computed(scope, function(use)
		local mutation = use(selectedMutation)
		if not mutation then return false end
		local owned = use(plantOwned)
		return table.find(owned, mutation) ~= nil
	end)
	
	local isMutationEquipped = Computed(scope, function(use)
		local mutation = use(selectedMutation)
		if not mutation then return false end
		local equipped = use(plantEquipped)
		return table.find(equipped, mutation) ~= nil
	end)
	
	local canEquipMore = Computed(scope, function(use)
		local equipped = use(plantEquipped)
		return #equipped < MAX_EQUIPPED_MUTATIONS
	end)
	
	local canPurchase = Computed(scope, function(use)
		local mutation = use(selectedMutation)
		if not mutation then return false end
		if use(isMutationOwned) then return false end
		
		local data = MutationData.Get(mutation)
		if not data then return false end
		
		local level = use(playerLevel)
		local coins = use(playerCoins)
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
	
	return New(scope, "Frame") {
		Name = "MutationScreen",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		ZIndex = 100,
		
		[Children] = {
			-- Main panel
			New(scope, "Frame") {
				Name = "Panel",
				Size = Theme.Layout.OverlaySize,
				Position = Theme.Layout.OverlayPosition,
				AnchorPoint = Theme.Layout.OverlayAnchorPoint,
				BackgroundTransparency = 1,
				
				[Children] = {
					-- Responsive scaling
					ResponsiveUtils.CreateUIScale(scope),
					
					-- ========================================
					-- HEADER
					-- ========================================
					New(scope, "Frame") {
						Name = "Header",
						Size = UDim2.new(1, 0, 0, HEADER_HEIGHT + SHADOW_OFFSET),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- Shadow
							New(scope, "Frame") {
								Name = "Shadow",
								Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
								Position = UDim2.fromOffset(0, SHADOW_OFFSET),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
							
							-- Main header
							New(scope, "Frame") {
								Name = "Main",
								Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ZIndex = 2,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									
									New(scope, "UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									-- Title
									New(scope, "TextLabel") {
										Name = "Title",
										Size = UDim2.fromOffset(280, 40),
										Position = UDim2.new(0.5, 0, 0.5, 0),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = "🧬 MUTATION LAB",
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextSize = 26,
										Font = Theme.Typography.Fonts.Title,
									},
									
									-- Coins display
									New(scope, "Frame") {
										Name = "CoinsContainer",
										Size = UDim2.fromOffset(110, 40),
										Position = UDim2.new(0, 20, 0.5, 0),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										
										[Children] = {
											ResourcePill({
												Scope = scope,
												Icon = Theme.Icons.Coin,
												Value = playerCoins,
												Color = "Gold",
												Width = 110,
											}),
										},
									},
									
									-- Close button
									New(scope, "Frame") {
										Name = "CloseContainer",
										Size = UDim2.fromOffset(50, 50 + SHADOW_OFFSET),
										Position = UDim2.new(1, -16, 0.5, 0),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										
										[Children] = {
											-- Shadow
											New(scope, "Frame") {
												Size = UDim2.fromOffset(50, 50),
												Position = UDim2.fromOffset(0, SHADOW_OFFSET),
												BackgroundColor3 = Theme.Colors.Danger.Shadow,
												ZIndex = 1,
												
												[Children] = {
													New(scope, "UICorner") {
														CornerRadius = Theme.Layout.CornerRadius,
													},
												},
											},
											
											-- Button
											New(scope, "TextButton") {
												Size = Computed(scope, function(use)
													local offset = use(closeOffset)
													return UDim2.fromOffset(50, 50 - offset)
												end),
												Position = Computed(scope, function(use)
													return UDim2.fromOffset(0, use(closeOffset))
												end),
												BackgroundColor3 = Theme.Colors.Danger.Main,
												Text = Theme.Icons.Close,
												TextColor3 = Color3.new(1, 1, 1),
												TextSize = 22,
												Font = Theme.Typography.Fonts.Title,
												AutoButtonColor = false,
												ZIndex = 2,
												
												[OnEvent("MouseButton1Down")] = function()
													isClosePressed:set(true)
												end,
												
												[OnEvent("MouseButton1Up")] = function()
													isClosePressed:set(false)
													props.OnBack()
												end,
												
												[OnEvent("MouseLeave")] = function()
													isClosePressed:set(false)
												end,
												
												[Children] = {
													New(scope, "UICorner") {
														CornerRadius = Theme.Layout.CornerRadius,
													},
													New(scope, "UIStroke") {
														Color = Theme.Colors.Surface.Stroke :: Color3,
														Thickness = 2,
													},
												},
											},
										},
									},
								},
							},
						},
					},
					
					-- ========================================
					-- PLANT SELECTOR BAR
					-- ========================================
					New(scope, "Frame") {
						Name = "PlantBar",
						Size = UDim2.new(1, 0, 0, PLANT_BAR_HEIGHT + SHADOW_OFFSET),
						Position = UDim2.fromOffset(0, HEADER_HEIGHT + SHADOW_OFFSET + 10),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- Shadow
							New(scope, "Frame") {
								Name = "Shadow",
								Size = UDim2.new(1, 0, 0, PLANT_BAR_HEIGHT),
								Position = UDim2.fromOffset(0, SHADOW_OFFSET),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
							
							-- Main bar with scrolling
							New(scope, "ScrollingFrame") {
								Name = "Main",
								Size = UDim2.new(1, 0, 0, PLANT_BAR_HEIGHT),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ScrollBarThickness = 0,
								ScrollingDirection = Enum.ScrollingDirection.X,
								AutomaticCanvasSize = Enum.AutomaticSize.X,
								CanvasSize = UDim2.new(0, 0, 0, 0),
								ZIndex = 2,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									
									New(scope, "UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									New(scope, "UIPadding") {
										PaddingTop = UDim.new(0, 8),
										PaddingBottom = UDim.new(0, 8),
										PaddingLeft = UDim.new(0, 12),
										PaddingRight = UDim.new(0, 12),
									},
									
									New(scope, "UIListLayout") {
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, 10),
									},
									
									-- Plant cards
									Computed(scope, function(use)
										local plants = use(unlockedPlants)
										local allEquipped = use(props.EquippedMutations) or {}
										
										local cards = {}
										for i, p in plants do
											local equipped = allEquipped[p.Type] or {}
											local isSelected = Computed(scope, function(use2)
												return use2(selectedPlant) == p.Type
											end)
											
											table.insert(cards, PlantCard(scope, {
												PlantType = p.Type,
												IsSelected = isSelected,
												EquippedCount = #equipped,
												OnSelect = function()
													selectedPlant:set(p.Type)
													selectedMutation:set(nil)
												end,
												LayoutOrder = i,
											}))
										end
										return cards
									end),
								},
							},
						},
					},
					
					-- ========================================
					-- CONTENT AREA (Grid + Detail Panel)
					-- ========================================
					New(scope, "Frame") {
						Name = "Content",
						Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + PLANT_BAR_HEIGHT + SHADOW_OFFSET * 3 + 30)),
						Position = UDim2.fromOffset(0, HEADER_HEIGHT + PLANT_BAR_HEIGHT + SHADOW_OFFSET * 2 + 20),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- ========================================
							-- MUTATIONS GRID (left side)
							-- ========================================
							New(scope, "Frame") {
								Name = "GridContainer",
								Size = UDim2.new(0.6, -10, 1, 0),
								BackgroundTransparency = 1,
								
								[Children] = {
									-- Shadow
									New(scope, "Frame") {
										Name = "Shadow",
										Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
										Position = UDim2.fromOffset(0, SHADOW_OFFSET),
										BackgroundColor3 = Theme.Colors.Surface.Shadow,
										ZIndex = 1,
										
										[Children] = {
											New(scope, "UICorner") {
												CornerRadius = Theme.Layout.CornerRadius,
											},
										},
									},
									
									-- Scrolling frame
									New(scope, "ScrollingFrame") {
										Name = "Grid",
										Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
										BackgroundColor3 = Theme.Colors.Surface.Main,
										ScrollBarThickness = 8,
										ScrollBarImageColor3 = Theme.Colors.Surface.Shadow,
										AutomaticCanvasSize = Enum.AutomaticSize.Y,
										CanvasSize = UDim2.new(0, 0, 0, 0),
										ZIndex = 2,
										
										[Children] = {
											New(scope, "UICorner") {
												CornerRadius = Theme.Layout.CornerRadius,
											},
											
											New(scope, "UIStroke") {
												Color = Theme.Colors.Surface.Stroke :: Color3,
												Thickness = Theme.Layout.StrokeThickness,
											},
											
											New(scope, "UIPadding") {
												PaddingTop = UDim.new(0, 12),
												PaddingBottom = UDim.new(0, 16),
												PaddingLeft = UDim.new(0, 12),
												PaddingRight = UDim.new(0, 12),
											},
											
											New(scope, "UIGridLayout") {
												CellSize = UDim2.fromOffset(90, 110),
												CellPadding = UDim2.fromOffset(10, 10),
												HorizontalAlignment = Enum.HorizontalAlignment.Left,
												SortOrder = Enum.SortOrder.LayoutOrder,
											},
											
											-- Mutation cards
											Computed(scope, function(use)
												local mutations = use(compatibleMutations)
												local owned = use(plantOwned)
												local equipped = use(plantEquipped)
												local level = use(playerLevel)
												
												local cards = {}
												for i, m in mutations do
													local isOwned = table.find(owned, m.Type) ~= nil
													local isEquipped = table.find(equipped, m.Type) ~= nil
													local isLocked = level < m.Data.RequiredLevel
													
													local isSelected = Computed(scope, function(use2)
														return use2(selectedMutation) == m.Type
													end)
													
													table.insert(cards, MutationCard(scope, {
														MutationType = m.Type,
														MutationData = m.Data,
														IsOwned = isOwned,
														IsEquipped = isEquipped,
														IsLocked = isLocked,
														IsSelected = isSelected,
														OnSelect = function()
															selectedMutation:set(m.Type)
														end,
														LayoutOrder = i,
													}))
												end
												return cards
											end),
										},
									},
								},
							},
							
							-- ========================================
							-- DETAIL PANEL (right side)
							-- ========================================
							New(scope, "Frame") {
								Name = "DetailContainer",
								Size = UDim2.new(0.4, -10, 1, 0),
								Position = UDim2.new(0.6, 10, 0, 0),
								BackgroundTransparency = 1,
								
								[Children] = {
									-- Shadow
									New(scope, "Frame") {
										Name = "Shadow",
										Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
										Position = UDim2.fromOffset(0, SHADOW_OFFSET),
										BackgroundColor3 = Theme.Colors.Surface.Shadow,
										ZIndex = 1,
										
										[Children] = {
											New(scope, "UICorner") {
												CornerRadius = Theme.Layout.CornerRadius,
											},
										},
									},
									
									-- Main panel
									New(scope, "Frame") {
										Name = "Detail",
										Size = UDim2.new(1, 0, 1, -SHADOW_OFFSET),
										BackgroundColor3 = Theme.Colors.Surface.Main,
										ZIndex = 2,
										
										[Children] = {
											New(scope, "UICorner") {
												CornerRadius = Theme.Layout.CornerRadius,
											},
											
											New(scope, "UIStroke") {
												Color = Theme.Colors.Surface.Stroke :: Color3,
												Thickness = Theme.Layout.StrokeThickness,
											},
											
											New(scope, "UIPadding") {
												PaddingTop = UDim.new(0, 16),
												PaddingBottom = UDim.new(0, 16),
												PaddingLeft = UDim.new(0, 16),
												PaddingRight = UDim.new(0, 16),
											},
											
											-- Content (reactive to selection)
											Computed(scope, function(use)
												local mutation = use(selectedMutation)
												local data = use(selectedMutationData)
												
												if not mutation or not data then
													-- Empty state
													return New(scope, "TextLabel") {
														Size = UDim2.new(1, 0, 1, 0),
														BackgroundTransparency = 1,
														Text = "Select a mutation\nto view details",
														TextColor3 = Theme.Colors.Surface.Shadow,
														TextSize = 16,
														Font = Theme.Typography.Fonts.Body,
														TextWrapped = true,
													}
												end
												
												local isOwned = use(isMutationOwned)
												local isEquipped = use(isMutationEquipped)
												local canBuy = use(canPurchase)
												local canEquip = use(canEquipMore)
												
												-- Action button state
												local actionText = if isEquipped then "UNEQUIP"
													elseif isOwned and canEquip then "EQUIP"
													elseif isOwned and not canEquip then "MAX EQUIPPED"
													elseif canBuy then `BUY {Theme.Icons.Coin}{data.Cost}`
													else "LOCKED"
												
												local actionColor = if isEquipped then Theme.Colors.Danger
													elseif isOwned and canEquip then Theme.Colors.Action
													elseif canBuy then Theme.Colors.Gold
													else Theme.Colors.Surface
												
												local actionEnabled = isEquipped or (isOwned and canEquip) or canBuy
												
												return New(scope, "Frame") {
													Size = UDim2.new(1, 0, 1, 0),
													BackgroundTransparency = 1,
													
													[Children] = {
														-- Icon + Name header
														New(scope, "Frame") {
															Size = UDim2.new(1, 0, 0, 60),
															BackgroundTransparency = 1,
															
															[Children] = {
																New(scope, "TextLabel") {
																	Size = UDim2.fromOffset(50, 50),
																	BackgroundTransparency = 1,
																	Text = getMutationIcon(mutation),
																	TextSize = 40,
																},
																New(scope, "TextLabel") {
																	Size = UDim2.new(1, -60, 0, 30),
																	Position = UDim2.fromOffset(55, 0),
																	BackgroundTransparency = 1,
																	Text = data.Name or mutation,
																	TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
																	TextSize = 22,
																	Font = Theme.Typography.Fonts.Title,
																	TextXAlignment = Enum.TextXAlignment.Left,
																},
																New(scope, "TextLabel") {
																	Size = UDim2.new(1, -60, 0, 20),
																	Position = UDim2.fromOffset(55, 32),
																	BackgroundTransparency = 1,
																	Text = `Level {data.RequiredLevel} required`,
																	TextColor3 = Theme.Colors.Surface.Shadow,
																	TextSize = 12,
																	Font = Theme.Typography.Fonts.Body,
																	TextXAlignment = Enum.TextXAlignment.Left,
																},
															},
														},
														
														-- Description
														New(scope, "TextLabel") {
															Size = UDim2.new(1, 0, 0, 60),
															Position = UDim2.fromOffset(0, 70),
															BackgroundTransparency = 1,
															Text = data.Description or "No description available.",
															TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
															TextSize = 14,
															Font = Theme.Typography.Fonts.Body,
															TextWrapped = true,
															TextXAlignment = Enum.TextXAlignment.Left,
															TextYAlignment = Enum.TextYAlignment.Top,
														},
														
														-- Effects list
														New(scope, "Frame") {
															Size = UDim2.new(1, 0, 0, 80),
															Position = UDim2.fromOffset(0, 140),
															BackgroundColor3 = Theme.Colors.Surface.Shadow,
															BackgroundTransparency = 0.5,
															
															[Children] = {
																New(scope, "UICorner") {
																	CornerRadius = Theme.Layout.CornerRadius,
																},
																New(scope, "UIPadding") {
																	PaddingTop = UDim.new(0, 8),
																	PaddingLeft = UDim.new(0, 10),
																},
																New(scope, "TextLabel") {
																	Size = UDim2.new(1, 0, 0, 16),
																	BackgroundTransparency = 1,
																	Text = "EFFECTS:",
																	TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
																	TextSize = 12,
																	Font = Enum.Font.GothamBold,
																	TextXAlignment = Enum.TextXAlignment.Left,
																},
																New(scope, "TextLabel") {
																	Size = UDim2.new(1, -10, 0, 50),
																	Position = UDim2.fromOffset(0, 20),
																	BackgroundTransparency = 1,
																	Text = formatEffects(data.Effects),
																	TextColor3 = Theme.Colors.Action.Main,
																	TextSize = 12,
																	Font = Theme.Typography.Fonts.Body,
																	TextXAlignment = Enum.TextXAlignment.Left,
																	TextYAlignment = Enum.TextYAlignment.Top,
																	TextWrapped = true,
																},
															},
														},
														
														-- Action button
														New(scope, "Frame") {
															Name = "ActionContainer",
															Size = UDim2.new(1, 0, 0, 50 + SHADOW_OFFSET),
															Position = UDim2.new(0, 0, 1, 0),
															AnchorPoint = Vector2.new(0, 1),
															BackgroundTransparency = 1,
															
															[Children] = {
																-- Shadow
																New(scope, "Frame") {
																	Size = UDim2.new(1, 0, 0, 50),
																	Position = UDim2.fromOffset(0, SHADOW_OFFSET),
																	BackgroundColor3 = actionColor.Shadow,
																	ZIndex = 1,
																	
																	[Children] = {
																		New(scope, "UICorner") {
																			CornerRadius = Theme.Layout.CornerRadius,
																		},
																	},
																},
																
																-- Button
																New(scope, "TextButton") {
																	Size = Computed(scope, function(use2)
																		local offset = use2(actionOffset)
																		return UDim2.new(1, 0, 0, 50 - offset)
																	end),
																	Position = Computed(scope, function(use2)
																		return UDim2.fromOffset(0, use2(actionOffset))
																	end),
																	BackgroundColor3 = actionColor.Main,
																	Text = actionText,
																	TextColor3 = Color3.new(1, 1, 1),
																	TextSize = 18,
																	Font = Theme.Typography.Fonts.Title,
																	AutoButtonColor = false,
																	ZIndex = 2,
																	
																	[OnEvent("MouseButton1Down")] = function()
																		if actionEnabled then
																			isActionPressed:set(true)
																		end
																	end,
																	
																	[OnEvent("MouseButton1Up")] = function()
																		isActionPressed:set(false)
																		if actionEnabled then
																			performAction()
																		end
																	end,
																	
																	[OnEvent("MouseLeave")] = function()
																		isActionPressed:set(false)
																	end,
																	
																	[Children] = {
																		New(scope, "UICorner") {
																			CornerRadius = Theme.Layout.CornerRadius,
																		},
																		New(scope, "UIStroke") {
																			Color = Theme.Colors.Surface.Stroke :: Color3,
																			Thickness = Theme.Layout.StrokeThickness,
																		},
																	},
																},
															},
														},
													},
												}
											end),
										},
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

return MutationScreen
