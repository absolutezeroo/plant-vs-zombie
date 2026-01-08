--!strict
--[[
    ProfileView.luau - Player profile and statistics
    
    Modern profile with avatar, dynamic title, and grid stats.
    Uses ModernTheme for consistent dark UI style.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModernTheme = require(Shared.ui.ModernTheme)

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local OnEvent = Fusion.OnEvent

local Colors = ModernTheme.Colors
local Fonts = ModernTheme.Fonts
local Sizing = ModernTheme.Sizing

export type ProfileViewProps = {
    PlayerData: any, -- Value<PlayerData?>
    OnBack: () -> (),
}

-- Get dynamic title based on level
local function getTitleForLevel(level: number): string
    if level >= 50 then return "🌟 Legendary Guardian"
    elseif level >= 40 then return "👑 Master Gardener"
    elseif level >= 30 then return "⚔️ Zombie Slayer"
    elseif level >= 20 then return "🛡️ Plant Defender"
    elseif level >= 10 then return "🌿 Garden Keeper"
    elseif level >= 5 then return "🌱 Sprout Tender"
    else return "🌰 Novice Gardener"
    end
end

-- Stat card for 2x2 grid
local function StatCard(scope: any, props: {
    Icon: string,
    Label: string,
    Value: any,
    Color: Color3?,
}): any
    return New(scope, "Frame") {
        Size = UDim2.new(0.5, -8, 0, 90),
        BackgroundColor3 = Colors.Card,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
            New(scope, "UIStroke") { Color = Colors.Border, Thickness = 1 },
            
            -- Icon
            New(scope, "TextLabel") {
                Size = UDim2.fromOffset(40, 40),
                Position = UDim2.fromOffset(12, 12),
                BackgroundTransparency = 1,
                Text = props.Icon,
                TextSize = 28,
            },
            
            -- Value (big number)
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -20, 0, 36),
                Position = UDim2.new(0, 10, 1, -42),
                BackgroundTransparency = 1,
                Text = props.Value,
                TextSize = 28,
                Font = Fonts.Title,
                TextColor3 = props.Color or Colors.Gold,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
            
            -- Label
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -60, 0, 24),
                Position = UDim2.fromOffset(54, 18),
                BackgroundTransparency = 1,
                Text = props.Label,
                TextSize = 13,
                Font = Fonts.Body,
                TextColor3 = Colors.TextMuted,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
        },
    }
end

return function(scope: any, props: ProfileViewProps)
    local player = Players.LocalPlayer
    
    -- Get avatar thumbnail
    local avatarUrl = Players:GetUserThumbnailAsync(
        player.UserId,
        Enum.ThumbnailType.HeadShot,
        Enum.ThumbnailSize.Size150x150
    )
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.Background,
        
        [Children] = {
            -- Header with avatar, name, title, and resources
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 120),
                BackgroundColor3 = Colors.Card,
                
                [Children] = {
                    New(scope, "UIGradient") {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 45, 60)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 42)),
                        }),
                        Rotation = 90,
                    },
                    
                    -- Avatar
                    New(scope, "ImageLabel") {
                        Size = UDim2.fromOffset(80, 80),
                        Position = UDim2.fromOffset(20, 20),
                        BackgroundColor3 = Colors.BackgroundLighter,
                        Image = avatarUrl,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "UIStroke") { Color = Colors.Gold, Thickness = 3 },
                        },
                    },
                    
                    -- Player name
                    New(scope, "TextLabel") {
                        Size = UDim2.new(0.5, 0, 0, 32),
                        Position = UDim2.fromOffset(115, 22),
                        BackgroundTransparency = 1,
                        Text = player.DisplayName,
                        TextSize = 24,
                        Font = Fonts.Title,
                        TextColor3 = Colors.TextWhite,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    
                    -- Dynamic title
                    New(scope, "TextLabel") {
                        Size = UDim2.new(0.5, 0, 0, 24),
                        Position = UDim2.fromOffset(115, 52),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            local data = use(props.PlayerData)
                            local level = if data then data.Level else 1
                            return getTitleForLevel(level)
                        end),
                        TextSize = 14,
                        Font = Fonts.Body,
                        TextColor3 = Colors.Success,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    
                    -- Resources (coins + gems)
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(200, 36),
                        Position = UDim2.fromOffset(115, 78),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 12),
                            },
                            
                            ModernTheme.ResourcePill(scope, {
                                Icon = "💰",
                                Value = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then tostring(data.Coins) else "0"
                                end),
                                Color = Colors.Coins,
                            }),
                            
                            ModernTheme.ResourcePill(scope, {
                                Icon = "💎",
                                Value = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then tostring(data.Gems) else "0"
                                end),
                                Color = Colors.Gems,
                            }),
                        },
                    },
                    
                    -- Close button (RIGHT side)
                    New(scope, "TextButton") {
                        Size = UDim2.fromOffset(44, 44),
                        Position = UDim2.new(1, -15, 0, 15),
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundColor3 = Colors.BackgroundLighter,
                        Text = "✕",
                        TextSize = 20,
                        Font = Fonts.Title,
                        TextColor3 = Colors.TextMuted,
                        
                        [OnEvent "Activated"] = props.OnBack,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                        },
                    },
                },
            },
            
            -- Main content
            New(scope, "ScrollingFrame") {
                Size = UDim2.new(1, -32, 1, -140),
                Position = UDim2.fromOffset(16, 130),
                BackgroundTransparency = 1,
                ScrollBarThickness = 4,
                ScrollBarImageColor3 = Colors.Border,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                
                [Children] = {
                    New(scope, "UIListLayout") {
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = UDim.new(0, 16),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    },
                    
                    -- Level Card (hero element)
                    New(scope, "Frame") {
                        Size = UDim2.new(1, 0, 0, 100),
                        BackgroundColor3 = Colors.Card,
                        LayoutOrder = 1,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = Sizing.RadiusLarge },
                            New(scope, "UIStroke") { Color = Colors.Success, Thickness = 2 },
                            New(scope, "UIGradient") {
                                Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 60, 40)),
                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 45, 30)),
                                }),
                                Rotation = 45,
                            },
                            
                            -- Level badge
                            New(scope, "Frame") {
                                Size = UDim2.fromOffset(70, 70),
                                Position = UDim2.fromOffset(20, 15),
                                BackgroundColor3 = Colors.Success,
                                
                                [Children] = {
                                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                                    New(scope, "UIStroke") { Color = Colors.Gold, Thickness = 3 },
                                    
                                    New(scope, "TextLabel") {
                                        Size = UDim2.new(1, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = Computed(scope, function(use)
                                            local data = use(props.PlayerData)
                                            return if data then tostring(data.Level) else "1"
                                        end),
                                        TextSize = 32,
                                        Font = Fonts.Title,
                                        TextColor3 = Colors.TextWhite,
                                    },
                                },
                            },
                            
                            -- Level info
                            New(scope, "TextLabel") {
                                Size = UDim2.fromOffset(100, 24),
                                Position = UDim2.fromOffset(105, 18),
                                BackgroundTransparency = 1,
                                Text = "LEVEL",
                                TextSize = 12,
                                Font = Fonts.Header,
                                TextColor3 = Colors.TextMuted,
                                TextXAlignment = Enum.TextXAlignment.Left,
                            },
                            
                            -- XP bar background
                            New(scope, "Frame") {
                                Size = UDim2.new(1, -125, 0, 24),
                                Position = UDim2.fromOffset(105, 42),
                                BackgroundColor3 = Colors.BackgroundLighter,
                                
                                [Children] = {
                                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                                    
                                    -- XP fill
                                    New(scope, "Frame") {
                                        Size = Computed(scope, function(use)
                                            local data = use(props.PlayerData)
                                            if not data then return UDim2.new(0, 0, 1, 0) end
                                            local progress = math.clamp(data.XP / math.max(data.TotalXPForNextLevel, 1), 0, 1)
                                            return UDim2.new(progress, 0, 1, 0)
                                        end),
                                        BackgroundColor3 = Colors.XP,
                                        
                                        [Children] = {
                                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                                            New(scope, "UIGradient") {
                                                Color = ColorSequence.new({
                                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 100, 255)),
                                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 130, 255)),
                                                }),
                                            },
                                        },
                                    },
                                    
                                    -- XP text overlay
                                    New(scope, "TextLabel") {
                                        Size = UDim2.new(1, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = Computed(scope, function(use)
                                            local data = use(props.PlayerData)
                                            if not data then return "0 / 100 XP" end
                                            return `{data.XP} / {data.TotalXPForNextLevel} XP`
                                        end),
                                        TextSize = 12,
                                        Font = Fonts.Header,
                                        TextColor3 = Colors.TextWhite,
                                    },
                                },
                            },
                        },
                    },
                    
                    -- Stats Grid (2x2)
                    New(scope, "Frame") {
                        Size = UDim2.new(1, 0, 0, 200),
                        BackgroundTransparency = 1,
                        LayoutOrder = 2,
                        
                        [Children] = {
                            -- Row 1
                            New(scope, "Frame") {
                                Size = UDim2.new(1, 0, 0, 90),
                                BackgroundTransparency = 1,
                                
                                [Children] = {
                                    New(scope, "UIListLayout") {
                                        FillDirection = Enum.FillDirection.Horizontal,
                                        Padding = UDim.new(0, 16),
                                    },
                                    
                                    StatCard(scope, {
                                        Icon = "🎮",
                                        Label = "Games",
                                        Value = Computed(scope, function(use)
                                            local data = use(props.PlayerData)
                                            return if data then tostring(data.GamesPlayed) else "0"
                                        end),
                                        Color = Colors.TextWhite,
                                    }),
                                    
                                    StatCard(scope, {
                                        Icon = "🏆",
                                        Label = "Wins",
                                        Value = Computed(scope, function(use)
                                            local data = use(props.PlayerData)
                                            return if data then tostring(data.GamesWon) else "0"
                                        end),
                                        Color = Colors.Gold,
                                    }),
                                },
                            },
                            
                            -- Row 2
                            New(scope, "Frame") {
                                Size = UDim2.new(1, 0, 0, 90),
                                Position = UDim2.fromOffset(0, 106),
                                BackgroundTransparency = 1,
                                
                                [Children] = {
                                    New(scope, "UIListLayout") {
                                        FillDirection = Enum.FillDirection.Horizontal,
                                        Padding = UDim.new(0, 16),
                                    },
                                    
                                    StatCard(scope, {
                                        Icon = "💀",
                                        Label = "Kills",
                                        Value = Computed(scope, function(use)
                                            local data = use(props.PlayerData)
                                            return if data then tostring(data.ZombiesKilled) else "0"
                                        end),
                                        Color = Colors.Error,
                                    }),
                                    
                                    StatCard(scope, {
                                        Icon = "🌱",
                                        Label = "Plants",
                                        Value = Computed(scope, function(use)
                                            local data = use(props.PlayerData)
                                            return if data then tostring(data.PlantsPlaced) else "0"
                                        end),
                                        Color = Colors.Success,
                                    }),
                                },
                            },
                        },
                    },
                    
                    -- Win Rate Banner
                    New(scope, "Frame") {
                        Size = UDim2.new(1, 0, 0, 60),
                        BackgroundColor3 = Computed(scope, function(use)
                            local data = use(props.PlayerData)
                            if not data or data.GamesPlayed == 0 then return Colors.Card end
                            local rate = data.GamesWon / data.GamesPlayed
                            if rate >= 0.7 then return Color3.fromRGB(50, 80, 50)
                            elseif rate >= 0.4 then return Color3.fromRGB(80, 70, 40)
                            else return Color3.fromRGB(80, 50, 50) end
                        end),
                        LayoutOrder = 3,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                            New(scope, "UIStroke") {
                                Color = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    if not data or data.GamesPlayed == 0 then return Colors.Border end
                                    local rate = data.GamesWon / data.GamesPlayed
                                    if rate >= 0.7 then return Colors.Success
                                    elseif rate >= 0.4 then return Colors.Warning
                                    else return Colors.Error end
                                end),
                                Thickness = 2,
                            },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    if not data or data.GamesPlayed == 0 then
                                        return "🎯 Win Rate: Play some games!"
                                    end
                                    local rate = math.floor((data.GamesWon / data.GamesPlayed) * 100)
                                    local emoji = if rate >= 70 then "🔥" elseif rate >= 40 then "👍" else "💪"
                                    return `{emoji} Win Rate: {rate}%`
                                end),
                                TextSize = 18,
                                Font = Fonts.Header,
                                TextColor3 = Colors.TextWhite,
                            },
                        },
                    },
                },
            },
        },
    }
end
