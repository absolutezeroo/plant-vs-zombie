--!strict
--[[
	CardDeck.luau - Plant selection card deck UI component
	
	Displays 3 plant cards at bottom of screen.
	- Tap to select plant
	- Shows cost, cooldown overlay
	- Highlights selected card
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

local Client = script.Parent.Parent
local PlayerDataClient = require(Client.modules.PlayerDataClient)

-- Theme
local PvZTheme = require(script.Parent.PvZTheme)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local ForValues = Fusion.ForValues

-- Card configuration
local CARD_SIZE = UDim2.fromOffset(60, 80) -- Smaller cards to fit 7 on mobile
local CARD_SPACING = 6
-- Full deck with all Epic 5 plants ordered by cost
local DECK_PLANTS = { 
	"PotatoMine",   -- 25 sun
	"Sunflower",    -- 50 sun  
	"WallNut",      -- 50 sun
	"Peashooter",   -- 100 sun
	"CherryBomb",   -- 150 sun
	"SnowPea",      -- 175 sun
	"Repeater",     -- 200 sun
}

-- Custom icon colors per plant type
local PLANT_ICON_COLORS: {[string]: Color3} = {
	Sunflower = Color3.fromRGB(255, 220, 50),   -- Yellow
	Peashooter = Color3.fromRGB(100, 200, 100), -- Green
	WallNut = Color3.fromRGB(180, 140, 80),     -- Brown
	SnowPea = Color3.fromRGB(130, 200, 255),    -- Ice blue
	CherryBomb = Color3.fromRGB(220, 60, 60),   -- Red
	PotatoMine = Color3.fromRGB(140, 100, 60),  -- Dark brown
	Repeater = Color3.fromRGB(60, 180, 60),     -- Darker green (double pea)
}

export type CardDeckProps = {
	Scope: any, -- Fusion.Scope
	SelectedPlant: any, -- Fusion.Value<string?>
	SunCount: any, -- Fusion.Value<number>
	Cooldowns: any, -- Fusion.Value<{[string]: number}>
	OnSelect: (plantType: string) -> (),
}

local function PlantCard(props: {
	Scope: any,
	PlantType: string,
	SelectedPlant: any,
	SunCount: any,
	Cooldowns: any,
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
	
	-- Update cooldown every frame (using Fusion's internal clock would be better but this works)
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
	
	-- Card background color (PvZ style)
	local backgroundColor = Computed(scope, function(use)
		if use(isOnCooldown) then
			return PvZTheme.Colors.Disabled
		elseif not use(canAfford) then
			return Color3.fromRGB(140, 80, 60) -- Brownish red when can't afford
		elseif use(isSelected) then
			return PvZTheme.Colors.GrassGreen
		else
			return PvZTheme.Colors.WoodBrown
		end
	end)
	
	-- Border color (PvZ style)
	local borderColor = Computed(scope, function(use)
		if use(isSelected) then
			return PvZTheme.Colors.SunYellow
		else
			return PvZTheme.Colors.WoodDark
		end
	end)
	
	-- Hover state for animation
	local isHovered = Value(scope, false)
	
	-- Card scale based on hover/selection
	local cardScale = Computed(scope, function(use)
		if use(isSelected) then
			return 1.05
		elseif use(isHovered) then
			return 1.08
		else
			return 1
		end
	end)
	
	-- Create the button with animation
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
			-- Scale container for animation
			New(scope, "UIScale")({
				Scale = cardScale,
			}),
			-- Border
			New(scope, "UIStroke")({
				Color = borderColor,
				Thickness = 3,
			}),
			
			-- Corner rounding
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
			
			-- Plant icon placeholder (colored square for MVP)
			New(scope, "Frame")({
				Name = "Icon",
				Position = UDim2.new(0.5, 0, 0.35, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(40, 40), -- Smaller icon for smaller cards
				BackgroundColor3 = PLANT_ICON_COLORS[plantType] or Color3.fromRGB(150, 150, 150),
				BorderSizePixel = 0,
				
				[Children] = {
					New(scope, "UICorner")({ CornerRadius = UDim.new(0, 6) }),
					New(scope, "TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = string.sub(plantType, 1, 1), -- First letter
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
					}),
				},
			}),
			
			-- Cost display with stroke
			New(scope, "TextLabel")({
				Name = "Cost",
				Position = UDim2.new(0.5, 0, 0.75, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0.9, 0, 0.2, 0),
				BackgroundTransparency = 1,
				Text = Computed(scope, function(use)
					if use(isOnCooldown) then
						return string.format("%.1fs", use(cooldownRemaining))
					else
						return PvZTheme.Icons.Sun .. " " .. tostring(stats.Cost)
					end
				end),
				TextColor3 = Computed(scope, function(use)
					if use(canAfford) and not use(isOnCooldown) then
						return PvZTheme.Colors.SunYellow
					else
						return Color3.fromRGB(255, 150, 150)
					end
				end),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				
				[Children] = {
					New(scope, "UIStroke")({
						Color = Color3.fromRGB(0, 0, 0),
						Thickness = 1,
					}),
				},
			}),
			
			-- Cooldown overlay
			New(scope, "Frame")({
				Name = "CooldownOverlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = Computed(scope, function(use)
					return use(isOnCooldown) and 0.5 or 1
				end),
				BorderSizePixel = 0,
				ZIndex = 10,
				
				[Children] = {
					New(scope, "UICorner")({ CornerRadius = UDim.new(0, 8) }),
				},
			}),
		},
	})
	
	return button
end

local function CardDeck(props: CardDeckProps)
	local scope = props.Scope
	
	-- Get unlocked plants sorted by cost
	local sortedUnlockedPlants = Computed(scope, function(use)
		local unlocked = use(PlayerDataClient.GetUnlockedPlantsValue())
		local sorted = table.clone(unlocked)
		table.sort(sorted, function(a, b)
			local statsA = PlantData[a]
			local statsB = PlantData[b]
			if not statsA then return false end
			if not statsB then return true end
			return statsA.Cost < statsB.Cost
		end)
		return sorted
	end)
	
	-- Calculate deck size based on unlocked plants
	local deckSize = Computed(scope, function(use)
		local unlocked = use(sortedUnlockedPlants)
		local numPlants = #unlocked
		return UDim2.fromOffset(
			numPlants * (CARD_SIZE.X.Offset + CARD_SPACING) - CARD_SPACING + 20,
			CARD_SIZE.Y.Offset + 20
		)
	end)
	
	return New(scope, "Frame")({
		Name = "CardDeck",
		Position = UDim2.new(0.5, 0, 1, -15),
		AnchorPoint = Vector2.new(0.5, 1),
		Size = deckSize,
		BackgroundColor3 = PvZTheme.Colors.WoodBrown,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		
		[Children] = {
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 14) }),
			New(scope, "UIStroke")({
				Color = PvZTheme.Colors.WoodDark,
				Thickness = 3,
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
			
			-- Reactive plant cards based on unlocked plants
			ForValues(scope, sortedUnlockedPlants, function(use, innerScope, plantType)
				local stats = PlantData[plantType]
				local layoutOrder = if stats then stats.Cost else 999
				
				return PlantCard({
					Scope = innerScope,
					PlantType = plantType,
					SelectedPlant = props.SelectedPlant,
					SunCount = props.SunCount,
					Cooldowns = props.Cooldowns,
					OnSelect = props.OnSelect,
					LayoutOrder = layoutOrder,
				})
			end),
		},
	})
end

return CardDeck
