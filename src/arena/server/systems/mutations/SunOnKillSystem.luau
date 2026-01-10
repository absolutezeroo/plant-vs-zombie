--!strict
--[[
	SunOnKillSystem.luau - Spawns sun when plants kill zombies
	
	Priority: 375 (After kill detection)
	
	Queries ProjectileHitEvent (WasKill=true) + SunOnKillComponent to spawn sun.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local EntityPool = require(Shared.utils.EntityPool)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	SUN_LIFETIME = 15, -- Seconds to collect kill bonus sun
	SPAWN_HEIGHT_OFFSET = 3, -- Studs above ground
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

-- 6. MAIN LOOP
local function OnStep(world)
	-- Process ProjectileHitEvents: spawn sun on kills from plants with SunOnKillComponent
	for _, hitEvent in world:query(Components.ProjectileHitEvent) do
		-- Only process kills
		if not hitEvent.WasKill then continue end
		
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local sunOnKill = world:get(sourcePlant, Components.SunOnKillComponent)
		if not sunOnKill then continue end
		
		local owner = world:get(sourcePlant, Components.OwnerComponent)
		if not owner then continue end
		
		-- Spawn sun at zombie death location
		local sunAmount = sunOnKill.SunAmount
		
		EntityPool.Spawn(
			Components.PositionComponent({
				X = hitEvent.PositionX,
				Y = hitEvent.PositionY + CONFIG.SPAWN_HEIGHT_OFFSET,
				Z = hitEvent.PositionZ,
			}),
			Components.SunComponent({
				Value = sunAmount,
				SpawnTime = os.clock(),
				Lifetime = CONFIG.SUN_LIFETIME,
				IsFalling = false,
				SourceType = "KillBonus",
			})
		)
	end
end

-- 7. EXPORT
return {
	priority = 375,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
