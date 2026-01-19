--!strict
--[[
	ProjectileMovementSystem.luau - Server-side projectile movement
	
	Priority: 161 (After spawn, before enhancement/combat detection)
	
	Handles:
	- Projectile position updates
	- Multi-directional projectile movement (Starfruit)
	- Max range checks and despawning
]]

--------------------------------------------------------------------------------
-- [1] IMPORTS
--------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GameConstants = require(Shared.config.GameConstants)
local EntityPool = require(Shared.utils.ecs.EntityPool)
local LaneCache = require(Shared.utils.ecs.LaneCache)

local Network = require(Shared.network.generated.server)

--------------------------------------------------------------------------------
-- [2] CONFIG (frozen constants - referencing GameConstants)
--------------------------------------------------------------------------------
local CONFIG = table.freeze({
	-- Movement limits
	MIN_DT = 1 / 120,
	MAX_DT = 1 / 15,
	-- Default max range (from GameConstants.Projectile)
	MAX_RANGE = GameConstants.Projectile.MAX_RANGE,
})

--------------------------------------------------------------------------------
-- [3] STATE (mutable runtime state)
--------------------------------------------------------------------------------
local State = {
	IsInitialized = false,
}

--------------------------------------------------------------------------------
-- [4] PRIVATE HELPERS
--------------------------------------------------------------------------------

-- Find a new target for homing projectile when current target dies
local function findNewTarget(pos: { X: number, Y: number, Z: number }): number?
	local allZombies = LaneCache.GetAllZombies()
	if #allZombies == 0 then
		return nil
	end

	local closest: number? = nil
	local closestDist = math.huge

	for _, zombieId in allZombies do
		-- Skip hypnotized zombies (allies)
		if LaneCache.IsHypnotized(zombieId) then
			continue
		end
		
		local zombiePos = LaneCache.GetPosition(zombieId)
		if not zombiePos then
			continue
		end

		local dx = zombiePos.X - pos.X
		local dz = zombiePos.Z - pos.Z
		local dist = dx * dx + dz * dz

		if dist < closestDist then
			closestDist = dist
			closest = zombieId
		end
	end

	return closest
end

-- Calculate turn toward target (returns new direction)
local function turnToward(
	currentDx: number,
	currentDz: number,
	targetDx: number,
	targetDz: number,
	turnSpeed: number,
	dt: number
): (number, number)
	-- Normalize target direction
	local targetMag = math.sqrt(targetDx * targetDx + targetDz * targetDz)
	if targetMag < 0.001 then
		return currentDx, currentDz
	end
	local normTargetDx = targetDx / targetMag
	local normTargetDz = targetDz / targetMag

	-- Calculate angle between current and target direction
	local dot = currentDx * normTargetDx + currentDz * normTargetDz
	dot = math.clamp(dot, -1, 1)
	local angleDiff = math.acos(dot)

	-- If already pointing at target, just use target direction
	if angleDiff < 0.01 then
		return normTargetDx, normTargetDz
	end

	-- Calculate max turn this frame
	local maxTurn = turnSpeed * dt
	local turnFraction = math.min(maxTurn / angleDiff, 1)

	-- Lerp direction
	local newDx = currentDx + (normTargetDx - currentDx) * turnFraction
	local newDz = currentDz + (normTargetDz - currentDz) * turnFraction

	-- Normalize result
	local newMag = math.sqrt(newDx * newDx + newDz * newDz)
	if newMag > 0.001 then
		newDx = newDx / newMag
		newDz = newDz / newMag
	end

	return newDx, newDz
end

--------------------------------------------------------------------------------
-- [5] ONSTEP (main loop - CANNOT yield)
--------------------------------------------------------------------------------
local function OnStep(world)
	-- CRITICAL: Use Matter's deltaTime for frame-rate independence
	local dt = Matter.useDeltaTime()
	dt = math.clamp(dt, CONFIG.MIN_DT, CONFIG.MAX_DT)
	local currentTime = os.clock()

	-- Move projectiles
	for projId, pos, proj in world:query(Components.PositionComponent, Components.ProjectileComponent) do
		local dx = proj.DirectionX or 1
		local dz = proj.DirectionZ or 0

		-- Check for homing component
		local homing = world:get(projId, Components.HomingComponent)
		if homing then
			-- Check lifetime
			if currentTime - homing.SpawnTime > homing.MaxLifetime then
				Network.ProjectileDespawned.FireAll({ EntityId = projId })
				EntityPool.SafeDespawn(projId, world)
				continue
			end

			-- Get target position
			local targetId = homing.TargetEntity
			local targetPos = LaneCache.GetPosition(targetId)

			-- If target died, find new target
			if not targetPos then
				local newTarget = findNewTarget({ X = pos.X, Y = pos.Y, Z = pos.Z })
				if newTarget then
					targetId = newTarget
					targetPos = LaneCache.GetPosition(newTarget)
					-- Update homing component with new target
					world:insert(
						projId,
						Components.HomingComponent({
							TargetEntity = newTarget,
							TurnSpeed = homing.TurnSpeed,
							MaxLifetime = homing.MaxLifetime,
							SpawnTime = homing.SpawnTime,
						})
					)
				end
			end

			-- Turn toward target
			if targetPos then
				local toDx = targetPos.X - pos.X
				local toDz = targetPos.Z - pos.Z
				dx, dz = turnToward(dx, dz, toDx, toDz, homing.TurnSpeed, dt)

				-- Update projectile direction
				world:insert(
					projId,
					Components.ProjectileComponent({
						Damage = proj.Damage,
						Speed = proj.Speed,
						DirectionX = dx,
						DirectionZ = dz,
						SourceEntity = proj.SourceEntity,
						Lane = LaneCache.GetLane(targetId) or proj.Lane,
						SpawnX = proj.SpawnX,
						SpawnZ = proj.SpawnZ,
						MaxRange = proj.MaxRange,
						CanHitFlying = proj.CanHitFlying,
						IsFrozen = proj.IsFrozen,
						SlowPercent = proj.SlowPercent,
						SlowDuration = proj.SlowDuration,
					})
				)
			end
		end

		local newX = pos.X + (proj.Speed * dx) * dt
		local newZ = pos.Z + (proj.Speed * dz) * dt

		-- Check max range (use SpawnZ for multi-directional projectiles)
		local spawnZ = proj.SpawnZ or pos.Z
		local distanceTraveled = math.sqrt((newX - proj.SpawnX) ^ 2 + (newZ - spawnZ) ^ 2)
		local maxRange = proj.MaxRange or CONFIG.MAX_RANGE

		if distanceTraveled > maxRange then
			-- Notify client to remove visual (no impact VFX)
			Network.ProjectileDespawned.FireAll({ EntityId = projId })
			EntityPool.SafeDespawn(projId, world)
			continue
		end

		-- Update position using component constructor
		world:insert(
			projId,
			Components.PositionComponent({
				X = newX,
				Y = pos.Y,
				Z = newZ,
			})
		)
	end
end

--------------------------------------------------------------------------------
-- [6] INIT / DISPOSE
--------------------------------------------------------------------------------
local function Init(_world)
	if State.IsInitialized then
		return
	end

	State.IsInitialized = true
end

local function Dispose()
	State.IsInitialized = false
end

--------------------------------------------------------------------------------
-- [7] EXPORT
--------------------------------------------------------------------------------
return {
	priority = 161,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
