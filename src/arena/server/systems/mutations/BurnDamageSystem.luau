--!strict
--[[
	BurnDamageSystem.luau - Processes burn damage over time
	
	Priority: 350 (Combat processing - after CombatSystem)
	
	Two responsibilities:
	1. Query ProjectileHitEvent + BurnEffectComponent to apply burns
	2. Process zombies with BurningComponent (DoT ticks)
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - processes burning entities
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
local BurningComponent = Components.BurningComponent
local BurnEffectComponent = Components.BurnEffectComponent
local HealthComponent = Components.HealthComponent
local DamageEvent = Components.DamageEvent
local ZombieTypeComponent = Components.ZombieTypeComponent
local ProjectileHitEvent = Components.ProjectileHitEvent

-- Helper: Apply burn to a zombie
local function applyBurn(world, zombieEntityId: number, damagePerSecond: number, duration: number)
	if not world:contains(zombieEntityId) then return end
	
	local existingBurn = world:get(zombieEntityId, BurningComponent)
	
	if existingBurn then
		-- Refresh duration if new burn is stronger or longer
		if damagePerSecond >= existingBurn.DamagePerSecond then
			world:insert(zombieEntityId, BurningComponent({
				DamagePerSecond = damagePerSecond,
				RemainingDuration = math.max(existingBurn.RemainingDuration, duration),
				LastTickTime = os.clock(),
			}))
		end
	else
		-- Apply new burn
		world:insert(zombieEntityId, BurningComponent({
			DamagePerSecond = damagePerSecond,
			RemainingDuration = duration,
			LastTickTime = os.clock(),
		}))
		Logger.Debug("BurnDamageSystem", `Applied burn to zombie {zombieEntityId}: {damagePerSecond} dps for {duration}s`)
	end
end

-- System function
local function BurnDamageSystem(world)
	local currentTime = os.clock()
	
	-- 1. Process ProjectileHitEvents: apply burns from plants with BurnEffectComponent
	for _, hitEvent in world:query(ProjectileHitEvent) do
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local burnEffect = world:get(sourcePlant, BurnEffectComponent)
		if burnEffect then
			applyBurn(world, hitEvent.TargetZombie, burnEffect.DamagePerSecond, burnEffect.Duration)
		end
	end
	
	-- 2. Process all burning zombies (DoT ticks)
	for entityId, burning, health, zombie in world:query(BurningComponent, HealthComponent, ZombieTypeComponent) do
		-- Check if burn expired
		local elapsed = currentTime - burning.LastTickTime
		local newRemaining = burning.RemainingDuration - elapsed
		
		if newRemaining <= 0 then
			-- Burn expired, remove component
			world:remove(entityId, BurningComponent)
			Logger.Debug("BurnDamageSystem", `Burn expired on entity {entityId}`)
		else
			-- Tick damage every second
			if elapsed >= 1 then
				local damage = burning.DamagePerSecond
				
				-- Apply damage
				world:insert(entityId, HealthComponent({
					Current = math.max(0, health.Current - damage),
					Max = health.Max,
				}))
				
				-- Emit damage event for visual feedback
				world:spawn(DamageEvent({
					Target = entityId,
					Amount = damage,
					DamageType = "Burn",
					Source = 0,
				}))
				
				-- Update burn timer
				world:insert(entityId, BurningComponent({
					DamagePerSecond = burning.DamagePerSecond,
					RemainingDuration = newRemaining,
					LastTickTime = currentTime,
				}))
				
				Logger.Debug("BurnDamageSystem", `Burn tick: {damage} damage to entity {entityId}`)
			end
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
	_name = "BurnDamageSystem",
	priority = 350,
	system = BurnDamageSystem,
	Init = Init,
	Dispose = Dispose,
}
