--!strict
--[[
	reset Command (Server)
	
	Resets all player data to defaults.
	Usage: reset
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Server = script.Parent.Parent.Parent
local PlayerDataService = require(Server.services.PlayerDataService)

return function(context, target: Player?)
	local player = target or context.Executor
	
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return `Profile not loaded for {player.Name}`
	end
	
	-- Reset to defaults
	profile.Data.Coins = 500
	profile.Data.Gems = 50
	profile.Data.Level = 1
	profile.Data.XP = 0
	profile.Data.TotalXPForNextLevel = 100
	profile.Data.GamesPlayed = 0
	profile.Data.GamesWon = 0
	profile.Data.ZombiesKilled = 0
	profile.Data.PlantsPlaced = 0
	profile.Data.UnlockedPlants = {
		Sunflower = true,
		Peashooter = true,
		WallNut = true,
	}
	profile.Data.Deck = {"Sunflower", "Peashooter", "WallNut"}
	profile.Data.PlantOwnedMutations = {}
	profile.Data.PlantEquippedMutations = {}
	
	-- Sync to client
	PlayerDataService.SyncToClient(player)
	
	Logger.Info("Cmdr", `Reset all data for {player.Name}`)
	return `Data reset to defaults for {player.Name}`
end
