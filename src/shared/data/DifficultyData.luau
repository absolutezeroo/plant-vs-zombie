--!strict
--[[
	DifficultyData.luau - Difficulty level definitions
	
	Players can freely choose any difficulty for any world.
	Higher difficulty = more waves, tougher zombies, better rewards.
	
	NOTE: GetDifficulty() applies LiveConfigService overrides for live tuning.
	The raw frozen tables are the "factory defaults".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sift = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Sift"))
local LiveConfigService = require(Shared.services.LiveConfigService)

export type DifficultyConfig = {
	Id: string, -- "easy", "normal", "hard", "nightmare"
	Name: string, -- Display name
	Description: string, -- Short description
	Order: number, -- Display order

	-- Visual
	Icon: string, -- Icon/emoji for UI
	Color: Color3, -- Theme color

	-- Wave configuration
	WaveCount: number, -- Number of waves
	BaseBudget: number, -- Starting zombie budget
	BudgetPerWave: number, -- Additional budget per wave
	SpawnInterval: number, -- Seconds between zombie spawns

	-- Difficulty multipliers
	ZombieHealthMult: number, -- Zombie health multiplier
	ZombieSpeedMult: number, -- Zombie speed multiplier
	ZombieDamageMult: number, -- Zombie damage multiplier

	-- Alternative names for WaveSpawner compatibility
	ZombieHPMultiplier: number?, -- Alias for ZombieHealthMult
	BudgetMultiplier: number?, -- Overall budget multiplier
	SpawnRateMultiplier: number?, -- Spawn speed multiplier (higher = faster)

	-- Boss configuration
	HasBoss: boolean, -- Does this difficulty have a boss wave?
	BossWave: number?, -- Which wave spawns the boss

	-- Rewards
	CoinReward: number, -- Base coins for completing
	XPReward: number, -- Base XP for completing
	CoinMultiplier: number, -- Multiplier for in-game coin drops

	-- Sun modifier (affects sky sun drops)
	SunDropInterval: number, -- Seconds between sky sun drops
}

-- ============================================
-- DIFFICULTY DEFINITIONS
-- ============================================

local Difficulties: { [string]: DifficultyConfig } = {

	-- ============================================
	-- EASY - For casual play / learning
	-- ============================================
	easy = {
		Id = "easy",
		Name = "Facile",
		Description = "Parfait pour découvrir le monde.",
		Order = 1,

		Icon = "⭐",
		Color = Color3.fromRGB(100, 200, 100), -- Green

		-- Waves
		WaveCount = 5,
		BaseBudget = 30,
		BudgetPerWave = 10,
		SpawnInterval = 3.5,

		-- Easy zombies
		ZombieHealthMult = 0.8,
		ZombieSpeedMult = 0.9,
		ZombieDamageMult = 0.8,

		-- No boss
		HasBoss = false,

		-- Low rewards
		CoinReward = 50,
		XPReward = 25,
		CoinMultiplier = 1.0,

		-- More sun
		SunDropInterval = 8,
	},

	-- ============================================
	-- NORMAL - Standard experience
	-- ============================================
	normal = {
		Id = "normal",
		Name = "Normal",
		Description = "L'expérience classique.",
		Order = 2,

		Icon = "⭐⭐",
		Color = Color3.fromRGB(100, 150, 255), -- Blue

		-- Waves
		WaveCount = 8,
		BaseBudget = 50,
		BudgetPerWave = 20,
		SpawnInterval = 2.5,

		-- Standard zombies
		ZombieHealthMult = 1.0,
		ZombieSpeedMult = 1.0,
		ZombieDamageMult = 1.0,

		-- Mini-boss on last wave
		HasBoss = true,
		BossWave = 8,

		-- Normal rewards
		CoinReward = 100,
		XPReward = 50,
		CoinMultiplier = 1.0,

		-- Normal sun
		SunDropInterval = 10,
	},

	-- ============================================
	-- HARD - For experienced players
	-- ============================================
	hard = {
		Id = "hard",
		Name = "Difficile",
		Description = "Les zombies sont plus résistants.",
		Order = 3,

		Icon = "⭐⭐⭐",
		Color = Color3.fromRGB(255, 150, 50), -- Orange

		-- More waves
		WaveCount = 12,
		BaseBudget = 80,
		BudgetPerWave = 35,
		SpawnInterval = 2.0,

		-- Tougher zombies
		ZombieHealthMult = 1.5,
		ZombieSpeedMult = 1.2,
		ZombieDamageMult = 1.3,

		-- Boss mid-game and end
		HasBoss = true,
		BossWave = 12,

		-- Better rewards
		CoinReward = 200,
		XPReward = 100,
		CoinMultiplier = 1.5,

		-- Less sun
		SunDropInterval = 12,
	},

	-- ============================================
	-- NIGHTMARE - Endgame challenge
	-- ============================================
	nightmare = {
		Id = "nightmare",
		Name = "Cauchemar",
		Description = "Seuls les meilleurs survivent.",
		Order = 4,

		Icon = "💀",
		Color = Color3.fromRGB(150, 50, 200), -- Purple

		-- Many waves
		WaveCount = 20,
		BaseBudget = 120,
		BudgetPerWave = 50,
		SpawnInterval = 1.5,

		-- Very tough zombies
		ZombieHealthMult = 2.0,
		ZombieSpeedMult = 1.4,
		ZombieDamageMult = 1.5,

		-- Multiple boss waves
		HasBoss = true,
		BossWave = 10, -- First boss at wave 10, another at 20

		-- Great rewards
		CoinReward = 500,
		XPReward = 250,
		CoinMultiplier = 2.0,

		-- Minimal sun
		SunDropInterval = 15,
	},
}

-- ============================================
-- API
-- ============================================

local DifficultyData = {}

-- Get all difficulties sorted by order (with live config applied)
function DifficultyData.GetAll(): { DifficultyConfig }
	local result: { DifficultyConfig } = {}
	for id, _ in Difficulties do
		local config = DifficultyData.GetDifficulty(id)
		if config then
			table.insert(result, config)
		end
	end
	table.sort(result, function(a, b)
		return a.Order < b.Order
	end)
	return result
end

-- Get all difficulties WITHOUT live config (factory defaults)
function DifficultyData.GetAllRaw(): { DifficultyConfig }
	local result: { DifficultyConfig } = {}
	for _, difficulty in Difficulties do
		table.insert(result, difficulty)
	end
	table.sort(result, function(a, b)
		return a.Order < b.Order
	end)
	return result
end

-- Get a specific difficulty by ID (with live config overrides applied)
function DifficultyData.GetDifficulty(difficultyId: string): DifficultyConfig?
	local baseConfig = Difficulties[difficultyId]
	if not baseConfig then
		return nil
	end

	-- Apply LiveConfigService overrides using Sift for immutability
	-- Global zombie multipliers stack with difficulty-specific multipliers
	local globalHealthMult = LiveConfigService.GetGlobalZombieMult("Health")
	local globalSpeedMult = LiveConfigService.GetGlobalZombieMult("Speed")
	local globalDamageMult = LiveConfigService.GetGlobalZombieMult("Damage")

	-- Get difficulty-specific overrides
	local healthMultOverride =
		LiveConfigService.GetDifficultyOverride(difficultyId, "ZombieHealthMult", baseConfig.ZombieHealthMult)
	local speedMultOverride =
		LiveConfigService.GetDifficultyOverride(difficultyId, "ZombieSpeedMult", baseConfig.ZombieSpeedMult)
	local damageMultOverride =
		LiveConfigService.GetDifficultyOverride(difficultyId, "ZombieDamageMult", baseConfig.ZombieDamageMult)
	local coinRewardOverride =
		LiveConfigService.GetDifficultyOverride(difficultyId, "CoinReward", baseConfig.CoinReward)

	-- Create new config with overrides (immutable pattern)
	local effectiveConfig = Sift.Dictionary.merge(baseConfig, {
		ZombieHealthMult = healthMultOverride * globalHealthMult,
		ZombieSpeedMult = speedMultOverride * globalSpeedMult,
		ZombieDamageMult = damageMultOverride * globalDamageMult,
		CoinReward = coinRewardOverride,
	})

	return effectiveConfig
end

-- Get a specific difficulty by ID WITHOUT live config (factory default)
function DifficultyData.GetDifficultyRaw(difficultyId: string): DifficultyConfig?
	return Difficulties[difficultyId]
end

return table.freeze(DifficultyData)
