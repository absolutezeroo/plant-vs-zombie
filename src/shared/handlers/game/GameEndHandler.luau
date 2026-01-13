--!strict
--[[
	GameEndHandler.luau - Pure logic for game end reward calculations
	
	Location: src/shared/handlers/game/
	
	Handles:
	- Reward calculation for game end
	- Building reward payloads for players
	
	This is a STATELESS module. It operates on data passed to it.
	WaveService calls these functions and handles state/networking.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionData = require(Shared.data.ProgressionData)

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type SessionStats = {
	ZombiesKilled: number,
	CoinsEarned: number,
	PlantsPlaced: number,
}

export type DifficultyConfig = {
	CoinReward: number?,
	XPReward: number?,
	ZombieHealthMult: number?,
	ZombieDamageMult: number?,
	SpawnInterval: number?,
	WaveCount: number?,
	Name: string?,
}

export type WorldConfig = {
	Name: string?,
	MapId: string?,
	SunStarting: number?,
}

export type GameEndInput = {
	IsVictory: boolean,
	StarRating: number,
	CurrentWave: number,
	TotalWaves: number,
	SessionStats: SessionStats,
	DifficultyConfig: DifficultyConfig?,
	WorldConfig: WorldConfig?,
}

export type PlayerRewardResult = {
	CoinsEarned: number,
	BonusCoins: number,
	XPEarned: number,
	GemsEarned: number,
}

export type BroadcastPayload = {
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

local GameEndHandler = {}

--------------------------------------------------------------------------------
-- REWARD CALCULATIONS
--------------------------------------------------------------------------------

--[[
	Calculate wave progress multiplier (0.0 - 1.0+).
	@param currentWave number - Current wave reached
	@param totalWaves number - Total waves in game
	@return number - Wave multiplier
]]
function GameEndHandler.CalculateWaveMultiplier(currentWave: number, totalWaves: number): number
	if totalWaves <= 0 then
		return 1.0
	end
	return currentWave / totalWaves
end

--[[
	Calculate base rewards from difficulty config.
	@param difficultyConfig DifficultyConfig? - Difficulty settings
	@return number, number - baseCoins, baseXP
]]
function GameEndHandler.GetBaseRewards(difficultyConfig: DifficultyConfig?): (number, number)
	local baseCoins = if difficultyConfig and difficultyConfig.CoinReward then difficultyConfig.CoinReward else 100
	local baseXP = if difficultyConfig and difficultyConfig.XPReward then difficultyConfig.XPReward else 50
	return baseCoins, baseXP
end

--[[
	Calculate star bonus multiplier.
	@param starRating number - Stars earned (0-3)
	@return number - Bonus multiplier
]]
function GameEndHandler.GetStarBonusMultiplier(starRating: number): number
	-- 0 stars = 0%, 1 star = 10%, 2 stars = 25%, 3 stars = 50%
	local starBonuses = { [0] = 0, [1] = 0.1, [2] = 0.25, [3] = 0.5 }
	return starBonuses[starRating] or 0
end

--[[
	Calculate gems earned from victory and stars.
	@param isVictory boolean - Whether player won
	@param starRating number - Stars earned
	@return number - Gems to award
]]
function GameEndHandler.CalculateGems(isVictory: boolean, starRating: number): number
	if not isVictory then
		return 0
	end
	
	-- Base: 5 gems for victory, +2 per star
	return 5 + (starRating * 2)
end

--[[
	Calculate total rewards for a player at game end.
	@param input GameEndInput - All game end data
	@param rewardCalcResult table? - Optional pre-calculated rewards from RewardCalculator
	@return PlayerRewardResult
]]
function GameEndHandler.CalculatePlayerRewards(input: GameEndInput, rewardCalcResult: any?): PlayerRewardResult
	local baseCoins, baseXP = GameEndHandler.GetBaseRewards(input.DifficultyConfig)
	local waveMultiplier = GameEndHandler.CalculateWaveMultiplier(input.CurrentWave, input.TotalWaves)
	local starBonus = GameEndHandler.GetStarBonusMultiplier(input.StarRating)
	
	-- Use RewardCalculator result if provided, otherwise calculate
	local totalCoins: number
	local bonusCoins: number
	local xpEarned: number
	local gemsEarned: number
	
	if rewardCalcResult then
		totalCoins = rewardCalcResult.TotalCoins or math.floor(baseCoins * waveMultiplier)
		bonusCoins = rewardCalcResult.BonusCoins or 0
		xpEarned = rewardCalcResult.XPEarned or baseXP
		gemsEarned = rewardCalcResult.GemsEarned or 0
	else
		-- Simple fallback calculation
		local baseEarned = math.floor(baseCoins * waveMultiplier)
		bonusCoins = math.floor(baseEarned * starBonus)
		totalCoins = if input.IsVictory then baseEarned + bonusCoins else 0
		xpEarned = baseXP
		gemsEarned = GameEndHandler.CalculateGems(input.IsVictory, input.StarRating)
	end
	
	return {
		CoinsEarned = totalCoins,
		BonusCoins = bonusCoins,
		XPEarned = xpEarned,
		GemsEarned = gemsEarned,
	}
end

--[[
	Build broadcast payload for client.
	@param input GameEndInput - Game end data
	@param rewards PlayerRewardResult - Calculated rewards
	@param newLevel number - Player's new level after XP
	@param levelsGained number - Levels gained from XP
	@return BroadcastPayload
]]
function GameEndHandler.BuildBroadcastPayload(
	input: GameEndInput,
	rewards: PlayerRewardResult,
	newLevel: number,
	levelsGained: number
): BroadcastPayload
	return {
		Victory = input.IsVictory,
		CoinsEarned = rewards.CoinsEarned,
		ZombiesKilled = input.SessionStats.ZombiesKilled,
		WavesCompleted = input.CurrentWave,
		BonusCoins = rewards.BonusCoins,
		StarRating = input.StarRating,
		XPEarned = rewards.XPEarned,
		GemsEarned = rewards.GemsEarned,
		NewLevel = newLevel,
		LevelsGained = levelsGained,
	}
end

return GameEndHandler
