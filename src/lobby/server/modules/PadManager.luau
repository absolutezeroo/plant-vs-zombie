--!strict
--[[
    PadManager.luau - Manages individual teleport pad configuration and state
    
    Reads Configuration from pad Models in workspace:
    Structure attendue:
    Workspace/
    └── TeleportPads/
        └── Day_Normal/             -- Model (any name)
            ├── Platform (Part)     -- Touch detection part
            ├── Billboard (Part?)   -- Attachment point for UI
            └── Configuration/
                ├── WorldId (StringValue)        -- Required: "day", "night", "pool", etc.
                ├── Difficulty (StringValue)     -- Required: "easy", "normal", "hard", etc.
                ├── MinPlayers (IntValue, optional)
                └── MaxPlayers (IntValue, optional)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local WorldData = require(Shared.data.WorldData)
local DifficultyData = require(Shared.data.DifficultyData)

-- Import lobby config (now in Shared.config)
local LobbyConfig = require(Shared.config.LobbyConfig)

export type PadConfig = {
	Model: Model,
	TriggerPart: BasePart, -- Gate part (touch detection to enter)
	Platform: BasePart, -- Platform in Zone (where player is teleported)
	SpawnPosition: Vector3, -- Position to teleport player to
	BillboardAttachment: Attachment?,
	WorldId: string,
	Difficulty: string,
	WorldConfig: WorldData.WorldConfig?,
	DifficultyConfig: DifficultyData.DifficultyConfig?,
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
		TriggerPart = nil :: any,
		Platform = nil :: any,
		SpawnPosition = Vector3.zero,
		BillboardAttachment = nil,
		WorldId = "",
		Difficulty = "normal",
		WorldConfig = nil,
		DifficultyConfig = nil,
		MinPlayers = LobbyConfig.DEFAULT_MIN_PLAYERS,
		MaxPlayers = LobbyConfig.DEFAULT_MAX_PLAYERS,
		CountdownDuration = LobbyConfig.COUNTDOWN_DURATION,
		IsValid = false,
	}

	-- Find Gate part (trigger for entering) - look for "Gate" Part inside Gate/Gate2/Gate3 model
	local gateModel = padModel:FindFirstChild("Gate", true)
	if gateModel and gateModel:IsA("Model") then
		local gatePart = gateModel:FindFirstChild("Gate")
		if gatePart and gatePart:IsA("BasePart") then
			config.TriggerPart = gatePart
		end
	elseif gateModel and gateModel:IsA("BasePart") then
		config.TriggerPart = gateModel
	end

	if not config.TriggerPart then
		Logger.Warn("PadManager", `Pad {padModel.Name} missing Gate trigger part`)
		return nil
	end

	-- Find Platform part in Zone (where player is teleported)
	local platform = padModel:FindFirstChild("Platform", true)
	if not platform or not platform:IsA("BasePart") then
		Logger.Warn("PadManager", `Pad {padModel.Name} missing Platform part`)
		return nil
	end
	config.Platform = platform

	-- Find Spawn position (where to teleport player in the zone)
	local spawnPart = padModel:FindFirstChild("Spawn", true) or padModel:FindFirstChild("spawn", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		config.SpawnPosition = spawnPart.Position + Vector3.new(0, 3, 0)
	else
		-- Use platform center as fallback
		config.SpawnPosition = platform.Position + Vector3.new(0, 3, 0)
	end

	-- Find optional Billboard attachment point (search recursively)
	local billboardPart = padModel:FindFirstChild("Billboard", true)
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

	-- Read WorldId (required)
	local worldIdValue = configFolder:FindFirstChild("WorldId")
	if not worldIdValue or not worldIdValue:IsA("StringValue") then
		Logger.Warn("PadManager", `Pad {padModel.Name} missing WorldId StringValue`)
		return nil
	end
	config.WorldId = worldIdValue.Value

	-- Read Difficulty (required)
	local difficultyValue = configFolder:FindFirstChild("Difficulty")
	if not difficultyValue or not difficultyValue:IsA("StringValue") then
		Logger.Warn("PadManager", `Pad {padModel.Name} missing Difficulty StringValue`)
		return nil
	end
	config.Difficulty = difficultyValue.Value

	-- Validate world exists using WorldData (data-driven)
	local worldConfig = WorldData.GetWorld(config.WorldId)
	if not worldConfig then
		Logger.Warn("PadManager", `Pad {padModel.Name} has invalid WorldId: {config.WorldId}`)
		return nil
	end
	config.WorldConfig = worldConfig

	-- Validate difficulty exists using DifficultyData (data-driven)
	local difficultyConfig = DifficultyData.GetDifficulty(config.Difficulty)
	if not difficultyConfig then
		Logger.Warn("PadManager", `Pad {padModel.Name} has invalid Difficulty: {config.Difficulty}`)
		return nil
	end
	config.DifficultyConfig = difficultyConfig

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
		worldId = config.WorldId,
		difficulty = config.Difficulty,
		minPlayers = config.MinPlayers,
		maxPlayers = config.MaxPlayers,
		countdownDuration = config.CountdownDuration,
	})

	return config
end

-- Get pad ID (unique identifier - just the model name)
function PadManager.GetPadId(padModel: Model): string
	return padModel.Name
end

return PadManager
