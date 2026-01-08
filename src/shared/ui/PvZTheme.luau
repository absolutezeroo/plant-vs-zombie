--!strict
--[[
    PvZTheme.luau - Unified Plants vs Zombies Theme System
    Shared between Arena and Lobby for consistent visual style
    
    Usage:
        local PvZTheme = require(shared.ui.PvZTheme)
        local panel = PvZTheme.WoodPanel(scope, {...})
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed

-- ============================================
-- COLOR PALETTE
-- Unified color scheme for PvZ style
-- ============================================
local Colors = {
    -- Wood/UI colors
    WoodLight = Color3.fromRGB(210, 180, 140),
    WoodMedium = Color3.fromRGB(185, 140, 90),
    WoodDark = Color3.fromRGB(139, 90, 43),
    WoodBorder = Color3.fromRGB(101, 67, 33),
    WoodBrown = Color3.fromRGB(139, 90, 43),  -- Alias for WoodDark
    
    -- Grass/Nature colors
    GrassLight = Color3.fromRGB(124, 252, 0),
    GrassMedium = Color3.fromRGB(50, 205, 50),
    GrassDark = Color3.fromRGB(34, 139, 34),
    GrassGreen = Color3.fromRGB(76, 175, 80),
    LeafGreen = Color3.fromRGB(56, 142, 60),
    
    -- Currency & Resource colors
    SunYellow = Color3.fromRGB(255, 220, 0),
    SunOrange = Color3.fromRGB(255, 180, 0),
    Coins = Color3.fromRGB(255, 215, 0),
    CoinGold = Color3.fromRGB(255, 193, 7),
    Gems = Color3.fromRGB(138, 43, 226),
    GemCyan = Color3.fromRGB(0, 229, 255),
    XP = Color3.fromRGB(0, 191, 255),
    XPPurple = Color3.fromRGB(156, 39, 176),
    
    -- Text colors
    TextLight = Color3.fromRGB(255, 255, 240),
    TextWhite = Color3.fromRGB(255, 255, 255),
    TextDark = Color3.fromRGB(61, 43, 31),
    TextShadow = Color3.fromRGB(40, 26, 13),
    TextGold = Color3.fromRGB(255, 220, 100),
    
    -- Health colors
    HealthRed = Color3.fromRGB(244, 67, 54),
    HealthGreen = Color3.fromRGB(76, 175, 80),
    
    -- State colors
    Danger = Color3.fromRGB(220, 20, 60),
    Success = Color3.fromRGB(50, 205, 50),
    Warning = Color3.fromRGB(255, 165, 0),
    Locked = Color3.fromRGB(100, 90, 80),
    Owned = Color3.fromRGB(100, 170, 90),
    Selected = Color3.fromRGB(255, 220, 100),
    Disabled = Color3.fromRGB(100, 100, 100),
    
    -- Button colors
    ButtonGreen = Color3.fromRGB(80, 180, 60),
    ButtonGreenHover = Color3.fromRGB(100, 200, 80),
    ButtonRed = Color3.fromRGB(200, 70, 60),
    ButtonRedHover = Color3.fromRGB(220, 90, 80),
    ButtonBlue = Color3.fromRGB(70, 140, 200),
    
    -- Legacy colors (compatibility)
    Gold = Color3.fromRGB(255, 200, 50),
    GoldDark = Color3.fromRGB(200, 150, 30),
    PanelBg = Color3.fromRGB(180, 130, 80),
    PanelBorder = Color3.fromRGB(100, 70, 40),
    DarkOverlay = Color3.fromRGB(20, 15, 10),
    OverlayDark = Color3.fromRGB(0, 0, 0),
    Victory = Color3.fromRGB(255, 215, 0),
    Defeat = Color3.fromRGB(139, 0, 0),
    
    -- Special colors
    Sky = Color3.fromRGB(135, 206, 235),
    SkyBlue = Color3.fromRGB(135, 206, 235),
    Night = Color3.fromRGB(25, 25, 112),
    Zombie = Color3.fromRGB(74, 111, 71),
}

-- ============================================
-- FONTS
-- Consistent typography
-- ============================================
local Fonts = {
    Title = Enum.Font.FredokaOne,
    Header = Enum.Font.GothamBold,
    Button = Enum.Font.GothamBold,
    Body = Enum.Font.Gotham,
    Numbers = Enum.Font.GothamBold,
}

-- ============================================
-- ICONS
-- Emoji icons for various game elements
-- ============================================
local Icons = {
    Sun = "☀️",
    Coin = "💴",
    Gem = "💎",
    XP = "⭐",
    Plant = "🌱",
    Zombie = "🧟",
    Heart = "❤️",
    Shield = "🛡️",
    Sword = "⚔️",
    Star = "⭐",
    Lock = "🔒",
    Check = "✓",
    Trophy = "🏆",
    Fire = "🔥",
    Lightning = "⚡",
    Clock = "⏰",
    Warning = "⚠️",
    Player = "👤",
    Players = "👥",
    Wave = "🌊",
    Shop = "🛒",
    Skull = "💀",
    Arrow = "➤",
    PlantFood = "🌟",
    Map = "🗺️",
}

-- ============================================
-- THEME MODULE
-- ============================================
local PvZTheme = {
    Colors = Colors,
    Fonts = Fonts,
    Icons = Icons,
}

-- ============================================
-- WOOD PANEL COMPONENT
-- Main container with wood texture feel
-- ============================================
function PvZTheme.WoodPanel(scope: any, props: {
    Size: UDim2,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    Children: any?,
    Variant: ("light" | "medium" | "dark")?,
    Padding: UDim?,
    CornerRadius: UDim?,
}): Frame
    local variant = props.Variant or "medium"
    local bgColor = if variant == "light" then Colors.WoodLight
        elseif variant == "dark" then Colors.WoodDark
        else Colors.WoodMedium
    
    return New(scope, "Frame") {
        Size = props.Size,
        Position = props.Position or UDim2.new(0, 0, 0, 0),
        AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
        BackgroundColor3 = bgColor,
        BorderSizePixel = 0,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = props.CornerRadius or UDim.new(0, 12),
            },
            New(scope, "UIStroke") {
                Color = Colors.WoodBorder,
                Thickness = 3,
            },
            New(scope, "UIPadding") {
                PaddingTop = props.Padding or UDim.new(0, 10),
                PaddingBottom = props.Padding or UDim.new(0, 10),
                PaddingLeft = props.Padding or UDim.new(0, 10),
                PaddingRight = props.Padding or UDim.new(0, 10),
            },
            -- Wood grain effect
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 220, 210)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 190, 180)),
                }),
                Rotation = 90,
            },
            props.Children,
        },
    }
end

-- ============================================
-- GRASS PANEL COMPONENT
-- Panel with grass/plant feel
-- ============================================
function PvZTheme.GrassPanel(scope: any, props: {
    Size: UDim2,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    Children: any?,
}): Frame
    return New(scope, "Frame") {
        Size = props.Size,
        Position = props.Position or UDim2.new(0, 0, 0, 0),
        AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
        BackgroundColor3 = Colors.GrassMedium,
        BorderSizePixel = 0,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 12),
            },
            New(scope, "UIStroke") {
                Color = Colors.GrassDark,
                Thickness = 3,
            },
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 220, 180)),
                }),
                Rotation = 90,
            },
            props.Children,
        },
    }
end

-- ============================================
-- HEADER BAR COMPONENT
-- Title bar with wood background
-- ============================================
function PvZTheme.HeaderBar(scope: any, props: {
    Title: string | any,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    ShowClose: boolean?,
    OnClose: (() -> ())?,
}): Frame
    return New(scope, "Frame") {
        Size = props.Size or UDim2.new(1, 0, 0, 50),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        BackgroundColor3 = Colors.WoodDark,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 10),
            },
            New(scope, "UIStroke") {
                Color = Colors.WoodBorder,
                Thickness = 2,
            },
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 150, 120)),
                }),
                Rotation = 90,
            },
            
            -- Title text
            New(scope, "TextLabel") {
                Size = UDim2.new(1, if props.ShowClose then -50 else 0, 1, 0),
                Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1,
                Text = props.Title,
                TextColor3 = Colors.TextLight,
                TextSize = 24,
                Font = Fonts.Title,
                TextXAlignment = Enum.TextXAlignment.Left,
                
                [Children] = {
                    New(scope, "UIStroke") {
                        Color = Colors.TextShadow,
                        Thickness = 2,
                    },
                },
            },
            
            -- Close button (optional)
            if props.ShowClose then New(scope, "TextButton") {
                Size = UDim2.new(0, 40, 0, 40),
                Position = UDim2.new(1, -45, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Colors.Danger,
                Text = "✕",
                TextColor3 = Colors.TextLight,
                TextSize = 20,
                Font = Fonts.Button,
                
                [Fusion.OnEvent("Activated")] = function()
                    if props.OnClose then
                        props.OnClose()
                    end
                end,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 8),
                    },
                },
            } else nil,
        },
    }
end

-- ============================================
-- STROKED TEXT COMPONENT
-- Text with shadow stroke
-- ============================================
function PvZTheme.StrokedText(scope: any, props: {
    Text: string | any,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    TextSize: number?,
    TextColor: Color3?,
    Font: Enum.Font?,
    TextXAlignment: Enum.TextXAlignment?,
    TextYAlignment: Enum.TextYAlignment?,
    StrokeColor: Color3?,
    StrokeThickness: number?,
}): TextLabel
    return New(scope, "TextLabel") {
        Size = props.Size or UDim2.new(1, 0, 0, 30),
        Position = props.Position or UDim2.new(0, 0, 0, 0),
        AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
        BackgroundTransparency = 1,
        Text = props.Text,
        TextSize = props.TextSize or 20,
        TextColor3 = props.TextColor or Colors.TextLight,
        Font = props.Font or Fonts.Title,
        TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
        TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
        
        [Children] = {
            New(scope, "UIStroke") {
                Color = props.StrokeColor or Colors.TextShadow,
                Thickness = props.StrokeThickness or 2,
            },
        },
    }
end

-- ============================================
-- WOOD BUTTON COMPONENT
-- Interactive button with PvZ style
-- ============================================
function PvZTheme.WoodButton(scope: any, props: {
    Text: string | any,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    OnClick: (() -> ())?,
    Variant: ("primary" | "secondary" | "danger")?,
    Disabled: (boolean | any)?,
}): TextButton
    local variant = props.Variant or "primary"
    local bgColor = if variant == "primary" then Colors.GrassMedium
        elseif variant == "danger" then Colors.Danger
        else Colors.WoodMedium
    local borderColor = if variant == "primary" then Colors.GrassDark
        elseif variant == "danger" then Color3.fromRGB(139, 0, 0)
        else Colors.WoodBorder
    
    return New(scope, "TextButton") {
        Size = props.Size or UDim2.new(0, 150, 0, 45),
        Position = props.Position or UDim2.new(0, 0, 0, 0),
        AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
        BackgroundColor3 = Computed(scope, function(use)
            local disabled = type(props.Disabled) == "table" and use(props.Disabled) or props.Disabled
            return if disabled then Colors.Locked else bgColor
        end),
        Text = props.Text,
        TextColor3 = Colors.TextLight,
        TextSize = 18,
        Font = Fonts.Button,
        AutoButtonColor = true,
        
        [Fusion.OnEvent("Activated")] = function()
            local disabled = type(props.Disabled) == "table" 
                and (props.Disabled :: any):get() 
                or props.Disabled
            if not disabled and props.OnClick then
                props.OnClick()
            end
        end,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 10),
            },
            New(scope, "UIStroke") {
                Color = borderColor,
                Thickness = 3,
            },
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 230, 230)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
                }),
                Rotation = 90,
            },
        },
    }
end

-- ============================================
-- ICON BUTTON COMPONENT
-- Circular button with icon
-- ============================================
function PvZTheme.IconButton(scope: any, props: {
    Icon: string,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    OnClick: (() -> ())?,
    Variant: ("primary" | "secondary" | "danger")?,
}): TextButton
    local variant = props.Variant or "secondary"
    local bgColor = if variant == "primary" then Colors.GrassMedium
        elseif variant == "danger" then Colors.Danger
        else Colors.WoodMedium
    
    return New(scope, "TextButton") {
        Size = props.Size or UDim2.new(0, 50, 0, 50),
        Position = props.Position or UDim2.new(0, 0, 0, 0),
        AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
        BackgroundColor3 = bgColor,
        Text = props.Icon,
        TextColor3 = Colors.TextLight,
        TextSize = 24,
        AutoButtonColor = true,
        
        [Fusion.OnEvent("Activated")] = function()
            if props.OnClick then
                props.OnClick()
            end
        end,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0.5, 0),
            },
            New(scope, "UIStroke") {
                Color = Colors.WoodBorder,
                Thickness = 2,
            },
        },
    }
end

-- ============================================
-- CURRENCY ROW COMPONENT
-- Display currency with icon
-- ============================================
function PvZTheme.CurrencyRow(scope: any, props: {
    Type: "Sun" | "Coins" | "Gems" | "XP",
    Amount: number | any,
    Size: UDim2?,
    Position: UDim2?,
}): Frame
    local icon = if props.Type == "Sun" then Icons.Sun
        elseif props.Type == "Coins" then Icons.Coin
        elseif props.Type == "Gems" then Icons.Gem
        else Icons.XP
    local color = if props.Type == "Sun" then Colors.SunYellow
        elseif props.Type == "Coins" then Colors.Coins
        elseif props.Type == "Gems" then Colors.Gems
        else Colors.XP
    
    return New(scope, "Frame") {
        Size = props.Size or UDim2.new(0, 120, 0, 40),
        Position = props.Position,
        BackgroundColor3 = Colors.WoodDark,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 10),
            },
            New(scope, "UIStroke") {
                Color = Colors.WoodBorder,
                Thickness = 2,
            },
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundTransparency = 1,
                Text = Computed(scope, function(use)
                    local amount = type(props.Amount) == "table" and use(props.Amount) or props.Amount
                    return icon .. " " .. tostring(amount or 0)
                end),
                TextColor3 = color,
                TextSize = 18,
                Font = Fonts.Numbers,
                TextXAlignment = Enum.TextXAlignment.Left,
                
                [Children] = {
                    New(scope, "UIStroke") {
                        Color = Colors.TextShadow,
                        Thickness = 1,
                    },
                },
            },
        },
    }
end

-- ============================================
-- STAT ROW COMPONENT
-- Display a stat with label and value
-- ============================================
function PvZTheme.StatRow(scope: any, props: {
    Icon: string,
    Label: string,
    Value: number | string | any,
    Color: Color3?,
    Size: UDim2?,
}): Frame
    return New(scope, "Frame") {
        Size = props.Size or UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Colors.WoodLight,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 8),
            },
            New(scope, "TextLabel") {
                Size = UDim2.new(0.6, -10, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = props.Icon .. " " .. props.Label,
                TextColor3 = Colors.TextDark,
                TextSize = 16,
                Font = Fonts.Body,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
            New(scope, "TextLabel") {
                Size = UDim2.new(0.4, -10, 1, 0),
                Position = UDim2.new(0.6, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = Computed(scope, function(use)
                    local val = type(props.Value) == "table" and use(props.Value) or props.Value
                    return tostring(val or 0)
                end),
                TextColor3 = props.Color or Colors.TextDark,
                TextSize = 18,
                Font = Fonts.Numbers,
                TextXAlignment = Enum.TextXAlignment.Right,
            },
        },
    }
end

-- ============================================
-- PROGRESS BAR COMPONENT
-- XP/health style progress bar
-- ============================================
function PvZTheme.ProgressBar(scope: any, props: {
    Current: number | any,
    Max: number | any,
    Color: Color3?,
    Size: UDim2?,
    ShowText: boolean?,
    TextFormat: string?,
}): Frame
    return New(scope, "Frame") {
        Size = props.Size or UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Colors.WoodDark,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 6),
            },
            New(scope, "UIStroke") {
                Color = Colors.WoodBorder,
                Thickness = 2,
            },
            
            -- Fill bar
            New(scope, "Frame") {
                Size = Computed(scope, function(use)
                    local current = type(props.Current) == "table" and use(props.Current) or props.Current
                    local max = type(props.Max) == "table" and use(props.Max) or props.Max
                    local pct = math.clamp((current or 0) / math.max(1, max or 1), 0, 1)
                    return UDim2.new(pct, 0, 1, 0)
                end),
                BackgroundColor3 = props.Color or Colors.XP,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 6),
                    },
                    New(scope, "UIGradient") {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 230, 230)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
                        }),
                        Rotation = 90,
                    },
                },
            },
            
            -- Text overlay
            if props.ShowText ~= false then New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = Computed(scope, function(use)
                    local current = type(props.Current) == "table" and use(props.Current) or props.Current
                    local max = type(props.Max) == "table" and use(props.Max) or props.Max
                    if props.TextFormat then
                        return string.format(props.TextFormat, current or 0, max or 0)
                    end
                    return `{current or 0} / {max or 0}`
                end),
                TextColor3 = Colors.TextLight,
                TextSize = 12,
                Font = Fonts.Numbers,
                
                [Children] = {
                    New(scope, "UIStroke") {
                        Color = Colors.TextShadow,
                        Thickness = 1,
                    },
                },
            } else nil,
        },
    }
end

-- ============================================
-- BANNER COMPONENT
-- Title banner with decorative edges
-- ============================================
function PvZTheme.Banner(scope: any, props: {
    Text: string | any,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    Color: Color3?,
}): Frame
    return New(scope, "Frame") {
        Size = props.Size or UDim2.new(0, 300, 0, 60),
        Position = props.Position or UDim2.new(0.5, 0, 0, 20),
        AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
        BackgroundColor3 = props.Color or Colors.WoodDark,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 8),
            },
            New(scope, "UIStroke") {
                Color = Colors.WoodBorder,
                Thickness = 3,
            },
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 200, 180)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 160, 140)),
                }),
                Rotation = 90,
            },
            PvZTheme.StrokedText(scope, {
                Text = props.Text,
                Size = UDim2.new(1, 0, 1, 0),
                TextSize = 28,
                Font = Fonts.Title,
            }),
        },
    }
end

-- ============================================
-- PLANT CARD COMPONENT
-- Card for displaying a plant in selection
-- ============================================
function PvZTheme.PlantCard(scope: any, props: {
    PlantName: string,
    IsOwned: boolean | any,
    IsLocked: boolean | any,
    IsSelected: boolean | any,
    Cost: number?,
    OnClick: (() -> ())?,
    Size: UDim2?,
}): Frame
    local isOwned = props.IsOwned
    local isLocked = props.IsLocked
    local isSelected = props.IsSelected
    
    return New(scope, "Frame") {
        Size = props.Size or UDim2.new(0, 90, 0, 110),
        BackgroundColor3 = Computed(scope, function(use)
            local selected = type(isSelected) == "table" and use(isSelected) or isSelected
            local owned = type(isOwned) == "table" and use(isOwned) or isOwned
            if selected then return Colors.SunYellow end
            if owned then return Colors.Owned end
            return Colors.WoodMedium
        end),
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 10),
            },
            New(scope, "UIStroke") {
                Color = Computed(scope, function(use)
                    local selected = type(isSelected) == "table" and use(isSelected) or isSelected
                    return if selected then Colors.SunOrange else Colors.WoodBorder
                end),
                Thickness = Computed(scope, function(use)
                    local selected = type(isSelected) == "table" and use(isSelected) or isSelected
                    return if selected then 4 else 2
                end),
            },
            
            -- Plant name
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -10, 0, 30),
                Position = UDim2.new(0.5, 0, 0, 60),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Text = props.PlantName,
                TextColor3 = Colors.TextDark,
                TextSize = 12,
                Font = Fonts.Button,
                TextWrapped = true,
            },
            
            -- Plant icon placeholder
            New(scope, "TextLabel") {
                Size = UDim2.new(0, 50, 0, 50),
                Position = UDim2.new(0.5, 0, 0, 8),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundColor3 = Colors.GrassMedium,
                Text = Icons.Plant,
                TextSize = 30,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 8),
                    },
                },
            },
            
            -- Cost badge
            if props.Cost then New(scope, "Frame") {
                Size = UDim2.new(0, 50, 0, 20),
                Position = UDim2.new(0.5, 0, 1, -25),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundColor3 = Colors.SunYellow,
                Visible = Computed(scope, function(use)
                    local owned = type(isOwned) == "table" and use(isOwned) or isOwned
                    return not owned
                end),
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 6),
                    },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = Icons.Coin .. " " .. tostring(props.Cost),
                        TextColor3 = Colors.TextDark,
                        TextSize = 12,
                        Font = Fonts.Numbers,
                    },
                },
            } else nil,
            
            -- Owned checkmark
            New(scope, "TextLabel") {
                Size = UDim2.new(0, 30, 0, 30),
                Position = UDim2.new(1, -35, 0, 5),
                BackgroundTransparency = 1,
                Text = Icons.Check,
                TextColor3 = Colors.GrassLight,
                TextSize = 24,
                Font = Fonts.Numbers,
                Visible = Computed(scope, function(use)
                    local owned = type(isOwned) == "table" and use(isOwned) or isOwned
                    return owned == true
                end),
                
                [Children] = {
                    New(scope, "UIStroke") {
                        Color = Colors.GrassDark,
                        Thickness = 2,
                    },
                },
            },
            
            -- Lock icon overlay
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = Icons.Lock,
                TextSize = 40,
                Visible = Computed(scope, function(use)
                    local locked = type(isLocked) == "table" and use(isLocked) or isLocked
                    return locked == true
                end),
            },
            
            -- Click handler
            New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                
                [Fusion.OnEvent("Activated")] = function()
                    if props.OnClick then
                        props.OnClick()
                    end
                end,
            },
        },
    }
end

-- ============================================
-- DECK SLOT COMPONENT
-- Slot in deck builder
-- ============================================
function PvZTheme.DeckSlot(scope: any, props: {
    Index: number,
    PlantType: (string | any)?,
    OnClick: (() -> ())?,
    Size: UDim2?,
}): Frame
    return New(scope, "Frame") {
        Size = props.Size or UDim2.new(0, 75, 0, 55),
        BackgroundColor3 = Computed(scope, function(use)
            local plant = type(props.PlantType) == "table" and use(props.PlantType) or props.PlantType
            return if plant then Colors.Owned else Colors.WoodDark
        end),
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 8),
            },
            New(scope, "UIStroke") {
                Color = Colors.WoodBorder,
                Thickness = 2,
            },
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = Computed(scope, function(use)
                    local plant = type(props.PlantType) == "table" and use(props.PlantType) or props.PlantType
                    if plant then
                        local name = plant
                        if #name > 8 then
                            name = name:sub(1, 7) .. ".."
                        end
                        return name
                    end
                    return tostring(props.Index)
                end),
                TextColor3 = Computed(scope, function(use)
                    local plant = type(props.PlantType) == "table" and use(props.PlantType) or props.PlantType
                    return if plant then Colors.TextDark else Colors.Locked
                end),
                TextSize = 12,
                Font = Fonts.Button,
                TextWrapped = true,
            },
            
            -- Click handler
            if props.OnClick then New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                
                [Fusion.OnEvent("Activated")] = function()
                    if props.OnClick then
                        props.OnClick()
                    end
                end,
            } else nil,
        },
    }
end

-- ============================================
-- TOOLTIP COMPONENT
-- Hoverable tooltip
-- ============================================
function PvZTheme.Tooltip(scope: any, props: {
    Text: string | any,
    Position: UDim2?,
    Visible: boolean | any,
}): Frame
    return New(scope, "Frame") {
        Size = UDim2.new(0, 200, 0, 40),
        Position = props.Position or UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Colors.WoodDark,
        Visible = props.Visible,
        ZIndex = 100,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 6),
            },
            New(scope, "UIStroke") {
                Color = Colors.WoodBorder,
                Thickness = 1,
            },
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundTransparency = 1,
                Text = props.Text,
                TextColor3 = Colors.TextLight,
                TextSize = 14,
                Font = Fonts.Body,
                TextWrapped = true,
            },
        },
    }
end

return PvZTheme
