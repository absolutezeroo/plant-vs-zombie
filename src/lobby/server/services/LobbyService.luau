--!strict
--[[
    LobbyService.luau - Manages teleport pads, queues, and countdowns
    
    Responsibilities:
    - Scan workspace for TeleportPad Models
    - Track players on each pad (queue management)
    - Handle countdown logic (start/cancel/complete)
    - Teleport groups when ready
    - Broadcast pad state updates to clients
]]

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local TeleportData = require(Shared.TeleportData)
local _StageData = require(Shared.data.StageData) -- Reserved for future use

-- Import modules
local PadManager = require(script.Parent.Parent.modules.PadManager)
local PlayerDataService = require(script.Parent.PlayerDataService)

-- Import config (now in Shared.config)
local LobbyConfig = require(Shared.config.LobbyConfig)

export type PadState = {
    Config: PadManager.PadConfig,
    PlayersInQueue: {Player},
    CountdownActive: boolean,
    CountdownRemaining: number,
    LastTouchTime: {[Player]: number}, -- Track AFK
}

local LobbyService = {}

-- State tracking
local _pads: {[Model]: PadState} = {}
local _playerCurrentPad: {[Player]: Model?} = {}
local _initialized = false

-- Network (set after Initialize)
local ZapServer: any = nil

-- Helper: Get player's current deck from profile
local function getPlayerDeck(player: Player): {string}?
    local profile = PlayerDataService.GetProfile(player)
    if not profile then return nil end
    
    -- Use Deck if set, otherwise default starter deck
    local deck = profile.Data.Deck
    if not deck or #deck == 0 then
        deck = {"Sunflower", "Peashooter", "WallNut"} -- Default deck
    end
    
    return deck
end

-- Helper: Check if player can join pad (stage unlocked)
local function canPlayerJoinPad(player: Player, stageId: string): (boolean, string?)
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    -- Check if stage is unlocked
    -- For now, allow all stages (TODO: implement progression)
    return true, nil
end

-- Add player to pad queue
function LobbyService.PlayerJoinedPad(player: Player, padModel: Model)
    local padState = _pads[padModel]
    if not padState then
        Logger.Warn("LobbyService", `Unknown pad: {padModel.Name}`)
        return
    end
    
    -- Check if player can join
    local canJoin, reason = canPlayerJoinPad(player, padState.Config.StageId)
    if not canJoin then
        Logger.Warn("LobbyService", `{player.Name} cannot join pad: {reason}`)
        -- TODO: Send error to client
        return
    end
    
    -- Remove from previous pad if any
    local previousPad = _playerCurrentPad[player]
    if previousPad then
        LobbyService.PlayerLeftPad(player, previousPad)
    end
    
    -- Add to queue
    if not table.find(padState.PlayersInQueue, player) then
        table.insert(padState.PlayersInQueue, player)
        _playerCurrentPad[player] = padModel
        padState.LastTouchTime[player] = os.clock()
        
        Logger.Info("LobbyService", `{player.Name} joined pad {padModel.Name}`, {
            queueSize = #padState.PlayersInQueue,
        })
        
        -- Check if should start countdown
        LobbyService._UpdateCountdown(padState)
        LobbyService._BroadcastPadState(padState)
    end
end

-- Remove player from pad queue
function LobbyService.PlayerLeftPad(player: Player, padModel: Model)
    local padState = _pads[padModel]
    if not padState then return end
    
    local index = table.find(padState.PlayersInQueue, player)
    if index then
        table.remove(padState.PlayersInQueue, index)
        padState.LastTouchTime[player] = nil
        _playerCurrentPad[player] = nil
        
        Logger.Info("LobbyService", `{player.Name} left pad {padModel.Name}`, {
            queueSize = #padState.PlayersInQueue,
        })
        
        -- Re-evaluate countdown
        LobbyService._UpdateCountdown(padState)
        LobbyService._BroadcastPadState(padState)
    end
end

-- Update countdown logic for a pad
function LobbyService._UpdateCountdown(padState: PadState)
    local queueSize = #padState.PlayersInQueue
    local config = padState.Config
    
    -- Instant teleport if max players reached
    if queueSize >= config.MaxPlayers then
        Logger.Info("LobbyService", `Max players reached on {config.Model.Name}, instant teleport`)
        LobbyService._TeleportGroup(padState)
        return
    end
    
    -- Start countdown if min players met
    if queueSize >= config.MinPlayers and not padState.CountdownActive then
        padState.CountdownActive = true
        padState.CountdownRemaining = LobbyConfig.COUNTDOWN_DURATION
        Logger.Info("LobbyService", `Countdown started on {config.Model.Name}`)
    end
    
    -- Cancel countdown if below min players
    if queueSize < config.MinPlayers and padState.CountdownActive then
        padState.CountdownActive = false
        padState.CountdownRemaining = 0
        Logger.Info("LobbyService", `Countdown cancelled on {config.Model.Name}`)
    end
end

-- Teleport all players in pad queue
function LobbyService._TeleportGroup(padState: PadState)
    local players = padState.PlayersInQueue
    if #players == 0 then return end
    
    local config = padState.Config
    Logger.Info("LobbyService", `Teleporting {#players} players from {config.Model.Name}`)
    
    -- Get each player's deck
    for _, player in players do
        local deck = getPlayerDeck(player)
        if not deck then
            Logger.Warn("LobbyService", `{player.Name} has no deck, skipping teleport`)
            continue
        end
        
        -- Create teleport data
        local teleportOptions = Instance.new("TeleportOptions")
        local arenaData = TeleportData.CreateArenaJoinData(config.StageId, deck)
        teleportOptions:SetTeleportData(arenaData)
        
        -- Teleport
        local success, err = pcall(function()
            TeleportService:TeleportAsync(
                TeleportData.PlaceIds.Arena,
                {player},
                teleportOptions
            )
        end)
        
        if not success then
            Logger.Error("LobbyService", `Teleport failed for {player.Name}: {err}`)
        end
    end
    
    -- Clear queue
    padState.PlayersInQueue = {}
    padState.LastTouchTime = {}
    padState.CountdownActive = false
    padState.CountdownRemaining = 0
    
    LobbyService._BroadcastPadState(padState)
end

-- Broadcast pad state to all clients
function LobbyService._BroadcastPadState(padState: PadState)
    if not ZapServer then return end
    
    local config = padState.Config
    local padId = PadManager.GetPadId(config.Model)
    
    -- Send to all players
    ZapServer.PadStateUpdate.FireAll({
        PadId = padId,
        StageId = config.StageId,
        PlayersCount = #padState.PlayersInQueue,
        MaxPlayers = config.MaxPlayers,
        CountdownRemaining = if padState.CountdownActive then padState.CountdownRemaining else nil,
        IsLocked = false, -- TODO: Check stage unlock status
    })
end

-- Heartbeat: Update countdowns and check for teleports
local function onHeartbeat(dt: number)
    for padModel, padState in _pads do
        if padState.CountdownActive then
            padState.CountdownRemaining -= dt
            
            if padState.CountdownRemaining <= 0 then
                -- Countdown complete, teleport!
                LobbyService._TeleportGroup(padState)
            end
        end
        
        -- Check AFK players
        for player, lastTouch in padState.LastTouchTime do
            if os.clock() - lastTouch > LobbyConfig.AFK_TIMEOUT then
                Logger.Warn("LobbyService", `{player.Name} AFK on pad, removing`)
                LobbyService.PlayerLeftPad(player, padModel)
            end
        end
    end
end

-- Scan workspace for TeleportPad Models
local function scanForPads()
    local workspace = game:GetService("Workspace")
    local teleportPadsFolder = workspace:FindFirstChild("TeleportPads")
    
    if not teleportPadsFolder then
        Logger.Warn("LobbyService", "No TeleportPads folder found in Workspace")
        return
    end
    
    for _, child in teleportPadsFolder:GetChildren() do
        if child:IsA("Model") then
            local config = PadManager.ReadPadConfig(child)
            if config and config.IsValid then
                _pads[child] = {
                    Config = config,
                    PlayersInQueue = {},
                    CountdownActive = false,
                    CountdownRemaining = 0,
                    LastTouchTime = {},
                }
                
                -- Setup touch detection
                config.Platform.Touched:Connect(function(hit)
                    local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        local player = Players:GetPlayerFromCharacter(hit.Parent)
                        if player then
                            LobbyService.PlayerJoinedPad(player, child)
                        end
                    end
                end)
                
                config.Platform.TouchEnded:Connect(function(hit)
                    local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        local player = Players:GetPlayerFromCharacter(hit.Parent)
                        if player then
                            LobbyService.PlayerLeftPad(player, child)
                        end
                    end
                end)
            end
        end
    end
    
    -- Count pads (can't use # on dictionary)
    local padCount = 0
    for _ in _pads do
        padCount += 1
    end
    Logger.Info("LobbyService", `Loaded {padCount} teleport pads`)
end

-- Initialize service
function LobbyService.Initialize(zapServer: any)
    if _initialized then
        Logger.Warn("LobbyService", "Already initialized")
        return
    end
    
    ZapServer = zapServer
    
    -- Scan for pads
    scanForPads()
    
    -- Start heartbeat
    RunService.Heartbeat:Connect(onHeartbeat)
    
    -- Handle player leaving
    Players.PlayerRemoving:Connect(function(player)
        local padModel = _playerCurrentPad[player]
        if padModel then
            LobbyService.PlayerLeftPad(player, padModel)
        end
    end)
    
    _initialized = true
    Logger.Info("LobbyService", "Lobby service initialized")
end

-- Get pad state (for debugging)
function LobbyService.GetPadState(padModel: Model): PadState?
    return _pads[padModel]
end

return LobbyService
