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
}

local PlantData: {[string]: PlantStats} = {
	-- ============================================
	-- MVP Plants (Epic 2)
	-- ============================================
	
	Sunflower = {
		Name = "Sunflower",
		Cost = 50,
		Cooldown = 5,
		Health = 100,
		Damage = 0,
		AttackSpeed = 0,
		Range = 0,
		Description = "Produces sun every 5 seconds",
		Category = "Producer",
	},
	
	Peashooter = {
		Name = "Peashooter",
		Cost = 100,
		Cooldown = 5,
		Health = 100,
		Damage = 20,
		AttackSpeed = 1.5,  -- 1.5 peas per second
		Range = 0,          -- Lane-wide
		Description = "Shoots peas at zombies",
		Category = "Attacker",
	},
	
	WallNut = {
		Name = "Wall-nut",
		Cost = 50,
		Cooldown = 20,
		Health = 400,       -- Tanky!
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
	},
	
	CherryBomb = {
		Name = "Cherry Bomb",
		Cost = 150,
		Cooldown = 30,
		Health = 1,         -- Dies on use
		Damage = 1800,      -- Instant kill most zombies
		AttackSpeed = 0,    -- One-time use
		Range = 9,          -- 3x3 area (1.5 cells each direction)
		Description = "Explodes and destroys nearby zombies",
		Category = "Special",
	},
	
	PotatoMine = {
		Name = "Potato Mine",
		Cost = 25,
		Cooldown = 20,
		Health = 100,
		Damage = 1800,      -- Instant kill on contact
		AttackSpeed = 0,
		Range = 0,          -- Contact only
		Description = "Arms after 15 seconds, explodes on contact",
		Category = "Special",
	},
}

-- Freeze to prevent runtime modification
table.freeze(PlantData)
for _, stats in PlantData do
	table.freeze(stats)
end

return PlantData
