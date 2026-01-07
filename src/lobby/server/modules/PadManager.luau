--!strict
--[[
    PadManager.luau - Manages individual teleport pad configuration and state
    
    Reads Configuration from pad Models in workspace:
    Structure attendue:
    Workspace/
    └── TeleportPads/
        └── Stage_1-1/              -- Model (any name)
            ├── Platform (Part)     -- Touch detection part
            ├── Billboard (Part?)   -- Attachment point for UI
            └── Configuration/
                ├── StageId (StringValue)
                ├── MinPlayers (IntValue, optional)
                └── MaxPlayers (IntValue, optional)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local StageData = require(Shared.data.StageData)

-- Import lobby config (now in Shared.config)
local LobbyConfig = require(Shared.config.LobbyConfig)

export type PadConfig = {
    Model: Model,
    Platform: BasePart,
    BillboardAttachment: Attachment?,
    StageId: string,
    MinPlayers: number,
    MaxPlayers: number,
    CountdownDuration: number,
    IsValid: boolean,
}

local PadManager = {}

-- Read configuration from a pad Model
function PadManager.ReadPadConfig(padModel: Model): PadConfig?
    local config: PadConfig = {
        Model = padModel,
        Platform = nil :: any,
        BillboardAttachment = nil,
        StageId = "",
        MinPlayers = LobbyConfig.DEFAULT_MIN_PLAYERS,
        MaxPlayers = LobbyConfig.DEFAULT_MAX_PLAYERS,
        CountdownDuration = LobbyConfig.COUNTDOWN_DURATION,
        IsValid = false,
    }
    
    -- Find Platform part
    local platform = padModel:FindFirstChild("Platform")
    if not platform or not platform:IsA("BasePart") then
        Logger.Warn("PadManager", `Pad {padModel.Name} missing Platform part`)
        return nil
    end
    config.Platform = platform
    
    -- Find optional Billboard attachment point
    local billboardPart = padModel:FindFirstChild("Billboard")
    if billboardPart and billboardPart:IsA("BasePart") then
        local attachment = billboardPart:FindFirstChildOfClass("Attachment")
        if not attachment then
            attachment = Instance.new("Attachment")
            attachment.Parent = billboardPart
        end
        config.BillboardAttachment = attachment
    else
        -- Create attachment on platform if no Billboard part
        local attachment = platform:FindFirstChildOfClass("Attachment")
        if not attachment then
            attachment = Instance.new("Attachment")
            attachment.Position = Vector3.new(0, 5, 0) -- 5 studs above platform
            attachment.Parent = platform
        end
        config.BillboardAttachment = attachment
    end
    
    -- Read Configuration folder
    local configFolder = padModel:FindFirstChild("Configuration")
    if not configFolder then
        Logger.Warn("PadManager", `Pad {padModel.Name} missing Configuration folder`)
        return nil
    end
    
    -- Read StageId (required)
    local stageIdValue = configFolder:FindFirstChild("StageId")
    if not stageIdValue or not stageIdValue:IsA("StringValue") then
        Logger.Warn("PadManager", `Pad {padModel.Name} missing StageId StringValue`)
        return nil
    end
    config.StageId = stageIdValue.Value
    
    -- Validate stage exists
    local stageConfig = StageData.GetStage(config.StageId)
    if not stageConfig then
        Logger.Warn("PadManager", `Pad {padModel.Name} has invalid StageId: {config.StageId}`)
        return nil
    end
    
    -- Read MinPlayers (optional)
    local minPlayersValue = configFolder:FindFirstChild("MinPlayers")
    if minPlayersValue and minPlayersValue:IsA("IntValue") then
        config.MinPlayers = math.max(1, minPlayersValue.Value)
    end
    
    -- Read MaxPlayers (optional)
    local maxPlayersValue = configFolder:FindFirstChild("MaxPlayers")
    if maxPlayersValue and maxPlayersValue:IsA("IntValue") then
        config.MaxPlayers = math.max(config.MinPlayers, maxPlayersValue.Value)
    end
    
    -- Read CountdownDuration (optional)
    local countdownValue = configFolder:FindFirstChild("CountdownDuration")
    if countdownValue and countdownValue:IsA("IntValue") then
        config.CountdownDuration = math.max(1, countdownValue.Value)
    end
    
    config.IsValid = true
    
    Logger.Info("PadManager", `Loaded pad: {padModel.Name}`, {
        stageId = config.StageId,
        minPlayers = config.MinPlayers,
        maxPlayers = config.MaxPlayers,
        countdownDuration = config.CountdownDuration,
    })
    
    return config
end

-- Get pad ID (unique identifier)
function PadManager.GetPadId(padModel: Model): string
    return padModel:GetFullName()
end

return PadManager
