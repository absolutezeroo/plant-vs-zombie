--!strict
--[[
    ProfileView.luau - Player profile and statistics
    
    Displays player level, XP, stats, and achievements.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local PvZTheme = require(ReplicatedStorage.Shared.ui.PvZTheme)

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed

export type ProfileViewProps = {
    PlayerData: any, -- Value<PlayerData?>
    OnBack: () -> (),
}

-- Stat row component
local function StatRow(scope: any, props: {
    Icon: string,
    Label: string,
    Value: any, -- Computed<string>
}): any
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = PvZTheme.Colors.WoodLight,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 8),
            },
            
            -- Icon
            New(scope, "TextLabel") {
                Size = UDim2.new(0, 50, 1, 0),
                BackgroundTransparency = 1,
                Text = props.Icon,
                TextSize = 24,
            },
            
            -- Label
            New(scope, "TextLabel") {
                Size = UDim2.new(0.5, -60, 1, 0),
                Position = UDim2.new(0, 50, 0, 0),
                BackgroundTransparency = 1,
                Text = props.Label,
                TextSize = 18,
                Font = Enum.Font.GothamBold,
                TextColor3 = PvZTheme.Colors.TextDark,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
            
            -- Value
            New(scope, "TextLabel") {
                Size = UDim2.new(0.4, 0, 1, 0),
                Position = UDim2.new(0.6, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = props.Value,
                TextSize = 20,
                Font = Enum.Font.GothamBlack,
                TextColor3 = PvZTheme.Colors.GrassGreen,
                TextXAlignment = Enum.TextXAlignment.Right,
            },
        },
    }
end

return function(scope: any, props: ProfileViewProps)
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = PvZTheme.Colors.SkyBlue,
        
        [Children] = {
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 150, 200)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 100, 150)),
                }),
                Rotation = 90,
            },
            
            -- Back button
            PvZTheme.BackButton(scope, props.OnBack),
            
            -- Header
            PvZTheme.Header(scope, "🏆 Profile"),
            
            -- Main content panel
            New(scope, "Frame") {
                Size = UDim2.new(0.9, 0, 0.75, 0),
                Position = UDim2.new(0.05, 0, 0.12, 0),
                BackgroundColor3 = PvZTheme.Colors.WoodBrown,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 16),
                    },
                    
                    New(scope, "UIStroke") {
                        Color = PvZTheme.Colors.WoodDark,
                        Thickness = 4,
                    },
                    
                    -- Level display (big)
                    New(scope, "Frame") {
                        Size = UDim2.new(0.95, 0, 0, 120),
                        Position = UDim2.new(0.025, 0, 0, 20),
                        BackgroundColor3 = PvZTheme.Colors.GrassGreen,
                        
                        [Children] = {
                            New(scope, "UICorner") {
                                CornerRadius = UDim.new(0, 12),
                            },
                            
                            -- Level number
                            New(scope, "TextLabel") {
                                Size = UDim2.new(0.3, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then `Lv.{data.Level}` else "Lv.1"
                                end),
                                TextSize = 48,
                                Font = Enum.Font.GothamBlack,
                                TextColor3 = PvZTheme.Colors.SunYellow,
                            },
                            
                            -- XP Bar container
                            New(scope, "Frame") {
                                Size = UDim2.new(0.6, 0, 0.4, 0),
                                Position = UDim2.new(0.35, 0, 0.3, 0),
                                BackgroundColor3 = PvZTheme.Colors.WoodDark,
                                
                                [Children] = {
                                    New(scope, "UICorner") {
                                        CornerRadius = UDim.new(0.5, 0),
                                    },
                                    
                                    -- XP Fill
                                    New(scope, "Frame") {
                                        Size = Computed(scope, function(use)
                                            local data = use(props.PlayerData)
                                            if not data then return UDim2.new(0, 0, 1, 0) end
                                            local progress = math.clamp(data.XP / math.max(data.TotalXPForNextLevel, 1), 0, 1)
                                            return UDim2.new(progress, 0, 1, 0)
                                        end),
                                        BackgroundColor3 = PvZTheme.Colors.SunYellow,
                                        
                                        [Children] = {
                                            New(scope, "UICorner") {
                                                CornerRadius = UDim.new(0.5, 0),
                                            },
                                        },
                                    },
                                },
                            },
                            
                            -- XP Text
                            New(scope, "TextLabel") {
                                Size = UDim2.new(0.6, 0, 0.3, 0),
                                Position = UDim2.new(0.35, 0, 0.65, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    if not data then return "XP: 0 / 100" end
                                    return `XP: {data.XP} / {data.TotalXPForNextLevel}`
                                end),
                                TextSize = 16,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = PvZTheme.Colors.TextWhite,
                            },
                        },
                    },
                    
                    -- Currency row
                    New(scope, "Frame") {
                        Size = UDim2.new(0.95, 0, 0, 50),
                        Position = UDim2.new(0.025, 0, 0, 155),
                        BackgroundColor3 = PvZTheme.Colors.WoodLight,
                        
                        [Children] = {
                            New(scope, "UICorner") {
                                CornerRadius = UDim.new(0, 8),
                            },
                            
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                VerticalAlignment = Enum.VerticalAlignment.Center,
                                Padding = UDim.new(0, 40),
                            },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.new(0, 120, 0, 40),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then `💰 {data.Coins}` else "💰 0"
                                end),
                                TextSize = 22,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = PvZTheme.Colors.CoinGold,
                            },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.new(0, 120, 0, 40),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then `💎 {data.Gems}` else "💎 0"
                                end),
                                TextSize = 22,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = PvZTheme.Colors.GemPurple,
                            },
                        },
                    },
                    
                    -- Stats section title
                    New(scope, "TextLabel") {
                        Size = UDim2.new(0.95, 0, 0, 30),
                        Position = UDim2.new(0.025, 0, 0, 220),
                        BackgroundTransparency = 1,
                        Text = "📊 Statistics",
                        TextSize = 20,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = PvZTheme.Colors.TextWhite,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    
                    -- Stats container
                    New(scope, "Frame") {
                        Size = UDim2.new(0.95, 0, 0, 230),
                        Position = UDim2.new(0.025, 0, 0, 255),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Vertical,
                                Padding = UDim.new(0, 8),
                            },
                            
                            StatRow(scope, {
                                Icon = "🎮",
                                Label = "Games Played",
                                Value = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then tostring(data.GamesPlayed) else "0"
                                end),
                            }),
                            
                            StatRow(scope, {
                                Icon = "🏆",
                                Label = "Games Won",
                                Value = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then tostring(data.GamesWon) else "0"
                                end),
                            }),
                            
                            StatRow(scope, {
                                Icon = "💀",
                                Label = "Zombies Killed",
                                Value = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then tostring(data.ZombiesKilled) else "0"
                                end),
                            }),
                            
                            StatRow(scope, {
                                Icon = "🌱",
                                Label = "Plants Placed",
                                Value = Computed(scope, function(use)
                                    local data = use(props.PlayerData)
                                    return if data then tostring(data.PlantsPlaced) else "0"
                                end),
                            }),
                        },
                    },
                    
                    -- Win rate
                    New(scope, "TextLabel") {
                        Size = UDim2.new(0.95, 0, 0, 40),
                        Position = UDim2.new(0.025, 0, 1, -55),
                        BackgroundColor3 = PvZTheme.Colors.Success,
                        Text = Computed(scope, function(use)
                            local data = use(props.PlayerData)
                            if not data or data.GamesPlayed == 0 then
                                return "Win Rate: N/A"
                            end
                            local rate = math.floor((data.GamesWon / data.GamesPlayed) * 100)
                            return `Win Rate: {rate}%`
                        end),
                        TextSize = 18,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = PvZTheme.Colors.TextWhite,
                        
                        [Children] = {
                            New(scope, "UICorner") {
                                CornerRadius = UDim.new(0, 8),
                            },
                        },
                    },
                },
            },
        },
    }
end
