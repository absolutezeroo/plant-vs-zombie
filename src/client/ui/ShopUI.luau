--!strict
--[[
	ShopUI.luau - Pre-game shop for unlocking plants and purchasing upgrades
	
	Displays:
	- Grid of all plants (locked/unlocked)
	- Cost to unlock locked plants
	- Upgrade buttons for unlocked plants
	- Player's coin balance
	
	Shows before wave starts (during "Prepare" phase).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local ProgressionData = require(Shared.data.ProgressionData)
local Logger = require(Shared.utils.Logger)

local Client = script.Parent.Parent
local PlayerDataClient = require(Client.modules.PlayerDataClient)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local ForPairs = Fusion.ForPairs

-- Shop configuration
local CARD_SIZE = UDim2.fromOffset(100, 140)
local CARD_SPACING = 10
local UPGRADE_BUTTON_SIZE = UDim2.fromOffset(28, 28)

-- Plant icon colors (same as CardDeck)
local PLANT_ICON_COLORS: {[string]: Color3} = {
	Sunflower = Color3.fromRGB(255, 220, 50),
	Peashooter = Color3.fromRGB(100, 200, 100),
	WallNut = Color3.fromRGB(180, 140, 80),
	SnowPea = Color3.fromRGB(130, 200, 255),
	CherryBomb = Color3.fromRGB(220, 60, 60),
	PotatoMine = Color3.fromRGB(140, 100, 60),
	Repeater = Color3.fromRGB(60, 180, 60),
}

-- Upgrade type icons
local UPGRADE_ICONS: {[string]: string} = {
	Damage = "⚔️",
	Health = "❤️",
	Cooldown = "⏱️",
}

local UPGRADE_COLORS: {[string]: Color3} = {
	Damage = Color3.fromRGB(220, 80, 80),
	Health = Color3.fromRGB(80, 180, 80),
	Cooldown = Color3.fromRGB(80, 150, 220),
}

-- Plant card component
local function PlantShopCard(props: {
	Scope: any,
	PlantType: string,
	OnUnlock: (plantType: string) -> (),
	OnUpgrade: (plantType: string, upgradeType: string) -> (),
})
	local scope = props.Scope
	local plantType = props.PlantType
	local stats = PlantData[plantType]
	local unlockInfo = ProgressionData.PlantUnlocks[plantType]
	
	if not stats or not unlockInfo then
		return nil
	end
	
	-- Is this plant unlocked?
	local isUnlocked = Computed(scope, function(use)
		local unlocked = use(PlayerDataClient.GetUnlockedPlantsValue())
		return table.find(unlocked, plantType) ~= nil
	end)
	
	-- Can afford unlock?
	local canAffordUnlock = Computed(scope, function(use)
		if unlockInfo.StarterPlant then return true end
		return use(PlayerDataClient.GetCoinsValue()) >= unlockInfo.Cost
	end)
	
	-- Get upgrade levels
	local upgradeLevels = Computed(scope, function(use)
		-- Force reactivity by reading coins (data sync updates coins)
		use(PlayerDataClient.GetCoinsValue())
		return PlayerDataClient.GetPlantUpgrades(plantType)
	end)
	
	-- Create upgrade button
	local function UpgradeButton(upgradeType: string)
		local upgradeInfo = ProgressionData.Upgrades[upgradeType]
		
		local currentLevel = Computed(scope, function(use)
			local levels = use(upgradeLevels)
			return (levels :: any)[upgradeType] or 0
		end)
		
		local nextCost = Computed(scope, function(use)
			local level = use(currentLevel)
			if level >= upgradeInfo.MaxLevel then
				return nil
			end
			return upgradeInfo.CostPerLevel[level + 1]
		end)
		
		local canAfford = Computed(scope, function(use)
			local cost = use(nextCost)
			if not cost then return false end
			return use(PlayerDataClient.GetCoinsValue()) >= cost
		end)
		
		local isMaxed = Computed(scope, function(use)
			return use(currentLevel) >= upgradeInfo.MaxLevel
		end)
		
		return New(scope, "TextButton")({
			Name = `Upgrade_{upgradeType}`,
			Size = UPGRADE_BUTTON_SIZE,
			BackgroundColor3 = Computed(scope, function(use)
				if use(isMaxed) then
					return Color3.fromRGB(100, 100, 100)
				elseif use(canAfford) then
					return UPGRADE_COLORS[upgradeType]
				else
					return Color3.fromRGB(80, 80, 80)
				end
			end),
			BorderSizePixel = 0,
			AutoButtonColor = Computed(scope, function(use)
				return not use(isMaxed) and use(canAfford)
			end),
			
			[OnEvent("Activated")] = function()
				if not Fusion.peek(isMaxed) and Fusion.peek(canAfford) then
					props.OnUpgrade(plantType, upgradeType)
				end
			end,
			
			[Children] = {
				New(scope, "UICorner")({ CornerRadius = UDim.new(0, 4) }),
				
				-- Icon
				New(scope, "TextLabel")({
					Position = UDim2.fromScale(0.5, 0.3),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromScale(0.8, 0.5),
					BackgroundTransparency = 1,
					Text = UPGRADE_ICONS[upgradeType],
					TextScaled = true,
				}),
				
				-- Level indicator
				New(scope, "TextLabel")({
					Position = UDim2.fromScale(0.5, 0.75),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromScale(0.8, 0.3),
					BackgroundTransparency = 1,
					Text = Computed(scope, function(use)
						local level = use(currentLevel)
						if use(isMaxed) then
							return "MAX"
						else
							return `{level}/{upgradeInfo.MaxLevel}`
						end
					end),
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
				}),
			},
		})
	end
	
	return New(scope, "Frame")({
		Name = `Card_{plantType}`,
		Size = CARD_SIZE,
		BackgroundColor3 = Computed(scope, function(use)
			if use(isUnlocked) then
				return Color3.fromRGB(50, 80, 50)
			else
				return Color3.fromRGB(60, 60, 60)
			end
		end),
		BorderSizePixel = 0,
		
		[Children] = {
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
			
			-- Plant icon
			New(scope, "Frame")({
				Name = "Icon",
				Position = UDim2.new(0.5, 0, 0.2, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(50, 50),
				BackgroundColor3 = Computed(scope, function(use)
					if use(isUnlocked) then
						return PLANT_ICON_COLORS[plantType] or Color3.fromRGB(150, 150, 150)
					else
						return Color3.fromRGB(80, 80, 80)
					end
				end),
				BorderSizePixel = 0,
				
				[Children] = {
					New(scope, "UICorner")({ CornerRadius = UDim.new(0, 6) }),
					New(scope, "TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = string.sub(plantType, 1, 1),
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
					}),
				},
			}),
			
			-- Plant name
			New(scope, "TextLabel")({
				Name = "PlantName",
				Position = UDim2.new(0.5, 0, 0.45, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0.9, 0, 0.12, 0),
				BackgroundTransparency = 1,
				Text = stats.Name,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Font = Enum.Font.GothamMedium,
			}),
			
			-- Locked overlay / Unlock button
			Computed(scope, function(use)
				if use(isUnlocked) then
					-- Show upgrade buttons
					return New(scope, "Frame")({
						Name = "Upgrades",
						Position = UDim2.new(0.5, 0, 0.75, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.new(0.95, 0, 0.35, 0),
						BackgroundTransparency = 1,
						
						[Children] = {
							New(scope, "UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 4),
							}),
							UpgradeButton("Damage"),
							UpgradeButton("Health"),
							UpgradeButton("Cooldown"),
						},
					})
				else
					-- Show unlock button
					return New(scope, "TextButton")({
						Name = "UnlockButton",
						Position = UDim2.new(0.5, 0, 0.75, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.new(0.8, 0, 0.25, 0),
						BackgroundColor3 = Computed(scope, function(use2)
							if use2(canAffordUnlock) then
								return Color3.fromRGB(80, 180, 80)
							else
								return Color3.fromRGB(100, 100, 100)
							end
						end),
						BorderSizePixel = 0,
						AutoButtonColor = canAffordUnlock,
						Text = `🪙 {unlockInfo.Cost}`,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
						
						[OnEvent("Activated")] = function()
							if Fusion.peek(canAffordUnlock) then
								props.OnUnlock(plantType)
							end
						end,
						
						[Children] = {
							New(scope, "UICorner")({ CornerRadius = UDim.new(0, 6) }),
						},
					})
				end
			end),
		},
	})
end

export type ShopUIProps = {
	Scope: any,
	Visible: any, -- Fusion.Value<boolean>
	OnClose: () -> (),
}

local function ShopUI(props: ShopUIProps)
	local scope = props.Scope
	
	-- Get sorted plant list
	local sortedPlants: {string} = {}
	for plantType, info in ProgressionData.PlantUnlocks do
		table.insert(sortedPlants, plantType)
	end
	table.sort(sortedPlants, function(a, b)
		return ProgressionData.PlantUnlocks[a].Order < ProgressionData.PlantUnlocks[b].Order
	end)
	
	-- Callbacks
	local function onUnlock(plantType: string)
		PlayerDataClient.RequestUnlockPlant(plantType)
		Logger.Debug("ShopUI", `Requested unlock for {plantType}`)
	end
	
	local function onUpgrade(plantType: string, upgradeType: string)
		PlayerDataClient.RequestPurchaseUpgrade(plantType, upgradeType)
		Logger.Debug("ShopUI", `Requested {upgradeType} upgrade for {plantType}`)
	end
	
	return New(scope, "Frame")({
		Name = "ShopUI",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		Visible = props.Visible,
		ZIndex = 50,
		
		[Children] = {
			-- Shop container
			New(scope, "Frame")({
				Name = "Container",
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(800, 500),
				BackgroundColor3 = Color3.fromRGB(30, 30, 30),
				BorderSizePixel = 0,
				
				[Children] = {
					New(scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
					
					-- Header
					New(scope, "Frame")({
						Name = "Header",
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.new(1, 0, 0, 60),
						BackgroundColor3 = Color3.fromRGB(40, 40, 40),
						BorderSizePixel = 0,
						
						[Children] = {
							New(scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
							
							-- Title
							New(scope, "TextLabel")({
								Position = UDim2.fromOffset(20, 0),
								Size = UDim2.new(0.5, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = "🛒 Plant Shop",
								TextColor3 = Color3.new(1, 1, 1),
								TextXAlignment = Enum.TextXAlignment.Left,
								TextSize = 28,
								Font = Enum.Font.GothamBold,
							}),
							
							-- Coin display
							New(scope, "TextLabel")({
								Position = UDim2.new(1, -120, 0.5, 0),
								AnchorPoint = Vector2.new(0, 0.5),
								Size = UDim2.fromOffset(100, 30),
								BackgroundTransparency = 1,
								Text = Computed(scope, function(use)
									return `🪙 {use(PlayerDataClient.GetCoinsValue())}`
								end),
								TextColor3 = Color3.fromRGB(255, 200, 50),
								TextXAlignment = Enum.TextXAlignment.Right,
								TextSize = 22,
								Font = Enum.Font.GothamBold,
							}),
							
							-- Close button
							New(scope, "TextButton")({
								Name = "CloseButton",
								Position = UDim2.new(1, -10, 0.5, 0),
								AnchorPoint = Vector2.new(1, 0.5),
								Size = UDim2.fromOffset(40, 40),
								BackgroundColor3 = Color3.fromRGB(200, 60, 60),
								BorderSizePixel = 0,
								Text = "✕",
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 24,
								Font = Enum.Font.GothamBold,
								
								[OnEvent("Activated")] = props.OnClose,
								
								[Children] = {
									New(scope, "UICorner")({ CornerRadius = UDim.new(0, 6) }),
								},
							}),
						},
					}),
					
					-- Plant grid
					New(scope, "ScrollingFrame")({
						Name = "PlantGrid",
						Position = UDim2.fromOffset(20, 80),
						Size = UDim2.new(1, -40, 1, -100),
						BackgroundTransparency = 1,
						ScrollBarThickness = 6,
						ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100),
						CanvasSize = UDim2.fromOffset(0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						
						[Children] = {
							New(scope, "UIGridLayout")({
								CellSize = CARD_SIZE,
								CellPadding = UDim2.fromOffset(CARD_SPACING, CARD_SPACING),
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
							}),
							
							-- Plant cards
							table.unpack((function()
								local cards = {}
								for _, plantType in sortedPlants do
									table.insert(cards, PlantShopCard({
										Scope = scope,
										PlantType = plantType,
										OnUnlock = onUnlock,
										OnUpgrade = onUpgrade,
									}))
								end
								return cards
							end)()),
						},
					}),
				},
			}),
		},
	})
end

return ShopUI
