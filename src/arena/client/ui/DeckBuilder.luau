--!strict
--[[
	DeckBuilder.luau - Deck building UI component
	
	Allows players to:
	- View all unlocked plants in a grid
	- Select up to 6 plants for their deck
	- Save deck to server
	
	Uses PvZ theme for consistent styling.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

local Client = script.Parent.Parent
local PlayerDataClient = require(Client.modules.PlayerDataClient)
local PvZTheme = require(script.Parent.PvZTheme)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local ForValues = Fusion.ForValues
local peek = Fusion.peek

local DeckBuilder = {}

local MAX_DECK_SIZE = 6

-- Plant card in the available plants grid
local function PlantGridCard(scope, props: {
	PlantType: string,
	IsInDeck: any, -- Fusion.Value<boolean>
	OnClick: () -> (),
})local isHovered = Value(scope, false)
	local data = PlantData[props.PlantType]
	local displayName = if data then data.Name else props.PlantType
	
	return New(scope, "TextButton") {
		Size = UDim2.new(0, 80, 0, 100),
		BackgroundColor3 = Computed(scope, function(use)
			if use(props.IsInDeck) then
				return PvZTheme.Colors.GrassGreen
			elseif use(isHovered) then
				return PvZTheme.Colors.WoodLight
			else
				return PvZTheme.Colors.WoodBrown
			end
		end),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		
		[OnEvent "Activated"] = props.OnClick,
		[OnEvent "MouseEnter"] = function()
			isHovered:set(true)
		end,
		[OnEvent "MouseLeave"] = function()
			isHovered:set(false)
		end,
		
		[Children] = {
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
			
			New(scope, "UIStroke") {
				Color = Computed(scope, function(use)
					return if use(props.IsInDeck) 
						then PvZTheme.Colors.LeafGreen 
						else PvZTheme.Colors.WoodDark
				end),
				Thickness = 3,
			},
			
			-- Plant icon placeholder
			New(scope, "TextLabel") {
				Size = UDim2.new(1, 0, 0, 50),
				Position = UDim2.new(0, 0, 0, 5),
				BackgroundTransparency = 1,
				Text = PvZTheme.Icons.Plant,
				TextSize = 36,
				Font = Enum.Font.GothamBold,
				TextColor3 = PvZTheme.Colors.TextWhite,
			},
			
			-- Plant name
			New(scope, "TextLabel") {
				Size = UDim2.new(1, -8, 0, 30),
				Position = UDim2.new(0, 4, 1, -35),
				BackgroundTransparency = 1,
				Text = displayName,
				TextSize = 11,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextColor3 = PvZTheme.Colors.TextWhite,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			},
			
			-- In deck indicator
			Computed(scope, function(use)
				if use(props.IsInDeck) then
					return New(scope, "TextLabel") {
						Size = UDim2.new(0, 24, 0, 24),
						Position = UDim2.new(1, -28, 0, 4),
						BackgroundColor3 = PvZTheme.Colors.GrassGreen,
						Text = "✓",
						TextSize = 16,
						Font = Enum.Font.GothamBold,
						TextColor3 = PvZTheme.Colors.TextWhite,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(1, 0),
							},
						},
					}
				else
					return nil
				end
			end),
		},
	}
end

-- Deck slot (shows plant or empty slot)
local function DeckSlot(scope, props: {
	Index: number,
	PlantType: Fusion.Computed<string?>,
	OnRemove: () -> (),
})
	local isHovered = Value(scope, false)
	
	return New(scope, "TextButton") {
		Size = UDim2.new(0, 70, 0, 90),
		BackgroundColor3 = Computed(scope, function(use)
			if use(props.PlantType) then
				return PvZTheme.Colors.GrassGreen
			else
				return PvZTheme.Colors.WoodDark
			end
		end),
		BackgroundTransparency = Computed(scope, function(use)
			return if use(props.PlantType) then 0 else 0.5
		end),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		
		[OnEvent "Activated"] = props.OnRemove,
		[OnEvent "MouseEnter"] = function()
			isHovered:set(true)
		end,
		[OnEvent "MouseLeave"] = function()
			isHovered:set(false)
		end,
		
		[Children] = {
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
			
			New(scope, "UIStroke") {
				Color = PvZTheme.Colors.WoodBrown,
				Thickness = 2,
			},
			
			-- Slot number
			New(scope, "TextLabel") {
				Size = UDim2.new(0, 20, 0, 20),
				Position = UDim2.new(0, 4, 0, 4),
				BackgroundColor3 = PvZTheme.Colors.WoodDark,
				Text = tostring(props.Index),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextColor3 = PvZTheme.Colors.TextWhite,
				
				[Children] = {
					New(scope, "UICorner") {
						CornerRadius = UDim.new(1, 0),
					},
				},
			},
			
			-- Plant icon or empty
			New(scope, "TextLabel") {
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.new(0, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = Computed(scope, function(use)
					local plant = use(props.PlantType)
					return if plant then PvZTheme.Icons.Plant else "+"
				end),
				TextSize = 28,
				Font = Enum.Font.GothamBold,
				TextColor3 = Computed(scope, function(use)
					return if use(props.PlantType) 
						then PvZTheme.Colors.TextWhite 
						else PvZTheme.Colors.WoodLight
				end),
			},
			
			-- Plant name
			New(scope, "TextLabel") {
				Size = UDim2.new(1, -4, 0, 20),
				Position = UDim2.new(0, 2, 1, -22),
				BackgroundTransparency = 1,
				Text = Computed(scope, function(use)
					local plant = use(props.PlantType)
					if plant then
						local data = PlantData[plant]
						return if data then data.Name else plant
					end
					return "Empty"
				end),
				TextSize = 9,
				TextScaled = true,
				Font = Enum.Font.GothamMedium,
				TextColor3 = PvZTheme.Colors.TextWhite,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			},
			
			-- Remove hint on hover
			Computed(scope, function(use)
				if use(isHovered) and use(props.PlantType) then
					return New(scope, "TextLabel") {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundColor3 = PvZTheme.Colors.HealthRed,
						BackgroundTransparency = 0.3,
						Text = "✕",
						TextSize = 24,
						Font = Enum.Font.GothamBold,
						TextColor3 = PvZTheme.Colors.TextWhite,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0, 8),
							},
						},
					}
				else
					return nil
				end
			end),
		},
	}
end

-- Create the DeckBuilder UI
function DeckBuilder.Create(scope, props: {
	Visible: any, -- Fusion.Value<boolean>
	OnClose: () -> (),
})
	-- Local deck state (editing)
	local editingDeck = Value(scope, PlayerDataClient.GetDeck())
	
	-- Sync with server deck when visibility changes
	local _ = Computed(scope, function(use)
		if use(props.Visible) then
			editingDeck:set(PlayerDataClient.GetDeck())
		end
		return nil
	end)
	
	-- Computed: is deck dirty (modified)?
	local isDirty = Computed(scope, function(use)
		local current = use(editingDeck)
		local saved = use(PlayerDataClient.GetDeckValue())
		
		if #current ~= #saved then return true end
		for i, plant in current do
			if saved[i] ~= plant then return true end
		end
		return false
	end)
	
	-- Add plant to deck
	local function addToDeck(plantType: string)
		local current = peek(editingDeck)
		if #current >= MAX_DECK_SIZE then
			Logger.Debug("DeckBuilder", "Deck is full")
			return
		end
		if table.find(current, plantType) then
			Logger.Debug("DeckBuilder", `{plantType} already in deck`)
			return
		end
		
		local newDeck = table.clone(current)
		table.insert(newDeck, plantType)
		editingDeck:set(newDeck)
	end
	
	-- Remove plant from deck
	local function removeFromDeck(index: number)
		local current = peek(editingDeck)
		if index < 1 or index > #current then return end
		
		local newDeck = table.clone(current)
		table.remove(newDeck, index)
		editingDeck:set(newDeck)
	end
	
	-- Toggle plant in/out of deck
	local function togglePlant(plantType: string)
		local current = peek(editingDeck)
		local idx = table.find(current, plantType)
		
		if idx then
			removeFromDeck(idx)
		else
			addToDeck(plantType)
		end
	end
	
	-- Save deck to server
	local function saveDeck()
		local deck = peek(editingDeck)
		if #deck < 1 then
			Logger.Warn("DeckBuilder", "Deck must have at least 1 plant")
			return
		end
		
		PlayerDataClient.SetDeckLocal(deck)
		PlayerDataClient.RequestSaveDeck(deck)
		props.OnClose()
	end
	
	-- Main container
	return New(scope, "Frame") {
		Name = "DeckBuilder",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = PvZTheme.Colors.OverlayDark,
		BackgroundTransparency = 0.4,
		Visible = props.Visible,
		ZIndex = 100,
		
		[Children] = {
			-- Main panel
			PvZTheme.WoodPanel(scope, {
				Size = UDim2.new(0, 600, 0, 500),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				
				[Children] = {
					-- Header
					PvZTheme.Banner(scope, {
						Size = UDim2.new(1, 20, 0, 50),
						Position = UDim2.new(0.5, 0, 0, -25),
						AnchorPoint = Vector2.new(0.5, 0),
						Text = "🌱 DECK BUILDER",
						TextSize = 24,
					}),
					
					-- Close button
					New(scope, "TextButton") {
						Name = "CloseButton",
						Size = UDim2.new(0, 36, 0, 36),
						Position = UDim2.new(1, -8, 0, 8),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundColor3 = PvZTheme.Colors.HealthRed,
						Text = "X",
						TextColor3 = PvZTheme.Colors.TextWhite,
						TextSize = 20,
						Font = Enum.Font.GothamBold,
						AutoButtonColor = true,
						
						[OnEvent "Activated"] = props.OnClose,
						
						[Children] = {
							New(scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
							New(scope, "UIStroke") {
								Color = Color3.fromRGB(180, 40, 40),
								Thickness = 2,
							},
						},
					},
					
					-- Deck slots section
					New(scope, "Frame") {
						Name = "DeckSection",
						Size = UDim2.new(1, -20, 0, 120),
						Position = UDim2.new(0, 10, 0, 45),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						BackgroundTransparency = 0.5,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0, 8),
							},
							
							-- Label
							New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 0, 25),
								BackgroundTransparency = 1,
								Text = Computed(scope, function(use)
									local count = #use(editingDeck)
									return `Your Deck ({count}/{MAX_DECK_SIZE})`
								end),
								TextSize = 16,
								Font = Enum.Font.GothamBold,
								TextColor3 = PvZTheme.Colors.TextGold,
								TextXAlignment = Enum.TextXAlignment.Center,
							},
							
							-- Deck slots container
							New(scope, "Frame") {
								Name = "Slots",
								Size = UDim2.new(1, -20, 0, 90),
								Position = UDim2.new(0, 10, 0, 25),
								BackgroundTransparency = 1,
								
								[Children] = {
									New(scope, "UIListLayout") {
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										Padding = UDim.new(0, 10),
									},
									
									-- Generate 6 deck slots
									ForValues(scope, {1, 2, 3, 4, 5, 6}, function(use, slotScope, index)
										return DeckSlot(slotScope, {
											Index = index,
											PlantType = Computed(slotScope, function(use2)
												local deck = use2(editingDeck)
												return deck[index]
											end),
											OnRemove = function()
												removeFromDeck(index)
											end,
										})
									end),
								},
							},
						},
					},
					
					-- Available plants section
					New(scope, "Frame") {
						Name = "PlantsSection",
						Size = UDim2.new(1, -20, 0, 260),
						Position = UDim2.new(0, 10, 0, 175),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						BackgroundTransparency = 0.5,
						ClipsDescendants = true,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0, 8),
							},
							
							-- Label
							New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 0, 25),
								BackgroundTransparency = 1,
								Text = Computed(scope, function(use)
									local unlocked = use(PlayerDataClient.GetUnlockedPlantsValue())
									return `Available Plants ({#unlocked})`
								end),
								TextSize = 16,
								Font = Enum.Font.GothamBold,
								TextColor3 = PvZTheme.Colors.TextGold,
								TextXAlignment = Enum.TextXAlignment.Center,
							},
							
							-- Scrolling plants grid
							New(scope, "ScrollingFrame") {
								Name = "PlantsGrid",
								Size = UDim2.new(1, -10, 1, -30),
								Position = UDim2.new(0, 5, 0, 25),
								BackgroundTransparency = 1,
								ScrollBarThickness = 6,
								ScrollBarImageColor3 = PvZTheme.Colors.WoodLight,
								CanvasSize = UDim2.new(0, 0, 0, 0),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								
								[Children] = {
									New(scope, "UIGridLayout") {
										CellSize = UDim2.new(0, 80, 0, 100),
										CellPadding = UDim2.new(0, 10, 0, 10),
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										SortOrder = Enum.SortOrder.LayoutOrder,
									},
									
									-- Generate plant cards for unlocked plants
									ForValues(scope, PlayerDataClient.GetUnlockedPlantsValue(), function(use, cardScope, plantType)
										local isInDeck = Computed(cardScope, function(use2)
											local deck = use2(editingDeck)
											return table.find(deck, plantType) ~= nil
										end)
										
										return PlantGridCard(cardScope, {
											PlantType = plantType,
											IsInDeck = isInDeck,
											OnClick = function()
												togglePlant(plantType)
											end,
										})
									end),
								},
							},
						},
					},
					
					-- Bottom buttons
					New(scope, "Frame") {
						Name = "Buttons",
						Size = UDim2.new(1, -20, 0, 50),
						Position = UDim2.new(0, 10, 1, -60),
						BackgroundTransparency = 1,
						
						[Children] = {
							New(scope, "UIListLayout") {
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 20),
							},
							
							-- Cancel button
							PvZTheme.WoodButton(scope, {
								Size = UDim2.new(0, 120, 0, 45),
								Text = "Cancel",
								OnClick = props.OnClose,
							}),
							
							-- Save button
							PvZTheme.WoodButton(scope, {
								Size = UDim2.new(0, 120, 0, 45),
								Text = Computed(scope, function(use)
									return if use(isDirty) then "💾 Save" else "✓ Saved"
								end),
								BackgroundColor = Computed(scope, function(use)
									if #use(editingDeck) < 1 then
										return PvZTheme.Colors.Disabled
									elseif use(isDirty) then
										return PvZTheme.Colors.GrassGreen
									else
										return PvZTheme.Colors.WoodBrown
									end
								end),
								OnClick = saveDeck,
							}),
						},
					},
				},
			}),
		},
	}
end

return DeckBuilder
