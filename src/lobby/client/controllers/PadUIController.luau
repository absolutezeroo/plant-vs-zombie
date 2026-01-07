--!strict
--[[
    PadUIController.luau - Manages BillboardGui on teleport pads + Leave UI
    
    Responsibilities:
    - Create/update BillboardGui for each pad
    - Listen for PadStateUpdate from server
    - Display: Stage info, X/Y players, countdown, status
    - Show Leave button when player is on pad (TDS-style)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local WorldData = require(Shared.data.WorldData)
local DifficultyData = require(Shared.data.DifficultyData)

-- Import Zap (navigate from controllers/ to client/ then to network/)
local LobbyClient = script.Parent.Parent
local ZapClient = require(LobbyClient:WaitForChild("network"):WaitForChild("generated"))

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local OnEvent = Fusion.OnEvent

-- Pad state tracking
type PadUIState = {
    PadId: string,
    Scope: any, -- Store scope to prevent garbage collection
    WorldId: Fusion.Value<string>,
    Difficulty: Fusion.Value<string>,
    PlayersCount: Fusion.Value<number>,
    MaxPlayers: Fusion.Value<number>,
    CountdownRemaining: Fusion.Value<number?>,
    BillboardGui: BillboardGui?,
}

local _padStates: {[string]: PadUIState} = {}
local _scope = Fusion.scoped(Fusion)

-- Track if player is currently on a pad
local _isOnPad = Value(_scope, false)
local _currentPadId = Value(_scope, "")
local _currentWorldId = Value(_scope, "")
local _currentDifficulty = Value(_scope, "")
local _currentCountdown = Value(_scope, nil :: number?)
local _currentPlayerCount = Value(_scope, 0)
local _currentMaxPlayers = Value(_scope, 1)
local _leaveButtonUI: ScreenGui? = nil

local PadUIController = {}

-- Create BillboardGui for a pad
local function createPadUI(scope, state: PadUIState): BillboardGui
    local worldConfig = WorldData.GetWorld(Fusion.peek(state.WorldId))
    local diffConfig = DifficultyData.GetDifficulty(Fusion.peek(state.Difficulty))
    local displayName = if worldConfig and diffConfig 
        then `{worldConfig.Name} ({diffConfig.Name})`
        else `{Fusion.peek(state.WorldId)} - {Fusion.peek(state.Difficulty)}`
    
    return New(scope, "BillboardGui") {
        Name = "PadUI",
        Size = UDim2.new(0, 200, 0, 120), -- Fixed pixel size (not studs)
        StudsOffset = Vector3.new(0, 5, 0),
        AlwaysOnTop = true,
        MaxDistance = 50, -- Only visible within 50 studs
        
        [Children] = {
            -- Background frame
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.fromRGB(139, 90, 43), -- Wood brown
                BorderSizePixel = 0,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 12),
                    },
                    
                    New(scope, "UIStroke") {
                        Color = Color3.fromRGB(101, 67, 33),
                        Thickness = 3,
                    },
                    
                    -- World + Difficulty name
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -16, 0, 32),
                        Position = UDim2.new(0, 8, 0, 8),
                        BackgroundTransparency = 1,
                        Text = displayName,
                        TextSize = 18,
                        TextScaled = false,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = Color3.fromRGB(255, 215, 0), -- Gold
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    
                    -- Player count
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -16, 0, 28),
                        Position = UDim2.new(0, 8, 0, 42),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            return `{use(state.PlayersCount)}/{use(state.MaxPlayers)} Players`
                        end),
                        TextSize = 16,
                        TextScaled = false,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    
                    -- Status / Countdown
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -16, 0, 28),
                        Position = UDim2.new(0, 8, 0, 76),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            local countdown = use(state.CountdownRemaining)
                            local isLocked = use(state.IsLocked)
                            local playerCount = use(state.PlayersCount)
                            local maxPlayers = use(state.MaxPlayers)
                            
                            if isLocked then
                                return "🔒 LOCKED"
                            elseif countdown and countdown > 0 then
                                return `Teleporting in {math.ceil(countdown)} seconds`
                            elseif playerCount >= maxPlayers then
                                return "🚀 Ready to teleport!"
                            elseif playerCount > 0 then
                                return "Waiting for players..."
                            else
                                return "Step on to join!"
                            end
                        end),
                        TextSize = 14,
                        TextScaled = false,
                        Font = Enum.Font.Gotham,
                        TextColor3 = Computed(scope, function(use)
                            local isLocked = use(state.IsLocked)
                            local countdown = use(state.CountdownRemaining)
                            local playerCount = use(state.PlayersCount)
                            local maxPlayers = use(state.MaxPlayers)
                            
                            if isLocked then
                                return Color3.fromRGB(200, 50, 50)
                            elseif countdown and countdown > 0 then
                                return Color3.fromRGB(255, 200, 50) -- Yellow during countdown
                            elseif playerCount >= maxPlayers then
                                return Color3.fromRGB(50, 255, 150) -- Bright green when ready
                            else
                                return Color3.fromRGB(50, 205, 50)
                            end
                        end),
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                },
            },
        },
    }
end

-- Update pad state from server
local function updatePadState(data: any)
    local padId = data.PadId
    local state = _padStates[padId]
    
    if not state then
        -- Create new state
        local scope = Fusion.scoped(Fusion)
        state = {
            PadId = padId,
            Scope = scope, -- Store scope to prevent GC
            WorldId = Value(scope, data.WorldId),
            Difficulty = Value(scope, data.Difficulty),
            PlayersCount = Value(scope, data.PlayersCount),
            MaxPlayers = Value(scope, data.MaxPlayers),
            CountdownRemaining = Value(scope, data.CountdownRemaining),
            BillboardGui = nil,
        }
        _padStates[padId] = state
        
        -- Find pad model in workspace
        -- PadId format: "Workspace.TeleportPads.Day_Normal"
        local workspace = game:GetService("Workspace")
        local teleportPadsFolder = workspace:FindFirstChild("TeleportPads")
        
        if teleportPadsFolder then
            -- Extract the model name (last part of path)
            local modelName = padId:match("[^.]+$") -- Get last segment
            local padModel = teleportPadsFolder:FindFirstChild(modelName)
            
            if padModel and padModel:IsA("Model") then
                -- Find attachment point
                local attachPart = padModel:FindFirstChild("Billboard")
                if not attachPart or not attachPart:IsA("BasePart") then
                    attachPart = padModel:FindFirstChild("Platform")
                end
                
                if attachPart and attachPart:IsA("BasePart") then
                    local attachPoint = attachPart:FindFirstChildOfClass("Attachment")
                    if not attachPoint then
                        attachPoint = Instance.new("Attachment")
                        attachPoint.Position = Vector3.new(0, 5, 0)
                        attachPoint.Parent = attachPart
                    end
                    
                    -- Create UI
                    local gui = createPadUI(scope, state)
                    gui.Adornee = attachPart
                    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
                    state.BillboardGui = gui
                    
                    Logger.Info("PadUI", `Created UI for pad {modelName}`)
                else
                    Logger.Warn("PadUI", `Could not find Platform for pad {modelName}`)
                end
            else
                Logger.Warn("PadUI", `Could not find pad model: {modelName}`)
            end
        else
            Logger.Warn("PadUI", "TeleportPads folder not found in Workspace")
        end
    else
        -- Update existing state
        print(`[PadUI] Update received: {data.PlayersCount}/{data.MaxPlayers} players`) -- Debug visible
        state.WorldId:set(data.WorldId)
        state.Difficulty:set(data.Difficulty)
        state.PlayersCount:set(data.PlayersCount)
        state.MaxPlayers:set(data.MaxPlayers)
        state.CountdownRemaining:set(data.CountdownRemaining)
        
        -- Also update current pad info if this is the pad we're on
        if Fusion.peek(_isOnPad) and data.PadId == Fusion.peek(_currentPadId) then
            _currentCountdown:set(data.CountdownRemaining)
            _currentPlayerCount:set(data.PlayersCount)
            _currentMaxPlayers:set(data.MaxPlayers)
        end
    end
end

-- Create Leave Button UI (shown when player is on a pad)
local function createLeaveButtonUI(): ScreenGui
    local worldConfig = Computed(_scope, function(use)
        local worldId = use(_currentWorldId)
        return WorldData.GetWorld(worldId)
    end)
    
    local difficultyConfig = Computed(_scope, function(use)
        local difficulty = use(_currentDifficulty)
        return DifficultyData.GetDifficulty(difficulty)
    end)
    
    return New(_scope, "ScreenGui") {
        Name = "PadLeaveUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        
        [Children] = {
            -- Container for Leave UI (centered bottom)
            New(_scope, "Frame") {
                Name = "Container",
                Size = UDim2.new(0, 300, 0, 150),
                Position = UDim2.new(0.5, -150, 1, -180),
                BackgroundColor3 = Color3.fromRGB(139, 90, 43),
                BorderSizePixel = 0,
                Visible = Computed(_scope, function(use)
                    return use(_isOnPad)
                end),
                
                [Children] = {
                    New(_scope, "UICorner") {
                        CornerRadius = UDim.new(0, 16),
                    },
                    
                    New(_scope, "UIStroke") {
                        Color = Color3.fromRGB(101, 67, 33),
                        Thickness = 4,
                    },
                    
                    -- World + Difficulty name
                    New(_scope, "TextLabel") {
                        Size = UDim2.new(1, -20, 0, 40),
                        Position = UDim2.new(0, 10, 0, 10),
                        BackgroundTransparency = 1,
                        Text = Computed(_scope, function(use)
                            local world = use(worldConfig)
                            local diff = use(difficultyConfig)
                            if world and diff then
                                return `🌿 {world.Name} ({diff.Name})`
                            end
                            return "Loading..."
                        end),
                        TextSize = 22,
                        TextScaled = false,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = Color3.fromRGB(255, 215, 0),
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    
                    -- Info text
                    New(_scope, "TextLabel") {
                        Size = UDim2.new(1, -20, 0, 28),
                        Position = UDim2.new(0, 10, 0, 52),
                        BackgroundTransparency = 1,
                        Text = Computed(_scope, function(use)
                            local countdown = use(_currentCountdown)
                            local playerCount = use(_currentPlayerCount)
                            local maxPlayers = use(_currentMaxPlayers)
                            
                            if countdown and countdown > 0 then
                                return `Teleporting in {math.ceil(countdown)} seconds`
                            elseif playerCount >= maxPlayers then
                                return "🚀 Ready to teleport!"
                            else
                                return `Waiting for players... ({playerCount}/{maxPlayers})`
                            end
                        end),
                        TextSize = 16,
                        TextScaled = false,
                        Font = Enum.Font.Gotham,
                        TextColor3 = Computed(_scope, function(use)
                            local countdown = use(_currentCountdown)
                            if countdown and countdown > 0 then
                                return Color3.fromRGB(255, 200, 50) -- Yellow
                            else
                                return Color3.fromRGB(255, 255, 255)
                            end
                        end),
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    
                    -- Leave Button
                    New(_scope, "TextButton") {
                        Name = "LeaveButton",
                        Size = UDim2.new(0, 120, 0, 40),
                        Position = UDim2.new(0.5, -60, 1, -55),
                        BackgroundColor3 = Color3.fromRGB(200, 60, 60),
                        Text = "Leave",
                        TextSize = 18,
                        TextScaled = false,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        
                        [OnEvent "Activated"] = function()
                            Logger.Info("PadUI", "Leave button clicked")
                            ZapClient.LeavePadRequest.Fire({})
                        end,
                        
                        [Children] = {
                            New(_scope, "UICorner") {
                                CornerRadius = UDim.new(0, 8),
                            },
                        },
                    },
                },
            },
        },
    }
end

-- Handle JoinedPad event
local function onJoinedPad(data: any)
    Logger.Info("PadUI", `Joined pad {data.PadId} (World: {data.WorldId}, Difficulty: {data.Difficulty})`)
    _currentPadId:set(data.PadId)
    _currentWorldId:set(data.WorldId)
    _currentDifficulty:set(data.Difficulty)
    _isOnPad:set(true)
end

-- Handle LeftPad event
local function onLeftPad(_data: any)
    Logger.Info("PadUI", "Left pad")
    _isOnPad:set(false)
    _currentPadId:set("")
    _currentWorldId:set("")
    _currentDifficulty:set("")
    _currentCountdown:set(nil)
    _currentPlayerCount:set(0)
    _currentMaxPlayers:set(1)
end

-- Initialize
function PadUIController.Initialize()
    Logger.Info("PadUI", "PadUIController initialized")
    
    -- Listen for pad state updates
    ZapClient.PadStateUpdate.On(updatePadState)
    
    -- Listen for join/leave pad events
    ZapClient.JoinedPad.On(onJoinedPad)
    ZapClient.LeftPad.On(onLeftPad)
    
    -- Create Leave button UI
    _leaveButtonUI = createLeaveButtonUI()
    _leaveButtonUI.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return PadUIController
