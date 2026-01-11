--!strict
--[[
	unlockall Command (Server)
	
	Unlocks all plants for the player.
	Usage: unlockall
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PlantData = require(Shared.data.PlantData)

local Server = script.Parent.Parent.Parent
local PlayerDataService = require(Server.services.PlayerDataService)

return function(context, target: Player?)
	local player = target or context.Executor
	
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return `Profile not loaded for {player.Name}`
	end
	
	local count = 0
	for _, plantType in PlantData.GetAllTypes() do
		if not profile.Data.UnlockedPlants[plantType] then
			profile.Data.UnlockedPlants[plantType] = true
			count += 1
		end
	end
	
	-- Sync to client
	PlayerDataService.SyncToClient(player)
	
	Logger.Info("Cmdr", `Unlocked all plants for {player.Name} (+{count} new)`)
	return `Unlocked all plants for {player.Name} (+{count} new)`
end
