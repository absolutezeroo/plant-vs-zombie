--!strict
--[[
	MultiplayerScalingHandler.luau - Pure logic for multiplayer scaling calculations
	
	Location: src/shared/handlers/game/
	
	Handles:
	- Budget scaling based on player count
	- Zombie HP scaling
	- Zombie speed scaling
	- Spawn rate scaling
	
	This is a STATELESS module. It operates on data passed to it.
	WaveService calls these functions to build spawner configs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConstants = require(Shared.config.GameConstants)

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type WorldConfig = {
	Name: string,
	MapId: string,
	ZombiePool: { string }?,
	Mechanics: { [string]: any }?,
	SunStarting: number?,
}

export type DifficultyConfig = {
	ZombieHealthMult: number?,
	ZombieDamageMult: number?,
	SpawnInterval: number?,
	WaveCount: number?,
	CoinReward: number?,
	XPReward: number?,
	Name: string?,
}

export type ScalingFactors = {
	BudgetScale: number,
	HPScale: number,
	SpeedScale: number,
	SpawnRateScale: number,
}

export type SpawnerConfig = {
	Name: string,
	MapId: string,
	ZombiePool: { string }?,
	Mechanics: { [string]: any }?,
	BaseZombieHP: number,
	ZombieSpeedMult: number,
	BaseBudgetMultiplier: number,
	SpawnInterval: number,
	TotalWaves: number,
	PlayerCount: number,
}

local MultiplayerScalingHandler = {}

--------------------------------------------------------------------------------
-- SCALING CALCULATIONS
--------------------------------------------------------------------------------

--[[
	Get scaling factors for a given player count.
	Uses GameConstants.Multiplayer tables.
	
	@param playerCount number - Number of players (will be clamped to 1-4)
	@return ScalingFactors
]]
function MultiplayerScalingHandler.GetScalingFactors(playerCount: number): ScalingFactors
	local mpConfig = GameConstants.Multiplayer
	local scaledCount = math.clamp(playerCount, 1, 4)
	
	return {
		BudgetScale = mpConfig.BUDGET_SCALE[scaledCount] or 1.0,
		HPScale = mpConfig.ZOMBIE_HP_SCALE[scaledCount] or 1.0,
		SpeedScale = mpConfig.ZOMBIE_SPEED_SCALE[scaledCount] or 1.0,
		SpawnRateScale = mpConfig.SPAWN_RATE_SCALE[scaledCount] or 1.0,
	}
end

--[[
	Calculate effective zombie HP multiplier.
	Combines difficulty multiplier with player count scaling.
	
	@param difficultyHealthMult number - From DifficultyConfig
	@param playerCount number - Number of players
	@return number - Final HP multiplier
]]
function MultiplayerScalingHandler.CalculateHPMultiplier(difficultyHealthMult: number, playerCount: number): number
	local factors = MultiplayerScalingHandler.GetScalingFactors(playerCount)
	return difficultyHealthMult * factors.HPScale
end

--[[
	Calculate effective spawn interval.
	Combines difficulty spawn interval with player count scaling.
	
	@param difficultySpawnInterval number - From DifficultyConfig
	@param playerCount number - Number of players
	@return number - Final spawn interval (lower = faster)
]]
function MultiplayerScalingHandler.CalculateSpawnInterval(difficultySpawnInterval: number, playerCount: number): number
	local factors = MultiplayerScalingHandler.GetScalingFactors(playerCount)
	return difficultySpawnInterval * factors.SpawnRateScale
end

--[[
	Calculate effective budget multiplier.
	Combines difficulty damage mult with player count scaling.
	
	@param difficultyDamageMult number - From DifficultyConfig
	@param playerCount number - Number of players
	@return number - Final budget multiplier
]]
function MultiplayerScalingHandler.CalculateBudgetMultiplier(difficultyDamageMult: number, playerCount: number): number
	local factors = MultiplayerScalingHandler.GetScalingFactors(playerCount)
	return difficultyDamageMult * factors.BudgetScale
end

--------------------------------------------------------------------------------
-- SPAWNER CONFIG BUILDING
--------------------------------------------------------------------------------

--[[
	Build a complete spawner config with all multiplayer scaling applied.
	
	@param worldConfig WorldConfig - World configuration
	@param difficultyConfig DifficultyConfig - Difficulty configuration
	@param playerCount number - Number of players in game
	@return SpawnerConfig
]]
function MultiplayerScalingHandler.BuildSpawnerConfig(
	worldConfig: WorldConfig,
	difficultyConfig: DifficultyConfig,
	playerCount: number
): SpawnerConfig
	local factors = MultiplayerScalingHandler.GetScalingFactors(playerCount)
	
	-- Apply all scaling factors
	local baseHP = (difficultyConfig.ZombieHealthMult or 1.0) * factors.HPScale
	local baseBudget = (difficultyConfig.ZombieDamageMult or 1.0) * factors.BudgetScale
	local spawnInterval = (difficultyConfig.SpawnInterval or 2.5) * factors.SpawnRateScale
	local totalWaves = difficultyConfig.WaveCount or 10
	
	return {
		Name = worldConfig.Name,
		MapId = worldConfig.MapId,
		ZombiePool = worldConfig.ZombiePool,
		Mechanics = worldConfig.Mechanics,
		BaseZombieHP = baseHP,
		ZombieSpeedMult = factors.SpeedScale,
		BaseBudgetMultiplier = baseBudget,
		SpawnInterval = spawnInterval,
		TotalWaves = totalWaves,
		PlayerCount = playerCount,
	}
end

return MultiplayerScalingHandler
