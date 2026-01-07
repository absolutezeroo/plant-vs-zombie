--!strict
--[[
    LobbyScreen.luau - Main lobby UI container
    
    Manages the lobby flow:
    1. Main menu with Play, Shop, Profile buttons
    2. Stage selection (embedded StageSelectUI)
    3. Deck building (embedded DeckBuilder)
    4. Results display (if returning from Arena)
    
    Uses PvZ theme for consistent styling.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StageData = require(Shared.data.StageData)
local TeleportData = require(Shared.TeleportData)
local Logger = require(Shared.utils.Logger)

-- Note: PvZTheme lives in client/ui, we need to require it from there
-- For lobby, we'll copy the essential theme or require from a shared location
-- For now, define minimal theme inline (TODO: move PvZTheme to shared)
local PvZTheme = {
    Colors = {
        WoodBrown = Color3.fromRGB(139, 90, 43),
        WoodLight = Color3.fromRGB(180, 130, 80),
        WoodDark = Color3.fromRGB(101, 67, 33),
        GrassGreen = Color3.fromRGB(34, 139, 34),
        LeafGreen = Color3.fromRGB(50, 205, 50),
        SkyBlue = Color3.fromRGB(135, 206, 235),
        SunYellow = Color3.fromRGB(255, 215, 0),
        TextWhite = Color3.fromRGB(255, 255, 255),
        TextDark = Color3.fromRGB(50, 30, 10),
        Disabled = Color3.fromRGB(100, 100, 100),
        Danger = Color3.fromRGB(200, 50, 50),
        Success = Color3.fromRGB(50, 200, 50),
    },
    Icons = {
        Play = "▶",
        Settings = "⚙",
        Shop = "🛒",
        Trophy = "🏆",
        Star = "⭐",
        Lock = "🔒",
        Back = "◀",
        Close = "✕",
    },
}

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local peek = Fusion.peek

-- Screen states
type LobbyView = "Main" | "StageSelect" | "DeckBuilder" | "Results" | "Shop" | "Profile"

-- Props type
export type LobbyScreenProps = {
    SelectedStage: any, -- Value<string?>
    SelectedDeck: any,  -- Value<{string}>
    IsLoading: any,     -- Value<boolean>
    ReturnData: any,    -- Value<LobbyReturnData?>
    OnPlayClicked: (stageId: string, deck: { string }) -> (),
}

-- Button component
local function MenuButton(scope, props: {
    Text: string,
    Icon: string?,
    Color: Color3?,
    OnClick: () -> (),
    Disabled: any?,
})
    local isHovered = Value(scope, false)
    local baseColor = props.Color or PvZTheme.Colors.GrassGreen
    
    return New(scope, "TextButton") {
        Size = UDim2.new(0.8, 0, 0, 60),
        BackgroundColor3 = Computed(scope, function(use)
            if props.Disabled and use(props.Disabled) then
                return PvZTheme.Colors.Disabled
            elseif use(isHovered) then
                return Color3.new(
                    math.min(baseColor.R * 1.2, 1),
                    math.min(baseColor.G * 1.2, 1),
                    math.min(baseColor.B * 1.2, 1)
                )
            end
            return baseColor
        end),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
        
        [OnEvent "Activated"] = function()
            if not props.Disabled or not peek(props.Disabled) then
                props.OnClick()
            end
        end,
        [OnEvent "MouseEnter"] = function()
            isHovered:set(true)
        end,
        [OnEvent "MouseLeave"] = function()
            isHovered:set(false)
        end,
        
        [Children] = {
            New(scope, "UICorner") {
                CornerRadius = UDim.new(0, 12),
            },
            
            New(scope, "UIStroke") {
                Color = PvZTheme.Colors.WoodDark,
                Thickness = 3,
            },
            
            -- Icon
            props.Icon and New(scope, "TextLabel") {
                Size = UDim2.new(0, 50, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = props.Icon,
                TextSize = 28,
                Font = Enum.Font.GothamBold,
                TextColor3 = PvZTheme.Colors.TextWhite,
            } or nil,
            
            -- Text
            New(scope, "TextLabel") {
                Size = UDim2.new(1, -70, 1, 0),
                Position = UDim2.new(0, props.Icon and 60 or 10, 0, 0),
                BackgroundTransparency = 1,
                Text = props.Text,
                TextSize = 24,
                Font = Enum.Font.GothamBold,
                TextColor3 = PvZTheme.Colors.TextWhite,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
        },
    }
end

-- Results popup component
local function ResultsPopup(scope, props: {
    Data: TeleportData.LobbyReturnData,
    OnClose: () -> (),
})
    local starsText = string.rep("⭐", props.Data.Stars) .. string.rep("☆", 3 - props.Data.Stars)
    
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        ZIndex = 100,
        
        [Children] = {
            -- Popup panel
            New(scope, "Frame") {
                Size = UDim2.new(0, 400, 0, 350),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = PvZTheme.Colors.WoodBrown,
                ZIndex = 101,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 16),
                    },
                    
                    New(scope, "UIStroke") {
                        Color = PvZTheme.Colors.WoodDark,
                        Thickness = 4,
                    },
                    
                    -- Title
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 0, 60),
                        BackgroundColor3 = if props.Data.Victory 
                            then PvZTheme.Colors.Success 
                            else PvZTheme.Colors.Danger,
                        Text = if props.Data.Victory then "🎉 VICTORY! 🎉" else "💀 DEFEAT 💀",
                        TextSize = 32,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = PvZTheme.Colors.TextWhite,
                        
                        [Children] = {
                            New(scope, "UICorner") {
                                CornerRadius = UDim.new(0, 16),
                            },
                        },
                    },
                    
                    -- Stars
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, 0, 0, 50),
                        Position = UDim2.new(0, 0, 0, 70),
                        BackgroundTransparency = 1,
                        Text = starsText,
                        TextSize = 40,
                    },
                    
                    -- Rewards
                    New(scope, "Frame") {
                        Size = UDim2.new(0.8, 0, 0, 100),
                        Position = UDim2.new(0.1, 0, 0, 130),
                        BackgroundColor3 = PvZTheme.Colors.WoodLight,
                        
                        [Children] = {
                            New(scope, "UICorner") {
                                CornerRadius = UDim.new(0, 8),
                            },
                            
                            New(scope, "UIListLayout") {
                                FillDirection = Enum.FillDirection.Vertical,
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                Padding = UDim.new(0, 5),
                            },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 0, 30),
                                BackgroundTransparency = 1,
                                Text = `💰 Coins: +{props.Data.CoinsEarned}`,
                                TextSize = 20,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = PvZTheme.Colors.TextDark,
                            },
                            
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 0, 30),
                                BackgroundTransparency = 1,
                                Text = `✨ XP: +{props.Data.XPEarned}`,
                                TextSize = 20,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = PvZTheme.Colors.TextDark,
                            },
                        },
                    },
                    
                    -- Continue button
                    New(scope, "TextButton") {
                        Size = UDim2.new(0.6, 0, 0, 50),
                        Position = UDim2.new(0.2, 0, 1, -70),
                        BackgroundColor3 = PvZTheme.Colors.GrassGreen,
                        Text = "Continue",
                        TextSize = 22,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = PvZTheme.Colors.TextWhite,
                        
                        [OnEvent "Activated"] = props.OnClose,
                        
                        [Children] = {
                            New(scope, "UICorner") {
                                CornerRadius = UDim.new(0, 10),
                            },
                        },
                    },
                },
            },
        },
    }
end

-- Main LobbyScreen component
return function(props: LobbyScreenProps)
    -- Create a scope for cleanup
    local scope = Fusion.scoped({})
    
    -- Current view state
    local currentView: Fusion.Value<LobbyView> = Value(scope, "Main")
    
    -- Check if we should show results
    local showResults = Computed(scope, function(use)
        return use(props.ReturnData) ~= nil
    end)
    
    -- Main menu view
    local function MainMenu()
        return New(scope, "Frame") {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            
            [Children] = {
                -- Logo/Title
                New(scope, "TextLabel") {
                    Size = UDim2.new(1, 0, 0, 120),
                    Position = UDim2.new(0, 0, 0.1, 0),
                    BackgroundTransparency = 1,
                    Text = "🌻 Plants vs Zombies 🧟",
                    TextSize = 42,
                    Font = Enum.Font.GothamBlack,
                    TextColor3 = PvZTheme.Colors.SunYellow,
                    TextStrokeTransparency = 0.5,
                    TextStrokeColor3 = PvZTheme.Colors.WoodDark,
                },
                
                -- Buttons container
                New(scope, "Frame") {
                    Size = UDim2.new(0, 300, 0, 280),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    
                    [Children] = {
                        New(scope, "UIListLayout") {
                            FillDirection = Enum.FillDirection.Vertical,
                            HorizontalAlignment = Enum.HorizontalAlignment.Center,
                            VerticalAlignment = Enum.VerticalAlignment.Center,
                            Padding = UDim.new(0, 15),
                        },
                        
                        MenuButton(scope, {
                            Text = "PLAY",
                            Icon = PvZTheme.Icons.Play,
                            Color = PvZTheme.Colors.GrassGreen,
                            OnClick = function()
                                Logger.Info("LobbyScreen", "Play clicked")
                                currentView:set("StageSelect")
                            end,
                        }),
                        
                        MenuButton(scope, {
                            Text = "Shop",
                            Icon = PvZTheme.Icons.Shop,
                            Color = PvZTheme.Colors.SunYellow,
                            OnClick = function()
                                Logger.Info("LobbyScreen", "Shop clicked")
                                currentView:set("Shop")
                            end,
                        }),
                        
                        MenuButton(scope, {
                            Text = "Profile",
                            Icon = PvZTheme.Icons.Trophy,
                            Color = PvZTheme.Colors.WoodBrown,
                            OnClick = function()
                                Logger.Info("LobbyScreen", "Profile clicked")
                                currentView:set("Profile")
                            end,
                        }),
                    },
                },
            },
        }
    end
    
    -- Placeholder views
    local function PlaceholderView(title: string)
        return New(scope, "Frame") {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = PvZTheme.Colors.WoodLight,
            
            [Children] = {
                -- Back button
                New(scope, "TextButton") {
                    Size = UDim2.new(0, 100, 0, 40),
                    Position = UDim2.new(0, 20, 0, 20),
                    BackgroundColor3 = PvZTheme.Colors.WoodBrown,
                    Text = "◀ Back",
                    TextSize = 18,
                    Font = Enum.Font.GothamBold,
                    TextColor3 = PvZTheme.Colors.TextWhite,
                    
                    [OnEvent "Activated"] = function()
                        currentView:set("Main")
                    end,
                    
                    [Children] = {
                        New(scope, "UICorner") {
                            CornerRadius = UDim.new(0, 8),
                        },
                    },
                },
                
                -- Title
                New(scope, "TextLabel") {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = title .. "\n(Coming Soon)",
                    TextSize = 36,
                    Font = Enum.Font.GothamBold,
                    TextColor3 = PvZTheme.Colors.TextDark,
                },
            },
        }
    end
    
    -- Stage Select view (temporary - will integrate real StageSelectUI later)
    local function StageSelectView()
        local selectedStage = Value(scope, nil :: string?)
        
        return New(scope, "Frame") {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = PvZTheme.Colors.SkyBlue,
            
            [Children] = {
                -- Back button
                New(scope, "TextButton") {
                    Size = UDim2.new(0, 100, 0, 40),
                    Position = UDim2.new(0, 20, 0, 20),
                    BackgroundColor3 = PvZTheme.Colors.WoodBrown,
                    Text = "◀ Back",
                    TextSize = 18,
                    Font = Enum.Font.GothamBold,
                    TextColor3 = PvZTheme.Colors.TextWhite,
                    
                    [OnEvent "Activated"] = function()
                        currentView:set("Main")
                    end,
                    
                    [Children] = {
                        New(scope, "UICorner") {
                            CornerRadius = UDim.new(0, 8),
                        },
                    },
                },
                
                -- Title
                New(scope, "TextLabel") {
                    Size = UDim2.new(1, 0, 0, 60),
                    Position = UDim2.new(0, 0, 0, 20),
                    BackgroundTransparency = 1,
                    Text = "🗺️ Select Stage",
                    TextSize = 32,
                    Font = Enum.Font.GothamBlack,
                    TextColor3 = PvZTheme.Colors.TextWhite,
                    TextStrokeTransparency = 0.5,
                },
                
                -- Stage buttons (simplified for now)
                New(scope, "Frame") {
                    Size = UDim2.new(0.8, 0, 0.6, 0),
                    Position = UDim2.new(0.1, 0, 0.2, 0),
                    BackgroundTransparency = 1,
                    
                    [Children] = {
                        New(scope, "UIGridLayout") {
                            CellSize = UDim2.new(0, 120, 0, 100),
                            CellPadding = UDim2.new(0, 15, 0, 15),
                            HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        },
                        
                        -- Generate stage buttons for World 1
                        table.unpack((function()
                            local buttons = {}
                            for i = 1, 5 do
                                local stageId = `1-{i}`
                                local isSelected = Computed(scope, function(use)
                                    return use(selectedStage) == stageId
                                end)
                                
                                table.insert(buttons, New(scope, "TextButton") {
                                    BackgroundColor3 = Computed(scope, function(use)
                                        return if use(isSelected) 
                                            then PvZTheme.Colors.GrassGreen 
                                            else PvZTheme.Colors.WoodBrown
                                    end),
                                    Text = `Stage {i}\n⭐⭐⭐`,
                                    TextSize = 16,
                                    Font = Enum.Font.GothamBold,
                                    TextColor3 = PvZTheme.Colors.TextWhite,
                                    
                                    [OnEvent "Activated"] = function()
                                        selectedStage:set(stageId)
                                        props.SelectedStage:set(stageId)
                                    end,
                                    
                                    [Children] = {
                                        New(scope, "UICorner") {
                                            CornerRadius = UDim.new(0, 10),
                                        },
                                        New(scope, "UIStroke") {
                                            Color = PvZTheme.Colors.WoodDark,
                                            Thickness = 3,
                                        },
                                    },
                                })
                            end
                            return buttons
                        end)()),
                    },
                },
                
                -- Next button
                Computed(scope, function(use)
                    if use(selectedStage) then
                        return New(scope, "TextButton") {
                            Size = UDim2.new(0, 200, 0, 50),
                            Position = UDim2.new(0.5, 0, 0.9, 0),
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundColor3 = PvZTheme.Colors.GrassGreen,
                            Text = "Build Deck →",
                            TextSize = 22,
                            Font = Enum.Font.GothamBold,
                            TextColor3 = PvZTheme.Colors.TextWhite,
                            
                            [OnEvent "Activated"] = function()
                                currentView:set("DeckBuilder")
                            end,
                            
                            [Children] = {
                                New(scope, "UICorner") {
                                    CornerRadius = UDim.new(0, 10),
                                },
                            },
                        }
                    end
                    return nil
                end),
            },
        }
    end
    
    -- Deck Builder view (simplified - will integrate real DeckBuilder later)
    local function DeckBuilderView()
        local deck = Value(scope, {} :: { string })
        local availablePlants = { "Sunflower", "Peashooter", "WallNut", "PotatoMine", "SnowPea", "Chomper", "Repeater", "CherryBomb" }
        
        return New(scope, "Frame") {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = PvZTheme.Colors.GrassGreen,
            
            [Children] = {
                -- Back button
                New(scope, "TextButton") {
                    Size = UDim2.new(0, 100, 0, 40),
                    Position = UDim2.new(0, 20, 0, 20),
                    BackgroundColor3 = PvZTheme.Colors.WoodBrown,
                    Text = "◀ Back",
                    TextSize = 18,
                    Font = Enum.Font.GothamBold,
                    TextColor3 = PvZTheme.Colors.TextWhite,
                    
                    [OnEvent "Activated"] = function()
                        currentView:set("StageSelect")
                    end,
                    
                    [Children] = {
                        New(scope, "UICorner") {
                            CornerRadius = UDim.new(0, 8),
                        },
                    },
                },
                
                -- Title
                New(scope, "TextLabel") {
                    Size = UDim2.new(1, 0, 0, 60),
                    Position = UDim2.new(0, 0, 0, 20),
                    BackgroundTransparency = 1,
                    Text = "🌱 Build Your Deck",
                    TextSize = 32,
                    Font = Enum.Font.GothamBlack,
                    TextColor3 = PvZTheme.Colors.TextWhite,
                    TextStrokeTransparency = 0.5,
                },
                
                -- Deck slots (top)
                New(scope, "Frame") {
                    Size = UDim2.new(0.9, 0, 0, 80),
                    Position = UDim2.new(0.05, 0, 0, 90),
                    BackgroundColor3 = PvZTheme.Colors.WoodBrown,
                    
                    [Children] = {
                        New(scope, "UICorner") {
                            CornerRadius = UDim.new(0, 10),
                        },
                        
                        New(scope, "TextLabel") {
                            Size = UDim2.new(1, 0, 0, 20),
                            BackgroundTransparency = 1,
                            Text = Computed(scope, function(use)
                                return `Your Deck ({#use(deck)}/6)`
                            end),
                            TextSize = 14,
                            Font = Enum.Font.GothamBold,
                            TextColor3 = PvZTheme.Colors.TextWhite,
                        },
                        
                        -- Deck display
                        New(scope, "TextLabel") {
                            Size = UDim2.new(1, 0, 0, 40),
                            Position = UDim2.new(0, 0, 0, 25),
                            BackgroundTransparency = 1,
                            Text = Computed(scope, function(use)
                                local d = use(deck)
                                if #d == 0 then
                                    return "Click plants below to add"
                                end
                                return table.concat(d, " | ")
                            end),
                            TextSize = 18,
                            Font = Enum.Font.Gotham,
                            TextColor3 = PvZTheme.Colors.TextWhite,
                        },
                    },
                },
                
                -- Available plants grid
                New(scope, "Frame") {
                    Size = UDim2.new(0.9, 0, 0.45, 0),
                    Position = UDim2.new(0.05, 0, 0.25, 0),
                    BackgroundColor3 = PvZTheme.Colors.WoodLight,
                    
                    [Children] = {
                        New(scope, "UICorner") {
                            CornerRadius = UDim.new(0, 10),
                        },
                        
                        New(scope, "ScrollingFrame") {
                            Size = UDim2.new(1, -20, 1, -20),
                            Position = UDim2.new(0, 10, 0, 10),
                            BackgroundTransparency = 1,
                            ScrollBarThickness = 6,
                            CanvasSize = UDim2.new(0, 0, 0, 250),
                            
                            [Children] = {
                                New(scope, "UIGridLayout") {
                                    CellSize = UDim2.new(0, 90, 0, 70),
                                    CellPadding = UDim2.new(0, 10, 0, 10),
                                },
                                
                                table.unpack((function()
                                    local cards = {}
                                    for _, plantType in availablePlants do
                                        local isInDeck = Computed(scope, function(use)
                                            local d = use(deck)
                                            return table.find(d, plantType) ~= nil
                                        end)
                                        
                                        table.insert(cards, New(scope, "TextButton") {
                                            BackgroundColor3 = Computed(scope, function(use)
                                                return if use(isInDeck) 
                                                    then PvZTheme.Colors.LeafGreen 
                                                    else PvZTheme.Colors.WoodBrown
                                            end),
                                            Text = plantType,
                                            TextSize = 12,
                                            Font = Enum.Font.GothamBold,
                                            TextColor3 = PvZTheme.Colors.TextWhite,
                                            TextWrapped = true,
                                            
                                            [OnEvent "Activated"] = function()
                                                local currentDeck = peek(deck)
                                                local idx = table.find(currentDeck, plantType)
                                                if idx then
                                                    -- Remove from deck
                                                    table.remove(currentDeck, idx)
                                                else
                                                    -- Add to deck (max 6)
                                                    if #currentDeck < 6 then
                                                        table.insert(currentDeck, plantType)
                                                    end
                                                end
                                                deck:set(table.clone(currentDeck))
                                                props.SelectedDeck:set(table.clone(currentDeck))
                                            end,
                                            
                                            [Children] = {
                                                New(scope, "UICorner") {
                                                    CornerRadius = UDim.new(0, 8),
                                                },
                                            },
                                        })
                                    end
                                    return cards
                                end)()),
                            },
                        },
                    },
                },
                
                -- Play button
                New(scope, "TextButton") {
                    Size = UDim2.new(0, 250, 0, 60),
                    Position = UDim2.new(0.5, 0, 0.9, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Computed(scope, function(use)
                        return if #use(deck) > 0 
                            then PvZTheme.Colors.SunYellow 
                            else PvZTheme.Colors.Disabled
                    end),
                    Text = "🎮 START BATTLE!",
                    TextSize = 24,
                    Font = Enum.Font.GothamBlack,
                    TextColor3 = PvZTheme.Colors.TextDark,
                    
                    [OnEvent "Activated"] = function()
                        local currentDeck = peek(deck)
                        local stageId = peek(props.SelectedStage)
                        if #currentDeck > 0 and stageId then
                            props.OnPlayClicked(stageId, currentDeck)
                        end
                    end,
                    
                    [Children] = {
                        New(scope, "UICorner") {
                            CornerRadius = UDim.new(0, 12),
                        },
                        New(scope, "UIStroke") {
                            Color = PvZTheme.Colors.WoodDark,
                            Thickness = 3,
                        },
                    },
                },
            },
        }
    end
    
    -- Main container
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = PvZTheme.Colors.SkyBlue,
        
        [Children] = {
            -- Gradient background
            New(scope, "UIGradient") {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(135, 206, 250)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 130, 180)),
                }),
                Rotation = 90,
            },
            
            -- View switcher
            Computed(scope, function(use)
                local view = use(currentView)
                if view == "Main" then
                    return MainMenu()
                elseif view == "StageSelect" then
                    return StageSelectView()
                elseif view == "DeckBuilder" then
                    return DeckBuilderView()
                elseif view == "Shop" then
                    return PlaceholderView("🛒 Shop")
                elseif view == "Profile" then
                    return PlaceholderView("🏆 Profile")
                end
                return nil
            end),
            
            -- Results popup overlay
            Computed(scope, function(use)
                local returnData = use(props.ReturnData)
                if returnData then
                    return ResultsPopup(scope, {
                        Data = returnData,
                        OnClose = function()
                            props.ReturnData:set(nil)
                        end,
                    })
                end
                return nil
            end),
            
            -- Loading overlay
            Computed(scope, function(use)
                if use(props.IsLoading) then
                    return New(scope, "Frame") {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundColor3 = Color3.new(0, 0, 0),
                        BackgroundTransparency = 0.5,
                        ZIndex = 200,
                        
                        [Children] = {
                            New(scope, "TextLabel") {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "⏳ Teleporting...",
                                TextSize = 32,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = PvZTheme.Colors.TextWhite,
                                ZIndex = 201,
                            },
                        },
                    }
                end
                return nil
            end),
        },
    }
end
