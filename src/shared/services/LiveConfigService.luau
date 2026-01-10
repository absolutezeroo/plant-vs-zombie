--!strict
--[[
	LiveConfigService.luau - Remote Configuration Wrapper
	
	Provides live tuning of game balance via Roblox Cloud Configuration.
	Falls back to hardcoded defaults if cloud config is unavailable.
	
	Uses DataStoreService GetDataStore for cloud config as a workaround since
	Roblox doesn't have a dedicated ConfigurationService yet.
	Alternatively, this can be replaced with MessagingService for real-time updates.
	
	Usage:
		local LiveConfigService = require(Shared.services.LiveConfigService)
		local mult = LiveConfigService.GetMultiplier("Global_ZombieHealth")
		local value = LiveConfigService.GetFloat("Difficulty_Hard_CoinReward", 200)
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- Config DataStore (only accessible on server)
local _configStore: DataStore? = nil
local _isServer = RunService:IsServer()

if _isServer then
	local success, store = pcall(function()
		return DataStoreService:GetDataStore("LiveConfig")
	end)
	if success then
		_configStore = store
	end
end

-- ============================================
-- TYPES
-- ============================================

-- ConfigKey is just a string alias for documentation
export type ConfigKey = string

-- Known config keys (for documentation/autocomplete)
-- Global: "Global_ZombieHealth", "Global_ZombieSpeed", "Global_ZombieDamage", etc.
-- Difficulty: "Difficulty_Easy_ZombieHealthMult", "Difficulty_Hard_CoinReward", etc.
-- Zombie: "Zombie_Basic_HealthMult", "Zombie_Gargantuar_DamageMult", etc.
-- Plant: "Plant_Peashooter_Cost", "Plant_Sunflower_Damage", etc.

-- Default values for all known config keys
local DEFAULT_VALUES: {[string]: number} = {
	-- Global multipliers (1.0 = no change)
	Global_ZombieHealth = 1.0,
	Global_ZombieSpeed = 1.0,
	Global_ZombieDamage = 1.0,
	Global_PlantDamage = 1.0,
	Global_PlantHealth = 1.0,
	Global_SunDropRate = 1.0,
	Global_CoinDropRate = 1.0,
	
	-- Difficulty-specific multipliers (1.0 = use base value)
	Difficulty_Easy_ZombieHealthMult = 1.0,
	Difficulty_Normal_ZombieHealthMult = 1.0,
	Difficulty_Hard_ZombieHealthMult = 1.0,
	Difficulty_Nightmare_ZombieHealthMult = 1.0,
	
	-- Difficulty coin rewards (0 = use base value)
	Difficulty_Easy_CoinReward = 0,
	Difficulty_Normal_CoinReward = 0,
	Difficulty_Hard_CoinReward = 0,
	Difficulty_Nightmare_CoinReward = 0,
	
	-- Zombie-specific multipliers (1.0 = no change)
	Zombie_Basic_HealthMult = 1.0,
	Zombie_Basic_SpeedMult = 1.0,
	Zombie_Basic_DamageMult = 1.0,
	Zombie_Gargantuar_HealthMult = 1.0,
	Zombie_Gargantuar_SpeedMult = 1.0,
	Zombie_Gargantuar_DamageMult = 1.0,
	
	-- Plant-specific overrides (0 = use base value)
	-- Format: Plant_{Type}_{Stat} where Stat = Cost, Damage, Cooldown, Health
	Plant_Peashooter_Cost = 0,
	Plant_Peashooter_Damage = 0,
	Plant_Peashooter_Cooldown = 0,
	Plant_Peashooter_Health = 0,
	Plant_Sunflower_Cost = 0,
	Plant_Sunflower_Cooldown = 0,
	Plant_WallNut_Cost = 0,
	Plant_WallNut_Health = 0,
	Plant_WallNut_Cooldown = 0,
}

-- ============================================
-- CACHE
-- ============================================

-- Cache to avoid repeated ConfigurationService calls
local _cache: {[string]: number} = {}
local _cacheExpiry: {[string]: number} = {}
local CACHE_TTL_SECONDS = 60 -- Refresh cache every 60 seconds

-- ============================================
-- PRIVATE FUNCTIONS
-- ============================================

local function isCacheValid(key: string): boolean
	local expiry = _cacheExpiry[key]
	if not expiry then
		return false
	end
	return os.clock() < expiry
end

local function setCacheValue(key: string, value: number): ()
	_cache[key] = value
	_cacheExpiry[key] = os.clock() + CACHE_TTL_SECONDS
end

local function getCloudFloat(key: string, default: number): number
	-- Check cache first
	if isCacheValid(key) then
		return _cache[key]
	end
	
	-- Only server can access DataStore
	if not _isServer or not _configStore then
		setCacheValue(key, default)
		return default
	end
	
	-- Try to get from DataStore
	local success, result = pcall(function()
		return _configStore:GetAsync(key)
	end)
	
	if success and result ~= nil and type(result) == "number" then
		setCacheValue(key, result)
		return result
	end
	
	-- Fallback to default
	setCacheValue(key, default)
	return default
end

local function getCloudString(key: string, default: string): string
	-- Only server can access DataStore
	if not _isServer or not _configStore then
		return default
	end
	
	local success, result = pcall(function()
		return _configStore:GetAsync(key)
	end)
	
	if success and result ~= nil and type(result) == "string" and result ~= "" then
		return result
	end
	
	return default
end

-- ============================================
-- PUBLIC API
-- ============================================

local LiveConfigService = {}

--[[
	Get a multiplier value from cloud config.
	Multipliers default to 1.0 (no change).
	
	@param key The config key to look up
	@return The multiplier value (1.0 if not configured)
]]
function LiveConfigService.GetMultiplier(key: ConfigKey): number
	local default = DEFAULT_VALUES[key] or 1.0
	return getCloudFloat(key, default)
end

--[[
	Get a float value from cloud config with explicit default.
	
	@param key The config key to look up
	@param default The default value if not found
	@return The configured value or default
]]
function LiveConfigService.GetFloat(key: ConfigKey, default: number): number
	return getCloudFloat(key, default)
end

--[[
	Get a string value from cloud config.
	
	@param key The config key to look up
	@param default The default value if not found
	@return The configured value or default
]]
function LiveConfigService.GetString(key: ConfigKey, default: string): string
	return getCloudString(key, default)
end

--[[
	Get the global zombie stat multiplier.
	Combines the global multiplier for a stat type.
	
	@param statType "Health" | "Speed" | "Damage"
	@return The combined multiplier
]]
function LiveConfigService.GetGlobalZombieMult(statType: "Health" | "Speed" | "Damage"): number
	local key = "Global_Zombie" .. statType :: ConfigKey
	return LiveConfigService.GetMultiplier(key)
end

--[[
	Get a zombie-specific stat multiplier.
	Format: Zombie_{ZombieType}_{Stat}Mult
	
	@param zombieType The zombie type (e.g., "Basic", "Gargantuar")
	@param statType "Health" | "Speed" | "Damage"
	@return The multiplier (1.0 if not configured)
]]
function LiveConfigService.GetZombieStatMult(zombieType: string, statType: "Health" | "Speed" | "Damage"): number
	local key = `Zombie_{zombieType}_{statType}Mult` :: ConfigKey
	return LiveConfigService.GetMultiplier(key)
end

--[[
	Get a difficulty-specific override value.
	Format: Difficulty_{DifficultyId}_{Field}
	
	@param difficultyId "Easy" | "Normal" | "Hard" | "Nightmare"
	@param field The field name (e.g., "ZombieHealthMult", "CoinReward")
	@param baseValue The base value from DifficultyData
	@return The overridden value or baseValue if not configured
]]
function LiveConfigService.GetDifficultyOverride(difficultyId: string, field: string, baseValue: number): number
	-- Capitalize first letter for key format
	local capitalizedId = difficultyId:sub(1, 1):upper() .. difficultyId:sub(2):lower()
	local key = `Difficulty_{capitalizedId}_{field}` :: ConfigKey
	
	local override = getCloudFloat(key, 0)
	
	-- If override is 0, use base value (0 means "not configured")
	-- For multipliers, check if it's a Mult field
	if field:match("Mult$") then
		-- Multiplier fields: 1.0 = no change, so we multiply
		local mult = if override == 0 then 1.0 else override
		return baseValue * mult
	else
		-- Direct value fields: 0 = use base, otherwise override
		return if override == 0 then baseValue else override
	end
end

--[[
	Clear the cache to force refresh from cloud.
	Call this when you need immediate updates.
]]
function LiveConfigService.ClearCache(): ()
	table.clear(_cache)
	table.clear(_cacheExpiry)
end

--[[
	Check if cloud config is available.
	Useful for debugging/testing.
	
	@return true if DataStore is accessible (server only)
]]
function LiveConfigService.IsCloudAvailable(): boolean
	return _isServer and _configStore ~= nil
end

--[[
	Set a config value (server only, for admin tools).
	
	@param key The config key to set
	@param value The value to store
	@return true if successful
]]
function LiveConfigService.SetConfigValue(key: ConfigKey, value: number): boolean
	if not _isServer or not _configStore then
		return false
	end
	
	local success = pcall(function()
		_configStore:SetAsync(key, value)
	end)
	
	if success then
		-- Update cache immediately
		setCacheValue(key, value)
	end
	
	return success
end

return table.freeze(LiveConfigService)
