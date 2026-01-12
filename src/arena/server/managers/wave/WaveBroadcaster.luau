--!strict
--[[
    WaveBroadcaster.luau - Handles network events for wave system
    
    Single Responsibility: Broadcast wave and game events to clients
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Types
local RewardCalculator = require(script.Parent.RewardCalculator)
export type RewardResult = RewardCalculator.RewardResult

export type WaveBroadcaster = {
	BroadcastGameStarted: (
		self: WaveBroadcaster,
		worldId: string,
		difficulty: string,
		worldName: string,
		difficultyName: string,
		waveCount: number
	) -> (),
	BroadcastWaveStarted: (self: WaveBroadcaster, waveNumber: number, zombieCount: number) -> (),
	BroadcastWaveCompleted: (self: WaveBroadcaster, waveNumber: number, survived: boolean) -> (),
	BroadcastGameOver: (self: WaveBroadcaster, victory: boolean, waveReached: number) -> (),
	BroadcastGameEndRewards: (self: WaveBroadcaster, player: Player, data: GameEndRewardsData) -> (),
	BroadcastTeleportCountdown: (self: WaveBroadcaster, timeRemaining: number) -> (),
	BroadcastPreparationTime: (self: WaveBroadcaster, timeRemaining: number) -> (),
	BroadcastIntermissionTime: (self: WaveBroadcaster, timeRemaining: number) -> (),
}

export type GameEndRewardsData = {
	Victory: boolean,
	CoinsEarned: number,
	ZombiesKilled: number,
	WavesCompleted: number,
	BonusCoins: number,
	StarRating: number,
	XPEarned: number,
	GemsEarned: number,
	NewLevel: number,
	LevelsGained: number,
}

local WaveBroadcaster = {}
WaveBroadcaster.__index = WaveBroadcaster

-- Lazy-load Network
local _network: any = nil
local function getNetwork()
	if not _network then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		_network = require(Shared.network.generated.server)
	end
	return _network
end

function WaveBroadcaster.new(): WaveBroadcaster
	local self = setmetatable({}, WaveBroadcaster)
	return self :: any
end

-- Broadcast game started (new World + Difficulty system)
function WaveBroadcaster:BroadcastGameStarted(
	worldId: string,
	difficulty: string,
	worldName: string,
	difficultyName: string,
	waveCount: number
)
	local Network = getNetwork()
	Network.GameStarted.FireAll({
		WorldId = worldId,
		Difficulty = difficulty,
		WaveCount = waveCount,
	})
	Logger.Debug("WaveBroadcaster", `Game started: {worldName} | {difficultyName}`)
end

-- Broadcast wave started
function WaveBroadcaster:BroadcastWaveStarted(waveNumber: number, zombieCount: number)
	local Network = getNetwork()
	Network.WaveStarted.FireAll({
		WaveNumber = waveNumber,
		ZombieCount = zombieCount,
	})
	Logger.Debug("WaveBroadcaster", `Wave {waveNumber} started`)
end

-- Broadcast wave completed
function WaveBroadcaster:BroadcastWaveCompleted(waveNumber: number, survived: boolean)
	local Network = getNetwork()
	Network.WaveCompleted.FireAll({
		WaveNumber = waveNumber,
		Survived = survived,
	})
	Logger.Debug("WaveBroadcaster", `Wave {waveNumber} completed`)
end

-- Broadcast game over
function WaveBroadcaster:BroadcastGameOver(victory: boolean, waveReached: number)
	local Network = getNetwork()
	Network.GameOver.FireAll({
		Victory = victory,
		WaveReached = waveReached,
	})
	Logger.Info("WaveBroadcaster", `Game over: {if victory then "VICTORY" else "DEFEAT"} at wave {waveReached}`)
end

-- Broadcast end game rewards to a specific player
function WaveBroadcaster:BroadcastGameEndRewards(player: Player, data: GameEndRewardsData)
	local Network = getNetwork()
	Network.GameEndRewards.Fire(player, data)
	Logger.Debug("WaveBroadcaster", `Rewards sent to {player.Name}: {data.CoinsEarned} coins, {data.XPEarned} XP`)
end

-- Broadcast teleport countdown
function WaveBroadcaster:BroadcastTeleportCountdown(timeRemaining: number)
	local Network = getNetwork()
	for _, player in Players:GetPlayers() do
		Network.TeleportCountdown.Fire(player, {
			TimeRemaining = timeRemaining,
		})
	end
end

-- Broadcast preparation time (client handles countdown locally via WaveStarted with WaveNumber=0)
function WaveBroadcaster:BroadcastPreparationTime(_timeRemaining: number)
	-- No-op: Client counts down locally after receiving WaveStarted with WaveNumber=0
end

-- Broadcast intermission time (client handles countdown locally via WaveCompleted)
function WaveBroadcaster:BroadcastIntermissionTime(_timeRemaining: number)
	-- No-op: Client counts down locally after receiving WaveCompleted
end

-- Singleton instance
local _instance: WaveBroadcaster? = nil

function WaveBroadcaster.GetInstance(): WaveBroadcaster
	if not _instance then
		_instance = WaveBroadcaster.new()
	end
	return _instance :: any
end

return WaveBroadcaster
