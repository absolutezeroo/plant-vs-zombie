--!strict
--[[
	CardDeck.luau - Plant selection card deck UI component
	
	Displays 3 plant cards at bottom of screen.
	- Tap to select plant
	- Shows cost, cooldown overlay
	- Highlights selected card
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value

-- Card configuration
local CARD_SIZE = UDim2.fromOffset(80, 100)
local CARD_SPACING = 10
local DECK_PLANTS = { "Sunflower", "Peashooter", "WallNut" } -- MVP deck

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
	
	-- Card background color
	local backgroundColor = Computed(scope, function(use)
		if use(isOnCooldown) then
			return Color3.fromRGB(80, 80, 80) -- Grey when on cooldown
		elseif not use(canAfford) then
			return Color3.fromRGB(120, 60, 60) -- Red when can't afford
		elseif use(isSelected) then
			return Color3.fromRGB(100, 180, 100) -- Green when selected
		else
			return Color3.fromRGB(60, 120, 60) -- Default green
		end
	end)
	
	-- Border color
	local borderColor = Computed(scope, function(use)
		if use(isSelected) then
			return Color3.fromRGB(255, 255, 0) -- Yellow border when selected
		else
			return Color3.fromRGB(40, 80, 40)
		end
	end)
	
	return New(scope, "TextButton")({
		Name = `Card_{plantType}`,
		Size = CARD_SIZE,
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		
		[OnEvent("Activated")] = function()
			props.OnSelect(plantType)
		end,
		
		[Children] = {
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
				Position = UDim2.new(0.5, 0, 0.3, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(50, 50),
				BackgroundColor3 = stats.Category == "Attacker" and Color3.fromRGB(100, 200, 100)
					or stats.Category == "Producer" and Color3.fromRGB(255, 220, 50)
					or stats.Category == "Defender" and Color3.fromRGB(180, 140, 80)
					or Color3.fromRGB(150, 150, 150),
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
			
			-- Cost display
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
						return `☀️ {stats.Cost}`
					end
				end),
				TextColor3 = Computed(scope, function(use)
					if use(canAfford) and not use(isOnCooldown) then
						return Color3.new(1, 1, 1)
					else
						return Color3.fromRGB(255, 150, 150)
					end
				end),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
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
end

local function CardDeck(props: CardDeckProps)
	local scope = props.Scope
	
	local cards = {}
	for _, plantType in DECK_PLANTS do
		table.insert(cards, PlantCard({
			Scope = scope,
			PlantType = plantType,
			SelectedPlant = props.SelectedPlant,
			SunCount = props.SunCount,
			Cooldowns = props.Cooldowns,
			OnSelect = props.OnSelect,
		}))
	end
	
	return New(scope, "Frame")({
		Name = "CardDeck",
		Position = UDim2.new(0.5, 0, 1, -20),
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(
			#DECK_PLANTS * (CARD_SIZE.X.Offset + CARD_SPACING) - CARD_SPACING + 20,
			CARD_SIZE.Y.Offset + 20
		),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		
		[Children] = {
			New(scope, "UICorner")({ CornerRadius = UDim.new(0, 12) }),
			New(scope, "UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, CARD_SPACING),
			}),
			New(scope, "UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),
			table.unpack(cards),
		},
	})
end

return CardDeck
