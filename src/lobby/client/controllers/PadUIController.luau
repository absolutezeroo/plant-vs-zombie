--!strict
--[[
    PadUIController.luau - Manages BillboardGui on teleport pads
    
    Responsibilities:
    - Create/update BillboardGui for each pad
    - Listen for PadStateUpdate from server
    - Display: Stage info, X/Y players, countdown, status
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local StageData = require(Shared.data.StageData)

-- Import Zap (navigate from controllers/ to client/ then to network/)
local LobbyClient = script.Parent.Parent
local ZapClient = require(LobbyClient:WaitForChild("network"):WaitForChild("generated"))

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value

-- Pad state tracking
type PadUIState = {
    PadId: string,
    StageId: Fusion.Value<string>,
    PlayersCount: Fusion.Value<number>,
    MaxPlayers: Fusion.Value<number>,
    CountdownRemaining: Fusion.Value<number?>,
    IsLocked: Fusion.Value<boolean>,
    BillboardGui: BillboardGui?,
}

local _padStates: {[string]: PadUIState} = {}

local PadUIController = {}

-- Create BillboardGui for a pad
local function createPadUI(scope, state: PadUIState): BillboardGui
    local stageConfig = StageData.GetStage(Fusion.peek(state.StageId))
    local stageName = if stageConfig then stageConfig.Name else state.StageId
    
    return New(scope, "BillboardGui") {
        Name = "PadUI",
        Size = UDim2.new(6, 0, 3, 0),
        StudsOffset = Vector3.new(0, 5, 0),
        AlwaysOnTop = true,
        
        [Children] = {
            -- Background frame
            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.fromRGB(139, 90, 43), -- Wood brown
                BorderSizePixel = 0,
                
                [Children] = {
                    New(scope, "UICorner") {
                        CornerRadius = UDim.new(0, 16),
                    },
                    
                    New(scope, "UIStroke") {
                        Color = Color3.fromRGB(101, 67, 33),
                        Thickness = 4,
                    },
                    
                    -- Stage name
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -20, 0, 40),
                        Position = UDim2.new(0, 10, 0, 10),
                        BackgroundTransparency = 1,
                        Text = stageName,
                        TextSize = 24,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = Color3.fromRGB(255, 215, 0), -- Gold
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    
                    -- Player count
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -20, 0, 30),
                        Position = UDim2.new(0, 10, 0, 55),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            return `{use(state.PlayersCount)}/{use(state.MaxPlayers)} Players`
                        end),
                        TextSize = 20,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    
                    -- Status / Countdown
                    New(scope, "TextLabel") {
                        Size = UDim2.new(1, -20, 0, 30),
                        Position = UDim2.new(0, 10, 0, 90),
                        BackgroundTransparency = 1,
                        Text = Computed(scope, function(use)
                            local countdown = use(state.CountdownRemaining)
                            local isLocked = use(state.IsLocked)
                            
                            if isLocked then
                                return "🔒 LOCKED"
                            elseif countdown and countdown > 0 then
                                return `Starting in {math.ceil(countdown)}...`
                            else
                                return "Step on to join!"
                            end
                        end),
                        TextSize = 18,
                        Font = Enum.Font.Gotham,
                        TextColor3 = Computed(scope, function(use)
                            local isLocked = use(state.IsLocked)
                            return if isLocked 
                                then Color3.fromRGB(200, 50, 50) 
                                else Color3.fromRGB(50, 205, 50)
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
            StageId = Value(scope, data.StageId),
            PlayersCount = Value(scope, data.PlayersCount),
            MaxPlayers = Value(scope, data.MaxPlayers),
            CountdownRemaining = Value(scope, data.CountdownRemaining),
            IsLocked = Value(scope, data.IsLocked),
            BillboardGui = nil,
        }
        _padStates[padId] = state
        
        -- Find pad model in workspace
        local workspace = game:GetService("Workspace")
        local padModel = workspace:FindFirstChild(padId:match("[^.]+$"), true) -- Get last part of path
        
        if padModel and padModel:IsA("Model") then
            -- Find attachment point
            local attachment = padModel:FindFirstChild("Billboard", true)
            if not attachment or not attachment:IsA("BasePart") then
                attachment = padModel:FindFirstChild("Platform")
            end
            
            if attachment then
                local attachPoint = attachment:FindFirstChildOfClass("Attachment")
                if not attachPoint then
                    attachPoint = Instance.new("Attachment")
                    attachPoint.Position = Vector3.new(0, 5, 0)
                    attachPoint.Parent = attachment
                end
                
                -- Create UI
                local gui = createPadUI(scope, state)
                gui.Adornee = attachment
                gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
                state.BillboardGui = gui
                
                Logger.Info("PadUI", `Created UI for pad {padId}`)
            end
        else
            Logger.Warn("PadUI", `Could not find pad model for {padId}`)
        end
    else
        -- Update existing state
        state.StageId:set(data.StageId)
        state.PlayersCount:set(data.PlayersCount)
        state.MaxPlayers:set(data.MaxPlayers)
        state.CountdownRemaining:set(data.CountdownRemaining)
        state.IsLocked:set(data.IsLocked)
    end
end

-- Initialize
function PadUIController.Initialize()
    Logger.Info("PadUI", "PadUIController initialized")
    
    -- Listen for pad state updates
    ZapClient.PadStateUpdate.On(updatePadState)
end

return PadUIController
