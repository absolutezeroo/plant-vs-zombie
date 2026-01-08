--!strict
--[[
    ShopView.luau - Plant shop interface
    
    Displays all plants with their unlock status and purchase price.
    Players can buy plants with Coins.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionData = require(Shared.data.ProgressionData)
local PlantData = require(Shared.data.PlantData)

local PvZTheme = require(ReplicatedStorage.Shared.ui.PvZTheme)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local peek = Fusion.peek

export type ShopViewProps = {
    PlayerData: any, -- Value<PlayerData?>
    OnBack: () -> (),
    OnPurchase: (plantType: string) -> (),
}

-- Get sorted plant list by Order
local function getSortedPlants(): {{PlantType: string, Info: ProgressionData.PlantUnlockInfo}}
    local plants = {}
    for plantType, info in pairs(ProgressionData.PlantUnlocks) do
        table.insert(plants, {PlantType = plantType, Info = info})
    end
    table.sort(plants, function(a, b)
        return a.Info.Order < b.Info.Order
    end)
    return plants
end

-- Single plant card in shop
local function PlantCard(scope: any, props: {
    PlantType: string,
    Cost: number,
    IsUnlocked: any, -- Computed<boolean>
    CanAfford: any,  -- Computed<boolean>
    OnPurchase: () -> (),
}): any
    local isHovered = Value(scope, false)
    local plantStats = PlantData[props.PlantType]
    
    return New(scope, "Frame") {
        Size = UDim2.new(0, 140, 0, 180),
        BackgroundColor3 = Computed(scope, function(use)
            if use(props.IsUnlocked) then
                return PvZTheme.Colors.LeafGreen
            elseif use(isHovered) then
                return PvZTheme.Colors.WoodLight
            else
                return PvZTheme.Colors.WoodBrown
            end
        end),
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 10),
            },
            
            New(scope, "UIStroke") {
                Color = Computed(scope, function(use)
                    return if use(props.IsUnlocked) then PvZTheme.Colors.Success else PvZTheme.Colors.WoodDark
                end),
                Thickness = 2,
            },
            
            -- Plant icon placeholder
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 60),
                Position = UDim2.new(0, 0, 0, 10),
                BackgroundTransparency = 1,
                Text = "🌱",
                TextSize = 40,
                Font = Enum.Font.GothamBold,
            },
            
            -- Plant name
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -10, 0, 30),
                Position = UDim2.new(0, 5, 0, 70),
                BackgroundTransparency = 1,
                Text = props.PlantType,
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                TextColor3 = PvZTheme.Colors.TextWhite,
                TextWrapped = true,
                TextTruncate = Enum.TextTruncate.AtEnd,
            },
            
            -- Category
            plantStats and New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 16),
                Position = UDim2.new(0, 0, 0, 98),
                BackgroundTransparency = 1,
                Text = plantStats.Category or "",
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextColor3 = PvZTheme.Colors.TextWhite,
                TextTransparency = 0.3,
            } or nil,
            
            -- Purchase button / Owned status
            Computed(scope, function(use)
                if use(props.IsUnlocked) then
                    return New(scope, "TextLabel") {
                        Size = UDim2.new(0.9, 0, 0, 35),
                        Position = UDim2.new(0.05, 0, 1, -45),
                        BackgroundColor3 = PvZTheme.Colors.Success,
                        Text = `{PvZTheme.Icons.Check} Owned`,
                        TextSize = 14,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = PvZTheme.Colors.TextWhite,
                        
                        [Children] = {
                            New(scope, "UICorner") {
                                CornerRadius = UDim.new(0, 6),
                            },
                        },
                    }
                else
                    local canAfford = use(props.CanAfford)
                    return New(scope, "TextButton") {
                        Size = UDim2.new(0.9, 0, 0, 35),
                        Position = UDim2.new(0.05, 0, 1, -45),
                        BackgroundColor3 = if canAfford then PvZTheme.Colors.CoinGold else PvZTheme.Colors.Disabled,
                        Text = `{PvZTheme.Icons.Coin} {props.Cost}`,
                        TextSize = 14,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = PvZTheme.Colors.TextDark,
                        
                        [OnEvent "Activated"] = function()
                            if peek(props.CanAfford) then
                                props.OnPurchase()
                            end
                        end,
                        [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                        [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
                        
                        [Children] = {
                            New(scope, "UICorner") {
                                CornerRadius = UDim.new(0, 6),
                            },
                        },
                    }
                end
            end),
        },
    }
end

return function(scope: any, props: ShopViewProps)
    local sortedPlants = getSortedPlants()
    local selectedFilter = Value(scope, "All") -- "All", "Owned", "Locked"
    
    -- Filter plants based on selection
    local filteredPlants = Computed(scope, function(use)
        local filter = use(selectedFilter)
        local playerData = use(props.PlayerData)
        local unlockedSet: {[string]: boolean} = {}
        
        if playerData and playerData.UnlockedPlants then
            for _, plantType in ipairs(playerData.UnlockedPlants) do
                unlockedSet[plantType] = true
            end
        end
        
        local result = {}
        for _, plant in ipairs(sortedPlants) do
            local isUnlocked = unlockedSet[plant.PlantType] == true
            if filter == "All" then
                table.insert(result, plant)
            elseif filter == "Owned" and isUnlocked then
                table.insert(result, plant)
            elseif filter == "Locked" and not isUnlocked then
                table.insert(result, plant)
            end
        end
        return result
    end)
    
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = PvZTheme.Colors.SkyBlue,
        
        [Children] = {
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 150)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 80)),
                }),
                Rotation = 90,
            },
            
            -- Back button
            PvZTheme.BackButton(scope, props.OnBack),
            
            -- Header
            PvZTheme.Header(scope, "🛒 Plant Shop"),
            
            -- Currency display
            New(scope, "Frame") {
                Size = UDim2.new(0, 200, 0, 40),
                Position = UDim2.new(1, -20, 0, 20),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = PvZTheme.Colors.WoodBrown,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 8),
                    },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            local data = use(props.PlayerData)
                            return if data then `💰 {data.Coins}` else "💰 ---"
                        end),
                        TextSize = 22,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = PvZTheme.Colors.CoinGold,
                    },
                },
            },
            
            -- Filter buttons
            New(scope, "Frame") {
                Size = UDim2.new(0.9, 0, 0, 40),
                Position = UDim2.new(0.05, 0, 0, 85),
                BackgroundTransparency = 1,
                
                [Children] = {
                    New(scope, "UIListLayout") {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        Padding = UDim.new(0, 10),
                    },
                    
                    -- Filter buttons
                    table.unpack((function()
                        local filters = {"All", "Owned", "Locked"}
                        local buttons = {}
                        for _, filter in filters do
                            local isActive = Computed(scope, function(use)
                                return use(selectedFilter) == filter
                            end)
                            table.insert(buttons, New(scope, "TextButton") {
                                Size = UDim2.new(0, 100, 0, 35),
                                BackgroundColor3 = Computed(scope, function(use)
                                    return if use(isActive) then PvZTheme.Colors.GrassGreen else PvZTheme.Colors.WoodBrown
                                end),
                                Text = filter,
                                TextSize = 16,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = PvZTheme.Colors.TextWhite,
                                
                                [OnEvent "Activated"] = function()
                                    selectedFilter:set(filter)
                                end,
                                
                                [Children] = {
                                    New(scope, "UICorner") {
                                        CornerRadius = UDim.new(0, 8),
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
                Size = UDim2.new(0.95, 0, 0.65, 0),
                Position = UDim2.new(0.025, 0, 0.18, 0),
                BackgroundColor3 = PvZTheme.Colors.WoodLight,
                BackgroundTransparency = 0.3,
                ScrollBarThickness = 8,
                CanvasSize = UDim2.new(0, 0, 0, 1200),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 10),
                    },
                    
                    New(scope, "UIPadding") {
                        PaddingTop = UDim.new(0, 15),
                        PaddingBottom = UDim.new(0, 15),
                        PaddingLeft = UDim.new(0, 15),
                        PaddingRight = UDim.new(0, 15),
                    },
                    
                    New(scope, "UIGridLayout") {
                        CellSize = UDim2.new(0, 140, 0, 180),
                        CellPadding = UDim2.new(0, 12, 0, 12),
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    },
                    
                    -- Generate plant cards dynamically
                    Computed(scope, function(use)
                        local plants = use(filteredPlants)
                        local playerData = use(props.PlayerData)
                        local coins = if playerData then playerData.Coins else 0
                        local unlockedSet: {[string]: boolean} = {}
                        
                        if playerData and playerData.UnlockedPlants then
                            for _, plantType in ipairs(playerData.UnlockedPlants) do
                                unlockedSet[plantType] = true
                            end
                        end
                        
                        local cards = {}
                        for i, plant in ipairs(plants) do
                            local isUnlocked = Value(scope, unlockedSet[plant.PlantType] == true)
                            local canAfford = Value(scope, coins >= plant.Info.Cost)
                            
                            table.insert(cards, PlantCard(scope, {
                                PlantType = plant.PlantType,
                                Cost = plant.Info.Cost,
                                IsUnlocked = isUnlocked,
                                CanAfford = canAfford,
                                OnPurchase = function()
                                    props.OnPurchase(plant.PlantType)
                                end,
                            }))
                        end
                        
                        return New(scope, "Frame") {
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            [Children] = cards,
                        }
                    end),
                },
            },
        },
    }
end
