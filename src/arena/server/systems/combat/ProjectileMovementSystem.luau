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
local EntityPool = require(Shared.utils.EntityPool)

local Network = require(Shared.network.generated.server)

--------------------------------------------------------------------------------
-- [2] CONFIG (frozen constants)
--------------------------------------------------------------------------------
local CONFIG = table.freeze({
	-- Movement limits
	MIN_DT = 1 / 120,
	MAX_DT = 1 / 15,
	-- Default max range
	MAX_RANGE = 100,
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
-- (none needed for movement)

--------------------------------------------------------------------------------
-- [5] ONSTEP (main loop - CANNOT yield)
--------------------------------------------------------------------------------
local function OnStep(world)
	-- CRITICAL: Use Matter's deltaTime for frame-rate independence
	local dt = Matter.useDeltaTime()
	dt = math.clamp(dt, CONFIG.MIN_DT, CONFIG.MAX_DT)

	-- Move projectiles
	for projId, pos, proj in world:query(Components.PositionComponent, Components.ProjectileComponent) do
		-- Handle multi-directional projectiles (Starfruit)
		local dx = proj.DirectionX or 1
		local dz = proj.DirectionZ or 0

		local newX = pos.X + (proj.Speed * dx) * dt
		local newZ = pos.Z + (proj.Speed * dz) * dt

		-- Check max range (use SpawnZ for multi-directional projectiles)
		local spawnZ = proj.SpawnZ or pos.Z
		local distanceTraveled = math.sqrt((newX - proj.SpawnX) ^ 2 + (newZ - spawnZ) ^ 2)
		local maxRange = proj.MaxRange or CONFIG.MAX_RANGE

		if distanceTraveled > maxRange then
			-- Notify client to remove visual (no impact VFX)
			Network.ProjectileDespawned.FireAll({ EntityId = projId })
			if EntityPool.IsPooledEntity(projId) then
				EntityPool.Despawn(projId)
			else
				world:despawn(projId)
			end
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
