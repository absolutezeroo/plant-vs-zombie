--!strict
--[[
    GameStateManager.luau - Manages game state transitions
    
    Single Responsibility: Track and manage game states
    (Waiting, Preparation, Playing, Intermission, Victory, Defeat)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Game state type
export type GameState = "Waiting" | "Preparation" | "Playing" | "Intermission" | "Victory" | "Defeat"

-- State change callback
export type StateChangeCallback = (newState: GameState, previousState: GameState) -> ()

export type GameStateManager = {
    GetState: (self: GameStateManager) -> GameState,
    SetState: (self: GameStateManager, state: GameState) -> boolean,
    IsPlaying: (self: GameStateManager) -> boolean,
    IsGameOver: (self: GameStateManager) -> boolean,
    CanStartGame: (self: GameStateManager) -> boolean,
    Reset: (self: GameStateManager) -> (),
    OnStateChange: (self: GameStateManager, callback: StateChangeCallback) -> (),
}

local GameStateManager = {}
GameStateManager.__index = GameStateManager

-- State
local _currentState: GameState = "Waiting"
local _stateChangeCallbacks: {StateChangeCallback} = {}

function GameStateManager.new(): GameStateManager
    local self = setmetatable({}, GameStateManager)
    return self :: any
end

-- Get current state
function GameStateManager:GetState(): GameState
    return _currentState
end

-- Set new state with validation
function GameStateManager:SetState(newState: GameState): boolean
    if newState == _currentState then
        return false
    end
    
    -- Validate state transitions
    local validTransitions: {[GameState]: {GameState}} = {
        Waiting = {"Preparation", "Playing"},
        Preparation = {"Playing", "Waiting"},
        Playing = {"Intermission", "Victory", "Defeat"},
        Intermission = {"Playing", "Victory", "Defeat"},
        Victory = {"Waiting"},
        Defeat = {"Waiting"},
    }
    
    local allowedTransitions = validTransitions[_currentState]
    local isValid = false
    for _, allowed in ipairs(allowedTransitions) do
        if allowed == newState then
            isValid = true
            break
        end
    end
    
    if not isValid then
        Logger.Warn("GameStateManager", `Invalid transition: {_currentState} -> {newState}`)
        return false
    end
    
    local previousState = _currentState
    _currentState = newState
    
    Logger.Info("GameStateManager", `State changed: {previousState} -> {newState}`)
    
    -- Notify callbacks
    for _, callback in ipairs(_stateChangeCallbacks) do
        task.spawn(callback, newState, previousState)
    end
    
    return true
end

-- Check if game is actively playing
function GameStateManager:IsPlaying(): boolean
    return _currentState == "Playing" or _currentState == "Intermission"
end

-- Check if game is over
function GameStateManager:IsGameOver(): boolean
    return _currentState == "Victory" or _currentState == "Defeat"
end

-- Check if can start a new game
function GameStateManager:CanStartGame(): boolean
    return _currentState == "Waiting"
end

-- Reset to initial state
function GameStateManager:Reset()
    _currentState = "Waiting"
    Logger.Info("GameStateManager", "State reset to Waiting")
end

-- Register state change callback
function GameStateManager:OnStateChange(callback: StateChangeCallback)
    table.insert(_stateChangeCallbacks, callback)
end

-- Singleton instance
local _instance: GameStateManager? = nil

function GameStateManager.GetInstance(): GameStateManager
    if not _instance then
        _instance = GameStateManager.new()
    end
    return _instance :: any
end

return GameStateManager
