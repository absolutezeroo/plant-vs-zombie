--!strict
--[[
    ArenaService.luau - Manages Arena battle lifecycle
    
    Handles:
    - Starting battles from TeleportData (Lobby → Arena)
    - Loading the correct map for each stage
    - Setting up stage and deck
    - Returning to Lobby with results
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local _Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local MapConfig = require(Shared.config.MapConfig)
local _TeleportData = require(Shared.data.TeleportData)

-- Check if running in Studio (skip preload to avoid yield issues)
local IS_STUDIO = RunService:IsStudio()

-- Services
local MapLoader = require(script.Parent.MapLoader)

-- Stage loading: Try new StageRegistry first, fallback to old StageData
local StageRegistry: any = nil
local StageData: any = nil

local function getStageConfig(stageId: string): any
    -- Try new system first
    if not StageRegistry then
        local success, registry = pcall(function()
            return require(Shared.data.stages.StageRegistry)
        end)
        if success then
            StageRegistry = registry
        end
    end
    
    if StageRegistry then
        local config = StageRegistry.GetStage(stageId)
        if config then
            return config
        end
    end
    
    -- Fallback to old StageData
    if not StageData then
        StageData = require(Shared.data.StageData)
    end
    return StageData.GetStage(stageId)
end

local ArenaService = {}

-- Track which players have started battles
local _activeBattles: { [Player]: {StageId: string, Deck: {string}} } = {}

-- Get battle data for a player
function ArenaService.GetBattleData(player: Player): {StageId: string, Deck: {string}}?
    return _activeBattles[player]
end

-- Start a battle for a player
function ArenaService.StartBattle(player: Player, stageId: string, deck: {string}): boolean
    Logger.Info("ArenaService", `Starting battle for {player.Name}: stage={stageId}, deck={#deck}`)
    
    -- Validate stage
    local stageConfig = getStageConfig(stageId)
    if not stageConfig then
        Logger.Error("ArenaService", `Invalid stage: {stageId}`)
        return false
    end
    
    -- Load the map for this stage
    -- In Studio: use LoadMap (no preload) to avoid yield issues
    -- In Production: use LoadMapWithPreload for smooth loading
    local mapId = stageConfig.MapId
    if mapId then
        local mapLoaded: boolean
        if IS_STUDIO then
            Logger.Info("ArenaService", `[Studio] Loading map without preload: {mapId}`)
            mapLoaded = MapLoader.LoadMap(mapId)
        else
            Logger.Info("ArenaService", `Loading map with preload: {mapId}`)
            mapLoaded = MapLoader.LoadMapWithPreload(mapId, player)
        end
        
        if not mapLoaded then
            -- Try to use existing ArenaMap in workspace
            Logger.Warn("ArenaService", `Map {mapId} not found, using existing ArenaMap`)
            MapConfig.Reload()
        end
    else
        -- No MapId specified, use existing map or reload config
        Logger.Info("ArenaService", "No MapId specified, using default map")
        MapConfig.Reload()
    end
    
    -- Track active battle
    _activeBattles[player] = {
        StageId = stageId,
        Deck = deck,
    }
    
    -- Lazy load WaveManager to avoid circular dependency
    local WaveManagerSystemModule = require(script.Parent.Parent.systems.wave.WaveManagerSystem) :: any
    local WaveManager = WaveManagerSystemModule.WaveManager
    
    -- Reset game state before starting new battle
    WaveManager.ResetGameState()
    
    -- Start the stage
    local success = WaveManager.StartStage(stageId)
    
    if not success then
        Logger.Error("ArenaService", `Failed to start stage {stageId}`)
        _activeBattles[player] = nil
        return false
    end
    
    Logger.Info("ArenaService", `Battle started: {stageConfig.Name}`)
    return true
end

-- End battle and prepare return data
function ArenaService.EndBattle(player: Player, victory: boolean, stars: number, coins: number, xp: number)
    local battleData = _activeBattles[player]
    if not battleData then
        Logger.Warn("ArenaService", `No active battle for {player.Name}`)
        return
    end
    
    Logger.Info("ArenaService", `Battle ended for {player.Name}: victory={victory}, stars={stars}`)
    
    -- Use the global function set by init.server.luau
    local sendToLobby = _G.ArenaSendPlayerToLobby
    if sendToLobby then
        sendToLobby(player, victory, stars, coins, xp)
    else
        Logger.Error("ArenaService", "ArenaSendPlayerToLobby not available")
    end
    
    _activeBattles[player] = nil
end

-- Clean up when player leaves
function ArenaService.OnPlayerRemoving(player: Player)
    _activeBattles[player] = nil
end

return ArenaService
