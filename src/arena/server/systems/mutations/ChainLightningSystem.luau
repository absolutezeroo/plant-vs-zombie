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

-- Components
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local ChainLightningComponent = Components.ChainLightningComponent
local DamageEvent = Components.DamageEvent
local ProjectileHitEvent = Components.ProjectileHitEvent

-- Find nearby zombies within range (excluding already hit ones)
local function findNearbyZombies(world, centerPos: {X: number, Y: number, Z: number}, range: number, excludeIds: {number}): {number}
	local nearby = {}
	
	for entityId, pos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
		-- Check if excluded
		local isExcluded = false
		for _, excludeId in excludeIds do
			if excludeId == entityId then
				isExcluded = true
				break
			end
		end
		
		if not isExcluded then
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
local function applyChainLightning(
	world, 
	sourceZombieId: number,
	baseDamage: number, 
	chainCount: number, 
	chainDamagePercent: number, 
	chainRange: number
)
	if not world:contains(sourceZombieId) then return end
	
	local sourcePos = world:get(sourceZombieId, PositionComponent)
	if not sourcePos then return end
	
	local hitZombies = {sourceZombieId}
	local currentPos: {X: number, Y: number, Z: number} = {X = sourcePos.X, Y = sourcePos.Y, Z = sourcePos.Z}
	local currentDamage = baseDamage * chainDamagePercent
	
	for i = 1, chainCount do
		-- Find next target
		local nearbyZombies = findNearbyZombies(world, currentPos, chainRange, hitZombies)
		
		if #nearbyZombies == 0 then
			break -- No more targets
		end
		
		local nextTarget = nearbyZombies[1]
		hitZombies = Sift.Array.push(hitZombies, nextTarget)
		
		-- Apply damage to next target
		local targetHealth = world:get(nextTarget, HealthComponent)
		if targetHealth then
			local healthCurrent = targetHealth.Current :: number
			world:insert(nextTarget, HealthComponent({
				Current = math.max(0, healthCurrent - currentDamage),
				Max = targetHealth.Max,
			}))
			
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
				chainLightning.ChainRange
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
