--!strict
--[[
	SplashDamageSystem.luau - Handles splash/area damage from mutations
	
	Priority: 345 (Before individual damage processing)
	
	Queries ProjectileHitEvent + SplashDamageComponent to apply AoE damage.
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop - processes hit events for splash damage
	- Dispose(): No cleanup needed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)
local LaneCache = require(Shared.utils.LaneCache)
local GridConfig = require(Shared.config.GridConfig)
local ECSUtils = require(Shared.utils.ECSUtils)
local MathUtils = require(Shared.utils.MathUtils)

-- Components
local SplashDamageComponent = Components.SplashDamageComponent
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local DamageEvent = Components.DamageEvent
local ProjectileHitEvent = Components.ProjectileHitEvent

-- Apply splash damage at a position
-- Uses LaneCache for O(lane_range) lookup instead of O(N) world:query
local function applySplashDamage(
	world, 
	impactPosition: {X: number, Y: number, Z: number},
	baseDamage: number,
	splashRadius: number,
	splashDamagePercent: number,
	sourceEntityId: number?,
	excludeEntityId: number?,
	impactLane: number? -- Lane where the projectile hit
)
	local splashDamage = math.floor(baseDamage * splashDamagePercent)
	if splashDamage <= 0 then return end
	
	local hitCount = 0
	
	-- Calculate how many lanes the splash radius covers
	local laneRadius = math.ceil(splashRadius / GridConfig.CELL_SIZE)
	local centerLane = impactLane or 3 -- Default to middle lane if unknown
	
	-- O(lane_range) lookup instead of O(N) world:query
	local zombiesInRange = LaneCache.GetEntitiesInLaneRange(centerLane, laneRadius)
	
	for _, entityId in zombiesInRange do
		-- Skip the primary target if specified
		if excludeEntityId and entityId == excludeEntityId then
			continue
		end
		
		if not world:contains(entityId) then continue end
		
		local pos = world:get(entityId, PositionComponent)
		if not pos then continue end
		
		-- Calculate distance using MathUtils
		local distance = MathUtils.Distance2D(pos.X, pos.Z, impactPosition.X, impactPosition.Z)
		
		if distance <= splashRadius then
			-- Apply splash damage (can optionally scale by distance)
			local distanceMultiplier = 1 - (distance / splashRadius) * 0.3 -- 30% falloff at max range
			local finalDamage = math.floor(splashDamage * distanceMultiplier)
			
			if finalDamage > 0 then
				local actualDamage, died = ECSUtils.DamageEntity(world, entityId, finalDamage, Components)
				if actualDamage > 0 then
					world:spawn(DamageEvent({
						Target = entityId,
						Amount = finalDamage,
						DamageType = "Splash",
						Source = sourceEntityId or 0,
					}))
					
					hitCount += 1
				end
			end
		end
	end
	
	if hitCount > 0 then
		Logger.Debug("SplashDamageSystem", `Splash hit {hitCount} zombies for {splashDamage} damage`)
	end
end

-- System function
local function SplashDamageSystem(world)
	-- Process ProjectileHitEvents: apply splash damage from plants with SplashDamageComponent
	for _, hitEvent in world:query(ProjectileHitEvent) do
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local splashDamage = world:get(sourcePlant, SplashDamageComponent)
		if splashDamage then
			applySplashDamage(
				world,
				{X = hitEvent.PositionX, Y = hitEvent.PositionY, Z = hitEvent.PositionZ},
				hitEvent.Damage,
				splashDamage.Radius,
				splashDamage.Percent,
				sourcePlant,
				hitEvent.TargetZombie, -- Exclude primary target
				hitEvent.Lane -- Pass lane for optimized lookup
			)
		end
	end
end

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	-- No state to clean up
end

return {
	_name = "SplashDamageSystem",
	priority = 345,
	system = SplashDamageSystem,
	Init = Init,
	Dispose = Dispose,
}
