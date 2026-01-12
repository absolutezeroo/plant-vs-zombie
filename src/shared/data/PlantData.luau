--!strict
--[[
	PlantData.luau - Plant type definitions and stats
	
	Central lookup table for all plant properties.
	Used by PlacementSystem (cost validation) and UI (card display).
	
	NOTE: Access via PlantData.Peashooter or PlantData.GetStats("Peashooter")
	Both apply LiveConfigService overrides for live tuning.
	Use PlantData.GetStatsRaw("Peashooter") for factory defaults.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sift = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Sift"))
local LiveConfigService = require(Shared.services.LiveConfigService)

export type PlantStats = {
	Name: string,
	Cost: number,
	Cooldown: number, -- Seconds before can place again
	Health: number,
	Damage: number, -- Per projectile or per tick
	AttackSpeed: number, -- Attacks per second (0 for non-attackers)
	Range: number, -- Attack range in studs (0 for lane-wide)
	Description: string,
	Category: string, -- "Attacker", "Producer", "Defender", "Special"

	-- Behavior flags (data-driven)
	CanShoot: boolean?, -- Can fire projectiles at zombies
	IsFrozen: boolean?, -- Projectiles apply slow effect
	IsRepeater: boolean?, -- Fires double projectiles
	IsExplosive: boolean?, -- Is a one-time explosion plant
	ExplodesOnPlace: boolean?, -- Explodes immediately after fuse (CherryBomb)
	NeedsArming: boolean?, -- Requires arming time before active (PotatoMine)
	ProducesSun: boolean?, -- Produces sun periodically

	-- Sun Producer stats (for ProducesSun plants)
	SunProductionInterval: number?, -- Seconds between sun production (default 24)
	FirstSunDelay: number?, -- Seconds before first sun (default 7)
	SunValue: number?, -- Sun value per production (default 25)

	-- Projectile stats (for CanShoot plants)
	SlowPercent: number?, -- Slow multiplier for IsFrozen (default 0.5)
	SlowDuration: number?, -- Slow duration in seconds (default 3)
	ShotDelay: number?, -- Delay between multi-shots for IsRepeater (default 0.1)
	ProjectileSpawnOffset: Vector3?, -- Offset from plant center for projectile spawn (default Vector3.new(2, 2.5, 0))

	-- Projectile visual variant (data-driven, replaces hardcoded switch)
	ProjectileVariant: string?, -- "Pea", "SnowPea", "FirePea", "Cabbage", "Kernel", "Butter", "Melon", "Spore", "Fume", "Star", "Spike", "Thorn"

	-- Advanced projectile stats
	IsCatapult: boolean?, -- Lobs projectiles in an arc (Cabbage-pult, Melon-pult)
	HasSplash: boolean?, -- Projectile deals splash damage
	SplashRadius: number?, -- Radius of splash damage
	PiercesShields: boolean?, -- Projectile ignores shields (Fume-shroom)
	CanStun: boolean?, -- Can stun zombies (Kernel-pult butter)
	StunChance: number?, -- Chance to stun (0-1)
	StunDuration: number?, -- Stun duration in seconds
	StunProjectileVariant: string?, -- Variant when stun procs ("Butter" for KernelPult)
	CanHitFlying: boolean?, -- Can hit flying zombies (Cactus, Cattail)
	ShotsPerBurst: number?, -- Number of shots per attack (Repeater=2, GatlingPea=4)
	ShootsMultiDirection: boolean?, -- Shoots in multiple directions (Starfruit)
	IsThreeLane: boolean?, -- Shoots in 3 lanes (Threepeater)
	ShootsBehind: boolean?, -- Also shoots behind (Split Pea)

	-- Explosive stats (for IsExplosive plants)
	FuseTime: number?, -- Seconds before explosion for ExplodesOnPlace (default 0.5)
	ArmDuration: number?, -- Seconds to arm for NeedsArming (default 15)
	TriggerRadius: number?, -- Radius to trigger armed explosion (default 2)

	-- Platform/Water requirements (data-driven placement validation)
	IsPlatform: boolean?, -- Is a platform plant (LilyPad, FlowerPot)
	IsWaterPlatform: boolean?, -- Platform for water lanes (LilyPad)
	IsGroundPlatform: boolean?, -- Platform for roof/ground (FlowerPot)
	AllowsPlantOnTop: boolean?, -- Allows another plant to be placed on top
	RequiresWater: boolean?, -- Must be placed on water lane (SeaShroom, TangleKelp)
	RequiresLilyPad: boolean?, -- Must be placed on a LilyPad (Cattail)

	-- Mushroom behavior (data-driven day/night cycle)
	IsMushroom: boolean?, -- Is a mushroom plant
	SleepsDuringDay: boolean?, -- Sleeps on day maps (needs Coffee Bean to wake)
	GrowsOverTime: boolean?, -- Grows larger over time (Sun-shroom)
	HidesWhenNear: boolean?, -- Hides when zombies are near (Scaredy-shroom)
	HideRadius: number?, -- Distance at which to hide (default 6 studs)

	-- Stacking behavior (for plants that can be placed on top of others)
	CanStackOnPlant: boolean?, -- Can be placed on top of Pumpkin/shell plants
	CanStackOnMushroom: boolean?, -- Can be placed on sleeping mushrooms (CoffeeBean)
	WakesMushrooms: boolean?, -- Wakes sleeping mushrooms when stacked
	IsShell: boolean?, -- Is a protective shell plant (Pumpkin)
}

local PlantData: { [string]: PlantStats } = {
	-- ============================================
	-- MVP Plants (Epic 2)
	-- ============================================

	Sunflower = {
		Name = "Sunflower",
		Cost = 50, -- Increased from 25
		Cooldown = 7, -- Increased from 5
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Produces 25 sun every 30 seconds",
		Category = "Producer",
		-- Behavior
		ProducesSun = true,
		SunProductionInterval = 30, -- Slowed from 24
		FirstSunDelay = 12, -- Increased from 7
		SunValue = 25,
		SunCount = 1, -- Number of suns produced per cycle
	},

	Peashooter = {
		Name = "Peashooter",
		Cost = 100,
		Cooldown = 7,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.0, -- Nerfed from 1.5
		Range = 0,
		Description = "Shoots peas at zombies",
		Category = "Attacker",
		CanShoot = true,
		ProjectileVariant = "Pea",
	},

	WallNut = {
		Name = "Wall-nut",
		Cost = 50,
		Cooldown = 30, -- Increased from 20
		Health = 400, -- 10 zombie attacks to destroy
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Blocks zombies with high health",
		Category = "Defender",
	},

	-- ============================================
	-- Future Plants (Epic 4+)
	-- ============================================

	SnowPea = {
		Name = "Snow Pea",
		Cost = 175,
		Cooldown = 7,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.0, -- Nerfed from 1.5
		Range = 0,
		Description = "Shoots frozen peas that slow zombies",
		Category = "Attacker",
		-- Behavior
		CanShoot = true,
		IsFrozen = true,
		ProjectileVariant = "SnowPea",
		-- Frozen projectile stats
		SlowPercent = 0.5,
		SlowDuration = 2, -- Reduced from 3
	},

	CherryBomb = {
		Name = "Cherry Bomb",
		Cost = 150,
		Cooldown = 45, -- Increased from 30
		Health = 1,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 9, -- Explosion radius in studs
		Description = "Explodes and destroys nearby zombies",
		Category = "Special",
		-- Behavior
		IsExplosive = true,
		ExplodesOnPlace = true,
		-- Explosive stats
		FuseTime = 0.5,
	},

	PotatoMine = {
		Name = "Potato Mine",
		Cost = 25,
		Cooldown = 25, -- Increased from 20
		Health = 100,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 0,
		Description = "Arms after 20 seconds, explodes on contact",
		Category = "Special",
		-- Behavior
		IsExplosive = true,
		NeedsArming = true,
		-- Armed explosive stats
		ArmDuration = 20, -- Increased from 15
		TriggerRadius = 2,
	},

	Repeater = {
		Name = "Repeater",
		Cost = 200,
		Cooldown = 7,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.0, -- Nerfed from 1.5
		Range = 0,
		Description = "Fires two peas at a time",
		Category = "Attacker",
		-- Behavior
		CanShoot = true,
		IsRepeater = true,
		ProjectileVariant = "Pea",
		-- Multi-shot stats
		ShotsPerBurst = 2,
		ShotDelay = 0.1,
	},

	-- ============================================
	-- Shooter Plants
	-- ============================================

	Threepeater = {
		Name = "Threepeater",
		Cost = 325,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Shoots peas in three lanes",
		Category = "Attacker",
		CanShoot = true,
		IsThreeLane = true,
		ProjectileVariant = "Pea",
	},

	SplitPea = {
		Name = "Split Pea",
		Cost = 125,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Shoots peas forward and backward",
		Category = "Attacker",
		CanShoot = true,
		ShootsBehind = true,
		ProjectileVariant = "Pea",
	},

	GatlingPea = {
		Name = "Gatling Pea",
		Cost = 250,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Shoots four peas at a time",
		Category = "Attacker",
		CanShoot = true,
		IsRepeater = true,
		ProjectileVariant = "Pea",
		ShotsPerBurst = 4,
		ShotDelay = 0.08,
	},

	Starfruit = {
		Name = "Starfruit",
		Cost = 125,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Shoots stars in 5 directions",
		Category = "Attacker",
		CanShoot = true,
		ShootsMultiDirection = true,
		ProjectileVariant = "Star",
	},

	Cactus = {
		Name = "Cactus",
		Cost = 125,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Shoots spikes, can hit balloons",
		Category = "Attacker",
		CanShoot = true,
		CanHitFlying = true,
		ProjectileVariant = "Spike",
	},

	Cattail = {
		Name = "Cattail",
		Cost = 225,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Homing spikes, targets any lane",
		Category = "Attacker",
		CanShoot = true,
		IsHoming = true,
		ProjectileVariant = "Thorn",
		RequiresLilyPad = true,
	},

	-- ============================================
	-- Catapult Plants
	-- ============================================

	CabbagePult = {
		Name = "Cabbage-pult",
		Cost = 100,
		Cooldown = 5,
		Health = 100,
		Damage = 40,
		AttackSpeed = 1.0,
		Range = 0,
		Description = "Lobs cabbages over shields",
		Category = "Attacker",
		CanShoot = true,
		IsCatapult = true,
		ProjectileVariant = "Cabbage",
	},

	KernelPult = {
		Name = "Kernel-pult",
		Cost = 100,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.0,
		Range = 0,
		Description = "Lobs kernels and butter",
		Category = "Attacker",
		CanShoot = true,
		IsCatapult = true,
		ProjectileVariant = "Kernel",
		CanStun = true,
		StunChance = 0.2,
		StunDuration = 4,
		StunProjectileVariant = "Butter",
	},

	MelonPult = {
		Name = "Melon-pult",
		Cost = 300,
		Cooldown = 5,
		Health = 100,
		Damage = 80,
		AttackSpeed = 0.75,
		Range = 0,
		Description = "Lobs heavy melons with splash",
		Category = "Attacker",
		CanShoot = true,
		IsCatapult = true,
		ProjectileVariant = "Melon",
		HasSplash = true,
		SplashRadius = 3,
	},

	WinterMelon = {
		Name = "Winter Melon",
		Cost = 500,
		Cooldown = 5,
		Health = 100,
		Damage = 80,
		AttackSpeed = 0.75,
		Range = 0,
		Description = "Frozen melons that slow and splash",
		Category = "Attacker",
		CanShoot = true,
		IsCatapult = true,
		IsFrozen = true,
		ProjectileVariant = "WinterMelon",
		HasSplash = true,
		SplashRadius = 3,
		SlowPercent = 0.5,
		SlowDuration = 3,
	},

	CobCannon = {
		Name = "Cob Cannon",
		Cost = 500,
		Cooldown = 30,
		Health = 300,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 0,
		Description = "Click to launch devastating corn cob",
		Category = "Special",
		IsManualFire = true,
		HasSplash = true,
		SplashRadius = 9,
		RequiresTwoKernelPults = true,
	},

	-- ============================================
	-- Mushroom Plants
	-- ============================================

	PuffShroom = {
		Name = "Puff-shroom",
		Cost = 0,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 18, -- Short range (3 cells)
		Description = "Free, short-range spore shooter",
		Category = "Attacker",
		CanShoot = true,
		ProjectileVariant = "Spore",
		IsMushroom = true,
		SleepsDuringDay = true,
	},

	SeaShroom = {
		Name = "Sea-shroom",
		Cost = 0,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 18,
		Description = "Aquatic puff-shroom",
		Category = "Attacker",
		CanShoot = true,
		ProjectileVariant = "Spore",
		IsMushroom = true,
		SleepsDuringDay = true,
		RequiresWater = true,
	},

	FumeShroom = {
		Name = "Fume-shroom",
		Cost = 75,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 24, -- 4 cells
		Description = "Fumes pierce shields",
		Category = "Attacker",
		CanShoot = true,
		ProjectileVariant = "Fume",
		IsMushroom = true,
		SleepsDuringDay = true,
		PiercesShields = true,
	},

	ScaredyShroom = {
		Name = "Scaredy-shroom",
		Cost = 25,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Long range, hides when zombies near",
		Category = "Attacker",
		CanShoot = true,
		ProjectileVariant = "Spore",
		IsMushroom = true,
		SleepsDuringDay = true,
		HidesWhenNear = true,
		HideRadius = 6,
	},

	SunShroom = {
		Name = "Sun-shroom",
		Cost = 25,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Produces small sun (15), grows to normal (25) after 2 minutes",
		Category = "Producer",
		IsMushroom = true,
		SleepsDuringDay = true,
		ProducesSun = true,
		SunProductionInterval = 24,
		FirstSunDelay = 7,
		SunValue = 15, -- Starts small
		SunValueGrown = 25, -- After growth time
		GrowthTime = 120, -- 2 minutes to grow
		SunCount = 1,
	},

	HypnoShroom = {
		Name = "Hypno-shroom",
		Cost = 75,
		Cooldown = 20,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Hypnotizes zombie that eats it",
		Category = "Special",
		IsMushroom = true,
		SleepsDuringDay = true,
		HypnotizesOnDeath = true,
	},

	IceShroom = {
		Name = "Ice-shroom",
		Cost = 75,
		Cooldown = 40,
		Health = 1,
		Damage = 20,
		AttackSpeed = 0,
		Range = 0,
		Description = "Freezes all zombies temporarily",
		Category = "Special",
		IsMushroom = true,
		SleepsDuringDay = true,
		IsExplosive = true,
		ExplodesOnPlace = true,
		FreezesAll = true,
		FreezeDuration = 4,
	},

	DoomShroom = {
		Name = "Doom-shroom",
		Cost = 125,
		Cooldown = 50,
		Health = 1,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 15, -- Large explosion radius
		Description = "Massive explosion, leaves crater",
		Category = "Special",
		IsMushroom = true,
		SleepsDuringDay = true,
		IsExplosive = true,
		ExplodesOnPlace = true,
		FuseTime = 1.0,
		LeavesCrater = true,
	},

	GloomShroom = {
		Name = "Gloom-shroom",
		Cost = 150,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 2.0,
		Range = 6, -- 1 cell radius (8 directions)
		Description = "Releases fumes in all directions",
		Category = "Attacker",
		IsMushroom = true,
		SleepsDuringDay = true,
		CanShoot = true,
		ProjectileVariant = "Fume",
		ShootsAllDirections = true,
		PiercesShields = true,
	},

	-- ============================================
	-- Defensive Plants
	-- ============================================

	TallNut = {
		Name = "Tall-nut",
		Cost = 125,
		Cooldown = 20,
		Health = 800,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Tall wall, blocks pole vaulters",
		Category = "Defender",
		BlocksJumpers = true,
	},

	Pumpkin = {
		Name = "Pumpkin",
		Cost = 125,
		Cooldown = 20,
		Health = 400,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Protects plant inside",
		Category = "Defender",
		IsShell = true,
		CanStackOnPlant = true,
	},

	Garlic = {
		Name = "Garlic",
		Cost = 50,
		Cooldown = 5,
		Health = 200,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Zombies switch lanes after biting",
		Category = "Defender",
		DivertsZombies = true,
	},

	-- ============================================
	-- Instant Kill Plants
	-- ============================================

	Chomper = {
		Name = "Chomper",
		Cost = 150,
		Cooldown = 5,
		Health = 100,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 6, -- 1 cell
		Description = "Eats zombie, chews for 42 seconds",
		Category = "Attacker",
		IsInstantKill = true,
		ChewDuration = 42,
	},

	Squash = {
		Name = "Squash",
		Cost = 50,
		Cooldown = 20,
		Health = 100,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 6,
		Description = "Jumps and squashes nearby zombie",
		Category = "Special",
		IsInstantKill = true,
		JumpsToTarget = true,
	},

	Jalapeno = {
		Name = "Jalapeno",
		Cost = 125,
		Cooldown = 40,
		Health = 1,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 0,
		Description = "Destroys entire lane",
		Category = "Special",
		IsExplosive = true,
		ExplodesOnPlace = true,
		IsLaneWide = true,
		FuseTime = 0.5,
	},

	TangleKelp = {
		Name = "Tangle Kelp",
		Cost = 25,
		Cooldown = 20,
		Health = 100,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 0,
		Description = "Pulls zombie underwater",
		Category = "Special",
		IsInstantKill = true,
		RequiresWater = true,
	},

	-- ============================================
	-- Support Plants
	-- ============================================

	TwinSunflower = {
		Name = "Twin Sunflower",
		Cost = 150,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Produces 2 suns at once (50 total)",
		Category = "Producer",
		ProducesSun = true,
		SunProductionInterval = 24,
		FirstSunDelay = 7,
		SunValue = 25, -- Each sun is worth 25
		SunCount = 2, -- Produces 2 suns per cycle!
	},

	Marigold = {
		Name = "Marigold",
		Cost = 50,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Produces coins",
		Category = "Producer",
		ProducesCoins = true,
		CoinProductionInterval = 24,
	},

	GoldMagnet = {
		Name = "Gold Magnet",
		Cost = 50,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Collects coins automatically",
		Category = "Support",
		CollectsCoins = true,
	},

	Torchwood = {
		Name = "Torchwood",
		Cost = 175,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Peas passing through become fireballs",
		Category = "Support",
		EnhancesPeas = true,
		FireDamageMultiplier = 2,
	},

	Plantern = {
		Name = "Plantern",
		Cost = 25,
		Cooldown = 20,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Illuminates fog",
		Category = "Support",
		RemovesFog = true,
		FogRadius = 36,
	},

	Blover = {
		Name = "Blover",
		Cost = 100,
		Cooldown = 5,
		Health = 1,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 0,
		Description = "Blows away fog and balloons",
		Category = "Special",
		IsInstant = true,
		RemovesFog = true,
		RemovesFlying = true,
	},

	UmbrellaLeaf = {
		Name = "Umbrella Leaf",
		Cost = 100,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 6, -- Protects 3x3 area
		Description = "Deflects catapult zombies",
		Category = "Defender",
		DeflectsProjectiles = true,
	},

	CoffeeBean = {
		Name = "Coffee Bean",
		Cost = 75,
		Cooldown = 5,
		Health = 1,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Wakes up mushrooms",
		Category = "Support",
		IsInstant = true,
		WakesMushrooms = true,
		CanStackOnMushroom = true,
	},

	-- ============================================
	-- Platform/Special Plants
	-- ============================================

	LilyPad = {
		Name = "Lily Pad",
		Cost = 25,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Platform for water lanes",
		Category = "Support",
		IsPlatform = true,
		IsWaterPlatform = true,
		AllowsPlantOnTop = true,
	},

	FlowerPot = {
		Name = "Flower Pot",
		Cost = 25,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Platform for roof levels",
		Category = "Support",
		IsPlatform = true,
		IsGroundPlatform = true,
		AllowsPlantOnTop = true,
	},

	GraveBuster = {
		Name = "Grave Buster",
		Cost = 75,
		Cooldown = 5,
		Health = 1,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Removes graves",
		Category = "Special",
		IsInstant = true,
		RemovesGraves = true,
	},

	Spikeweed = {
		Name = "Spikeweed",
		Cost = 100,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 0,
		Range = 0,
		Description = "Damages zombies walking over",
		Category = "Attacker",
		IsTrap = true,
		DamagesOnWalk = true,
		PopsTires = true,
	},

	Imitater = {
		Name = "Imitater",
		Cost = 0, -- Adds to imitated plant cost
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Becomes another plant",
		Category = "Special",
		IsImitater = true,
	},

	ExplodeONut = {
		Name = "Explode-o-nut",
		Cost = 50,
		Cooldown = 20,
		Health = 400,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 9,
		Description = "Wall-nut that explodes when eaten",
		Category = "Defender",
		IsExplosive = true,
		ExplodesOnDeath = true,
	},
}

-- Freeze raw data to prevent runtime modification
table.freeze(PlantData)
for _, stats in PlantData do
	table.freeze(stats)
end

-- ============================================
-- API MODULE
-- ============================================

local PlantDataModule = {}

-- Raw data table (factory defaults, frozen)
PlantDataModule.RawData = PlantData

--[[
	Get all plant types (factory defaults).
	@return Array of plant type names
]]
function PlantDataModule.GetAllTypes(): { string }
	local types: { string } = {}
	for plantType, _ in PlantData do
		table.insert(types, plantType)
	end
	return types
end

--[[
	Get stats for a specific plant type with LiveConfigService overrides applied.
	
	@param plantType The plant type (e.g., "Peashooter", "Sunflower")
	@return The effective stats with cloud config applied, or nil if not found
]]
function PlantDataModule.GetStats(plantType: string): PlantStats?
	local baseStats = PlantData[plantType]
	if not baseStats then
		return nil
	end

	-- Get plant-specific overrides (0 = use base value)
	local costOverride = LiveConfigService.GetFloat(`Plant_{plantType}_Cost`, 0)
	local damageOverride = LiveConfigService.GetFloat(`Plant_{plantType}_Damage`, 0)
	local cooldownOverride = LiveConfigService.GetFloat(`Plant_{plantType}_Cooldown`, 0)
	local healthOverride = LiveConfigService.GetFloat(`Plant_{plantType}_Health`, 0)

	-- Get global plant multiplier
	local globalDamageMult = LiveConfigService.GetMultiplier("Global_PlantDamage")

	-- Build overrides table only for non-zero values
	local overrides: { [string]: any } = {}

	-- Apply cost override (direct replacement if set)
	if costOverride > 0 then
		overrides.Cost = math.floor(costOverride)
	end

	-- Apply cooldown override (direct replacement if set)
	if cooldownOverride > 0 then
		overrides.Cooldown = cooldownOverride
	end

	-- Apply health override (direct replacement if set)
	if healthOverride > 0 then
		overrides.Health = math.floor(healthOverride)
	end

	-- Apply damage: combine override with global multiplier
	local effectiveDamage = if damageOverride > 0 then damageOverride else baseStats.Damage
	overrides.Damage = math.floor(effectiveDamage * globalDamageMult)

	-- Merge with base stats (immutable)
	return Sift.Dictionary.merge(baseStats, overrides)
end

--[[
	Get raw stats for a specific plant type WITHOUT LiveConfigService overrides.
	
	@param plantType The plant type (e.g., "Peashooter", "Sunflower")
	@return The factory default stats, or nil if not found
]]
function PlantDataModule.GetStatsRaw(plantType: string): PlantStats?
	return PlantData[plantType]
end

--[[
	Check if a plant type exists.
	
	@param plantType The plant type to check
	@return true if the plant type exists
]]
function PlantDataModule.Exists(plantType: string): boolean
	return PlantData[plantType] ~= nil
end

-- ============================================
-- METATABLE FOR BACKWARDS COMPATIBILITY
-- ============================================
-- Allows PlantData.Peashooter syntax to still work
-- Redirects to GetStats() for live config support

setmetatable(PlantDataModule :: any, {
	__index = function(_, key: string): PlantStats?
		-- Skip known function/property names
		if key == "GetStats" or key == "GetStatsRaw" or key == "GetAllTypes" or key == "Exists" or key == "RawData" then
			return nil
		end
		-- Redirect to GetStats for any plant type access
		return PlantDataModule.GetStats(key)
	end,
})

return PlantDataModule
