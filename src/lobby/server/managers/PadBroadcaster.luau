--!strict
--[[
    PadBroadcaster.luau - Handles network broadcasting for pad state
    
    Single Responsibility: Send pad state updates to clients via Zap
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Zap generated module
local ZapServer = require(script.Parent.Parent.network.generated)

-- Dependencies
local PadManager = require(script.Parent.Parent.modules.PadManager)
local PadQueueManager = require(script.Parent.PadQueueManager)
local CountdownManager = require(script.Parent.CountdownManager)

export type PadStatePayload = {
    PadId: string,
    WorldId: string,
    Difficulty: string,
    PlayersCount: number,
    MaxPlayers: number,
    CountdownRemaining: number?,
    PlayerNames: string?,
}

export type PadBroadcaster = {
    BroadcastPadState: (self: PadBroadcaster, padId: string, config: PadManager.PadConfig) -> (),
    NotifyPlayerJoined: (self: PadBroadcaster, player: Player, padId: string, worldId: string, difficulty: string, position: Vector3) -> (),
    NotifyPlayerLeft: (self: PadBroadcaster, player: Player) -> (),
}

local PadBroadcaster = {}
PadBroadcaster.__index = PadBroadcaster

function PadBroadcaster.new(): PadBroadcaster
    local self = setmetatable({}, PadBroadcaster)
    return self
end

-- Get player names from player list as comma-separated string
local function getPlayerNames(players: {Player}): string?
    if #players == 0 then
        return nil
    end
    local names = {}
    for _, player in ipairs(players) do
        table.insert(names, player.Name)
    end
    return table.concat(names, ", ")
end

-- Broadcast full pad state to all clients
function PadBroadcaster:BroadcastPadState(padId: string, config: PadManager.PadConfig)
    local queueManager = PadQueueManager.GetInstance()
    local countdownManager = CountdownManager.GetInstance()
    
    local players = queueManager:GetPlayersOnPad(padId)
    local playerCount = #players
    local countdownRemaining = countdownManager:GetRemainingTime(padId)
    
    local payload: PadStatePayload = {
        PadId = padId,
        WorldId = config.WorldId,
        Difficulty = config.Difficulty,
        PlayersCount = playerCount,
        MaxPlayers = config.MaxPlayers,
        CountdownRemaining = if countdownRemaining > 0 then math.ceil(countdownRemaining) else nil,
        PlayerNames = getPlayerNames(players),
    }
    
    ZapServer.PadStateUpdate.FireAll(payload)
end

-- Notify a specific player that they joined a pad
function PadBroadcaster:NotifyPlayerJoined(player: Player, padId: string, worldId: string, difficulty: string, position: Vector3)
    ZapServer.JoinedPad.Fire(player, {
        PadId = padId,
        WorldId = worldId,
        Difficulty = difficulty,
        Position = position,
    })
    Logger.Debug("PadBroadcaster", `Notified: {player.Name} joined pad {padId}`)
end

-- Notify a specific player that they left a pad
function PadBroadcaster:NotifyPlayerLeft(player: Player)
    ZapServer.LeftPad.Fire(player, {})
    Logger.Debug("PadBroadcaster", `Notified: {player.Name} left pad`)
end

-- Singleton instance
local _instance: PadBroadcaster? = nil

function PadBroadcaster.GetInstance(): PadBroadcaster
    if not _instance then
        _instance = PadBroadcaster.new()
    end
    return _instance
end

return PadBroadcaster
