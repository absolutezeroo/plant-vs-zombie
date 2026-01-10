--!strict
--[[
	WorldData.luau - World/Map definitions
	
	All worlds are accessible from the start.
	Each world has unique mechanics, zombie pools, and visual themes.
	
	Difficulty is chosen separately (see DifficultyData.luau)
]]

export type WorldConfig = {
	Id: string,                -- "day", "night", "pool", "roof", "fog"
	Name: string,              -- Display name
	Description: string,       -- Short description
	Order: number,             -- Display order in world select
	
	-- Map/Visual
	MapId: string,             -- Map asset to load
	Theme: string,             -- Visual theme for UI
	Icon: string,              -- Icon asset ID
	
	-- Mechanics flags
	IsNight: boolean,          -- Mushrooms awake, sun spawns less
	HasWater: boolean,         -- Pool lanes require lily pads
	HasFog: boolean,           -- Limited visibility
	IsRoof: boolean,           -- Requires flower pots, angled shots
	Mechanics: {string}?,      -- Special mechanics list for spawner
	
	-- Zombie pool for this world
	ZombiePool: {string},      -- Available zombie types
	BossType: string?,         -- Boss zombie for this world
	
	-- Grid configuration (can override defaults)
	GridLanes: number?,        -- Default 5
	GridColumns: number?,      -- Default 9
	WaterLanes: {number}?,     -- Which lanes are water (e.g., {3, 4} for pool)
	
	-- Starting resources
	SunStarting: number,       -- Starting sun amount
	
	-- Unlock (nil = unlocked from start)
	RequiredLevel: number?,    -- Player level required (nil = free)
}

-- ============================================
-- WORLD DEFINITIONS
-- ============================================

local Worlds: {[string]: WorldConfig} = {
	
	-- ============================================
	-- WORLD 1: DAY (Unlocked from start)
	-- ============================================
	day = {
		Id = "day",
		Name = "Jardin de Jour",
		Description = "Un jardin ensoleillé, parfait pour débuter.",
		Order = 1,
		
		MapId = "Map_Day",
		Theme = "day",
		Icon = "☀️", -- Sunny day
		
		-- Mechanics
		IsNight = false,
		HasWater = false,
		HasFog = false,
		IsRoof = false,
		
		-- Zombies
		ZombiePool = {"Basic", "Cone", "Bucket", "Flag", "Pole"},
		BossType = "MiniGargantuar",
		
		-- Starting sun
		SunStarting = 50,
	},
	
	-- ============================================
	-- WORLD 2: NIGHT
	-- ============================================
	night = {
		Id = "night",
		Name = "Jardin de Nuit",
		Description = "Les champignons brillent sous la lune.",
		Order = 2,
		
		MapId = "Map_Night",
		Theme = "night",
		Icon = "🌙", -- Night moon
		
		-- Mechanics
		IsNight = true,  -- Mushrooms awake, reduced sky sun
		HasWater = false,
		HasFog = false,
		IsRoof = false,
		
		-- Zombies
		ZombiePool = {"Basic", "Cone", "Bucket", "Flag", "Newspaper", "Football"},
		BossType = "Gargantuar",
		
		-- Starting sun (less sun drops from sky at night)
		SunStarting = 50,
	},
	
	-- ============================================
	-- WORLD 3: POOL
	-- ============================================
	pool = {
		Id = "pool",
		Name = "Piscine",
		Description = "Attention aux zombies aquatiques !",
		Order = 3,
		
		MapId = "Map_Pool",
		Theme = "pool",
		Icon = "🌊", -- Pool waves
		
		-- Mechanics
		IsNight = false,
		HasWater = true,  -- Lanes 3-4 are water
		HasFog = false,
		IsRoof = false,
		
		-- Grid overrides for pool
		GridLanes = 6,    -- 6 lanes instead of 5
		WaterLanes = {3, 4}, -- Middle lanes are water
		
		-- Zombies (includes aquatic)
		ZombiePool = {"Basic", "Cone", "Bucket", "Flag", "Pole", "Balloon"},
		BossType = "Gargantuar",
		
		-- Starting sun
		SunStarting = 50,
	},
	
	-- ============================================
	-- WORLD 4: FOG
	-- ============================================
	fog = {
		Id = "fog",
		Name = "Brouillard",
		Description = "Visibilité réduite, restez vigilant !",
		Order = 4,
		
		MapId = "Map_Fog",
		Theme = "fog",
		Icon = "🌫️", -- Fog cloud
		
		-- Mechanics
		IsNight = true,   -- Also night time
		HasWater = true,  -- Pool + Fog combo
		HasFog = true,    -- Limited visibility
		IsRoof = false,
		
		-- Grid overrides
		GridLanes = 6,
		WaterLanes = {3, 4},
		
		-- Zombies
		ZombiePool = {"Basic", "Cone", "Bucket", "Flag", "Newspaper", "Balloon", "Football"},
		BossType = "Gargantuar",
		
		-- Starting sun
		SunStarting = 50,
	},
	
	-- ============================================
	-- WORLD 5: ROOF
	-- ============================================
	roof = {
		Id = "roof",
		Name = "Toit",
		Description = "Les projectiles suivent la pente !",
		Order = 5,
		
		MapId = "Map_Roof",
		Theme = "roof",
		Icon = "🏠", -- Roof/House
		
		-- Mechanics
		IsNight = false,
		HasWater = false,
		HasFog = false,
		IsRoof = true,    -- Requires flower pots, angled projectiles
		
		-- Zombies
		ZombiePool = {"Basic", "Cone", "Bucket", "Flag", "Pole", "Football", "Imp"},
		BossType = "Gargantuar",
		
		-- Starting sun
		SunStarting = 50,
	},
	
	-- ============================================
	-- WORLD 6: BOSS RUSH (Endgame)
	-- ============================================
	boss = {
		Id = "boss",
		Name = "Boss Rush",
		Description = "Affrontez tous les boss d'affilée !",
		Order = 6,
		
		MapId = "Map_Day", -- Uses day map
		Theme = "boss",
		Icon = "💀", -- Boss skull
		
		-- Mechanics
		IsNight = false,
		HasWater = false,
		HasFog = false,
		IsRoof = false,
		
		-- All zombie types + multiple bosses
		ZombiePool = {"Basic", "Cone", "Bucket", "Flag", "Pole", "Newspaper", "Football", "Imp"},
		BossType = "Gargantuar",
		
		-- More starting sun for harder content
		SunStarting = 100,
		
		-- Requires some progression
		RequiredLevel = 10,
	},
}

-- ============================================
-- API
-- ============================================

local WorldData = {}

-- Get all worlds sorted by order
function WorldData.GetAllWorlds(): {WorldConfig}
	local result: {WorldConfig} = {}
	for _, world in Worlds do
		table.insert(result, world)
	end
	table.sort(result, function(a, b)
		return a.Order < b.Order
	end)
	return result
end

-- Get a specific world by ID
function WorldData.GetWorld(worldId: string): WorldConfig?
	return Worlds[worldId]
end

-- Check if world is unlocked for player level
function WorldData.IsUnlocked(worldId: string, playerLevel: number): boolean
	local world = Worlds[worldId]
	if not world then
		return false
	end
	if world.RequiredLevel then
		return playerLevel >= world.RequiredLevel
	end
	return true -- No requirement = unlocked
end

-- Get worlds unlocked at a specific level
function WorldData.GetUnlockedWorlds(playerLevel: number): {WorldConfig}
	local result: {WorldConfig} = {}
	for _, world in WorldData.GetAllWorlds() do
		if WorldData.IsUnlocked(world.Id, playerLevel) then
			table.insert(result, world)
		end
	end
	return result
end

return table.freeze(WorldData)
