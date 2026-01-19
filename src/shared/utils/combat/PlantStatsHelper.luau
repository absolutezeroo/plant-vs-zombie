--!strict
--[[
	PlantStatsHelper.luau - Safe accessors for PlantData stats
	
	Consolidates the common pattern:
	  local value = (stats and stats.Field) or DEFAULT
	
	Provides type-safe getters with sensible defaults.
	Use when you may have nil stats or optional fields.
	
	USAGE:
	local PlantStatsHelper = require(Shared.utils.combat.PlantStatsHelper)
	local helper = PlantStatsHelper.FromStats(stats)
	local damage = helper:GetDamage(25)  -- Returns stats.Damage or 25
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)

-- Default values (from PlantData type definition)
local DEFAULTS = {
	Damage = 20,
	AttackSpeed = 1.0,
	Range = 0,
	SlowPercent = 0.5,
	SlowDuration = 3,
	ShotDelay = 0.1,
	SplashRadius = 0,
	StunChance = 0,
	StunDuration = 0,
	SunProductionInterval = 24,
	FirstSunDelay = 7,
	SunValue = 25,
	HomingTurnSpeed = 4,
	HomingMaxLifetime = 10,
}

export type PlantStatsHelper = {
	stats: PlantData.PlantStats?,
	
	-- Numeric getters with defaults
	GetDamage: (self: PlantStatsHelper, default: number?) -> number,
	GetRange: (self: PlantStatsHelper, default: number?) -> number,
	GetAttackSpeed: (self: PlantStatsHelper, default: number?) -> number,
	GetSlowPercent: (self: PlantStatsHelper, default: number?) -> number,
	GetSlowDuration: (self: PlantStatsHelper, default: number?) -> number,
	GetSplashRadius: (self: PlantStatsHelper, default: number?) -> number,
	GetStunChance: (self: PlantStatsHelper, default: number?) -> number,
	GetStunDuration: (self: PlantStatsHelper, default: number?) -> number,
	GetShotDelay: (self: PlantStatsHelper, default: number?) -> number,
	GetSunProductionInterval: (self: PlantStatsHelper, default: number?) -> number,
	GetFirstSunDelay: (self: PlantStatsHelper, default: number?) -> number,
	GetSunValue: (self: PlantStatsHelper, default: number?) -> number,
	GetHomingTurnSpeed: (self: PlantStatsHelper, default: number?) -> number,
	GetHomingMaxLifetime: (self: PlantStatsHelper, default: number?) -> number,
	
	-- Boolean getters (default false)
	IsFrozen: (self: PlantStatsHelper) -> boolean,
	IsCatapult: (self: PlantStatsHelper) -> boolean,
	HasSplash: (self: PlantStatsHelper) -> boolean,
	PiercesShields: (self: PlantStatsHelper) -> boolean,
	CanStun: (self: PlantStatsHelper) -> boolean,
	CanHitFlying: (self: PlantStatsHelper) -> boolean,
	IsHoming: (self: PlantStatsHelper) -> boolean,
	IsRepeater: (self: PlantStatsHelper) -> boolean,
	ProducesSun: (self: PlantStatsHelper) -> boolean,
	
	-- String getters (default nil)
	GetProjectileVariant: (self: PlantStatsHelper, default: string?) -> string?,
	GetStunProjectileVariant: (self: PlantStatsHelper, default: string?) -> string?,
	
	-- Vector3 getters
	GetProjectileSpawnOffset: (self: PlantStatsHelper, default: Vector3?) -> Vector3?,
}

local PlantStatsHelperClass = {}
PlantStatsHelperClass.__index = PlantStatsHelperClass

-- ============================================
-- Numeric Getters
-- ============================================

function PlantStatsHelperClass:GetDamage(default: number?): number
	local d = default or DEFAULTS.Damage
	return if self.stats and self.stats.Damage then self.stats.Damage else d
end

function PlantStatsHelperClass:GetRange(default: number?): number
	local d = default or DEFAULTS.Range
	return if self.stats and self.stats.Range then self.stats.Range else d
end

function PlantStatsHelperClass:GetAttackSpeed(default: number?): number
	local d = default or DEFAULTS.AttackSpeed
	return if self.stats and self.stats.AttackSpeed then self.stats.AttackSpeed else d
end

function PlantStatsHelperClass:GetSlowPercent(default: number?): number
	local d = default or DEFAULTS.SlowPercent
	return if self.stats and self.stats.SlowPercent then self.stats.SlowPercent else d
end

function PlantStatsHelperClass:GetSlowDuration(default: number?): number
	local d = default or DEFAULTS.SlowDuration
	return if self.stats and self.stats.SlowDuration then self.stats.SlowDuration else d
end

function PlantStatsHelperClass:GetSplashRadius(default: number?): number
	local d = default or DEFAULTS.SplashRadius
	return if self.stats and self.stats.SplashRadius then self.stats.SplashRadius else d
end

function PlantStatsHelperClass:GetStunChance(default: number?): number
	local d = default or DEFAULTS.StunChance
	return if self.stats and self.stats.StunChance then self.stats.StunChance else d
end

function PlantStatsHelperClass:GetStunDuration(default: number?): number
	local d = default or DEFAULTS.StunDuration
	return if self.stats and self.stats.StunDuration then self.stats.StunDuration else d
end

function PlantStatsHelperClass:GetShotDelay(default: number?): number
	local d = default or DEFAULTS.ShotDelay
	return if self.stats and self.stats.ShotDelay then self.stats.ShotDelay else d
end

function PlantStatsHelperClass:GetSunProductionInterval(default: number?): number
	local d = default or DEFAULTS.SunProductionInterval
	return if self.stats and self.stats.SunProductionInterval then self.stats.SunProductionInterval else d
end

function PlantStatsHelperClass:GetFirstSunDelay(default: number?): number
	local d = default or DEFAULTS.FirstSunDelay
	return if self.stats and self.stats.FirstSunDelay then self.stats.FirstSunDelay else d
end

function PlantStatsHelperClass:GetSunValue(default: number?): number
	local d = default or DEFAULTS.SunValue
	return if self.stats and self.stats.SunValue then self.stats.SunValue else d
end

function PlantStatsHelperClass:GetHomingTurnSpeed(default: number?): number
	local d = default or DEFAULTS.HomingTurnSpeed
	return if self.stats and self.stats.HomingTurnSpeed then self.stats.HomingTurnSpeed else d
end

function PlantStatsHelperClass:GetHomingMaxLifetime(default: number?): number
	local d = default or DEFAULTS.HomingMaxLifetime
	return if self.stats and self.stats.HomingMaxLifetime then self.stats.HomingMaxLifetime else d
end

-- ============================================
-- Boolean Getters
-- ============================================

function PlantStatsHelperClass:IsFrozen(): boolean
	return (self.stats and self.stats.IsFrozen) or false
end

function PlantStatsHelperClass:IsCatapult(): boolean
	return (self.stats and self.stats.IsCatapult) or false
end

function PlantStatsHelperClass:HasSplash(): boolean
	return (self.stats and self.stats.HasSplash) or false
end

function PlantStatsHelperClass:PiercesShields(): boolean
	return (self.stats and self.stats.PiercesShields) or false
end

function PlantStatsHelperClass:CanStun(): boolean
	return (self.stats and self.stats.CanStun) or false
end

function PlantStatsHelperClass:CanHitFlying(): boolean
	return (self.stats and self.stats.CanHitFlying) or false
end

function PlantStatsHelperClass:IsHoming(): boolean
	return (self.stats and self.stats.IsHoming) or false
end

function PlantStatsHelperClass:IsRepeater(): boolean
	return (self.stats and self.stats.IsRepeater) or false
end

function PlantStatsHelperClass:ProducesSun(): boolean
	return (self.stats and self.stats.ProducesSun) or false
end

-- ============================================
-- String Getters
-- ============================================

function PlantStatsHelperClass:GetProjectileVariant(default: string?): string?
	return if self.stats and self.stats.ProjectileVariant then self.stats.ProjectileVariant else default
end

function PlantStatsHelperClass:GetStunProjectileVariant(default: string?): string?
	return if self.stats and self.stats.StunProjectileVariant then self.stats.StunProjectileVariant else default
end

-- ============================================
-- Vector3 Getters
-- ============================================

function PlantStatsHelperClass:GetProjectileSpawnOffset(default: Vector3?): Vector3?
	return if self.stats and self.stats.ProjectileSpawnOffset then self.stats.ProjectileSpawnOffset else default
end

-- ============================================
-- Module API
-- ============================================

local PlantStatsHelper = {}

--[[
	Create a helper from stats (may be nil)
	
	@param stats PlantStats? - Plant stats or nil
	@return PlantStatsHelper - Safe accessor object
]]
function PlantStatsHelper.FromStats(stats: PlantData.PlantStats?): PlantStatsHelper
	local self = setmetatable({
		stats = stats,
	}, PlantStatsHelperClass)
	return self :: PlantStatsHelper
end

--[[
	Create a helper from plant type name
	
	@param plantType string - Plant type name (e.g., "Peashooter")
	@return PlantStatsHelper - Safe accessor object
]]
function PlantStatsHelper.FromType(plantType: string): PlantStatsHelper
	local stats = PlantData.GetStats(plantType)
	return PlantStatsHelper.FromStats(stats)
end

--[[
	Quick access to a single stat with default
	Useful for one-off access without creating a helper object
	
	@param stats PlantStats? - Plant stats or nil
	@param field string - Field name to access
	@param default any - Default value if field is nil
	@return any - The value or default
]]
function PlantStatsHelper.Get(stats: PlantData.PlantStats?, field: string, default: any): any
	if stats and (stats :: any)[field] ~= nil then
		return (stats :: any)[field]
	end
	return default
end

--[[
	Quick access to a boolean stat
	
	@param stats PlantStats? - Plant stats or nil
	@param field string - Field name to access
	@return boolean - The value or false
]]
function PlantStatsHelper.GetBool(stats: PlantData.PlantStats?, field: string): boolean
	return (stats and (stats :: any)[field]) or false
end

return PlantStatsHelper
