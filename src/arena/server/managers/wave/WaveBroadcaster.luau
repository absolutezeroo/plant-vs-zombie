--!strict
--[[
    WaveBroadcaster.luau - Handles network events for wave system
    
    Single Responsibility: Broadcast wave/stage events to clients
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Types
local RewardCalculator = require(script.Parent.RewardCalculator)
export type RewardResult = RewardCalculator.RewardResult

export type WaveBroadcaster = {
    BroadcastGameStarted: (self: WaveBroadcaster, worldId: string, difficulty: string, worldName: string, difficultyName: string, waveCount: number) -> (),
    BroadcastStageStarted: (self: WaveBroadcaster, stageId: string, stageName: string, waveCount: number) -> (),
    BroadcastWaveStarted: (self: WaveBroadcaster, waveNumber: number, zombieCount: number) -> (),
    BroadcastWaveCompleted: (self: WaveBroadcaster, waveNumber: number, survived: boolean) -> (),
    BroadcastGameOver: (self: WaveBroadcaster, victory: boolean, waveReached: number) -> (),
    BroadcastStageComplete: (self: WaveBroadcaster, player: Player, data: StageCompleteData) -> (),
    BroadcastGameEndRewards: (self: WaveBroadcaster, player: Player, data: GameEndRewardsData) -> (),
    BroadcastTeleportCountdown: (self: WaveBroadcaster, timeRemaining: number) -> (),
    BroadcastPreparationTime: (self: WaveBroadcaster, timeRemaining: number) -> (),
    BroadcastIntermissionTime: (self: WaveBroadcaster, timeRemaining: number) -> (),
}

export type StageCompleteData = {
    StageId: string,
    Victory: boolean,
    Stars: number,
    CoinsEarned: number,
    XPEarned: number,
    IsFirstClear: boolean,
    IsNewBest: boolean,
    PreviousStars: number,
}

export type GameEndRewardsData = {
    WorldId: string?,
    Difficulty: string?,
    Victory: boolean,
    CoinsEarned: number,
    ZombiesKilled: number,
    WavesCompleted: number,
    TotalWaves: number?,
    BonusCoins: number,
    StarRating: number,
    XPEarned: number,
    GemsEarned: number?,
    NewLevel: number,
    LevelsGained: number,
    IsEndless: boolean?,
}

local WaveBroadcaster = {}
WaveBroadcaster.__index = WaveBroadcaster

-- Lazy-load Network
local _network: any = nil
local function getNetwork()
    if not _network then
        local Server = script.Parent.Parent.Parent
        _network = require(Server.network.generated)
    end
    return _network
end

function WaveBroadcaster.new(): WaveBroadcaster
    local self = setmetatable({}, WaveBroadcaster)
    return self :: any
end

-- Broadcast game started (new World + Difficulty system)
function WaveBroadcaster:BroadcastGameStarted(worldId: string, difficulty: string, worldName: string, difficultyName: string, waveCount: number)
    local Network = getNetwork()
    -- Use StageStarted event for compatibility, or add GameStarted to packets.zap
    Network.StageStarted.FireAll({
        StageId = `{worldId}-{difficulty}`,
        StageName = `{worldName} ({difficultyName})`,
        WaveCount = waveCount,
        -- New fields (will be ignored by old clients)
        WorldId = worldId,
        Difficulty = difficulty,
        WorldName = worldName,
        DifficultyName = difficultyName,
    })
    Logger.Debug("WaveBroadcaster", `Game started: {worldName} | {difficultyName}`)
end

-- Broadcast stage started (legacy)
function WaveBroadcaster:BroadcastStageStarted(stageId: string, stageName: string, waveCount: number)
    local Network = getNetwork()
    Network.StageStarted.FireAll({
        StageId = stageId,
        StageName = stageName,
        WaveCount = waveCount,
    })
    Logger.Debug("WaveBroadcaster", `Stage started: {stageId}`)
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

-- Broadcast stage complete to a specific player
function WaveBroadcaster:BroadcastStageComplete(player: Player, data: StageCompleteData)
    local Network = getNetwork()
    Network.StageComplete.Fire(player, data)
    Logger.Debug("WaveBroadcaster", `Stage complete sent to {player.Name}`)
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

-- Broadcast preparation time
function WaveBroadcaster:BroadcastPreparationTime(timeRemaining: number)
    local Network = getNetwork()
    Network.PreparationTime.FireAll({
        TimeRemaining = timeRemaining,
    })
end

-- Broadcast intermission time
function WaveBroadcaster:BroadcastIntermissionTime(timeRemaining: number)
    local Network = getNetwork()
    Network.IntermissionTime.FireAll({
        TimeRemaining = timeRemaining,
    })
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
