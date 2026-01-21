--!strict
--[[
	BossSystem.luau - Server-side boss zombie behavior
	
	Priority: 175 (Simulation phase - after combat, before death)
	
	Handles:
	- Gargantuar spawning Imp at 50% health
	- Boss-specific death effects
	
	V3 Architecture: Matter Hooks pattern
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages.MatterHooks)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local MapConfig = require(Shared.config.MapConfig)
local ZombieData = require(Shared.data.ZombieData)
local EntityPool = require(Shared.utils.ecs.EntityPool)

-- Network
local Network = require(Shared.network.generated.server)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	MINION_SPAWN_OFFSET_X = 2, -- Studs behind boss
	MINION_SPAWN_Y = 1,
})

-- 3. TYPES
type BossState = {
	HasSpawnedMinion: { [number]: boolean },
	CachedZombieDir: Vector3,
}

-- Helper: Spawn a minion zombie at the boss's position
local function spawnMinion(
	world,
	state: { value: BossState },
	bossId: number,
	minionType: string,
	lane: number,
	posX: number,
	posZ: number
)
	local minionStats = ZombieData[minionType]
	if not minionStats then
		return
	end

	local direction = state.value.CachedZombieDir

	local minionId = EntityPool.Spawn(
		Components.PositionComponent({
			X = posX + CONFIG.MINION_SPAWN_OFFSET_X,
			Y = CONFIG.MINION_SPAWN_Y,
			Z = posZ,
		}),
		Components.HealthComponent({
			Current = minionStats.Health,
			Max = minionStats.Health,
		}),
		Components.MovementComponent({
			VelocityX = direction.X * minionStats.Speed,
			VelocityY = 0,
			VelocityZ = direction.Z * minionStats.Speed,
		}),
		Components.ZombieTypeComponent({
			ZombieType = minionType,
			Lane = lane,
			SpawnTime = os.clock(),
		})
	)

	if not minionId then
		return
	end

	-- Broadcast to clients
	Network.ZombieSpawned.FireAll({
		EntityId = minionId,
		ZombieType = minionType,
		Lane = lane,
		PositionX = posX + CONFIG.MINION_SPAWN_OFFSET_X,
	})
end

-- 4. SYSTEM FUNCTION
local function BossSystem(world)
	-- State managed via Hooks.useMap
	local state = Hooks.useMap("BossState", {
		HasSpawnedMinion = {} :: { [number]: boolean },
		CachedZombieDir = Vector3.new(-1, 0, 0),
	})

	-- Refresh cached MapConfig values (may change after loadmap)
	if MapConfig.IsInitialized() then
		state.value.CachedZombieDir = MapConfig.GetZombieDirection()
	end

	-- Check all zombies for boss behavior
	for zombieId, health, zombie, pos in
		world:query(Components.HealthComponent, Components.ZombieTypeComponent, Components.PositionComponent)
	do
		local stats = ZombieData[zombie.ZombieType]
		if not stats or not stats.IsBoss then
			continue
		end

		-- Check if boss should spawn minion at 50% health
		if stats.SpawnsOnHalfHealth and not state.value.HasSpawnedMinion[zombieId] then
			local halfHealth = health.Max / 2

			if health.Current <= halfHealth and health.Current > 0 then
				local spawnCount = stats.SpawnCount or 1
				local minionType = stats.SpawnsOnHalfHealth

				for i = 1, spawnCount do
					local offsetZ = (i - 1) * 2
					spawnMinion(world, state, zombieId, minionType, zombie.Lane, pos.X, pos.Z + offsetZ)
				end

				state.value.HasSpawnedMinion[zombieId] = true
			end
		end
	end

	-- Clean up tracking for despawned bosses
	for zombieId in state.value.HasSpawnedMinion do
		if not world:contains(zombieId) then
			state.value.HasSpawnedMinion[zombieId] = nil
		end
	end
end

-- 5. EXPORT
return {
	priority = 175,
	system = BossSystem,
}
