--!strict
--[[
	CardDeck.luau - Arena Plant Selection Deck
	
	Uses EXACT same style as LobbyHUD:
	- CasualTheme.DeckBar for container (identical to Lobby)
	- CasualTheme.UnitCard for each plant card (identical to Lobby)
	- Added: cooldown overlay, shovel button
	
	Design: Same deck bar as Lobby for visual consistency
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)
local CasualTheme = require(Shared.ui.CasualTheme)

local Client = script.Parent.Parent
local PlayerDataClient = require(Client.modules.PlayerDataClient)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring

-- Theme (same as Lobby)
local Colors = CasualTheme.Colors
local Sizing = CasualTheme.Sizing
local Fonts = CasualTheme.Fonts
local DeckBar = CasualTheme.DeckBar
local UnitCard = CasualTheme.UnitCard

export type CardDeckProps = {
	Scope: any,
	SelectedPlant: any, -- Value<string?>
	SunCount: any, -- Value<number>
	Cooldowns: any, -- Value<{[string]: number}>
	ShovelMode: any, -- Value<boolean>
	PlayerMutations: any?, -- Value<{[string]: {string}}>?
	OnSelect: (plantType: string) -> (),
	OnShovelToggle: () -> (),
}

--[[
	ShovelButton - Styled like UnitCard with juicy animation
]]
local function ShovelButton(scope: any, props: {
	ShovelMode: any,
	OnToggle: () -> (),
})
	local isHovered = Value(scope, false)
	local isPressed = Value(scope, false)
	
	-- Juicy bounce animation (same as UnitCard)
	local targetScale = Computed(scope, function(use)
		local active = use(props.ShovelMode)
		local pressed = use(isPressed)
		local hovered = use(isHovered)
		
		if pressed then return 0.92 end
		if active then return 1.08 end
		if hovered then return 1.04 end
		return 1
	end)
	
	local springScale = Spring(scope, targetScale, 35, 0.7)
	
	return New(scope, "Frame") {
		Name = "ShovelButton",
		Size = Sizing.UnitCardSize, -- Same size as UnitCard
		BackgroundTransparency = 1,
		LayoutOrder = 99999,
		
		[Children] = {
			-- Scale container for bounce
			New(scope, "Frame") {
				Size = UDim2.new(1, 0, 1, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundTransparency = 1,
				
				[Children] = {
					New(scope, "UIScale") { Scale = springScale },
					
					-- Main body (brown squircle)
					New(scope, "Frame") {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundColor3 = Computed(scope, function(use)
							return if use(props.ShovelMode) 
								then Colors.CardRed
								else Color3.fromRGB(139, 90, 43) -- Brown
						end),
						
						[Children] = {
							New(scope, "UICorner") { CornerRadius = Sizing.SquircleMedium },
							
							-- Thick stroke (selected = yellow)
							New(scope, "UIStroke") {
								Color = Computed(scope, function(use)
									return if use(props.ShovelMode)
										then Colors.StrokeSelected
										else Colors.StrokeDark
								end),
								Thickness = Computed(scope, function(use)
									return if use(props.ShovelMode) 
										then Sizing.StrokeHeavy 
										else Sizing.StrokeThick
								end),
							},
							
							-- Glossy gradient (same as UnitCard)
							New(scope, "UIGradient") {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
									ColorSequenceKeypoint.new(0.35, Color3.fromRGB(245, 245, 245)),
									ColorSequenceKeypoint.new(0.6, Color3.fromRGB(220, 220, 220)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
								}),
								Rotation = 90,
							},
							
							-- Shovel icon
							New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 0, 50),
								Position = UDim2.new(0, 0, 0, 8),
								BackgroundTransparency = 1,
								Text = "🪓",
								TextSize = 36,
								TextColor3 = Colors.TextWhite,
								
								[Children] = {
									New(scope, "UIStroke") {
										Color = Colors.TextShadow,
										Thickness = 1,
										Transparency = 0.5,
									},
								},
							},
							
							-- Cost badge position (same as UnitCard)
							New(scope, "Frame") {
								Name = "LabelBadge",
								Size = Sizing.CostBadgeSize,
								Position = UDim2.new(0, -4, 1, -6),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = Computed(scope, function(use)
									return if use(props.ShovelMode)
										then Colors.CardRed
										else Colors.CostBadge
								end),
								ZIndex = 5,
								
								[Children] = {
									New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
									New(scope, "UIStroke") {
										Color = Colors.StrokeDark,
										Thickness = Sizing.StrokeNormal,
									},
									New(scope, "TextLabel") {
										Size = UDim2.new(1, 0, 1, 0),
										BackgroundTransparency = 1,
										Text = Computed(scope, function(use)
											return if use(props.ShovelMode) then "❌" else "DIG"
										end),
										TextColor3 = Colors.TextWhite,
										TextSize = 11,
										Font = Fonts.Numbers,
										
										[Children] = {
											New(scope, "UIStroke") {
												Color = Colors.TextShadow,
												Thickness = 1,
											},
										},
									},
								},
							},
							
							-- Click detector
							New(scope, "TextButton") {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = "",
								ZIndex = 10,
								
								[OnEvent "Activated"] = props.OnToggle,
								[OnEvent "MouseEnter"] = function() isHovered:set(true) end,
								[OnEvent "MouseLeave"] = function() 
									isHovered:set(false) 
									isPressed:set(false)
								end,
								[OnEvent "MouseButton1Down"] = function() isPressed:set(true) end,
								[OnEvent "MouseButton1Up"] = function() isPressed:set(false) end,
							},
						},
					},
				},
			},
		},
	}
end

--[[
	CardDeck - Uses DeckBar and UnitCard from CasualTheme (SAME as Lobby)
]]
local function CardDeck(props: CardDeckProps)
	local scope = props.Scope
	
	-- Get player's deck sorted by cost
	local sortedDeck = Computed(scope, function(use)
		local deck = use(PlayerDataClient.GetDeckValue())
		return Sift.Array.sort(deck, function(a, b)
			local statsA = PlantData[a]
			local statsB = PlantData[b]
			if not statsA then return false end
			if not statsB then return true end
			return statsA.Cost < statsB.Cost
		end)
	end)
	
	-- Build cards exactly like LobbyHUD does
	local cards = {}
	
	for slotIndex = 1, 6 do
		-- Plant type for this slot (reactive)
		local plantType = Computed(scope, function(use)
			local deck = use(sortedDeck)
			return deck[slotIndex]
		end)
		
		-- Cost for this slot (reactive)
		local cost = Computed(scope, function(use)
			local plant = use(plantType)
			if plant then
				local stats = PlantData[plant]
				return stats and stats.Cost or 0
			end
			return 0
		end)
		
		-- Is selected? (compare plantType to SelectedPlant)
		local isSelected = Computed(scope, function(use)
			local plant = use(plantType)
			local selected = use(props.SelectedPlant)
			return plant and selected == plant
		end)
		
		-- Cooldown tracking for this slot
		local cooldownValue = Value(scope, 0)
		local slotDestroyed = false
		
		task.spawn(function()
			while not slotDestroyed do
				local plant = Fusion.peek(plantType)
				if plant then
					local cooldowns = Fusion.peek(props.Cooldowns)
					local endTime = cooldowns[plant]
					if endTime then
						cooldownValue:set(math.max(0, endTime - tick()))
					else
						cooldownValue:set(0)
					end
				else
					cooldownValue:set(0)
				end
				task.wait(0.1)
			end
		end)
		
		table.insert(scope, function()
			slotDestroyed = true
		end)
		
		local isOnCooldown = Computed(scope, function(use)
			return use(cooldownValue) > 0
		end)
		
		-- Can afford?
		local canAfford = Computed(scope, function(use)
			local c = use(cost)
			local sun = use(props.SunCount)
			return sun >= c
		end)
		
		-- Disabled = on cooldown OR can't afford
		local isDisabled = Computed(scope, function(use)
			return use(isOnCooldown) or not use(canAfford)
		end)
		
		-- Wrap UnitCard in a container that adds cooldown overlay
		local cardContainer = New(scope, "Frame") {
			Name = `CardSlot_{slotIndex}`,
			Size = Sizing.UnitCardSize,
			BackgroundTransparency = 1,
			LayoutOrder = slotIndex,
			
			[Children] = {
				-- The UnitCard (EXACT same as Lobby)
				UnitCard(scope, {
					PlantType = plantType,
					Cost = cost,
					SlotIndex = slotIndex,
					IsSelected = isSelected,
					IsDisabled = isDisabled,
					Hotkey = tostring(slotIndex),
					OnClick = function()
						local plant = Fusion.peek(plantType)
						if not plant then return end
						
						-- Don't select if on cooldown
						if Fusion.peek(isOnCooldown) then
							Logger.Debug("CardDeck", `{plant} is on cooldown`)
							return
						end
						
						-- Don't select if can't afford
						if not Fusion.peek(canAfford) then
							Logger.Debug("CardDeck", `Cannot afford {plant}`)
							return
						end
						
						props.OnSelect(plant)
					end,
				}),
				
				-- Cooldown overlay (Arena-specific, on top)
				Computed(scope, function(use)
					local cd = use(cooldownValue)
					if cd > 0 then
						return New(scope, "Frame") {
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundColor3 = Color3.fromRGB(0, 0, 0),
							BackgroundTransparency = 0.5,
							ZIndex = 20,
							
							[Children] = {
								New(scope, "UICorner") { CornerRadius = Sizing.SquircleMedium },
								New(scope, "TextLabel") {
									Size = UDim2.new(1, 0, 1, 0),
									BackgroundTransparency = 1,
									Text = string.format("%.1f", cd),
									TextColor3 = Colors.TextWhite,
									TextSize = 22,
									Font = Fonts.Numbers,
									
									[Children] = {
										New(scope, "UIStroke") {
											Color = Colors.StrokeDark,
											Thickness = 2,
										},
									},
								},
							},
						}
					end
					return nil
				end),
			},
		}
		
		table.insert(cards, cardContainer)
	end
	
	-- Add shovel button at the end
	table.insert(cards, ShovelButton(scope, {
		ShovelMode = props.ShovelMode,
		OnToggle = props.OnShovelToggle,
	}))
	
	-- Use DeckBar from CasualTheme (EXACT same as Lobby)
	return DeckBar(scope, {
		Children = cards,
	})
end

return CardDeck
