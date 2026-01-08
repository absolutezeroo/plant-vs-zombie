--!strict
--[[
	BossSystem.luau - Server-side boss zombie behavior
	
	Priority: 175 (Simulation phase - after combat, before death)
	
	Handles:
	- Gargantuar spawning Imp at 50% health
	- Boss-specific death effects
	- Future boss mechanics
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - processes boss behavior
	- Dispose(): Clear tracking state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local ZombieData = require(Shared.data.ZombieData)
local Logger = require(Shared.utils.Logger)
local Types = require(Shared.Types)

-- Network
local Network = require(Shared.network.generated.server)

-- Type alias for world parameter
type MatterWorld = Types.MatterWorld

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local MovementComponent = Components.MovementComponent

-- Track bosses that have already spawned their minions
local _hasSpawnedMinion: {[number]: boolean} = {}

-- Spawn a minion zombie at the boss's position
local function spawnMinion(world: MatterWorld, bossId: number, minionType: string, lane: number, posX: number, posZ: number)
	local minionStats = ZombieData[minionType]
	if not minionStats then
		Logger.Warn("BossSystem", `Unknown minion type: {minionType}`)
		return
	end
	
	-- Spawn the minion slightly behind the boss
	local direction = MapConfig.GetZombieDirection()
	
	local minionId = world:spawn(
		PositionComponent({
			X = posX + 2, -- Behind the boss
			Y = 1,
			Z = posZ,
		}),
		HealthComponent({
			Current = minionStats.Health,
			Max = minionStats.Health,
		}),
		MovementComponent({
			VelocityX = direction.X * minionStats.Speed,
			VelocityY = 0,
			VelocityZ = direction.Z * minionStats.Speed,
		}),
		ZombieTypeComponent({
			ZombieType = minionType,
			Lane = lane,
			SpawnTime = os.clock(),
		})
	)
	
	-- Broadcast to clients
	Network.ZombieSpawned.FireAll({
		EntityId = minionId,
		ZombieType = minionType,
		Lane = lane,
		PositionX = posX + 2,
	})
	
	Logger.Info("BossSystem", `Boss {bossId} spawned {minionType} (entity {minionId}) in lane {lane}`)
end

local function BossSystem(world: MatterWorld)
	-- Check all zombies for boss behavior
	for zombieId, health, zombie, pos in world:query(HealthComponent, ZombieTypeComponent, PositionComponent) do
		local stats = ZombieData[zombie.ZombieType]
		if not stats or not stats.IsBoss then
			continue
		end
		
		-- Check if boss should spawn minion at 50% health
		if stats.SpawnsOnHalfHealth and not _hasSpawnedMinion[zombieId] then
			local halfHealth = health.Max / 2
			
			if health.Current <= halfHealth and health.Current > 0 then
				-- Spawn minion(s)
				local spawnCount = stats.SpawnCount or 1
				local minionType = stats.SpawnsOnHalfHealth
				
				for i = 1, spawnCount do
					-- Slight offset for multiple spawns
					local offsetZ = (i - 1) * 2
					spawnMinion(world, zombieId, minionType, zombie.Lane, pos.X, pos.Z + offsetZ)
				end
				
				-- Mark as spawned
				_hasSpawnedMinion[zombieId] = true
				
				Logger.Info("BossSystem", `Gargantuar {zombieId} threw {spawnCount} {minionType}(s)!`)
			end
		end
	end
	
	-- Clean up tracking for despawned bosses
	for zombieId in _hasSpawnedMinion do
		if not world:contains(zombieId) then
			_hasSpawnedMinion[zombieId] = nil
		end
	end
end

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	table.clear(_hasSpawnedMinion)
end

return {
	_name = "BossSystem",
	priority = 175, -- After combat (170), before death (180)
	system = BossSystem,
	Init = Init,
	Dispose = Dispose,
}
