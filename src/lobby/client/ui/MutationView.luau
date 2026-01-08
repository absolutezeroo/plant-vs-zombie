--!strict
--[[
    MutationView.luau - Plant mutation management interface
    
    Two tabs:
    - Shop (Boutique): Purchase mutations for plants
    - Equipment (Équipement): Equip/unequip owned mutations on plants
    
    Migrated to ModernTheme for consistent dark UI style.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MutationData = require(Shared.data.MutationData)
local PlantData = require(Shared.data.PlantData)
local ModernTheme = require(Shared.ui.ModernTheme)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local peek = Fusion.peek
local ForPairs = Fusion.ForPairs

local Colors = ModernTheme.Colors
local Fonts = ModernTheme.Fonts
local Sizing = ModernTheme.Sizing

-- Constants
local TAB_SHOP = "shop"
local TAB_EQUIP = "equip"
local MAX_EQUIPPED_MUTATIONS = 3 -- Maximum mutations per plant
local DEFAULT_MUTATION_COLOR = Color3.fromRGB(100, 100, 120) -- Fallback color

-- Mutation category icons
local CATEGORY_ICONS: {[string]: string} = {
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

-- Mutation category colors (vibrant for dark theme)
local CATEGORY_COLORS: {[string]: Color3} = {
    Fire = Color3.fromRGB(255, 100, 50),
    Ice = Color3.fromRGB(100, 180, 255),
    Electric = Color3.fromRGB(255, 220, 80),
    Toxic = Color3.fromRGB(120, 255, 120),
    Shadow = Color3.fromRGB(160, 100, 220),
    Solar = Color3.fromRGB(255, 200, 80),
    Reinforced = Color3.fromRGB(180, 180, 190),
    Primal = Color3.fromRGB(220, 130, 70),
    Swift = Color3.fromRGB(150, 220, 255),
}

-- Mapping mutation Ids to their category (base type)
local MUTATION_TO_CATEGORY: {[string]: string} = {
    Fire = "Fire", Inferno = "Fire",
    Ice = "Ice", Frost = "Ice",
    Electric = "Electric", Storm = "Electric",
    Toxic = "Toxic", Plague = "Toxic",
    Shadow = "Shadow", Void = "Shadow",
    Solar = "Solar", Radiant = "Solar",
    Reinforced = "Reinforced", Fortress = "Reinforced",
    Primal = "Primal", Savage = "Primal",
    Swift = "Swift",
}

local function getMutationCategory(mutationId: string): string
    return MUTATION_TO_CATEGORY[mutationId] or mutationId
end

export type MutationViewProps = {
    PlayerData: any, -- Value<PlayerData?>
    OwnedMutations: any, -- Value<{[string]: {string}}> -- Purchased mutations per plant
    EquippedMutations: any, -- Value<{[string]: {string}}> -- Equipped mutations per plant
    OnBack: () -> (),
    OnPurchaseMutation: (plantType: string, mutationType: string) -> (),
    OnEquipMutation: (plantType: string, mutationType: string) -> (),
    OnUnequipMutation: (plantType: string, mutationType: string) -> (),
}

--------------------------------------------------------------------------------
-- COMMON COMPONENTS
--------------------------------------------------------------------------------

-- Tab button component
local function TabButton(scope: any, props: {
    Text: string,
    Icon: string,
    IsActive: any, -- Computed<boolean>
    OnClick: () -> (),
}): any
    return New(scope, "TextButton") {
        Size = UDim2.new(0.5, -4, 1, 0),
        BackgroundColor3 = Computed(scope, function(use)
            return if use(props.IsActive) then (Colors.Gold or Color3.fromRGB(255, 193, 7)) else (Colors.BackgroundLighter or DEFAULT_MUTATION_COLOR)
        end),
        Text = "",
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = props.OnClick,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
            
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = `{props.Icon} {props.Text}`,
                TextSize = 14,
                Font = Fonts.Header,
                TextColor3 = Computed(scope, function(use)
                    return if use(props.IsActive) then Colors.TextWhite else Colors.TextMuted
                end),
            },
        },
    }
end

-- Mutation badge showing a mutation (optionally removable)
local function MutationBadge(scope: any, props: {
    MutationType: string,
    OnRemove: (() -> ())?,
    Size: number?,
}): any
    local mutation = MutationData.Get(props.MutationType)
    if not mutation then return nil end
    
    local category = getMutationCategory(mutation.Id)
    local icon = CATEGORY_ICONS[category] or "✨"
    local color = CATEGORY_COLORS[category] or Colors.Success or DEFAULT_MUTATION_COLOR
    local hasRemove = props.OnRemove ~= nil
    local size = props.Size or 40
    
    return New(scope, "TextButton") {
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = color or DEFAULT_MUTATION_COLOR,
        Text = "",
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = if hasRemove then props.OnRemove else nil,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
                }),
                Rotation = 90,
            },
            
            -- Icon
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = icon,
                TextSize = math.floor(size * 0.55),
            },
            
            -- Remove X badge (only if removable)
            if hasRemove then New(scope, "TextLabel") {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(1, 2, 0, -2),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = Colors.Error,
                Text = "✕",
                TextSize = 10,
                Font = Fonts.Title,
                TextColor3 = Colors.TextWhite,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                },
            } else nil,
        },
    }
end

--------------------------------------------------------------------------------
-- SHOP TAB COMPONENTS
--------------------------------------------------------------------------------

-- Mutation option card for purchasing
local function ShopMutationCard(scope: any, props: {
    MutationType: string,
    Data: any,
    IsOwned: any, -- Computed<boolean>
    CanPurchase: any, -- Computed<boolean>
    OnPurchase: () -> (),
}): any
    local data = props.Data
    local category = getMutationCategory(data.Id)
    local icon = CATEGORY_ICONS[category] or "✨"
    local color = CATEGORY_COLORS[category] or Colors.Success or DEFAULT_MUTATION_COLOR
    
    return New(scope, "TextButton") {
        Size = UDim2.new(0, 150, 0, 100),
        BackgroundColor3 = Computed(scope, function(use)
            if use(props.IsOwned) then
                return Colors.BackgroundLighter or DEFAULT_MUTATION_COLOR
            elseif use(props.CanPurchase) then
                return color or DEFAULT_MUTATION_COLOR
            else
                return Colors.BackgroundLighter or DEFAULT_MUTATION_COLOR
            end
        end),
        Text = "",
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = function()
            if not peek(props.IsOwned) and peek(props.CanPurchase) then
                props.OnPurchase()
            end
        end,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
            New(scope, "UIStroke") {
                Color = Computed(scope, function(use)
                    if use(props.IsOwned) then return Colors.Success or DEFAULT_MUTATION_COLOR end
                    if use(props.CanPurchase) then return color or DEFAULT_MUTATION_COLOR end
                    return Colors.Border or DEFAULT_MUTATION_COLOR
                end),
                Thickness = Computed(scope, function(use)
                    return if use(props.IsOwned) then 3 else 2
                end),
                Transparency = 0.3,
            },
            
            -- Darken overlay
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = Computed(scope, function(use)
                    if use(props.IsOwned) then return 0.5 end
                    if use(props.CanPurchase) then return 0.7 end
                    return 0.4
                end),
                ZIndex = 0,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                },
            },
            
            -- Icon + Name row
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 26),
                Position = UDim2.fromOffset(0, 4),
                BackgroundTransparency = 1,
                
                [Children] = {
                    New(scope, "TextLabel") {
                        Size = UDim2.fromOffset(24, 24),
                        Position = UDim2.fromOffset(6, 0),
                        BackgroundTransparency = 1,
                        Text = icon,
                        TextSize = 18,
                    },
                    
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -38, 1, 0),
                        Position = UDim2.fromOffset(32, 0),
                        BackgroundTransparency = 1,
                        Text = data.Name or props.MutationType,
                        TextSize = 11,
                        Font = Fonts.Header,
                        TextColor3 = Colors.TextWhite,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                    },
                },
            },
            
            -- Description
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -12, 0, 28),
                Position = UDim2.fromOffset(6, 30),
                BackgroundTransparency = 1,
                Text = data.Description or "",
                TextSize = 9,
                Font = Fonts.Body,
                TextColor3 = Colors.TextMuted,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                TextTruncate = Enum.TextTruncate.AtEnd,
            },
            
            -- Bottom row: Level + Cost/Owned
            New(scope, "Frame") {
                Size = UDim2.new(1, -12, 0, 20),
                Position = UDim2.new(0, 6, 1, -24),
                BackgroundTransparency = 1,
                
                [Children] = {
                    -- Level badge
                    New(scope, "TextLabel") {
                        Size = UDim2.fromOffset(38, 18),
                        BackgroundColor3 = Colors.BackgroundLighter,
                        Text = `Lv.{data.RequiredLevel}`,
                        TextSize = 9,
                        Font = Fonts.Body,
                        TextColor3 = Colors.TextMuted,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                        },
                    },
                    
                    -- Cost or Owned badge
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(70, 18),
                        Position = UDim2.new(1, 0, 0, 0),
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundColor3 = Computed(scope, function(use)
                            return if use(props.IsOwned) then (Colors.Success or DEFAULT_MUTATION_COLOR) else (Colors.BackgroundLighter or DEFAULT_MUTATION_COLOR)
                        end),
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    if use(props.IsOwned) then
                                        return "✓ Possédée"
                                    else
                                        return `🪙 {data.Cost}`
                                    end
                                end),
                                TextSize = 10,
                                Font = Fonts.Header,
                                TextColor3 = Computed(scope, function(use)
                                    return if use(props.IsOwned) then Colors.TextWhite else Colors.Coins
                                end),
                            },
                        },
                    },
                },
            },
        },
    }
end

-- Plant card for Shop tab
local function ShopPlantCard(scope: any, props: {
    PlantType: string,
    PlantStats: any,
    OwnedMutations: any, -- Computed<{string}>
    PlayerLevel: any,
    PlayerCoins: any,
    OnPurchase: (mutationType: string) -> (),
}): any
    local isExpanded = Value(scope, false)
    
    local compatibleMutations = Computed(scope, function(use)
        local plantStats = props.PlantStats
        local category = plantStats.Category
        local result: {{Type: string, Data: MutationData.MutationInfo}} = {}
        
        for mutationType, data in MutationData.GetAll() do
            if table.find(data.CompatibleCategories, category) then
                table.insert(result, {Type = mutationType, Data = data})
            end
        end
        
        table.sort(result, function(a, b)
            if a.Data.RequiredLevel ~= b.Data.RequiredLevel then
                return a.Data.RequiredLevel < b.Data.RequiredLevel
            end
            return a.Type < b.Type
        end)
        
        return result
    end)
    
    local ownedCount = Computed(scope, function(use)
        return #use(props.OwnedMutations)
    end)
    
    return New(scope, "Frame") {
        Size = Computed(scope, function(use)
            return if use(isExpanded) 
                then UDim2.new(1, 0, 0, 300) 
                else UDim2.new(1, 0, 0, 85)
        end),
        BackgroundColor3 = Colors.Card,
        ClipsDescendants = true,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusLarge },
            New(scope, "UIStroke") { Color = Colors.Border, Thickness = 1 },
            
            -- Header
            New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 0, 85),
                BackgroundTransparency = 1,
                Text = "",
                
                [OnEvent "Activated"] = function()
                    isExpanded:set(not peek(isExpanded))
                end,
                
                [Children] = {
                    -- Plant icon
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(60, 60),
                        Position = UDim2.fromOffset(12, 12),
                        BackgroundColor3 = Colors.Success or Color3.fromRGB(76, 175, 80),
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "UIGradient") {
                                Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 200, 100)),
                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 140, 60)),
                                }),
                                Rotation = 90,
                            },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "🌱",
                                TextSize = 28,
                            },
                        },
                    },
                    
                    -- Plant name
                    New(scope, "TextLabel") {
                        Size = UDim2.new(0.4, -80, 0, 28),
                        Position = UDim2.fromOffset(85, 14),
                        BackgroundTransparency = 1,
                        Text = props.PlantType,
                        TextSize = 18,
                        Font = Fonts.Title,
                        TextColor3 = Colors.TextWhite,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    
                    -- Category + owned count
                    New(scope, "Frame") {
                        Size = UDim2.new(0, 150, 0, 22),
                        Position = UDim2.fromOffset(85, 46),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 8),
                            },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.fromOffset(75, 22),
                                BackgroundColor3 = Colors.BackgroundLighter,
                                Text = props.PlantStats.Category,
                                TextSize = 11,
                                Font = Fonts.Body,
                                TextColor3 = Colors.TextMuted,
                                
                                [Children] = {
                                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                                },
                            },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.fromOffset(60, 22),
                                BackgroundColor3 = Computed(scope, function(use)
                                    return if use(ownedCount) > 0 then (Colors.Success or DEFAULT_MUTATION_COLOR) else (Colors.BackgroundLighter or DEFAULT_MUTATION_COLOR)
                                end),
                                Text = Computed(scope, function(use)
                                    return `{use(ownedCount)} achetée(s)`
                                end),
                                TextSize = 10,
                                Font = Fonts.Body,
                                TextColor3 = Colors.TextWhite,
                                
                                [Children] = {
                                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                                },
                            },
                        },
                    },
                    
                    -- Owned mutations preview
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(180, 44),
                        Position = UDim2.new(1, -230, 0.5, 0),
                        AnchorPoint = Vector2.new(0, 0.5),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 6),
                                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                                VerticalAlignment = Enum.VerticalAlignment.Center,
                            },
                            
                            ForPairs(scope, props.OwnedMutations, function(use, scope, index, mutationType)
                                return index, MutationBadge(scope, {
                                    MutationType = mutationType,
                                    OnRemove = nil,
                                })
                            end),
                        },
                    },
                    
                    -- Expand indicator
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(36, 36),
                        Position = UDim2.new(1, -12, 0.5, 0),
                        AnchorPoint = Vector2.new(1, 0.5),
                        BackgroundColor3 = Colors.BackgroundLighter,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    return if use(isExpanded) then "▲" else "▼"
                                end),
                                TextSize = 14,
                                Font = Fonts.Title,
                                TextColor3 = Colors.TextMuted,
                            },
                        },
                    },
                },
            },
            
            -- Expanded content
            New(scope, "ScrollingFrame") {
                Size = UDim2.new(1, -24, 0, 195),
                Position = UDim2.fromOffset(12, 95),
                BackgroundColor3 = Colors.BackgroundLighter,
                ScrollBarThickness = 4,
                ScrollBarImageColor3 = Colors.Border,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                    New(scope, "UIGridLayout") {
                        CellSize = UDim2.fromOffset(150, 100),
                        CellPadding = UDim2.fromOffset(8, 8),
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    },
                    New(scope, "UIPadding") {
                        PaddingTop = UDim.new(0, 8),
                        PaddingBottom = UDim.new(0, 8),
                        PaddingLeft = UDim.new(0, 8),
                        PaddingRight = UDim.new(0, 8),
                    },
                    
                    ForPairs(scope, compatibleMutations, function(use, scope, index, mutationInfo)
                        local mutationType = mutationInfo.Type
                        local data = mutationInfo.Data
                        
                        local isOwned = Computed(scope, function(use)
                            local owned = use(props.OwnedMutations)
                            return table.find(owned, mutationType) ~= nil
                        end)
                        
                        local canPurchase = Computed(scope, function(use)
                            if use(isOwned) then return false end
                            local level = use(props.PlayerLevel)
                            local coins = use(props.PlayerCoins)
                            if level < data.RequiredLevel then return false end
                            if coins < data.Cost then return false end
                            return true
                        end)
                        
                        return index, ShopMutationCard(scope, {
                            MutationType = mutationType,
                            Data = data,
                            IsOwned = isOwned,
                            CanPurchase = canPurchase,
                            OnPurchase = function()
                                props.OnPurchase(mutationType)
                            end,
                        })
                    end),
                },
            },
        },
    }
end

--------------------------------------------------------------------------------
-- EQUIP TAB COMPONENTS
--------------------------------------------------------------------------------

-- Mutation slot (empty or filled)
local function MutationSlot(scope: any, props: {
    MutationType: string?, -- nil if empty
    SlotIndex: number,
    OnRemove: (() -> ())?,
}): any
    local isEmpty = props.MutationType == nil
    
    if isEmpty then
        return New(scope, "Frame") {
            Size = UDim2.fromOffset(50, 50),
            BackgroundColor3 = Colors.BackgroundLighter,
            
            [Children] = {
                New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                New(scope, "UIStroke") { Color = Colors.Border, Thickness = 2, Transparency = 0.5 },
                
                New(scope, "TextLabel") {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = "+",
                    TextSize = 24,
                    Font = Fonts.Title,
                    TextColor3 = Colors.TextMuted,
                },
            },
        }
    else
        return MutationBadge(scope, {
            MutationType = props.MutationType :: string,
            OnRemove = props.OnRemove,
            Size = 50,
        })
    end
end

-- Available mutation to equip (smaller card)
local function EquipMutationOption(scope: any, props: {
    MutationType: string,
    IsEquipped: any, -- Computed<boolean>
    CanEquip: any, -- Computed<boolean>
    OnEquip: () -> (),
}): any
    local mutation = MutationData.Get(props.MutationType)
    if not mutation then return nil end
    
    local category = getMutationCategory(mutation.Id)
    local icon = CATEGORY_ICONS[category] or "✨"
    local color = CATEGORY_COLORS[category] or Colors.Success or DEFAULT_MUTATION_COLOR
    
    return New(scope, "TextButton") {
        Size = UDim2.fromOffset(80, 80),
        BackgroundColor3 = Computed(scope, function(use)
            if use(props.IsEquipped) then return Colors.Success or DEFAULT_MUTATION_COLOR end
            if use(props.CanEquip) then return color or DEFAULT_MUTATION_COLOR end
            return Colors.BackgroundLighter or DEFAULT_MUTATION_COLOR
        end),
        Text = "",
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = function()
            if not peek(props.IsEquipped) and peek(props.CanEquip) then
                props.OnEquip()
            end
        end,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
            New(scope, "UIStroke") {
                Color = Computed(scope, function(use)
                    if use(props.IsEquipped) then return Colors.Success or DEFAULT_MUTATION_COLOR end
                    return color or DEFAULT_MUTATION_COLOR
                end),
                Thickness = Computed(scope, function(use)
                    return if use(props.IsEquipped) then 3 else 2
                end),
                Transparency = 0.3,
            },
            
            -- Darken overlay
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = Computed(scope, function(use)
                    if use(props.IsEquipped) then return 0.3 end
                    if use(props.CanEquip) then return 0.6 end
                    return 0.7
                end),
                ZIndex = 0,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                },
            },
            
            -- Icon
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 40),
                Position = UDim2.fromOffset(0, 5),
                BackgroundTransparency = 1,
                Text = icon,
                TextSize = 28,
            },
            
            -- Name
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -8, 0, 20),
                Position = UDim2.new(0, 4, 1, -25),
                BackgroundTransparency = 1,
                Text = mutation.Name or props.MutationType,
                TextSize = 10,
                Font = Fonts.Header,
                TextColor3 = Colors.TextWhite,
                TextTruncate = Enum.TextTruncate.AtEnd,
            },
            
            -- Equipped check
            Computed(scope, function(use)
                if use(props.IsEquipped) then
                    return New(scope, "TextLabel") {
                        Size = UDim2.fromOffset(20, 20),
                        Position = UDim2.new(1, -4, 0, 4),
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundColor3 = Colors.Success or Color3.fromRGB(76, 175, 80),
                        Text = "✓",
                        TextSize = 12,
                        Font = Fonts.Title,
                        TextColor3 = Colors.TextWhite,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                        },
                    }
                end
                return nil
            end),
        },
    }
end

-- Plant card for Equip tab
local function EquipPlantCard(scope: any, props: {
    PlantType: string,
    PlantStats: any,
    OwnedMutations: any, -- Computed<{string}>
    EquippedMutations: any, -- Computed<{string}>
    OnEquip: (mutationType: string) -> (),
    OnUnequip: (mutationType: string) -> (),
}): any
    local isExpanded = Value(scope, false)
    
    local equippedCount = Computed(scope, function(use)
        return #use(props.EquippedMutations)
    end)
    
    local ownedCount = Computed(scope, function(use)
        return #use(props.OwnedMutations)
    end)
    
    return New(scope, "Frame") {
        Size = Computed(scope, function(use)
            return if use(isExpanded) 
                then UDim2.new(1, 0, 0, 240) 
                else UDim2.new(1, 0, 0, 90)
        end),
        BackgroundColor3 = Colors.Card,
        ClipsDescendants = true,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusLarge },
            New(scope, "UIStroke") { Color = Colors.Border, Thickness = 1 },
            
            -- Header
            New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 0, 90),
                BackgroundTransparency = 1,
                Text = "",
                
                [OnEvent "Activated"] = function()
                    isExpanded:set(not peek(isExpanded))
                end,
                
                [Children] = {
                    -- Plant icon
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(55, 55),
                        Position = UDim2.fromOffset(12, 17),
                        BackgroundColor3 = Colors.Success or Color3.fromRGB(76, 175, 80),
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "UIGradient") {
                                Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 200, 100)),
                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 140, 60)),
                                }),
                                Rotation = 90,
                            },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "🌱",
                                TextSize = 26,
                            },
                        },
                    },
                    
                    -- Plant name + stats
                    New(scope, "Frame") {
                        Size = UDim2.new(0, 150, 0, 55),
                        Position = UDim2.fromOffset(80, 17),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 0, 22),
                                BackgroundTransparency = 1,
                                Text = props.PlantType,
                                TextSize = 16,
                                Font = Fonts.Title,
                                TextColor3 = Colors.TextWhite,
                                TextXAlignment = Enum.TextXAlignment.Left,
                            },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 0, 18),
                                Position = UDim2.fromOffset(0, 24),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    return `{use(equippedCount)}/{MAX_EQUIPPED_MUTATIONS} équipées • {use(ownedCount)} possédées`
                                end),
                                TextSize = 11,
                                Font = Fonts.Body,
                                TextColor3 = Colors.TextMuted,
                                TextXAlignment = Enum.TextXAlignment.Left,
                            },
                        },
                    },
                    
                    -- Equipped slots
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(180, 55),
                        Position = UDim2.new(1, -230, 0.5, 0),
                        AnchorPoint = Vector2.new(0, 0.5),
                        BackgroundTransparency = 1,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 8),
                                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                                VerticalAlignment = Enum.VerticalAlignment.Center,
                            },
                            
                            -- Render slots
                            Computed(scope, function(use)
                                local equipped = use(props.EquippedMutations)
                                local slots = {}
                                
                                for i = 1, MAX_EQUIPPED_MUTATIONS do
                                    local mutationType = equipped[i]
                                    local slotKey = `slot_{i}`
                                    
                                    slots[slotKey] = MutationSlot(scope, {
                                        MutationType = mutationType,
                                        SlotIndex = i,
                                        OnRemove = if mutationType then function()
                                            props.OnUnequip(mutationType)
                                        end else nil,
                                    })
                                end
                                
                                return slots
                            end),
                        },
                    },
                    
                    -- Expand indicator
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(36, 36),
                        Position = UDim2.new(1, -12, 0.5, 0),
                        AnchorPoint = Vector2.new(1, 0.5),
                        BackgroundColor3 = Colors.BackgroundLighter,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    return if use(isExpanded) then "▲" else "▼"
                                end),
                                TextSize = 14,
                                Font = Fonts.Title,
                                TextColor3 = Colors.TextMuted,
                            },
                        },
                    },
                },
            },
            
            -- Expanded: available mutations to equip
            New(scope, "Frame") {
                Size = UDim2.new(1, -24, 0, 130),
                Position = UDim2.fromOffset(12, 100),
                BackgroundColor3 = Colors.BackgroundLighter,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                    New(scope, "UIPadding") {
                        PaddingTop = UDim.new(0, 8),
                        PaddingBottom = UDim.new(0, 8),
                        PaddingLeft = UDim.new(0, 8),
                        PaddingRight = UDim.new(0, 8),
                    },
                    
                    -- Title
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 0, 20),
                        BackgroundTransparency = 1,
                        Text = "Mutations possédées :",
                        TextSize = 12,
                        Font = Fonts.Header,
                        TextColor3 = Colors.TextMuted,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    
                    -- Mutations grid
                    New(scope, "ScrollingFrame") {
                        Size = UDim2.new(1, 0, 1, -28),
                        Position = UDim2.fromOffset(0, 26),
                        BackgroundTransparency = 1,
                        ScrollBarThickness = 4,
                        ScrollBarImageColor3 = Colors.Border,
                        CanvasSize = UDim2.new(0, 0, 0, 0),
                        AutomaticCanvasSize = Enum.AutomaticSize.X,
                        ScrollingDirection = Enum.ScrollingDirection.X,
                        
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 8),
                                VerticalAlignment = Enum.VerticalAlignment.Center,
                            },
                            
                            ForPairs(scope, props.OwnedMutations, function(use, scope, index, mutationType)
                                local isEquipped = Computed(scope, function(use)
                                    local equipped = use(props.EquippedMutations)
                                    return table.find(equipped, mutationType) ~= nil
                                end)
                                
                                local canEquip = Computed(scope, function(use)
                                    if use(isEquipped) then return false end
                                    local equipped = use(props.EquippedMutations)
                                    return #equipped < MAX_EQUIPPED_MUTATIONS
                                end)
                                
                                return index, EquipMutationOption(scope, {
                                    MutationType = mutationType,
                                    IsEquipped = isEquipped,
                                    CanEquip = canEquip,
                                    OnEquip = function()
                                        props.OnEquip(mutationType)
                                    end,
                                })
                            end),
                            
                            -- Empty state
                            Computed(scope, function(use)
                                if #use(props.OwnedMutations) == 0 then
                                    return New(scope, "TextLabel") {
                                        Size = UDim2.new(0, 200, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = "Aucune mutation achetée\nVisite la Boutique !",
                                        TextSize = 12,
                                        Font = Fonts.Body,
                                        TextColor3 = Colors.TextMuted,
                                        TextWrapped = true,
                                    }
                                end
                                return nil
                            end),
                        },
                    },
                },
            },
        },
    }
end

--------------------------------------------------------------------------------
-- MAIN VIEW
--------------------------------------------------------------------------------

return function(scope: any, props: MutationViewProps)
    local activeTab = Value(scope, TAB_SHOP)
    
    -- Compute unlocked plants
    local unlockedPlants = Computed(scope, function(use)
        local data = use(props.PlayerData)
        if not data then return {} end
        
        local unlockedSet: {[string]: boolean} = {}
        if data.UnlockedPlants then
            for _, plantType in ipairs(data.UnlockedPlants) do
                unlockedSet[plantType] = true
            end
        end
        
        local result: {{Type: string, Stats: any}} = {}
        for plantType, stats in PlantData do
            if unlockedSet[plantType] then
                table.insert(result, {Type = plantType, Stats = stats})
            end
        end
        
        table.sort(result, function(a, b)
            return a.Type < b.Type
        end)
        
        return result
    end)
    
    local playerLevel = Computed(scope, function(use)
        local data = use(props.PlayerData)
        return if data then data.Level else 1
    end)
    
    local playerCoins = Computed(scope, function(use)
        local data = use(props.PlayerData)
        return if data then data.Coins else 0
    end)
    
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.Background,
        
        [Children] = {
            -- Header
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 70),
                BackgroundColor3 = Color3.fromRGB(30, 30, 42),
                
                [Children] = {
                    -- Title
                    New(scope, "TextLabel") {
                        Size = UDim2.new(0.5, 0, 1, 0),
                        Position = UDim2.new(0.5, 0, 0, 0),
                        AnchorPoint = Vector2.new(0.5, 0),
                        BackgroundTransparency = 1,
                        Text = "🧬 Mutations",
                        TextSize = 24,
                        Font = Fonts.Title,
                        TextColor3 = Colors.TextWhite,
                    },
                    
                    -- Coins pill
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(110, 36),
                        Position = UDim2.fromOffset(15, 17),
                        BackgroundColor3 = Colors.BackgroundLighter,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "UIStroke") { Color = Colors.Coins, Thickness = 2, Transparency = 0.6 },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = Computed(scope, function(use)
                                    return `🪙 {use(playerCoins)}`
                                end),
                                TextSize = 16,
                                Font = Fonts.Header,
                                TextColor3 = Colors.Coins,
                            },
                        },
                    },
                    
                    -- Close button
                    New(scope, "TextButton") {
                        Size = UDim2.fromOffset(44, 44),
                        Position = UDim2.new(1, -15, 0.5, 0),
                        AnchorPoint = Vector2.new(1, 0.5),
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
            
            -- Tab bar
            New(scope, "Frame") {
                Size = UDim2.new(1, -32, 0, 44),
                Position = UDim2.fromOffset(16, 80),
                BackgroundColor3 = Colors.Card,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                    New(scope, "UIPadding") {
                        PaddingTop = UDim.new(0, 4),
                        PaddingBottom = UDim.new(0, 4),
                        PaddingLeft = UDim.new(0, 4),
                        PaddingRight = UDim.new(0, 4),
                    },
                    
                    New(scope, "UIListLayout") {
                        FillDirection = Enum.FillDirection.Horizontal,
                        Padding = UDim.new(0, 8),
                    },
                    
                    TabButton(scope, {
                        Text = "Boutique",
                        Icon = "🛒",
                        IsActive = Computed(scope, function(use)
                            return use(activeTab) == TAB_SHOP
                        end),
                        OnClick = function()
                            activeTab:set(TAB_SHOP)
                        end,
                    }),
                    
                    TabButton(scope, {
                        Text = "Équipement",
                        Icon = "⚙️",
                        IsActive = Computed(scope, function(use)
                            return use(activeTab) == TAB_EQUIP
                        end),
                        OnClick = function()
                            activeTab:set(TAB_EQUIP)
                        end,
                    }),
                },
            },
            
            -- Main content
            New(scope, "ScrollingFrame") {
                Size = UDim2.new(1, -32, 1, -145),
                Position = UDim2.fromOffset(16, 135),
                BackgroundTransparency = 1,
                ScrollBarThickness = 4,
                ScrollBarImageColor3 = Colors.Border,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                
                [Children] = {
                    New(scope, "UIListLayout") {
                        Padding = UDim.new(0, 12),
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    },
                    
                    -- Shop tab content
                    Computed(scope, function(use)
                        if use(activeTab) ~= TAB_SHOP then return {} end
                        
                        local plants = use(unlockedPlants)
                        if #plants == 0 then
                            return {
                                EmptyState = New(scope, "Frame") {
                                    Size = UDim2.new(1, 0, 0, 150),
                                    BackgroundColor3 = Colors.Card,
                                    
                                    [Children] = {
                                        New(scope, "UICorner") { CornerRadius = Sizing.RadiusLarge },
                                        New(scope, "TextLabel") {
                                            Size = UDim2.new(1, -40, 1, 0),
                                            Position = UDim2.fromOffset(20, 0),
                                            BackgroundTransparency = 1,
                                            Text = "🌱 Aucune plante débloquée !\n\nVisite le Shop pour débloquer des plantes,\npuis reviens acheter des mutations.",
                                            TextSize = 16,
                                            Font = Fonts.Body,
                                            TextColor3 = Colors.TextMuted,
                                            TextWrapped = true,
                                        },
                                    },
                                },
                            }
                        end
                        
                        local cards = {}
                        for _, plantInfo in ipairs(plants) do
                            local plantType = plantInfo.Type
                            
                            local plantOwnedMutations = Computed(scope, function(use)
                                local allOwned = use(props.OwnedMutations)
                                return allOwned[plantType] or {}
                            end)
                            
                            cards[plantType] = ShopPlantCard(scope, {
                                PlantType = plantType,
                                PlantStats = plantInfo.Stats,
                                OwnedMutations = plantOwnedMutations,
                                PlayerLevel = playerLevel,
                                PlayerCoins = playerCoins,
                                OnPurchase = function(mutationType)
                                    props.OnPurchaseMutation(plantType, mutationType)
                                end,
                            })
                        end
                        
                        return cards
                    end),
                    
                    -- Equip tab content
                    Computed(scope, function(use)
                        if use(activeTab) ~= TAB_EQUIP then return {} end
                        
                        local plants = use(unlockedPlants)
                        if #plants == 0 then
                            return {
                                EmptyState = New(scope, "Frame") {
                                    Size = UDim2.new(1, 0, 0, 150),
                                    BackgroundColor3 = Colors.Card,
                                    
                                    [Children] = {
                                        New(scope, "UICorner") { CornerRadius = Sizing.RadiusLarge },
                                        New(scope, "TextLabel") {
                                            Size = UDim2.new(1, -40, 1, 0),
                                            Position = UDim2.fromOffset(20, 0),
                                            BackgroundTransparency = 1,
                                            Text = "🌱 Aucune plante débloquée !\n\nDébloque d'abord des plantes\npour équiper des mutations.",
                                            TextSize = 16,
                                            Font = Fonts.Body,
                                            TextColor3 = Colors.TextMuted,
                                            TextWrapped = true,
                                        },
                                    },
                                },
                            }
                        end
                        
                        local cards = {}
                        for _, plantInfo in ipairs(plants) do
                            local plantType = plantInfo.Type
                            
                            local plantOwnedMutations = Computed(scope, function(use)
                                local allOwned = use(props.OwnedMutations)
                                return allOwned[plantType] or {}
                            end)
                            
                            local plantEquippedMutations = Computed(scope, function(use)
                                local allEquipped = use(props.EquippedMutations)
                                return allEquipped[plantType] or {}
                            end)
                            
                            cards[plantType] = EquipPlantCard(scope, {
                                PlantType = plantType,
                                PlantStats = plantInfo.Stats,
                                OwnedMutations = plantOwnedMutations,
                                EquippedMutations = plantEquippedMutations,
                                OnEquip = function(mutationType)
                                    props.OnEquipMutation(plantType, mutationType)
                                end,
                                OnUnequip = function(mutationType)
                                    props.OnUnequipMutation(plantType, mutationType)
                                end,
                            })
                        end
                        
                        return cards
                    end),
                },
            },
        },
    }
end
