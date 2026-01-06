--!strict
--[[
	ProgressionData.luau - Progression system configuration
	
	Defines unlock costs, upgrade costs, and coin rewards.
	Used by PlayerDataService and Shop UI.
]]

export type PlantUnlockInfo = {
	Cost: number,           -- Coins to unlock
	StarterPlant: boolean,  -- Free from start?
	Order: number,          -- Display order in shop
}

export type UpgradeInfo = {
	MaxLevel: number,
	CostPerLevel: {number}, -- Cost for each level [1, 2, 3]
	Bonus: number,          -- Percentage bonus per level
}

-- Plants unlock configuration
local PlantUnlocks: {[string]: PlantUnlockInfo} = {
	-- Starter plants (free)
	Sunflower = {
		Cost = 0,
		StarterPlant = true,
		Order = 1,
	},
	Peashooter = {
		Cost = 0,
		StarterPlant = true,
		Order = 2,
	},
	WallNut = {
		Cost = 0,
		StarterPlant = true,
		Order = 3,
	},
	
	-- Unlockable plants
	PotatoMine = {
		Cost = 100,
		StarterPlant = false,
		Order = 4,
	},
	SnowPea = {
		Cost = 250,
		StarterPlant = false,
		Order = 5,
	},
	CherryBomb = {
		Cost = 300,
		StarterPlant = false,
		Order = 6,
	},
	Repeater = {
		Cost = 500,
		StarterPlant = false,
		Order = 7,
	},
}

-- Upgrade configurations
local Upgrades: {[string]: UpgradeInfo} = {
	Damage = {
		MaxLevel = 3,
		CostPerLevel = {150, 300, 500},
		Bonus = 0.15, -- +15% per level
	},
	Health = {
		MaxLevel = 3,
		CostPerLevel = {100, 200, 400},
		Bonus = 0.25, -- +25% per level
	},
	Cooldown = {
		MaxLevel = 3,
		CostPerLevel = {200, 400, 750},
		Bonus = 0.20, -- -20% per level (reduction)
	},
}

-- Coin rewards per zombie type
local ZombieCoinRewards: {[string]: number} = {
	Basic = 5,
	Cone = 8,
	Bucket = 12,
	Pole = 10,
	Newspaper = 7,
	Football = 20,
	Imp = 3,
	Flag = 15,
}

-- Victory bonus (multiplied by wave number)
local VICTORY_BONUS_PER_WAVE = 25

-- XP and Level configuration
local XP_PER_ZOMBIE = 5           -- Base XP per zombie killed
local XP_PER_WAVE = 50            -- XP bonus per wave completed
local XP_VICTORY_BONUS = 200      -- XP bonus for winning
local XP_PER_STAR = 25            -- Bonus XP per star earned

-- Level curve: XP required = BASE * (MULTIPLIER ^ (level - 1))
local LEVEL_XP_BASE = 100         -- XP for level 2
local LEVEL_XP_MULTIPLIER = 1.5   -- Each level needs 50% more XP
local MAX_LEVEL = 50              -- Maximum player level

-- Gem rewards
local GEMS_PER_LEVEL_UP = 10      -- Gems earned per level up
local GEMS_VICTORY_3_STAR = 5     -- Gems for 3-star victory
local GEMS_FIRST_CLEAR = 25       -- Gems for first-time stage clear

-- Calculate XP required for a specific level
local function getXPForLevel(level: number): number
	if level <= 1 then return 0 end
	if level > MAX_LEVEL then return math.huge end
	return math.floor(LEVEL_XP_BASE * math.pow(LEVEL_XP_MULTIPLIER, level - 2))
end

-- Calculate total XP needed to reach a level (cumulative)
local function getTotalXPForLevel(level: number): number
	local total = 0
	for lvl = 2, level do
		total += getXPForLevel(lvl)
	end
	return total
end

-- Level up rewards (coins, gems, unlocks)
local LevelRewards: {[number]: {Coins: number?, Gems: number?, UnlockPlant: string?}} = {
	[5] = { Coins = 500, Gems = 20 },
	[10] = { Coins = 1000, Gems = 50, UnlockPlant = "SnowPea" },
	[15] = { Coins = 1500, Gems = 50 },
	[20] = { Coins = 2000, Gems = 100, UnlockPlant = "Repeater" },
	[25] = { Coins = 2500, Gems = 100 },
	[30] = { Coins = 3000, Gems = 150, UnlockPlant = "CherryBomb" },
	[40] = { Coins = 5000, Gems = 200 },
	[50] = { Coins = 10000, Gems = 500 },
}

-- Freeze tables
table.freeze(PlantUnlocks)
table.freeze(Upgrades)
table.freeze(ZombieCoinRewards)
table.freeze(LevelRewards)

return {
	PlantUnlocks = PlantUnlocks,
	Upgrades = Upgrades,
	ZombieCoinRewards = ZombieCoinRewards,
	LevelRewards = LevelRewards,
	VICTORY_BONUS_PER_WAVE = VICTORY_BONUS_PER_WAVE,
	
	-- XP/Level constants
	XP_PER_ZOMBIE = XP_PER_ZOMBIE,
	XP_PER_WAVE = XP_PER_WAVE,
	XP_VICTORY_BONUS = XP_VICTORY_BONUS,
	XP_PER_STAR = XP_PER_STAR,
	MAX_LEVEL = MAX_LEVEL,
	
	-- Gem constants
	GEMS_PER_LEVEL_UP = GEMS_PER_LEVEL_UP,
	GEMS_VICTORY_3_STAR = GEMS_VICTORY_3_STAR,
	GEMS_FIRST_CLEAR = GEMS_FIRST_CLEAR,
	
	-- Level functions
	GetXPForLevel = getXPForLevel,
	GetTotalXPForLevel = getTotalXPForLevel,
}
