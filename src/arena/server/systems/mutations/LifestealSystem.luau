--!strict
--[[
	LifestealSystem.luau - Heals plants when they deal damage
	
	Priority: 370 (After damage processing)
	
	Plants with LifestealComponent heal for a percentage of damage dealt.
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): No per-frame logic, API-driven
	- Dispose(): No cleanup needed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)

-- Components
local LifestealComponent = Components.LifestealComponent
local HealthComponent = Components.HealthComponent
local PlantTypeComponent = Components.PlantTypeComponent

-- Module API
local API = {}

-- Called when a plant deals damage
function API.OnPlantDealsDamage(world, plantEntityId: number, damageDealt: number)
	if not world:contains(plantEntityId) then return end
	
	local lifesteal = world:get(plantEntityId, LifestealComponent)
	if not lifesteal then return end
	
	local health = world:get(plantEntityId, HealthComponent)
	if not health then return end
	
	-- Calculate heal amount
	local lifestealPercent = lifesteal.Percent :: number
	local healAmount = math.floor(damageDealt * lifestealPercent)
	if healAmount <= 0 then return end
	
	-- Apply healing (cap at max)
	local healthCurrent = health.Current :: number
	local healthMax = health.Max :: number
	local newHealth = math.min(healthMax, healthCurrent + healAmount)
	if newHealth > healthCurrent then
		world:insert(plantEntityId, HealthComponent({
			Current = newHealth,
			Max = healthMax,
		}))
		
		Logger.Debug("LifestealSystem", `Plant {plantEntityId} healed {healAmount} from lifesteal`)
	end
end

-- System function (no per-frame logic, API-driven)
local function LifestealSystem(_world)
	-- Lifesteal is triggered via API.OnPlantDealsDamage
	-- No per-frame processing needed
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
	API = API,
}
