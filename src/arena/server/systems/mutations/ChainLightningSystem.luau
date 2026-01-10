--!strict
--[[
	ChainLightningSystem.luau - Handles chain lightning damage propagation
	
	Priority: 360 (Combat processing - after CombatSystem)
	
	Queries ProjectileHitEvent + ChainLightningComponent to apply chain damage.
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop - processes hit events for chain lightning
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

-- Components
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local ChainLightningComponent = Components.ChainLightningComponent
local DamageEvent = Components.DamageEvent
local ProjectileHitEvent = Components.ProjectileHitEvent

-- Find nearby zombies within range (excluding already hit ones)
-- Uses LaneCache for O(lane_range) lookup instead of O(N) world:query
local function findNearbyZombies(world, centerPos: {X: number, Y: number, Z: number}, range: number, excludeIds: {number}, centerLane: number?): {number}
	local nearby = {}
	
	-- Calculate how many lanes the range covers
	local laneRadius = math.ceil(range / GridConfig.CELL_SIZE)
	local lane = centerLane or 3 -- Default to middle lane if unknown
	
	-- O(lane_range) lookup instead of O(N) world:query
	local zombiesInRange = LaneCache.GetEntitiesInLaneRange(lane, laneRadius)
	
	for _, entityId in zombiesInRange do
		-- Check if excluded
		local isExcluded = false
		for _, excludeId in excludeIds do
			if excludeId == entityId then
				isExcluded = true
				break
			end
		end
		
		if not isExcluded then
			if not world:contains(entityId) then continue end
			
			local pos = LaneCache.GetPosition(entityId)
			if not pos then continue end
			
			-- Calculate distance
			local dx = pos.X - centerPos.X
			local dz = pos.Z - centerPos.Z
			local distance = math.sqrt(dx * dx + dz * dz)
			
			if distance <= range then
				nearby = Sift.Array.push(nearby, {
					entityId = entityId,
					distance = distance,
				})
			end
		end
	end
	
	-- Sort by distance (closest first)
	local sortedNearby = Sift.Array.sort(nearby, function(a, b)
		return a.distance < b.distance
	end)
	
	-- Return just entity IDs
	return Sift.Array.map(sortedNearby, function(data)
		return data.entityId
	end)
end

-- Apply chain lightning damage from a source
-- Uses LaneCache for efficient nearby zombie lookups
local function applyChainLightning(
	world, 
	sourceZombieId: number,
	baseDamage: number, 
	chainCount: number, 
	chainDamagePercent: number, 
	chainRange: number,
	sourceLane: number?
)
	if not world:contains(sourceZombieId) then return end
	
	local sourcePos = world:get(sourceZombieId, PositionComponent)
	if not sourcePos then return end
	
	local hitZombies = {sourceZombieId}
	local currentPos: {X: number, Y: number, Z: number} = {X = sourcePos.X, Y = sourcePos.Y, Z = sourcePos.Z}
	local currentDamage = baseDamage * chainDamagePercent
	local currentLane = sourceLane or 3 -- Track current lane for optimized lookups
	
	for i = 1, chainCount do
		-- Find next target (pass current lane for optimized lookup)
		local nearbyZombies = findNearbyZombies(world, currentPos, chainRange, hitZombies, currentLane)
		
		if #nearbyZombies == 0 then
			break -- No more targets
		end
		
		local nextTarget = nearbyZombies[1]
		hitZombies = Sift.Array.push(hitZombies, nextTarget)
		
		-- Apply damage to next target using ECSUtils
		local actualDamage, died = ECSUtils.DamageEntity(world, nextTarget, currentDamage, Components)
		if actualDamage > 0 then
			-- Emit damage event
			world:spawn(DamageEvent({
				Target = nextTarget,
				Amount = currentDamage,
				DamageType = "Lightning",
				Source = sourceZombieId,
			}))
			
			Logger.Debug("ChainLightningSystem", `Chain {i}: {currentDamage} damage to entity {nextTarget}`)
		end
		
		-- Update for next chain
		local nextPos = world:get(nextTarget, PositionComponent)
		if not nextPos then break end
		currentPos = {X = nextPos.X, Y = nextPos.Y, Z = nextPos.Z}
	end
	
	if #hitZombies > 1 then
		Logger.Debug("ChainLightningSystem", `Chain lightning hit {#hitZombies - 1} additional zombies`)
	end
end

-- System function
local function ChainLightningSystem(world)
	-- Process ProjectileHitEvents: apply chain lightning from plants with ChainLightningComponent
	for _, hitEvent in world:query(ProjectileHitEvent) do
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local chainLightning = world:get(sourcePlant, ChainLightningComponent)
		if chainLightning then
			applyChainLightning(
				world,
				hitEvent.TargetZombie,
				hitEvent.Damage,
				chainLightning.ChainCount,
				chainLightning.ChainDamage,
				chainLightning.ChainRange,
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
	_name = "ChainLightningSystem",
	priority = 360,
	system = ChainLightningSystem,
	Init = Init,
	Dispose = Dispose,
}
