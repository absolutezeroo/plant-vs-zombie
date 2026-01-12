--!strict
--[[
	SplashDamageSystem.luau - Handles splash/area damage from mutations
	
	Priority: 345 (Before individual damage processing)
	
	Queries ProjectileHitEvent + SplashDamageComponent to apply AoE damage.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local LaneCache = require(Shared.utils.LaneCache)
local GridConfig = require(Shared.config.GridConfig)
local ECSUtils = require(Shared.utils.ECSUtils)
local MathUtils = require(Shared.utils.MathUtils)

-- Network for VFX events
local Network = require(Shared.network.generated.server)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	DISTANCE_FALLOFF = 0.3, -- 30% damage falloff at max range
	DEFAULT_CENTER_LANE = 3, -- Middle lane fallback
})

-- 3. STATE (minimal - stateless system)
local State = {
	IsInitialized = false,
}

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then return end
	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	State.IsInitialized = false
end

-- Helper: Apply splash damage at a position
-- Uses LaneCache for O(lane_range) lookup instead of O(N) world:query
local function applySplashDamage(
	world, 
	impactPosition: {X: number, Y: number, Z: number},
	baseDamage: number,
	splashRadius: number,
	splashDamagePercent: number,
	sourceEntityId: number?,
	excludeEntityId: number?,
	impactLane: number?
)
	local splashDamage = math.floor(baseDamage * splashDamagePercent)
	if splashDamage <= 0 then return end
	
	-- Calculate how many lanes the splash radius covers
	local laneRadius = math.ceil(splashRadius / GridConfig.CELL_SIZE)
	local centerLane = impactLane or CONFIG.DEFAULT_CENTER_LANE
	
	-- O(lane_range) lookup instead of O(N) world:query
	local zombiesInRange = LaneCache.GetEntitiesInLaneRange(centerLane, laneRadius)
	
	for _, entityId in zombiesInRange do
		if excludeEntityId and entityId == excludeEntityId then continue end
		if not world:contains(entityId) then continue end
		
		local pos = world:get(entityId, Components.PositionComponent)
		if not pos then continue end
		
		local distance = MathUtils.Distance2D(pos.X, pos.Z, impactPosition.X, impactPosition.Z)
		
		if distance <= splashRadius then
			local distanceMultiplier = 1 - (distance / splashRadius) * CONFIG.DISTANCE_FALLOFF
			local finalDamage = math.floor(splashDamage * distanceMultiplier)
			
			if finalDamage > 0 then
				local actualDamage = ECSUtils.DamageEntity(world, entityId, finalDamage, Components)
				if actualDamage > 0 then
					world:spawn(Components.DamageEvent({
						Target = entityId,
						Amount = finalDamage,
						DamageType = "Splash",
						Source = sourceEntityId or 0,
					}))
				end
			end
		end
	end
end

-- 6. MAIN LOOP
local function OnStep(world)
	-- Process ProjectileHitEvents: apply splash damage from plants with SplashDamageComponent
	for _, hitEvent in world:query(Components.ProjectileHitEvent) do
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local splashDamage = world:get(sourcePlant, Components.SplashDamageComponent)
		if splashDamage then
			-- Fire VFX event for splash damage ring
			Network.SplashDamageVFX.FireAll({
				PositionX = hitEvent.PositionX,
				PositionY = hitEvent.PositionY,
				PositionZ = hitEvent.PositionZ,
				Radius = splashDamage.Radius,
			})
			
			applySplashDamage(
				world,
				{X = hitEvent.PositionX, Y = hitEvent.PositionY, Z = hitEvent.PositionZ},
				hitEvent.Damage,
				splashDamage.Radius,
				splashDamage.Percent,
				sourcePlant,
				hitEvent.TargetZombie,
				hitEvent.Lane
			)
		end
	end
end

-- 7. EXPORT
return {
	priority = 345,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
