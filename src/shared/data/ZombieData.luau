--!strict
--[[
	ZombieData.luau - Zombie type statistics
	
	Defines all zombie types with their stats.
	Server-authoritative, clients use for prediction.
	
	NOTE: Use GetStats(type) to get stats with LiveConfigService overrides applied.
	The raw ZombieStats table is the "factory default".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sift = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Sift"))
local LiveConfigService = require(Shared.services.LiveConfigService)

export type ZombieStats = {
	Health: number,
	Speed: number,          -- Studs per second
	Damage: number,         -- Damage per bite
	AttackSpeed: number,    -- Seconds between attacks
	Category: string,       -- "Normal", "Armored", "Special", "Boss"
	
	-- Wave spawn config (data-driven)
	SpawnCost: number,      -- Budget cost to spawn this zombie
	
	-- Behavior flags
	CanJump: boolean?,      -- Can vault over first plant (Pole Vaulter)
	HasRage: boolean?,      -- Speeds up when armor destroyed (Newspaper)
	IsFlagBearer: boolean?, -- Spawns at wave start (Flag zombie)
	IsFlying: boolean?,     -- Flies over ground plants (Balloon)
	IsBoss: boolean?,       -- Boss type - spawns Imp on half health (Gargantuar)
	
	-- Rage stats (for HasRage zombies)
	RageSpeed: number?,     -- Speed when enraged
	RageAttackSpeed: number?, -- Attack speed when enraged
	ArmorHealth: number?,   -- Health of removable armor (newspaper, cone, bucket)
	
	-- Shield stats (for HasShield zombies - blocks projectiles, pierced by Fume-shroom)
	HasShield: boolean?,    -- Has a shield that blocks projectiles (Screen-Door, Ladder)
	ShieldHealth: number?,  -- Health of the shield (damage goes to shield first)
	
	-- Flying stats (for IsFlying zombies)
	FlyHeight: number?,     -- Y offset when flying (default 3)
	
	-- Boss stats (for IsBoss zombies)
	SpawnsOnHalfHealth: string?, -- Zombie type to spawn at 50% HP
	SpawnCount: number?,    -- How many to spawn
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
	
	-- Screen-Door zombie - shield blocks projectiles (pierced by Fume-shroom)
	ScreenDoor = {
		Health = 100,       -- Base zombie health
		Speed = 1.5,
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Armored",
		SpawnCost = 35,
		-- Shield behavior
		HasShield = true,
		ShieldHealth = 400, -- Door absorbs damage until destroyed
	},
	
	-- Ladder zombie - places ladder over Wall-nuts (shield while carrying)
	Ladder = {
		Health = 100,
		Speed = 1.8,
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Special",
		SpawnCost = 40,
		-- Shield while carrying ladder
		HasShield = true,
		ShieldHealth = 300, -- Ladder absorbs damage
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
	
	-- ============================================
	-- Flying Zombies
	-- ============================================
	
	-- Balloon zombie - flies over ground plants, only hit by Cactus/Cattail
	Balloon = {
		Health = 75,        -- Fragile when popped
		Speed = 1.2,        -- Slower than walking
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Special",
		SpawnCost = 20,
		-- Flying behavior
		IsFlying = true,
		FlyHeight = 4,      -- Studs above ground
	},
	
	-- ============================================
	-- Boss Zombies
	-- ============================================
	
	-- Gargantuar - massive boss, throws Imp at half health
	Gargantuar = {
		Health = 3000,      -- Extremely tanky
		Speed = 0.8,        -- Slow but devastating
		Damage = 100,       -- Instant-kills most plants
		AttackSpeed = 1.5,  -- Slow swings
		Category = "Boss",
		SpawnCost = 150,    -- Equivalent to 15 basics
		-- Boss behavior
		IsBoss = true,
		SpawnsOnHalfHealth = "Imp",
		SpawnCount = 1,
	},
	
	-- Mini-Gargantuar for easier waves
	MiniGargantuar = {
		Health = 1500,
		Speed = 1.0,
		Damage = 50,
		AttackSpeed = 1.2,
		Category = "Boss",
		SpawnCost = 80,
		IsBoss = true,
		SpawnsOnHalfHealth = "Imp",
		SpawnCount = 1,
	},
}

-- ============================================
-- API
-- ============================================

local ZombieDataModule = {}

-- Raw data table (factory defaults, frozen)
ZombieDataModule.RawData = table.freeze(ZombieData)

--[[
	Get all zombie types (factory defaults).
	@return Array of zombie type names
]]
function ZombieDataModule.GetAllTypes(): {string}
	local types: {string} = {}
	for zombieType, _ in ZombieData do
		table.insert(types, zombieType)
	end
	return types
end

--[[
	Get stats for a specific zombie type with LiveConfigService overrides applied.
	
	@param zombieType The zombie type (e.g., "Basic", "Gargantuar")
	@return The effective stats with cloud config multipliers applied, or nil if not found
]]
function ZombieDataModule.GetStats(zombieType: string): ZombieStats?
	local baseStats = ZombieData[zombieType]
	if not baseStats then
		return nil
	end
	
	-- Get global multipliers
	local globalHealthMult = LiveConfigService.GetGlobalZombieMult("Health")
	local globalSpeedMult = LiveConfigService.GetGlobalZombieMult("Speed")
	local globalDamageMult = LiveConfigService.GetGlobalZombieMult("Damage")
	
	-- Get zombie-specific multipliers
	local zombieHealthMult = LiveConfigService.GetZombieStatMult(zombieType, "Health")
	local zombieSpeedMult = LiveConfigService.GetZombieStatMult(zombieType, "Speed")
	local zombieDamageMult = LiveConfigService.GetZombieStatMult(zombieType, "Damage")
	
	-- Apply multipliers (global * zombie-specific)
	local effectiveStats = Sift.Dictionary.merge(baseStats, {
		Health = math.floor(baseStats.Health * globalHealthMult * zombieHealthMult),
		Speed = baseStats.Speed * globalSpeedMult * zombieSpeedMult,
		Damage = math.floor(baseStats.Damage * globalDamageMult * zombieDamageMult),
	})
	
	-- Also apply to armor health if present
	if baseStats.ArmorHealth then
		effectiveStats = Sift.Dictionary.merge(effectiveStats, {
			ArmorHealth = math.floor(baseStats.ArmorHealth * globalHealthMult * zombieHealthMult),
		})
	end
	
	-- Apply to shield health if present
	if baseStats.ShieldHealth then
		effectiveStats = Sift.Dictionary.merge(effectiveStats, {
			ShieldHealth = math.floor(baseStats.ShieldHealth * globalHealthMult * zombieHealthMult),
		})
	end
	
	return effectiveStats
end

--[[
	Get raw stats for a specific zombie type WITHOUT LiveConfigService overrides.
	
	@param zombieType The zombie type (e.g., "Basic", "Gargantuar")
	@return The factory default stats, or nil if not found
]]
function ZombieDataModule.GetStatsRaw(zombieType: string): ZombieStats?
	return ZombieData[zombieType]
end

--[[
	Check if a zombie type exists.
	
	@param zombieType The zombie type to check
	@return true if the zombie type exists
]]
function ZombieDataModule.Exists(zombieType: string): boolean
	return ZombieData[zombieType] ~= nil
end

return table.freeze(ZombieDataModule)
