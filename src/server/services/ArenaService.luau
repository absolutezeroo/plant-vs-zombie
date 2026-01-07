--!strict
--[[
    ArenaService.luau - Manages Arena battle lifecycle
    
    Handles:
    - Starting battles from TeleportData (Lobby → Arena)
    - Setting up stage and deck
    - Returning to Lobby with results
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local StageData = require(Shared.data.StageData)
local TeleportData = require(Shared.TeleportData)

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
    local stageConfig = StageData.GetStage(stageId)
    if not stageConfig then
        Logger.Error("ArenaService", `Invalid stage: {stageId}`)
        return false
    end
    
    -- Track active battle
    _activeBattles[player] = {
        StageId = stageId,
        Deck = deck,
    }
    
    -- Get WaveManager from WaveManagerSystem
    local WaveManagerSystemModule = require(script.Parent.Parent.systems.wave.WaveManagerSystem)
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
