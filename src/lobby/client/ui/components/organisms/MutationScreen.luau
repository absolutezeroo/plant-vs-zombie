--!strict
--[[
	MutationScreen.luau - Mutation Lab (Toon Pop + Responsive)
	
	Organism for managing plant mutations.
	Follows EXACT same "Toon Pop" design as ShopScreen:
	- Dark overlay background (50% black)
	- Centered panel (90% x 90%) with BackgroundTransparency = 1
	- Position-based layout (no UIListLayout for main sections)
	- Each section (Header, PlantBar, Content) has its own Shadow + Main
	
	Uses Fusion 0.3 scope:Method() syntax.
	Fully responsive using Scale-based sizing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)
local PlantViewport = require(Shared.ui.components.atoms.PlantViewport)

local Components = script.Parent.Parent
local Atoms = Components.atoms
local ResourcePill = require(Atoms.ResourcePill)

-- Fusion primitives
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

-- Constants
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
	DamageBonus = "Damage", HealthBonus = "Health", CooldownReduction = "Cooldown",
	AttackSpeedBonus = "Attack Speed", AddsBurnDamage = "Burn", BurnDamagePerSecond = "Burn DPS",
	BurnDuration = "Burn Duration", AddsFreeze = "Freeze", FreezeChance = "Freeze Chance",
	FreezeDuration = "Freeze Duration", EnhancedSlow = "Slow", AddsChainLightning = "Chain Lightning",
	ChainCount = "Chain Targets", ChainDamage = "Chain Damage", ChainRange = "Chain Range",
	AddsPoisonCloud = "Poison Cloud", PoisonRadius = "Poison Radius", PoisonDamagePerSecond = "Poison DPS",
	PoisonDuration = "Poison Duration", AddsLifesteal = "Lifesteal", LifestealPercent = "Lifesteal",
	AddsSunOnKill = "Sun on Kill", SunPerKill = "Sun/Kill", SunDropChance = "Sun Chance",
	ExtraHealth = "Bonus HP", DamageReduction = "Damage Reduction", SplashDamage = "Splash Damage",
	SplashRadius = "Splash Radius", SplashPercent = "Splash %", Knockback = "Knockback",
}

local function formatEffects(effects: any): string
	if not effects then return "• Enhances abilities" end
	
	local lines: {string} = {}
	for key, value in pairs(effects) do
		local label = EFFECT_LABELS[key] or key
		local displayValue: string
		
		if type(value) == "boolean" then
			if value then displayValue = "✓" else continue end
		elseif type(value) == "number" then
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
	
	return if #lines == 0 then "• Enhances abilities" else table.concat(lines, "\n")
end

export type MutationScreenProps = {
	Scope: any,
	PlayerData: any,
	OwnedMutations: any,
	EquippedMutations: any,
	OnBack: () -> (),
	OnPurchaseMutation: (plantType: string, mutationType: string) -> (),
	OnEquipMutation: (plantType: string, mutationType: string) -> (),
	OnUnequipMutation: (plantType: string, mutationType: string) -> (),
}

--------------------------------------------------------------------------------
-- PlantCard - Selectable plant in the plant bar (Responsive)
--------------------------------------------------------------------------------
local function PlantCard(scope: any, props: {
	PlantType: string,
	IsSelected: any,
	EquippedCount: number,
	OnSelect: () -> (),
	LayoutOrder: number,
}): Frame
	local isPressed = scope:Value(false)
	
	local pressOffset = scope:Spring(scope:Computed(function(use)
		return if use(isPressed) then 0.06 else 0
	end), 40, 0.7)
	
	-- Create plant viewport
	local viewport = PlantViewport.CreateWithScope(scope, {
		PlantType = props.PlantType,
		Size = UDim2.fromScale(0.85, 0.7),
		Position = UDim2.fromScale(0.5, 0.35),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		CameraFOV = 40,
		CameraDistance = 1.4,
		CameraHeight = 0.1,
	})
	
	return scope:New("Frame") {
		Name = "PlantCard_" .. props.PlantType,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		
		[Children] = {
			scope:New("UIAspectRatioConstraint") { AspectRatio = 0.9 },
			
			-- Shadow
			scope:New("Frame") {
				Name = "Shadow",
				Size = UDim2.fromScale(1, 0.94),
				Position = UDim2.fromScale(0, 0.06),
				BackgroundColor3 = scope:Computed(function(use)
					return if use(props.IsSelected) 
						then Theme.Colors.Action.Shadow 
						else Theme.Colors.Surface.Shadow
				end),
				ZIndex = 1,
				
				[Children] = {
					scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
				},
			},
			
			-- Main card
			scope:New("Frame") {
				Name = "Main",
				Size = scope:Computed(function(use)
					local offset = use(pressOffset)
					return UDim2.fromScale(1, 0.94 - offset)
				end),
				Position = scope:Computed(function(use)
					return UDim2.fromScale(0, use(pressOffset))
				end),
				BackgroundColor3 = scope:Computed(function(use)
					return if use(props.IsSelected) 
						then Theme.Colors.Action.Main 
						else Theme.Colors.Surface.Main
				end),
				ZIndex = 2,
				
				[Children] = {
					scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
					
					scope:New("UIStroke") {
						Color = Theme.Colors.Surface.Stroke :: Color3,
						Thickness = scope:Computed(function(use)
							return if use(props.IsSelected) then 4 else Theme.Layout.StrokeThickness
						end),
					},
					
					viewport,
					
					-- Plant name
					scope:New("TextLabel") {
						Size = UDim2.fromScale(1, 0.2),
						Position = UDim2.fromScale(0.5, 0.92),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Text = props.PlantType,
						TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
						TextScaled = true,
						Font = Enum.Font.GothamBold,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 4,
						
						[Children] = {
							scope:New("UITextSizeConstraint") { MaxTextSize = 12, MinTextSize = 8 },
						},
					},
					
					-- Equipped mutations badge
					props.EquippedCount > 0 and scope:New("Frame") {
						Size = UDim2.fromScale(0.28, 0.28),
						Position = UDim2.fromScale(0.95, 0.05),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundColor3 = Theme.Colors.Purple.Main,
						ZIndex = 5,
						
						[Children] = {
							scope:New("UIAspectRatioConstraint") { AspectRatio = 1 },
							scope:New("UICorner") { CornerRadius = UDim.new(0.5, 0) },
							scope:New("TextLabel") {
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = tostring(props.EquippedCount),
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								Font = Enum.Font.GothamBold,
								
								[Children] = {
									scope:New("UITextSizeConstraint") { MaxTextSize = 14, MinTextSize = 8 },
								},
							},
						},
					} or nil,
					
					-- Click handler
					scope:New("TextButton") {
						Size = UDim2.fromScale(1, 1),
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
-- MutationCard - A mutation in the grid (Responsive)
--------------------------------------------------------------------------------
local function MutationCard(scope: any, props: {
	MutationType: string,
	MutationData: any,
	IsOwned: boolean,
	IsEquipped: boolean,
	IsLocked: boolean,
	IsSelected: any,
	OnSelect: () -> (),
	LayoutOrder: number,
}): Frame
	local isPressed = scope:Value(false)
	
	local pressOffset = scope:Spring(scope:Computed(function(use)
		return if use(isPressed) then 0.05 else 0
	end), 40, 0.7)
	
	local cardColor = if props.IsEquipped then Theme.Colors.Purple.Main
		elseif props.IsOwned then Theme.Colors.Action.Main
		elseif props.IsLocked then Theme.Colors.Surface.Shadow
		else Theme.Colors.Surface.Main
	
	local shadowColor = if props.IsEquipped then Theme.Colors.Purple.Shadow
		elseif props.IsOwned then Theme.Colors.Action.Shadow
		elseif props.IsLocked then Color3.fromHex("#888888")
		else Theme.Colors.Surface.Shadow
	
	return scope:New("Frame") {
		Name = "MutationCard_" .. props.MutationType,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		
		[Children] = {
			scope:New("UIAspectRatioConstraint") { AspectRatio = 0.82 },
			
			-- Shadow
			scope:New("Frame") {
				Name = "Shadow",
				Size = UDim2.fromScale(1, 0.92),
				Position = UDim2.fromScale(0, 0.08),
				BackgroundColor3 = shadowColor,
				ZIndex = 1,
				
				[Children] = {
					scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
				},
			},
			
			-- Main card
			scope:New("Frame") {
				Name = "Main",
				Size = scope:Computed(function(use)
					local offset = use(pressOffset)
					return UDim2.fromScale(1, 0.92 - offset)
				end),
				Position = scope:Computed(function(use)
					return UDim2.fromScale(0, use(pressOffset))
				end),
				BackgroundColor3 = cardColor,
				ZIndex = 2,
				
				[Children] = {
					scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
					
					scope:New("UIStroke") {
						Color = scope:Computed(function(use)
							return if use(props.IsSelected) 
								then Theme.Colors.Gold.Main 
								else Theme.Colors.Surface.Stroke :: Color3
						end),
						Thickness = scope:Computed(function(use)
							return if use(props.IsSelected) then 4 else Theme.Layout.StrokeThickness
						end),
					},
					
					-- Mutation icon
					scope:New("TextLabel") {
						Size = UDim2.fromScale(0.6, 0.45),
						Position = UDim2.fromScale(0.5, 0.28),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = getMutationIcon(props.MutationType),
						TextScaled = true,
						ZIndex = 3,
						
						[Children] = {
							scope:New("UITextSizeConstraint") { MaxTextSize = 40, MinTextSize = 16 },
						},
					},
					
					-- Mutation name
					scope:New("TextLabel") {
						Size = UDim2.fromScale(0.9, 0.18),
						Position = UDim2.fromScale(0.5, 0.62),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = props.MutationData.Name or props.MutationType,
						TextColor3 = if props.IsLocked 
							then Color3.fromHex("#888888") 
							else Theme.Colors.Surface.Stroke :: Color3,
						TextScaled = true,
						Font = Enum.Font.GothamBold,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 3,
						
						[Children] = {
							scope:New("UITextSizeConstraint") { MaxTextSize = 12, MinTextSize = 8 },
						},
					},
					
					-- Status badge
					scope:New("Frame") {
						Size = UDim2.fromScale(0.85, 0.16),
						Position = UDim2.fromScale(0.5, 0.88),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = if props.IsEquipped then Theme.Colors.Purple.Shadow
							elseif props.IsOwned then Theme.Colors.Action.Shadow
							elseif props.IsLocked then Color3.fromHex("#666666")
							else Theme.Colors.Gold.Main,
						ZIndex = 3,
						
						[Children] = {
							scope:New("UICorner") { CornerRadius = UDim.new(0.3, 0) },
							scope:New("TextLabel") {
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = if props.IsEquipped then "EQUIPPED"
									elseif props.IsOwned then "OWNED"
									elseif props.IsLocked then `Lv.{props.MutationData.RequiredLevel}`
									else `${Theme.Icons.Coin}{props.MutationData.Cost}`,
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								Font = Enum.Font.GothamBold,
								
								[Children] = {
									scope:New("UITextSizeConstraint") { MaxTextSize = 10, MinTextSize = 6 },
								},
							},
						},
					},
					
					-- Lock overlay
					props.IsLocked and scope:New("Frame") {
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.new(0, 0, 0),
						BackgroundTransparency = 0.5,
						ZIndex = 8,
						
						[Children] = {
							scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
							scope:New("TextLabel") {
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = Theme.Icons.Lock,
								TextScaled = true,
								
								[Children] = {
									scope:New("UITextSizeConstraint") { MaxTextSize = 32, MinTextSize = 16 },
								},
							},
						},
					} or nil,
					
					-- Click handler
					scope:New("TextButton") {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,
						
						[OnEvent("MouseButton1Down")] = function()
							if not props.IsLocked then isPressed:set(true) end
						end,
						
						[OnEvent("MouseButton1Up")] = function()
							isPressed:set(false)
							if not props.IsLocked then props.OnSelect() end
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
-- MutationScreen Component (Same structure as ShopScreen)
--------------------------------------------------------------------------------
local function MutationScreen(props: MutationScreenProps): Frame
	local scope = props.Scope
	
	-- State
	local selectedPlant = scope:Value(nil :: string?)
	local selectedMutation = scope:Value(nil :: string?)
	
	-- Close button animation
	local isClosePressed = scope:Value(false)
	local closeOffset = scope:Spring(scope:Computed(function(use)
		return if use(isClosePressed) then 4 else 0
	end), 40, 0.7)
	
	-- Action button animation
	local isActionPressed = scope:Value(false)
	local actionOffset = scope:Spring(scope:Computed(function(use)
		return if use(isActionPressed) then 0.06 else 0
	end), 40, 0.7)
	
	-- Unlocked plants
	local unlockedPlants = scope:Computed(function(use)
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
	
	-- Equipped/Owned mutations for selected plant
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
	
	-- Player data
	local playerCoins = scope:Computed(function(use)
		local data = use(props.PlayerData)
		return if data then data.Coins else 0
	end)
	
	local playerLevel = scope:Computed(function(use)
		local data = use(props.PlayerData)
		return if data then data.Level else 1
	end)
	
	-- Selected mutation info
	local selectedMutationData = scope:Computed(function(use)
		local mutation = use(selectedMutation)
		if not mutation then return nil end
		return MutationData.Get(mutation)
	end)
	
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
		local requiredLevel = data.RequiredLevel :: number
		local cost = data.Cost :: number
		return level >= requiredLevel and coins >= cost
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
	
	return scope:New("Frame") {
		Name = "MutationScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		ZIndex = 100,
		
		[Children] = {
			-- Main panel (90% centered, transparent like ShopScreen)
			scope:New("Frame") {
				Name = "Panel",
				Size = UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				
				[Children] = {
					-- ═══════════════════════════════════════════════
					-- HEADER (top 10%) - Same as ShopScreen
					-- ═══════════════════════════════════════════════
					scope:New("Frame") {
						Name = "Header",
						Size = UDim2.fromScale(1, 0.1),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- Shadow
							scope:New("Frame") {
								Name = "Shadow",
								Size = UDim2.fromScale(1, 0.9),
								Position = UDim2.fromScale(0.5, 0.1),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,
								
								[Children] = {
									scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
								},
							},
							
							-- Main header
							scope:New("Frame") {
								Name = "Main",
								Size = UDim2.fromScale(1, 0.9),
								Position = UDim2.fromScale(0.5, 0),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ZIndex = 2,
								
								[Children] = {
									scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
									
									scope:New("UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									-- Title (centered)
									scope:New("TextLabel") {
										Name = "Title",
										Size = UDim2.fromScale(0.3, 0.6),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Text = "🧬 MUTATION LAB",
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextScaled = true,
										Font = Theme.Typography.Fonts.Title,
										
										[Children] = {
											scope:New("UITextSizeConstraint") { MaxTextSize = 32, MinTextSize = 16 },
										},
									},
									
									-- Coins display (left)
									scope:New("Frame") {
										Name = "CoinsContainer",
										Size = UDim2.fromScale(0.15, 0.6),
										Position = UDim2.fromScale(0.02, 0.5),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										
										[Children] = {
											ResourcePill({
												Scope = scope,
												Icon = Theme.Icons.Coin,
												Value = playerCoins,
												Color = "Gold",
											}),
										},
									},
									
									-- Close button (right) - Same as ShopScreen
									scope:New("Frame") {
										Name = "CloseContainer",
										Size = UDim2.fromScale(0.08, 0.75),
										Position = UDim2.fromScale(0.98, 0.5),
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										
										[Children] = {
											scope:New("UIAspectRatioConstraint") {
												AspectRatio = 1,
												DominantAxis = Enum.DominantAxis.Height,
											},
											
											-- Shadow
											scope:New("Frame") {
												Size = UDim2.fromScale(1, 0.9),
												Position = UDim2.fromScale(0.5, 0.1),
												AnchorPoint = Vector2.new(0.5, 0),
												BackgroundColor3 = Theme.Colors.Danger.Shadow,
												ZIndex = 1,
												
												[Children] = {
													scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
												},
											},
											
											-- Button
											scope:New("TextButton") {
												Size = scope:Computed(function(use)
													local offset = use(closeOffset) :: number
													return UDim2.fromScale(1, 0.9 - offset * 0.01)
												end),
												Position = scope:Computed(function(use)
													local offset = use(closeOffset) :: number
													return UDim2.fromScale(0.5, offset * 0.01)
												end),
												AnchorPoint = Vector2.new(0.5, 0),
												BackgroundColor3 = Theme.Colors.Danger.Main,
												Text = Theme.Icons.Close,
												TextColor3 = Color3.new(1, 1, 1),
												TextScaled = true,
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
													scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
													scope:New("UIStroke") {
														Color = Theme.Colors.Surface.Stroke :: Color3,
														Thickness = 2,
													},
													scope:New("UITextSizeConstraint") { MaxTextSize = 24, MinTextSize = 14 },
												},
											},
										},
									},
								},
							},
						},
					},
					
					-- ═══════════════════════════════════════════════
					-- PLANT SELECTOR BAR (11% to 23% = 12% height)
					-- ═══════════════════════════════════════════════
					scope:New("Frame") {
						Name = "PlantBar",
						Size = UDim2.fromScale(1, 0.12),
						Position = UDim2.fromScale(0.5, 0.11),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- Shadow
							scope:New("Frame") {
								Name = "Shadow",
								Size = UDim2.fromScale(1, 0.95),
								Position = UDim2.fromScale(0.5, 0.05),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,
								
								[Children] = {
									scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
								},
							},
							
							-- Main bar
							scope:New("ScrollingFrame") {
								Name = "Main",
								Size = UDim2.fromScale(1, 0.95),
								Position = UDim2.fromScale(0.5, 0),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ScrollBarThickness = 0,
								ScrollingDirection = Enum.ScrollingDirection.X,
								AutomaticCanvasSize = Enum.AutomaticSize.X,
								CanvasSize = UDim2.fromScale(0, 0),
								ZIndex = 2,
								
								[Children] = {
									scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
									scope:New("UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									scope:New("UIPadding") {
										PaddingTop = UDim.new(0.08, 0),
										PaddingBottom = UDim.new(0.08, 0),
										PaddingLeft = UDim.new(0.01, 0),
										PaddingRight = UDim.new(0.01, 0),
									},
									
									scope:New("UIListLayout") {
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0.008, 0),
									},
									
									-- Plant cards
									scope:Computed(function(use)
										local plants = use(unlockedPlants) :: {{Type: string, Stats: any}}
										local allEquipped = use(props.EquippedMutations) or {}
										
										local cards: {any} = {}
										for i, p in plants do
											local plantType: string = p.Type
											local equipped = allEquipped[plantType] or {}
											local isSelected = scope:Computed(function(use2)
												return use2(selectedPlant) == plantType
											end)
											
											table.insert(cards, PlantCard(scope, {
												PlantType = plantType,
												IsSelected = isSelected,
												EquippedCount = #equipped,
												OnSelect = function()
													selectedPlant:set(plantType)
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
					
					-- ═══════════════════════════════════════════════
					-- CONTENT (24% to 100% = 76% height) - Grid + Detail
					-- ═══════════════════════════════════════════════
					scope:New("Frame") {
						Name = "Content",
						Size = UDim2.fromScale(1, 0.76),
						Position = UDim2.fromScale(0.5, 1),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- ═══════════════════════════════════════════════
							-- MUTATIONS GRID (left 58%)
							-- ═══════════════════════════════════════════════
							scope:New("Frame") {
								Name = "GridContainer",
								Size = UDim2.fromScale(0.58, 1),
								Position = UDim2.fromScale(0, 0),
								BackgroundTransparency = 1,
								
								[Children] = {
									-- Shadow
									scope:New("Frame") {
										Name = "Shadow",
										Size = UDim2.fromScale(1, 0.99),
										Position = UDim2.fromScale(0.5, 0.01),
										AnchorPoint = Vector2.new(0.5, 0),
										BackgroundColor3 = Theme.Colors.Surface.Shadow,
										ZIndex = 1,
										
										[Children] = {
											scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
										},
									},
									
									-- Scrolling frame
									scope:New("ScrollingFrame") {
										Name = "Grid",
										Size = UDim2.fromScale(1, 0.99),
										Position = UDim2.fromScale(0.5, 0),
										AnchorPoint = Vector2.new(0.5, 0),
										BackgroundColor3 = Theme.Colors.Surface.Main,
										ScrollBarThickness = 8,
										ScrollBarImageColor3 = Theme.Colors.Surface.Shadow,
										ScrollingDirection = Enum.ScrollingDirection.Y,
										AutomaticCanvasSize = Enum.AutomaticSize.Y,
										CanvasSize = UDim2.new(0, 0, 0, 0),
										ZIndex = 2,
										
										[Children] = {
											scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
											scope:New("UIStroke") {
												Color = Theme.Colors.Surface.Stroke :: Color3,
												Thickness = Theme.Layout.StrokeThickness,
											},
											
											scope:New("UIPadding") {
												PaddingTop = UDim.new(0.02, 0),
												PaddingBottom = UDim.new(0.03, 0),
												PaddingLeft = UDim.new(0.02, 0),
												PaddingRight = UDim.new(0.02, 0),
											},
											
											scope:New("UIGridLayout") {
												CellSize = UDim2.fromScale(0.22, 0.28),
												CellPadding = UDim2.fromScale(0.02, 0.02),
												HorizontalAlignment = Enum.HorizontalAlignment.Left,
												SortOrder = Enum.SortOrder.LayoutOrder,
											},
											
											-- Mutation cards
											scope:Computed(function(use)
												local mutations = use(compatibleMutations) :: {{Type: string, Data: any}}
												local owned = use(plantOwned) :: {string}
												local equipped = use(plantEquipped) :: {string}
												local level = use(playerLevel) :: number
												
												local cards: {any} = {}
												for i, m in mutations do
													local mutationType: string = m.Type
													local mutData: any = m.Data
													local isOwned = table.find(owned, mutationType) ~= nil
													local isEquipped = table.find(equipped, mutationType) ~= nil
													local isLocked = level < (mutData.RequiredLevel :: number)
													
													local isSelected = scope:Computed(function(use2)
														return use2(selectedMutation) == mutationType
													end)
													
													table.insert(cards, MutationCard(scope, {
														MutationType = mutationType,
														MutationData = mutData,
														IsOwned = isOwned,
														IsEquipped = isEquipped,
														IsLocked = isLocked,
														IsSelected = isSelected,
														OnSelect = function()
															selectedMutation:set(mutationType)
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
							
							-- ═══════════════════════════════════════════════
							-- DETAIL PANEL (right 40%)
							-- ═══════════════════════════════════════════════
							scope:New("Frame") {
								Name = "DetailContainer",
								Size = UDim2.fromScale(0.40, 1),
								Position = UDim2.fromScale(1, 0),
								AnchorPoint = Vector2.new(1, 0),
								BackgroundTransparency = 1,
								
								[Children] = {
									-- Shadow
									scope:New("Frame") {
										Name = "Shadow",
										Size = UDim2.fromScale(1, 0.99),
										Position = UDim2.fromScale(0.5, 0.01),
										AnchorPoint = Vector2.new(0.5, 0),
										BackgroundColor3 = Theme.Colors.Surface.Shadow,
										ZIndex = 1,
										
										[Children] = {
											scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
										},
									},
									
									-- Main panel
									scope:New("Frame") {
										Name = "Detail",
										Size = UDim2.fromScale(1, 0.99),
										Position = UDim2.fromScale(0.5, 0),
										AnchorPoint = Vector2.new(0.5, 0),
										BackgroundColor3 = Theme.Colors.Surface.Main,
										ZIndex = 2,
										
										[Children] = {
											scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
											scope:New("UIStroke") {
												Color = Theme.Colors.Surface.Stroke :: Color3,
												Thickness = Theme.Layout.StrokeThickness,
											},
											
											scope:New("UIPadding") {
												PaddingTop = UDim.new(0.03, 0),
												PaddingBottom = UDim.new(0.03, 0),
												PaddingLeft = UDim.new(0.04, 0),
												PaddingRight = UDim.new(0.04, 0),
											},
											
											-- Content (reactive to selection)
											scope:Computed(function(use)
												local mutation = use(selectedMutation) :: string?
												local data = use(selectedMutationData) :: any
												
												if not mutation or not data then
													-- Empty state
													return scope:New("TextLabel") {
														Size = UDim2.fromScale(1, 1),
														BackgroundTransparency = 1,
														Text = "Select a mutation\nto view details",
														TextColor3 = Theme.Colors.Surface.Shadow,
														TextScaled = true,
														Font = Theme.Typography.Fonts.Body,
														TextWrapped = true,
														
														[Children] = {
															scope:New("UITextSizeConstraint") { MaxTextSize = 18, MinTextSize = 12 },
														},
													}
												end
												
												local mutationName: string = mutation :: string
												local isOwned = use(isMutationOwned)
												local isEquipped = use(isMutationEquipped)
												local canBuy = use(canPurchase)
												local canEquip = use(canEquipMore)
												
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
												
												return scope:New("Frame") {
													Size = UDim2.fromScale(1, 1),
													BackgroundTransparency = 1,
													
													[Children] = {
														-- Icon + Name header
														scope:New("Frame") {
															Size = UDim2.fromScale(1, 0.12),
															BackgroundTransparency = 1,
															
															[Children] = {
																scope:New("TextLabel") {
																	Size = UDim2.fromScale(0.15, 1),
																	BackgroundTransparency = 1,
																	Text = getMutationIcon(mutationName),
																	TextScaled = true,
																	
																	[Children] = {
																		scope:New("UIAspectRatioConstraint") { AspectRatio = 1 },
																		scope:New("UITextSizeConstraint") { MaxTextSize = 44, MinTextSize = 24 },
																	},
																},
																scope:New("TextLabel") {
																	Size = UDim2.fromScale(0.82, 0.55),
																	Position = UDim2.fromScale(0.18, 0),
																	BackgroundTransparency = 1,
																	Text = data.Name or mutationName,
																	TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
																	TextScaled = true,
																	Font = Theme.Typography.Fonts.Title,
																	TextXAlignment = Enum.TextXAlignment.Left,
																	
																	[Children] = {
																		scope:New("UITextSizeConstraint") { MaxTextSize = 24, MinTextSize = 14 },
																	},
																},
																scope:New("TextLabel") {
																	Size = UDim2.fromScale(0.82, 0.4),
																	Position = UDim2.fromScale(0.18, 0.55),
																	BackgroundTransparency = 1,
																	Text = `Level {data.RequiredLevel} required`,
																	TextColor3 = Theme.Colors.Surface.Shadow,
																	TextScaled = true,
																	Font = Theme.Typography.Fonts.Body,
																	TextXAlignment = Enum.TextXAlignment.Left,
																	
																	[Children] = {
																		scope:New("UITextSizeConstraint") { MaxTextSize = 14, MinTextSize = 9 },
																	},
																},
															},
														},
														
														-- Description
														scope:New("TextLabel") {
															Size = UDim2.fromScale(1, 0.15),
															Position = UDim2.fromScale(0, 0.15),
															BackgroundTransparency = 1,
															Text = data.Description or "No description available.",
															TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
															TextScaled = true,
															Font = Theme.Typography.Fonts.Body,
															TextWrapped = true,
															TextXAlignment = Enum.TextXAlignment.Left,
															TextYAlignment = Enum.TextYAlignment.Top,
															
															[Children] = {
																scope:New("UITextSizeConstraint") { MaxTextSize = 16, MinTextSize = 10 },
															},
														},
														
														-- Effects list
														scope:New("Frame") {
															Size = UDim2.fromScale(1, 0.25),
															Position = UDim2.fromScale(0, 0.34),
															BackgroundColor3 = Theme.Colors.Surface.Shadow,
															BackgroundTransparency = 0.5,
															
															[Children] = {
																scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
																scope:New("UIPadding") {
																	PaddingTop = UDim.new(0.08, 0),
																	PaddingLeft = UDim.new(0.04, 0),
																},
																scope:New("TextLabel") {
																	Size = UDim2.fromScale(1, 0.2),
																	BackgroundTransparency = 1,
																	Text = "EFFECTS:",
																	TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
																	TextScaled = true,
																	Font = Enum.Font.GothamBold,
																	TextXAlignment = Enum.TextXAlignment.Left,
																	
																	[Children] = {
																		scope:New("UITextSizeConstraint") { MaxTextSize = 14, MinTextSize = 9 },
																	},
																},
																scope:New("TextLabel") {
																	Size = UDim2.fromScale(0.95, 0.7),
																	Position = UDim2.fromScale(0, 0.25),
																	BackgroundTransparency = 1,
																	Text = formatEffects(data.Effects),
																	TextColor3 = Theme.Colors.Action.Main,
																	TextScaled = true,
																	Font = Theme.Typography.Fonts.Body,
																	TextXAlignment = Enum.TextXAlignment.Left,
																	TextYAlignment = Enum.TextYAlignment.Top,
																	TextWrapped = true,
																	
																	[Children] = {
																		scope:New("UITextSizeConstraint") { MaxTextSize = 13, MinTextSize = 9 },
																	},
																},
															},
														},
														
														-- Action button
														scope:New("Frame") {
															Name = "ActionContainer",
															Size = UDim2.fromScale(1, 0.12),
															Position = UDim2.fromScale(0, 0.88),
															BackgroundTransparency = 1,
															
															[Children] = {
																-- Shadow
																scope:New("Frame") {
																	Size = UDim2.fromScale(1, 0.85),
																	Position = UDim2.fromScale(0, 0.15),
																	BackgroundColor3 = actionColor.Shadow,
																	ZIndex = 1,
																	
																	[Children] = {
																		scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
																	},
																},
																
																-- Button
																scope:New("TextButton") {
																	Size = scope:Computed(function(use2)
																		local offset = use2(actionOffset)
																		return UDim2.fromScale(1, 0.85 - offset)
																	end),
																	Position = scope:Computed(function(use2)
																		return UDim2.fromScale(0, use2(actionOffset))
																	end),
																	BackgroundColor3 = actionColor.Main,
																	Text = actionText,
																	TextColor3 = Color3.new(1, 1, 1),
																	TextScaled = true,
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
																		scope:New("UICorner") { CornerRadius = Theme.Layout.CornerRadius },
																		scope:New("UIStroke") {
																			Color = Theme.Colors.Surface.Stroke :: Color3,
																			Thickness = Theme.Layout.StrokeThickness,
																		},
																		scope:New("UITextSizeConstraint") { MaxTextSize = 20, MinTextSize = 12 },
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
