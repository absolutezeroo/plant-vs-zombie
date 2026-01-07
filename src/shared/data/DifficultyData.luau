--!strict
--[[
	DifficultyData.luau - Difficulty level definitions
	
	Players can freely choose any difficulty for any world.
	Higher difficulty = more waves, tougher zombies, better rewards.
]]

export type DifficultyConfig = {
	Id: string,                -- "easy", "normal", "hard", "nightmare"
	Name: string,              -- Display name
	Description: string,       -- Short description
	Order: number,             -- Display order
	
	-- Visual
	Icon: string,              -- Icon/emoji for UI
	Color: Color3,             -- Theme color
	
	-- Wave configuration
	WaveCount: number,         -- Number of waves
	BaseBudget: number,        -- Starting zombie budget
	BudgetPerWave: number,     -- Additional budget per wave
	SpawnInterval: number,     -- Seconds between zombie spawns
	
	-- Difficulty multipliers
	ZombieHealthMult: number,  -- Zombie health multiplier
	ZombieSpeedMult: number,   -- Zombie speed multiplier
	ZombieDamageMult: number,  -- Zombie damage multiplier
	
	-- Alternative names for WaveSpawner compatibility
	ZombieHPMultiplier: number?,   -- Alias for ZombieHealthMult
	BudgetMultiplier: number?,     -- Overall budget multiplier
	SpawnRateMultiplier: number?,  -- Spawn speed multiplier (higher = faster)
	
	-- Boss configuration
	HasBoss: boolean,          -- Does this difficulty have a boss wave?
	BossWave: number?,         -- Which wave spawns the boss
	
	-- Rewards
	CoinReward: number,        -- Base coins for completing
	XPReward: number,          -- Base XP for completing
	CoinMultiplier: number,    -- Multiplier for in-game coin drops
	
	-- Sun modifier (affects sky sun drops)
	SunDropInterval: number,   -- Seconds between sky sun drops
}

-- ============================================
-- DIFFICULTY DEFINITIONS
-- ============================================

local Difficulties: {[string]: DifficultyConfig} = {
	
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
	
	--[[
	-- ============================================
	-- ENDLESS - Survival mode (special) - DISABLED FOR NOW
	-- TODO: Activer quand le mode survie sera implémenté
	-- ============================================
	endless = {
		Id = "endless",
		Name = "Infini",
		Description = "Combien de temps tiendrez-vous ?",
		Order = 5,
		
		Icon = "♾️",
		Color = Color3.fromRGB(255, 50, 50), -- Red
		
		-- Infinite waves (use high number, game ends on death)
		WaveCount = 999,
		BaseBudget = 50,
		BudgetPerWave = 15, -- Scales infinitely
		SpawnInterval = 2.0,
		
		-- Starts normal, scales up
		ZombieHealthMult = 1.0, -- Scales with wave number
		ZombieSpeedMult = 1.0,
		ZombieDamageMult = 1.0,
		
		-- Boss every 10 waves
		HasBoss = true,
		BossWave = 10,
		
		-- Rewards based on waves survived
		CoinReward = 10, -- Per wave survived
		XPReward = 5,    -- Per wave survived
		CoinMultiplier = 1.0,
		
		-- Normal sun
		SunDropInterval = 10,
	},
	]]
}

-- ============================================
-- API
-- ============================================

local DifficultyData = {}

-- Get all difficulties sorted by order
function DifficultyData.GetAll(): {DifficultyConfig}
	local result: {DifficultyConfig} = {}
	for _, difficulty in Difficulties do
		table.insert(result, difficulty)
	end
	table.sort(result, function(a, b)
		return a.Order < b.Order
	end)
	return result
end

-- Get a specific difficulty by ID
function DifficultyData.GetDifficulty(difficultyId: string): DifficultyConfig?
	return Difficulties[difficultyId]
end

-- Calculate rewards for endless mode based on waves survived
function DifficultyData.CalculateEndlessRewards(wavesSurvived: number): (number, number)
	local config = Difficulties.endless
	local coins = config.CoinReward * wavesSurvived
	local xp = config.XPReward * wavesSurvived
	
	-- Bonus for milestones
	local milestoneBonus = math.floor(wavesSurvived / 10) * 50
	coins = coins + milestoneBonus
	xp = xp + math.floor(milestoneBonus / 2)
	
	return coins, xp
end

-- Calculate scaled difficulty for endless mode
function DifficultyData.GetEndlessMultipliers(waveNumber: number): (number, number, number)
	-- Health scales 5% per wave
	local healthMult = 1.0 + (waveNumber * 0.05)
	-- Speed scales 1% per wave, capped at 2x
	local speedMult = math.min(2.0, 1.0 + (waveNumber * 0.01))
	-- Damage scales 2% per wave
	local damageMult = 1.0 + (waveNumber * 0.02)
	
	return healthMult, speedMult, damageMult
end

return table.freeze(DifficultyData)
