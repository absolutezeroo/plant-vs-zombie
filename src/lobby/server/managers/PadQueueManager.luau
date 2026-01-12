--!strict
--[[
    PadQueueManager.luau - Manages player queues for teleport pads
    
    Single Responsibility: Track which players are on which pads
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Types
local PadManager = require(script.Parent.Parent.modules.PadManager)
export type PadConfig = PadManager.PadConfig

export type PadQueueManager = {
	JoinPad: (self: PadQueueManager, player: Player, padId: string, padConfig: PadConfig) -> boolean,
	LeavePad: (self: PadQueueManager, player: Player) -> string?,
	GetPlayerPad: (self: PadQueueManager, player: Player) -> string?,
	GetPlayersOnPad: (self: PadQueueManager, padId: string) -> { Player },
	GetPlayerCount: (self: PadQueueManager, padId: string) -> number,
	HasSpace: (self: PadQueueManager, padId: string, padConfig: PadConfig) -> boolean,
	IsFull: (self: PadQueueManager, padId: string, padConfig: PadConfig) -> boolean,
	Cleanup: (self: PadQueueManager, player: Player) -> string?,
}

local PadQueueManager = {}
PadQueueManager.__index = PadQueueManager

-- State
local _padPlayers: { [string]: { Player } } = {} -- padId -> list of players
local _playerToPad: { [Player]: string } = {} -- player -> padId

function PadQueueManager.new(): PadQueueManager
	local self = setmetatable({}, PadQueueManager)
	return self
end

-- Initialize queue for a pad if needed
local function ensurePadQueue(padId: string)
	if not _padPlayers[padId] then
		_padPlayers[padId] = {}
	end
end

-- Add player to a pad queue
function PadQueueManager:JoinPad(player: Player, padId: string, padConfig: PadConfig): boolean
	-- Already on a pad?
	if _playerToPad[player] then
		Logger.Warn("PadQueueManager", `{player.Name} already on pad {_playerToPad[player]}`)
		return false
	end

	ensurePadQueue(padId)

	-- Check capacity
	if #_padPlayers[padId] >= padConfig.MaxPlayers then
		Logger.Debug("PadQueueManager", `Pad {padId} is full`)
		return false
	end

	-- Add to queue
	table.insert(_padPlayers[padId], player)
	_playerToPad[player] = padId

	Logger.Debug("PadQueueManager", `{player.Name} joined pad {padId} ({#_padPlayers[padId]}/{padConfig.MaxPlayers})`)

	return true
end

-- Remove player from their current pad
function PadQueueManager:LeavePad(player: Player): string?
	local padId = _playerToPad[player]
	if not padId then
		return nil
	end

	-- Remove from queue
	local players = _padPlayers[padId]
	if players then
		for i, p in ipairs(players) do
			if p == player then
				table.remove(players, i)
				break
			end
		end
	end

	_playerToPad[player] = nil
	Logger.Debug("PadQueueManager", `{player.Name} left pad {padId}`)

	return padId
end

-- Get which pad a player is on
function PadQueueManager:GetPlayerPad(player: Player): string?
	return _playerToPad[player]
end

-- Get all players on a pad
function PadQueueManager:GetPlayersOnPad(padId: string): { Player }
	return _padPlayers[padId] or {}
end

-- Get player count on a pad
function PadQueueManager:GetPlayerCount(padId: string): number
	local players = _padPlayers[padId]
	return if players then #players else 0
end

-- Check if pad has space
function PadQueueManager:HasSpace(padId: string, padConfig: PadConfig): boolean
	return self:GetPlayerCount(padId) < padConfig.MaxPlayers
end

-- Check if pad is full
function PadQueueManager:IsFull(padId: string, padConfig: PadConfig): boolean
	return self:GetPlayerCount(padId) >= padConfig.MaxPlayers
end

-- Cleanup when player leaves game
function PadQueueManager:Cleanup(player: Player): string?
	return self:LeavePad(player)
end

-- Clear all players from a pad (after teleport)
function PadQueueManager:ClearPad(padId: string)
	local players = _padPlayers[padId]
	if players then
		for _, player in ipairs(players) do
			_playerToPad[player] = nil
		end
		_padPlayers[padId] = {}
	end
	Logger.Debug("PadQueueManager", `Pad {padId} cleared`)
end

-- Singleton instance
local _instance: PadQueueManager? = nil

function PadQueueManager.GetInstance(): PadQueueManager
	if not _instance then
		_instance = PadQueueManager.new()
	end
	return _instance
end

return PadQueueManager
