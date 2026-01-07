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
    StageId: number,
    PlayersCount: number,
    MaxPlayers: number,
    CountdownRemaining: number?,
    IsLocked: boolean,
    PlayerNames: {string}?,
}

export type PadBroadcaster = {
    BroadcastPadState: (self: PadBroadcaster, padId: string, config: PadManager.PadConfig) -> (),
    NotifyPlayerJoined: (self: PadBroadcaster, player: Player, padId: string) -> (),
    NotifyPlayerLeft: (self: PadBroadcaster, player: Player, padId: string) -> (),
}

local PadBroadcaster = {}
PadBroadcaster.__index = PadBroadcaster

function PadBroadcaster.new(): PadBroadcaster
    local self = setmetatable({}, PadBroadcaster)
    return self
end

-- Get player names from player list
local function getPlayerNames(players: {Player}): {string}
    local names = {}
    for _, player in ipairs(players) do
        table.insert(names, player.Name)
    end
    return names
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
        StageId = config.StageId,
        PlayersCount = playerCount,
        MaxPlayers = config.MaxPlayers,
        CountdownRemaining = if countdownRemaining > 0 then math.ceil(countdownRemaining) else nil,
        IsLocked = false,
        PlayerNames = if playerCount > 0 then getPlayerNames(players) else nil,
    }
    
    ZapServer.PadStateUpdate.FireAll(payload)
end

-- Notify all clients that a player joined a pad
function PadBroadcaster:NotifyPlayerJoined(player: Player, padId: string)
    ZapServer.JoinedPad.FireAll({
        PlayerName = player.Name,
        PadId = padId,
    })
    Logger.Debug("PadBroadcaster", `Notified: {player.Name} joined pad {padId}`)
end

-- Notify all clients that a player left a pad
function PadBroadcaster:NotifyPlayerLeft(player: Player, padId: string)
    ZapServer.LeftPad.FireAll({
        PlayerName = player.Name,
        PadId = padId,
    })
    Logger.Debug("PadBroadcaster", `Notified: {player.Name} left pad {padId}`)
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
