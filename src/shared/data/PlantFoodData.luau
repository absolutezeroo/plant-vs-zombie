--!strict
--[[
	PlantFoodData.luau - Plant Food ultimate ability definitions
	
	Each plant has a unique "ultimate" ability when Plant Food is used.
	Abilities range from burst attacks to instant sun production.
]]

export type PlantFoodAbility = {
	Name: string,
	Description: string,
	Duration: number,       -- Duration of effect in seconds (0 = instant)
	
	-- Attack abilities
	RapidFireShots: number?,  -- Number of rapid shots (Peashooter, Repeater)
	ShotInterval: number?,    -- Time between rapid shots
	
	-- Production abilities
	InstantSun: number?,      -- Instant sun production (Sunflower)
	
	-- Defensive abilities
	ArmorBoost: number?,      -- HP boost for duration (Wall-nut)
	ReflectDamage: boolean?,  -- Reflects damage to attackers
	
	-- Explosive abilities
	InstantExplode: boolean?, -- Explodes immediately (CherryBomb)
	ExplosionRadius: number?, -- Override explosion radius
	
	-- Special abilities
	FreezeAll: boolean?,      -- Freezes all zombies on screen (Snow Pea)
	FreezeDuration: number?,  -- Duration of freeze effect
	
	-- Catapult abilities
	MassiveLob: number?,      -- Number of massive projectiles
	SplashRadius: number?,    -- Splash damage radius
}

local PlantFoodData: {[string]: PlantFoodAbility} = {
	-- ============================================
	-- MVP Plants
	-- ============================================
	
	Sunflower = {
		Name = "Sun Burst",
		Description = "Produces 150 sun instantly",
		Duration = 0,
		InstantSun = 150,
	},
	
	Peashooter = {
		Name = "Gatling Mode",
		Description = "Fires 60 peas rapidly",
		Duration = 3,
		RapidFireShots = 60,
		ShotInterval = 0.05,
	},
	
	WallNut = {
		Name = "Steel Shell",
		Description = "Gains 4000 HP armor for 10 seconds",
		Duration = 10,
		ArmorBoost = 4000,
		ReflectDamage = true,
	},
	
	-- ============================================
	-- Shooter Plants
	-- ============================================
	
	SnowPea = {
		Name = "Blizzard",
		Description = "Freezes all zombies for 5 seconds",
		Duration = 0,
		FreezeAll = true,
		FreezeDuration = 5,
	},
	
	Repeater = {
		Name = "Mega Gatling",
		Description = "Fires 120 peas rapidly",
		Duration = 3,
		RapidFireShots = 120,
		ShotInterval = 0.025,
	},
	
	Threepeater = {
		Name = "Pea Storm",
		Description = "All lanes get 30 rapid peas",
		Duration = 2,
		RapidFireShots = 30,
		ShotInterval = 0.066,
	},
	
	GatlingPea = {
		Name = "Pea Apocalypse",
		Description = "Fires 200 peas at extreme speed",
		Duration = 4,
		RapidFireShots = 200,
		ShotInterval = 0.02,
	},
	
	Cactus = {
		Name = "Spike Storm",
		Description = "Fires piercing spikes in all lanes",
		Duration = 2,
		RapidFireShots = 50,
		ShotInterval = 0.04,
	},
	
	-- ============================================
	-- Explosive Plants
	-- ============================================
	
	CherryBomb = {
		Name = "Instant Kaboom",
		Description = "Explodes immediately with larger radius",
		Duration = 0,
		InstantExplode = true,
		ExplosionRadius = 12,
	},
	
	PotatoMine = {
		Name = "Armed & Ready",
		Description = "Arms instantly and explodes with larger radius",
		Duration = 0,
		InstantExplode = true,
		ExplosionRadius = 6,
	},
	
	-- ============================================
	-- Catapult Plants
	-- ============================================
	
	CabbagePult = {
		Name = "Cabbage Barrage",
		Description = "Launches 10 giant cabbages",
		Duration = 2,
		MassiveLob = 10,
		SplashRadius = 4,
	},
	
	KernelPult = {
		Name = "Butter Blitz",
		Description = "Launches 10 guaranteed butter (stuns)",
		Duration = 2,
		MassiveLob = 10,
	},
	
	MelonPult = {
		Name = "Melon Storm",
		Description = "Launches 8 giant melons with huge splash",
		Duration = 2,
		MassiveLob = 8,
		SplashRadius = 6,
	},
	
	WinterMelon = {
		Name = "Frozen Melon Rain",
		Description = "Launches 8 giant frozen melons",
		Duration = 2,
		MassiveLob = 8,
		SplashRadius = 6,
		FreezeAll = false,
		FreezeDuration = 5,
	},
}

-- Helper function to get ability or nil
function PlantFoodData.GetAbility(plantType: string): PlantFoodAbility?
	return PlantFoodData[plantType]
end

return PlantFoodData
