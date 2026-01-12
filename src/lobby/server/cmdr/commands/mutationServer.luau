--!strict
--[[
	mutation Command (Server)
	
	Adds a mutation to a plant.
	Usage: mutation Peashooter:Fire
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)

local Server = script.Parent.Parent.Parent
local PlayerDataService = require(Server.services.PlayerDataService)

return function(context, plantMutation: string, target: Player?)
	local player = target or context.Executor

	-- Parse "PlantType:MutationType"
	local parts = string.split(plantMutation, ":")
	if #parts ~= 2 then
		return "Format: PlantType:MutationType (e.g., Peashooter:Fire)"
	end

	-- Capitalize both parts
	local plantType = string.upper(string.sub(parts[1], 1, 1)) .. string.sub(parts[1], 2)
	local mutationType = string.upper(string.sub(parts[2], 1, 1)) .. string.sub(parts[2], 2)

	-- Validate plant
	local plantStats = PlantData.GetStats(plantType)
	if not plantStats then
		return `Unknown plant: {plantType}`
	end

	-- Validate mutation
	if not MutationData.Get(mutationType) then
		return `Unknown mutation: {mutationType}`
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return "Profile not loaded"
	end

	-- Initialize mutation tables if needed
	if not profile.Data.PlantOwnedMutations then
		profile.Data.PlantOwnedMutations = {}
	end
	if not profile.Data.PlantEquippedMutations then
		profile.Data.PlantEquippedMutations = {}
	end
	if not profile.Data.PlantOwnedMutations[plantType] then
		profile.Data.PlantOwnedMutations[plantType] = {}
	end
	if not profile.Data.PlantEquippedMutations[plantType] then
		profile.Data.PlantEquippedMutations[plantType] = {}
	end

	-- Check if already owns
	if table.find(profile.Data.PlantOwnedMutations[plantType], mutationType) then
		return `{plantType} already owns {mutationType} for {player.Name}`
	end

	-- Add to both owned AND equipped
	table.insert(profile.Data.PlantOwnedMutations[plantType], mutationType)
	table.insert(profile.Data.PlantEquippedMutations[plantType], mutationType)

	-- Sync to client
	PlayerDataService.SyncToClient(player)

	Logger.Info("Cmdr", `Added {mutationType} to {plantType} for {player.Name}`)
	return `Added {mutationType} to {plantType} for {player.Name}`
end
