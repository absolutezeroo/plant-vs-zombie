--!strict
--[[
	killall Command (Server)
	
	Kills all zombies on the field by setting their health to 0.
	Usage: killall
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local EntityPool = require(Shared.utils.EntityPool)
local Logger = require(Shared.utils.Logger)

return function(_context)
	local world = EntityPool.GetWorld()
	
	if not world then
		return "World not initialized"
	end
	
	-- Count and kill all zombies by setting health to 0
	local killCount = 0
	local ZombieTypeComponent = Components.ZombieTypeComponent
	local HealthComponent = Components.HealthComponent
	
	for id, _zombieType in world:query(ZombieTypeComponent) do
		-- Get current health and set to 0
		local health = world:get(id, HealthComponent)
		if health then
			world:insert(id, HealthComponent({
				Current = 0,
				Max = health.Max,
			}))
			killCount += 1
		end
	end
	
	Logger.Info("Cmdr", `Killed {killCount} zombies`)
	return `Killed {killCount} zombies`
end
