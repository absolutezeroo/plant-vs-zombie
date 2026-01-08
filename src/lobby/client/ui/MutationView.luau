--!strict
--[[
    MutationView.luau - Plant mutation management interface
    
    Allows players to view and purchase mutations for their plants.
    Mutations add special abilities (fire damage, freeze, lifesteal, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MutationData = require(Shared.data.MutationData)
local PlantData = require(Shared.data.PlantData)

local PvZTheme = require(ReplicatedStorage.Shared.ui.PvZTheme)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local peek = Fusion.peek
local ForPairs = Fusion.ForPairs

-- Mutation category icons
local CATEGORY_ICONS: {[string]: string} = {
	Fire = "🔥",
	Ice = "❄️",
	Electric = "⚡",
	Toxic = "☠️",
	Shadow = "🌑",
	Solar = "☀️",
	Reinforced = "🛡️",
	Primal = "💥",
}

-- Mutation category colors
local CATEGORY_COLORS: {[string]: Color3} = {
	Fire = Color3.fromRGB(255, 100, 50),
	Ice = Color3.fromRGB(100, 200, 255),
	Electric = Color3.fromRGB(255, 255, 100),
	Toxic = Color3.fromRGB(100, 255, 100),
	Shadow = Color3.fromRGB(100, 50, 150),
	Solar = Color3.fromRGB(255, 200, 50),
	Reinforced = Color3.fromRGB(150, 150, 150),
	Primal = Color3.fromRGB(200, 100, 50),
}

export type MutationViewProps = {
	PlayerData: any, -- Value<PlayerData?>
	PlantMutations: any, -- Value<{[string]: {string}}>
	OnBack: () -> (),
	OnPurchaseMutation: (plantType: string, mutationType: string) -> (),
	OnRemoveMutation: (plantType: string, mutationType: string) -> (),
}

-- Mutation badge showing active mutation
local function MutationBadge(scope: any, props: {
	MutationType: string,
	OnRemove: () -> (),
}): any
	local mutation = MutationData.Get(props.MutationType)
	if not mutation then return nil end
	
	local icon = CATEGORY_ICONS[mutation.Category] or "✨"
	local color = CATEGORY_COLORS[mutation.Category] or PvZTheme.Colors.GrassGreen
	
	return New(scope, "TextButton") {
		Size = UDim2.new(0, 36, 0, 36),
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = false,
		
		[OnEvent "Activated"] = props.OnRemove,
		
		[Children] = {
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
			New(scope, "TextLabel") {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = icon,
				TextSize = 20,
			},
			-- Remove X on hover
			New(scope, "TextLabel") {
				Size = UDim2.new(0, 14, 0, 14),
				Position = UDim2.new(1, 2, 0, -2),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = PvZTheme.Colors.Error,
				Text = "✕",
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				TextColor3 = PvZTheme.Colors.TextWhite,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
				},
			},
		},
	}
end

-- Plant card with mutations
local function PlantMutationCard(scope: any, props: {
	PlantType: string,
	PlantStats: any,
	Mutations: any, -- Computed<{string}>
	PlayerLevel: any, -- Computed<number>
	PlayerCoins: any, -- Computed<number>
	OnPurchase: (mutationType: string) -> (),
	OnRemove: (mutationType: string) -> (),
}): any
	local isExpanded = Value(scope, false)
	
	-- Get compatible mutations for this plant
	local compatibleMutations = Computed(scope, function(use)
		local plantStats = props.PlantStats
		local category = plantStats.Category
		local result: {typeof(MutationData.Get("Fire"))} = {}
		
		for mutationType, data in MutationData.GetAll() do
			if table.find(data.CompatibleCategories, category) then
				table.insert(result, {Type = mutationType, Data = data})
			end
		end
		
		-- Sort by tier then name
		table.sort(result, function(a, b)
			if a.Data.Tier ~= b.Data.Tier then
				return a.Data.Tier < b.Data.Tier
			end
			return a.Type < b.Type
		end)
		
		return result
	end)
	
	return New(scope, "Frame") {
		Size = Computed(scope, function(use)
			return if use(isExpanded) 
				then UDim2.new(1, 0, 0, 280) 
				else UDim2.new(1, 0, 0, 80)
		end),
		BackgroundColor3 = PvZTheme.Colors.WoodBrown,
		ClipsDescendants = true,
		
		[Children] = {
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 12),
			},
			
			-- Header (always visible)
			New(scope, "TextButton") {
				Size = UDim2.new(1, 0, 0, 80),
				BackgroundTransparency = 1,
				Text = "",
				
				[OnEvent "Activated"] = function()
					isExpanded:set(not peek(isExpanded))
				end,
				
				[Children] = {
					-- Plant icon
					New(scope, "TextLabel") {
						Size = UDim2.new(0, 60, 0, 60),
						Position = UDim2.new(0, 10, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = PvZTheme.Colors.GrassGreen,
						Text = "🌱",
						TextSize = 30,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0, 10),
							},
						},
					},
					
					-- Plant name
					New(scope, "TextLabel") {
						Size = UDim2.new(0.4, -80, 0, 30),
						Position = UDim2.new(0, 80, 0, 15),
						BackgroundTransparency = 1,
						Text = props.PlantType,
						TextSize = 18,
						Font = Enum.Font.GothamBold,
						TextColor3 = PvZTheme.Colors.TextWhite,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
					
					-- Category badge
					New(scope, "TextLabel") {
						Size = UDim2.new(0, 80, 0, 20),
						Position = UDim2.new(0, 80, 0, 48),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						Text = props.PlantStats.Category,
						TextSize = 12,
						Font = Enum.Font.Gotham,
						TextColor3 = PvZTheme.Colors.TextWhite,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0, 4),
							},
						},
					},
					
					-- Active mutations display
					New(scope, "Frame") {
						Size = UDim2.new(0, 150, 0, 40),
						Position = UDim2.new(1, -200, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						
						[Children] = {
							New(scope, "UIListLayout") {
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 4),
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
							},
							
							ForPairs(scope, props.Mutations, function(use, scope, index, mutationType)
								return index, MutationBadge(scope, {
									MutationType = mutationType,
									OnRemove = function()
										props.OnRemove(mutationType)
									end,
								})
							end, Fusion.cleanup),
						},
					},
					
					-- Expand indicator
					New(scope, "TextLabel") {
						Size = UDim2.new(0, 30, 0, 30),
						Position = UDim2.new(1, -10, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						Text = Computed(scope, function(use)
							return if use(isExpanded) then "▲" else "▼"
						end),
						TextSize = 16,
						TextColor3 = PvZTheme.Colors.TextWhite,
					},
				},
			},
			
			-- Expanded mutation selection
			New(scope, "ScrollingFrame") {
				Size = UDim2.new(1, -20, 0, 180),
				Position = UDim2.new(0, 10, 0, 90),
				BackgroundColor3 = PvZTheme.Colors.WoodDark,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = PvZTheme.Colors.WoodLight,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0, 8),
					},
					
					New(scope, "UIGridLayout") {
						CellSize = UDim2.new(0, 140, 0, 70),
						CellPadding = UDim2.new(0, 8, 0, 8),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					},
					
					New(scope, "UIPadding") {
						PaddingAll = UDim.new(0, 8),
					},
					
					-- Mutation options
					ForPairs(scope, compatibleMutations, function(use, scope, index, mutationInfo)
						local mutationType = mutationInfo.Type
						local data = mutationInfo.Data
						
						local isOwned = Computed(scope, function(use)
							local mutations = use(props.Mutations)
							return table.find(mutations, mutationType) ~= nil
						end)
						
						local canPurchase = Computed(scope, function(use)
							if use(isOwned) then return false end
							
							local level = use(props.PlayerLevel)
							local coins = use(props.PlayerCoins)
							
							if level < data.RequiredLevel then return false end
							if coins < data.Cost then return false end
							
							-- Check compatibility with existing mutations
							local mutations = use(props.Mutations)
							for _, existing in mutations do
								if not MutationData.IsCompatibleWith(mutationType, existing) then
									return false
								end
							end
							
							return true
						end)
						
						local icon = CATEGORY_ICONS[data.Category] or "✨"
						local color = CATEGORY_COLORS[data.Category] or PvZTheme.Colors.GrassGreen
						
						return index, New(scope, "TextButton") {
							BackgroundColor3 = Computed(scope, function(use)
								if use(isOwned) then
									return PvZTheme.Colors.LeafGreen
								elseif use(canPurchase) then
									return color
								else
									return PvZTheme.Colors.Disabled
								end
							end),
							Text = "",
							AutoButtonColor = false,
							
							[OnEvent "Activated"] = function()
								if peek(canPurchase) then
									props.OnPurchase(mutationType)
								end
							end,
							
							[Children] = {
								New(scope, "UICorner") {
									CornerRadius = UDim.new(0, 8),
								},
								
								-- Icon
								New(scope, "TextLabel") {
									Size = UDim2.new(0, 30, 0, 30),
									Position = UDim2.new(0, 5, 0, 5),
									BackgroundTransparency = 1,
									Text = icon,
									TextSize = 20,
								},
								
								-- Name
								New(scope, "TextLabel") {
									Size = UDim2.new(1, -40, 0, 20),
									Position = UDim2.new(0, 35, 0, 5),
									BackgroundTransparency = 1,
									Text = mutationType,
									TextSize = 11,
									Font = Enum.Font.GothamBold,
									TextColor3 = PvZTheme.Colors.TextWhite,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextTruncate = Enum.TextTruncate.AtEnd,
								},
								
								-- Tier
								New(scope, "TextLabel") {
									Size = UDim2.new(0, 50, 0, 14),
									Position = UDim2.new(0, 35, 0, 25),
									BackgroundColor3 = PvZTheme.Colors.WoodDark,
									Text = `T{data.Tier}`,
									TextSize = 10,
									Font = Enum.Font.Gotham,
									TextColor3 = PvZTheme.Colors.TextWhite,
									
									[Children] = {
										New(scope, "UICorner") {
											CornerRadius = UDim.new(0, 3),
										},
									},
								},
								
								-- Cost or owned
								New(scope, "TextLabel") {
									Size = UDim2.new(1, -10, 0, 20),
									Position = UDim2.new(0, 5, 1, -25),
									BackgroundTransparency = 1,
									Text = Computed(scope, function(use)
										if use(isOwned) then
											return "✓ Owned"
										else
											return `🪙{data.Cost}`
										end
									end),
									TextSize = 12,
									Font = Enum.Font.GothamBold,
									TextColor3 = Computed(scope, function(use)
										return if use(isOwned) 
											then PvZTheme.Colors.TextWhite 
											else PvZTheme.Colors.SunYellow
									end),
									TextXAlignment = Enum.TextXAlignment.Left,
								},
								
								-- Level requirement
								Computed(scope, function(use)
									local level = use(props.PlayerLevel)
									if data.RequiredLevel > level then
										return New(scope, "TextLabel") {
											Size = UDim2.new(0, 50, 0, 16),
											Position = UDim2.new(1, -5, 1, -20),
											AnchorPoint = Vector2.new(1, 0),
											BackgroundColor3 = PvZTheme.Colors.Error,
											Text = `Lv{data.RequiredLevel}`,
											TextSize = 10,
											Font = Enum.Font.GothamBold,
											TextColor3 = PvZTheme.Colors.TextWhite,
											
											[Children] = {
												New(scope, "UICorner") {
													CornerRadius = UDim.new(0, 4),
												},
											},
										}
									end
									return nil
								end),
							},
						}
					end, Fusion.cleanup),
				},
			},
		},
	}
end

return function(scope: any, props: MutationViewProps)
	-- Compute unlocked plants
	local unlockedPlants = Computed(scope, function(use)
		local data = use(props.PlayerData)
		if not data then return {} end
		
		local result: {{Type: string, Stats: any}} = {}
		for plantType, stats in PlantData.GetAll() do
			if data.UnlockedPlants[plantType] then
				table.insert(result, {Type = plantType, Stats = stats})
			end
		end
		
		table.sort(result, function(a, b)
			return a.Type < b.Type
		end)
		
		return result
	end)
	
	local playerLevel = Computed(scope, function(use)
		local data = use(props.PlayerData)
		return if data then data.Level else 1
	end)
	
	local playerCoins = Computed(scope, function(use)
		local data = use(props.PlayerData)
		return if data then data.Coins else 0
	end)
	
	return New(scope, "Frame") {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = PvZTheme.Colors.SkyBlue,
		
		[Children] = {
			New(scope, "UIGradient") {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 40, 80)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 20, 50)),
				}),
				Rotation = 90,
			},
			
			-- Back button
			PvZTheme.BackButton(scope, props.OnBack),
			
			-- Header
			PvZTheme.Header(scope, "🧬 Mutations"),
			
			-- Coins display
			New(scope, "Frame") {
				Size = UDim2.new(0, 120, 0, 40),
				Position = UDim2.new(1, -20, 0, 15),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = PvZTheme.Colors.WoodBrown,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(0, 10),
					},
					New(scope, "TextLabel") {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = Computed(scope, function(use)
							return `🪙 {use(playerCoins)}`
						end),
						TextSize = 18,
						Font = Enum.Font.GothamBold,
						TextColor3 = PvZTheme.Colors.SunYellow,
					},
				},
			},
			
			-- Main content
			New(scope, "ScrollingFrame") {
				Size = UDim2.new(0.9, 0, 0.8, 0),
				Position = UDim2.new(0.05, 0, 0.12, 0),
				BackgroundTransparency = 1,
				ScrollBarThickness = 8,
				ScrollBarImageColor3 = PvZTheme.Colors.WoodLight,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				
				[Children] = {
					New(scope, "UIListLayout") {
						Padding = UDim.new(0, 12),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					},
					
					-- Plant cards
					ForPairs(scope, unlockedPlants, function(use, scope, index, plantInfo)
						local plantType = plantInfo.Type
						
						local plantMutations = Computed(scope, function(use)
							local allMutations = use(props.PlantMutations)
							return allMutations[plantType] or {}
						end)
						
						return index, PlantMutationCard(scope, {
							PlantType = plantType,
							PlantStats = plantInfo.Stats,
							Mutations = plantMutations,
							PlayerLevel = playerLevel,
							PlayerCoins = playerCoins,
							OnPurchase = function(mutationType)
								props.OnPurchaseMutation(plantType, mutationType)
							end,
							OnRemove = function(mutationType)
								props.OnRemoveMutation(plantType, mutationType)
							end,
						})
					end, Fusion.cleanup),
					
					-- Empty state
					Computed(scope, function(use)
						if #use(unlockedPlants) == 0 then
							return New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 0, 100),
								BackgroundTransparency = 1,
								Text = "No plants unlocked yet!\nUnlock plants in the Shop.",
								TextSize = 18,
								Font = Enum.Font.Gotham,
								TextColor3 = PvZTheme.Colors.TextWhite,
								TextWrapped = true,
							}
						end
						return nil
					end),
				},
			},
		},
	}
end
