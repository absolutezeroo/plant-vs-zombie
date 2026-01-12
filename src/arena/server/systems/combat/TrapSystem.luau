--!strict
--[[
	TrapSystem.luau - Server-side trap and diversion behaviors
	
	Priority: 165 (Simulation phase - after movement, before combat)
	
	Handles:
	- Spikeweed/Spikerock damaging zombies walking over (IsTrap, DamagesOnWalk)
	- Garlic diverting zombies to adjacent lanes (DivertsZombies)
	- Vehicle tire popping (PopsTires) - for Zomboni etc.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local GameConstants = require(Shared.config.GameConstants)
local PlantData = require(Shared.data.PlantData)
local ZombieData = require(Shared.data.ZombieData)
local LaneCache = require(Shared.utils.LaneCache)
local ChanceUtils = require(Shared.utils.ChanceUtils)
local ECSUtils = require(Shared.utils.ECSUtils)

-- Network
local Network = require(Shared.network.generated.server)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	SPIKEWEED_HIT_RADIUS = GameConstants.Trap.SPIKEWEED_HIT_RADIUS,
	SPIKEWEED_DAMAGE_INTERVAL = GameConstants.Trap.SPIKEWEED_DAMAGE_INTERVAL,
	GARLIC_BITE_THRESHOLD = GameConstants.Trap.GARLIC_BITE_THRESHOLD,
})

-- 3. STATE
local State = {
	IsInitialized = false,
	TrapDamageTimes = {} :: { [string]: number }, -- "trapId_zombieId" -> lastDamageTime
	GarlicBites = {} :: { [string]: number }, -- "garlicId_zombieId" -> biteCount
}

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end
	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	State.IsInitialized = false
	table.clear(State.TrapDamageTimes)
	table.clear(State.GarlicBites)
end

-- 6. MAIN LOOP
local function OnStep(world)
	local currentTime = os.clock()

	-- Process traps (Spikeweed)
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
			local lastDamage = State.TrapDamageTimes[key] or 0
			if currentTime - lastDamage < CONFIG.SPIKEWEED_DAMAGE_INTERVAL then
				continue
			end

			-- Apply damage using ECSUtils
			local actualDamage, isDead = ECSUtils.DamageEntity(world, zombieId, damage, Components)
			if actualDamage > 0 then
				State.TrapDamageTimes[key] = currentTime

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
	for key in State.TrapDamageTimes do
		local parts = string.split(key, "_")
		local trapId = tonumber(parts[1])
		local zombieId = tonumber(parts[2])

		-- Remove if invalid IDs or entities no longer exist
		local shouldRemove = not trapId or not zombieId
			or not world:contains(trapId) or not world:contains(zombieId)
		if shouldRemove then
			State.TrapDamageTimes[key] = nil
		end
	end

	for key in State.GarlicBites do
		local parts = string.split(key, "_")
		local garlicId = tonumber(parts[1])
		local zombieId = tonumber(parts[2])

		-- Remove if invalid IDs or entities no longer exist
		local shouldRemove = not garlicId or not zombieId
			or not world:contains(garlicId) or not world:contains(zombieId)
		if shouldRemove then
			State.GarlicBites[key] = nil
		end
	end
end

-- TODO: Garlic diversion - implement via ChewingComponent query when zombie bites Garlic
-- Should detect when zombie with ChewingComponent.TargetId == garlicId finishes eating
-- Then divert zombie to adjacent lane after GARLIC_BITE_THRESHOLD bites

-- 7. EXPORT
return {
	priority = 165,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
