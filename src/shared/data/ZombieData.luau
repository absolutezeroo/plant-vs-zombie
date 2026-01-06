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
}

local ZombieData: {[string]: ZombieStats} = {
	-- Basic zombie - standard enemy
	Basic = {
		Health = 100,
		Speed = 1.5,
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Normal",
	},
	
	-- Cone zombie - more health
	Cone = {
		Health = 200,       -- Cone adds 100 HP
		Speed = 1.5,
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Armored",
	},
	
	-- Bucket zombie - even more health
	Bucket = {
		Health = 400,       -- Bucket adds 300 HP
		Speed = 1.5,
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Armored",
	},
	
	-- Pole Vaulter - jumps over first plant
	Pole = {
		Health = 150,
		Speed = 3.0,        -- Fast initially
		Damage = 20,
		AttackSpeed = 1.0,
		Category = "Special",
	},
	
	-- Newspaper zombie - gets angry when paper destroyed
	Newspaper = {
		Health = 150,       -- 50 paper + 100 zombie
		Speed = 1.5,
		Damage = 20,
		AttackSpeed = 0.5,  -- Faster when angry
		Category = "Special",
	},
	
	-- Football zombie - tanky and fast
	Football = {
		Health = 500,
		Speed = 2.5,
		Damage = 25,
		AttackSpeed = 0.8,
		Category = "Armored",
	},
}

return table.freeze(ZombieData)
