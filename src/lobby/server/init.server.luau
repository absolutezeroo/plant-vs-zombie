--!strict
--[[
    Lobby Server Bootstrap
    
    Initializes the Lobby place:
    - Loads player profiles via ProfileStore
    - Handles TeleportService requests to Arena
    - Manages lobby-specific state (no ECS needed here)
]]

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages")

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ErrorHandler = require(Shared.utils.ErrorHandler)
local TeleportData = require(Shared.TeleportData)
local StageData = require(Shared.data.StageData)
local PlantData = require(Shared.data.PlantData)

-- Import services from this folder
local PlayerDataService = require(script.services.PlayerDataService)

-- Initialize services
PlayerDataService.Initialize()
Logger.Info("Lobby", "PlayerDataService initialized")

-- Track players in lobby
local playersInLobby: { [Player]: boolean } = {}

--[[
    Handle teleport request from client
    Validates deck and stage before teleporting
]]
local function handleTeleportToArena(player: Player, stageId: string, deck: { string })
    Logger.Info("Lobby", `{player.Name} requesting teleport to {stageId}`)
    
    -- Validate stage exists
    local stage = StageData.GetStage(stageId)
    if not stage then
        Logger.Warn("Lobby", `Invalid stage: {stageId}`)
        -- TODO: Send error response to client via Zap
        return
    end
    
    -- Validate deck
    if #deck < 1 or #deck > 6 then
        Logger.Warn("Lobby", `Invalid deck size: {#deck}`)
        return
    end
    
    -- Validate player owns all plants in deck
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        Logger.Warn("Lobby", `No profile for {player.Name}`)
        return
    end
    
    local unlockedPlants = profile.Data.PlantMastery
    for _, plantType in deck do
        if not PlantData[plantType] then
            Logger.Warn("Lobby", `Invalid plant type: {plantType}`)
            return
        end
        
        -- Check if plant is unlocked (starter plants always available)
        local plantInfo = PlantData[plantType]
        if plantInfo.Tier > 0 then -- Non-starter
            if not unlockedPlants[plantType] then
                Logger.Warn("Lobby", `{player.Name} doesn't own {plantType}`)
                return
            end
        end
    end
    
    -- Create teleport data
    local teleportOptions = Instance.new("TeleportOptions")
    local arenaData = TeleportData.CreateArenaJoinData(stageId, deck)
    teleportOptions:SetTeleportData(arenaData)
    
    -- Teleport to Arena
    local success, err = pcall(function()
        TeleportService:TeleportAsync(
            TeleportData.PlaceIds.Arena,
            { player },
            teleportOptions
        )
    end)
    
    if not success then
        Logger.Error("Lobby", `Teleport failed: {err}`)
        -- TODO: Send error response to client
    end
end

--[[
    Handle player joining Lobby
    Could be fresh join or return from Arena
]]
local function onPlayerAdded(player: Player)
    Logger.Info("Lobby", `{player.Name} joined lobby`)
    playersInLobby[player] = true
    
    -- Check if returning from Arena with results
    local teleportData = player:GetJoinData().TeleportData
    if teleportData then
        local isValid, err = TeleportData.ValidateLobbyReturnData(teleportData)
        if isValid then
            Logger.Info("Lobby", `{player.Name} returned from Arena`, {
                stageId = teleportData.StageId,
                victory = teleportData.Victory,
                stars = teleportData.Stars,
            })
            -- Results already saved by Arena server before teleport
            -- Client will show results UI based on this data
        else
            Logger.Warn("Lobby", `Invalid return data: {err}`)
        end
    end
end

local function onPlayerRemoving(player: Player)
    Logger.Info("Lobby", `{player.Name} leaving lobby`)
    playersInLobby[player] = nil
end

-- Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game (Studio testing)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end

-- Setup network event handlers (Zap generated)
-- TODO: Connect Zap events after adding TeleportToArena to packets.zap
-- ZapServer.TeleportToArenaRequest:SetCallback(function(player, data)
--     handleTeleportToArena(player, data.StageId, data.Deck)
-- end)

Logger.Info("Lobby", "Lobby server initialized")
