--!strict
--[[
    LobbyHUD.luau - Modern Lobby HUD
    
    Minimal, clean overlay showing:
    - Player resources (top-left pills)
    - Current deck preview (bottom bar)
    
    Dark modern style matching ShopView/DeckBuilderView.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModernTheme = require(Shared.ui.ModernTheme)

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed

-- Use shared theme colors with local aliases for convenience
local ThemeColors = ModernTheme.Colors
local Colors = {
    PanelBg = ThemeColors.BackgroundLight,
    PanelBgLight = ThemeColors.PanelLight,
    SlotEmpty = ThemeColors.SlotEmpty,
    SlotFilled = ThemeColors.SlotFilled,
    Gold = ThemeColors.Coins,
    Cyan = ThemeColors.XP,
    Purple = ThemeColors.Gems,
    Green = ThemeColors.SuccessLight,
    TextWhite = ThemeColors.TextWhite,
    TextMuted = ThemeColors.TextMuted,
    Border = ThemeColors.Border,
}

-- Use shared emoji functions from ModernTheme
local getPlantEmoji = ModernTheme.GetPlantEmoji
local getMutationEmoji = ModernTheme.GetMutationEmoji

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

-- Resource pill component
local function ResourcePill(scope: any, props: {
    Icon: string,
    Value: any, -- Computed<string>
    Color: Color3,
}): Frame
    return New(scope, "Frame") {
        Size = UDim2.fromOffset(110, 38),
        BackgroundColor3 = Colors.PanelBg,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0, 19) },
            New(scope, "UIStroke") { Color = Colors.Border, Thickness = 2 },
            
            New(scope, "TextLabel") {
                Size = UDim2.fromOffset(30, 38),
                Position = UDim2.fromOffset(6, 0),
                BackgroundTransparency = 1,
                Text = props.Icon,
                TextSize = 20,
            },
            
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -42, 1, 0),
                Position = UDim2.fromOffset(36, 0),
                BackgroundTransparency = 1,
                Text = props.Value,
                TextColor3 = props.Color,
                TextSize = 16,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
        },
    }
end

-- Deck slot component
local function DeckSlot(scope: any, props: {
    Index: number,
    PlantType: any, -- Computed<string?>
    Mutations: any, -- Computed<{string}?>
}): Frame
    return New(scope, "Frame") {
        Size = UDim2.fromOffset(80, 78),
        BackgroundColor3 = Computed(scope, function(use)
            local plant = use(props.PlantType)
            return if plant then Colors.SlotFilled else Colors.SlotEmpty
        end),
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
            New(scope, "UIStroke") { 
                Color = Computed(scope, function(use)
                    local plant = use(props.PlantType)
                    local mutations = use(props.Mutations)
                    local hasMutation = mutations and #mutations > 0
                    if hasMutation then return Color3.fromRGB(255, 150, 50) end
                    return if plant then Colors.Green else Colors.Border
                end),
                Thickness = Computed(scope, function(use)
                    local mutations = use(props.Mutations)
                    return if mutations and #mutations > 0 then 3 else 2
                end),
            },
            
            -- Mutation badge
            Computed(scope, function(use)
                local mutations = use(props.Mutations)
                if mutations and #mutations > 0 then
                    return New(scope, "Frame") {
                        Size = UDim2.fromOffset(22, 22),
                        Position = UDim2.new(1, -4, 0, 4),
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 100, 50),
                        ZIndex = 6,
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = getMutationEmoji(mutations[1]),
                                TextSize = 12,
                            },
                        },
                    }
                end
                return nil
            end),
            
            -- Slot number
            New(scope, "TextLabel") {
                Size = UDim2.fromOffset(18, 18),
                Position = UDim2.fromOffset(4, 4),
                BackgroundColor3 = Colors.PanelBg,
                Text = tostring(props.Index),
                TextColor3 = Colors.TextMuted,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                [Children] = { New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) } },
            },
            
            -- Plant emoji or +
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 36),
                Position = UDim2.fromOffset(0, 20),
                BackgroundTransparency = 1,
                Text = Computed(scope, function(use)
                    local plant = use(props.PlantType)
                    return if plant then getPlantEmoji(plant) else "+"
                end),
                TextSize = Computed(scope, function(use)
                    local plant = use(props.PlantType)
                    return if plant then 28 else 32
                end),
                TextColor3 = Computed(scope, function(use)
                    local plant = use(props.PlantType)
                    return if plant then Colors.TextWhite else Colors.TextMuted
                end),
                TextTransparency = Computed(scope, function(use)
                    local plant = use(props.PlantType)
                    return if plant then 0 else 0.5
                end),
            },
            
            -- Plant name
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -8, 0, 18),
                Position = UDim2.new(0, 4, 1, -20),
                BackgroundTransparency = 1,
                Text = Computed(scope, function(use)
                    local plant = use(props.PlantType)
                    if plant then
                        return if #plant > 9 then plant:sub(1, 8) .. "." else plant
                    end
                    return ""
                end),
                TextColor3 = Colors.TextWhite,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextTruncate = Enum.TextTruncate.AtEnd,
            },
        },
    }
end

local function LobbyHUD(scope: any, props: {
    PlayerData: Fusion.Value<PlayerData?>,
    CurrentDeck: Fusion.Value<{string}>,
    EquippedMutations: Fusion.Value<{[string]: {string}}>?,
}): ScreenGui
    
    local playerData = props.PlayerData
    local currentDeck = props.CurrentDeck
    local plantMutations = props.EquippedMutations -- Renamed for HUD display
    
    return New(scope, "ScreenGui") {
        Name = "LobbyHUD",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        
        [Children] = {
            -- ============================================
            -- TOP LEFT: Resource Pills
            -- ============================================
            New(scope, "Frame") {
                Name = "ResourceBar",
                Size = UDim2.fromOffset(360, 45),
                Position = UDim2.fromOffset(15, 50),
                BackgroundTransparency = 1,
                
                [Children] = {
                    New(scope, "UIListLayout") {
                        FillDirection = Enum.FillDirection.Horizontal,
                        Padding = UDim.new(0, 10),
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                    },
                    
                    -- Level pill
                    ResourcePill(scope, {
                        Icon = "⭐",
                        Value = Computed(scope, function(use)
                            local data = use(playerData)
                            return "Lv." .. tostring(data and data.Level or 1)
                        end),
                        Color = Colors.Purple,
                    }),
                    
                    -- Coins pill
                    ResourcePill(scope, {
                        Icon = "🪙",
                        Value = Computed(scope, function(use)
                            local data = use(playerData)
                            return tostring(data and data.Coins or 0)
                        end),
                        Color = Colors.Gold,
                    }),
                    
                    -- Gems pill
                    ResourcePill(scope, {
                        Icon = "💎",
                        Value = Computed(scope, function(use)
                            local data = use(playerData)
                            return tostring(data and data.Gems or 0)
                        end),
                        Color = Colors.Cyan,
                    }),
                },
            },
            
            -- ============================================
            -- TOP RIGHT: Player Badge
            -- ============================================
            New(scope, "Frame") {
                Name = "PlayerBadge",
                Size = UDim2.fromOffset(180, 42),
                Position = UDim2.new(1, -195, 0, 50),
                BackgroundColor3 = Colors.PanelBg,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 21) },
                    New(scope, "UIStroke") { Color = Colors.Border, Thickness = 2 },
                    
                    New(scope, "TextLabel") {
                        Size = UDim2.fromOffset(28, 28),
                        Position = UDim2.fromOffset(8, 7),
                        BackgroundTransparency = 1,
                        Text = "🌿",
                        TextSize = 20,
                    },
                    
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -48, 1, 0),
                        Position = UDim2.fromOffset(38, 0),
                        BackgroundTransparency = 1,
                        Text = Players.LocalPlayer.Name,
                        TextColor3 = Colors.TextWhite,
                        TextSize = 14,
                        Font = Enum.Font.GothamBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                    },
                },
            },
            
            -- ============================================
            -- BOTTOM: Deck Preview Bar
            -- ============================================
            New(scope, "Frame") {
                Name = "DeckBar",
                Size = UDim2.fromOffset(600, 100),
                Position = UDim2.new(0.5, 0, 1, -20),
                AnchorPoint = Vector2.new(0.5, 1),
                BackgroundColor3 = Colors.PanelBg,
                BackgroundTransparency = 0.1,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 18) },
                    New(scope, "UIStroke") { Color = Colors.Border, Thickness = 2 },
                    
                    -- Deck slots
                    New(scope, "Frame") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 14),
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                VerticalAlignment = Enum.VerticalAlignment.Center,
                            },
                            
                            -- 6 slots
                            (function()
                                local slots = {}
                                for i = 1, 6 do
                                    table.insert(slots, DeckSlot(scope, {
                                        Index = i,
                                        PlantType = Computed(scope, function(use)
                                            local deck = use(currentDeck)
                                            return deck[i]
                                        end),
                                        Mutations = Computed(scope, function(use)
                                            local deck = use(currentDeck)
                                            local plant = deck[i]
                                            if plant and plantMutations then
                                                local mutations = use(plantMutations)
                                                return mutations[plant]
                                            end
                                            return nil
                                        end),
                                    }))
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
