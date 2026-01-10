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
local ECSUtils = require(Shared.utils.ECSUtils)

return function(_context)
	local world = EntityPool.GetWorld()
	
	if not world then
		return "World not initialized"
	end
	
	-- Count and kill all zombies using ECSUtils
	local killCount = 0
	local ZombieTypeComponent = Components.ZombieTypeComponent
	
	for id, _zombieType in world:query(ZombieTypeComponent) do
		if ECSUtils.KillEntity(world, id, Components) then
			killCount += 1
		end
	end
	
	Logger.Info("Cmdr", `Killed {killCount} zombies`)
	return `Killed {killCount} zombies`
end
