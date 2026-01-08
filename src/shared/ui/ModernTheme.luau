--!strict
--[[
    ModernTheme.luau - Modern Dark UI Theme System
    
    Unified design system for the modern dark UI style.
    Used by ShopView, LobbyHUD, DeckBuilderView, and new Views.
    
    This replaces the old PvZTheme wood-style for a cleaner,
    more modern Roblox game aesthetic.
    
    Usage:
        local Theme = require(shared.ui.ModernTheme)
        local button = Theme.Button(scope, {...})
        local color = Theme.Colors.Primary
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value

-- ============================================
-- COLOR PALETTE
-- Modern dark theme with accent colors
-- ============================================
local Colors = {
    -- Backgrounds
    Background = Color3.fromRGB(22, 22, 30),
    BackgroundLight = Color3.fromRGB(30, 30, 40),
    BackgroundLighter = Color3.fromRGB(38, 38, 50),
    
    -- Cards & Panels
    Card = Color3.fromRGB(38, 38, 50),
    CardHover = Color3.fromRGB(50, 50, 65),
    CardSelected = Color3.fromRGB(60, 60, 80),
    Panel = Color3.fromRGB(30, 30, 42),
    PanelLight = Color3.fromRGB(45, 45, 58),
    
    -- Slots
    SlotEmpty = Color3.fromRGB(40, 40, 52),
    SlotFilled = Color3.fromRGB(50, 70, 50),
    
    -- Borders
    Border = Color3.fromRGB(60, 60, 75),
    BorderLight = Color3.fromRGB(80, 80, 95),
    BorderFocus = Color3.fromRGB(100, 100, 120),
    
    -- Primary Accents
    Gold = Color3.fromRGB(255, 193, 7),
    GoldDark = Color3.fromRGB(200, 150, 0),
    GoldLight = Color3.fromRGB(255, 220, 100),
    
    -- Status Colors
    Success = Color3.fromRGB(76, 175, 80),
    SuccessLight = Color3.fromRGB(129, 199, 132),
    SuccessDark = Color3.fromRGB(56, 142, 60),
    
    Error = Color3.fromRGB(244, 67, 54),
    ErrorLight = Color3.fromRGB(255, 100, 100),
    ErrorDark = Color3.fromRGB(200, 50, 50),
    
    Warning = Color3.fromRGB(255, 152, 0),
    WarningLight = Color3.fromRGB(255, 180, 50),
    
    Info = Color3.fromRGB(33, 150, 243),
    InfoLight = Color3.fromRGB(100, 180, 255),
    
    -- Resource Colors
    Coins = Color3.fromRGB(255, 193, 7),
    Gems = Color3.fromRGB(180, 100, 255),
    XP = Color3.fromRGB(0, 200, 220),
    Sun = Color3.fromRGB(255, 200, 0),
    
    -- Text
    TextWhite = Color3.new(1, 1, 1),
    TextLight = Color3.fromRGB(220, 220, 230),
    TextMuted = Color3.fromRGB(140, 140, 150),
    TextDark = Color3.fromRGB(100, 100, 110),
    TextDisabled = Color3.fromRGB(80, 80, 90),
    
    -- Disabled state
    Disabled = Color3.fromRGB(60, 60, 70),
    DisabledText = Color3.fromRGB(100, 100, 110),
    
    -- Overlay
    OverlayDark = Color3.fromRGB(0, 0, 0),
    OverlayLight = Color3.fromRGB(255, 255, 255),
}

-- Nature/Green variant (for DeckBuilder)
local ColorsNature = {
    Background = Color3.fromRGB(20, 25, 20),
    Card = Color3.fromRGB(35, 45, 35),
    CardHover = Color3.fromRGB(50, 65, 50),
    CardSelected = Color3.fromRGB(60, 90, 60),
    Panel = Color3.fromRGB(28, 35, 28),
    SlotEmpty = Color3.fromRGB(30, 40, 30),
    SlotFilled = Color3.fromRGB(55, 80, 55),
    Border = Color3.fromRGB(60, 75, 60),
    TextMuted = Color3.fromRGB(140, 155, 140),
}

-- ============================================
-- FONTS
-- ============================================
local Fonts = {
    Title = Enum.Font.GothamBlack,
    Header = Enum.Font.GothamBold,
    Button = Enum.Font.GothamBold,
    Body = Enum.Font.Gotham,
    Label = Enum.Font.GothamMedium,
    Mono = Enum.Font.RobotoMono,
}

-- ============================================
-- SIZING
-- ============================================
local Sizing = {
    -- Border radius
    RadiusSmall = UDim.new(0, 6),
    RadiusMedium = UDim.new(0, 10),
    RadiusLarge = UDim.new(0, 14),
    RadiusRound = UDim.new(0, 999),
    RadiusPill = UDim.new(0, 19),
    
    -- Padding
    PaddingSmall = UDim.new(0, 8),
    PaddingMedium = UDim.new(0, 12),
    PaddingLarge = UDim.new(0, 16),
    PaddingXL = UDim.new(0, 24),
    
    -- Stroke
    StrokeThin = 1,
    StrokeNormal = 2,
    StrokeThick = 3,
    
    -- Common heights
    ButtonHeight = 44,
    InputHeight = 40,
    TopBarHeight = 56,
    CardWidth = 180,
    CardHeight = 245,
    SlotSize = 75,
}

-- ============================================
-- SHARED DATA
-- ============================================

-- Plant emoji mapping
local PlantEmojis: {[string]: string} = {
    Peashooter = "🌱", Sunflower = "🌻", WallNut = "🥜",
    PotatoMine = "💣", SnowPea = "❄️", Repeater = "🌿",
    CherryBomb = "🍒", Chomper = "🦷", Jalapeno = "🌶️",
    TallNut = "🧱", Squash = "🎃", ThreePeater = "🌾",
    TorchWood = "🔥", Spikeweed = "⚔️", Pumpkin = "🎃",
    Starfruit = "⭐", MagnifyingGrass = "🔍", CattailPlant = "🐱",
    CobCannon = "🌽", Bonkchoy = "🥬", Snapdragon = "🐉",
    IceBerg = "🧊", SunShroom = "🍄",
}

-- Mutation emoji mapping
local MutationEmojis: {[string]: string} = {
    Fire = "🔥", Inferno = "🔥",
    Ice = "❄️", Frost = "❄️",
    Electric = "⚡", Thunder = "⚡", Storm = "⚡",
    Toxic = "☠️", Plague = "☠️",
    Shadow = "🌑", Void = "🌑",
    Solar = "☀️", Radiant = "☀️",
    Reinforced = "🛡️", Fortress = "🛡️",
    Primal = "💥", Savage = "💥",
    Swift = "💨", Sonic = "💨",
}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function getPlantEmoji(plantType: string): string
    return PlantEmojis[plantType] or "🌱"
end

local function getMutationEmoji(mutationType: string): string
    return MutationEmojis[mutationType] or "✨"
end

-- ============================================
-- UI COMPONENTS
-- ============================================

--[[
    Panel - Basic container with dark background
]]
local function Panel(scope: any, props: {
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    BackgroundColor3: Color3?,
    Variant: ("default" | "light" | "card" | "nature")?,
    Rounded: ("small" | "medium" | "large")?,
    HasStroke: boolean?,
    [any]: any,
}): Frame
    local variant = props.Variant or "default"
    local bgColor = props.BackgroundColor3
    
    if not bgColor then
        if variant == "light" then bgColor = Colors.BackgroundLight
        elseif variant == "card" then bgColor = Colors.Card
        elseif variant == "nature" then bgColor = ColorsNature.Background
        else bgColor = Colors.Background end
    end
    
    local radius = Sizing.RadiusMedium
    if props.Rounded == "small" then radius = Sizing.RadiusSmall
    elseif props.Rounded == "large" then radius = Sizing.RadiusLarge end
    
    return New(scope, "Frame") {
        Size = props.Size or UDim2.new(1, 0, 1, 0),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        BackgroundColor3 = bgColor,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = radius },
            if props.HasStroke ~= false then New(scope, "UIStroke") { 
                Color = Colors.Border, 
                Thickness = Sizing.StrokeNormal,
            } else nil,
            props[Children],
        },
    }
end

--[[
    Card - Hoverable card with optional selection state
]]
local function Card(scope: any, props: {
    Size: UDim2?,
    Position: UDim2?,
    IsSelected: any?, -- Value<boolean> or Computed<boolean>
    OnClick: (() -> ())?,
    Variant: ("default" | "nature")?,
    [any]: any,
}): Frame
    local isHovered = Value(scope, false)
    local colors = if props.Variant == "nature" then ColorsNature else Colors
    
    return New(scope, "Frame") {
        Size = props.Size or UDim2.fromOffset(Sizing.CardWidth, Sizing.CardHeight),
        Position = props.Position,
        BackgroundColor3 = Computed(scope, function(use)
            local selected = props.IsSelected and use(props.IsSelected)
            if selected then return colors.CardSelected or Colors.CardSelected end
            if use(isHovered) then return colors.CardHover or Colors.CardHover end
            return colors.Card or Colors.Card
        end),
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusLarge },
            New(scope, "UIStroke") {
                Color = Computed(scope, function(use)
                    local selected = props.IsSelected and use(props.IsSelected)
                    if selected then return Colors.Gold end
                    if use(isHovered) then return Colors.BorderFocus end
                    return colors.Border or Colors.Border
                end),
                Thickness = Sizing.StrokeNormal,
            },
            
            -- Invisible click detector
            if props.OnClick then New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                [OnEvent "Activated"] = props.OnClick,
                [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
            } else nil,
            
            props[Children],
        },
    }
end

--[[
    Button - Standard button with variants
]]
local function Button(scope: any, props: {
    Text: string | any,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    Variant: ("primary" | "success" | "danger" | "ghost")?,
    Disabled: any?, -- Value<boolean> or boolean
    OnClick: () -> (),
    [any]: any,
}): TextButton
    local isHovered = Value(scope, false)
    local variant = props.Variant or "primary"
    
    local baseColor = Colors.Gold
    local hoverColor = Colors.GoldLight
    local textColor = Color3.fromRGB(30, 30, 30)
    
    if variant == "success" then
        baseColor = Colors.Success
        hoverColor = Colors.SuccessLight
        textColor = Colors.TextWhite
    elseif variant == "danger" then
        baseColor = Colors.Error
        hoverColor = Colors.ErrorLight
        textColor = Colors.TextWhite
    elseif variant == "ghost" then
        baseColor = Colors.BackgroundLighter
        hoverColor = Colors.Card
        textColor = Colors.TextWhite
    end
    
    local isDisabled = props.Disabled
    
    return New(scope, "TextButton") {
        Size = props.Size or UDim2.new(1, 0, 0, Sizing.ButtonHeight),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        BackgroundColor3 = Computed(scope, function(use)
            local disabled = if typeof(isDisabled) == "table" then use(isDisabled) else isDisabled
            if disabled then return Colors.Disabled end
            if use(isHovered) then return hoverColor end
            return baseColor
        end),
        Text = props.Text,
        TextColor3 = Computed(scope, function(use)
            local disabled = if typeof(isDisabled) == "table" then use(isDisabled) else isDisabled
            if disabled then return Colors.DisabledText end
            return textColor
        end),
        TextSize = 16,
        Font = Fonts.Button,
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = function()
            local disabled = if typeof(isDisabled) == "table" then Fusion.peek(isDisabled) else isDisabled
            if not disabled then props.OnClick() end
        end,
        [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
        [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
            props[Children],
        },
    }
end

--[[
    IconButton - Small button with icon/emoji
]]
local function IconButton(scope: any, props: {
    Icon: string,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    Variant: ("primary" | "ghost" | "danger")?,
    OnClick: () -> (),
}): TextButton
    local isHovered = Value(scope, false)
    local variant = props.Variant or "ghost"
    
    local baseColor = Colors.BackgroundLighter
    local hoverColor = Colors.Card
    if variant == "primary" then
        baseColor = Colors.Gold
        hoverColor = Colors.GoldLight
    elseif variant == "danger" then
        baseColor = Colors.Error
        hoverColor = Colors.ErrorLight
    end
    
    return New(scope, "TextButton") {
        Size = props.Size or UDim2.fromOffset(40, 40),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        BackgroundColor3 = Computed(scope, function(use)
            return if use(isHovered) then hoverColor else baseColor
        end),
        Text = props.Icon,
        TextSize = 20,
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = props.OnClick,
        [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
        [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
        },
    }
end

--[[
    BackButton - Standard back button (top-left)
    DEPRECATED: Use CloseButton instead (Roblox buttons are on left)
]]
local function BackButton(scope: any, onBack: () -> ()): TextButton
    return IconButton(scope, {
        Icon = "←",
        Size = UDim2.fromOffset(50, 50),
        Position = UDim2.fromOffset(16, 16),
        Variant = "ghost",
        OnClick = onBack,
    })
end

--[[
    CloseButton - Close button on RIGHT (avoids Roblox system buttons on left)
]]
local function CloseButton(scope: any, onClose: () -> ()): TextButton
    return IconButton(scope, {
        Icon = "✕",
        Size = UDim2.fromOffset(44, 44),
        Position = UDim2.new(1, -12, 0, 6),
        AnchorPoint = Vector2.new(1, 0),
        Variant = "ghost",
        OnClick = onClose,
    })
end

--[[
    TopBar - Header bar with title and optional close button
]]
local function TopBar(scope: any, props: {
    Title: string | any,
    OnClose: (() -> ())?,
    LeftContent: any?,
    RightContent: any?,
}): Frame
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 0, Sizing.TopBarHeight),
        BackgroundColor3 = Colors.Panel,
        ZIndex = 10,
        
        [Children] = {
            -- Title
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = props.Title,
                TextColor3 = Colors.TextWhite,
                TextSize = 22,
                Font = Fonts.Header,
            },
            
            -- Close button on RIGHT (if provided)
            if props.OnClose then New(scope, "TextButton") {
                Size = UDim2.fromOffset(44, 44),
                Position = UDim2.new(1, -12, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Colors.BackgroundLighter,
                Text = "✕",
                TextSize = 20,
                TextColor3 = Colors.TextWhite,
                Font = Fonts.Header,
                AutoButtonColor = false,
                ZIndex = 11,
                
                [OnEvent "Activated"] = props.OnClose,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                },
            } else nil,
            
            -- Left content
            if props.LeftContent then New(scope, "Frame") {
                Size = UDim2.new(0, 100, 1, 0),
                BackgroundTransparency = 1,
                [Children] = { props.LeftContent },
            } else nil,
            
            -- Right content
            if props.RightContent then New(scope, "Frame") {
                Size = UDim2.new(0, 100, 1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                [Children] = { props.RightContent },
            } else nil,
        },
    }
end

--[[
    ResourcePill - Compact resource display (coins, gems, etc.)
]]
local function ResourcePill(scope: any, props: {
    Icon: string,
    Value: any, -- string | Computed<string>
    Color: Color3?,
}): Frame
    return New(scope, "Frame") {
        Size = UDim2.fromOffset(110, 38),
        BackgroundColor3 = Colors.Panel,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusPill },
            New(scope, "UIStroke") { Color = Colors.Border, Thickness = Sizing.StrokeNormal },
            
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
                TextColor3 = props.Color or Colors.TextWhite,
                TextSize = 16,
                Font = Fonts.Header,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
        },
    }
end

--[[
    Badge - Small status indicator
]]
local function Badge(scope: any, props: {
    Text: string | any,
    Color: Color3?,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
}): Frame
    return New(scope, "Frame") {
        Size = props.Size or UDim2.fromOffset(24, 24),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        BackgroundColor3 = props.Color or Colors.Warning,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = props.Text,
                TextSize = 12,
                Font = Fonts.Header,
                TextColor3 = Colors.TextWhite,
            },
        },
    }
end

--[[
    ProgressBar - Horizontal progress indicator
]]
local function ProgressBar(scope: any, props: {
    Progress: any, -- number | Computed<number> (0-1)
    Size: UDim2?,
    Position: UDim2?,
    Color: Color3?,
    ShowLabel: boolean?,
}): Frame
    local progressValue = props.Progress
    
    return New(scope, "Frame") {
        Size = props.Size or UDim2.new(1, 0, 0, 12),
        Position = props.Position,
        BackgroundColor3 = Colors.BackgroundLighter,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
            
            -- Fill
            New(scope, "Frame") {
                Size = Computed(scope, function(use)
                    local p = if typeof(progressValue) == "table" then use(progressValue) else progressValue
                    return UDim2.new(math.clamp(p, 0, 1), 0, 1, 0)
                end),
                BackgroundColor3 = props.Color or Colors.Success,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                },
            },
            
            -- Label
            if props.ShowLabel then New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = Computed(scope, function(use)
                    local p = if typeof(progressValue) == "table" then use(progressValue) else progressValue
                    return string.format("%d%%", math.floor(p * 100))
                end),
                TextColor3 = Colors.TextWhite,
                TextSize = 10,
                Font = Fonts.Header,
            } else nil,
        },
    }
end

--[[
    Overlay - Full screen overlay for modals
]]
local function Overlay(scope: any, props: {
    Visible: any, -- Value<boolean>
    OnClose: (() -> ())?,
    [any]: any,
}): Frame
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.OverlayDark,
        BackgroundTransparency = Computed(scope, function(use)
            return if use(props.Visible) then 0.4 else 1
        end),
        Visible = props.Visible,
        
        [Children] = {
            -- Click to close (optional)
            if props.OnClose then New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                [OnEvent "Activated"] = props.OnClose,
            } else nil,
            
            props[Children],
        },
    }
end

-- ============================================
-- EXPORT
-- ============================================

local ModernTheme = {
    -- Color palettes
    Colors = Colors,
    ColorsNature = ColorsNature,
    
    -- Typography
    Fonts = Fonts,
    
    -- Sizing constants
    Sizing = Sizing,
    
    -- Utility functions
    GetPlantEmoji = getPlantEmoji,
    GetMutationEmoji = getMutationEmoji,
    
    -- UI Components
    Panel = Panel,
    Card = Card,
    Button = Button,
    IconButton = IconButton,
    BackButton = BackButton,
    CloseButton = CloseButton,
    TopBar = TopBar,
    ResourcePill = ResourcePill,
    Badge = Badge,
    ProgressBar = ProgressBar,
    Overlay = Overlay,
}

return table.freeze(ModernTheme)
