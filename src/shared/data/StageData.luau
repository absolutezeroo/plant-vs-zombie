--!strict
--[[
	StageData.luau - Stage/Level configuration
	
	Defines all stages organized by world:
	- World 1: Day (basic zombies)
	- World 2: Night (cones, buckets, newspaper)
	- World 3: Pool (poles, footballs)
	- World 4: Fog (balloons, imps)
	- World 5: Roof (gargantuars, bosses)
	
	Each stage has:
	- Wave count and zombie budget per wave
	- Available zombie types
	- Difficulty modifiers
	- Star thresholds and rewards
]]

export type StageConfig = {
	Name: string,
	World: number,
	Level: number,
	
	-- Wave configuration
	WaveCount: number,
	BaseBudget: number,           -- Starting zombie budget per wave
	BudgetPerWave: number,        -- Additional budget added each wave
	SpawnInterval: number,        -- Seconds between zombie spawns
	
	-- Zombie pool for this stage
	ZombiePool: {string},         -- Available zombie types
	BossWave: number?,            -- Wave number that spawns boss (nil = no boss)
	BossType: string?,            -- Boss zombie type
	
	-- Difficulty modifiers
	ZombieHealthMult: number?,    -- Zombie health multiplier (default 1.0)
	ZombieSpeedMult: number?,     -- Zombie speed multiplier (default 1.0)
	SunStarting: number?,         -- Starting sun (default 50)
	
	-- Star rating thresholds
	Star1Health: number,          -- Minimum base health % for 1 star
	Star2Health: number,          -- Minimum base health % for 2 stars
	Star3Health: number,          -- Minimum base health % for 3 stars
	
	-- Rewards
	CoinReward: number,           -- Base coins for completing
	XPReward: number,             -- XP for completing
	FirstClearBonus: number?,     -- Extra coins on first clear
	
	-- Unlock requirements
	RequiredStage: string?,       -- Stage that must be completed to unlock (e.g. "1-4")
	RequiredLevel: number?,       -- Player level required
}

-- Helper to create stage ID
local function stageId(world: number, level: number): string
	return `{world}-{level}`
end

-- ============================================
-- STAGE DEFINITIONS
-- ============================================

local Stages: {[string]: StageConfig} = {}

-- ============================================
-- WORLD 1: DAY (Tutorial / Easy)
-- ============================================

Stages["1-1"] = {
	Name = "First Encounter",
	World = 1,
	Level = 1,
	
	WaveCount = 3,
	BaseBudget = 30,
	BudgetPerWave = 10,
	SpawnInterval = 3.0,
	
	ZombiePool = {"Basic"},
	
	SunStarting = 100,  -- Extra sun for first level
	
	Star1Health = 0,    -- Just survive
	Star2Health = 50,
	Star3Health = 90,
	
	CoinReward = 50,
	XPReward = 25,
	FirstClearBonus = 100,
}

Stages["1-2"] = {
	Name = "Growing Horde",
	World = 1,
	Level = 2,
	
	WaveCount = 4,
	BaseBudget = 40,
	BudgetPerWave = 15,
	SpawnInterval = 2.8,
	
	ZombiePool = {"Basic", "Flag"},
	
	Star1Health = 0,
	Star2Health = 50,
	Star3Health = 85,
	
	CoinReward = 75,
	XPReward = 35,
	FirstClearBonus = 75,
	
	RequiredStage = "1-1",
}

Stages["1-3"] = {
	Name = "Cone Heads",
	World = 1,
	Level = 3,
	
	WaveCount = 5,
	BaseBudget = 50,
	BudgetPerWave = 20,
	SpawnInterval = 2.5,
	
	ZombiePool = {"Basic", "Cone", "Flag"},
	
	Star1Health = 0,
	Star2Health = 40,
	Star3Health = 80,
	
	CoinReward = 100,
	XPReward = 50,
	FirstClearBonus = 75,
	
	RequiredStage = "1-2",
}

Stages["1-4"] = {
	Name = "Bucket Brigade",
	World = 1,
	Level = 4,
	
	WaveCount = 6,
	BaseBudget = 60,
	BudgetPerWave = 25,
	SpawnInterval = 2.3,
	
	ZombiePool = {"Basic", "Cone", "Bucket", "Flag"},
	
	Star1Health = 0,
	Star2Health = 35,
	Star3Health = 75,
	
	CoinReward = 125,
	XPReward = 60,
	FirstClearBonus = 100,
	
	RequiredStage = "1-3",
}

Stages["1-5"] = {
	Name = "Day's End",
	World = 1,
	Level = 5,
	
	WaveCount = 8,
	BaseBudget = 80,
	BudgetPerWave = 30,
	SpawnInterval = 2.0,
	
	ZombiePool = {"Basic", "Cone", "Bucket", "Flag"},
	BossWave = 8,
	BossType = "MiniGargantuar",
	
	Star1Health = 0,
	Star2Health = 30,
	Star3Health = 70,
	
	CoinReward = 200,
	XPReward = 100,
	FirstClearBonus = 200,
	
	RequiredStage = "1-4",
}

-- ============================================
-- WORLD 2: NIGHT (Medium)
-- ============================================

Stages["2-1"] = {
	Name = "Twilight",
	World = 2,
	Level = 1,
	
	WaveCount = 5,
	BaseBudget = 70,
	BudgetPerWave = 25,
	SpawnInterval = 2.5,
	
	ZombiePool = {"Basic", "Cone", "Newspaper"},
	
	SunStarting = 75,
	
	Star1Health = 0,
	Star2Health = 40,
	Star3Health = 75,
	
	CoinReward = 150,
	XPReward = 75,
	FirstClearBonus = 100,
	
	RequiredStage = "1-5",
	RequiredLevel = 5,
}

Stages["2-2"] = {
	Name = "Night Shift",
	World = 2,
	Level = 2,
	
	WaveCount = 6,
	BaseBudget = 80,
	BudgetPerWave = 30,
	SpawnInterval = 2.3,
	
	ZombiePool = {"Basic", "Cone", "Bucket", "Newspaper", "Flag"},
	
	ZombieHealthMult = 1.1,
	
	Star1Health = 0,
	Star2Health = 35,
	Star3Health = 70,
	
	CoinReward = 175,
	XPReward = 85,
	FirstClearBonus = 100,
	
	RequiredStage = "2-1",
}

Stages["2-3"] = {
	Name = "Pole Position",
	World = 2,
	Level = 3,
	
	WaveCount = 7,
	BaseBudget = 90,
	BudgetPerWave = 35,
	SpawnInterval = 2.2,
	
	ZombiePool = {"Basic", "Cone", "Pole", "Newspaper", "Flag"},
	
	ZombieHealthMult = 1.15,
	
	Star1Health = 0,
	Star2Health = 30,
	Star3Health = 65,
	
	CoinReward = 200,
	XPReward = 100,
	FirstClearBonus = 125,
	
	RequiredStage = "2-2",
}

Stages["2-4"] = {
	Name = "Midnight Rush",
	World = 2,
	Level = 4,
	
	WaveCount = 8,
	BaseBudget = 100,
	BudgetPerWave = 40,
	SpawnInterval = 2.0,
	
	ZombiePool = {"Basic", "Cone", "Bucket", "Pole", "Newspaper", "Flag"},
	
	ZombieHealthMult = 1.2,
	ZombieSpeedMult = 1.1,
	
	Star1Health = 0,
	Star2Health = 25,
	Star3Health = 60,
	
	CoinReward = 250,
	XPReward = 125,
	FirstClearBonus = 150,
	
	RequiredStage = "2-3",
}

Stages["2-5"] = {
	Name = "Witching Hour",
	World = 2,
	Level = 5,
	
	WaveCount = 10,
	BaseBudget = 120,
	BudgetPerWave = 45,
	SpawnInterval = 1.8,
	
	ZombiePool = {"Basic", "Cone", "Bucket", "Pole", "Newspaper", "Flag"},
	BossWave = 10,
	BossType = "Gargantuar",
	
	ZombieHealthMult = 1.25,
	ZombieSpeedMult = 1.15,
	
	Star1Health = 0,
	Star2Health = 20,
	Star3Health = 55,
	
	CoinReward = 350,
	XPReward = 175,
	FirstClearBonus = 250,
	
	RequiredStage = "2-4",
}

-- ============================================
-- WORLD 3: POOL (Hard)
-- ============================================

Stages["3-1"] = {
	Name = "Pool Party",
	World = 3,
	Level = 1,
	
	WaveCount = 7,
	BaseBudget = 100,
	BudgetPerWave = 40,
	SpawnInterval = 2.2,
	
	ZombiePool = {"Basic", "Cone", "Bucket", "Football", "Flag"},
	
	ZombieHealthMult = 1.2,
	
	Star1Health = 0,
	Star2Health = 30,
	Star3Health = 65,
	
	CoinReward = 275,
	XPReward = 140,
	FirstClearBonus = 150,
	
	RequiredStage = "2-5",
	RequiredLevel = 10,
}

Stages["3-2"] = {
	Name = "Deep End",
	World = 3,
	Level = 2,
	
	WaveCount = 8,
	BaseBudget = 120,
	BudgetPerWave = 45,
	SpawnInterval = 2.0,
	
	ZombiePool = {"Basic", "Cone", "Bucket", "Pole", "Football", "Imp", "Flag"},
	
	ZombieHealthMult = 1.3,
	ZombieSpeedMult = 1.1,
	
	Star1Health = 0,
	Star2Health = 25,
	Star3Health = 60,
	
	CoinReward = 325,
	XPReward = 165,
	FirstClearBonus = 175,
	
	RequiredStage = "3-1",
}

Stages["3-3"] = {
	Name = "Cannon Ball",
	World = 3,
	Level = 3,
	
	WaveCount = 9,
	BaseBudget = 140,
	BudgetPerWave = 50,
	SpawnInterval = 1.8,
	
	ZombiePool = {"Basic", "Cone", "Bucket", "Pole", "Football", "Imp", "Flag"},
	
	ZombieHealthMult = 1.35,
	ZombieSpeedMult = 1.15,
	
	Star1Health = 0,
	Star2Health = 20,
	Star3Health = 55,
	
	CoinReward = 375,
	XPReward = 190,
	FirstClearBonus = 200,
	
	RequiredStage = "3-2",
}

Stages["3-4"] = {
	Name = "Splash Zone",
	World = 3,
	Level = 4,
	
	WaveCount = 10,
	BaseBudget = 160,
	BudgetPerWave = 55,
	SpawnInterval = 1.6,
	
	ZombiePool = {"Cone", "Bucket", "Pole", "Football", "Newspaper", "Imp", "Flag"},
	
	ZombieHealthMult = 1.4,
	ZombieSpeedMult = 1.2,
	
	Star1Health = 0,
	Star2Health = 15,
	Star3Health = 50,
	
	CoinReward = 425,
	XPReward = 215,
	FirstClearBonus = 225,
	
	RequiredStage = "3-3",
}

Stages["3-5"] = {
	Name = "Tidal Wave",
	World = 3,
	Level = 5,
	
	WaveCount = 12,
	BaseBudget = 180,
	BudgetPerWave = 60,
	SpawnInterval = 1.5,
	
	ZombiePool = {"Cone", "Bucket", "Pole", "Football", "Newspaper", "Imp", "Flag"},
	BossWave = 12,
	BossType = "Gargantuar",
	
	ZombieHealthMult = 1.5,
	ZombieSpeedMult = 1.25,
	
	Star1Health = 0,
	Star2Health = 10,
	Star3Health = 45,
	
	CoinReward = 500,
	XPReward = 250,
	FirstClearBonus = 350,
	
	RequiredStage = "3-4",
}

-- ============================================
-- WORLD 4: FOG (Expert)
-- ============================================

Stages["4-1"] = {
	Name = "Misty Morning",
	World = 4,
	Level = 1,
	
	WaveCount = 8,
	BaseBudget = 140,
	BudgetPerWave = 50,
	SpawnInterval = 2.0,
	
	ZombiePool = {"Basic", "Cone", "Bucket", "Balloon", "Imp", "Flag"},
	
	ZombieHealthMult = 1.4,
	ZombieSpeedMult = 1.15,
	SunStarting = 50,
	
	Star1Health = 0,
	Star2Health = 25,
	Star3Health = 55,
	
	CoinReward = 400,
	XPReward = 200,
	FirstClearBonus = 200,
	
	RequiredStage = "3-5",
	RequiredLevel = 15,
}

Stages["4-2"] = {
	Name = "Dense Fog",
	World = 4,
	Level = 2,
	
	WaveCount = 9,
	BaseBudget = 160,
	BudgetPerWave = 55,
	SpawnInterval = 1.8,
	
	ZombiePool = {"Cone", "Bucket", "Pole", "Balloon", "Imp", "Newspaper", "Flag"},
	
	ZombieHealthMult = 1.5,
	ZombieSpeedMult = 1.2,
	
	Star1Health = 0,
	Star2Health = 20,
	Star3Health = 50,
	
	CoinReward = 450,
	XPReward = 225,
	FirstClearBonus = 225,
	
	RequiredStage = "4-1",
}

Stages["4-3"] = {
	Name = "Blind Assault",
	World = 4,
	Level = 3,
	
	WaveCount = 10,
	BaseBudget = 180,
	BudgetPerWave = 60,
	SpawnInterval = 1.6,
	
	ZombiePool = {"Cone", "Bucket", "Pole", "Football", "Balloon", "Imp", "Flag"},
	
	ZombieHealthMult = 1.6,
	ZombieSpeedMult = 1.25,
	
	Star1Health = 0,
	Star2Health = 15,
	Star3Health = 45,
	
	CoinReward = 500,
	XPReward = 250,
	FirstClearBonus = 250,
	
	RequiredStage = "4-2",
}

Stages["4-4"] = {
	Name = "Zero Visibility",
	World = 4,
	Level = 4,
	
	WaveCount = 11,
	BaseBudget = 200,
	BudgetPerWave = 65,
	SpawnInterval = 1.5,
	
	ZombiePool = {"Bucket", "Pole", "Football", "Balloon", "Imp", "Newspaper", "Flag"},
	BossWave = 11,
	BossType = "MiniGargantuar",
	
	ZombieHealthMult = 1.7,
	ZombieSpeedMult = 1.3,
	
	Star1Health = 0,
	Star2Health = 10,
	Star3Health = 40,
	
	CoinReward = 550,
	XPReward = 275,
	FirstClearBonus = 300,
	
	RequiredStage = "4-3",
}

Stages["4-5"] = {
	Name = "Storm Front",
	World = 4,
	Level = 5,
	
	WaveCount = 13,
	BaseBudget = 220,
	BudgetPerWave = 70,
	SpawnInterval = 1.4,
	
	ZombiePool = {"Bucket", "Pole", "Football", "Balloon", "Imp", "Newspaper", "Flag"},
	BossWave = 13,
	BossType = "Gargantuar",
	
	ZombieHealthMult = 1.8,
	ZombieSpeedMult = 1.35,
	
	Star1Health = 0,
	Star2Health = 5,
	Star3Health = 35,
	
	CoinReward = 650,
	XPReward = 325,
	FirstClearBonus = 400,
	
	RequiredStage = "4-4",
}

-- ============================================
-- WORLD 5: ROOF (Master)
-- ============================================

Stages["5-1"] = {
	Name = "Rooftop Rumble",
	World = 5,
	Level = 1,
	
	WaveCount = 10,
	BaseBudget = 200,
	BudgetPerWave = 65,
	SpawnInterval = 1.6,
	
	ZombiePool = {"Cone", "Bucket", "Pole", "Football", "Balloon", "Imp", "Flag"},
	
	ZombieHealthMult = 1.75,
	ZombieSpeedMult = 1.3,
	SunStarting = 50,
	
	Star1Health = 0,
	Star2Health = 15,
	Star3Health = 45,
	
	CoinReward = 600,
	XPReward = 300,
	FirstClearBonus = 350,
	
	RequiredStage = "4-5",
	RequiredLevel = 20,
}

Stages["5-2"] = {
	Name = "High Ground",
	World = 5,
	Level = 2,
	
	WaveCount = 11,
	BaseBudget = 220,
	BudgetPerWave = 70,
	SpawnInterval = 1.5,
	
	ZombiePool = {"Bucket", "Pole", "Football", "Balloon", "Imp", "Newspaper", "Flag"},
	BossWave = 11,
	BossType = "MiniGargantuar",
	
	ZombieHealthMult = 1.85,
	ZombieSpeedMult = 1.35,
	
	Star1Health = 0,
	Star2Health = 10,
	Star3Health = 40,
	
	CoinReward = 700,
	XPReward = 350,
	FirstClearBonus = 400,
	
	RequiredStage = "5-1",
}

Stages["5-3"] = {
	Name = "Aerial Assault",
	World = 5,
	Level = 3,
	
	WaveCount = 12,
	BaseBudget = 240,
	BudgetPerWave = 75,
	SpawnInterval = 1.4,
	
	ZombiePool = {"Bucket", "Pole", "Football", "Balloon", "Imp", "Newspaper", "Flag"},
	BossWave = 12,
	BossType = "Gargantuar",
	
	ZombieHealthMult = 2.0,
	ZombieSpeedMult = 1.4,
	
	Star1Health = 0,
	Star2Health = 5,
	Star3Health = 35,
	
	CoinReward = 800,
	XPReward = 400,
	FirstClearBonus = 500,
	
	RequiredStage = "5-2",
}

Stages["5-4"] = {
	Name = "Final Stand",
	World = 5,
	Level = 4,
	
	WaveCount = 14,
	BaseBudget = 260,
	BudgetPerWave = 80,
	SpawnInterval = 1.3,
	
	ZombiePool = {"Bucket", "Pole", "Football", "Balloon", "Imp", "Newspaper", "Flag"},
	BossWave = 14,
	BossType = "Gargantuar",
	
	ZombieHealthMult = 2.2,
	ZombieSpeedMult = 1.45,
	
	Star1Health = 0,
	Star2Health = 5,
	Star3Health = 30,
	
	CoinReward = 1000,
	XPReward = 500,
	FirstClearBonus = 750,
	
	RequiredStage = "5-3",
}

Stages["5-5"] = {
	Name = "Dr. Zomboss",
	World = 5,
	Level = 5,
	
	WaveCount = 15,
	BaseBudget = 300,
	BudgetPerWave = 100,
	SpawnInterval = 1.2,
	
	ZombiePool = {"Bucket", "Pole", "Football", "Balloon", "Imp", "Newspaper", "Flag"},
	BossWave = 15,
	BossType = "Gargantuar",
	
	ZombieHealthMult = 2.5,
	ZombieSpeedMult = 1.5,
	
	Star1Health = 0,
	Star2Health = 5,
	Star3Health = 25,
	
	CoinReward = 1500,
	XPReward = 750,
	FirstClearBonus = 1000,
	
	RequiredStage = "5-4",
}

-- ============================================
-- MODULE API
-- ============================================

local StageData = {}

-- Get stage config by ID (e.g. "1-1", "2-3")
function StageData.GetStage(stageId: string): StageConfig?
	return Stages[stageId]
end

-- Get all stages for a world
function StageData.GetWorldStages(world: number): {StageConfig}
	local worldStages = {}
	for id, config in Stages do
		if config.World == world then
			table.insert(worldStages, config)
		end
	end
	table.sort(worldStages, function(a, b)
		return a.Level < b.Level
	end)
	return worldStages
end

-- Get all stage IDs sorted
function StageData.GetAllStageIds(): {string}
	local ids = {}
	for id in Stages do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local wa, la = a:match("(%d+)-(%d+)")
		local wb, lb = b:match("(%d+)-(%d+)")
		if wa == wb then
			return tonumber(la) < tonumber(lb)
		end
		return tonumber(wa) < tonumber(wb)
	end)
	return ids
end

-- Get world names
StageData.WorldNames = {
	[1] = "Day",
	[2] = "Night",
	[3] = "Pool",
	[4] = "Fog",
	[5] = "Roof",
}

-- Get world count
StageData.WORLD_COUNT = 5
StageData.LEVELS_PER_WORLD = 5

-- Check if stage is unlocked for a player (given their completed stages and level)
function StageData.IsStageUnlocked(stageId: string, completedStages: {[string]: number}, playerLevel: number): boolean
	local config = Stages[stageId]
	if not config then
		return false
	end
	
	-- First stage is always unlocked
	if stageId == "1-1" then
		return true
	end
	
	-- Check level requirement
	if config.RequiredLevel and playerLevel < config.RequiredLevel then
		return false
	end
	
	-- Check required stage completion
	if config.RequiredStage then
		local stars = completedStages[config.RequiredStage]
		if not stars or stars < 1 then
			return false
		end
	end
	
	return true
end

-- Calculate stars earned based on health percentage
function StageData.CalculateStars(stageId: string, healthPercent: number): number
	local config = Stages[stageId]
	if not config then
		return 0
	end
	
	if healthPercent >= config.Star3Health then
		return 3
	elseif healthPercent >= config.Star2Health then
		return 2
	elseif healthPercent >= config.Star1Health then
		return 1
	else
		return 0
	end
end

return table.freeze(StageData)
