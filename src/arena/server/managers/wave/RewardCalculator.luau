--!strict
--[[
    RewardCalculator.luau - Calculates end-game rewards
    
    Single Responsibility: Calculate coins, XP, gems, stars based on performance
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionData = require(Shared.data.ProgressionData)
local StageData = require(Shared.data.StageData)
local Logger = require(Shared.utils.Logger)

-- Types
export type SessionStats = {
    ZombiesKilled: number,
    CoinsEarned: number,
    PlantsPlaced: number,
}

export type RewardResult = {
    TotalCoins: number,
    BonusCoins: number,
    StageCoins: number,
    FirstClearBonus: number,
    XPEarned: number,
    GemsEarned: number,
    StarRating: number,
    LevelsGained: number,
    IsFirstClear: boolean,
    IsNewBest: boolean,
}

export type RewardCalculator = {
    CalculateRewards: (self: RewardCalculator, params: RewardParams) -> RewardResult,
    CalculateStarRating: (self: RewardCalculator, healthPercent: number) -> number,
}

export type RewardParams = {
    IsVictory: boolean,
    WaveReached: number,
    SessionStats: SessionStats,
    StageConfig: StageData.StageConfig?,
    StarRating: number,
    IsFirstClear: boolean,
    IsNewBest: boolean,
}

local RewardCalculator = {}
RewardCalculator.__index = RewardCalculator

function RewardCalculator.new(): RewardCalculator
    local self = setmetatable({}, RewardCalculator)
    return self :: any
end

-- Calculate star rating based on base health percent
function RewardCalculator:CalculateStarRating(healthPercent: number): number
    if healthPercent >= 0.8 then
        return 3
    elseif healthPercent >= 0.5 then
        return 2
    elseif healthPercent > 0 then
        return 1
    end
    return 0
end

-- Calculate all rewards for end of game
function RewardCalculator:CalculateRewards(params: RewardParams): RewardResult
    local result: RewardResult = {
        TotalCoins = 0,
        BonusCoins = 0,
        StageCoins = 0,
        FirstClearBonus = 0,
        XPEarned = 0,
        GemsEarned = 0,
        StarRating = params.StarRating,
        LevelsGained = 0,
        IsFirstClear = params.IsFirstClear,
        IsNewBest = params.IsNewBest,
    }
    
    local stats = params.SessionStats
    local stageConfig = params.StageConfig
    
    -- Base coins from zombies killed during game
    result.TotalCoins = stats.CoinsEarned
    
    -- Victory bonus per wave
    if params.IsVictory then
        result.BonusCoins = params.WaveReached * ProgressionData.VICTORY_BONUS_PER_WAVE
        result.TotalCoins += result.BonusCoins
    end
    
    -- Stage completion rewards
    if stageConfig then
        if params.IsVictory then
            result.StageCoins = stageConfig.CoinReward or 0
            result.TotalCoins += result.StageCoins
            
            -- First clear bonus
            if params.IsFirstClear and stageConfig.FirstClearBonus then
                result.FirstClearBonus = stageConfig.FirstClearBonus
                result.TotalCoins += result.FirstClearBonus
            end
        end
    end
    
    -- XP calculation
    result.XPEarned = 0
    result.XPEarned += stats.ZombiesKilled * ProgressionData.XP_PER_ZOMBIE
    result.XPEarned += params.WaveReached * ProgressionData.XP_PER_WAVE
    
    if params.IsVictory then
        if stageConfig then
            result.XPEarned += stageConfig.XPReward or 0
        end
        result.XPEarned += ProgressionData.XP_VICTORY_BONUS
        result.XPEarned += params.StarRating * ProgressionData.XP_PER_STAR
    end
    
    -- Gems for 3-star victory
    if params.IsVictory and params.StarRating == 3 then
        result.GemsEarned = ProgressionData.GEMS_VICTORY_3_STAR
    end
    
    Logger.Debug("RewardCalculator", `Rewards: {result.TotalCoins} coins, {result.XPEarned} XP, {result.GemsEarned} gems`)
    
    return result
end

-- Singleton instance
local _instance: RewardCalculator? = nil

function RewardCalculator.GetInstance(): RewardCalculator
    if not _instance then
        _instance = RewardCalculator.new()
    end
    return _instance :: any
end

return RewardCalculator
