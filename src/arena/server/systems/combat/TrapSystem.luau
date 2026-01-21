--!strict
--[[
	TrapSystem.luau - Server-side trap and diversion behaviors
	
	Priority: 165 (Simulation phase - after movement, before combat)
	
	Handles:
	- Spikeweed/Spikerock damaging zombies walking over (IsTrap, DamagesOnWalk)
	- Garlic diverting zombies to adjacent lanes (DivertsZombies)
	- Vehicle tire popping (PopsTires) - for Zomboni etc.

	V3 Architecture: Matter Hooks pattern
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages.MatterHooks)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local GameConstants = require(Shared.config.GameConstants)
local PlantData = require(Shared.data.PlantData)
local ZombieData = require(Shared.data.ZombieData)
local LaneCache = require(Shared.utils.ecs.LaneCache)
local ChanceUtils = require(Shared.utils.core.ChanceUtils)
local ECSUtils = require(Shared.utils.ecs.ECSUtils)

-- Network
local Network = require(Shared.network.generated.server)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	SPIKEWEED_HIT_RADIUS = GameConstants.Trap.SPIKEWEED_HIT_RADIUS,
	SPIKEWEED_DAMAGE_INTERVAL = GameConstants.Trap.SPIKEWEED_DAMAGE_INTERVAL,
	GARLIC_BITE_THRESHOLD = GameConstants.Trap.GARLIC_BITE_THRESHOLD,
})

-- 3. HELPER TYPES
type TrapState = {
	TrapDamageTimes: { [string]: number },
	GarlicBites: { [string]: number },
}

-- 4. SYSTEM FUNCTION
local function TrapSystem(world)
	local currentTime = os.clock()

	-- State managed via Hooks.useMap
	local state = Hooks.useMap("TrapState", {
		TrapDamageTimes = {} :: { [string]: number },
		GarlicBites = {} :: { [string]: number },
	})

	-- ==============================================
	-- Helper: Divert zombie to adjacent lane
	-- ==============================================
	local function divertZombie(zombieId: number, zombie: any, zombiePos: any)
		local currentLane = zombie.Lane

		-- Choose direction: prefer away from center (more dramatic), fallback to random
		local newLane: number
		if currentLane <= 2 then
			newLane = currentLane + 1 -- Move down
		elseif currentLane >= 4 then
			newLane = currentLane - 1 -- Move up
		else
			-- Center lane: random direction
			newLane = if ChanceUtils.Roll(0.5) then currentLane + 1 else currentLane - 1
		end

		-- Clamp to valid lanes (1-5)
		newLane = math.clamp(newLane, 1, GridConfig.GRID_LANES)

		-- Calculate new Z position for the new lane
		local laneOffset = (newLane - currentLane) * GridConfig.CELL_SIZE
		local newZ = zombiePos.Z + laneOffset

		-- Update zombie lane and position
		world:insert(zombieId, Components.ZombieTypeComponent({
			ZombieType = zombie.ZombieType,
			Lane = newLane,
		}))

		world:insert(zombieId, Components.PositionComponent({
			X = zombiePos.X,
			Y = zombiePos.Y,
			Z = newZ,
		}))

		-- Remove target so zombie resumes moving
		if world:get(zombieId, Components.TargetComponent) then
			world:remove(zombieId, Components.TargetComponent)
		end

		-- Resume movement
		local stats = ZombieData[zombie.ZombieType]
		if stats then
			local direction = MapConfig.GetZombieDirection()
			world:insert(zombieId, Components.MovementComponent({
				VelocityX = direction.X * stats.Speed,
				VelocityY = 0,
				VelocityZ = direction.Z * stats.Speed,
			}))
		end

		-- Broadcast lane change to clients
		Network.ZombieDiverted.FireAll({
			EntityId = zombieId,
			NewLane = newLane,
			NewZ = newZ,
		})
	end

	-- ==============================================
	-- Process Garlic diversion
	-- ==============================================
	-- Check zombies that are currently eating a Garlic
	for zombieId, target in world:query(Components.TargetComponent) do
		if not world:contains(target.TargetEntity) then
			continue
		end

		local plant = world:get(target.TargetEntity, Components.PlantTypeComponent)
		if not plant then
			continue
		end

		local plantStats = PlantData[plant.PlantType]
		if not plantStats or not plantStats.DivertsZombies then
			continue
		end

		local zombie = world:get(zombieId, Components.ZombieTypeComponent)
		local zombiePos = world:get(zombieId, Components.PositionComponent)
		if not zombie or not zombiePos then
			continue
		end

		-- Key for tracking bites on this specific garlic
		local key = `{target.TargetEntity}_{zombieId}`

		-- Initialize bite count on first encounter
		if not state.value.GarlicBites[key] then
			state.value.GarlicBites[key] = 0
		end

		-- Check if zombie just bit the garlic
		local lastBiteCheck = state.value.TrapDamageTimes[`garlic_{key}`] or 0
		local zombieStats = ZombieData[zombie.ZombieType]
		local attackSpeed = if zombieStats then zombieStats.AttackSpeed else 1.0

		if currentTime - lastBiteCheck >= attackSpeed then
			state.value.GarlicBites[key] = state.value.GarlicBites[key] + 1
			state.value.TrapDamageTimes[`garlic_{key}`] = currentTime

			-- Check if threshold reached
			if state.value.GarlicBites[key] >= CONFIG.GARLIC_BITE_THRESHOLD then
				-- Divert zombie to adjacent lane!
				divertZombie(zombieId, zombie, zombiePos)

				-- Clear bite counter (zombie is gone)
				state.value.GarlicBites[key] = nil
				state.value.TrapDamageTimes[`garlic_{key}`] = nil
			end
		end
	end

	-- ==============================================
	-- Process traps (Spikeweed)
	-- ==============================================
	for trapId, trapPos, trap in world:query(Components.PositionComponent, Components.PlantTypeComponent) do
		local stats = PlantData[trap.PlantType]
		if not stats or not stats.IsTrap or not stats.DamagesOnWalk then
			continue
		end

		local damage = stats.Damage or 20

		-- O(1) lane lookup instead of O(N) world:query
		local zombiesInLane = LaneCache.GetEntitiesInLane(trap.Lane)

		-- Check for zombies walking over
		for _, zombieId in zombiesInLane do
			if not world:contains(zombieId) then
				continue
			end

			local zombiePos = world:get(zombieId, Components.PositionComponent)
			if not zombiePos then
				continue
			end

			local zombie = world:get(zombieId, Components.ZombieTypeComponent)
			if not zombie then
				continue
			end

			local distance = math.abs(zombiePos.X - trapPos.X)
			if distance > CONFIG.SPIKEWEED_HIT_RADIUS then
				continue
			end

			-- Check damage cooldown
			local key = `{trapId}_{zombieId}`
			local lastDamage = state.value.TrapDamageTimes[key] or 0
			if currentTime - lastDamage < CONFIG.SPIKEWEED_DAMAGE_INTERVAL then
				continue
			end

			-- Apply damage using ECSUtils
			local actualDamage, isDead = ECSUtils.DamageEntity(world, zombieId, damage, Components)
			if actualDamage > 0 then
				state.value.TrapDamageTimes[key] = currentTime

				-- Broadcast damage
				local health = world:get(zombieId, Components.HealthComponent)
				Network.EntityDamaged.FireAll({
					EntityId = zombieId,
					NewHealth = health and health.Current or 0,
					DamageAmount = actualDamage,
				})

				-- Check for vehicle (PopsTires)
				if stats.PopsTires and not isDead then
					local zombieStats = ZombieData[zombie.ZombieType]
					if zombieStats and zombieStats.IsVehicle then
						ECSUtils.KillEntity(world, zombieId, Components)
					end
				end
			end
		end
	end

	-- Cleanup old entries
	for key in state.value.TrapDamageTimes do
		local parts = string.split(key, "_")
		local trapId = tonumber(parts[1])
		local zombieId = tonumber(parts[2])

		-- Remove if invalid IDs or entities no longer exist
		local shouldRemove = not trapId or not zombieId
			or not world:contains(trapId) or not world:contains(zombieId)
		if shouldRemove then
			state.value.TrapDamageTimes[key] = nil
		end
	end

	for key in state.value.GarlicBites do
		local parts = string.split(key, "_")
		local garlicId = tonumber(parts[1])
		local zombieId = tonumber(parts[2])

		-- Remove if invalid IDs or entities no longer exist
		local shouldRemove = not garlicId or not zombieId
			or not world:contains(garlicId) or not world:contains(zombieId)
		if shouldRemove then
			state.value.GarlicBites[key] = nil
		end
	end
end

-- 5. EXPORT
return {
	priority = 165,
	system = TrapSystem,
}
