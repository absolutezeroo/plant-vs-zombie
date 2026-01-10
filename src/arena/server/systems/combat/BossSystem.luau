--!strict
--[[
	BossSystem.luau - Server-side boss zombie behavior
	
	Priority: 175 (Simulation phase - after combat, before death)
	
	Handles:
	- Gargantuar spawning Imp at 50% health
	- Boss-specific death effects
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local MapConfig = require(Shared.config.MapConfig)
local ZombieData = require(Shared.data.ZombieData)
local EntityPool = require(Shared.utils.EntityPool)

-- Network
local Network = require(Shared.network.generated.server)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	MINION_SPAWN_OFFSET_X = 2, -- Studs behind boss
	MINION_SPAWN_Y = 1,
})

-- 3. STATE
local State = {
	IsInitialized = false,
	HasSpawnedMinion = {} :: {[number]: boolean},
	CachedZombieDir = Vector3.new(-1, 0, 0),
}

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then return end
	
	-- Pre-cache MapConfig values to avoid yield in OnStep
	if MapConfig.IsInitialized() then
		State.CachedZombieDir = MapConfig.GetZombieDirection()
	else
		-- Fallback: force init (should not happen if bootstrap is correct)
		State.CachedZombieDir = MapConfig.GetZombieDirection()
	end
	
	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	State.IsInitialized = false
	State.CachedZombieDir = Vector3.new(-1, 0, 0)
	table.clear(State.HasSpawnedMinion)
end

-- Helper: Spawn a minion zombie at the boss's position
local function spawnMinion(world, bossId: number, minionType: string, lane: number, posX: number, posZ: number)
	local minionStats = ZombieData[minionType]
	if not minionStats then return end
	
	local direction = State.CachedZombieDir
	
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
	
	if not minionId then return end
	
	-- Broadcast to clients
	Network.ZombieSpawned.FireAll({
		EntityId = minionId,
		ZombieType = minionType,
		Lane = lane,
		PositionX = posX + CONFIG.MINION_SPAWN_OFFSET_X,
	})
end

-- 6. MAIN LOOP
local function OnStep(world)
	-- Check all zombies for boss behavior
	for zombieId, health, zombie, pos in world:query(Components.HealthComponent, Components.ZombieTypeComponent, Components.PositionComponent) do
		local stats = ZombieData[zombie.ZombieType]
		if not stats or not stats.IsBoss then
			continue
		end
		
		-- Check if boss should spawn minion at 50% health
		if stats.SpawnsOnHalfHealth and not State.HasSpawnedMinion[zombieId] then
			local halfHealth = health.Max / 2
			
			if health.Current <= halfHealth and health.Current > 0 then
				local spawnCount = stats.SpawnCount or 1
				local minionType = stats.SpawnsOnHalfHealth
				
				for i = 1, spawnCount do
					local offsetZ = (i - 1) * 2
					spawnMinion(world, zombieId, minionType, zombie.Lane, pos.X, pos.Z + offsetZ)
				end
				
				State.HasSpawnedMinion[zombieId] = true
			end
		end
	end
	
	-- Clean up tracking for despawned bosses
	for zombieId in State.HasSpawnedMinion do
		if not world:contains(zombieId) then
			State.HasSpawnedMinion[zombieId] = nil
		end
	end
end

-- 7. EXPORT
return {
	priority = 175,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
