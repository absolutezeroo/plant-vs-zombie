--!strict
--[[
    ShopView.luau - Modern Plant Shop UI
    
    Clean, card-based design inspired by modern Roblox games.
    Dark theme with gold accents, smooth hover effects.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionData = require(Shared.data.ProgressionData)
local PlantData = require(Shared.data.PlantData)
local ModernTheme = require(Shared.ui.ModernTheme)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local peek = Fusion.peek

-- Use shared theme colors with local aliases for convenience
local ThemeColors = ModernTheme.Colors
local Colors = {
    Background = ThemeColors.Background,
    CardBg = ThemeColors.Card,
    CardHover = ThemeColors.CardHover,
    TopBar = ThemeColors.Panel,
    Gold = ThemeColors.Gold,
    GoldDark = ThemeColors.GoldDark,
    Green = ThemeColors.Success,
    GreenLight = ThemeColors.SuccessLight,
    TextWhite = ThemeColors.TextWhite,
    TextMuted = ThemeColors.TextMuted,
    Disabled = ThemeColors.Disabled,
    Border = ThemeColors.Border,
}

export type ShopViewProps = {
    PlayerData: any,
    OnBack: () -> (),
    OnPurchase: (plantType: string) -> (),
}

-- Use shared emoji function from ModernTheme
local getPlantEmoji = ModernTheme.GetPlantEmoji

local function getSortedPlants(): {{PlantType: string, Info: ProgressionData.PlantUnlockInfo}}
    local plants = {}
    for plantType, info in pairs(ProgressionData.PlantUnlocks) do
        table.insert(plants, {PlantType = plantType, Info = info})
    end
    table.sort(plants, function(a, b) return a.Info.Order < b.Info.Order end)
    return plants
end

-- Modern plant card
local function PlantCard(scope: any, props: {
    PlantType: string,
    Cost: number,
    IsUnlocked: any,
    CanAfford: any,
    OnPurchase: () -> (),
}): Frame
    local isHovered = Value(scope, false)
    local plantStats = PlantData[props.PlantType]
    local emoji = getPlantEmoji(props.PlantType)
    
    return New(scope, "Frame") {
        Name = props.PlantType,
        Size = UDim2.fromOffset(180, 245),
        BackgroundColor3 = Computed(scope, function(use)
            return if use(isHovered) then Colors.CardHover else Colors.CardBg
        end),
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0, 14) },
            
            New(scope, "UIStroke") {
                Color = Computed(scope, function(use)
                    if use(props.IsUnlocked) then return Colors.Green end
                    if use(isHovered) then return Colors.Gold end
                    return Colors.Border
                end),
                Thickness = 2,
            },
            
            -- Owned badge
            Computed(scope, function(use)
                if not use(props.IsUnlocked) then return nil end
                return New(scope, "Frame") {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = Colors.Green,
                    [Children] = {
                        New(scope, "UICorner") { CornerRadius = UDim.new(0, 14) },
                        New(scope, "Frame") {
                            Size = UDim2.new(1, 0, 0.5, 0),
                            Position = UDim2.new(0, 0, 0.5, 0),
                            BackgroundColor3 = Colors.Green,
                        },
                        New(scope, "TextLabel") {
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = "✓ OWNED",
                            TextColor3 = Colors.TextWhite,
                            TextSize = 12,
                            Font = Enum.Font.GothamBold,
                        },
                    },
                }
            end),
            
            -- Plant icon
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 75),
                Position = UDim2.fromOffset(0, 35),
                BackgroundTransparency = 1,
                Text = emoji,
                TextSize = 55,
            },
            
            -- Plant name
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -16, 0, 26),
                Position = UDim2.new(0, 8, 0, 112),
                BackgroundTransparency = 1,
                Text = props.PlantType,
                TextColor3 = Colors.TextWhite,
                TextSize = 16,
                Font = Enum.Font.GothamBold,
                TextTruncate = Enum.TextTruncate.AtEnd,
            },
            
            -- Category
            plantStats and New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 18),
                Position = UDim2.fromOffset(0, 138),
                BackgroundTransparency = 1,
                Text = plantStats.Category or "",
                TextColor3 = Colors.TextMuted,
                TextSize = 12,
                Font = Enum.Font.Gotham,
            } or nil,
            
            -- Sun cost display
            plantStats and New(scope, "Frame") {
                Size = UDim2.fromOffset(65, 24),
                Position = UDim2.new(0.5, 0, 0, 158),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundColor3 = Color3.fromRGB(255, 180, 0),
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 6) },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = `☀️ {plantStats.Cost}`,
                        TextColor3 = Color3.fromRGB(50, 50, 50),
                        TextSize = 12,
                        Font = Enum.Font.GothamBold,
                    },
                },
            } or nil,
            
            -- Buy button OR owned info
            Computed(scope, function(use)
                if use(props.IsUnlocked) then
                    -- Show stats for owned plants instead of empty space
                    return New(scope, "Frame") {
                        Size = UDim2.new(1, -24, 0, 42),
                        Position = UDim2.new(0, 12, 1, -52),
                        BackgroundColor3 = Color3.fromRGB(45, 65, 45),
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "✓ In Collection",
                                TextColor3 = Colors.GreenLight,
                                TextSize = 14,
                                Font = Enum.Font.GothamBold,
                            },
                        },
                    }
                end
                
                local canAfford = use(props.CanAfford)
                
                return New(scope, "TextButton") {
                    Size = UDim2.new(1, -24, 0, 42),
                    Position = UDim2.new(0, 12, 1, -52),
                    BackgroundColor3 = if canAfford then Colors.Gold else Colors.Disabled,
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 15, -- Above hover detector
                    
                    [OnEvent "Activated"] = function()
                        if peek(props.CanAfford) then props.OnPurchase() end
                    end,
                    
                    [Children] = {
                        New(scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
                        New(scope, "TextLabel") {
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = `🪙 {props.Cost}`,
                            TextColor3 = if canAfford then Color3.fromRGB(40, 40, 40) else Colors.TextMuted,
                            TextSize = 15,
                            Font = Enum.Font.GothamBold,
                        },
                    },
                }
            end),
            
            -- Hover detector (covers card EXCEPT buy button area at bottom)
            New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, -60), -- Stop before the buy button
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 10,
                [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
            },
        },
    }
end

-- Filter pill
local function FilterPill(scope: any, text: string, isActive: any, onClick: () -> ()): TextButton
    return New(scope, "TextButton") {
        Size = UDim2.fromOffset(85, 34),
        BackgroundColor3 = Computed(scope, function(use)
            return if use(isActive) then Colors.Gold else Colors.CardBg
        end),
        Text = text,
        TextColor3 = Computed(scope, function(use)
            return if use(isActive) then Color3.fromRGB(30, 30, 30) else Colors.TextWhite
        end),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        [OnEvent "Activated"] = onClick,
        [Children] = { New(scope, "UICorner") { CornerRadius = UDim.new(0, 17) } },
    }
end

return function(scope: any, props: ShopViewProps): Frame
    local sortedPlants = getSortedPlants()
    local selectedFilter = Value(scope, "All")
    
    local filteredPlants = Computed(scope, function(use)
        local filter = use(selectedFilter)
        local playerData = use(props.PlayerData)
        local unlockedSet: {[string]: boolean} = {}
        
        if playerData and playerData.UnlockedPlants then
            for _, pt in ipairs(playerData.UnlockedPlants) do
                unlockedSet[pt] = true
            end
        end
        
        local result = {}
        for _, plant in ipairs(sortedPlants) do
            local owned = unlockedSet[plant.PlantType] == true
            if filter == "All" or (filter == "Owned" and owned) or (filter == "Locked" and not owned) then
                table.insert(result, plant)
            end
        end
        return result
    end)
    
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.Background,
        
        [Children] = {
            -- Top bar
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 90),
                BackgroundColor3 = Colors.TopBar,
                
                [Children] = {
                    -- Close button (RIGHT side to avoid Roblox UI)
                    New(scope, "TextButton") {
                        Size = UDim2.fromOffset(44, 44),
                        Position = UDim2.new(1, -15, 0, 32),
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundColor3 = Colors.CardBg,
                        Text = "✕",
                        TextColor3 = Colors.TextWhite,
                        TextSize = 20,
                        Font = Enum.Font.GothamBold,
                        [OnEvent "Activated"] = props.OnBack,
                        [Children] = { New(scope, "UICorner") { CornerRadius = UDim.new(0, 12) } },
                    },
                    
                    -- Title
                    New(scope, "TextLabel") {
                        Size = UDim2.fromOffset(150, 50),
                        Position = UDim2.new(0.5, 0, 0, 32),
                        AnchorPoint = Vector2.new(0.5, 0),
                        BackgroundTransparency = 1,
                        Text = "🛒 SHOP",
                        TextColor3 = Colors.TextWhite,
                        TextSize = 26,
                        Font = Enum.Font.GothamBlack,
                    },
                    
                    -- Coins (RIGHT side, before close button)
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(140, 44),
                        Position = UDim2.new(1, -70, 0, 35),
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundColor3 = Colors.CardBg,
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0, 20) },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then `🪙 {data.Coins}` else "🪙 ---"
                                end),
                                TextColor3 = Colors.Gold,
                                TextSize = 18,
                                Font = Enum.Font.GothamBold,
                            },
                        },
                    },
                },
            },
            
            -- Filters
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 50),
                Position = UDim2.fromOffset(0, 95),
                BackgroundTransparency = 1,
                [Children] = {
                    New(scope, "UIListLayout") {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        Padding = UDim.new(0, 10),
                    },
                    FilterPill(scope, "All", Computed(scope, function(use) return use(selectedFilter) == "All" end), 
                        function() selectedFilter:set("All") end),
                    FilterPill(scope, "Owned", Computed(scope, function(use) return use(selectedFilter) == "Owned" end), 
                        function() selectedFilter:set("Owned") end),
                    FilterPill(scope, "Locked", Computed(scope, function(use) return use(selectedFilter) == "Locked" end), 
                        function() selectedFilter:set("Locked") end),
                },
            },
            
            -- Grid
            New(scope, "ScrollingFrame") {
                Size = UDim2.new(1, -30, 1, -160),
                Position = UDim2.fromOffset(15, 150),
                BackgroundTransparency = 1,
                ScrollBarThickness = 6,
                ScrollBarImageColor3 = Colors.Border,
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                
                [Children] = {
                    New(scope, "UIPadding") { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 20), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) },
                    New(scope, "UIGridLayout") {
                        CellSize = UDim2.fromOffset(180, 245),
                        CellPadding = UDim2.fromOffset(18, 18),
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    },
                    
                    Computed(scope, function(use)
                        local plants = use(filteredPlants)
                        local playerData = use(props.PlayerData)
                        local coins = if playerData then playerData.Coins else 0
                        local unlockedSet: {[string]: boolean} = {}
                        
                        if playerData and playerData.UnlockedPlants then
                            for _, pt in ipairs(playerData.UnlockedPlants) do
                                unlockedSet[pt] = true
                            end
                        end
                        
                        local cards = {}
                        for _, plant in ipairs(plants) do
                            table.insert(cards, PlantCard(scope, {
                                PlantType = plant.PlantType,
                                Cost = plant.Info.Cost,
                                IsUnlocked = Value(scope, unlockedSet[plant.PlantType] == true),
                                CanAfford = Value(scope, coins >= plant.Info.Cost),
                                OnPurchase = function() props.OnPurchase(plant.PlantType) end,
                            }))
                        end
                        return cards
                    end),
                },
            },
        },
    }
end
