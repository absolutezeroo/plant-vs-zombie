--!strict
--[[
	ZombieData.luau - Zombie type statistics
	
	Defines all zombie types with their stats.
	Server-authoritative, clients use for prediction.
]]

export type ZombieStats = {
	Health: number,
	Speed: number,          -- Studs per second
	Damage: number,         -- Damage per bite
	AttackSpeed: number,    -- Seconds between attacks
	Category: string,       -- "Normal", "Armored", "Special"
	
	-- Wave spawn config (data-driven)
	SpawnCost: number,      -- Budget cost to spawn this zombie
	
	-- Behavior flags
	CanJump: boolean?,      -- Can vault over first plant (Pole Vaulter)
	HasRage: boolean?,      -- Speeds up when armor destroyed (Newspaper)
	IsFlagBearer: boolean?, -- Spawns at wave start (Flag zombie)
	
	-- Rage stats (for HasRage zombies)
	RageSpeed: number?,     -- Speed when enraged
	RageAttackSpeed: number?, -- Attack speed when enraged
	ArmorHealth: number?,   -- Health of removable armor (newspaper, cone, bucket)
}

local ZombieData: {[string]: ZombieStats} = {
	-- Basic zombie - standard enemy
	Basic = {
		Health = 100,
		Speed = 1.5,
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Normal",
		SpawnCost = 10,
	},
	
	-- Cone zombie - more health
	Cone = {
		Health = 200,       -- Cone adds 100 HP
		Speed = 1.5,
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Armored",
		SpawnCost = 20,
		ArmorHealth = 100,  -- Cone HP
	},
	
	-- Bucket zombie - even more health
	Bucket = {
		Health = 400,       -- Bucket adds 300 HP
		Speed = 1.5,
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Armored",
		SpawnCost = 30,
		ArmorHealth = 300,  -- Bucket HP
	},
	
	-- Pole Vaulter - jumps over first plant
	Pole = {
		Health = 150,
		Speed = 3.0,        -- Fast initially
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Special",
		SpawnCost = 25,
		-- Behavior
		CanJump = true,
	},
	
	-- Newspaper zombie - gets angry when paper destroyed
	Newspaper = {
		Health = 150,       -- 50 paper + 100 zombie
		Speed = 1.5,
		Damage = 20,
		AttackSpeed = 1.0,  -- Normal attack speed
		Category = "Special",
		SpawnCost = 15,
		-- Rage behavior
		HasRage = true,
		ArmorHealth = 50,   -- Newspaper HP
		RageSpeed = 3.0,    -- Speed when enraged
		RageAttackSpeed = 0.5, -- Attack speed when enraged
	},
	
	-- Football zombie - tanky and fast
	Football = {
		Health = 500,
		Speed = 2.5,
		Damage = 25,
		AttackSpeed = 0.8,
		Category = "Armored",
		SpawnCost = 50,
		ArmorHealth = 400,  -- Helmet HP
	},
	
	-- Imp - small, fast, weak
	Imp = {
		Health = 50,
		Speed = 3.0,        -- Very fast
		Damage = 15,
		AttackSpeed = 0.8,
		Category = "Normal",
		SpawnCost = 8,
	},
	
	-- Flag zombie - signals large waves
	Flag = {
		Health = 100,
		Speed = 1.8,        -- Slightly faster than Basic
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Normal",
		SpawnCost = 10,
		-- Behavior
		IsFlagBearer = true,
	},
}

return table.freeze(ZombieData)
