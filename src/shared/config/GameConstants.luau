--!strict
--[[
	GameConstants.luau - Centralized game configuration constants
	
	All magic numbers and gameplay tuning values should live here.
	Systems import from this file instead of hardcoding values.
	
	NOTE: For live-tunable values, use LiveConfigService instead.
	This file is for compile-time constants that rarely change.
]]

local GameConstants = {}

-- ============================================
-- CATEGORIES (Enums)
-- ============================================

GameConstants.PlantCategory = table.freeze({
	Attacker = "Attacker",
	Producer = "Producer",
	Defender = "Defender",
	Special = "Special",
	Support = "Support",
})

GameConstants.ZombieCategory = table.freeze({
	Normal = "Normal",
	Armored = "Armored",
	Special = "Special",
	Boss = "Boss",
})

GameConstants.ProjectileVariant = table.freeze({
	Pea = "Pea",
	SnowPea = "SnowPea",
	FirePea = "FirePea",
	Cabbage = "Cabbage",
	Kernel = "Kernel",
	Butter = "Butter",
	Melon = "Melon",
	WinterMelon = "WinterMelon",
	Spore = "Spore",
	Fume = "Fume",
	Star = "Star",
	Spike = "Spike",
	Thorn = "Thorn",
})

-- ============================================
-- COMBAT
-- ============================================

GameConstants.Combat = table.freeze({
	-- Projectile hit detection
	PROJECTILE_HIT_RADIUS = 2.5, -- Studs
	MULTI_DIRECTIONAL_RANGE_MULT = 1.5, -- Multiplier for Starfruit-style shots

	-- Zombie melee
	ZOMBIE_BITE_RANGE = 4, -- Studs
	ZOMBIE_BITE_INTERVAL = 1.0, -- Seconds

	-- Splash damage
	SPLASH_DAMAGE_PERCENT = 0.5, -- 50% of direct damage
	SPLASH_FALLOFF_PERCENT = 0.3, -- 30% damage reduction at edge

	-- Slow effects
	MAX_SLOW_PERCENT = 0.9, -- Maximum slow (90%)
	DEFAULT_SLOW_PERCENT = 0.5, -- Standard slow (50%)
	DEFAULT_SLOW_DURATION = 3, -- Seconds

	-- Squash jump
	SQUASH_HIT_RADIUS = 3, -- Studs
	SQUASH_JUMP_HEIGHT = 5, -- Studs
	SQUASH_JUMP_DURATION = 0.5, -- Seconds
})

-- ============================================
-- ECONOMY
-- ============================================

GameConstants.Economy = table.freeze({
	-- Starting resources
	STARTING_SUN = 50,

	-- Sky sun drops
	SKY_SUN_SPAWN_INTERVAL = 7, -- Seconds base
	SKY_SUN_SPAWN_VARIANCE = 3, -- Random ± seconds
	SKY_SUN_VALUE = 25,
	SKY_SUN_LIFETIME = 12, -- Seconds before despawn
	SKY_SUN_FALL_SPEED = 4, -- Studs/second
	SKY_SUN_SPAWN_HEIGHT = 25, -- Studs above ground

	-- Plant sun production (defaults)
	DEFAULT_SUN_PRODUCTION_INTERVAL = 24, -- Seconds
	DEFAULT_FIRST_SUN_DELAY = 7, -- Seconds
	DEFAULT_SUN_VALUE = 25,
	PLANT_SUN_LIFETIME = 12, -- Seconds

	-- Shovel
	SHOVEL_REFUND_PERCENT = 0.5, -- 50% cost refund

	-- Coins
	DEFAULT_ZOMBIE_COIN_REWARD = 5,
})

-- ============================================
-- PLANTS (Defaults for PlantData)
-- ============================================

GameConstants.PlantDefaults = table.freeze({
	Cooldown = 5,
	Health = 100,
	Damage = 0,
	AttackSpeed = 0,
	Range = 0,
})

GameConstants.ExplosiveDefaults = table.freeze({
	FUSE_TIME = 0.5, -- Seconds before explosion
	ARM_DURATION = 15, -- Seconds to arm
	TRIGGER_RADIUS = 2, -- Studs to trigger armed
})

GameConstants.MushroomDefaults = table.freeze({
	HIDE_RADIUS = 6, -- Studs (Scaredy-shroom)
	SUN_SHROOM_GROW_TIME = 120, -- Seconds to mature
	SUN_SHROOM_SMALL_VALUE = 15,
	SUN_SHROOM_LARGE_VALUE = 25,
})

GameConstants.ChomperDefaults = table.freeze({
	CHEW_DURATION = 42, -- Seconds to digest
	CHOMP_RANGE = 6, -- Studs
})

-- ============================================
-- ZOMBIES
-- ============================================

GameConstants.ZombieDefaults = table.freeze({
	Speed = 1.5,
	Damage = 20,
	AttackSpeed = 1.0,
})

GameConstants.BossDefaults = table.freeze({
	MINION_SPAWN_HEALTH_THRESHOLD = 0.5, -- Spawn at 50% HP
	MINION_SPAWN_OFFSET = 2, -- Studs behind boss
	MINION_SPACING = 2, -- Studs between minions
})

-- ============================================
-- WAVES
-- ============================================

GameConstants.Wave = table.freeze({
	FIRST_WAVE_DELAY = 20, -- Seconds before first wave
	WAVE_DELAY = 10, -- Seconds between waves
	COUNTDOWN_DURATION = 5, -- Seconds countdown
	WAVE_END_GRACE_PERIOD = 3, -- Seconds after last zombie

	-- Spawn intervals by phase
	TRICKLE_INTERVAL = 4, -- Seconds
	ASSAULT_INTERVAL = 2, -- Seconds
	FLAG_INTERVAL = 1.5, -- Seconds
})

-- ============================================
-- PLANT FOOD
-- ============================================

GameConstants.PlantFood = table.freeze({
	MAX_CHARGES = 3,
	GLOWING_ZOMBIE_CHANCE = 0.15, -- 15% chance for glowing zombie
	GUARANTEED_PER_WAVE = 1, -- Minimum glowing zombies per wave
})

-- ============================================
-- TRAPS
-- ============================================

GameConstants.Trap = table.freeze({
	SPIKEWEED_HIT_RADIUS = 3, -- Studs
	SPIKEWEED_DAMAGE_INTERVAL = 0.5, -- Seconds
	GARLIC_BITE_THRESHOLD = 3, -- Bites before lane switch
})

-- ============================================
-- GRID
-- ============================================

GameConstants.Grid = table.freeze({
	LANES = 5,
	COLUMNS = 9,
	CELL_WIDTH = 6, -- Studs
	CELL_DEPTH = 6, -- Studs
})

-- ============================================
-- PERFORMANCE
-- ============================================

GameConstants.Performance = table.freeze({
	POSITION_BROADCAST_INTERVAL = 0.1, -- Seconds
	MAX_ENTITIES = 200,
	MAX_PROJECTILES = 25,
})

return table.freeze(GameConstants)
