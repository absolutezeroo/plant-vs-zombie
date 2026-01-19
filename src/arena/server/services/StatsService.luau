--!strict
--[[
	StatsService.luau - Manages session statistics for players
	
	Tracks:
	- ZombiesKilled (per session)
	- CoinsEarned (per session)
	- PlantsPlaced (per session)
	
	Session stats reset between games.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------
export type SessionStats = {
	ZombiesKilled: number,
	CoinsEarned: number,
	PlantsPlaced: number,
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local _isInitialized = false
local _trove: any = nil
local _sessionStats: { [Player]: SessionStats } = {}

--------------------------------------------------------------------------------
-- Private Functions
--------------------------------------------------------------------------------
local function ensureStats(player: Player): SessionStats
	if not _sessionStats[player] then
		_sessionStats[player] = {
			ZombiesKilled = 0,
			CoinsEarned = 0,
			PlantsPlaced = 0,
		}
	end
	return _sessionStats[player]
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
local StatsService = {}

--[[
	Initialize the stats service
]]
function StatsService.Initialize()
	if _isInitialized then
		return
	end

	_trove = Trove.new()

	-- Clean up when player leaves
	_trove:Connect(Players.PlayerRemoving, function(player)
		_sessionStats[player] = nil
	end)

	_isInitialized = true
	Logger.Info("StatsService", "Initialized")
end

--[[
	Get session stats for a player (creates default if not exists)
]]
function StatsService.GetSessionStats(player: Player): SessionStats
	return ensureStats(player)
end

--[[
	Add zombie kill to session stats
]]
function StatsService.AddZombieKill(player: Player, count: number?)
	local stats = ensureStats(player)
	stats.ZombiesKilled += count or 1
end

--[[
	Add coins earned to session stats
]]
function StatsService.AddCoinsEarned(player: Player, amount: number)
	local stats = ensureStats(player)
	stats.CoinsEarned += amount
end

--[[
	Add plant placed to session stats
]]
function StatsService.AddPlantPlaced(player: Player, count: number?)
	local stats = ensureStats(player)
	stats.PlantsPlaced += count or 1
end

--[[
	Reset session stats for a single player
]]
function StatsService.ResetSessionStats(player: Player)
	_sessionStats[player] = {
		ZombiesKilled = 0,
		CoinsEarned = 0,
		PlantsPlaced = 0,
	}
end

--[[
	Reset all session stats for all players
]]
function StatsService.ResetAllSessionStats()
	for player, _ in _sessionStats do
		StatsService.ResetSessionStats(player)
	end
	Logger.Debug("StatsService", "All session stats reset")
end

--[[
	Dispose the service
]]
function StatsService.Dispose()
	if _trove then
		_trove:Destroy()
		_trove = nil
	end
	table.clear(_sessionStats)
	_isInitialized = false
	Logger.Debug("StatsService", "Disposed")
end

return StatsService
