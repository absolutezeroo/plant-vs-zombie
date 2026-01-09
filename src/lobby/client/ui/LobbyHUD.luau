--!strict
--[[
    LobbyHUD.luau - Casual Mobile HUD
    
    Modern Mobile Casual UI with glossy cartoon finish:
    - Player resources (top-left squircle pills)
    - Player avatar & level badge (top-left)
    - Current deck preview (bottom bar with UnitCards)
    
    Design: Squircle shapes, vibrant colors, thick strokes, juicy animations
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CasualTheme = require(Shared.ui.CasualTheme)

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value

-- Use CasualTheme colors
local Colors = CasualTheme.Colors
local Sizing = CasualTheme.Sizing
local Fonts = CasualTheme.Fonts

-- Theme component shortcuts
local UnitCard = CasualTheme.UnitCard
local ResourcePill = CasualTheme.ResourcePill
local LevelBadge = CasualTheme.LevelBadge
local DeckBar = CasualTheme.DeckBar
local AvatarFrame = CasualTheme.AvatarFrame

-- Plant cost data (for demo - normally from PlantData)
local PlantCosts: {[string]: number} = {
    Peashooter = 100, Sunflower = 50, WallNut = 50,
    PotatoMine = 25, SnowPea = 175, Repeater = 200,
    CherryBomb = 150, Chomper = 150, Jalapeno = 125,
    TallNut = 125, Squash = 50, ThreePeater = 325,
    TorchWood = 175, Spikeweed = 100, Pumpkin = 125,
    Starfruit = 125, MagnifyingGrass = 50, CattailPlant = 225,
    CobCannon = 500, Bonkchoy = 150, Snapdragon = 150,
    IceBerg = 75, SunShroom = 25, Cactus = 125,
}

local function getPlantCost(plantType: string?): number
    if not plantType then return 0 end
    return PlantCosts[plantType] or 100
end

export type PlayerData = {
    Coins: number,
    Gems: number,
    Level: number,
    XP: number,
    TotalXPForNextLevel: number,
    GamesPlayed: number,
    GamesWon: number,
    ZombiesKilled: number,
    PlantsPlaced: number,
    UnlockedPlants: {string},
    Deck: {string},
}

local function LobbyHUD(scope: any, props: {
    PlayerData: any, -- Value<PlayerData?>
    CurrentDeck: any, -- Value<{string}>
    EquippedMutations: any?, -- Value<{[string]: {string}}>?
    SelectedSlot: any?, -- Value<number?>
}): ScreenGui
    
    local playerData = props.PlayerData
    local currentDeck = props.CurrentDeck
    local currentSelectedSlot = props.SelectedSlot or Value(scope, 2) -- Default: slot 2 selected
    
    return New(scope, "ScreenGui") {
        Name = "LobbyHUD",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        
        [Children] = {
            -- ============================================
            -- TOP LEFT: Avatar + Level Badge (like reference image)
            -- Avatar circle with star badge extending to the right
            -- ============================================
            New(scope, "Frame") {
                Name = "PlayerInfo",
                Size = UDim2.fromOffset(180, 80),
                Position = UDim2.fromOffset(16, 16),
                BackgroundTransparency = 1,
                
                [Children] = {
                    -- Avatar frame (light blue circle)
                    AvatarFrame(scope, {
                        UserId = Players.LocalPlayer.UserId,
                        Size = UDim2.fromOffset(70, 70),
                    }),
                    
                    -- Level badge (extending from avatar, like in image)
                    New(scope, "Frame") {
                        Name = "LevelBadge",
                        Size = UDim2.fromOffset(90, 36),
                        Position = UDim2.fromOffset(50, 20), -- Overlaps avatar on right
                        BackgroundColor3 = Colors.LevelBadgeBg, -- Light blue
                        BackgroundTransparency = 0, -- OPAQUE
                        ZIndex = 4,
                        
                        [Children] = {
                            New(scope, "UICorner") { 
                                CornerRadius = UDim.new(0, 18), -- Pill-like
                            },
                            New(scope, "UIStroke") { 
                                Color = Colors.StrokeDark, 
                                Thickness = Sizing.StrokeThick,
                            },
                            
                            -- Glossy gradient - COLOR ONLY
                            New(scope, "UIGradient") {
                                Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                                    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 248, 255)),
                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 210, 230)),
                                }),
                                Rotation = 90,
                            },
                            
                            -- Star icon (positioned on left, slightly rotated)
                            New(scope, "Frame") {
                                Name = "Star",
                                Size = UDim2.fromOffset(32, 32),
                                Position = UDim2.fromOffset(-6, 2),
                                BackgroundColor3 = Colors.LevelBadge, -- Golden yellow
                                BackgroundTransparency = 0, -- OPAQUE
                                Rotation = 15,
                                ZIndex = 6,
                                
                                [Children] = {
                                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 6) },
                                    New(scope, "UIStroke") { 
                                        Color = Colors.StrokeDark, 
                                        Thickness = 3,
                                    },
                                    -- Glossy star - COLOR ONLY
                                    New(scope, "UIGradient") {
                                        Color = ColorSequence.new({
                                            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 180)),
                                            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 100)),
                                            ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 180, 60)),
                                        }),
                                        Rotation = 90,
                                    },
                                    New(scope, "TextLabel") {
                                        Size = UDim2.new(1, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = "⭐",
                                        TextSize = 18,
                                        Rotation = -15, -- Counter-rotate
                                    },
                                },
                            },
                            
                            -- Level text "Lv 15"
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, -28, 1, 0),
                                Position = UDim2.fromOffset(28, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    local data = use(playerData)
                                    return "Lv " .. tostring(data and data.Level or 15)
                                end),
                                TextColor3 = Colors.TextWhite,
                                TextSize = 16,
                                Font = Fonts.Header,
                                TextXAlignment = Enum.TextXAlignment.Center,
                                
                                [Children] = {
                                    New(scope, "UIStroke") {
                                        Color = Colors.TextShadow,
                                        Thickness = 1,
                                        Transparency = 0.3,
                                    },
                                },
                            },
                        },
                    },
                },
            },
            
            -- ============================================
            -- TOP RIGHT: Coins & Gems Pills (from image)
            -- ============================================
            New(scope, "Frame") {
                Name = "ResourceBar",
                Size = UDim2.fromOffset(280, 50),
                Position = UDim2.new(1, -20, 0, 20),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                
                [Children] = {
                    New(scope, "UIListLayout") {
                        FillDirection = Enum.FillDirection.Horizontal,
                        Padding = UDim.new(0, 12),
                        HorizontalAlignment = Enum.HorizontalAlignment.Right,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                    },
                    
                    -- Coins pill (gold/yellow like in image)
                    ResourcePill(scope, {
                        Icon = "🪙",
                        Value = Computed(scope, function(use)
                            local data = use(playerData)
                            return tostring(data and data.Coins or 1250)
                        end),
                        Color = Colors.TextWhite,
                        BackgroundColor = Colors.CoinsPill,
                    }),
                    
                    -- Gems pill (purple/magenta like in image)
                    ResourcePill(scope, {
                        Icon = "💎",
                        Value = Computed(scope, function(use)
                            local data = use(playerData)
                            return tostring(data and data.Gems or 50)
                        end),
                        Color = Colors.TextWhite,
                        BackgroundColor = Colors.GemsPill,
                    }),
                },
            },
            
            -- ============================================
            -- BOTTOM: Unit Deck Bar (main feature)
            -- ============================================
            DeckBar(scope, {
                Children = (function()
                    local cards = {}
                    for i = 1, 6 do
                        local plantType = Computed(scope, function(use)
                            local deck = use(currentDeck)
                            return deck[i]
                        end)
                        
                        local cost = Computed(scope, function(use)
                            local deck = use(currentDeck)
                            local plant = deck[i]
                            return getPlantCost(plant)
                        end)
                        
                        local isSelected = Computed(scope, function(use)
                            return use(currentSelectedSlot) == i
                        end)
                        
                        table.insert(cards, UnitCard(scope, {
                            PlantType = plantType,
                            Cost = cost,
                            SlotIndex = i,
                            IsSelected = isSelected,
                            Hotkey = tostring(i),
                            OnClick = function()
                                currentSelectedSlot:set(i)
                            end,
                        }))
                    end
                    return cards
                end)(),
            }),
        },
    }
end

return LobbyHUD
