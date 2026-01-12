--!strict
--[[
	PoisonCloudSystem.luau - Handles poison clouds and poisoned zombies
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 365 (Combat processing)
	
	Spawns poison clouds when plants with PoisonCloudComponent die.
	Damages zombies inside poison clouds over time.
	
	LIFECYCLE:
	- Init(): No init needed
	- OnStep(): Main loop (CANNOT yield) - processes poison clouds
	- Dispose(): Clear active clouds
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)
local LaneCache = require(Shared.utils.LaneCache)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local ECSUtils = require(Shared.utils.ECSUtils)
local MathUtils = require(Shared.utils.MathUtils)

-- Network for VFX events
local Network = require(Shared.network.generated.server)

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 365,
	TICK_INTERVAL = 1, -- Damage tick every second
})

-- ============================================================
-- SECTION 3: STATE (all mutable data)
-- ============================================================
export type ActiveCloud = {
	Position: { X: number, Y: number, Z: number },
	Lane: number,
	Radius: number,
	DamagePerSecond: number,
	RemainingDuration: number,
	LastTickTime: number,
}

local State = {
	ActiveClouds = {} :: { ActiveCloud },
	IsInitialized = false,
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

-- Spawn a poison cloud at a position
-- NOTE: MapConfig.WorldToGrid is safe to call - MapConfig.Initialize() is called at server bootstrap
local function spawnPoisonCloud(
	position: { X: number, Y: number, Z: number },
	radius: number,
	damagePerSecond: number,
	duration: number
)
	local _, lane = MapConfig.WorldToGrid(Vector3.new(position.X, position.Y, position.Z))

	table.insert(State.ActiveClouds, {
		Position = position,
		Lane = lane or 3,
		Radius = radius,
		DamagePerSecond = damagePerSecond,
		RemainingDuration = duration,
		LastTickTime = os.clock(),
	})

	-- Fire VFX event for poison cloud
	Network.PoisonCloudVFX.FireAll({
		PositionX = position.X,
		PositionY = position.Y,
		PositionZ = position.Z,
		Radius = radius,
		Duration = duration,
	})

	Logger.Debug(
		"PoisonCloudSystem",
		`Spawned poison cloud at ({position.X}, {position.Z}) lane {lane or 3} - radius {radius}, {damagePerSecond} dps for {duration}s`
	)
end

-- ============================================================
-- SECTION 5: ONSTEP (main ECS loop)
-- ============================================================
local function OnStep(world)
	local currentTime = os.clock()
	local cloudsToRemove = {}

	-- React to plant deaths with PoisonCloudComponent
	for entityId, record in world:queryChanged(Components.HealthComponent) do
		-- Check if entity just died
		if record.new and record.new.Current <= 0 then
			-- Check if it had PoisonCloudComponent
			local poisonCloud = world:get(entityId, Components.PoisonCloudComponent)
			if not poisonCloud then
				continue
			end

			local pos = world:get(entityId, Components.PositionComponent)
			if not pos then
				continue
			end

			-- Spawn cloud at death location
			spawnPoisonCloud(
				{ X = pos.X, Y = pos.Y, Z = pos.Z },
				poisonCloud.Radius,
				poisonCloud.DamagePerSecond,
				poisonCloud.Duration
			)
		end
	end

	-- Process each active cloud
	for i, cloud in State.ActiveClouds do
		local elapsed = currentTime - cloud.LastTickTime
		cloud.RemainingDuration -= elapsed

		if cloud.RemainingDuration <= 0 then
			table.insert(cloudsToRemove, i)
		else
			-- Tick damage every second
			if elapsed >= CONFIG.TICK_INTERVAL then
				cloud.LastTickTime = currentTime

				-- Calculate how many lanes the cloud radius covers
				local laneRadius = math.ceil(cloud.Radius / GridConfig.CELL_SIZE)

				-- O(lane_range) lookup instead of O(N) world:query
				local zombiesInRange = LaneCache.GetEntitiesInLaneRange(cloud.Lane, laneRadius)

				-- Find zombies in cloud
				for _, entityId in zombiesInRange do
					if not world:contains(entityId) then
						continue
					end

					local pos = LaneCache.GetPosition(entityId)
					if not pos then
						continue
					end

					local distance = MathUtils.Distance2D(pos.X, pos.Z, cloud.Position.X, cloud.Position.Z)

					if distance <= cloud.Radius then
						-- Apply poison damage
						local actualDamage, died =
							ECSUtils.DamageEntity(world, entityId, cloud.DamagePerSecond, Components)
						if actualDamage > 0 then
							world:insert(
								entityId,
								Components.DamageEvent({
									Amount = cloud.DamagePerSecond,
									DamageType = "Poison",
									SourceEntityId = nil,
								})
							)

							-- Send network event for client visual feedback (floating damage numbers)
							local targetHealth = world:get(entityId, Components.HealthComponent)
							Network.EntityDamaged.FireAll({
								EntityId = entityId,
								NewHealth = targetHealth and targetHealth.Current or 0,
								DamageAmount = actualDamage,
								DamageType = "Poison",
							})
						end
					end
				end
			end
		end
	end

	-- Remove expired clouds (in reverse order to preserve indices)
	for i = #cloudsToRemove, 1, -1 do
		table.remove(State.ActiveClouds, cloudsToRemove[i])
	end
end

-- ============================================================
-- SECTION 6: INIT / DISPOSE
-- ============================================================
local function Init(_world)
	if State.IsInitialized then
		return
	end
	State.IsInitialized = true
	Logger.Debug("PoisonCloudSystem", "Initialized")
end

local function Dispose()
	State.IsInitialized = false
	table.clear(State.ActiveClouds)
	Logger.Debug("PoisonCloudSystem", "Disposed")
end

-- ============================================================
-- SECTION 7: MODULE EXPORT
-- ============================================================
return {
	priority = CONFIG.PRIORITY,
	system = OnStep,
	Init = Init,
	Dispose = Dispose,
}
