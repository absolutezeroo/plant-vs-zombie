--!strict
--[[
	PlantData.luau - Plant type definitions and stats
	
	Central lookup table for all plant properties.
	Used by PlacementSystem (cost validation) and UI (card display).
]]

export type PlantStats = {
	Name: string,
	Cost: number,
	Cooldown: number,       -- Seconds before can place again
	Health: number,
	Damage: number,         -- Per projectile or per tick
	AttackSpeed: number,    -- Attacks per second (0 for non-attackers)
	Range: number,          -- Attack range in studs (0 for lane-wide)
	Description: string,
	Category: string,       -- "Attacker", "Producer", "Defender", "Special"
	
	-- Behavior flags (data-driven)
	CanShoot: boolean?,      -- Can fire projectiles at zombies
	IsFrozen: boolean?,      -- Projectiles apply slow effect
	IsRepeater: boolean?,    -- Fires double projectiles
	IsExplosive: boolean?,   -- Is a one-time explosion plant
	ExplodesOnPlace: boolean?, -- Explodes immediately after fuse (CherryBomb)
	NeedsArming: boolean?,   -- Requires arming time before active (PotatoMine)
	ProducesSun: boolean?,   -- Produces sun periodically
	
	-- Sun Producer stats (for ProducesSun plants)
	SunProductionInterval: number?, -- Seconds between sun production (default 24)
	FirstSunDelay: number?,         -- Seconds before first sun (default 7)
	SunValue: number?,              -- Sun value per production (default 25)
	
	-- Projectile stats (for CanShoot plants)
	SlowPercent: number?,    -- Slow multiplier for IsFrozen (default 0.5)
	SlowDuration: number?,   -- Slow duration in seconds (default 3)
	ShotDelay: number?,      -- Delay between multi-shots for IsRepeater (default 0.1)
	
	-- Explosive stats (for IsExplosive plants)
	FuseTime: number?,       -- Seconds before explosion for ExplodesOnPlace (default 0.5)
	ArmDuration: number?,    -- Seconds to arm for NeedsArming (default 15)
	TriggerRadius: number?,  -- Radius to trigger armed explosion (default 2)
}

local PlantData: {[string]: PlantStats} = {
	-- ============================================
	-- MVP Plants (Epic 2)
	-- ============================================
	
	Sunflower = {
		Name = "Sunflower",
		Cost = 25,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Produces sun every 24 seconds",
		Category = "Producer",
		-- Behavior
		ProducesSun = true,
		-- Sun production stats
		SunProductionInterval = 24,
		FirstSunDelay = 7,
		SunValue = 25,
	},
	
	Peashooter = {
		Name = "Peashooter",
		Cost = 100,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Shoots peas at zombies",
		Category = "Attacker",
		CanShoot = true,
	},
	
	WallNut = {
		Name = "Wall-nut",
		Cost = 50,
		Cooldown = 20,
		Health = 400,
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
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Shoots frozen peas that slow zombies",
		Category = "Attacker",
		-- Behavior
		CanShoot = true,
		IsFrozen = true,
		-- Frozen projectile stats
		SlowPercent = 0.5,
		SlowDuration = 3,
	},
	
	CherryBomb = {
		Name = "Cherry Bomb",
		Cost = 150,
		Cooldown = 30,
		Health = 1,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 9,          -- Explosion radius in studs
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
		Cooldown = 20,
		Health = 100,
		Damage = 1800,
		AttackSpeed = 0,
		Range = 0,
		Description = "Arms after 15 seconds, explodes on contact",
		Category = "Special",
		-- Behavior
		IsExplosive = true,
		NeedsArming = true,
		-- Armed explosive stats
		ArmDuration = 15,
		TriggerRadius = 2,
	},
	
	Repeater = {
		Name = "Repeater",
		Cost = 200,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,
		Range = 0,
		Description = "Fires two peas at a time",
		Category = "Attacker",
		-- Behavior
		CanShoot = true,
		IsRepeater = true,
		-- Multi-shot stats
		ShotDelay = 0.1,
	},
}

-- Freeze to prevent runtime modification
table.freeze(PlantData)
for _, stats in PlantData do
	table.freeze(stats)
end

return PlantData
