--!strict
--[[
    CasualTheme.luau - Modern Mobile Casual UI Theme
    
    Design Direction:
    - "Modern Mobile Casual UI, glossy cartoon finish"
    - Squircle shapes (squares with heavy rounded corners)
    - Vibrant colors with thick dark outlines (UIStroke)
    - Buttons feel tactile and 'juicy' (bouncy)
    - Clean, vector-like, high contrast aesthetic
    
    Usage:
        local CasualTheme = require(Shared.ui.CasualTheme)
        local card = CasualTheme.UnitCard(scope, {...})
        local color = CasualTheme.Colors.AppleGreen
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring

-- ============================================
-- COLOR PALETTE
-- Vibrant, high-contrast mobile casual colors
-- Extracted from reference image
-- ============================================
local Colors = {
    -- Primary Accents (from DA spec)
    AppleGreen = Color3.fromRGB(76, 217, 100),      -- #4CD964
    AppleGreenDark = Color3.fromRGB(60, 180, 80),   -- Darker variant
    AppleGreenLight = Color3.fromRGB(100, 230, 120),-- Lighter variant
    
    ManaBlue = Color3.fromRGB(52, 152, 219),        -- #3498DB
    ManaBlueDark = Color3.fromRGB(41, 128, 185),    -- Darker variant
    ManaBlueLight = Color3.fromRGB(85, 180, 240),   -- Lighter variant
    
    -- Card Colors (vibrant, distinct per slot - from image analysis)
    CardGreen = Color3.fromRGB(92, 184, 92),        -- Cactus green (slightly muted)
    CardYellow = Color3.fromRGB(255, 200, 60),      -- Sunflower yellow (warm)
    CardCyan = Color3.fromRGB(72, 201, 214),        -- Mushroom cyan/turquoise
    CardRed = Color3.fromRGB(217, 83, 79),          -- Rose coral red
    CardPink = Color3.fromRGB(240, 148, 164),       -- Succulent pink
    CardTeal = Color3.fromRGB(92, 184, 120),        -- Tree green-teal
    
    -- UI Backgrounds
    PanelDark = Color3.fromRGB(45, 60, 80),         -- Dark blue-gray panel
    PanelMedium = Color3.fromRGB(60, 80, 100),      -- Medium panel
    PanelLight = Color3.fromRGB(80, 105, 130),      -- Lighter panel
    CardBar = Color3.fromRGB(55, 75, 100),          -- Bottom bar background (blue-gray)
    CardBarBorder = Color3.fromRGB(35, 50, 70),     -- Bottom bar border
    
    -- Top HUD elements (from image)
    AvatarFrame = Color3.fromRGB(91, 163, 208),     -- Light blue frame #5BA3D0
    LevelBadgeBg = Color3.fromRGB(91, 163, 208),    -- Light blue same as avatar
    
    -- Currency Pills (from image)
    CoinsPill = Color3.fromRGB(255, 193, 7),        -- Gold/yellow pill
    CoinsPillDark = Color3.fromRGB(220, 160, 0),    -- Darker gold
    GemsPill = Color3.fromRGB(180, 90, 220),        -- Purple/magenta pill
    GemsPillDark = Color3.fromRGB(150, 70, 190),    -- Darker purple
    
    -- Borders (thick dark outlines for cartoon effect)
    StrokeDark = Color3.fromRGB(40, 55, 75),        -- Dark blue-gray stroke
    StrokeMedium = Color3.fromRGB(55, 75, 95),      -- Medium stroke
    StrokeLight = Color3.fromRGB(80, 100, 120),     -- Light stroke
    StrokeSelected = Color3.fromRGB(255, 255, 200), -- Glowing selected
    
    -- Cost Badge (blue pill from image)
    CostBadge = Color3.fromRGB(52, 152, 219),       -- Mana blue
    CostBadgeDark = Color3.fromRGB(41, 128, 185),   -- Darker
    
    -- Currency & Resources (legacy compatibility)
    Coins = Color3.fromRGB(255, 193, 7),            -- Gold coins
    Gems = Color3.fromRGB(180, 90, 220),            -- Purple gems
    Sun = Color3.fromRGB(255, 220, 0),              -- Yellow sun
    XP = Color3.fromRGB(0, 200, 220),               -- Cyan XP
    
    -- Arena HUD Colors (aliases for compatibility)
    PrimaryGreen = Color3.fromRGB(76, 217, 100),    -- Same as AppleGreen
    AccentOrange = Color3.fromRGB(255, 165, 50),    -- Orange accent
    CoinGold = Color3.fromRGB(255, 193, 7),         -- Same as Coins
    GemPurple = Color3.fromRGB(180, 90, 220),       -- Same as Gems
    SunYellow = Color3.fromRGB(255, 220, 0),        -- Same as Sun
    HealthGreen = Color3.fromRGB(76, 217, 100),     -- Health bar green
    HealthRed = Color3.fromRGB(231, 76, 60),        -- Health bar red (low health)
    
    -- Level Badge (yellow star from image)
    LevelBadge = Color3.fromRGB(255, 210, 60),      -- Golden yellow star
    LevelBadgeGlow = Color3.fromRGB(255, 225, 100), -- Lighter glow
    
    -- Text
    TextWhite = Color3.fromRGB(255, 255, 255),
    TextLight = Color3.fromRGB(240, 245, 250),
    TextDark = Color3.fromRGB(30, 40, 50),
    TextMuted = Color3.fromRGB(150, 165, 180),
    TextShadow = Color3.fromRGB(20, 30, 40),
    
    -- States
    Selected = Color3.fromRGB(255, 230, 150),       -- Warm glow for selected
    Disabled = Color3.fromRGB(80, 90, 100),
    Success = Color3.fromRGB(76, 217, 100),
    Warning = Color3.fromRGB(255, 165, 0),
    Error = Color3.fromRGB(231, 76, 60),
    
    -- Overlay
    OverlayDark = Color3.fromRGB(0, 0, 0),
    
    -- ============================================
    -- MUTATION LAB COLORS (Sci-Fi Theme)
    -- From reference image - neon blue, cyan glows
    -- ============================================
    
    -- Lab Background
    LabBgDark = Color3.fromRGB(15, 25, 45),         -- Very dark blue
    LabBgMedium = Color3.fromRGB(25, 40, 65),       -- Dark blue panels
    LabBgLight = Color3.fromRGB(35, 55, 85),        -- Lighter blue panels
    
    -- Neon/Glow colors
    NeonCyan = Color3.fromRGB(0, 220, 255),         -- Bright cyan glow
    NeonCyanDark = Color3.fromRGB(0, 160, 200),     -- Darker cyan
    NeonBlue = Color3.fromRGB(60, 140, 255),        -- Electric blue
    NeonPurple = Color3.fromRGB(140, 80, 255),      -- Purple accent
    
    -- Mutation Node states (from reference image)
    NodeUnlocked = Color3.fromRGB(76, 217, 100),    -- Bright green (unlocked)
    NodeUnlockedDark = Color3.fromRGB(50, 160, 60), -- Darker green
    NodeUnlockedBorder = Color3.fromRGB(255, 180, 50), -- Golden/orange border for unlocked
    NodeLocked = Color3.fromRGB(120, 125, 135),     -- Gray metallic (locked)
    NodeLockedDark = Color3.fromRGB(80, 85, 95),    -- Darker gray border
    NodeLockIcon = Color3.fromRGB(255, 160, 50),    -- Orange lock icon
    NodeSelected = Color3.fromRGB(100, 220, 255),   -- Cyan (selected)
    
    -- Hologram effect
    HologramBlue = Color3.fromRGB(80, 180, 255),    -- Light blue hologram
    HologramCyan = Color3.fromRGB(0, 255, 255),     -- Cyan hologram edge
    HologramGlow = Color3.fromRGB(120, 200, 255),   -- Glow effect
    
    -- Energy/Lightning
    EnergyBlue = Color3.fromRGB(100, 180, 255),     -- Energy connection lines
    EnergyGlow = Color3.fromRGB(150, 220, 255),     -- Glow on lines
    
    -- Mutation categories (from image)
    MutDamage = Color3.fromRGB(80, 200, 80),        -- Sword - green
    MutHealth = Color3.fromRGB(80, 200, 80),        -- Shield - green  
    MutRange = Color3.fromRGB(220, 80, 80),         -- Target - red
    MutSpeed = Color3.fromRGB(255, 220, 60),        -- Lightning - yellow
}

-- Card color presets for each deck slot (from image - exact match)
local CardColorPresets = {
    Color3.fromRGB(92, 184, 92),    -- 1: Green (cactus with sunglasses)
    Color3.fromRGB(255, 200, 60),   -- 2: Yellow (sunflower) - warm gold
    Color3.fromRGB(72, 201, 214),   -- 3: Cyan/Turquoise (mushroom)
    Color3.fromRGB(217, 83, 79),    -- 4: Coral Red (rose in pot)
    Color3.fromRGB(240, 148, 164),  -- 5: Pink (succulent)
    Color3.fromRGB(92, 184, 120),   -- 6: Teal-Green (tree)
}

-- ============================================
-- FONTS
-- Clean, readable mobile fonts
-- ============================================
local Fonts = {
    Title = Enum.Font.FredokaOne,       -- Playful, rounded
    Header = Enum.Font.GothamBold,
    Button = Enum.Font.GothamBold,
    Body = Enum.Font.Gotham,
    Label = Enum.Font.GothamMedium,
    Numbers = Enum.Font.GothamBlack,    -- Bold numbers for costs
}

-- ============================================
-- SIZING (Squircle-focused)
-- Heavy rounded corners = Squircle effect
-- ============================================
local Sizing = {
    -- Squircle corner radii (heavy rounding)
    SquircleSmall = UDim.new(0, 12),
    SquircleMedium = UDim.new(0, 18),
    SquircleLarge = UDim.new(0, 24),
    SquircleXL = UDim.new(0, 32),
    
    -- Numeric corner radii (for direct use)
    CornerRadiusSmall = 12,
    CornerRadiusMedium = 16,
    CornerRadiusLarge = 20,
    CornerRadiusXL = 28,
    
    -- Pills (fully rounded ends)
    PillRadius = UDim.new(0, 999),
    
    -- Thick cartoon strokes
    StrokeThin = 2,
    StrokeMedium = 3,
    StrokeNormal = 3,
    StrokeThick = 4,
    StrokeHeavy = 5,
    
    -- Card sizes (from image analysis)
    UnitCardSize = UDim2.fromOffset(80, 90),        -- Main card size
    UnitCardLarge = UDim2.fromOffset(90, 100),      -- Selected/hover size
    CostBadgeSize = UDim2.fromOffset(32, 24),       -- Cost pill in corner
    
    -- HUD elements
    ResourcePillHeight = 44,
    ResourcePillWidth = 120,
    BottomBarHeight = 110,
    TopBarHeight = 60,
    
    -- Touch targets (mobile-first 44pt minimum)
    TouchMin = 44,
}

-- ============================================
-- PLANT EMOJI MAPPING
-- ============================================
local PlantEmojis: {[string]: string} = {
    Peashooter = "🌱", Sunflower = "🌻", WallNut = "🥜",
    PotatoMine = "💣", SnowPea = "❄️", Repeater = "🌿",
    CherryBomb = "🍒", Chomper = "🦷", Jalapeno = "🌶️",
    TallNut = "🧱", Squash = "🎃", ThreePeater = "🌾",
    TorchWood = "🔥", Spikeweed = "⚔️", Pumpkin = "🎃",
    Starfruit = "⭐", MagnifyingGrass = "🔍", CattailPlant = "🐱",
    CobCannon = "🌽", Bonkchoy = "🥬", Snapdragon = "🐉",
    IceBerg = "🧊", SunShroom = "🍄", Cactus = "🌵",
}

local function getPlantEmoji(plantType: string): string
    return PlantEmojis[plantType] or "🌱"
end

-- ============================================
-- MUTATION EMOJI MAPPING
-- ============================================
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

local function getMutationEmoji(mutationType: string): string
    return MutationEmojis[mutationType] or "✨"
end

-- ============================================
-- THEME MODULE
-- ============================================
local CasualTheme = {
    Colors = Colors,
    CardColorPresets = CardColorPresets,
    Fonts = Fonts,
    Sizing = Sizing,
    GetPlantEmoji = getPlantEmoji,
    GetMutationEmoji = getMutationEmoji,
}

-- ============================================
-- UNIT CARD COMPONENT
-- The main plant card in the bottom deck bar
-- Pixel-perfect replica of the reference image
-- ============================================
function CasualTheme.UnitCard(scope: any, props: {
    PlantType: any,             -- Value<string?> or Computed<string?>
    Cost: any,                  -- Value<number> or Computed<number>
    SlotIndex: number,          -- 1-6 for color presets
    IsSelected: any?,           -- Value<boolean> or Computed<boolean>
    IsDisabled: any?,           -- Value<boolean> (not enough sun, cooldown)
    OnClick: (() -> ())?,
    Hotkey: string?,            -- Optional keyboard hotkey display
}): any
    local isHovered = Value(scope, false)
    local isPressed = Value(scope, false)
    
    -- Get card background color from preset or fallback
    local slotColor = CardColorPresets[props.SlotIndex] or Colors.AppleGreen
    
    -- Animated scale for "juicy" bounce effect
    local targetScale = Computed(scope, function(use)
        local selected = props.IsSelected and use(props.IsSelected)
        local pressed = use(isPressed)
        local hovered = use(isHovered)
        
        if pressed then return 0.92 end
        if selected then return 1.08 end
        if hovered then return 1.04 end
        return 1
    end)
    
    local springScale = Spring(scope, targetScale, 35, 0.7)
    
    return New(scope, "Frame") {
        Name = "UnitCard",
        Size = Sizing.UnitCardSize,
        BackgroundTransparency = 1, -- Container is transparent
        
        [Children] = {
            -- Scale container for bounce animation
            New(scope, "Frame") {
                Name = "ScaleContainer",
                Size = UDim2.new(1, 0, 1, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                BackgroundTransparency = 1,
                
                [Children] = {
                    New(scope, "UIScale") {
                        Scale = springScale,
                    },
                    
                    -- Main Card Body (Squircle)
                    New(scope, "Frame") {
                        Name = "CardBody",
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 0, -- OPAQUE
                        BackgroundColor3 = Computed(scope, function(use)
                            local disabled = props.IsDisabled and use(props.IsDisabled)
                            if disabled then return Colors.Disabled end
                            return slotColor
                        end),
                        
                        [Children] = {
                            -- Squircle corners
                            New(scope, "UICorner") { 
                                CornerRadius = Sizing.SquircleMedium,
                            },
                            
                            -- Thick dark cartoon stroke
                            New(scope, "UIStroke") {
                                Color = Computed(scope, function(use)
                                    local selected = props.IsSelected and use(props.IsSelected)
                                    if selected then return Colors.StrokeSelected end
                                    return Colors.StrokeDark
                                end),
                                Thickness = Computed(scope, function(use)
                                    local selected = props.IsSelected and use(props.IsSelected)
                                    return if selected then Sizing.StrokeHeavy else Sizing.StrokeThick
                                end),
                            },
                            
                            -- Glossy gradient overlay (cartoon shine) - COLOR BLEND
                            New(scope, "UIGradient") {
                                Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                                    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(245, 245, 245)),
                                    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(220, 220, 220)),
                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
                                }),
                                Rotation = 90,
                            },
                            
                            -- Plant Icon (emoji centered)
                            New(scope, "TextLabel") {
                                Name = "PlantIcon",
                                Size = UDim2.new(1, 0, 0, 50),
                                Position = UDim2.new(0, 0, 0, 8),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    local plant = if typeof(props.PlantType) == "table" 
                                        then use(props.PlantType) 
                                        else props.PlantType
                                    return if plant then getPlantEmoji(plant) else "➕"
                                end),
                                TextSize = 36,
                                TextColor3 = Colors.TextWhite,
                                Font = Enum.Font.SourceSans, -- Emoji font
                                
                                [Children] = {
                                    -- Drop shadow for icon
                                    New(scope, "UIStroke") {
                                        Color = Colors.TextShadow,
                                        Thickness = 1,
                                        Transparency = 0.5,
                                    },
                                },
                            },
                            
                            -- Cost Badge (blue pill in bottom-left corner)
                            New(scope, "Frame") {
                                Name = "CostBadge",
                                Size = Sizing.CostBadgeSize,
                                Position = UDim2.new(0, -4, 1, -6),
                                AnchorPoint = Vector2.new(0, 1),
                                BackgroundColor3 = Colors.CostBadge,
                                BackgroundTransparency = 0, -- OPAQUE
                                ZIndex = 5,
                                
                                [Children] = {
                                    New(scope, "UICorner") { 
                                        CornerRadius = UDim.new(0.5, 0), -- Pill shape
                                    },
                                    New(scope, "UIStroke") {
                                        Color = Colors.StrokeDark,
                                        Thickness = Sizing.StrokeNormal,
                                    },
                                    
                                    -- Cost number
                                    New(scope, "TextLabel") {
                                        Size = UDim2.new(1, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = Computed(scope, function(use)
                                            local cost = if typeof(props.Cost) == "table"
                                                then use(props.Cost)
                                                else props.Cost
                                            return tostring(cost or 0)
                                        end),
                                        TextColor3 = Colors.TextWhite,
                                        TextSize = 14,
                                        Font = Fonts.Numbers,
                                        
                                        [Children] = {
                                            New(scope, "UIStroke") {
                                                Color = Colors.TextShadow,
                                                Thickness = 1,
                                            },
                                        },
                                    },
                                },
                            },
                            
                            -- Hotkey Badge (optional, top-right corner)
                            if props.Hotkey then New(scope, "Frame") {
                                Name = "HotkeyBadge",
                                Size = UDim2.fromOffset(20, 18),
                                Position = UDim2.new(1, 2, 0, -2),
                                AnchorPoint = Vector2.new(1, 0),
                                BackgroundColor3 = Colors.PanelDark,
                                ZIndex = 5,
                                
                                [Children] = {
                                    New(scope, "UICorner") { 
                                        CornerRadius = UDim.new(0, 6),
                                    },
                                    New(scope, "UIStroke") {
                                        Color = Colors.StrokeMedium,
                                        Thickness = 2,
                                    },
                                    New(scope, "TextLabel") {
                                        Size = UDim2.new(1, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = props.Hotkey,
                                        TextColor3 = Colors.TextLight,
                                        TextSize = 11,
                                        Font = Fonts.Numbers,
                                    },
                                },
                            } else nil,
                            
                            -- Click detector (invisible button)
                            if props.OnClick then New(scope, "TextButton") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "",
                                ZIndex = 10,
                                
                                [OnEvent "Activated"] = function()
                                    local disabled = props.IsDisabled and Fusion.peek(props.IsDisabled)
                                    if not disabled and props.OnClick then
                                        props.OnClick()
                                    end
                                end,
                                [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                                [OnEvent "MouseLeave"] = function() 
                                    isHovered:set(false) 
                                    isPressed:set(false)
                                end,
                                [OnEvent "MouseButton1Down"] = function() isPressed:set(true) end,
                                [OnEvent "MouseButton1Up"] = function() isPressed:set(false) end,
                            } else nil,
                        },
                    },
                },
            },
        },
    }
end

-- ============================================
-- RESOURCE PILL COMPONENT
-- Top HUD resource display (coins, gems)
-- Glossy gradient style like in reference image
-- ============================================
function CasualTheme.ResourcePill(scope: any, props: {
    Icon: string,
    Value: any,                 -- string | Computed<string>
    Color: Color3?,
    BackgroundColor: Color3?,
}): any
    local bgColor = props.BackgroundColor or Colors.CoinsPill
    
    return New(scope, "Frame") {
        Name = "ResourcePill",
        Size = UDim2.fromOffset(Sizing.ResourcePillWidth, Sizing.ResourcePillHeight),
        BackgroundColor3 = bgColor,
        BackgroundTransparency = 0, -- OPAQUE
        
        [Children] = {
            -- Squircle corners (more rounded like in image)
            New(scope, "UICorner") { 
                CornerRadius = UDim.new(0, 22), -- Very rounded, almost pill
            },
            
            -- Thick cartoon stroke
            New(scope, "UIStroke") { 
                Color = Colors.StrokeDark, 
                Thickness = Sizing.StrokeThick,
            },
            
            -- Glossy gradient (top-to-bottom shine) - COLOR ONLY
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(0.3, Color3.fromRGB(250, 250, 250)),
                    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(230, 230, 230)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
                }),
                Rotation = 90,
            },
            
            -- Icon (left side)
            New(scope, "TextLabel") {
                Size = UDim2.fromOffset(36, Sizing.ResourcePillHeight),
                Position = UDim2.fromOffset(10, 0),
                BackgroundTransparency = 1,
                Text = props.Icon,
                TextSize = 22,
                
                [Children] = {
                    New(scope, "UIStroke") {
                        Color = Colors.TextShadow,
                        Thickness = 1,
                        Transparency = 0.5,
                    },
                },
            },
            
            -- Value (right side, bold white text)
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -54, 1, 0),
                Position = UDim2.fromOffset(46, 0),
                BackgroundTransparency = 1,
                Text = props.Value,
                TextColor3 = props.Color or Colors.TextWhite,
                TextSize = 18,
                Font = Fonts.Numbers,
                TextXAlignment = Enum.TextXAlignment.Left,
                
                [Children] = {
                    New(scope, "UIStroke") {
                        Color = Colors.TextShadow,
                        Thickness = 1,
                        Transparency = 0.3,
                    },
                },
            },
        },
    }
end

-- ============================================
-- LEVEL BADGE COMPONENT
-- Player level display with star icon (from image)
-- ============================================
function CasualTheme.LevelBadge(scope: any, props: {
    Level: any,                 -- number | Computed<number>
    Size: UDim2?,
}): any
    return New(scope, "Frame") {
        Name = "LevelBadge",
        Size = props.Size or UDim2.fromOffset(100, 40),
        BackgroundColor3 = Colors.ManaBlue,
        
        [Children] = {
            New(scope, "UICorner") { 
                CornerRadius = Sizing.SquircleMedium,
            },
            New(scope, "UIStroke") { 
                Color = Colors.StrokeDark, 
                Thickness = Sizing.StrokeThick,
            },
            
            -- Star icon (left side)
            New(scope, "Frame") {
                Name = "StarContainer",
                Size = UDim2.fromOffset(32, 32),
                Position = UDim2.fromOffset(-8, 4),
                BackgroundColor3 = Colors.LevelBadge,
                Rotation = 15,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 6) },
                    New(scope, "UIStroke") { 
                        Color = Colors.StrokeDark, 
                        Thickness = Sizing.StrokeNormal,
                    },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "⭐",
                        TextSize = 18,
                        Rotation = -15, -- Counter-rotate text
                    },
                },
            },
            
            -- Level text
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -30, 1, 0),
                Position = UDim2.fromOffset(30, 0),
                BackgroundTransparency = 1,
                Text = Computed(scope, function(use)
                    local level = if typeof(props.Level) == "table"
                        then use(props.Level)
                        else props.Level
                    return "Lv " .. tostring(level or 1)
                end),
                TextColor3 = Colors.TextWhite,
                TextSize = 16,
                Font = Fonts.Header,
                TextXAlignment = Enum.TextXAlignment.Center,
                
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
-- DECK BAR COMPONENT
-- Bottom bar containing unit cards
-- Matches reference image style
-- ============================================
function CasualTheme.DeckBar(scope: any, props: {
    Children: any?,
}): any
    return New(scope, "Frame") {
        Name = "DeckBar",
        Size = UDim2.new(0, 0, 0, Sizing.BottomBarHeight), -- Width adapts to content
        AutomaticSize = Enum.AutomaticSize.X, -- Auto-width based on children
        Position = UDim2.new(0.5, 0, 1, -12),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = Colors.CardBar,
        BackgroundTransparency = 0, -- OPAQUE
        
        [Children] = {
            -- Squircle corners (heavy rounding like in image)
            New(scope, "UICorner") { 
                CornerRadius = UDim.new(0, 28), -- Very rounded
            },
            
            -- Thick dark stroke
            New(scope, "UIStroke") { 
                Color = Colors.CardBarBorder, 
                Thickness = Sizing.StrokeThick,
            },
            
            -- Subtle inner gradient for depth - COLOR ONLY
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 115, 145)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 95, 125)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 70, 95)),
                }),
                Rotation = 90,
            },
            
            -- Padding for content (creates space around cards)
            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 16),
                PaddingRight = UDim.new(0, 16),
                PaddingTop = UDim.new(0, 10),
                PaddingBottom = UDim.new(0, 10),
            },
            
            -- Horizontal layout with proper spacing
            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 12), -- More spacing between cards
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                VerticalAlignment = Enum.VerticalAlignment.Center,
            },
            
            props.Children,
        },
    }
end

-- ============================================
-- PLAYER AVATAR FRAME
-- Circular avatar with light blue border (from image top-left)
-- ============================================
function CasualTheme.AvatarFrame(scope: any, props: {
    UserId: number?,
    Size: UDim2?,
}): any
    local size = props.Size or UDim2.fromOffset(70, 70)
    
    return New(scope, "Frame") {
        Name = "AvatarFrame",
        Size = size,
        BackgroundColor3 = Colors.AvatarFrame, -- Light blue like in image
        BackgroundTransparency = 0, -- OPAQUE
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
            New(scope, "UIStroke") { 
                Color = Colors.StrokeDark, 
                Thickness = Sizing.StrokeThick,
            },
            
            -- Glossy shine on frame - COLOR ONLY
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 248, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 210, 230)),
                }),
                Rotation = 90,
            },
            
            -- Inner avatar image (circular, slightly smaller)
            New(scope, "ImageLabel") {
                Size = UDim2.new(1, -10, 1, -10),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(200, 200, 200),
                Image = props.UserId 
                    and ("rbxthumb://type=AvatarHeadShot&id=" .. props.UserId .. "&w=150&h=150")
                    or "",
                    
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                },
            },
        },
    }
end

-- ============================================
-- JUICY BUTTON
-- Tactile, bouncy button with cartoon style
-- ============================================
function CasualTheme.JuicyButton(scope: any, props: {
    Text: string | any,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    Color: Color3?,
    OnClick: () -> (),
    Disabled: any?,
}): any
    local isHovered = Value(scope, false)
    local isPressed = Value(scope, false)
    
    local targetScale = Computed(scope, function(use)
        if use(isPressed) then return 0.92 end
        if use(isHovered) then return 1.05 end
        return 1
    end)
    
    local springScale = Spring(scope, targetScale, 35, 0.7)
    
    local bgColor = props.Color or Colors.AppleGreen
    
    return New(scope, "TextButton") {
        Size = props.Size or UDim2.fromOffset(150, 50),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        BackgroundColor3 = Computed(scope, function(use)
            local disabled = props.Disabled and use(props.Disabled)
            if disabled then return Colors.Disabled end
            if use(isPressed) then
                -- Slightly darker when pressed
                return Color3.new(
                    bgColor.R * 0.85,
                    bgColor.G * 0.85,
                    bgColor.B * 0.85
                )
            end
            return bgColor
        end),
        Text = props.Text,
        TextColor3 = Computed(scope, function(use)
            local disabled = props.Disabled and use(props.Disabled)
            return if disabled then Colors.TextMuted else Colors.TextWhite
        end),
        TextSize = 18,
        Font = Fonts.Button,
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = function()
            local disabled = props.Disabled and Fusion.peek(props.Disabled)
            if not disabled then props.OnClick() end
        end,
        [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
        [OnEvent "MouseLeave"] = function() 
            isHovered:set(false) 
            isPressed:set(false)
        end,
        [OnEvent "MouseButton1Down"] = function() isPressed:set(true) end,
        [OnEvent "MouseButton1Up"] = function() isPressed:set(false) end,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.SquircleMedium },
            New(scope, "UIStroke") { 
                Color = Colors.StrokeDark, 
                Thickness = Sizing.StrokeThick,
            },
            New(scope, "UIScale") { Scale = springScale },
            
            -- Glossy shine
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
                }),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.7),
                    NumberSequenceKeypoint.new(0.4, 0.85),
                    NumberSequenceKeypoint.new(1, 0.95),
                }),
                Rotation = 90,
            },
        },
    }
end

-- ============================================
-- MUTATION LAB COMPONENTS
-- Sci-Fi style mutation interface
-- ============================================

-- Mutation icons mapping
local MutationIcons: {[string]: string} = {
    Damage = "⚔️",
    Health = "🛡️",
    Range = "🎯",
    Speed = "⚡",
    Fire = "🔥",
    Ice = "❄️",
    Electric = "⚡",
    Toxic = "☠️",
    Shadow = "🌑",
    Solar = "☀️",
    Reinforced = "🛡️",
    Primal = "💥",
    Swift = "💨",
}

--[[
    MutationNode - Circular mutation slot in the lab
    Can be: unlocked (green), locked (gray), selected (cyan glow)
]]
function CasualTheme.MutationNode(scope: any, props: {
    MutationType: string,
    Label: string?,
    Icon: string?,
    IsUnlocked: any,            -- Value<boolean> or Computed<boolean>
    IsSelected: any?,           -- Value<boolean> or Computed<boolean>
    OnClick: (() -> ())?,
    Size: number?,
    Position: UDim2?,
}): any
    local isHovered = Value(scope, false)
    local size = props.Size or 70
    
    local icon = props.Icon or MutationIcons[props.MutationType] or "❓"
    
    -- Animated scale
    local targetScale = Computed(scope, function(use)
        local selected = props.IsSelected and use(props.IsSelected)
        local hovered = use(isHovered)
        if selected then return 1.1 end
        if hovered then return 1.05 end
        return 1
    end)
    local springScale = Spring(scope, targetScale, 30, 0.8)
    
    return New(scope, "Frame") {
        Name = "MutationNode",
        Size = UDim2.fromOffset(size, size + 24), -- Extra for label
        Position = props.Position,
        BackgroundTransparency = 1,
        
        [Children] = {
            -- Scale container
            New(scope, "Frame") {
                Size = UDim2.fromOffset(size, size),
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(0.5, 0, 0, 0),
                BackgroundTransparency = 1,
                
                [Children] = {
                    New(scope, "UIScale") { Scale = springScale },
                    
                    -- Main circle
                    New(scope, "Frame") {
                        Name = "NodeCircle",
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundColor3 = Computed(scope, function(use)
                            local unlocked = if typeof(props.IsUnlocked) == "table" 
                                then use(props.IsUnlocked) 
                                else props.IsUnlocked
                            return if unlocked then Colors.NodeUnlocked else Colors.NodeLocked
                        end),
                        BackgroundTransparency = 0,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            
                            -- Thick border
                            New(scope, "UIStroke") {
                                Color = Computed(scope, function(use)
                                    local selected = props.IsSelected and use(props.IsSelected)
                                    local unlocked = if typeof(props.IsUnlocked) == "table" 
                                        then use(props.IsUnlocked) 
                                        else props.IsUnlocked
                                    if selected then return Colors.NeonCyan end
                                    return if unlocked then Colors.NodeUnlockedDark else Colors.NodeLockedDark
                                end),
                                Thickness = Computed(scope, function(use)
                                    local selected = props.IsSelected and use(props.IsSelected)
                                    return if selected then 5 else 4
                                end),
                            },
                            
                            -- Gradient for 3D effect
                            New(scope, "UIGradient") {
                                Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                                    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 240, 240)),
                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
                                }),
                                Rotation = 90,
                            },
                            
                            -- Icon (or lock if locked)
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    local unlocked = if typeof(props.IsUnlocked) == "table" 
                                        then use(props.IsUnlocked) 
                                        else props.IsUnlocked
                                    return if unlocked then icon else "🔒"
                                end),
                                TextSize = math.floor(size * 0.45),
                                TextColor3 = Colors.TextWhite,
                                
                                [Children] = {
                                    New(scope, "UIStroke") {
                                        Color = Colors.TextShadow,
                                        Thickness = 1,
                                        Transparency = 0.3,
                                    },
                                },
                            },
                            
                            -- Click detector
                            if props.OnClick then New(scope, "TextButton") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "",
                                ZIndex = 10,
                                
                                [OnEvent "Activated"] = props.OnClick,
                                [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                                [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
                            } else nil,
                        },
                    },
                },
            },
            
            -- Label below
            if props.Label then New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 20),
                Position = UDim2.new(0.5, 0, 1, -18),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Text = props.Label,
                TextSize = 13,
                Font = Fonts.Header,
                TextColor3 = Colors.TextWhite,
                
                [Children] = {
                    New(scope, "UIStroke") {
                        Color = Colors.TextShadow,
                        Thickness = 1,
                        Transparency = 0.3,
                    },
                },
            } else nil,
        },
    }
end

--[[
    PlantCapsule - Central holographic capsule showing the plant
    Glowing cyan/blue effect like in the reference
]]
function CasualTheme.PlantCapsule(scope: any, props: {
    PlantType: any,             -- string or Value<string>
    Size: UDim2?,
}): any
    local size = props.Size or UDim2.fromOffset(140, 160)
    
    return New(scope, "Frame") {
        Name = "PlantCapsule",
        Size = size,
        BackgroundTransparency = 1,
        
        [Children] = {
            -- Outer glow ring
            New(scope, "Frame") {
                Size = UDim2.new(1, 40, 1, 40),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Colors.NeonCyan,
                BackgroundTransparency = 0.7,
                ZIndex = 0,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                },
            },
            
            -- Inner glow
            New(scope, "Frame") {
                Size = UDim2.new(1, 20, 1, 20),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Colors.HologramBlue,
                BackgroundTransparency = 0.5,
                ZIndex = 1,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                },
            },
            
            -- Main capsule circle
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Colors.LabBgMedium,
                BackgroundTransparency = 0,
                ZIndex = 2,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    New(scope, "UIStroke") {
                        Color = Colors.NeonCyan,
                        Thickness = 4,
                    },
                    
                    -- Hologram gradient
                    New(scope, "UIGradient") {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 120, 180)),
                            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 80, 140)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 50, 90)),
                        }),
                        Rotation = 90,
                    },
                    
                    -- Plant emoji
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 0.7, 0),
                        Position = UDim2.new(0.5, 0, 0.4, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            local plantType = if typeof(props.PlantType) == "table"
                                then use(props.PlantType)
                                else props.PlantType
                            return getPlantEmoji(plantType or "Sunflower")
                        end),
                        TextSize = 60,
                        ZIndex = 3,
                    },
                },
            },
            
            -- Base/pedestal
            New(scope, "Frame") {
                Size = UDim2.fromOffset(100, 30),
                Position = UDim2.new(0.5, 0, 1, -15),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Colors.LabBgLight,
                BackgroundTransparency = 0,
                ZIndex = 4,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    New(scope, "UIStroke") {
                        Color = Colors.NeonCyanDark,
                        Thickness = 3,
                    },
                    New(scope, "UIGradient") {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 140, 180)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 80, 120)),
                        }),
                        Rotation = 90,
                    },
                },
            },
        },
    }
end

--[[
    LabTitle - Glowing neon title text
]]
function CasualTheme.LabTitle(scope: any, props: {
    Text: string,
    Size: UDim2?,
    Position: UDim2?,
}): any
    return New(scope, "TextLabel") {
        Size = props.Size or UDim2.new(1, 0, 0, 50),
        Position = props.Position or UDim2.new(0.5, 0, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Text = props.Text,
        TextSize = 32,
        Font = Fonts.Title,
        TextColor3 = Colors.NeonCyan,
        
        [Children] = {
            -- Glow effect (double stroke)
            New(scope, "UIStroke") {
                Color = Colors.NeonCyanDark,
                Thickness = 3,
                Transparency = 0.3,
            },
        },
    }
end

--[[
    LabBackButton - Orange/yellow back button
]]
function CasualTheme.LabBackButton(scope: any, props: {
    OnClick: () -> (),
}): any
    local isHovered = Value(scope, false)
    
    return New(scope, "TextButton") {
        Size = UDim2.fromOffset(90, 36),
        Position = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Computed(scope, function(use)
            return if use(isHovered) 
                then Color3.fromRGB(255, 180, 60)
                else Color3.fromRGB(255, 150, 40)
        end),
        BackgroundTransparency = 0,
        Text = "",
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = props.OnClick,
        [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
        [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
            New(scope, "UIStroke") {
                Color = Color3.fromRGB(180, 100, 20),
                Thickness = 3,
            },
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 240, 220)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 180, 120)),
                }),
                Rotation = 90,
            },
            
            -- Arrow + Text
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "◀ BACK",
                TextSize = 14,
                Font = Fonts.Header,
                TextColor3 = Colors.TextDark,
            },
        },
    }
end

--[[
    LabResourceBar - Top right coins/gems display
]]
function CasualTheme.LabResourceBar(scope: any, props: {
    Coins: any,
    Gems: any,
}): any
    return New(scope, "Frame") {
        Size = UDim2.fromOffset(200, 36),
        Position = UDim2.new(1, -16, 0, 16),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        
        [Children] = {
            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 8),
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                VerticalAlignment = Enum.VerticalAlignment.Center,
            },
            
            -- Coins
            New(scope, "Frame") {
                Size = UDim2.fromOffset(85, 32),
                BackgroundColor3 = Colors.CoinsPill,
                BackgroundTransparency = 0,
                LayoutOrder = 1,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    New(scope, "UIStroke") { Color = Colors.StrokeDark, Thickness = 3 },
                    New(scope, "UIGradient") {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 200)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 180, 100)),
                        }),
                        Rotation = 90,
                    },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            local coins = if typeof(props.Coins) == "table" then use(props.Coins) else props.Coins
                            return "🪙 " .. tostring(coins or 0)
                        end),
                        TextSize = 14,
                        Font = Fonts.Numbers,
                        TextColor3 = Colors.TextDark,
                    },
                },
            },
            
            -- Gems
            New(scope, "Frame") {
                Size = UDim2.fromOffset(65, 32),
                BackgroundColor3 = Colors.GemsPill,
                BackgroundTransparency = 0,
                LayoutOrder = 2,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    New(scope, "UIStroke") { Color = Colors.StrokeDark, Thickness = 3 },
                    New(scope, "UIGradient") {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 200, 255)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 100, 200)),
                        }),
                        Rotation = 90,
                    },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            local gems = if typeof(props.Gems) == "table" then use(props.Gems) else props.Gems
                            return "💎 " .. tostring(gems or 0)
                        end),
                        TextSize = 14,
                        Font = Fonts.Numbers,
                        TextColor3 = Colors.TextWhite,
                    },
                },
            },
        },
    }
end

return table.freeze(CasualTheme)
