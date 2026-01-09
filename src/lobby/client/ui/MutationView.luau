--!strict
--[[
    MutationView.luau - Mutation Lab Interface
    
    Sci-Fi themed mutation management with:
    - Holographic plant capsule in center
    - Circular mutation nodes around the plant
    - Neon cyan/blue glow effects
    
    Redesigned to match "Mutation Lab" reference image.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MutationData = require(Shared.data.MutationData)
local PlantData = require(Shared.data.PlantData)
local CasualTheme = require(Shared.ui.CasualTheme)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local peek = Fusion.peek

local Colors = CasualTheme.Colors
local Fonts = CasualTheme.Fonts

-- Constants
local MAX_EQUIPPED_MUTATIONS = 3
local NODE_SIZE = 70
local CAPSULE_SIZE = 140
local ORBIT_RADIUS = 170  -- Distance from center to mutation nodes

-- Mutation icons mapping
local MUTATION_ICONS: {[string]: string} = {
    Fire = "🔥",
    Ice = "❄️",
    Electric = "⚡",
    Toxic = "☠️",
    Shadow = "🌑",
    Solar = "☀️",
    Reinforced = "🛡️",
    Primal = "💥",
    Swift = "💨",
    Damage = "⚔️",
    Health = "🛡️",
    Range = "🎯",
    Speed = "⚡",
    Inferno = "🔥",
    Frost = "❄️",
    Storm = "⚡",
    Plague = "☠️",
    Void = "🌑",
    Radiant = "☀️",
    Fortress = "🏰",
    Savage = "💥",
}

-- Plant emojis
local PLANT_EMOJIS: {[string]: string} = {
    Sunflower = "🌻",
    Peashooter = "🌱",
    Cactus = "🌵",
    Mushroom = "🍄",
    Rose = "🌹",
    Succulent = "🪴",
    Tree = "🌳",
}

local function getPlantEmoji(plantType: string): string
    return PLANT_EMOJIS[plantType] or "🌱"
end

local function getMutationIcon(mutationType: string): string
    return MUTATION_ICONS[mutationType] or "✨"
end

export type MutationViewProps = {
    PlayerData: any,
    OwnedMutations: any,
    EquippedMutations: any,
    OnBack: () -> (),
    OnPurchaseMutation: (plantType: string, mutationType: string) -> (),
    OnEquipMutation: (plantType: string, mutationType: string) -> (),
    OnUnequipMutation: (plantType: string, mutationType: string) -> (),
}

--------------------------------------------------------------------------------
-- HELPER: Calculate circular position for nodes
--------------------------------------------------------------------------------
local function getCircularPosition(index: number, total: number, radius: number): UDim2
    local angle = (index - 1) * (2 * math.pi / total) - math.pi / 2 -- Start from top
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    return UDim2.new(0.5, x, 0.5, y)
end

-- Get angle in degrees for a node position
local function getNodeAngle(index: number, total: number): number
    local angle = (index - 1) * (2 * math.pi / total) - math.pi / 2
    return math.deg(angle)
end

--------------------------------------------------------------------------------
-- SKILL TREE CONNECTION LINE (simple straight line from capsule to node)
--------------------------------------------------------------------------------
local function SkillTreeConnection(scope: any, props: {
    NodeIndex: number,   -- Which node (1-8)
    TotalNodes: number,  -- Total number of nodes
    IsActive: any,       -- If the connection is unlocked
}): any
    -- Calculate angle for this node (same as node position calculation)
    local angle = ((props.NodeIndex - 1) / props.TotalNodes) * math.pi * 2 - math.pi / 2
    
    -- Start point: edge of capsule outer ring
    local startRadius = 110  -- Just outside the capsule rings
    local startX = math.cos(angle) * startRadius
    local startY = math.sin(angle) * startRadius
    
    -- End point: just before the mutation node
    local endRadius = ORBIT_RADIUS - 40  -- Stop before the node
    local endX = math.cos(angle) * endRadius
    local endY = math.sin(angle) * endRadius
    
    -- Calculate line properties
    local deltaX = endX - startX
    local deltaY = endY - startY
    local lineLength = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    local lineAngle = math.deg(math.atan2(deltaY, deltaX))
    
    -- Midpoint for positioning
    local midX = (startX + endX) / 2
    local midY = (startY + endY) / 2
    
    return New(scope, "Frame") {
        Name = "SkillTreeConnection",
        Size = UDim2.fromOffset(lineLength, 6),
        Position = UDim2.new(0.5, midX, 0.5, midY),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = lineAngle,
        BackgroundColor3 = Computed(scope, function(use)
            local active = if typeof(props.IsActive) == "table" 
                then use(props.IsActive) else props.IsActive
            return if active then Colors.NeonCyan else Color3.fromRGB(45, 55, 70)
        end),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 2,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0, 3) },
            
            -- Glow for active
            Computed(scope, function(use)
                local active = if typeof(props.IsActive) == "table" 
                    then use(props.IsActive) else props.IsActive
                if active then
                    return New(scope, "Frame") {
                        Size = UDim2.new(1, 4, 1, 8),
                        Position = UDim2.new(0.5, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Colors.NeonCyan,
                        BackgroundTransparency = 0.6,
                        BorderSizePixel = 0,
                        ZIndex = 1,
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0, 6) },
                        },
                    }
                end
                return nil
            end),
            
            -- Diamond at start
            New(scope, "Frame") {
                Size = UDim2.fromOffset(8, 8),
                Position = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Rotation = 45,
                BackgroundColor3 = Computed(scope, function(use)
                    local active = if typeof(props.IsActive) == "table" 
                        then use(props.IsActive) else props.IsActive
                    return if active then Colors.NeonCyan else Color3.fromRGB(55, 65, 80)
                end),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 3,
            },
            
            -- Diamond at end
            New(scope, "Frame") {
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.new(1, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Rotation = 45,
                BackgroundColor3 = Computed(scope, function(use)
                    local active = if typeof(props.IsActive) == "table" 
                        then use(props.IsActive) else props.IsActive
                    return if active then Colors.NeonCyan else Color3.fromRGB(55, 65, 80)
                end),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 3,
            },
        },
    }
end

--------------------------------------------------------------------------------
-- PLANT SELECTOR CARD (horizontal list at top)
--------------------------------------------------------------------------------
local function PlantSelectorCard(scope: any, props: {
    PlantType: string,
    IsSelected: any,
    OnSelect: () -> (),
    EquippedCount: any,
}): any
    local isHovered = Value(scope, false)
    
    local targetScale = Computed(scope, function(use)
        local selected = use(props.IsSelected)
        local hovered = use(isHovered)
        if selected then return 1.1 end
        if hovered then return 1.05 end
        return 1
    end)
    local springScale = Spring(scope, targetScale, 30, 0.8)
    
    return New(scope, "Frame") {
        Size = UDim2.fromOffset(80, 90),
        BackgroundTransparency = 1,
        
        [Children] = {
            New(scope, "UIScale") { Scale = springScale },
            
            -- Card background
            New(scope, "Frame") {
                Size = UDim2.fromOffset(70, 70),
                Position = UDim2.new(0.5, 0, 0, 0),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundColor3 = Computed(scope, function(use)
                    return if use(props.IsSelected) then Colors.NeonCyan else Colors.LabBgLight
                end),
                BackgroundTransparency = 0,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.25, 0) },
                    New(scope, "UIStroke") {
                        Color = Computed(scope, function(use)
                            return if use(props.IsSelected) then Colors.NeonCyanDark else Colors.StrokeDark
                        end),
                        Thickness = Computed(scope, function(use)
                            return if use(props.IsSelected) then 4 else 3
                        end),
                    },
                    
                    -- Glossy gradient
                    New(scope, "UIGradient") {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 250, 255)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 200, 220)),
                        }),
                        Rotation = 90,
                    },
                    
                    -- Plant emoji
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 0.7, 0),
                        Position = UDim2.new(0.5, 0, 0.35, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Text = getPlantEmoji(props.PlantType),
                        TextSize = 36,
                    },
                    
                    -- Equipped count badge
                    Computed(scope, function(use)
                        local count = use(props.EquippedCount)
                        if count > 0 then
                            return New(scope, "Frame") {
                                Size = UDim2.fromOffset(24, 24),
                                Position = UDim2.new(1, -2, 0, -2),
                                AnchorPoint = Vector2.new(1, 0),
                                BackgroundColor3 = Colors.NodeUnlocked,
                                
                                [Children] = {
                                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                                    New(scope, "UIStroke") { Color = Colors.StrokeDark, Thickness = 2 },
                                    New(scope, "TextLabel") {
                                        Size = UDim2.new(1, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = tostring(count),
                                        TextSize = 12,
                                        Font = Fonts.Numbers,
                                        TextColor3 = Colors.TextWhite,
                                    },
                                },
                            }
                        end
                        return nil
                    end),
                    
                    -- Click detector
                    New(scope, "TextButton") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "",
                        ZIndex = 10,
                        
                        [OnEvent "Activated"] = props.OnSelect,
                        [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                        [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
                    },
                },
            },
            
            -- Plant name label
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 18),
                Position = UDim2.new(0.5, 0, 1, -16),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Text = props.PlantType,
                TextSize = 11,
                Font = Fonts.Header,
                TextColor3 = Colors.TextWhite,
                
                [Children] = {
                    New(scope, "UIStroke") {
                        Color = Colors.TextShadow,
                        Thickness = 1,
                        Transparency = 0.5,
                    },
                },
            },
        },
    }
end

--------------------------------------------------------------------------------
-- MUTATION NODE (circular slot in the lab)
--------------------------------------------------------------------------------
local function MutationNode(scope: any, props: {
    MutationType: string,
    MutationData: any,
    Position: UDim2,
    IsOwned: any,
    IsEquipped: any,
    OnClick: () -> (),
}): any
    local isHovered = Value(scope, false)
    
    local icon = getMutationIcon(props.MutationType)
    local data = props.MutationData
    
    local targetScale = Computed(scope, function(use)
        local equipped = use(props.IsEquipped)
        local hovered = use(isHovered)
        if equipped then return 1.15 end
        if hovered then return 1.08 end
        return 1
    end)
    local springScale = Spring(scope, targetScale, 28, 0.75)
    
    return New(scope, "Frame") {
        Name = `Node_{props.MutationType}`,
        Size = UDim2.fromOffset(NODE_SIZE, NODE_SIZE + 20),
        Position = props.Position,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        
        [Children] = {
            -- Scale container
            New(scope, "Frame") {
                Size = UDim2.fromOffset(NODE_SIZE, NODE_SIZE),
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(0.5, 0, 0, 0),
                BackgroundTransparency = 1,
                
                [Children] = {
                    New(scope, "UIScale") { Scale = springScale },
                    
                    -- Glow ring (when equipped)
                    Computed(scope, function(use)
                        if use(props.IsEquipped) then
                            return New(scope, "Frame") {
                                Size = UDim2.new(1, 16, 1, 16),
                                Position = UDim2.new(0.5, 0, 0.5, 0),
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundColor3 = Colors.NeonCyan,
                                BackgroundTransparency = 0.6,
                                ZIndex = 0,
                                
                                [Children] = {
                                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                                },
                            }
                        end
                        return nil
                    end),
                    
                    -- Main circle
                    New(scope, "Frame") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundColor3 = Computed(scope, function(use)
                            local owned = use(props.IsOwned)
                            local equipped = use(props.IsEquipped)
                            if equipped then return Colors.NodeUnlocked end -- Equipped = green
                            if owned then return Colors.NodeUnlocked end     -- Owned = green
                            return Colors.NodeLocked                          -- Locked = gray
                        end),
                        BackgroundTransparency = 0,
                        ZIndex = 1,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            
                            -- Golden border for unlocked, dark gray for locked
                            New(scope, "UIStroke") {
                                Color = Computed(scope, function(use)
                                    local owned = use(props.IsOwned)
                                    local equipped = use(props.IsEquipped)
                                    if equipped or owned then 
                                        return Colors.NodeUnlockedBorder or Color3.fromRGB(255, 180, 50)
                                    end
                                    return Colors.NodeLockedDark
                                end),
                                Thickness = Computed(scope, function(use)
                                    local owned = use(props.IsOwned)
                                    return if owned then 5 else 3
                                end),
                            },
                            
                            -- Glossy gradient
                            New(scope, "UIGradient") {
                                Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                                    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 240, 240)),
                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
                                }),
                                Rotation = 90,
                            },
                            
                            -- Icon (colored for unlocked, orange lock for locked)
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    return if use(props.IsOwned) then icon else "🔒"
                                end),
                                TextSize = Computed(scope, function(use)
                                    return if use(props.IsOwned) 
                                        then math.floor(NODE_SIZE * 0.5)
                                        else math.floor(NODE_SIZE * 0.4)
                                end),
                                TextColor3 = Computed(scope, function(use)
                                    -- Lock icon is orange, regular icons are white
                                    return if use(props.IsOwned) 
                                        then Colors.TextWhite 
                                        else Colors.NodeLockIcon or Color3.fromRGB(255, 160, 50)
                                end),
                                ZIndex = 2,
                                
                                [Children] = {
                                    New(scope, "UIStroke") {
                                        Color = Colors.TextShadow,
                                        Thickness = 1,
                                        Transparency = 0.4,
                                    },
                                },
                            },
                            
                            -- Click detector
                            New(scope, "TextButton") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "",
                                ZIndex = 10,
                                
                                [OnEvent "Activated"] = props.OnClick,
                                [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                                [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
                            },
                        },
                    },
                },
            },
            
            -- Label below node
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 20, 0, 18),
                Position = UDim2.new(0.5, 0, 1, -16),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Text = data and data.Name or props.MutationType,
                TextSize = 11,
                Font = Fonts.Header,
                TextColor3 = Colors.TextWhite,
                TextTruncate = Enum.TextTruncate.AtEnd,
                
                [Children] = {
                    New(scope, "UIStroke") {
                        Color = Colors.TextShadow,
                        Thickness = 1,
                        Transparency = 0.4,
                    },
                },
            },
        },
    }
end

--------------------------------------------------------------------------------
-- PLANT CAPSULE (holographic center display)
--------------------------------------------------------------------------------
-- Rune symbols for mystical rings
local RUNE_SYMBOLS = {"◆", "◇", "●", "○", "▲", "△", "■", "□", "★", "☆", "✦", "✧", "⬡", "⬢"}

local function PlantCapsule(scope: any, props: {
    PlantType: any,
}): any
    -- Create multiple concentric rune ring texts
    local function createRuneRing(ringIndex: number, radius: number, numSymbols: number)
        local symbols = {}
        for i = 1, numSymbols do
            local angle = (i / numSymbols) * math.pi * 2 + (ringIndex * 0.2) -- offset each ring
            local x = math.cos(angle) * radius
            local y = math.sin(angle) * radius
            local symbol = RUNE_SYMBOLS[(i + ringIndex) % #RUNE_SYMBOLS + 1]
            
            table.insert(symbols, New(scope, "TextLabel") {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(0.5, x, 0.5, y - 10),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Text = symbol,
                TextSize = 10 + ringIndex * 2,
                TextColor3 = Colors.NeonCyan,
                TextTransparency = 0.4 + (ringIndex * 0.15),
                Rotation = math.deg(angle) + 90,
                ZIndex = 0,
            })
        end
        return symbols
    end
    
    -- Collect all rune symbols from rings
    local runeSymbols = {}
    -- Ring 1: Outermost - large radius, fewer symbols
    for _, symbol in ipairs(createRuneRing(1, CAPSULE_SIZE * 0.85, 16)) do
        table.insert(runeSymbols, symbol)
    end
    -- Ring 2: Middle ring
    for _, symbol in ipairs(createRuneRing(2, CAPSULE_SIZE * 0.65, 12)) do
        table.insert(runeSymbols, symbol)
    end
    -- Ring 3: Inner ring - smallest, most visible
    for _, symbol in ipairs(createRuneRing(3, CAPSULE_SIZE * 0.45, 8)) do
        table.insert(runeSymbols, symbol)
    end
    
    return New(scope, "Frame") {
        Name = "PlantCapsule",
        Size = UDim2.fromOffset(CAPSULE_SIZE * 2.2, CAPSULE_SIZE * 2.2),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        
        [Children] = {
            -- Mystical rune rings (symbols around the capsule)
            runeSymbols,
            
            -- Outermost ring glow
            New(scope, "Frame") {
                Size = UDim2.fromOffset(CAPSULE_SIZE + 80, CAPSULE_SIZE + 80),
                Position = UDim2.new(0.5, 0, 0.5, -10),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                ZIndex = 0,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    New(scope, "UIStroke") {
                        Color = Colors.NeonCyan,
                        Thickness = 2,
                        Transparency = 0.6,
                    },
                },
            },
            
            -- Second ring
            New(scope, "Frame") {
                Size = UDim2.fromOffset(CAPSULE_SIZE + 55, CAPSULE_SIZE + 55),
                Position = UDim2.new(0.5, 0, 0.5, -10),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                ZIndex = 0,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    New(scope, "UIStroke") {
                        Color = Colors.NeonCyan,
                        Thickness = 1.5,
                        Transparency = 0.5,
                    },
                },
            },
            
            -- Outer glow ring (existing)
            New(scope, "Frame") {
                Size = UDim2.fromOffset(CAPSULE_SIZE + 40, CAPSULE_SIZE + 40),
                Position = UDim2.new(0.5, 0, 0.5, -10),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Colors.NeonCyan,
                BackgroundTransparency = 0.8,
                ZIndex = 0,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                },
            },
            
            -- Inner glow
            New(scope, "Frame") {
                Size = UDim2.fromOffset(CAPSULE_SIZE + 20, CAPSULE_SIZE + 20),
                Position = UDim2.new(0.5, 0, 0.5, -10),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Colors.HologramBlue,
                BackgroundTransparency = 0.6,
                ZIndex = 1,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                },
            },
            
            -- Main capsule circle
            New(scope, "Frame") {
                Size = UDim2.fromOffset(CAPSULE_SIZE, CAPSULE_SIZE),
                Position = UDim2.new(0.5, 0, 0.5, -10),
                AnchorPoint = Vector2.new(0.5, 0.5),
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
                        Size = UDim2.new(1, 0, 1, 0),
                        Position = UDim2.new(0.5, 0, 0.45, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            local plantType = if typeof(props.PlantType) == "table"
                                then use(props.PlantType)
                                else props.PlantType
                            return getPlantEmoji(plantType or "")
                        end),
                        TextSize = 65,
                        ZIndex = 3,
                    },
                },
            },
            
            -- Base/pedestal
            New(scope, "Frame") {
                Size = UDim2.fromOffset(100, 28),
                Position = UDim2.new(0.5, 0, 1, -30),
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

--------------------------------------------------------------------------------
-- INFO PANEL (mutation details when clicking a node)
--------------------------------------------------------------------------------
local function InfoPanel(scope: any, props: {
    SelectedMutation: any,
    IsOwned: any,
    IsEquipped: any,
    CanPurchase: any,
    OnPurchase: () -> (),
    OnEquip: () -> (),
    OnUnequip: () -> (),
}): any
    return Computed(scope, function(use)
        local mutationType = use(props.SelectedMutation)
        if not mutationType then return nil end
        
        local data = MutationData.Get(mutationType)
        if not data then return nil end
        
        local isOwned = use(props.IsOwned)
        local isEquipped = use(props.IsEquipped)
        local canPurchase = use(props.CanPurchase)
        
        return New(scope, "Frame") {
            Size = UDim2.fromOffset(240, 130),
            Position = UDim2.new(1, -20, 0.5, 0),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Colors.LabBgMedium,
            BackgroundTransparency = 0,
            
            [Children] = {
                New(scope, "UICorner") { CornerRadius = UDim.new(0, 18) },
                New(scope, "UIStroke") {
                    Color = Colors.NeonCyanDark,
                    Thickness = 3,
                },
                New(scope, "UIPadding") {
                    PaddingTop = UDim.new(0, 12),
                    PaddingBottom = UDim.new(0, 12),
                    PaddingLeft = UDim.new(0, 14),
                    PaddingRight = UDim.new(0, 14),
                },
                
                -- Header: icon + name
                New(scope, "Frame") {
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundTransparency = 1,
                    
                    [Children] = {
                        New(scope, "TextLabel") {
                            Size = UDim2.fromOffset(28, 28),
                            BackgroundTransparency = 1,
                            Text = getMutationIcon(mutationType),
                            TextSize = 22,
                        },
                        New(scope, "TextLabel") {
                            Size = UDim2.new(1, -36, 1, 0),
                            Position = UDim2.fromOffset(32, 0),
                            BackgroundTransparency = 1,
                            Text = data.Name or mutationType,
                            TextSize = 16,
                            Font = Fonts.Title,
                            TextColor3 = Colors.TextWhite,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        },
                    },
                },
                
                -- Description
                New(scope, "TextLabel") {
                    Size = UDim2.new(1, 0, 0, 36),
                    Position = UDim2.fromOffset(0, 32),
                    BackgroundTransparency = 1,
                    Text = data.Description or "",
                    TextSize = 11,
                    Font = Fonts.Body,
                    TextColor3 = Colors.TextMuted,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    TextWrapped = true,
                },
                
                -- Level requirement
                New(scope, "TextLabel") {
                    Size = UDim2.fromOffset(80, 20),
                    Position = UDim2.fromOffset(0, 70),
                    BackgroundColor3 = Colors.LabBgLight,
                    Text = `Lv.{data.RequiredLevel}`,
                    TextSize = 11,
                    Font = Fonts.Body,
                    TextColor3 = Colors.TextMuted,
                    
                    [Children] = {
                        New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    },
                },
                
                -- Action button
                New(scope, "TextButton") {
                    Size = UDim2.new(1, 0, 0, 32),
                    Position = UDim2.new(0, 0, 1, 0),
                    AnchorPoint = Vector2.new(0, 1),
                    BackgroundColor3 = if isEquipped then Colors.Error
                        elseif isOwned then Colors.NodeUnlocked
                        elseif canPurchase then Colors.ManaBlue
                        else Colors.NodeLocked,
                    Text = "",
                    AutoButtonColor = false,
                    
                    [OnEvent "Activated"] = function()
                        if isEquipped then
                            props.OnUnequip()
                        elseif isOwned then
                            props.OnEquip()
                        elseif canPurchase then
                            props.OnPurchase()
                        end
                    end,
                    
                    [Children] = {
                        New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                        New(scope, "UIStroke") {
                            Color = Colors.StrokeDark,
                            Thickness = 3,
                        },
                        
                        New(scope, "TextLabel") {
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = if isEquipped then "✕ Unequip"
                                elseif isOwned then "⚡ Equip"
                                elseif canPurchase then `🪙 Buy {data.Cost}`
                                else "🔒 Locked",
                            TextSize = 13,
                            Font = Fonts.Header,
                            TextColor3 = Colors.TextWhite,
                        },
                    },
                },
            },
        }
    end)
end

--------------------------------------------------------------------------------
-- MAIN MUTATION VIEW
--------------------------------------------------------------------------------
local function MutationView(scope: any, props: MutationViewProps): any
    -- State
    local selectedPlant = Value(scope, nil :: string?)
    local selectedMutation = Value(scope, nil :: string?)
    
    -- Derived: unlocked plants
    local unlockedPlants = Computed(scope, function(use)
        local data = use(props.PlayerData)
        if not data then return {} end
        
        local result: {{Type: string, Stats: any}} = {}
        for plantType, stats in pairs(PlantData) do
            local unlockedList = data.UnlockedPlants or {}
            if table.find(unlockedList, plantType) then
                table.insert(result, {Type = plantType, Stats = stats})
            end
        end
        table.sort(result, function(a, b) return a.Type < b.Type end)
        
        -- Auto-select first plant if none selected
        local current = peek(selectedPlant)
        if not current and #result > 0 then
            task.defer(function()
                selectedPlant:set(result[1].Type)
            end)
        end
        
        return result
    end)
    
    -- Compatible mutations for selected plant
    local compatibleMutations = Computed(scope, function(use)
        local plantType = use(selectedPlant)
        if not plantType then return {} end
        
        local plantStats = PlantData[plantType]
        if not plantStats then return {} end
        
        local category = plantStats.Category
        local result: {{Type: string, Data: any}} = {}
        
        for mutationType, data in pairs(MutationData.GetAll()) do
            if table.find(data.CompatibleCategories, category) then
                table.insert(result, {Type = mutationType, Data = data})
            end
        end
        
        table.sort(result, function(a, b)
            return a.Data.RequiredLevel < b.Data.RequiredLevel
        end)
        
        return result
    end)
    
    -- Equipped mutations for selected plant
    local plantEquipped = Computed(scope, function(use)
        local plantType = use(selectedPlant)
        if not plantType then return {} end
        
        local allEquipped = use(props.EquippedMutations) or {}
        return allEquipped[plantType] or {}
    end)
    
    -- Owned mutations for selected plant
    local plantOwned = Computed(scope, function(use)
        local plantType = use(selectedPlant)
        if not plantType then return {} end
        
        local allOwned = use(props.OwnedMutations) or {}
        return allOwned[plantType] or {}
    end)
    
    -- Player data
    local playerCoins = Computed(scope, function(use)
        local data = use(props.PlayerData)
        return if data then data.Coins else 0
    end)
    
    local playerGems = Computed(scope, function(use)
        local data = use(props.PlayerData)
        return if data then data.Gems else 0
    end)
    
    local playerLevel = Computed(scope, function(use)
        local data = use(props.PlayerData)
        return if data then data.Level else 1
    end)
    
    -- Selected mutation states
    local isMutationOwned = Computed(scope, function(use)
        local mutation = use(selectedMutation)
        if not mutation then return false end
        local owned = use(plantOwned)
        return table.find(owned, mutation) ~= nil
    end)
    
    local isMutationEquipped = Computed(scope, function(use)
        local mutation = use(selectedMutation)
        if not mutation then return false end
        local equipped = use(plantEquipped)
        return table.find(equipped, mutation) ~= nil
    end)
    
    local canPurchaseMutation = Computed(scope, function(use)
        local mutation = use(selectedMutation)
        if not mutation then return false end
        if use(isMutationOwned) then return false end
        
        local data = MutationData.Get(mutation)
        if not data then return false end
        
        local level = use(playerLevel)
        local coins = use(playerCoins)
        return level >= data.RequiredLevel and coins >= data.Cost
    end)
    
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.LabBgDark,
        BackgroundTransparency = 0,
        
        [Children] = {
            -- Gradient overlay for depth
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 40, 70)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 25, 45)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 18, 35)),
                }),
                Rotation = 90,
            },
            
            -- Title: MUTATION LAB
            CasualTheme.LabTitle(scope, {
                Text = "⚗️ MUTATION LAB",
                Position = UDim2.new(0.5, 0, 0, 16),
            }),
            
            -- Back button
            CasualTheme.LabBackButton(scope, {
                OnClick = props.OnBack,
            }),
            
            -- Resources (top right)
            CasualTheme.LabResourceBar(scope, {
                Coins = playerCoins,
                Gems = playerGems,
            }),
            
            -- Plant selector with arrows (mobile-friendly)
            New(scope, "Frame") {
                Name = "PlantSelector",
                Size = UDim2.new(0, 280, 0, 90),
                Position = UDim2.new(0.5, 0, 0, 65),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                
                [Children] = {
                    -- Left arrow
                    New(scope, "TextButton") {
                        Name = "LeftArrow",
                        Size = UDim2.fromOffset(44, 44),
                        Position = UDim2.new(0, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(0, 0.5),
                        BackgroundColor3 = Colors.LabBgMedium,
                        BackgroundTransparency = 0,
                        Text = "◀",
                        TextSize = 22,
                        TextColor3 = Colors.NeonCyan,
                        Font = Fonts.Header,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "UIStroke") { Color = Colors.NeonCyanDark, Thickness = 2 },
                        },
                        
                        [OnEvent "Activated"] = function()
                            local plants = peek(unlockedPlants)
                            local current = peek(selectedPlant)
                            if #plants == 0 then return end
                            
                            local currentIndex = 1
                            for i, p in ipairs(plants) do
                                if p.Type == current then
                                    currentIndex = i
                                    break
                                end
                            end
                            
                            local newIndex = currentIndex + 1
                            if newIndex > #plants then newIndex = 1 end
                            selectedPlant:set(plants[newIndex].Type)
                            selectedMutation:set(nil)
                        end,
                    },
                    
                    -- Current plant display (center)
                    New(scope, "Frame") {
                        Name = "CurrentPlant",
                        Size = UDim2.fromOffset(100, 90),
                        Position = UDim2.new(0.5, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            -- Plant card
                            New(scope, "Frame") {
                                Size = UDim2.fromOffset(75, 75),
                                Position = UDim2.new(0.5, 0, 0, 0),
                                AnchorPoint = Vector2.new(0.5, 0),
                                BackgroundColor3 = Colors.NeonCyan,
                                BackgroundTransparency = 0,
                                
                                [Children] = {
                                    New(scope, "UICorner") { CornerRadius = UDim.new(0.2, 0) },
                                    New(scope, "UIStroke") { Color = Colors.NeonCyanDark, Thickness = 4 },
                                    New(scope, "UIGradient") {
                                        Color = ColorSequence.new({
                                            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                                            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 250, 255)),
                                            ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 210, 230)),
                                        }),
                                        Rotation = 90,
                                    },
                                    
                                    -- Plant emoji
                                    New(scope, "TextLabel") {
                                        Size = UDim2.new(1, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = Computed(scope, function(use)
                                            return getPlantEmoji(use(selectedPlant) or "")
                                        end),
                                        TextSize = 42,
                                    },
                                    
                                    -- Equipped count badge
                                    Computed(scope, function(use)
                                        local plantType = use(selectedPlant)
                                        if not plantType then return nil end
                                        local allEquipped = use(props.EquippedMutations) or {}
                                        local equipped = allEquipped[plantType] or {}
                                        local count = #equipped
                                        if count > 0 then
                                            return New(scope, "Frame") {
                                                Size = UDim2.fromOffset(26, 26),
                                                Position = UDim2.new(1, -2, 0, -2),
                                                AnchorPoint = Vector2.new(1, 0),
                                                BackgroundColor3 = Colors.NodeUnlocked,
                                                
                                                [Children] = {
                                                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                                                    New(scope, "UIStroke") { Color = Colors.StrokeDark, Thickness = 2 },
                                                    New(scope, "TextLabel") {
                                                        Size = UDim2.new(1, 0, 1, 0),
                                                        BackgroundTransparency = 1,
                                                        Text = tostring(count),
                                                        TextSize = 13,
                                                        Font = Fonts.Numbers,
                                                        TextColor3 = Colors.TextWhite,
                                                    },
                                                },
                                            }
                                        end
                                        return nil
                                    end),
                                },
                            },
                            
                            -- Plant name
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 20, 0, 16),
                                Position = UDim2.new(0.5, 0, 1, -2),
                                AnchorPoint = Vector2.new(0.5, 1),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    return use(selectedPlant) or "Select"
                                end),
                                TextSize = 12,
                                Font = Fonts.Header,
                                TextColor3 = Colors.TextWhite,
                                TextTruncate = Enum.TextTruncate.AtEnd,
                                
                                [Children] = {
                                    New(scope, "UIStroke") {
                                        Color = Colors.TextShadow,
                                        Thickness = 1,
                                        Transparency = 0.5,
                                    },
                                },
                            },
                        },
                    },
                    
                    -- Right arrow
                    New(scope, "TextButton") {
                        Name = "RightArrow",
                        Size = UDim2.fromOffset(44, 44),
                        Position = UDim2.new(1, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(1, 0.5),
                        BackgroundColor3 = Colors.LabBgMedium,
                        BackgroundTransparency = 0,
                        Text = "▶",
                        TextSize = 22,
                        TextColor3 = Colors.NeonCyan,
                        Font = Fonts.Header,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "UIStroke") { Color = Colors.NeonCyanDark, Thickness = 2 },
                        },
                        
                        [OnEvent "Activated"] = function()
                            local plants = peek(unlockedPlants)
                            local current = peek(selectedPlant)
                            if #plants == 0 then return end
                            
                            local currentIndex = 1
                            for i, p in ipairs(plants) do
                                if p.Type == current then
                                    currentIndex = i
                                    break
                                end
                            end
                            
                            local newIndex = currentIndex - 1
                            if newIndex < 1 then newIndex = #plants end
                            selectedPlant:set(plants[newIndex].Type)
                            selectedMutation:set(nil)
                        end,
                    },
                    
                    -- Page indicator dots
                    New(scope, "Frame") {
                        Name = "PageDots",
                        Size = UDim2.new(1, 0, 0, 10),
                        Position = UDim2.new(0.5, 0, 1, 5),
                        AnchorPoint = Vector2.new(0.5, 0),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 6),
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                VerticalAlignment = Enum.VerticalAlignment.Center,
                            },
                            
                            -- Generate dots
                            Computed(scope, function(use)
                                local plants = use(unlockedPlants)
                                local current = use(selectedPlant)
                                local dots = {}
                                
                                for i, p in ipairs(plants) do
                                    local isActive = p.Type == current
                                    dots[`dot_{i}`] = New(scope, "Frame") {
                                        Size = UDim2.fromOffset(isActive and 10 or 6, isActive and 10 or 6),
                                        BackgroundColor3 = isActive and Colors.NeonCyan or Color3.fromRGB(80, 90, 100),
                                        BackgroundTransparency = 0,
                                        
                                        [Children] = {
                                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                                        },
                                    }
                                end
                                
                                return dots
                            end),
                        },
                    },
                },
            },
            
            -- Mutation Lab area (center)
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 380),
                Position = UDim2.new(0.5, 0, 0.5, 20),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                
                [Children] = {
                    -- Skill Tree connections from center to each node
                    Computed(scope, function(use)
                        local mutations = use(compatibleMutations)
                        local owned = use(plantOwned) or {}
                        local equipped = use(plantEquipped) or {}
                        local connections = {}
                        
                        local totalNodes = math.min(#mutations, 8)
                        if totalNodes == 0 then return {} end
                        
                        -- Create radial connections from center to each node
                        for i, mutInfo in ipairs(mutations) do
                            if i > 8 then break end
                            
                            local mutationType = mutInfo.Type
                            
                            -- Check if this mutation is owned or equipped
                            local isActive = table.find(owned, mutationType) ~= nil 
                                or table.find(equipped, mutationType) ~= nil
                            
                            connections[`connection_{i}`] = SkillTreeConnection(scope, {
                                NodeIndex = i,
                                TotalNodes = totalNodes,
                                IsActive = isActive,
                            })
                        end
                        
                        return connections
                    end),
                    
                    -- Plant capsule in center
                    PlantCapsule(scope, {
                        PlantType = selectedPlant,
                    }),
                    
                    -- Mutation nodes in circle around plant
                    Computed(scope, function(use)
                        local mutations = use(compatibleMutations)
                        local nodes = {}
                        
                        local totalNodes = math.min(#mutations, 8) -- Max 8 nodes in circle
                        
                        for i, mutInfo in ipairs(mutations) do
                            if i > 8 then break end
                            
                            local mutationType = mutInfo.Type
                            local position = getCircularPosition(i, totalNodes, ORBIT_RADIUS)
                            
                            local isOwned = Computed(scope, function(use)
                                return table.find(use(plantOwned), mutationType) ~= nil
                            end)
                            
                            local isEquipped = Computed(scope, function(use)
                                return table.find(use(plantEquipped), mutationType) ~= nil
                            end)
                            
                            nodes[mutationType] = MutationNode(scope, {
                                MutationType = mutationType,
                                MutationData = mutInfo.Data,
                                Position = position,
                                IsOwned = isOwned,
                                IsEquipped = isEquipped,
                                OnClick = function()
                                    selectedMutation:set(mutationType)
                                end,
                            })
                        end
                        
                        return nodes
                    end),
                },
            },
            
            -- Info panel (right side, when mutation selected)
            InfoPanel(scope, {
                SelectedMutation = selectedMutation,
                IsOwned = isMutationOwned,
                IsEquipped = isMutationEquipped,
                CanPurchase = canPurchaseMutation,
                OnPurchase = function()
                    local plantType = peek(selectedPlant)
                    local mutationType = peek(selectedMutation)
                    if plantType and mutationType then
                        props.OnPurchaseMutation(plantType, mutationType)
                    end
                end,
                OnEquip = function()
                    local plantType = peek(selectedPlant)
                    local mutationType = peek(selectedMutation)
                    if plantType and mutationType then
                        props.OnEquipMutation(plantType, mutationType)
                    end
                end,
                OnUnequip = function()
                    local plantType = peek(selectedPlant)
                    local mutationType = peek(selectedMutation)
                    if plantType and mutationType then
                        props.OnUnequipMutation(plantType, mutationType)
                    end
                end,
            }),
            
            -- Empty state (no plants)
            Computed(scope, function(use)
                local plants = use(unlockedPlants)
                if #plants == 0 then
                    return New(scope, "Frame") {
                        Size = UDim2.new(0.8, 0, 0.5, 0),
                        Position = UDim2.new(0.5, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Colors.LabBgMedium,
                        BackgroundTransparency = 0,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0, 24) },
                            New(scope, "UIStroke") { Color = Colors.NeonCyanDark, Thickness = 3 },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, -40, 1, 0),
                                Position = UDim2.new(0.5, 0, 0.5, 0),
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Text = "🌱 No Plants Unlocked!\n\nVisit the Shop to unlock plants,\nthen return to mutate them.",
                                TextSize = 18,
                                Font = Fonts.Body,
                                TextColor3 = Colors.TextMuted,
                                TextWrapped = true,
                            },
                        },
                    }
                end
                return nil
            end),
        },
    }
end

return MutationView
