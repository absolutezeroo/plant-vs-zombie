--!strict
--[[
	unlock Command (Server)
	
	Unlocks a specific plant for the player.
	Usage: unlock Repeater
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)
local PlantData = require(Shared.data.PlantData)

local Server = script.Parent.Parent.Parent
local PlayerDataService = require(Server.services.PlayerDataService)

return function(context, plantType: string, target: Player?)
	local player = target or context.Executor

	-- Capitalize first letter
	plantType = string.upper(string.sub(plantType, 1, 1)) .. string.sub(plantType, 2)

	-- Validate plant exists
	local stats = PlantData.GetStats(plantType)
	if not stats then
		return `Unknown plant: {plantType}`
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return `Profile not loaded for {player.Name}`
	end

	if profile.Data.UnlockedPlants[plantType] then
		return `{plantType} already unlocked for {player.Name}`
	end

	profile.Data.UnlockedPlants[plantType] = true

	-- Sync to client
	PlayerDataService.SyncToClient(player)

	Logger.Info("Cmdr", `Unlocked {plantType} for {player.Name}`)
	return `Unlocked {plantType} for {player.Name}`
end
