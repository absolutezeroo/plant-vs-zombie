--!strict
--[[
	BurnDamageSystem.luau - Processes burn damage over time
	
	Priority: 350 (Combat processing - after CombatSystem)
	
	Two responsibilities:
	1. Query ProjectileHitEvent + BurnEffectComponent to apply burns
	2. Process zombies with BurningComponent (DoT ticks)
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local ECSUtils = require(Shared.utils.ECSUtils)

-- Network for VFX events
local Network = require(Shared.network.generated.server)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	TICK_INTERVAL = 1, -- Seconds between burn ticks
})

-- 3. STATE (minimal - stateless system)
local State = {
	IsInitialized = false,
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
end

-- Helper: Apply burn to a zombie
local function applyBurn(world, zombieEntityId: number, damagePerSecond: number, duration: number)
	if not world:contains(zombieEntityId) then
		return
	end

	local existingBurn = world:get(zombieEntityId, Components.BurningComponent)

	if existingBurn then
		-- Refresh duration if new burn is stronger or longer
		if damagePerSecond >= existingBurn.DamagePerSecond then
			world:insert(
				zombieEntityId,
				Components.BurningComponent({
					DamagePerSecond = damagePerSecond,
					RemainingDuration = math.max(existingBurn.RemainingDuration, duration),
					LastTickTime = os.clock(),
				})
			)
		end
	else
		-- Apply new burn
		world:insert(
			zombieEntityId,
			Components.BurningComponent({
				DamagePerSecond = damagePerSecond,
				RemainingDuration = duration,
				LastTickTime = os.clock(),
			})
		)

		-- Fire VFX event for burn application
		local pos = world:get(zombieEntityId, Components.PositionComponent)
		if pos then
			Network.StatusApplied.FireAll({
				EntityId = zombieEntityId,
				StatusType = "Burn",
				Duration = duration,
				PositionX = pos.X,
				PositionY = pos.Y,
				PositionZ = pos.Z,
			})
		end
	end
end

-- 6. MAIN LOOP
local function OnStep(world)
	local currentTime = os.clock()

	-- 1. Process ProjectileHitEvents: apply burns from plants with BurnEffectComponent
	for _, hitEvent in world:query(Components.ProjectileHitEvent) do
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then
			continue
		end

		local burnEffect = world:get(sourcePlant, Components.BurnEffectComponent)
		if burnEffect then
			applyBurn(world, hitEvent.TargetZombie, burnEffect.DamagePerSecond, burnEffect.Duration)
		end
	end

	-- 2. Process all burning zombies (DoT ticks)
	for entityId, burning in
		world:query(Components.BurningComponent, Components.HealthComponent, Components.ZombieTypeComponent)
	do
		local elapsed = currentTime - burning.LastTickTime
		local newRemaining = burning.RemainingDuration - elapsed

		if newRemaining <= 0 then
			-- Burn expired, remove component
			world:remove(entityId, Components.BurningComponent)

			-- Notify clients for VFX cleanup
			local pos = world:get(entityId, Components.PositionComponent)
			if pos then
				Network.StatusRemoved.FireAll({
					EntityId = entityId,
					StatusType = "Burn",
					PositionX = pos.X,
					PositionY = pos.Y,
					PositionZ = pos.Z,
				})
			end
		else
			-- Tick damage every second
			if elapsed >= CONFIG.TICK_INTERVAL then
				local damage = burning.DamagePerSecond

				-- Apply damage using ECSUtils
				local actualDamage = ECSUtils.DamageEntity(world, entityId, damage, Components)

				if actualDamage > 0 then
					-- Emit damage event for visual feedback
					world:spawn(Components.DamageEvent({
						Target = entityId,
						Amount = damage,
						DamageType = "Burn",
						Source = 0,
					}))

					-- Send network event for client visual feedback (floating damage numbers)
					local targetHealth = world:get(entityId, Components.HealthComponent)
					Network.EntityDamaged.FireAll({
						EntityId = entityId,
						NewHealth = targetHealth and targetHealth.Current or 0,
						DamageAmount = actualDamage,
						DamageType = "Fire",
					})
				end

				-- Update burn timer
				world:insert(
					entityId,
					Components.BurningComponent({
						DamagePerSecond = burning.DamagePerSecond,
						RemainingDuration = newRemaining,
						LastTickTime = currentTime,
					})
				)
			end
		end
	end
end

-- 7. EXPORT
return {
	priority = 350,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
