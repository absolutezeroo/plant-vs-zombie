--!strict
--[[
    DeckBuilderView.luau - Modern Deck Builder UI
    
    Clean layout with drag-like selection, clear deck slots,
    and modern Roblox-style design.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local ProgressionData = require(Shared.data.ProgressionData)
local MutationData = require(Shared.data.MutationData)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local peek = Fusion.peek

-- Modern dark color palette
local Colors = {
    Background = Color3.fromRGB(20, 25, 20),
    CardBg = Color3.fromRGB(35, 45, 35),
    CardHover = Color3.fromRGB(50, 65, 50),
    CardSelected = Color3.fromRGB(60, 90, 60),
    TopBar = Color3.fromRGB(28, 35, 28),
    DeckBar = Color3.fromRGB(40, 50, 40),
    SlotEmpty = Color3.fromRGB(30, 40, 30),
    SlotFilled = Color3.fromRGB(55, 80, 55),
    Gold = Color3.fromRGB(255, 193, 7),
    Green = Color3.fromRGB(76, 175, 80),
    GreenBright = Color3.fromRGB(100, 200, 100),
    Red = Color3.fromRGB(244, 67, 54),
    TextWhite = Color3.new(1, 1, 1),
    TextMuted = Color3.fromRGB(140, 155, 140),
    Border = Color3.fromRGB(60, 75, 60),
    Locked = Color3.fromRGB(60, 60, 65),
}

export type DeckBuilderViewProps = {
    SelectedDeck: any,
    PlayerData: any,
    PlantMutations: any?, -- Value<{[string]: {string}}>
    OnBack: () -> (),
    OnPlay: () -> (),
    OnSaveDeck: (deck: {string}) -> (),
}

-- Mutation emoji mapping
local MutationEmojis: {[string]: string} = {
    Fire = "🔥", Inferno = "🔥",
    Ice = "❄️", Frost = "❄️",
    Electric = "⚡", Thunder = "⚡",
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

-- Plant emojis
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

local function getPlantEmoji(plantType: string): string
    return PlantEmojis[plantType] or "🌱"
end

-- Deck slot component
local function DeckSlot(scope: any, props: {
    Index: number,
    PlantType: string?,
    Mutations: {string}?,
    OnRemove: () -> (),
}): Frame
    local isHovered = Value(scope, false)
    local hasPlant = props.PlantType ~= nil
    local hasMutation = props.Mutations and #props.Mutations > 0
    
    return New(scope, "Frame") {
        Size = UDim2.fromOffset(75, 85),
        BackgroundColor3 = Computed(scope, function(use)
            if hasPlant then
                return if use(isHovered) then Colors.Red else Colors.SlotFilled
            end
            return Colors.SlotEmpty
        end),
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
            New(scope, "UIStroke") {
                Color = if hasMutation 
                    then Color3.fromRGB(255, 150, 50) -- Orange glow for mutated
                    elseif hasPlant then Colors.GreenBright 
                    else Colors.Border,
                Thickness = if hasMutation then 3 else 2,
            },
            
            -- Mutation badge (top-right)
            hasMutation and New(scope, "Frame") {
                Size = UDim2.fromOffset(22, 22),
                Position = UDim2.new(1, -4, 0, 4),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = Color3.fromRGB(255, 100, 50),
                ZIndex = 5,
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = getMutationEmoji(props.Mutations[1]),
                        TextSize = 12,
                    },
                },
            } or nil,
            
            -- Slot number badge
            New(scope, "Frame") {
                Size = UDim2.fromOffset(22, 22),
                Position = UDim2.fromOffset(4, 4),
                BackgroundColor3 = Colors.TopBar,
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = tostring(props.Index),
                        TextColor3 = Colors.TextMuted,
                        TextSize = 11,
                        Font = Enum.Font.GothamBold,
                    },
                },
            },
            
            -- Plant emoji or +
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 35),
                Position = UDim2.fromOffset(0, 25),
                BackgroundTransparency = 1,
                Text = if hasPlant then getPlantEmoji(props.PlantType :: string) else "+",
                TextSize = if hasPlant then 28 else 32,
                TextColor3 = if hasPlant then Colors.TextWhite else Colors.TextMuted,
            },
            
            -- Plant name (small)
            hasPlant and New(scope, "TextLabel") {
                Size = UDim2.new(1, -8, 0, 16),
                Position = UDim2.new(0, 4, 1, -20),
                BackgroundTransparency = 1,
                Text = props.PlantType :: string,
                TextColor3 = Colors.TextWhite,
                TextSize = 9,
                Font = Enum.Font.GothamBold,
                TextTruncate = Enum.TextTruncate.AtEnd,
            } or nil,
            
            -- Remove hint on hover
            Computed(scope, function(use)
                if hasPlant and use(isHovered) then
                    return New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundColor3 = Colors.Red,
                        BackgroundTransparency = 0.3,
                        Text = "✕",
                        TextColor3 = Colors.TextWhite,
                        TextSize = 24,
                        Font = Enum.Font.GothamBold,
                        [Children] = { New(scope, "UICorner") { CornerRadius = UDim.new(0, 12) } },
                    }
                end
                return nil
            end),
            
            -- Click handler
            New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 10,
                [OnEvent "Activated"] = function()
                    if hasPlant then props.OnRemove() end
                end,
                [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
            },
        },
    }
end

-- Plant selection card
local function PlantCard(scope: any, props: {
    PlantType: string,
    PlantStats: any,
    IsInDeck: any,
    IsLocked: boolean,
    Mutations: {string}?,
    OnToggle: () -> (),
}): Frame
    local isHovered = Value(scope, false)
    local emoji = getPlantEmoji(props.PlantType)
    local hasMutation = props.Mutations and #props.Mutations > 0
    
    return New(scope, "Frame") {
        Name = props.PlantType,
        Size = UDim2.fromOffset(105, 130),
        BackgroundColor3 = Computed(scope, function(use)
            if props.IsLocked then return Colors.Locked end
            if use(props.IsInDeck) then return Colors.CardSelected end
            if use(isHovered) then return Colors.CardHover end
            return Colors.CardBg
        end),
        
        [Children] = {
            New(scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
            
            New(scope, "UIStroke") {
                Color = Computed(scope, function(use)
                    if props.IsLocked then return Colors.Locked end
                    if hasMutation then return Color3.fromRGB(255, 150, 50) end
                    if use(props.IsInDeck) then return Colors.Gold end
                    if use(isHovered) then return Colors.GreenBright end
                    return Colors.Border
                end),
                Thickness = if hasMutation then 3 else 2,
            },
            
            -- Mutation badge (top-right corner)
            hasMutation and New(scope, "Frame") {
                Size = UDim2.fromOffset(24, 24),
                Position = UDim2.new(1, -4, 0, 4),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = Color3.fromRGB(255, 100, 50),
                ZIndex = 6,
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = getMutationEmoji(props.Mutations[1]),
                        TextSize = 14,
                    },
                },
            } or nil,
            
            -- Lock overlay
            props.IsLocked and New(scope, "Frame") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.5,
                ZIndex = 5,
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 12) },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "🔒",
                        TextSize = 30,
                    },
                },
            } or nil,
            
            -- In-deck checkmark
            Computed(scope, function(use)
                if use(props.IsInDeck) then
                    return New(scope, "Frame") {
                        Size = UDim2.fromOffset(24, 24),
                        Position = UDim2.new(1, -6, 0, 6),
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundColor3 = Colors.Gold,
                        ZIndex = 3,
                        [Children] = {
                            New(scope, "UICorner") { CornerRadius = UDim.new(0.5, 0) },
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "✓",
                                TextColor3 = Color3.fromRGB(30, 30, 30),
                                TextSize = 14,
                                Font = Enum.Font.GothamBold,
                            },
                        },
                    }
                end
                return nil
            end),
            
            -- Plant emoji
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 45),
                Position = UDim2.fromOffset(0, 12),
                BackgroundTransparency = 1,
                Text = emoji,
                TextSize = 36,
            },
            
            -- Plant name
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -8, 0, 20),
                Position = UDim2.new(0, 4, 0, 58),
                BackgroundTransparency = 1,
                Text = props.PlantType,
                TextColor3 = if props.IsLocked then Colors.TextMuted else Colors.TextWhite,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextTruncate = Enum.TextTruncate.AtEnd,
            },
            
            -- Sun cost
            New(scope, "Frame") {
                Size = UDim2.fromOffset(50, 20),
                Position = UDim2.new(0.5, 0, 0, 80),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundColor3 = Color3.fromRGB(255, 180, 0),
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 6) },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = `☀️{props.PlantStats.Cost}`,
                        TextColor3 = Color3.fromRGB(50, 50, 50),
                        TextSize = 11,
                        Font = Enum.Font.GothamBold,
                    },
                },
            },
            
            -- Category
            New(scope, "TextLabel") {
                Size = UDim2.new(1, 0, 0, 14),
                Position = UDim2.new(0, 0, 1, -18),
                BackgroundTransparency = 1,
                Text = props.PlantStats.Category or "",
                TextColor3 = Colors.TextMuted,
                TextSize = 9,
                Font = Enum.Font.Gotham,
            },
            
            -- Click handler
            not props.IsLocked and New(scope, "TextButton") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 10,
                [OnEvent "Activated"] = props.OnToggle,
                [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
            } or nil,
        },
    }
end

-- Filter pill
local function FilterPill(scope: any, text: string, isActive: any, onClick: () -> ()): TextButton
    return New(scope, "TextButton") {
        Size = UDim2.fromOffset(75, 30),
        BackgroundColor3 = Computed(scope, function(use)
            return if use(isActive) then Colors.Gold else Colors.CardBg
        end),
        Text = text,
        TextColor3 = Computed(scope, function(use)
            return if use(isActive) then Color3.fromRGB(30, 30, 30) else Colors.TextWhite
        end),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        [OnEvent "Activated"] = onClick,
        [Children] = { New(scope, "UICorner") { CornerRadius = UDim.new(0, 15) } },
    }
end

return function(scope: any, props: DeckBuilderViewProps): Frame
    local selectedFilter = Value(scope, "All")
    local localDeck = Value(scope, table.clone(peek(props.SelectedDeck) or {}))
    
    -- Unlocked set
    local unlockedSet = Computed(scope, function(use)
        local data = use(props.PlayerData)
        local set: {[string]: boolean} = {}
        if data and data.UnlockedPlants then
            for _, pt in ipairs(data.UnlockedPlants) do set[pt] = true end
        end
        return set
    end)
    
    -- Sorted plants
    local sortedPlants = (function()
        local plants = {}
        for plantType, info in pairs(ProgressionData.PlantUnlocks) do
            local stats = PlantData[plantType]
            if stats then
                table.insert(plants, { PlantType = plantType, Order = info.Order, Stats = stats })
            end
        end
        table.sort(plants, function(a, b) return a.Order < b.Order end)
        return plants
    end)()
    
    -- Filtered plants
    local filteredPlants = Computed(scope, function(use)
        local filter = use(selectedFilter)
        local result = {}
        for _, p in ipairs(sortedPlants) do
            if filter == "All" or p.Stats.Category == filter then
                table.insert(result, p)
            end
        end
        return result
    end)
    
    local function togglePlant(plantType: string)
        local deck = table.clone(peek(localDeck))
        local idx = table.find(deck, plantType)
        if idx then
            table.remove(deck, idx)
        elseif #deck < 6 then
            table.insert(deck, plantType)
        end
        localDeck:set(deck)
        props.SelectedDeck:set(table.clone(deck))
    end
    
    local function removePlant(index: number)
        local deck = table.clone(peek(localDeck))
        if deck[index] then
            table.remove(deck, index)
            localDeck:set(deck)
            props.SelectedDeck:set(table.clone(deck))
        end
    end
    
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.Background,
        
        [Children] = {
            -- Top bar
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 60),
                BackgroundColor3 = Colors.TopBar,
                [Children] = {
                    -- Close (RIGHT side to avoid Roblox UI)
                    New(scope, "TextButton") {
                        Size = UDim2.fromOffset(44, 44),
                        Position = UDim2.new(1, -12, 0, 8),
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundColor3 = Colors.CardBg,
                        Text = "✕",
                        TextColor3 = Colors.TextWhite,
                        TextSize = 20,
                        Font = Enum.Font.GothamBold,
                        [OnEvent "Activated"] = props.OnBack,
                        [Children] = { New(scope, "UICorner") { CornerRadius = UDim.new(0, 10) } },
                    },
                    -- Title
                    New(scope, "TextLabel") {
                        Size = UDim2.fromOffset(200, 60),
                        Position = UDim2.new(0.5, 0, 0, 0),
                        AnchorPoint = Vector2.new(0.5, 0),
                        BackgroundTransparency = 1,
                        Text = "🌱 DECK BUILDER",
                        TextColor3 = Colors.TextWhite,
                        TextSize = 22,
                        Font = Enum.Font.GothamBlack,
                    },
                },
            },
            
            -- Deck slots bar
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 110),
                Position = UDim2.fromOffset(0, 65),
                BackgroundColor3 = Colors.DeckBar,
                [Children] = {
                    -- Deck count
                    New(scope, "TextLabel") {
                        Size = UDim2.fromOffset(100, 25),
                        Position = UDim2.fromOffset(15, 5),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            return `Your Deck: {#use(localDeck)}/6`
                        end),
                        TextColor3 = Colors.TextWhite,
                        TextSize = 13,
                        Font = Enum.Font.GothamBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    
                    -- Slots container
                    New(scope, "Frame") {
                        Size = UDim2.new(1, -20, 0, 85),
                        Position = UDim2.fromOffset(10, 22),
                        BackgroundTransparency = 1,
                        [Children] = {
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Horizontal,
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                Padding = UDim.new(0, 8),
                            },
                            Computed(scope, function(use)
                                local deck = use(localDeck)
                                local mutations = if props.PlantMutations then use(props.PlantMutations) else {}
                                local slots = {}
                                for i = 1, 6 do
                                    local plantType = deck[i]
                                    table.insert(slots, DeckSlot(scope, {
                                        Index = i,
                                        PlantType = plantType,
                                        Mutations = if plantType then mutations[plantType] else nil,
                                        OnRemove = function() removePlant(i) end,
                                    }))
                                end
                                return slots
                            end),
                        },
                    },
                },
            },
            
            -- Category filters
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 40),
                Position = UDim2.fromOffset(0, 180),
                BackgroundTransparency = 1,
                [Children] = {
                    New(scope, "UIListLayout") {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        Padding = UDim.new(0, 6),
                    },
                    FilterPill(scope, "All", Computed(scope, function(use) return use(selectedFilter) == "All" end),
                        function() selectedFilter:set("All") end),
                    FilterPill(scope, "Attacker", Computed(scope, function(use) return use(selectedFilter) == "Attacker" end),
                        function() selectedFilter:set("Attacker") end),
                    FilterPill(scope, "Producer", Computed(scope, function(use) return use(selectedFilter) == "Producer" end),
                        function() selectedFilter:set("Producer") end),
                    FilterPill(scope, "Defender", Computed(scope, function(use) return use(selectedFilter) == "Defender" end),
                        function() selectedFilter:set("Defender") end),
                    FilterPill(scope, "Special", Computed(scope, function(use) return use(selectedFilter) == "Special" end),
                        function() selectedFilter:set("Special") end),
                },
            },
            
            -- Plants grid
            New(scope, "ScrollingFrame") {
                Size = UDim2.new(1, -20, 0.48, 0),
                Position = UDim2.new(0, 10, 0, 225),
                BackgroundTransparency = 1,
                ScrollBarThickness = 5,
                ScrollBarImageColor3 = Colors.Border,
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                [Children] = {
                    New(scope, "UIPadding") { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 10) },
                    New(scope, "UIGridLayout") {
                        CellSize = UDim2.fromOffset(105, 130),
                        CellPadding = UDim2.fromOffset(10, 10),
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    },
                    Computed(scope, function(use)
                        local plants = use(filteredPlants)
                        local unlocked = use(unlockedSet)
                        local mutations = if props.PlantMutations then use(props.PlantMutations) else {}
                        local cards = {}
                        for _, p in ipairs(plants) do
                            local isLocked = not unlocked[p.PlantType]
                            local isInDeck = Computed(scope, function(use2)
                                return table.find(use2(localDeck), p.PlantType) ~= nil
                            end)
                            local plantMutations = mutations[p.PlantType]
                            table.insert(cards, PlantCard(scope, {
                                PlantType = p.PlantType,
                                PlantStats = p.Stats,
                                IsInDeck = isInDeck,
                                IsLocked = isLocked,
                                Mutations = plantMutations,
                                OnToggle = function() togglePlant(p.PlantType) end,
                            }))
                        end
                        return cards
                    end),
                },
            },
            
            -- Play button
            New(scope, "TextButton") {
                Size = UDim2.new(0.85, 0, 0, 55),
                Position = UDim2.new(0.5, 0, 0.94, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Computed(scope, function(use)
                    return if #use(localDeck) > 0 then Colors.Green else Colors.Locked
                end),
                Text = "",
                AutoButtonColor = false,
                
                [OnEvent "Activated"] = function()
                    local deck = peek(localDeck)
                    if #deck > 0 then
                        props.OnSaveDeck(deck)
                        props.OnPlay()
                    end
                end,
                
                [Children] = {
                    New(scope, "UICorner") { CornerRadius = UDim.new(0, 14) },
                    New(scope, "UIStroke") {
                        Color = Computed(scope, function(use)
                            return if #use(localDeck) > 0 then Colors.GreenBright else Colors.Border
                        end),
                        Thickness = 3,
                    },
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "🎮 START BATTLE",
                        TextColor3 = Colors.TextWhite,
                        TextSize = 22,
                        Font = Enum.Font.GothamBlack,
                    },
                },
            },
        },
    }
end
