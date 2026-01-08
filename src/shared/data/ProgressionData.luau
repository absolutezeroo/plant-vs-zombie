--!strict
--[[
	ProgressionData.luau - Progression system configuration
	
	Defines unlock costs and coin rewards.
	Used by PlayerDataService and Shop UI.
	
	Note: Upgrades have been replaced by the Mutation system (see MutationData.luau)
]]

export type PlantUnlockInfo = {
	Cost: number,           -- Coins to unlock
	StarterPlant: boolean,  -- Free from start?
	Order: number,          -- Display order in shop
}

-- Plants unlock configuration (ALL 48 plants)
local PlantUnlocks: {[string]: PlantUnlockInfo} = {
	-- ============================================
	-- STARTER PLANTS (Free from start)
	-- ============================================
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
	
	-- ============================================
	-- TIER 1: Early Game (Levels 1-10, 50-200 coins)
	-- ============================================
	PotatoMine = {
		Cost = 50,
		StarterPlant = false,
		Order = 4,
	},
	PuffShroom = {
		Cost = 75,
		StarterPlant = false,
		Order = 5,
	},
	SunShroom = {
		Cost = 100,
		StarterPlant = false,
		Order = 6,
	},
	Chomper = {
		Cost = 150,
		StarterPlant = false,
		Order = 7,
	},
	SnowPea = {
		Cost = 200,
		StarterPlant = false,
		Order = 8,
	},
	
	-- ============================================
	-- TIER 2: Mid-Early Game (Levels 10-20, 250-500 coins)
	-- ============================================
	Repeater = {
		Cost = 250,
		StarterPlant = false,
		Order = 9,
	},
	FumeShroom = {
		Cost = 300,
		StarterPlant = false,
		Order = 10,
	},
	Squash = {
		Cost = 350,
		StarterPlant = false,
		Order = 11,
	},
	Garlic = {
		Cost = 400,
		StarterPlant = false,
		Order = 12,
	},
	CherryBomb = {
		Cost = 450,
		StarterPlant = false,
		Order = 13,
	},
	TallNut = {
		Cost = 500,
		StarterPlant = false,
		Order = 14,
	},
	
	-- ============================================
	-- TIER 3: Mid Game (Levels 20-30, 600-1000 coins)
	-- ============================================
	Threepeater = {
		Cost = 600,
		StarterPlant = false,
		Order = 15,
	},
	Jalapeno = {
		Cost = 700,
		StarterPlant = false,
		Order = 16,
	},
	Spikeweed = {
		Cost = 750,
		StarterPlant = false,
		Order = 17,
	},
	Torchwood = {
		Cost = 800,
		StarterPlant = false,
		Order = 18,
	},
	CabbagePult = {
		Cost = 850,
		StarterPlant = false,
		Order = 19,
	},
	Pumpkin = {
		Cost = 900,
		StarterPlant = false,
		Order = 20,
	},
	ScaredyShroom = {
		Cost = 950,
		StarterPlant = false,
		Order = 21,
	},
	HypnoShroom = {
		Cost = 1000,
		StarterPlant = false,
		Order = 22,
	},
	
	-- ============================================
	-- TIER 4: Mid-Late Game (Levels 30-40, 1200-2000 coins)
	-- ============================================
	SplitPea = {
		Cost = 1200,
		StarterPlant = false,
		Order = 23,
	},
	KernelPult = {
		Cost = 1300,
		StarterPlant = false,
		Order = 24,
	},
	Starfruit = {
		Cost = 1400,
		StarterPlant = false,
		Order = 25,
	},
	Cactus = {
		Cost = 1500,
		StarterPlant = false,
		Order = 26,
	},
	Blover = {
		Cost = 1600,
		StarterPlant = false,
		Order = 27,
	},
	SeaShroom = {
		Cost = 1700,
		StarterPlant = false,
		Order = 28,
	},
	TwinSunflower = {
		Cost = 1800,
		StarterPlant = false,
		Order = 29,
	},
	MelonPult = {
		Cost = 2000,
		StarterPlant = false,
		Order = 30,
	},
	
	-- ============================================
	-- TIER 5: Late Game (Levels 40-50, 2500-4000 coins)
	-- ============================================
	GatlingPea = {
		Cost = 2500,
		StarterPlant = false,
		Order = 31,
	},
	GloomShroom = {
		Cost = 2800,
		StarterPlant = false,
		Order = 32,
	},
	Cattail = {
		Cost = 3000,
		StarterPlant = false,
		Order = 33,
	},
	WinterMelon = {
		Cost = 3500,
		StarterPlant = false,
		Order = 34,
	},
	IceShroom = {
		Cost = 3800,
		StarterPlant = false,
		Order = 35,
	},
	DoomShroom = {
		Cost = 4000,
		StarterPlant = false,
		Order = 36,
	},
	
	-- ============================================
	-- TIER 6: End Game (Level 50+, 5000+ coins)
	-- ============================================
	CobCannon = {
		Cost = 5000,
		StarterPlant = false,
		Order = 37,
	},
	Marigold = {
		Cost = 5500,
		StarterPlant = false,
		Order = 38,
	},
	GoldMagnet = {
		Cost = 6000,
		StarterPlant = false,
		Order = 39,
	},
	Imitater = {
		Cost = 7500,
		StarterPlant = false,
		Order = 40,
	},
	
	-- ============================================
	-- UTILITY PLANTS (Various levels)
	-- ============================================
	LilyPad = {
		Cost = 100,
		StarterPlant = false,
		Order = 41,
	},
	FlowerPot = {
		Cost = 100,
		StarterPlant = false,
		Order = 42,
	},
	TangleKelp = {
		Cost = 300,
		StarterPlant = false,
		Order = 43,
	},
	GraveBuster = {
		Cost = 200,
		StarterPlant = false,
		Order = 44,
	},
	Plantern = {
		Cost = 400,
		StarterPlant = false,
		Order = 45,
	},
	UmbrellaLeaf = {
		Cost = 600,
		StarterPlant = false,
		Order = 46,
	},
	CoffeeBean = {
		Cost = 500,
		StarterPlant = false,
		Order = 47,
	},
	ExplodeONut = {
		Cost = 2000,
		StarterPlant = false,
		Order = 48,
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
-- Plants are unlocked for FREE at these levels (alternative to buying with coins)
local LevelRewards: {[number]: {Coins: number?, Gems: number?, UnlockPlant: string?}} = {
	-- Early milestones (quick rewards to hook players)
	[2] = { Coins = 50 },
	[3] = { Coins = 75, UnlockPlant = "PotatoMine" },
	[4] = { Coins = 100 },
	[5] = { Coins = 200, Gems = 15, UnlockPlant = "PuffShroom" },
	
	-- Building momentum
	[6] = { Coins = 150 },
	[7] = { Coins = 200, UnlockPlant = "SunShroom" },
	[8] = { Coins = 250 },
	[9] = { Coins = 300 },
	[10] = { Coins = 500, Gems = 25, UnlockPlant = "SnowPea" },
	
	-- Mid-early game
	[11] = { Coins = 300 },
	[12] = { Coins = 400, UnlockPlant = "Chomper" },
	[13] = { Coins = 400 },
	[14] = { Coins = 500 },
	[15] = { Coins = 750, Gems = 35, UnlockPlant = "Repeater" },
	
	-- Getting stronger
	[16] = { Coins = 500 },
	[17] = { Coins = 600, UnlockPlant = "FumeShroom" },
	[18] = { Coins = 600 },
	[19] = { Coins = 700 },
	[20] = { Coins = 1000, Gems = 50, UnlockPlant = "CherryBomb" },
	
	-- Mid game
	[21] = { Coins = 700 },
	[22] = { Coins = 800, UnlockPlant = "Squash" },
	[23] = { Coins = 800 },
	[24] = { Coins = 900, UnlockPlant = "TallNut" },
	[25] = { Coins = 1250, Gems = 60, UnlockPlant = "Threepeater" },
	
	-- Getting serious
	[26] = { Coins = 900 },
	[27] = { Coins = 1000, UnlockPlant = "Jalapeno" },
	[28] = { Coins = 1000 },
	[29] = { Coins = 1100, UnlockPlant = "Torchwood" },
	[30] = { Coins = 1500, Gems = 75, UnlockPlant = "HypnoShroom" },
	
	-- Late-mid game
	[31] = { Coins = 1100 },
	[32] = { Coins = 1200, UnlockPlant = "SplitPea" },
	[33] = { Coins = 1200 },
	[34] = { Coins = 1300, UnlockPlant = "Starfruit" },
	[35] = { Coins = 1750, Gems = 90, UnlockPlant = "Cactus" },
	
	-- Late game
	[36] = { Coins = 1300 },
	[37] = { Coins = 1400, UnlockPlant = "TwinSunflower" },
	[38] = { Coins = 1500 },
	[39] = { Coins = 1600, UnlockPlant = "MelonPult" },
	[40] = { Coins = 2500, Gems = 100, UnlockPlant = "GatlingPea" },
	
	-- End game
	[41] = { Coins = 1700 },
	[42] = { Coins = 1800, UnlockPlant = "GloomShroom" },
	[43] = { Coins = 1900 },
	[44] = { Coins = 2000, UnlockPlant = "Cattail" },
	[45] = { Coins = 3000, Gems = 150, UnlockPlant = "WinterMelon" },
	
	-- Prestige levels
	[46] = { Coins = 2500 },
	[47] = { Coins = 3000, UnlockPlant = "IceShroom" },
	[48] = { Coins = 3500, UnlockPlant = "DoomShroom" },
	[49] = { Coins = 4000 },
	[50] = { Coins = 10000, Gems = 500, UnlockPlant = "CobCannon" },
}

-- Freeze tables
table.freeze(PlantUnlocks)
table.freeze(ZombieCoinRewards)
table.freeze(LevelRewards)

return {
	PlantUnlocks = PlantUnlocks,
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
