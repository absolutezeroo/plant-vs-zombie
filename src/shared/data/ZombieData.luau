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
	Speed: number, -- Studs per second
	Damage: number, -- Damage per bite
	AttackSpeed: number, -- Seconds between attacks
	Category: string, -- "Normal", "Armored", "Special", "Boss"

	-- Wave spawn config (data-driven)
	SpawnCost: number, -- Budget cost to spawn this zombie

	-- Behavior flags
	CanJump: boolean?, -- Can vault over first plant (Pole Vaulter)
	HasRage: boolean?, -- Speeds up when armor destroyed (Newspaper)
	IsFlagBearer: boolean?, -- Spawns at wave start (Flag zombie)
	IsFlying: boolean?, -- Flies over ground plants (Balloon)
	IsBoss: boolean?, -- Boss type - spawns Imp on half health (Gargantuar)

	-- Rage stats (for HasRage zombies)
	RageSpeed: number?, -- Speed when enraged
	RageAttackSpeed: number?, -- Attack speed when enraged
	ArmorHealth: number?, -- Health of removable armor (newspaper, cone, bucket)

	-- Shield stats (for HasShield zombies - blocks projectiles, pierced by Fume-shroom)
	HasShield: boolean?, -- Has a shield that blocks projectiles (Screen-Door, Ladder)
	ShieldHealth: number?, -- Health of the shield (damage goes to shield first)

	-- Flying stats (for IsFlying zombies)
	FlyHeight: number?, -- Y offset when flying (default 3)

	-- Boss stats (for IsBoss zombies)
	SpawnsOnHalfHealth: string?, -- Zombie type to spawn at 50% HP
	SpawnCount: number?, -- How many to spawn
}

local ZombieData: { [string]: ZombieStats } = {
	-- Basic zombie - standard enemy
	Basic = {
		Health = 200, -- Buffed from 100 (takes 10 pea shots)
		Speed = 2.0, -- Buffed from 1.5
		Damage = 40, -- Buffed from 20
		AttackSpeed = 0.8, -- Faster attacks (was 1.0)
		Category = "Normal",
		SpawnCost = 10,
	},

	-- Cone zombie - more health
	Cone = {
		Health = 400, -- Buffed from 200
		Speed = 2.0, -- Buffed from 1.5
		Damage = 40, -- Buffed from 20
		AttackSpeed = 0.8, -- Faster attacks
		Category = "Armored",
		SpawnCost = 20,
		ArmorHealth = 200, -- Buffed from 100
	},

	-- Bucket zombie - even more health
	Bucket = {
		Health = 800, -- Buffed from 400
		Speed = 2.0, -- Buffed from 1.5
		Damage = 50, -- Buffed from 20
		AttackSpeed = 0.7, -- Faster attacks
		Category = "Armored",
		SpawnCost = 35,
		ArmorHealth = 600, -- Buffed from 300
	},

	-- Pole Vaulter - jumps over first plant
	Pole = {
		Health = 300, -- Buffed from 150
		Speed = 4.0, -- Buffed from 3.0 (very fast)
		Damage = 40,
		AttackSpeed = 0.8,
		Category = "Special",
		SpawnCost = 25,
		-- Behavior
		CanJump = true,
	},

	-- Newspaper zombie - gets angry when paper destroyed
	Newspaper = {
		Health = 300, -- Buffed from 150
		Speed = 2.0, -- Buffed from 1.5
		Damage = 40,
		AttackSpeed = 0.8,
		Category = "Special",
		SpawnCost = 18,
		-- Rage behavior
		HasRage = true,
		ArmorHealth = 100, -- Buffed from 50
		RageSpeed = 5.0, -- Buffed from 3.0
		RageAttackSpeed = 0.3, -- Faster (was 0.5)
	},

	-- Football zombie - tanky and fast
	Football = {
		Health = 1200, -- Buffed from 500
		Speed = 3.5, -- Buffed from 2.5
		Damage = 60, -- Buffed from 25
		AttackSpeed = 0.5, -- Faster attacks (was 0.8)
		Category = "Armored",
		SpawnCost = 60,
		ArmorHealth = 800, -- Buffed from 400
	},

	-- Screen-Door zombie - shield blocks projectiles (pierced by Fume-shroom)
	ScreenDoor = {
		Health = 200, -- Buffed from 100
		Speed = 2.0, -- Buffed from 1.5
		Damage = 40,
		AttackSpeed = 0.8,
		Category = "Armored",
		SpawnCost = 40,
		-- Shield behavior
		HasShield = true,
		ShieldHealth = 800, -- Buffed from 400
	},

	-- Ladder zombie - places ladder over Wall-nuts (shield while carrying)
	Ladder = {
		Health = 200, -- Buffed from 100
		Speed = 2.5, -- Buffed from 1.8
		Damage = 40,
		AttackSpeed = 0.8,
		Category = "Special",
		SpawnCost = 45,
		-- Shield while carrying ladder
		HasShield = true,
		ShieldHealth = 600, -- Buffed from 300
	},

	-- Imp - small, fast, weak
	Imp = {
		Health = 100, -- Buffed from 50
		Speed = 4.5, -- Buffed from 3.0 (very fast)
		Damage = 30, -- Buffed from 15
		AttackSpeed = 0.5, -- Very fast attacks
		Category = "Normal",
		SpawnCost = 10,
	},

	-- Flag zombie - signals large waves
	Flag = {
		Health = 200, -- Buffed from 100
		Speed = 2.5, -- Buffed from 1.8
		Damage = 40,
		AttackSpeed = 0.8,
		Category = "Normal",
		SpawnCost = 12,
		-- Behavior
		IsFlagBearer = true,
	},

	-- ============================================
	-- Flying Zombies
	-- ============================================

	-- Balloon zombie - flies over ground plants, only hit by Cactus/Cattail
	Balloon = {
		Health = 150, -- Buffed from 75
		Speed = 2.0, -- Buffed from 1.2
		Damage = 40,
		AttackSpeed = 0.8,
		Category = "Special",
		SpawnCost = 25,
		-- Flying behavior
		IsFlying = true,
		FlyHeight = 4, -- Studs above ground
	},

	-- ============================================
	-- Boss Zombies
	-- ============================================

	-- Gargantuar - massive boss, throws Imp at half health
	Gargantuar = {
		Health = 6000, -- Buffed from 3000 (needs serious firepower)
		Speed = 1.2, -- Buffed from 0.8
		Damage = 200, -- Buffed from 100 (instant-kills everything)
		AttackSpeed = 1.0, -- Faster swings (was 1.5)
		Category = "Boss",
		SpawnCost = 180,
		-- Boss behavior
		IsBoss = true,
		SpawnsOnHalfHealth = "Imp",
		SpawnCount = 2, -- Spawns 2 Imps now
	},

	-- Mini-Gargantuar for easier waves
	MiniGargantuar = {
		Health = 3000, -- Buffed from 1500
		Speed = 1.5, -- Buffed from 1.0
		Damage = 100, -- Buffed from 50
		AttackSpeed = 0.8, -- Faster attacks (was 1.2)
		Category = "Boss",
		SpawnCost = 100,
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
function ZombieDataModule.GetAllTypes(): { string }
	local types: { string } = {}
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

-- ============================================
-- METATABLE FOR BACKWARDS COMPATIBILITY
-- ============================================
-- Allows ZombieData.Basic syntax to still work
-- Redirects to GetStats() for live config support

setmetatable(ZombieDataModule :: any, {
	__index = function(_, key: string): ZombieStats?
		-- Skip known function names
		if key == "GetStats" or key == "GetStatsRaw" or key == "GetAllTypes" or key == "Exists" or key == "RawData" then
			return nil
		end
		-- Redirect to GetStats for any zombie type access
		return ZombieDataModule.GetStats(key)
	end,
})

return ZombieDataModule
