--!strict
--[[
	max Command (Server)
	
	Maxes out all resources.
	Usage: max
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
	
	profile.Data.Coins = 999999
	profile.Data.Gems = 9999
	profile.Data.Level = 50
	profile.Data.XP = 0
	profile.Data.TotalXPForNextLevel = 100 + (50 * 50)
	
	-- Sync to client
	PlayerDataService.SyncToClient(player)
	
	Logger.Info("Cmdr", `Maxed resources for {player.Name}`)
	return `Max resources for {player.Name}: 999999 coins, 9999 gems, level 50`
end
