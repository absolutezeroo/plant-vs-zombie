--!strict
--[[
    MutationView.luau - Plant mutation management interface
    
    Allows players to view and purchase mutations for their plants.
    Mutations add special abilities (fire damage, freeze, lifesteal, etc.)
    
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
    PlantMutations: any, -- Value<{[string]: {string}}>
    OnBack: () -> (),
    OnPurchaseMutation: (plantType: string, mutationType: string) -> (),
    OnRemoveMutation: (plantType: string, mutationType: string) -> (),
}

-- Mutation badge showing active mutation
local function MutationBadge(scope: any, props: {
    MutationType: string,
    OnRemove: () -> (),
}): any
    local mutation = MutationData.Get(props.MutationType)
    if not mutation then return nil end
    
    local category = getMutationCategory(mutation.Id)
    local icon = CATEGORY_ICONS[category] or "✨"
    local color = CATEGORY_COLORS[category] or Colors.Success
    
    return New(scope, "TextButton") {
        Size = UDim2.fromOffset(40, 40),
        BackgroundColor3 = color,
        Text = "",
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = props.OnRemove,
        
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
                TextSize = 22,
            },
            
            -- Remove X badge
            New(scope, "TextLabel") {
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
            },
        },
    }
end

-- Mutation option card in the grid
local function MutationOption(scope: any, props: {
    MutationType: string,
    Data: any,
    IsOwned: any, -- Computed<boolean>
    CanPurchase: any, -- Computed<boolean>
    OnPurchase: () -> (),
}): any
    local data = props.Data
    local category = getMutationCategory(data.Id)
    local icon = CATEGORY_ICONS[category] or "✨"
    local color = CATEGORY_COLORS[category] or Colors.Success
    
    return New(scope, "TextButton") {
        Size = UDim2.new(0, 130, 0, 80),
        BackgroundColor3 = Computed(scope, function(use)
            if use(props.IsOwned) then
                return Colors.Success
            elseif use(props.CanPurchase) then
                return color
            else
                return Colors.BackgroundLighter
            end
        end),
        Text = "",
        AutoButtonColor = false,
        
        [OnEvent "Activated"] = function()
            if peek(props.CanPurchase) then
                props.OnPurchase()
            end
        end,
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
            New(scope, "UIStroke") {
                Color = Computed(scope, function(use)
                    if use(props.IsOwned) then return Colors.Success end
                    if use(props.CanPurchase) then return color end
                    return Colors.Border
                end),
                Thickness = 2,
                Transparency = 0.5,
            },
            
            -- Darken if not available
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = Computed(scope, function(use)
                    if use(props.IsOwned) or use(props.CanPurchase) then
                        return 0.7
                    end
                    return 0.4
                end),
                ZIndex = 0,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = Sizing.RadiusMedium },
                },
            },
            
            -- Icon + Name row
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.fromOffset(0, 6),
                BackgroundTransparency = 1,
                
                [Children] = {
                    New(scope, "TextLabel") {
                        Size = UDim2.fromOffset(28, 28),
                        Position = UDim2.fromOffset(8, 0),
                        BackgroundTransparency = 1,
                        Text = icon,
                        TextSize = 20,
                    },
                    
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -45, 1, 0),
                        Position = UDim2.fromOffset(38, 0),
                        BackgroundTransparency = 1,
                        Text = props.MutationType,
                        TextSize = 12,
                        Font = Fonts.Header,
                        TextColor3 = Colors.TextWhite,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                    },
                },
            },
            
            -- Level badge
            New(scope, "TextLabel") {
                Size = UDim2.fromOffset(45, 18),
                Position = UDim2.fromOffset(8, 40),
                BackgroundColor3 = Colors.BackgroundLighter,
                Text = `Lv.{data.RequiredLevel}`,
                TextSize = 10,
                Font = Fonts.Body,
                TextColor3 = Colors.TextMuted,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                },
            },
            
            -- Cost or Owned status
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -16, 0, 20),
                Position = UDim2.new(0, 8, 1, -24),
                BackgroundTransparency = 1,
                Text = Computed(scope, function(use)
                    if use(props.IsOwned) then
                        return "✓ Equipped"
                    else
                        return `🪙 {data.Cost}`
                    end
                end),
                TextSize = 12,
                Font = Fonts.Header,
                TextColor3 = Computed(scope, function(use)
                    return if use(props.IsOwned) then Colors.TextWhite else Colors.Coins
                end),
                TextXAlignment = Enum.TextXAlignment.Left,
            },
        },
    }
end

-- Plant card with mutations
local function PlantMutationCard(scope: any, props: {
    PlantType: string,
    PlantStats: any,
    Mutations: any, -- Computed<{string}>
    PlayerLevel: any, -- Computed<number>
    PlayerCoins: any, -- Computed<number>
    OnPurchase: (mutationType: string) -> (),
    OnRemove: (mutationType: string) -> (),
}): any
    local isExpanded = Value(scope, false)
    
    -- Get compatible mutations for this plant
    local compatibleMutations = Computed(scope, function(use)
        local plantStats = props.PlantStats
        local category = plantStats.Category
        local result: {{Type: string, Data: MutationData.MutationInfo}} = {}
        
        for mutationType, data in MutationData.GetAll() do
            if table.find(data.CompatibleCategories, category) then
                table.insert(result, {Type = mutationType, Data = data})
            end
        end
        
        -- Sort by required level then name
        table.sort(result, function(a, b)
            if a.Data.RequiredLevel ~= b.Data.RequiredLevel then
                return a.Data.RequiredLevel < b.Data.RequiredLevel
            end
            return a.Type < b.Type
        end)
        
        return result
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
            
            -- Header (always visible, clickable)
            New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 0, 85),
                BackgroundTransparency = 1,
                Text = "",
                
                [OnEvent "Activated"] = function()
                    isExpanded:set(not peek(isExpanded))
                end,
                
                [Children] = {
                    -- Plant icon circle
                    New(scope, "Frame") {
                        Size = UDim2.fromOffset(60, 60),
                        Position = UDim2.fromOffset(12, 12),
                        BackgroundColor3 = Colors.Success,
                        
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
                    
                    -- Category badge
                    New(scope, "TextLabel") {
                        Size = UDim2.fromOffset(75, 22),
                        Position = UDim2.fromOffset(85, 46),
                        BackgroundColor3 = Colors.BackgroundLighter,
                        Text = props.PlantStats.Category,
                        TextSize = 11,
                        Font = Fonts.Body,
                        TextColor3 = Colors.TextMuted,
                        
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                        },
                    },
                    
                    -- Active mutations display
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
                            
                            ForPairs(scope, props.Mutations, function(use, scope, index, mutationType)
                                return index, MutationBadge(scope, {
                                    MutationType = mutationType,
                                    OnRemove = function()
                                        props.OnRemove(mutationType)
                                    end,
                                })
                            end),
                        },
                    },
                    
                    -- Expand/collapse indicator
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
            
            -- Expanded mutation selection area
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
                        CellSize = UDim2.fromOffset(130, 80),
                        CellPadding = UDim2.fromOffset(8, 8),
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    },
                    
                    New(scope, "UIPadding") {
                        PaddingTop = UDim.new(0, 8),
                        PaddingBottom = UDim.new(0, 8),
                        PaddingLeft = UDim.new(0, 8),
                        PaddingRight = UDim.new(0, 8),
                    },
                    
                    -- Mutation options
                    ForPairs(scope, compatibleMutations, function(use, scope, index, mutationInfo)
                        local mutationType = mutationInfo.Type
                        local data = mutationInfo.Data
                        
                        local isOwned = Computed(scope, function(use)
                            local mutations = use(props.Mutations)
                            return table.find(mutations, mutationType) ~= nil
                        end)
                        
                        local canPurchase = Computed(scope, function(use)
                            if use(isOwned) then return false end
                            
                            local level = use(props.PlayerLevel)
                            local coins = use(props.PlayerCoins)
                            
                            if level < data.RequiredLevel then return false end
                            if coins < data.Cost then return false end
                            
                            -- Check compatibility with existing mutations
                            local mutations = use(props.Mutations)
                            for _, existing in mutations do
                                if not MutationData.IsCompatibleWith(mutationType, existing) then
                                    return false
                                end
                            end
                            
                            return true
                        end)
                        
                        return index, MutationOption(scope, {
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

return function(scope: any, props: MutationViewProps)
    -- Compute unlocked plants
    local unlockedPlants = Computed(scope, function(use)
        local data = use(props.PlayerData)
        if not data then return {} end
        
        local result: {{Type: string, Stats: any}} = {}
        for plantType, stats in PlantData do
            if data.UnlockedPlants[plantType] then
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
            
            -- Header (top bar)
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
                    
                    -- Close button (RIGHT side)
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
            
            -- Main content
            New(scope, "ScrollingFrame") {
                Size = UDim2.new(1, -32, 1, -90),
                Position = UDim2.fromOffset(16, 80),
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
                    
                    -- Plant cards
                    ForPairs(scope, unlockedPlants, function(use, scope, index, plantInfo)
                        local plantType = plantInfo.Type
                        
                        local plantMutations = Computed(scope, function(use)
                            local allMutations = use(props.PlantMutations)
                            return allMutations[plantType] or {}
                        end)
                        
                        return index, PlantMutationCard(scope, {
                            PlantType = plantType,
                            PlantStats = plantInfo.Stats,
                            Mutations = plantMutations,
                            PlayerLevel = playerLevel,
                            PlayerCoins = playerCoins,
                            OnPurchase = function(mutationType)
                                props.OnPurchaseMutation(plantType, mutationType)
                            end,
                            OnRemove = function(mutationType)
                                props.OnRemoveMutation(plantType, mutationType)
                            end,
                        })
                    end),
                    
                    -- Empty state
                    Computed(scope, function(use)
                        if #use(unlockedPlants) == 0 then
                            return New(scope, "Frame") {
                                Size = UDim2.new(1, 0, 0, 150),
                                BackgroundColor3 = Colors.Card,
                                
                                [Children] = {
                                    New(scope, "UICorner") { CornerRadius = Sizing.RadiusLarge },
                                    
                                    New(scope, "TextLabel") {
                                        Size = UDim2.new(1, -40, 1, 0),
                                        Position = UDim2.fromOffset(20, 0),
                                        BackgroundTransparency = 1,
                                        Text = "🌱 No plants unlocked yet!\n\nVisit the Shop to unlock plants,\nthen come back to add mutations.",
                                        TextSize = 16,
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
            },
        },
    }
end
