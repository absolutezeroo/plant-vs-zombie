--!strict
--[[
    DeckBuilderView.luau - Deck building interface
    
    Allows players to select 1-6 plants for their deck.
    Only shows unlocked plants, with filtering and search.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local ProgressionData = require(Shared.data.ProgressionData)

local PvZTheme = require(ReplicatedStorage.Shared.ui.PvZTheme)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local peek = Fusion.peek

export type DeckBuilderViewProps = {
    SelectedDeck: any,   -- Value<{string}>
    PlayerData: any,     -- Value<PlayerData?>
    OnBack: () -> (),
    OnPlay: () -> (),
    OnSaveDeck: (deck: {string}) -> (),
}

-- Plant card in deck builder
local function PlantCard(scope: any, props: {
    PlantType: string,
    PlantStats: any, -- PlantData.PlantStats
    IsInDeck: any,    -- Computed<boolean>
    IsLocked: boolean,
    OnToggle: () -> (),
}): any
    local isHovered = Value(scope, false)
    
    return New(scope, "TextButton") {
        Size = UDim2.new(0, 100, 0, 120),
        BackgroundColor3 = Computed(scope, function(use)
            if props.IsLocked then
                return PvZTheme.Colors.Disabled
            elseif use(props.IsInDeck) then
                return PvZTheme.Colors.LeafGreen
            elseif use(isHovered) then
                return PvZTheme.Colors.WoodLight
            else
                return PvZTheme.Colors.WoodBrown
            end
        end),
        AutoButtonColor = false,
        Text = "",
        
        [OnEvent "Activated"] = function()
            if not props.IsLocked then
                props.OnToggle()
            end
        end,
        [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
        [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 10),
            },
            
            New(scope, "UIStroke") {
                Color = Computed(scope, function(use)
                    return if use(props.IsInDeck) then PvZTheme.Colors.SunYellow else PvZTheme.Colors.WoodDark
                end),
                Thickness = 2,
            },
            
            -- Lock icon if locked
            props.IsLocked and New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 40),
                Position = UDim2.new(0, 0, 0, 10),
                BackgroundTransparency = 1,
                Text = "🔒",
                TextSize = 30,
            } or New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 40),
                Position = UDim2.new(0, 0, 0, 10),
                BackgroundTransparency = 1,
                Text = "🌱",
                TextSize = 30,
            },
            
            -- Plant name
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -6, 0, 30),
                Position = UDim2.new(0, 3, 0, 50),
                BackgroundTransparency = 1,
                Text = props.PlantType,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextColor3 = PvZTheme.Colors.TextWhite,
                TextWrapped = true,
                TextTruncate = Enum.TextTruncate.AtEnd,
            },
            
            -- Cost
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 20),
                Position = UDim2.new(0, 0, 0, 80),
                BackgroundTransparency = 1,
                Text = `☀️{props.PlantStats.Cost}`,
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                TextColor3 = PvZTheme.Colors.SunYellow,
            },
            
            -- Checkmark if in deck
            Computed(scope, function(use)
                if use(props.IsInDeck) then
                    return New(scope, "TextLabel") {
                        Size = UDim2.new(0, 25, 0, 25),
                        Position = UDim2.new(1, -5, 0, 5),
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundColor3 = PvZTheme.Colors.Success,
                        Text = "✓",
                        TextSize = 16,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = PvZTheme.Colors.TextWhite,
                        
                        [Children] = {
                            New(scope, "UICorner") {
                                CornerRadius = UDim.new(0.5, 0),
                            },
                        },
                    }
                end
                return nil
            end),
        },
    }
end

-- Deck slot display
local function DeckSlot(scope: any, props: {
    Index: number,
    PlantType: string?,
    OnRemove: () -> (),
}): any
    local isHovered = Value(scope, false)
    
    return New(scope, "TextButton") {
        Size = UDim2.new(0, 80, 0, 80),
        BackgroundColor3 = Computed(scope, function(use)
            if props.PlantType then
                return if use(isHovered) then PvZTheme.Colors.Danger else PvZTheme.Colors.LeafGreen
            end
            return PvZTheme.Colors.WoodDark
        end),
        AutoButtonColor = false,
        Text = "",
        
        [OnEvent "Activated"] = function()
            if props.PlantType then
                props.OnRemove()
            end
        end,
        [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
        [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 10),
            },
            
            New(scope, "UIStroke") {
                Color = PvZTheme.Colors.WoodDark,
                Thickness = 2,
            },
            
            -- Slot number
            New(scope, "TextLabel") {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0, 5, 0, 5),
                BackgroundTransparency = 1,
                Text = tostring(props.Index),
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextColor3 = PvZTheme.Colors.TextWhite,
                TextTransparency = 0.5,
            },
            
            -- Plant name or empty
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -10, 1, -25),
                Position = UDim2.new(0, 5, 0, 20),
                BackgroundTransparency = 1,
                Text = props.PlantType or "+",
                TextSize = if props.PlantType then 11 else 30,
                Font = Enum.Font.GothamBold,
                TextColor3 = PvZTheme.Colors.TextWhite,
                TextWrapped = true,
            },
            
            -- Remove hint on hover
            Computed(scope, function(use)
                if props.PlantType and use(isHovered) then
                    return New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 0, 20),
                        Position = UDim2.new(0, 0, 1, -20),
                        BackgroundTransparency = 1,
                        Text = "Remove",
                        TextSize = 10,
                        Font = Enum.Font.Gotham,
                        TextColor3 = PvZTheme.Colors.TextWhite,
                    }
                end
                return nil
            end),
        },
    }
end

return function(scope: any, props: DeckBuilderViewProps)
    local selectedFilter = Value(scope, "All") -- "All", "Attacker", "Producer", "Defender", "Special"
    local localDeck = Value(scope, table.clone(peek(props.SelectedDeck) or {}))
    
    -- Get unlocked plant set
    local unlockedSet = Computed(scope, function(use)
        local data = use(props.PlayerData)
        local set: {[string]: boolean} = {}
        if data and data.UnlockedPlants then
            for _, plantType in ipairs(data.UnlockedPlants) do
                set[plantType] = true
            end
        end
        return set
    end)
    
    -- Get sorted plants by unlock order
    local sortedPlants = (function()
        local plants = {}
        for plantType, info in pairs(ProgressionData.PlantUnlocks) do
            local stats = PlantData[plantType]
            if stats then
                table.insert(plants, {
                    PlantType = plantType,
                    Order = info.Order,
                    Stats = stats,
                })
            end
        end
        table.sort(plants, function(a, b)
            return a.Order < b.Order
        end)
        return plants
    end)()
    
    -- Filtered plants
    local filteredPlants = Computed(scope, function(use)
        local filter = use(selectedFilter)
        local result = {}
        for _, plant in ipairs(sortedPlants) do
            if filter == "All" or plant.Stats.Category == filter then
                table.insert(result, plant)
            end
        end
        return result
    end)
    
    -- Toggle plant in/out of deck
    local function togglePlant(plantType: string)
        local deck = table.clone(peek(localDeck))
        local idx = table.find(deck, plantType)
        if idx then
            table.remove(deck, idx)
        else
            if #deck < 6 then
                table.insert(deck, plantType)
            end
        end
        localDeck:set(deck)
        props.SelectedDeck:set(table.clone(deck))
    end
    
    -- Remove plant from deck by index
    local function removePlant(index: number)
        local deck = table.clone(peek(localDeck))
        if deck[index] then
            table.remove(deck, index)
            localDeck:set(deck)
            props.SelectedDeck:set(table.clone(deck))
        end
    end
    
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = PvZTheme.Colors.GrassGreen,
        
        [Children] = {
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 180, 50)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 120, 30)),
                }),
                Rotation = 90,
            },
            
            -- Back button
            PvZTheme.BackButton(scope, props.OnBack),
            
            -- Header
            PvZTheme.Header(scope, "🌱 Build Your Deck"),
            
            -- Deck slots (top)
            New(scope, "Frame") {
                Size = UDim2.new(0.95, 0, 0, 100),
                Position = UDim2.new(0.025, 0, 0, 80),
                BackgroundColor3 = PvZTheme.Colors.WoodBrown,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 12),
                    },
                    
                    New(scope, "UIPadding") {
                        PaddingTop = UDim.new(0, 10),
                        PaddingLeft = UDim.new(0, 10),
                    },
                    
                    -- Deck count
                    New(scope, "TextLabel") {
                        Size = UDim2.new(0, 80, 0, 25),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            return `Deck: {#use(localDeck)}/6`
                        end),
                        TextSize = 14,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = PvZTheme.Colors.TextWhite,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    
                    -- Deck slots container
                    New(scope, "Frame") {
                        Size = UDim2.new(1, -20, 0, 80),
                        Position = UDim2.new(0, 0, 0, 5),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                Padding = UDim.new(0, 8),
                            },
                            
                            -- Generate 6 slots
                            Computed(scope, function(use)
                                local deck = use(localDeck)
                                local slots = {}
                                for i = 1, 6 do
                                    table.insert(slots, DeckSlot(scope, {
                                        Index = i,
                                        PlantType = deck[i],
                                        OnRemove = function()
                                            removePlant(i)
                                        end,
                                    }))
                                end
                                return New(scope, "Frame") {
                                    Size = UDim2.new(1, 0, 1, 0),
                                    BackgroundTransparency = 1,
                                    [Children] = {
                                        New(scope, "UIListLayout") {
                                            FillDirection = Enum.FillDirection.Horizontal,
                                            HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                            Padding = UDim.new(0, 8),
                                        },
                                        table.unpack(slots),
                                    },
                                }
                            end),
                        },
                    },
                },
            },
            
            -- Category filter buttons
            New(scope, "Frame") {
                Size = UDim2.new(0.95, 0, 0, 35),
                Position = UDim2.new(0.025, 0, 0, 190),
                BackgroundTransparency = 1,
                
                [Children] = {
                    New(scope, "UIListLayout") {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        Padding = UDim.new(0, 8),
                    },
                    
                    table.unpack((function()
                        local filters = {"All", "Attacker", "Producer", "Defender", "Special"}
                        local buttons = {}
                        for _, filter in filters do
                            local isActive = Computed(scope, function(use)
                                return use(selectedFilter) == filter
                            end)
                            table.insert(buttons, New(scope, "TextButton") {
                                Size = UDim2.new(0, 85, 0, 30),
                                BackgroundColor3 = Computed(scope, function(use)
                                    return if use(isActive) then PvZTheme.Colors.SunYellow else PvZTheme.Colors.WoodBrown
                                end),
                                Text = filter,
                                TextSize = 12,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = Computed(scope, function(use)
                                    return if use(isActive) then PvZTheme.Colors.TextDark else PvZTheme.Colors.TextWhite
                                end),
                                
                                [OnEvent "Activated"] = function()
                                    selectedFilter:set(filter)
                                end,
                                
                                [Children] = {
                                    New(scope, "UICorner") {
                                        CornerRadius = UDim.new(0, 6),
                                    },
                                },
                            })
                        end
                        return buttons
                    end)()),
                },
            },
            
            -- Plants grid (scrolling)
            New(scope, "ScrollingFrame") {
                Size = UDim2.new(0.95, 0, 0.42, 0),
                Position = UDim2.new(0.025, 0, 0.32, 0),
                BackgroundColor3 = PvZTheme.Colors.WoodLight,
                BackgroundTransparency = 0.3,
                ScrollBarThickness = 8,
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 10),
                    },
                    
                    New(scope, "UIPadding") {
                        PaddingTop = UDim.new(0, 10),
                        PaddingBottom = UDim.new(0, 10),
                        PaddingLeft = UDim.new(0, 10),
                        PaddingRight = UDim.new(0, 10),
                    },
                    
                    New(scope, "UIGridLayout") {
                        CellSize = UDim2.new(0, 100, 0, 120),
                        CellPadding = UDim2.new(0, 10, 0, 10),
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    },
                    
                    -- Generate plant cards
                    Computed(scope, function(use)
                        local plants = use(filteredPlants)
                        local unlocked = use(unlockedSet)
                        local deck = use(localDeck)
                        
                        local cards = {}
                        for _, plant in ipairs(plants) do
                            local isLocked = not unlocked[plant.PlantType]
                            local isInDeck = Computed(scope, function(use2)
                                return table.find(use2(localDeck), plant.PlantType) ~= nil
                            end)
                            
                            table.insert(cards, PlantCard(scope, {
                                PlantType = plant.PlantType,
                                PlantStats = plant.Stats,
                                IsInDeck = isInDeck,
                                IsLocked = isLocked,
                                OnToggle = function()
                                    togglePlant(plant.PlantType)
                                end,
                            }))
                        end
                        
                        return New(scope, "Frame") {
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            BackgroundTransparency = 1,
                            [Children] = {
                                New(scope, "UIGridLayout") {
                                    CellSize = UDim2.new(0, 100, 0, 120),
                                    CellPadding = UDim2.new(0, 10, 0, 10),
                                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                    SortOrder = Enum.SortOrder.LayoutOrder,
                                },
                                table.unpack(cards),
                            },
                        }
                    end),
                },
            },
            
            -- Play button
            New(scope, "TextButton") {
                Size = UDim2.new(0, 280, 0, 65),
                Position = UDim2.new(0.5, 0, 0.92, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Computed(scope, function(use)
                    return if #use(localDeck) > 0 then PvZTheme.Colors.SunYellow else PvZTheme.Colors.Disabled
                end),
                Text = "🎮 START BATTLE!",
                TextSize = 26,
                Font = Enum.Font.GothamBlack,
                TextColor3 = PvZTheme.Colors.TextDark,
                
                [OnEvent "Activated"] = function()
                    local deck = peek(localDeck)
                    if #deck > 0 then
                        props.OnSaveDeck(deck)
                        props.OnPlay()
                    end
                end,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 14),
                    },
                    New(scope, "UIStroke") {
                        Color = PvZTheme.Colors.WoodDark,
                        Thickness = 4,
                    },
                },
            },
        },
    }
end
