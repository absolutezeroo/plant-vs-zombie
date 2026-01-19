--!strict
--[[
	NetworkUtils.luau - Server-side network broadcast helpers
	
	Consolidates common network broadcast patterns to reduce code duplication
	and ensure consistent event payloads across the codebase.
	
	PHILOSOPHY:
	- All functions are thin wrappers around Zap-generated Network events
	- Provides sensible defaults and consistent payloads
	- Reduces risk of typos or missing fields
	
	USAGE:
	local NetworkUtils = require(Shared.utils.network.NetworkUtils)
	NetworkUtils.BroadcastEntityDied(zombieId)
	NetworkUtils.BroadcastDamage(zombieId, 50, "Projectile", position)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.network.generated.server)

local NetworkUtils = {}

-- ============================================
-- Entity Events
-- ============================================

--[[
	Broadcast that an entity died
	
	@param entityId number - Entity that died
]]
function NetworkUtils.BroadcastEntityDied(entityId: number)
	Network.EntityDied.FireAll({
		EntityId = entityId,
	})
end

--[[
	Broadcast that an entity took damage
	
	@param entityId number - Entity that was damaged
	@param damage number - Amount of damage dealt
	@param damageType string? - Type of damage ("Projectile", "Melee", "Poison", etc.)
	@param position Vector3? - Position where damage occurred
]]
function NetworkUtils.BroadcastDamage(
	entityId: number,
	damage: number,
	damageType: string?,
	position: Vector3?
)
	Network.EntityDamaged.FireAll({
		EntityId = entityId,
		Damage = damage,
		DamageType = damageType or "Unknown",
		Position = position or Vector3.zero,
	})
end

-- ============================================
-- VFX Events
-- ============================================

--[[
	Broadcast an explosion VFX
	
	@param position Vector3 - Center of explosion
	@param radius number? - Explosion radius (default 6)
	@param variant string? - Explosion variant ("Cherry", "Jalapeno", "PotaoMine", etc.)
]]
function NetworkUtils.BroadcastExplosion(
	position: Vector3,
	radius: number?,
	variant: string?
)
	Network.ExplosionVFX.FireAll({
		Position = position,
		Radius = radius or 6,
		Variant = variant or "Default",
	})
end

--[[
	Broadcast a projectile hit VFX
	
	@param position Vector3 - Position of impact
	@param variant string? - Projectile variant ("Pea", "SnowPea", "Butter", etc.)
]]
function NetworkUtils.BroadcastProjectileHit(
	position: Vector3,
	variant: string?
)
	Network.ProjectileHit.FireAll({
		Position = position,
		Variant = variant or "Pea",
	})
end

--[[
	Broadcast splash damage VFX
	
	@param position Vector3 - Center of splash
	@param radius number? - Splash radius (default 6)
]]
function NetworkUtils.BroadcastSplash(
	position: Vector3,
	radius: number?
)
	Network.SplashDamageVFX.FireAll({
		Position = position,
		Radius = radius or 6,
	})
end

-- ============================================
-- Projectile Events
-- ============================================

--[[
	Broadcast projectile spawned
	
	@param entityId number - Projectile entity ID
	@param position Vector3 - Spawn position
	@param velocity Vector3 - Initial velocity
	@param variant string - Projectile variant
	@param sourceId number? - Source entity ID (optional)
]]
function NetworkUtils.BroadcastProjectileSpawned(
	entityId: number,
	position: Vector3,
	velocity: Vector3,
	variant: string,
	sourceId: number?
)
	Network.ProjectileSpawned.FireAll({
		EntityId = entityId,
		Position = position,
		Velocity = velocity,
		Variant = variant,
		SourceId = sourceId or 0,
	})
end

--[[
	Broadcast projectile despawned
	
	@param entityId number - Projectile entity ID
]]
function NetworkUtils.BroadcastProjectileDespawned(entityId: number)
	Network.ProjectileDespawned.FireAll({
		EntityId = entityId,
	})
end

-- ============================================
-- Status Effect Events
-- ============================================

--[[
	Broadcast status effect applied
	
	@param entityId number - Entity that received the status
	@param statusType string - Type of status ("Frozen", "Burning", "Stunned", etc.)
	@param duration number? - Duration in seconds (optional)
]]
function NetworkUtils.BroadcastStatusApplied(
	entityId: number,
	statusType: string,
	duration: number?
)
	Network.StatusApplied.FireAll({
		EntityId = entityId,
		StatusType = statusType,
		Duration = duration or 0,
	})
end

--[[
	Broadcast status effect removed
	
	@param entityId number - Entity that lost the status
	@param statusType string - Type of status that was removed
]]
function NetworkUtils.BroadcastStatusRemoved(
	entityId: number,
	statusType: string
)
	Network.StatusRemoved.FireAll({
		EntityId = entityId,
		StatusType = statusType,
	})
end

-- ============================================
-- Economy Events
-- ============================================

--[[
	Broadcast sun collected
	
	@param playerId number - Player who collected the sun
	@param amount number - Amount of sun collected
	@param position Vector3? - Position where sun was collected
]]
function NetworkUtils.BroadcastSunCollected(
	playerId: number,
	amount: number,
	position: Vector3?
)
	Network.SunCollected.FireAll({
		PlayerId = playerId,
		Amount = amount,
		Position = position or Vector3.zero,
	})
end

-- ============================================
-- Plant Events
-- ============================================

--[[
	Broadcast plant spawned
	
	@param entityId number - Plant entity ID
	@param plantType string - Type of plant ("Peashooter", "Sunflower", etc.)
	@param position Vector3 - Plant position
	@param row number - Grid row
	@param column number - Grid column
]]
function NetworkUtils.BroadcastPlantSpawned(
	entityId: number,
	plantType: string,
	position: Vector3,
	row: number,
	column: number
)
	Network.PlantSpawned.FireAll({
		EntityId = entityId,
		PlantType = plantType,
		Position = position,
		Row = row,
		Column = column,
	})
end

-- ============================================
-- Zombie Events
-- ============================================

--[[
	Broadcast zombie spawned
	
	@param entityId number - Zombie entity ID
	@param zombieType string - Type of zombie
	@param position Vector3 - Spawn position
	@param lane number - Lane number
]]
function NetworkUtils.BroadcastZombieSpawned(
	entityId: number,
	zombieType: string,
	position: Vector3,
	lane: number
)
	Network.ZombieSpawned.FireAll({
		EntityId = entityId,
		ZombieType = zombieType,
		Position = position,
		Lane = lane,
	})
end

--[[
	Broadcast zombie hypnotized
	
	@param zombieId number - Zombie entity ID
]]
function NetworkUtils.BroadcastZombieHypnotized(zombieId: number)
	Network.ZombieHypnotized.FireAll({
		ZombieId = zombieId,
	})
end

--[[
	Broadcast zombie diverted (e.g., by Garlic)
	
	@param zombieId number - Zombie entity ID
	@param fromLane number - Original lane
	@param toLane number - New lane
]]
function NetworkUtils.BroadcastZombieDiverted(
	zombieId: number,
	fromLane: number,
	toLane: number
)
	Network.ZombieDiverted.FireAll({
		ZombieId = zombieId,
		FromLane = fromLane,
		ToLane = toLane,
	})
end

-- ============================================
-- Fog Events
-- ============================================

--[[
	Broadcast fog enabled
	
	@param foggyColumns {number} - Columns covered by fog
]]
function NetworkUtils.BroadcastFogEnabled(foggyColumns: { number })
	Network.FogEnabled.FireAll({
		FoggyColumns = foggyColumns,
	})
end

--[[
	Broadcast fog cleared
]]
function NetworkUtils.BroadcastFogCleared()
	Network.FogCleared.FireAll({})
end

--[[
	Broadcast fog illumination update
	
	@param illuminatedCells {{Row: number, Column: number}} - Cells illuminated by Planterns
]]
function NetworkUtils.BroadcastFogIllumination(illuminatedCells: { { Row: number, Column: number } })
	Network.FogIlluminationUpdate.FireAll({
		IlluminatedCells = illuminatedCells,
	})
end

return NetworkUtils
