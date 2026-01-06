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

-- Freeze tables
table.freeze(PlantUnlocks)
table.freeze(Upgrades)
table.freeze(ZombieCoinRewards)

return {
	PlantUnlocks = PlantUnlocks,
	Upgrades = Upgrades,
	ZombieCoinRewards = ZombieCoinRewards,
	VICTORY_BONUS_PER_WAVE = VICTORY_BONUS_PER_WAVE,
}
