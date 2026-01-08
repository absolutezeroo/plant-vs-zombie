--!strict
--[[
    ZoneInteractionController.luau - Handles ProximityPrompt interactions
    
    Listens for ProximityPrompts in InteractiveZones:
    - ShopZone → Opens Shop UI
    - DeckBuilderZone → Opens Deck Builder UI
    - ProfileZone → Opens Profile UI
    
    Uses PvZStyle for consistent Plants vs Zombies aesthetic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PlantData = require(Shared.data.PlantData)
local ProgressionData = require(Shared.data.ProgressionData)

-- Import PvZ Style (using relative path from controllers folder)
local PvZTheme = require(ReplicatedStorage.Shared.ui.PvZTheme)

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local OnEvent = Fusion.OnEvent

local ZoneInteractionController = {}

-- State
local _scope = Fusion.scoped(Fusion)
local _currentUI: ScreenGui? = nil
local _playerData = Value(_scope, nil :: any?)
local _unlockedPlants = Value(_scope, {} :: {string})
local _currentDeck = Value(_scope, {} :: {string})

-- Callbacks
local _onPurchasePlant: ((string) -> ())? = nil
local _onSaveDeck: (({string}) -> ())? = nil

-- Close any open UI
local function closeCurrentUI()
    if _currentUI then
        _currentUI:Destroy()
        _currentUI = nil
    end
end

-- ============================================
-- SHOP UI
-- ============================================
local function createShopUI(): ScreenGui
    -- Get all plants with unlock info
    local function getPlants()
        local plants = {}
        local unlocked = Fusion.peek(_unlockedPlants)
        local unlockedSet = {}
        for _, p in unlocked do
            unlockedSet[p] = true
        end
        
        for plantType, stats in pairs(PlantData) do
            local unlockInfo = ProgressionData.PlantUnlocks[plantType]
            local cost = unlockInfo and unlockInfo.Cost or 0
            local isOwned = unlockedSet[plantType] == true
            
            table.insert(plants, {
                Type = plantType,
                Stats = stats,
                Cost = cost,
                IsOwned = isOwned,
            })
        end
        
        -- Sort: owned first, then by cost
        table.sort(plants, function(a, b)
            if a.IsOwned ~= b.IsOwned then
                return a.IsOwned
            end
            return a.Cost < b.Cost
        end)
        
        return plants
    end
    
    local function createPlantCard(plant: any)
        local data = Fusion.peek(_playerData)
        local coins = data and data.Coins or 0
        local canAfford = coins >= plant.Cost
        
        return New(_scope, "Frame") {
            Size = UDim2.new(0, 130, 0, 190),
            BackgroundColor3 = if plant.IsOwned 
                then PvZTheme.Colors.Owned 
                else PvZTheme.Colors.WoodLight,
            
            [Children] = {
                New(_scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
                New(_scope, "UIStroke") { 
                    Color = PvZTheme.Colors.WoodBorder, 
                    Thickness = 3,
                },
                
                -- Plant icon area
                New(_scope, "Frame") {
                    Size = UDim2.new(0, 80, 0, 80),
                    Position = UDim2.new(0.5, -40, 0, 12),
                    BackgroundColor3 = PvZTheme.Colors.GrassMedium,
                    
                    [Children] = {
                        New(_scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
                        New(_scope, "UIStroke") { 
                            Color = PvZTheme.Colors.GrassDark, 
                            Thickness = 2,
                        },
                        New(_scope, "TextLabel") {
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = "🌱",
                            TextSize = 45,
                        },
                    },
                },
                
                -- Plant name
                New(_scope, "TextLabel") {
                    Size = UDim2.new(1, -10, 0, 32),
                    Position = UDim2.new(0, 5, 0, 97),
                    BackgroundTransparency = 1,
                    Text = plant.Type,
                    TextColor3 = PvZTheme.Colors.TextDark,
                    TextSize = 14,
                    Font = PvZTheme.Fonts.Button,
                    TextWrapped = true,
                    TextYAlignment = Enum.TextYAlignment.Top,
                },
                
                -- Cost or Owned badge
                New(_scope, "Frame") {
                    Size = UDim2.new(0, 80, 0, 26),
                    Position = UDim2.new(0.5, -40, 0, 130),
                    BackgroundColor3 = if plant.IsOwned 
                        then PvZTheme.Colors.GrassMedium
                        elseif canAfford then PvZTheme.Colors.GoldDark
                        else PvZTheme.Colors.Locked,
                    
                    [Children] = {
                        New(_scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
                        New(_scope, "TextLabel") {
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = if plant.IsOwned then "✓ Owned" else `{PvZTheme.Icons.Coin} {plant.Cost}`,
                            TextColor3 = PvZTheme.Colors.TextLight,
                            TextSize = 13,
                            Font = PvZTheme.Fonts.Numbers,
                            
                            [Children] = {
                                New(_scope, "UIStroke") {
                                    Color = PvZTheme.Colors.TextShadow,
                                    Thickness = 1,
                                },
                            },
                        },
                    },
                },
                
                -- Buy button (only if not owned)
                if not plant.IsOwned then New(_scope, "TextButton") {
                    Size = UDim2.new(0, 90, 0, 32),
                    Position = UDim2.new(0.5, -45, 1, -40),
                    BackgroundColor3 = if canAfford 
                        then PvZTheme.Colors.ButtonGreen
                        else PvZTheme.Colors.Locked,
                    Text = if canAfford then "BUY" else `Need {PvZTheme.Icons.Coin}`,
                    TextColor3 = PvZTheme.Colors.TextLight,
                    TextSize = 14,
                    Font = PvZTheme.Fonts.Button,
                    
                    [OnEvent "Activated"] = function()
                        if canAfford and _onPurchasePlant then
                            _onPurchasePlant(plant.Type)
                            closeCurrentUI()
                        end
                    end,
                    
                    [Children] = {
                        New(_scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
                        New(_scope, "UIStroke") { 
                            Color = PvZTheme.Colors.WoodBorder, 
                            Thickness = 2,
                        },
                    },
                } else nil,
            },
        }
    end
    
    return New(_scope, "ScreenGui") {
        Name = "ShopUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        
        [Children] = {
            -- Darkened background
            New(_scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = PvZTheme.Colors.DarkOverlay,
                BackgroundTransparency = 0.4,
                Text = "",
                AutoButtonColor = false,
                [OnEvent "Activated"] = closeCurrentUI,
            },
            
            -- Main wood panel
            New(_scope, "Frame") {
                Size = UDim2.new(0, 850, 0, 620),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = PvZTheme.Colors.WoodMedium,
                
                [Children] = {
                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 20) },
                    New(_scope, "UIStroke") { 
                        Color = PvZTheme.Colors.WoodBorder, 
                        Thickness = 5,
                    },
                    
                    -- Header
                    New(_scope, "Frame") {
                        Size = UDim2.new(1, 0, 0, 70),
                        BackgroundColor3 = PvZTheme.Colors.WoodDark,
                        
                        [Children] = {
                            New(_scope, "UICorner") { CornerRadius = UDim.new(0, 18) },
                            New(_scope, "Frame") {
                                Size = UDim2.new(1, 0, 0, 25),
                                Position = UDim2.new(0, 0, 1, -25),
                                BackgroundColor3 = PvZTheme.Colors.WoodDark,
                                BorderSizePixel = 0,
                            },
                            
                            -- Title
                            New(_scope, "TextLabel") {
                                Size = UDim2.new(0.6, 0, 1, 0),
                                Position = UDim2.new(0, 25, 0, 0),
                                BackgroundTransparency = 1,
                                Text = "🌻 CRAZY DAVE'S PLANT SHOP",
                                TextColor3 = PvZTheme.Colors.Gold,
                                TextSize = 32,
                                Font = PvZTheme.Fonts.Title,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                
                                [Children] = {
                                    New(_scope, "UIStroke") {
                                        Color = PvZTheme.Colors.TextShadow,
                                        Thickness = 2,
                                    },
                                },
                            },
                            
                            -- Coins display
                            New(_scope, "Frame") {
                                Size = UDim2.new(0, 140, 0, 45),
                                Position = UDim2.new(1, -230, 0.5, -22),
                                BackgroundColor3 = PvZTheme.Colors.WoodLight,
                                
                                [Children] = {
                                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
                                    New(_scope, "UIStroke") { 
                                        Color = PvZTheme.Colors.WoodBorder, 
                                        Thickness = 2,
                                    },
                                    New(_scope, "TextLabel") {
                                        Size = UDim2.new(1, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = Computed(_scope, function(use)
                                            local data = use(_playerData)
                                            return `{PvZTheme.Icons.Coin} {data and data.Coins or 0}`
                                        end),
                                        TextColor3 = PvZTheme.Colors.Coins,
                                        TextSize = 22,
                                        Font = PvZTheme.Fonts.Numbers,
                                        
                                        [Children] = {
                                            New(_scope, "UIStroke") {
                                                Color = PvZTheme.Colors.TextShadow,
                                                Thickness = 1.5,
                                            },
                                        },
                                    },
                                },
                            },
                            
                            -- Close button
                            New(_scope, "TextButton") {
                                Size = UDim2.new(0, 50, 0, 50),
                                Position = UDim2.new(1, -65, 0.5, -25),
                                BackgroundColor3 = PvZTheme.Colors.ButtonRed,
                                Text = "✕",
                                TextColor3 = PvZTheme.Colors.TextLight,
                                TextSize = 28,
                                Font = PvZTheme.Fonts.Button,
                                
                                [OnEvent "Activated"] = closeCurrentUI,
                                
                                [Children] = {
                                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
                                    New(_scope, "UIStroke") { 
                                        Color = PvZTheme.Colors.WoodBorder, 
                                        Thickness = 3,
                                    },
                                },
                            },
                        },
                    },
                    
                    -- Plants grid
                    New(_scope, "ScrollingFrame") {
                        Size = UDim2.new(1, -40, 1, -100),
                        Position = UDim2.new(0, 20, 0, 80),
                        BackgroundTransparency = 1,
                        ScrollBarThickness = 10,
                        ScrollBarImageColor3 = PvZTheme.Colors.WoodDark,
                        CanvasSize = UDim2.new(0, 0, 0, 800),
                        
                        [Children] = {
                            New(_scope, "UIGridLayout") {
                                CellSize = UDim2.new(0, 130, 0, 190),
                                CellPadding = UDim2.new(0, 12, 0, 12),
                                SortOrder = Enum.SortOrder.LayoutOrder,
                            },
                            
                            (function()
                                local cards = {}
                                for _, plant in getPlants() do
                                    table.insert(cards, createPlantCard(plant))
                                end
                                return cards
                            end)(),
                        },
                    },
                },
            },
        },
    }
end

-- ============================================
-- DECK BUILDER UI
-- ============================================
local function createDeckBuilderUI(): ScreenGui
    local localDeck = Value(_scope, table.clone(Fusion.peek(_currentDeck)))
    
    local function togglePlant(plantType: string)
        local deck = Fusion.peek(localDeck)
        local newDeck = {}
        local found = false
        
        for _, p in deck do
            if p == plantType then
                found = true
            else
                table.insert(newDeck, p)
            end
        end
        
        if not found and #newDeck < 6 then
            table.insert(newDeck, plantType)
        end
        
        localDeck:set(newDeck)
    end
    
    local function saveDeck()
        if _onSaveDeck then
            _onSaveDeck(Fusion.peek(localDeck))
        end
        closeCurrentUI()
    end
    
    local function createPlantCard(plantType: string)
        local unlocked = Fusion.peek(_unlockedPlants)
        local isOwned = table.find(unlocked, plantType) ~= nil
        
        return New(_scope, "TextButton") {
            Size = UDim2.new(0, 95, 0, 115),
            BackgroundColor3 = Computed(_scope, function(use)
                local deck = use(localDeck)
                local inDeck = table.find(deck, plantType) ~= nil
                if inDeck then
                    return PvZTheme.Colors.Selected
                elseif isOwned then
                    return PvZTheme.Colors.WoodLight
                else
                    return PvZTheme.Colors.Locked
                end
            end),
            Text = "",
            AutoButtonColor = isOwned,
            
            [OnEvent "Activated"] = function()
                if isOwned then
                    togglePlant(plantType)
                end
            end,
            
            [Children] = {
                New(_scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
                New(_scope, "UIStroke") { 
                    Color = Computed(_scope, function(use)
                        local deck = use(localDeck)
                        local inDeck = table.find(deck, plantType) ~= nil
                        return if inDeck then PvZTheme.Colors.GrassDark else PvZTheme.Colors.WoodBorder
                    end),
                    Thickness = 3,
                },
                
                -- Icon
                New(_scope, "Frame") {
                    Size = UDim2.new(0, 55, 0, 55),
                    Position = UDim2.new(0.5, -27, 0, 8),
                    BackgroundColor3 = PvZTheme.Colors.GrassMedium,
                    
                    [Children] = {
                        New(_scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
                        New(_scope, "TextLabel") {
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = if isOwned then "🌱" else "🔒",
                            TextSize = 32,
                        },
                    },
                },
                
                -- Name
                New(_scope, "TextLabel") {
                    Size = UDim2.new(1, -6, 0, 40),
                    Position = UDim2.new(0, 3, 0, 68),
                    BackgroundTransparency = 1,
                    Text = plantType,
                    TextColor3 = if isOwned then PvZTheme.Colors.TextDark else PvZTheme.Colors.Locked,
                    TextSize = 11,
                    Font = PvZTheme.Fonts.Button,
                    TextWrapped = true,
                    TextYAlignment = Enum.TextYAlignment.Top,
                },
                
                -- Check mark if in deck
                New(_scope, "TextLabel") {
                    Size = UDim2.new(0, 24, 0, 24),
                    Position = UDim2.new(1, -28, 0, 4),
                    BackgroundTransparency = 1,
                    Text = "✓",
                    TextColor3 = PvZTheme.Colors.GrassLight,
                    TextSize = 20,
                    Font = PvZTheme.Fonts.Numbers,
                    Visible = Computed(_scope, function(use)
                        local deck = use(localDeck)
                        return table.find(deck, plantType) ~= nil
                    end),
                    
                    [Children] = {
                        New(_scope, "UIStroke") {
                            Color = PvZTheme.Colors.GrassDark,
                            Thickness = 2,
                        },
                    },
                },
            },
        }
    end
    
    return New(_scope, "ScreenGui") {
        Name = "DeckBuilderUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        
        [Children] = {
            -- Darkened background
            New(_scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = PvZTheme.Colors.DarkOverlay,
                BackgroundTransparency = 0.4,
                Text = "",
                AutoButtonColor = false,
                [OnEvent "Activated"] = closeCurrentUI,
            },
            
            -- Main panel
            New(_scope, "Frame") {
                Size = UDim2.new(0, 900, 0, 650),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = PvZTheme.Colors.WoodMedium,
                
                [Children] = {
                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 20) },
                    New(_scope, "UIStroke") { 
                        Color = PvZTheme.Colors.WoodBorder, 
                        Thickness = 5,
                    },
                    
                    -- Header
                    New(_scope, "Frame") {
                        Size = UDim2.new(1, 0, 0, 70),
                        BackgroundColor3 = PvZTheme.Colors.WoodDark,
                        
                        [Children] = {
                            New(_scope, "UICorner") { CornerRadius = UDim.new(0, 18) },
                            New(_scope, "Frame") {
                                Size = UDim2.new(1, 0, 0, 25),
                                Position = UDim2.new(0, 0, 1, -25),
                                BackgroundColor3 = PvZTheme.Colors.WoodDark,
                                BorderSizePixel = 0,
                            },
                            
                            -- Title
                            New(_scope, "TextLabel") {
                                Size = UDim2.new(0.5, 0, 1, 0),
                                Position = UDim2.new(0, 25, 0, 0),
                                BackgroundTransparency = 1,
                                Text = "🎴 BUILD YOUR DECK",
                                TextColor3 = PvZTheme.Colors.GrassLight,
                                TextSize = 32,
                                Font = PvZTheme.Fonts.Title,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                
                                [Children] = {
                                    New(_scope, "UIStroke") {
                                        Color = PvZTheme.Colors.TextShadow,
                                        Thickness = 2,
                                    },
                                },
                            },
                            
                            -- Deck count
                            New(_scope, "TextLabel") {
                                Size = UDim2.new(0, 100, 1, 0),
                                Position = UDim2.new(1, -220, 0, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(_scope, function(use)
                                    return `{#use(localDeck)}/6`
                                end),
                                TextColor3 = PvZTheme.Colors.Gold,
                                TextSize = 28,
                                Font = PvZTheme.Fonts.Numbers,
                                
                                [Children] = {
                                    New(_scope, "UIStroke") {
                                        Color = PvZTheme.Colors.TextShadow,
                                        Thickness = 2,
                                    },
                                },
                            },
                            
                            -- Close button
                            New(_scope, "TextButton") {
                                Size = UDim2.new(0, 50, 0, 50),
                                Position = UDim2.new(1, -65, 0.5, -25),
                                BackgroundColor3 = PvZTheme.Colors.ButtonRed,
                                Text = "✕",
                                TextColor3 = PvZTheme.Colors.TextLight,
                                TextSize = 28,
                                Font = PvZTheme.Fonts.Button,
                                
                                [OnEvent "Activated"] = closeCurrentUI,
                                
                                [Children] = {
                                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
                                    New(_scope, "UIStroke") { 
                                        Color = PvZTheme.Colors.WoodBorder, 
                                        Thickness = 3,
                                    },
                                },
                            },
                        },
                    },
                    
                    -- Current deck display
                    New(_scope, "Frame") {
                        Size = UDim2.new(1, -40, 0, 90),
                        Position = UDim2.new(0, 20, 0, 80),
                        BackgroundColor3 = PvZTheme.Colors.WoodLight,
                        
                        [Children] = {
                            New(_scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
                            New(_scope, "UIStroke") { 
                                Color = PvZTheme.Colors.WoodBorder, 
                                Thickness = 3,
                            },
                            
                            New(_scope, "TextLabel") {
                                Size = UDim2.new(0, 120, 0, 25),
                                Position = UDim2.new(0, 15, 0, 5),
                                BackgroundTransparency = 1,
                                Text = "YOUR DECK:",
                                TextColor3 = PvZTheme.Colors.TextDark,
                                TextSize = 14,
                                Font = PvZTheme.Fonts.Button,
                                TextXAlignment = Enum.TextXAlignment.Left,
                            },
                            
                            -- Deck slots
                            New(_scope, "Frame") {
                                Size = UDim2.new(1, -30, 0, 55),
                                Position = UDim2.new(0, 15, 0, 28),
                                BackgroundTransparency = 1,
                                
                                [Children] = {
                                    New(_scope, "UIListLayout") {
                                        FillDirection = Enum.FillDirection.Horizontal,
                                        Padding = UDim.new(0, 10),
                                    },
                                    
                                    (function()
                                        local slots = {}
                                        for i = 1, 6 do
                                            table.insert(slots, New(_scope, "Frame") {
                                                Size = UDim2.new(0, 85, 0, 55),
                                                BackgroundColor3 = Computed(_scope, function(use)
                                                    local deck = use(localDeck)
                                                    return if deck[i] then PvZTheme.Colors.Owned else PvZTheme.Colors.WoodDark
                                                end),
                                                
                                                [Children] = {
                                                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
                                                    New(_scope, "UIStroke") { 
                                                        Color = PvZTheme.Colors.WoodBorder, 
                                                        Thickness = 2,
                                                    },
                                                    New(_scope, "TextLabel") {
                                                        Size = UDim2.new(1, -4, 1, -4),
                                                        Position = UDim2.new(0, 2, 0, 2),
                                                        BackgroundTransparency = 1,
                                                        Text = Computed(_scope, function(use)
                                                            local deck = use(localDeck)
                                                            if deck[i] then
                                                                local name = deck[i]
                                                                if #name > 9 then
                                                                    name = name:sub(1, 8) .. ".."
                                                                end
                                                                return name
                                                            end
                                                            return tostring(i)
                                                        end),
                                                        TextColor3 = Computed(_scope, function(use)
                                                            local deck = use(localDeck)
                                                            return if deck[i] then PvZTheme.Colors.TextDark else PvZTheme.Colors.Locked
                                                        end),
                                                        TextSize = 12,
                                                        Font = PvZTheme.Fonts.Button,
                                                        TextWrapped = true,
                                                    },
                                                },
                                            })
                                        end
                                        return slots
                                    end)(),
                                },
                            },
                        },
                    },
                    
                    -- Plants grid
                    New(_scope, "ScrollingFrame") {
                        Size = UDim2.new(1, -40, 0, 380),
                        Position = UDim2.new(0, 20, 0, 180),
                        BackgroundTransparency = 1,
                        ScrollBarThickness = 10,
                        ScrollBarImageColor3 = PvZTheme.Colors.WoodDark,
                        CanvasSize = UDim2.new(0, 0, 0, 600),
                        
                        [Children] = {
                            New(_scope, "UIGridLayout") {
                                CellSize = UDim2.new(0, 95, 0, 115),
                                CellPadding = UDim2.new(0, 8, 0, 8),
                                SortOrder = Enum.SortOrder.LayoutOrder,
                            },
                            
                            (function()
                                local cards = {}
                                for plantType, _ in pairs(PlantData) do
                                    table.insert(cards, createPlantCard(plantType))
                                end
                                return cards
                            end)(),
                        },
                    },
                    
                    -- Save button
                    New(_scope, "TextButton") {
                        Size = UDim2.new(0, 220, 0, 55),
                        Position = UDim2.new(0.5, -110, 1, -70),
                        BackgroundColor3 = PvZTheme.Colors.ButtonGreen,
                        Text = "💾 SAVE DECK",
                        TextColor3 = PvZTheme.Colors.TextLight,
                        TextSize = 24,
                        Font = PvZTheme.Fonts.Title,
                        
                        [OnEvent "Activated"] = saveDeck,
                        
                        [Children] = {
                            New(_scope, "UICorner") { CornerRadius = UDim.new(0, 14) },
                            New(_scope, "UIStroke") { 
                                Color = PvZTheme.Colors.WoodBorder, 
                                Thickness = 4,
                            },
                            New(_scope, "Frame") {
                                Size = UDim2.new(1, -10, 0.35, 0),
                                Position = UDim2.new(0, 5, 0, 5),
                                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                                BackgroundTransparency = 0.7,
                                BorderSizePixel = 0,
                                
                                [Children] = {
                                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

-- ============================================
-- PROFILE UI
-- ============================================
local function createProfileUI(): ScreenGui
    return New(_scope, "ScreenGui") {
        Name = "ProfileUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        
        [Children] = {
            -- Darkened background
            New(_scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = PvZTheme.Colors.DarkOverlay,
                BackgroundTransparency = 0.4,
                Text = "",
                AutoButtonColor = false,
                [OnEvent "Activated"] = closeCurrentUI,
            },
            
            -- Main panel
            New(_scope, "Frame") {
                Size = UDim2.new(0, 480, 0, 520),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = PvZTheme.Colors.WoodMedium,
                
                [Children] = {
                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 20) },
                    New(_scope, "UIStroke") { 
                        Color = PvZTheme.Colors.WoodBorder, 
                        Thickness = 5,
                    },
                    
                    -- Header
                    New(_scope, "Frame") {
                        Size = UDim2.new(1, 0, 0, 70),
                        BackgroundColor3 = PvZTheme.Colors.WoodDark,
                        
                        [Children] = {
                            New(_scope, "UICorner") { CornerRadius = UDim.new(0, 18) },
                            New(_scope, "Frame") {
                                Size = UDim2.new(1, 0, 0, 25),
                                Position = UDim2.new(0, 0, 1, -25),
                                BackgroundColor3 = PvZTheme.Colors.WoodDark,
                                BorderSizePixel = 0,
                            },
                            
                            New(_scope, "TextLabel") {
                                Size = UDim2.new(0.7, 0, 1, 0),
                                Position = UDim2.new(0, 25, 0, 0),
                                BackgroundTransparency = 1,
                                Text = "📊 YOUR STATS",
                                TextColor3 = PvZTheme.Colors.Gold,
                                TextSize = 32,
                                Font = PvZTheme.Fonts.Title,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                
                                [Children] = {
                                    New(_scope, "UIStroke") {
                                        Color = PvZTheme.Colors.TextShadow,
                                        Thickness = 2,
                                    },
                                },
                            },
                            
                            -- Close button
                            New(_scope, "TextButton") {
                                Size = UDim2.new(0, 50, 0, 50),
                                Position = UDim2.new(1, -65, 0.5, -25),
                                BackgroundColor3 = PvZTheme.Colors.ButtonRed,
                                Text = "✕",
                                TextColor3 = PvZTheme.Colors.TextLight,
                                TextSize = 28,
                                Font = PvZTheme.Fonts.Button,
                                
                                [OnEvent "Activated"] = closeCurrentUI,
                                
                                [Children] = {
                                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
                                    New(_scope, "UIStroke") { 
                                        Color = PvZTheme.Colors.WoodBorder, 
                                        Thickness = 3,
                                    },
                                },
                            },
                        },
                    },
                    
                    -- Player name
                    New(_scope, "TextLabel") {
                        Size = UDim2.new(1, -40, 0, 45),
                        Position = UDim2.new(0, 20, 0, 80),
                        BackgroundTransparency = 1,
                        Text = Players.LocalPlayer.Name,
                        TextColor3 = PvZTheme.Colors.TextLight,
                        TextSize = 28,
                        Font = PvZTheme.Fonts.Title,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        
                        [Children] = {
                            New(_scope, "UIStroke") {
                                Color = PvZTheme.Colors.TextShadow,
                                Thickness = 2,
                            },
                        },
                    },
                    
                    -- Level & XP
                    New(_scope, "Frame") {
                        Size = UDim2.new(1, -40, 0, 70),
                        Position = UDim2.new(0, 20, 0, 130),
                        BackgroundColor3 = PvZTheme.Colors.WoodLight,
                        
                        [Children] = {
                            New(_scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
                            New(_scope, "UIStroke") { 
                                Color = PvZTheme.Colors.WoodBorder, 
                                Thickness = 3,
                            },
                            
                            New(_scope, "TextLabel") {
                                Size = UDim2.new(0.5, 0, 0, 30),
                                Position = UDim2.new(0, 15, 0, 8),
                                BackgroundTransparency = 1,
                                Text = Computed(_scope, function(use)
                                    local data = use(_playerData)
                                    return `⭐ Level {data and data.Level or 1}`
                                end),
                                TextColor3 = PvZTheme.Colors.Gold,
                                TextSize = 24,
                                Font = PvZTheme.Fonts.Numbers,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                
                                [Children] = {
                                    New(_scope, "UIStroke") {
                                        Color = PvZTheme.Colors.TextShadow,
                                        Thickness = 1.5,
                                    },
                                },
                            },
                            
                            -- XP Bar
                            New(_scope, "Frame") {
                                Size = UDim2.new(1, -30, 0, 22),
                                Position = UDim2.new(0, 15, 0, 40),
                                BackgroundColor3 = PvZTheme.Colors.WoodDark,
                                
                                [Children] = {
                                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 6) },
                                    New(_scope, "UIStroke") { 
                                        Color = PvZTheme.Colors.WoodBorder, 
                                        Thickness = 2,
                                    },
                                    
                                    -- Fill
                                    New(_scope, "Frame") {
                                        Size = Computed(_scope, function(use)
                                            local data = use(_playerData)
                                            if not data then return UDim2.new(0, 0, 1, 0) end
                                            local pct = data.XP / math.max(1, data.TotalXPForNextLevel)
                                            return UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
                                        end),
                                        BackgroundColor3 = PvZTheme.Colors.XP,
                                        
                                        [Children] = {
                                            New(_scope, "UICorner") { CornerRadius = UDim.new(0, 6) },
                                        },
                                    },
                                    
                                    -- Text
                                    New(_scope, "TextLabel") {
                                        Size = UDim2.new(1, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = Computed(_scope, function(use)
                                            local data = use(_playerData)
                                            if not data then return "0 / 100 XP" end
                                            return `{data.XP} / {data.TotalXPForNextLevel} XP`
                                        end),
                                        TextColor3 = PvZTheme.Colors.TextLight,
                                        TextSize = 12,
                                        Font = PvZTheme.Fonts.Numbers,
                                        
                                        [Children] = {
                                            New(_scope, "UIStroke") {
                                                Color = PvZTheme.Colors.TextShadow,
                                                Thickness = 1,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    
                    -- Currencies
                    New(_scope, "Frame") {
                        Size = UDim2.new(1, -40, 0, 50),
                        Position = UDim2.new(0, 20, 0, 210),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(_scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 15),
                            },
                            
                            -- Coins
                            New(_scope, "Frame") {
                                Size = UDim2.new(0, 130, 0, 45),
                                BackgroundColor3 = PvZTheme.Colors.WoodLight,
                                
                                [Children] = {
                                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
                                    New(_scope, "UIStroke") { 
                                        Color = PvZTheme.Colors.WoodBorder, 
                                        Thickness = 2,
                                    },
                                    New(_scope, "TextLabel") {
                                        Size = UDim2.new(1, -10, 1, 0),
                                        Position = UDim2.new(0, 5, 0, 0),
                                        BackgroundTransparency = 1,
                                        Text = Computed(_scope, function(use)
                                            local data = use(_playerData)
                                            return `{PvZTheme.Icons.Coin} {data and data.Coins or 0}`
                                        end),
                                        TextColor3 = PvZTheme.Colors.Coins,
                                        TextSize = 20,
                                        Font = PvZTheme.Fonts.Numbers,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    },
                                },
                            },
                            
                            -- Gems
                            New(_scope, "Frame") {
                                Size = UDim2.new(0, 130, 0, 45),
                                BackgroundColor3 = PvZTheme.Colors.WoodLight,
                                
                                [Children] = {
                                    New(_scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
                                    New(_scope, "UIStroke") { 
                                        Color = PvZTheme.Colors.WoodBorder, 
                                        Thickness = 2,
                                    },
                                    New(_scope, "TextLabel") {
                                        Size = UDim2.new(1, -10, 1, 0),
                                        Position = UDim2.new(0, 5, 0, 0),
                                        BackgroundTransparency = 1,
                                        Text = Computed(_scope, function(use)
                                            local data = use(_playerData)
                                            return `💎 {data and data.Gems or 0}`
                                        end),
                                        TextColor3 = PvZTheme.Colors.Gems,
                                        TextSize = 20,
                                        Font = PvZTheme.Fonts.Numbers,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    },
                                },
                            },
                        },
                    },
                    
                    -- Stats grid
                    New(_scope, "Frame") {
                        Size = UDim2.new(1, -40, 0, 170),
                        Position = UDim2.new(0, 20, 0, 270),
                        BackgroundColor3 = PvZTheme.Colors.WoodLight,
                        
                        [Children] = {
                            New(_scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
                            New(_scope, "UIStroke") { 
                                Color = PvZTheme.Colors.WoodBorder, 
                                Thickness = 3,
                            },
                            New(_scope, "UIPadding") {
                                PaddingTop = UDim.new(0, 10),
                                PaddingBottom = UDim.new(0, 10),
                                PaddingLeft = UDim.new(0, 15),
                                PaddingRight = UDim.new(0, 15),
                            },
                            New(_scope, "UIListLayout") {
                                Padding = UDim.new(0, 8),
                            },
                            
                            -- Games Played
                            PvZTheme.StatRow(_scope, {
                                Icon = "🎮",
                                Label = "Games Played",
                                Value = Computed(_scope, function(use)
                                    local data = use(_playerData)
                                    return data and data.GamesPlayed or 0
                                end),
                            }),
                            
                            -- Wins
                            PvZTheme.StatRow(_scope, {
                                Icon = "🏆",
                                Label = "Victories",
                                Value = Computed(_scope, function(use)
                                    local data = use(_playerData)
                                    return data and data.GamesWon or 0
                                end),
                                Color = PvZTheme.Colors.GrassLight,
                            }),
                            
                            -- Zombies Killed
                            PvZTheme.StatRow(_scope, {
                                Icon = "💀",
                                Label = "Zombies Defeated",
                                Value = Computed(_scope, function(use)
                                    local data = use(_playerData)
                                    return data and data.ZombiesKilled or 0
                                end),
                                Color = PvZTheme.Colors.ButtonRed,
                            }),
                            
                            -- Plants Placed
                            PvZTheme.StatRow(_scope, {
                                Icon = "🌱",
                                Label = "Plants Grown",
                                Value = Computed(_scope, function(use)
                                    local data = use(_playerData)
                                    return data and data.PlantsPlaced or 0
                                end),
                                Color = PvZTheme.Colors.GrassMedium,
                            }),
                        },
                    },
                    
                    -- Win rate
                    New(_scope, "Frame") {
                        Size = UDim2.new(1, -40, 0, 45),
                        Position = UDim2.new(0, 20, 0, 450),
                        BackgroundColor3 = PvZTheme.Colors.WoodDark,
                        
                        [Children] = {
                            New(_scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
                            New(_scope, "UIStroke") { 
                                Color = PvZTheme.Colors.WoodBorder, 
                                Thickness = 2,
                            },
                            New(_scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(_scope, function(use)
                                    local data = use(_playerData)
                                    if not data or data.GamesPlayed == 0 then
                                        return "📈 Win Rate: Play some games!"
                                    end
                                    local rate = math.floor((data.GamesWon / data.GamesPlayed) * 100)
                                    return `📈 Win Rate: {rate}%`
                                end),
                                TextColor3 = PvZTheme.Colors.Gold,
                                TextSize = 20,
                                Font = PvZTheme.Fonts.Numbers,
                                
                                [Children] = {
                                    New(_scope, "UIStroke") {
                                        Color = PvZTheme.Colors.TextShadow,
                                        Thickness = 1.5,
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

-- ============================================
-- PROMPT HANDLERS
-- ============================================
local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
    if player ~= Players.LocalPlayer then return end
    
    closeCurrentUI()
    
    if prompt.Name == "ShopPrompt" then
        Logger.Info("ZoneInteraction", "Opening Shop")
        _currentUI = createShopUI()
        _currentUI.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        
    elseif prompt.Name == "DeckPrompt" then
        Logger.Info("ZoneInteraction", "Opening Deck Builder")
        _currentUI = createDeckBuilderUI()
        _currentUI.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        
    elseif prompt.Name == "ProfilePrompt" then
        Logger.Info("ZoneInteraction", "Opening Profile")
        _currentUI = createProfileUI()
        _currentUI.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
end

-- ============================================
-- PUBLIC API
-- ============================================

function ZoneInteractionController.Initialize()
    Logger.Info("ZoneInteraction", "Initializing ZoneInteractionController")
    ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
end

function ZoneInteractionController.SetPlayerData(data: any)
    _playerData:set(data)
    if data then
        _unlockedPlants:set(data.UnlockedPlants or {})
        _currentDeck:set(data.Deck or {})
    end
end

function ZoneInteractionController.SetOnPurchasePlant(callback: (string) -> ())
    _onPurchasePlant = callback
end

function ZoneInteractionController.SetOnSaveDeck(callback: ({string}) -> ())
    _onSaveDeck = callback
end

function ZoneInteractionController.UpdateUnlockedPlants(plants: {string})
    _unlockedPlants:set(plants)
end

function ZoneInteractionController.UpdateDeck(deck: {string})
    _currentDeck:set(deck)
end

return ZoneInteractionController
