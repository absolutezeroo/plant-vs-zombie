--!strict
--[[
	LifestealSystem.luau - Heals plants when they deal damage
	
	Priority: 370 (After damage processing)
	
	Queries ProjectileHitEvent + LifestealComponent to heal plants.
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop - processes hit events for lifesteal
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
local LifestealComponent = Components.LifestealComponent
local HealthComponent = Components.HealthComponent
local ProjectileHitEvent = Components.ProjectileHitEvent

-- System function
local function LifestealSystem(world)
	-- Process ProjectileHitEvents: heal plants with LifestealComponent
	for _, hitEvent in world:query(ProjectileHitEvent) do
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local lifesteal = world:get(sourcePlant, LifestealComponent)
		if not lifesteal then continue end
		
		local health = world:get(sourcePlant, HealthComponent)
		if not health then continue end
		
		-- Calculate heal amount
		local lifestealPercent = lifesteal.Percent :: number
		local healAmount = math.floor(hitEvent.Damage * lifestealPercent)
		if healAmount <= 0 then continue end
		
		-- Apply healing (cap at max, immutable via Sift)
		local healthCurrent = health.Current :: number
		local healthMax = health.Max :: number
		local newHealth = math.min(healthMax, healthCurrent + healAmount)
		if newHealth > healthCurrent then
			world:insert(sourcePlant, Sift.Dictionary.merge(health, {
				Current = newHealth,
			}))
			
			Logger.Debug("LifestealSystem", `Plant {sourcePlant} healed {healAmount} from lifesteal`)
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
	_name = "LifestealSystem",
	priority = 370,
	system = LifestealSystem,
	Init = Init,
	Dispose = Dispose,
}
