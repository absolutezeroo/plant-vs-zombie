--!strict
--[[
    LobbyHUD.luau - Minimal overlay HUD for lobby
    
    Shows:
    - Player level, coins, gems (top bar)
    - Current deck (bottom bar)
    
    Uses PvZ cartoon style - wooden frames, nature colors, drop shadows.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local PvZTheme = require(ReplicatedStorage.Shared.ui.PvZTheme)

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value

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
    PlayerData: Fusion.Value<PlayerData?>,
    CurrentDeck: Fusion.Value<{string}>,
}): ScreenGui
    
    local playerData = props.PlayerData
    local currentDeck = props.CurrentDeck
    
    return New(scope, "ScreenGui") {
        Name = "LobbyHUD",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        
        [Children] = {
            -- ============================================
            -- LEFT PANEL: Resources & Player Stats (PvZ Style - same as Arena)
            -- ============================================
            PvZTheme.WoodPanel(scope, {
                Name = "ResourcePanel",
                Position = UDim2.new(0, 15, 0, 70),
                Size = UDim2.fromOffset(180, 165),
                Children = {
                    -- Level & XP Row
                    New(scope, "Frame") {
                        Name = "LevelRow",
                        Position = UDim2.fromOffset(10, 10),
                        Size = UDim2.new(1, -20, 0, 40),
                        BackgroundColor3 = PvZTheme.Colors.WoodDark,
                        BackgroundTransparency = 0.5,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
                            New(scope, "TextLabel") {
                                Name = "StarIcon",
                                Position = UDim2.fromOffset(5, 0),
                                Size = UDim2.new(0, 30, 1, 0),
                                BackgroundTransparency = 1,
                                Text = PvZTheme.Icons.Star,
                                TextScaled = true,
                            },
                            PvZTheme.StrokedText(scope, {
                                Position = UDim2.new(0, 38, 0.5, 0),
                                Size = UDim2.new(0, 50, 0.6, 0),
                                AnchorPoint = Vector2.new(0, 0.5),
                                Text = Computed(scope, function(use)
                                    local data = use(playerData)
                                    return "Lv." .. tostring(data and data.Level or 1)
                                end),
                                TextColor3 = PvZTheme.Colors.TextGold,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextSize = 16,
                            }),
                            -- XP Progress Bar
                            PvZTheme.ProgressBar(scope, {
                                Position = UDim2.new(0, 90, 0.5, 0),
                                Size = UDim2.new(1, -100, 0.4, 0),
                                AnchorPoint = Vector2.new(0, 0.5),
                                Current = Computed(scope, function(use)
                                    local data = use(playerData)
                                    return data and data.XP or 0
                                end),
                                Max = Computed(scope, function(use)
                                    local data = use(playerData)
                                    return data and data.TotalXPForNextLevel or 100
                                end),
                                Color = PvZTheme.Colors.XPPurple,
                                ShowText = false,
                            }),
                        },
                    },
                    
                    -- Coins Row
                    New(scope, "Frame") {
                        Name = "CoinsRow",
                        Position = UDim2.fromOffset(10, 55),
                        Size = UDim2.new(1, -20, 0, 40),
                        BackgroundColor3 = PvZTheme.Colors.WoodDark,
                        BackgroundTransparency = 0.5,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
                            New(scope, "TextLabel") {
                                Name = "CoinIcon",
                                Position = UDim2.fromOffset(5, 0),
                                Size = UDim2.new(0, 30, 1, 0),
                                BackgroundTransparency = 1,
                                Text = PvZTheme.Icons.Coin,
                                TextScaled = true,
                            },
                            PvZTheme.StrokedText(scope, {
                                Position = UDim2.new(0, 40, 0.5, 0),
                                Size = UDim2.new(1, -50, 0.7, 0),
                                AnchorPoint = Vector2.new(0, 0.5),
                                Text = Computed(scope, function(use)
                                    local data = use(playerData)
                                    return tostring(data and data.Coins or 0)
                                end),
                                TextColor3 = PvZTheme.Colors.CoinGold,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextSize = 18,
                            }),
                        },
                    },
                    
                    -- Gems Row
                    New(scope, "Frame") {
                        Name = "GemsRow",
                        Position = UDim2.fromOffset(10, 100),
                        Size = UDim2.new(1, -20, 0, 40),
                        BackgroundColor3 = PvZTheme.Colors.WoodDark,
                        BackgroundTransparency = 0.5,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
                            New(scope, "TextLabel") {
                                Name = "GemIcon",
                                Position = UDim2.fromOffset(5, 0),
                                Size = UDim2.new(0, 30, 1, 0),
                                BackgroundTransparency = 1,
                                Text = PvZTheme.Icons.Gem,
                                TextScaled = true,
                            },
                            PvZTheme.StrokedText(scope, {
                                Position = UDim2.new(0, 40, 0.5, 0),
                                Size = UDim2.new(1, -50, 0.7, 0),
                                AnchorPoint = Vector2.new(0, 0.5),
                                Text = Computed(scope, function(use)
                                    local data = use(playerData)
                                    return tostring(data and data.Gems or 0)
                                end),
                                TextColor3 = PvZTheme.Colors.GemCyan,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextSize = 18,
                            }),
                        },
                    },
                },
            }),
            
            -- ============================================
            -- TOP RIGHT: Player name with leaf decoration
            -- ============================================
            New(scope, "Frame") {
                Name = "PlayerBadge",
                Size = UDim2.new(0, 200, 0, 44),
                Position = UDim2.new(1, -215, 0, 15),
                BackgroundColor3 = PvZTheme.Colors.GrassMedium,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 10) },
                    New(scope, "UIStroke") { 
                        Color = PvZTheme.Colors.GrassDark, 
                        Thickness = 3,
                    },
                    
                    New(scope, "TextLabel") {
                        Size = UDim2.new(0, 30, 0, 30),
                        Position = UDim2.new(0, 8, 0.5, -15),
                        BackgroundTransparency = 1,
                        Text = "🌿",
                        TextSize = 24,
                    },
                    
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -45, 1, 0),
                        Position = UDim2.new(0, 38, 0, 0),
                        BackgroundTransparency = 1,
                        Text = Players.LocalPlayer.Name,
                        TextColor3 = PvZTheme.Colors.TextLight,
                        TextSize = 16,
                        Font = PvZTheme.Fonts.Button,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        
                        [Children] = {
                            New(scope, "UIStroke") {
                                Color = PvZTheme.Colors.TextShadow,
                                Thickness = 1,
                            },
                        },
                    },
                },
            },
            
            -- ============================================
            -- BOTTOM BAR (Current Deck Display)
            -- ============================================
            New(scope, "Frame") {
                Name = "BottomBar",
                Size = UDim2.new(0, 560, 0, 85),
                Position = UDim2.new(0.5, -280, 1, -95),
                BackgroundColor3 = PvZTheme.Colors.WoodMedium,
                BackgroundTransparency = 0.1,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 14) },
                    New(scope, "UIStroke") { 
                        Color = PvZTheme.Colors.WoodBorder, 
                        Thickness = 4,
                    },
                    
                    -- Label with plant icon
                    New(scope, "Frame") {
                        Size = UDim2.new(0, 110, 0, 26),
                        Position = UDim2.new(0, 10, 0, 5),
                        BackgroundColor3 = PvZTheme.Colors.GrassMedium,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0, 6) },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "🌱 Your Deck",
                                TextColor3 = PvZTheme.Colors.TextLight,
                                TextSize = 13,
                                Font = PvZTheme.Fonts.Button,
                                
                                [Children] = {
                                    New(scope, "UIStroke") {
                                        Color = PvZTheme.Colors.GrassDark,
                                        Thickness = 1,
                                    },
                                },
                            },
                        },
                    },
                    
                    -- Deck slots container
                    New(scope, "Frame") {
                        Size = UDim2.new(1, -24, 0, 52),
                        Position = UDim2.new(0, 12, 0, 28),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 10),
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                            },
                            
                            -- 6 deck slots
                            (function()
                                local slots = {}
                                for i = 1, 6 do
                                    table.insert(slots, New(scope, "Frame") {
                                        Name = `Slot{i}`,
                                        Size = UDim2.new(0, 80, 0, 52),
                                        BackgroundColor3 = Computed(scope, function(use)
                                            local deck = use(currentDeck)
                                            return if deck[i] 
                                                then PvZTheme.Colors.Owned
                                                else PvZTheme.Colors.WoodDark
                                        end),
                                        
                                        [Children] = {
                                            New(scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
                                            New(scope, "UIStroke") { 
                                                Color = Computed(scope, function(use)
                                                    local deck = use(currentDeck)
                                                    return if deck[i]
                                                        then PvZTheme.Colors.GrassDark
                                                        else PvZTheme.Colors.WoodBorder
                                                end),
                                                Thickness = 2,
                                            },
                                            
                                            -- Plant icon
                                            New(scope, "TextLabel") {
                                                Size = UDim2.new(1, 0, 0, 25),
                                                Position = UDim2.new(0, 0, 0, 3),
                                                BackgroundTransparency = 1,
                                                Text = Computed(scope, function(use)
                                                    local deck = use(currentDeck)
                                                    return if deck[i] then "🌱" else "➕"
                                                end),
                                                TextSize = 20,
                                                TextTransparency = Computed(scope, function(use)
                                                    local deck = use(currentDeck)
                                                    return if deck[i] then 0 else 0.7
                                                end),
                                            },
                                            
                                            -- Plant name
                                            New(scope, "TextLabel") {
                                                Size = UDim2.new(1, -6, 0, 22),
                                                Position = UDim2.new(0, 3, 0, 27),
                                                BackgroundTransparency = 1,
                                                Text = Computed(scope, function(use)
                                                    local deck = use(currentDeck)
                                                    if deck[i] then
                                                        local name = deck[i]
                                                        if #name > 9 then
                                                            name = name:sub(1, 8) .. ".."
                                                        end
                                                        return name
                                                    end
                                                    return ""
                                                end),
                                                TextColor3 = Computed(scope, function(use)
                                                    local deck = use(currentDeck)
                                                    return if deck[i]
                                                        then PvZTheme.Colors.TextDark
                                                        else PvZTheme.Colors.Locked
                                                end),
                                                TextSize = 10,
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
        },
    }
end

return LobbyHUD
