--!strict
--[[
	BalanceConfig.lua - Game balance data for plants and zombies
	
	These values are tuned for gameplay balance. Modifying without
	playtesting may break wave difficulty curves.
]]

local BalanceConfig = {
	-- Sun Economy
	Sun = {
		STARTING_SUN = 50,          -- Sun at match start
		SUN_DROP_VALUE = 25,        -- Sun from Sunflower production
		SKY_SUN_VALUE = 25,         -- Sun from sky drops
		SKY_SUN_INTERVAL = 10,      -- Seconds between sky sun drops
	},
	
	-- Wave Generation
	Wave = {
		BUDGET_BASE = 50,           -- Wave 1 budget
		BUDGET_MULTIPLIER = 1.6,    -- Budget = BASE × MULT^(Wave-1)
		WAVE_DELAY = 30,            -- Seconds between waves
		FIRST_WAVE_DELAY = 45,      -- Seconds before first wave
	},
	
	-- Plant Stats (MVP Plants)
	Plants = {
		Peashooter = {
			Cost = 100,
			Cooldown = 7.5,
			Health = 300,
			Damage = 20,
			FireRate = 1.5,         -- Seconds between shots
			Range = 100,            -- Targeting range (studs)
		},
		Sunflower = {
			Cost = 50,
			Cooldown = 7.5,
			Health = 300,
			Production = 25,        -- Sun produced per cycle
			Interval = 24,          -- Seconds between production
		},
		WallNut = {
			Cost = 50,
			Cooldown = 30,
			Health = 4000,          -- High HP tank
		},
		SnowPea = {
			Cost = 175,
			Cooldown = 7.5,
			Health = 300,
			Damage = 20,
			FireRate = 1.5,
			Range = 100,
			SlowMultiplier = 0.5,   -- 50% slow on hit
			SlowDuration = 10,      -- Slow lasts 10 seconds
		},
		CherryBomb = {
			Cost = 150,
			Cooldown = 50,
			Health = 1,             -- Instant use
			Damage = 1800,          -- Kills most zombies
			Radius = 1,             -- 3x3 grid cells
		},
	},
	
	-- Zombie Stats (MVP Zombies)
	Zombies = {
		Basic = {
			Health = 200,
			Speed = 0.5,            -- Studs per second
			Damage = 100,           -- Damage per bite
			AttackSpeed = 1.0,      -- Seconds between bites
			BudgetCost = 50,        -- Wave budget cost
		},
		Conehead = {
			Health = 560,           -- 200 + 360 (cone)
			Speed = 0.5,
			Damage = 100,
			AttackSpeed = 1.0,
			BudgetCost = 75,
		},
		Buckethead = {
			Health = 1300,          -- 200 + 1100 (bucket)
			Speed = 0.5,
			Damage = 100,
			AttackSpeed = 1.0,
			BudgetCost = 125,
		},
	},
}

return table.freeze(BalanceConfig)
