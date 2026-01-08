--!strict
--[[
	SplashDamageSystem.luau - Handles splash/area damage from plants
	
	Priority: 345 (Before individual damage processing)
	
	Plants with SplashDamageComponent deal damage in an area on hit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)

-- Components
local SplashDamageComponent = Components.SplashDamageComponent
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local DamageEvent = Components.DamageEvent

-- Module API
local API = {}

-- Apply splash damage at a position
function API.ApplySplashDamage(
	world, 
	impactPosition: {X: number, Y: number, Z: number},
	baseDamage: number,
	splashRadius: number,
	splashDamagePercent: number,
	sourceEntityId: number?,
	excludeEntityId: number?
)
	local splashDamage = math.floor(baseDamage * splashDamagePercent)
	if splashDamage <= 0 then return end
	
	local hitCount = 0
	
	-- Find zombies in splash radius
	for entityId, pos, health, zombie in world:query(PositionComponent, HealthComponent, ZombieTypeComponent) do
		-- Skip the primary target if specified
		if excludeEntityId and entityId == excludeEntityId then
			continue
		end
		
		-- Calculate distance
		local dx = pos.X - impactPosition.X
		local dz = pos.Z - impactPosition.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		
		if distance <= splashRadius then
			-- Apply splash damage (can optionally scale by distance)
			local distanceMultiplier = 1 - (distance / splashRadius) * 0.3 -- 30% falloff at max range
			local finalDamage = math.floor(splashDamage * distanceMultiplier)
			
			if finalDamage > 0 then
				world:insert(entityId, HealthComponent({
					Current = math.max(0, health.Current - finalDamage),
					Max = health.Max,
				}))
				
				world:insert(entityId, DamageEvent({
					Amount = finalDamage,
					DamageType = "Splash",
					SourceEntityId = sourceEntityId,
				}))
				
				hitCount += 1
			end
		end
	end
	
	if hitCount > 0 then
		Logger.Debug("SplashDamageSystem", `Splash hit {hitCount} zombies for {splashDamage} damage`)
	end
end

-- System function (no per-frame logic, API-driven)
local function SplashDamageSystem(world)
	-- Splash damage is triggered via API.ApplySplashDamage when projectiles hit
	-- No per-frame processing needed
end

return {
	system = SplashDamageSystem,
	priority = 345,
	API = API,
}
