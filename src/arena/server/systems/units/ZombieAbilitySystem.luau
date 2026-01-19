--!strict
--[[
	ZombieAbilitySystem.luau - Process zombie ability tick behaviors
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 90 (Environment phase - before movement, after tile modifiers)
	
	Handles:
	- OnTick ability hooks (Regeneration, Catapult projectiles, etc.)
	- SpawnMinionEvent processing (Gargantuar -> Imp)
	- DeathExplosionEvent processing (Jack-in-the-Box)
	- RageComponent speed application
	
	LIFECYCLE:
	- Init(): Cache references
	- OnStep(): Process zombie abilities (CANNOT yield)
	- Dispose(): Clear state
	
	EXTENSIBILITY:
	- New OnTick behaviors: Add to ZombieAbilityData.Abilities with OnTick hook
	- New events: Add component, process in OnStep
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local ZombieData = require(Shared.data.ZombieData)
local ZombieAbilityData = require(Shared.data.ZombieAbilityData)
local Logger = require(Shared.utils.Logger)
local LaneCache = require(Shared.utils.LaneCache)
local ECSUtils = require(Shared.utils.ECSUtils)
local EntityPool = require(Shared.utils.EntityPool)
local NetworkUtils = require(Shared.utils.NetworkUtils)

-- Server modules
local Server = script.Parent.Parent.Parent

-- Network (lazy load)
local Network: any = nil
local function getNetwork()
	if not Network then
		Network = require(Shared.network.generated.server)
	end
	return Network
end

-- WaveSpawner (lazy load for minion spawning)
local WaveSpawner: any = nil
local function getWaveSpawner()
	if not WaveSpawner then
		WaveSpawner = require(Server.managers.wave.WaveSpawner)
	end
	return WaveSpawner.GetInstance()
end

-- ============================================================
-- SECTION 2: CONFIG
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 90,
	
	-- OnTick is called for zombies with tick-based abilities
	-- Throttled to avoid per-frame overhead for all zombies
	TICK_INTERVAL = 0.25, -- Check abilities every 0.25 seconds
	
	-- Death explosion defaults
	DEFAULT_EXPLOSION_RADIUS = 3,
	DEFAULT_EXPLOSION_DAMAGE = 100,
})

-- ============================================================
-- SECTION 3: STATE
-- ============================================================
local State = {
	IsInitialized = false,
	LastTickTime = 0,
	
	-- Cache zombies with OnTick abilities for efficiency
	TickableZombies = {} :: { [number]: string }, -- entityId -> zombieType
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

-- Check if a zombie type has any OnTick abilities
local function hasTickAbility(zombieType: string): boolean
	local abilities = ZombieAbilityData.GetAbilitiesForZombie(zombieType)
	for _, ability in abilities do
		if ability.OnTick then
			return true
		end
	end
	return false
end

-- Process SpawnMinionEvent components
local function processSpawnMinionEvents(world: any, currentTime: number)
	for entityId, event, pos in world:query(Components.SpawnMinionEvent, Components.PositionComponent) do
		if event.Processed then
			continue
		end
		
		-- Get zombie's lane
		local zombie = world:get(entityId, Components.ZombieTypeComponent)
		local lane = zombie and zombie.Lane or 1
		
		-- Spawn the minion at current position
		local spawner = getWaveSpawner()
		local minionId = spawner:SpawnZombie(world, event.MinionType, lane, nil)
		
		if minionId and minionId > 0 then
			-- Position minion near parent zombie
			world:insert(minionId, Components.PositionComponent({
				X = pos.X + 2, -- Slightly behind parent
				Y = pos.Y,
				Z = pos.Z,
			}))
			
			Logger.Info("ZombieAbility", `{zombie and zombie.ZombieType or "Unknown"} spawned {event.MinionType} minion`)
		end
		
		-- Mark as processed (will be cleaned up by EventCleanupSystem)
		world:insert(entityId, Components.SpawnMinionEvent({
			MinionType = event.MinionType,
			SpawnTime = event.SpawnTime,
			Processed = true,
		}))
	end
end

-- Process DeathExplosionEvent components
local function processDeathExplosions(world: any, currentTime: number)
	for entityId, event, pos in world:query(Components.DeathExplosionEvent, Components.PositionComponent) do
		if event.Processed then
			continue
		end
		
		local radius = event.Radius or CONFIG.DEFAULT_EXPLOSION_RADIUS
		local damage = event.Damage or CONFIG.DEFAULT_EXPLOSION_DAMAGE
		local damagesPlants = event.DamagesPlants
		
		local hitCount = 0
		
		if damagesPlants then
			-- Damage nearby plants (zombie explosion like Jack-in-the-Box)
			-- Use grid lookup for efficiency
			local centerColumn = math.floor(pos.X / GridConfig.CELL_SIZE) + 1
			local centerLane = math.floor(pos.Z / GridConfig.CELL_SIZE) + 1
			local cellRadius = math.ceil(radius / GridConfig.CELL_SIZE)
			
			for col = centerColumn - cellRadius, centerColumn + cellRadius do
				for lane = centerLane - cellRadius, centerLane + cellRadius do
					local plantId = LaneCache.GetPlantAt(col, lane)
					if plantId and world:contains(plantId) then
						local plantPos = world:get(plantId, Components.PositionComponent)
						if plantPos then
							local dx = plantPos.X - pos.X
							local dz = plantPos.Z - pos.Z
							local dist = math.sqrt(dx * dx + dz * dz)
							
							if dist <= radius then
								local _, killed = ECSUtils.DamageEntity(world, plantId, damage, Components)
								if killed then
									hitCount += 1
								end
							end
						end
					end
				end
			end
		else
			-- Damage nearby zombies (hypnotized zombie explosion)
			local allZombies = LaneCache.GetAllZombies()
			for _, zombieId in allZombies do
				if zombieId == entityId then continue end -- Don't damage self
				if not world:contains(zombieId) then continue end
				
				local zombiePos = world:get(zombieId, Components.PositionComponent)
				if zombiePos then
					local dx = zombiePos.X - pos.X
					local dz = zombiePos.Z - pos.Z
					local dist = math.sqrt(dx * dx + dz * dz)
					
					if dist <= radius then
						local _, killed = ECSUtils.DamageEntity(world, zombieId, damage, Components)
						if killed then
							hitCount += 1
						end
					end
				end
			end
		end
		
		-- Broadcast explosion VFX
		getNetwork().ExplosionVFX.FireAll({
			PositionX = pos.X,
			PositionY = pos.Y,
			PositionZ = pos.Z,
			Radius = radius,
		})
		
		Logger.Info("ZombieAbility", `Death explosion at ({pos.X}, {pos.Z}) hit {hitCount} targets`)
		
		-- Mark as processed
		world:insert(entityId, Components.DeathExplosionEvent({
			Radius = event.Radius,
			Damage = event.Damage,
			DamagesPlants = event.DamagesPlants,
			TriggerTime = event.TriggerTime,
			Processed = true,
		}))
	end
end

-- Process RageComponent speed modifications
local function processRageEffects(world: any)
	for zombieId, rage, zombie, movement in 
		world:query(Components.RageComponent, Components.ZombieTypeComponent, Components.MovementComponent)
	do
		local stats = ZombieData[zombie.ZombieType]
		if not stats then continue end
		
		local baseSpeed = stats.Speed
		local ragedSpeed = baseSpeed * rage.SpeedMultiplier
		
		-- Get current velocity direction
		local currentVelX = movement.VelocityX
		local currentVelZ = movement.VelocityZ
		local currentSpeed = math.sqrt(currentVelX * currentVelX + currentVelZ * currentVelZ)
		
		-- Only update if not already at raged speed
		if currentSpeed > 0 and math.abs(currentSpeed - ragedSpeed) > 0.1 then
			local dirX = currentVelX / currentSpeed
			local dirZ = currentVelZ / currentSpeed
			
			world:insert(zombieId, Components.MovementComponent({
				VelocityX = dirX * ragedSpeed,
				VelocityY = 0,
				VelocityZ = dirZ * ragedSpeed,
			}))
		end
	end
end

-- Process OnTick hooks for zombies with tick abilities
local function processTickAbilities(world: any, currentTime: number, deltaTime: number)
	-- Register new zombies with tick abilities
	for zombieId, zombie in world:query(Components.ZombieTypeComponent) do
		if not State.TickableZombies[zombieId] then
			if hasTickAbility(zombie.ZombieType) then
				State.TickableZombies[zombieId] = zombie.ZombieType
			end
		end
	end
	
	-- Process tick abilities
	for zombieId, zombieType in State.TickableZombies do
		if not world:contains(zombieId) then
			State.TickableZombies[zombieId] = nil
			continue
		end
		
		local health = world:get(zombieId, Components.HealthComponent)
		local pos = world:get(zombieId, Components.PositionComponent)
		
		local ctx: ZombieAbilityData.AbilityContext = {
			EntityId = zombieId,
			World = world,
			ZombieType = zombieType,
			CurrentHealth = health and health.Current or 0,
			MaxHealth = health and health.Max or 0,
		}
		
		-- Get abilities and call OnTick
		local abilities = ZombieAbilityData.GetAbilitiesForZombie(zombieType)
		for _, ability in abilities do
			if ability.OnTick then
				ability.OnTick(ctx, deltaTime)
			end
		end
	end
end

-- ============================================================
-- SECTION 5: ONSTEP (main ECS loop)
-- ============================================================
local function OnStep(world: any, deltaTime: number)
	local currentTime = os.clock()
	
	-- Process spawn minion events (Gargantuar -> Imp)
	processSpawnMinionEvents(world, currentTime)
	
	-- Process death explosion events (Jack-in-the-Box)
	processDeathExplosions(world, currentTime)
	
	-- Process rage speed effects
	processRageEffects(world)
	
	-- Throttle OnTick processing for performance
	if currentTime - State.LastTickTime >= CONFIG.TICK_INTERVAL then
		processTickAbilities(world, currentTime, currentTime - State.LastTickTime)
		State.LastTickTime = currentTime
	end
	
	-- Cleanup despawned entities from cache
	for entityId in State.TickableZombies do
		if not world:contains(entityId) then
			State.TickableZombies[entityId] = nil
		end
	end
end

-- ============================================================
-- SECTION 6: INIT / DISPOSE
-- ============================================================

local function Init(_world: any)
	if State.IsInitialized then
		return
	end
	
	State.IsInitialized = true
	State.LastTickTime = os.clock()
	
	Logger.Info("ZombieAbilitySystem", "Initialized")
end

local function Dispose()
	table.clear(State.TickableZombies)
	State.IsInitialized = false
	State.LastTickTime = 0
	
	Logger.Debug("ZombieAbilitySystem", "Disposed")
end

-- ============================================================
-- SECTION 7: EXPORT
-- ============================================================

return {
	priority = CONFIG.PRIORITY,
	system = OnStep,
	Init = Init,
	Dispose = Dispose,
}
