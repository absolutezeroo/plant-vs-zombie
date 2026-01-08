--!strict
--[[
	CardDeck.luau - Plant selection card deck UI component
	
	Modern card deck UI matching Lobby style:
	- Shows plant cards with mutation badges
	- Displays cost, cooldown overlay
	- Highlights selected card
	- Includes shovel button
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)
local ModernTheme = require(Shared.ui.ModernTheme)

local Client = script.Parent.Parent
local PlayerDataClient = require(Client.modules.PlayerDataClient)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local ForValues = Fusion.ForValues

-- Use shared theme colors
local ThemeColors = ModernTheme.Colors
local Colors = {
	CardBg = ThemeColors.PanelLight,
	CardSelected = ThemeColors.SuccessLight,
	CardDisabled = ThemeColors.Disabled,
	SlotEmpty = ThemeColors.SlotEmpty,
	SlotFilled = ThemeColors.SlotFilled,
	Green = ThemeColors.SuccessLight,
	Red = ThemeColors.Error,
	Gold = ThemeColors.Coins,
	TextWhite = ThemeColors.TextWhite,
	TextMuted = ThemeColors.TextMuted,
	Border = ThemeColors.Border,
}

-- Use shared emoji functions
local getPlantEmoji = ModernTheme.GetPlantEmoji
local getMutationEmoji = ModernTheme.GetMutationEmoji

-- Card configuration
local CARD_SIZE = UDim2.fromOffset(75, 95)
local CARD_SPACING = 8

export type CardDeckProps = {
	Scope: any, -- Fusion.Scope
	SelectedPlant: any, -- Fusion.Value<string?>
	SunCount: any, -- Fusion.Value<number>
	Cooldowns: any, -- Fusion.Value<{[string]: number}>
	ShovelMode: any, -- Fusion.Value<boolean>
	PlayerMutations: any?, -- Fusion.Value<{[string]: {string}}>?
	OnSelect: (plantType: string) -> (),
	OnShovelToggle: () -> (),
}

local function PlantCard(props: {
	Scope: any,
	PlantType: string,
	SelectedPlant: any,
	SunCount: any,
	Cooldowns: any,
	Mutations: {string}?,
	OnSelect: (plantType: string) -> (),
	LayoutOrder: number?,
})
	local scope = props.Scope
	local plantType = props.PlantType
	local stats = PlantData[plantType]
	
	if not stats then
		Logger.Warn("CardDeck", `Unknown plant type: {plantType}`)
		return nil
	end
	
	-- Is this card selected?
	local isSelected = Computed(scope, function(use)
		return use(props.SelectedPlant) == plantType
	end)
	
	-- Can player afford this?
	local canAfford = Computed(scope, function(use)
		return use(props.SunCount) >= stats.Cost
	end)
	
	-- Cooldown remaining
	local cooldownRemaining = Value(scope, 0)
	
	-- Update cooldown every frame
	task.spawn(function()
		while true do
			local cooldowns = Fusion.peek(props.Cooldowns)
			local endTime = cooldowns[plantType]
			if endTime then
				cooldownRemaining:set(math.max(0, endTime - tick()))
			else
				cooldownRemaining:set(0)
			end
			task.wait(0.1)
		end
	end)
	
	local isOnCooldown = Computed(scope, function(use)
		return use(cooldownRemaining) > 0
	end)
	
	-- Modern card colors
	local backgroundColor = Computed(scope, function(use)
		if use(isOnCooldown) then
			return Colors.CardDisabled
		elseif not use(canAfford) then
			return Color3.fromRGB(80, 50, 50) -- Dark red when can't afford
		elseif use(isSelected) then
			return Colors.CardSelected
		else
			return Colors.SlotFilled
		end
	end)
	
	local borderColor = Computed(scope, function(use)
		local hasMutation = props.Mutations and #props.Mutations > 0
		if hasMutation then
			return Color3.fromRGB(255, 150, 50) -- Orange for mutations
		elseif use(isSelected) then
			return Colors.Gold
		else
			return Colors.Green
		end
	end)
	
	local borderThickness = if props.Mutations and #props.Mutations > 0 then 3 else 2
	
	-- Hover state
	local isHovered = Value(scope, false)
	
	local button = New(scope, "TextButton")({
		Name = `Card_{plantType}`,
		Size = CARD_SIZE,
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder or 0,
		
		[OnEvent("Activated")] = function()
			props.OnSelect(plantType)
		end,
		
		[OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,
		
		[OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,
		
		[Children] = {
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
			New(scope, "UIStroke")({
				Color = borderColor,
				Thickness = borderThickness,
			}),
			
			-- Mutation badge (top-right)
			(props.Mutations and #props.Mutations > 0) and New(scope, "Frame")({
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.new(1, -4, 0, 4),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(255, 100, 50),
				ZIndex = 6,
				[Children] = {
					New(scope, "UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					New(scope, "TextLabel")({
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = getMutationEmoji(props.Mutations[1]),
						TextSize = 14,
					}),
				},
			}) or nil,
			
			-- Plant emoji
			New(scope, "TextLabel")({
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.fromOffset(0, 10),
				BackgroundTransparency = 1,
				Text = getPlantEmoji(plantType),
				TextSize = 32,
			}),
			
			-- Cost
			New(scope, "Frame")({
				Size = UDim2.fromOffset(45, 22),
				Position = UDim2.new(0.5, 0, 0, 50),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Colors.CardBg,
				[Children] = {
					New(scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
					New(scope, "UIStroke")({
						Color = Colors.Border,
						Thickness = 1,
					}),
					New(scope, "TextLabel")({
						Size = UDim2.fromOffset(16, 22),
						Position = UDim2.fromOffset(2, 0),
						BackgroundTransparency = 1,
						Text = "☀️",
						TextSize = 12,
					}),
					New(scope, "TextLabel")({
						Size = UDim2.fromOffset(25, 22),
						Position = UDim2.fromOffset(18, 0),
						BackgroundTransparency = 1,
						Text = tostring(stats.Cost),
						TextColor3 = Computed(scope, function(use)
							return if use(canAfford) then Colors.Gold else Colors.Red
						end),
						TextSize = 13,
						Font = Enum.Font.GothamBold,
					}),
				},
			}),
			
			-- Plant name (small, bottom)
			New(scope, "TextLabel")({
				Size = UDim2.new(1, -8, 0, 18),
				Position = UDim2.new(0, 4, 1, -20),
				BackgroundTransparency = 1,
				Text = if #plantType > 9 then plantType:sub(1, 8) .. "." else plantType,
				TextColor3 = Colors.TextWhite,
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			
			-- Cooldown overlay
			Computed(scope, function(use)
				if use(isOnCooldown) then
					local cd = use(cooldownRemaining)
					return New(scope, "Frame")({
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.6,
						ZIndex = 3,
						[Children] = {
							New(scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
							New(scope, "TextLabel")({
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = string.format("%.1f", cd),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 20,
								Font = Enum.Font.GothamBold,
							}),
						},
					})
				end
				return nil
			end),
		},
	})
	
	return button
end

local function CardDeck(props: CardDeckProps)
	local scope = props.Scope
	
	-- Get player's saved deck
	local sortedDeckPlants = Computed(scope, function(use)
		local deck = use(PlayerDataClient.GetDeckValue())
		local sorted = table.clone(deck)
		table.sort(sorted, function(a, b)
			local statsA = PlantData[a]
			local statsB = PlantData[b]
			if not statsA then return false end
			if not statsB then return true end
			return statsA.Cost < statsB.Cost
		end)
		return sorted
	end)
	
	-- Calculate deck size based on saved deck (+1 for shovel button)
	local deckSize = Computed(scope, function(use)
		local deck = use(sortedDeckPlants)
		local numPlants = #deck + 1 -- +1 for shovel
		return UDim2.fromOffset(
			numPlants * (CARD_SIZE.X.Offset + CARD_SPACING) - CARD_SPACING + 20,
			CARD_SIZE.Y.Offset + 20
		)
	end)
	
	-- Shovel button style
	local shovelBgColor = Computed(scope, function(use)
		return if use(props.ShovelMode) 
			then Colors.Red -- Active = red
			else Colors.CardBg
	end)
	
	local shovelBorderColor = Computed(scope, function(use)
		return if use(props.ShovelMode)
			then Colors.Gold
			else Colors.Border
	end)
	
	return New(scope, "Frame")({
		Name = "CardDeck",
		Position = UDim2.new(0.5, 0, 1, -15),
		AnchorPoint = Vector2.new(0.5, 1),
		Size = deckSize,
		BackgroundColor3 = Colors.CardBg,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		
		[Children] = {
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 16) }),
			New(scope, "UIStroke")({
				Color = Colors.Border,
				Thickness = 2,
			}),
			New(scope, "UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, CARD_SPACING),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			New(scope, "UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),
			
			-- Reactive plant cards based on saved deck
			ForValues(scope, sortedDeckPlants, function(use, innerScope, plantType)
				local stats = PlantData[plantType]
				local layoutOrder = if stats then stats.Cost else 999
				
				-- Get mutations for this plant (reactive)
				local mutations = nil
				if props.PlayerMutations then
					local allMutations = use(props.PlayerMutations)
					if allMutations then
						mutations = allMutations[plantType]
						if mutations and #mutations > 0 then
							Logger.Info("CardDeck", `{plantType} has {#mutations} mutations: {table.concat(mutations, ", ")}`)
						end
					end
				end
				
				return PlantCard({
					Scope = innerScope,
					PlantType = plantType,
					SelectedPlant = props.SelectedPlant,
					SunCount = props.SunCount,
					Cooldowns = props.Cooldowns,
					Mutations = mutations,
					OnSelect = props.OnSelect,
					LayoutOrder = layoutOrder,
				})
			end),
			
			-- Shovel Button (at the end)
			New(scope, "TextButton")({
				Name = "ShovelButton",
				Size = CARD_SIZE,
				BackgroundColor3 = shovelBgColor,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				LayoutOrder = 99999, -- Always last
				
				[OnEvent("Activated")] = function()
					props.OnShovelToggle()
				end,
				
				[Children] = {
					New(scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
					New(scope, "UIStroke")({
						Color = shovelBorderColor,
						Thickness = 2,
					}),
					
					-- Shovel icon (emoji)
					New(scope, "TextLabel")({
						Name = "Icon",
						Position = UDim2.new(0.5, 0, 0.4, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(40, 40),
						BackgroundTransparency = 1,
						Text = "🪓",
						TextScaled = true,
					}),
					
					-- Label
					New(scope, "TextLabel")({
						Name = "Label",
						Position = UDim2.new(0.5, 0, 0.78, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.new(0.9, 0, 0.2, 0),
						BackgroundTransparency = 1,
						Text = Computed(scope, function(use)
							return if use(props.ShovelMode) then "CANCEL" else "DIG"
						end),
						TextColor3 = Colors.TextWhite,
						TextScaled = true,
						Font = Enum.Font.GothamBold,
						
						[Children] = {
							New(scope, "UIStroke")({
								Color = Color3.fromRGB(0, 0, 0),
								Thickness = 1,
							}),
						},
					}),
				},
			}),
		},
	})
end

return CardDeck
