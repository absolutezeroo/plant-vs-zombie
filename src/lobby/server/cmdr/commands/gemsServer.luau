--!strict
--[[
	gems Command (Server)
	
	Gives gems to the player's account.
	Usage: gems 100
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Server = script.Parent.Parent.Parent
local PlayerDataService = require(Server.services.PlayerDataService)

return function(context, amount: number, target: Player?)
	local player = target or context.Executor
	
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return `Profile not loaded for {player.Name}`
	end
	
	profile.Data.Gems = (profile.Data.Gems or 0) + amount
	
	-- Sync to client
	PlayerDataService.SyncToClient(player)
	
	Logger.Info("Cmdr", `Gave {amount} gems to {player.Name}`)
	return `+{amount} gems to {player.Name} (total: {profile.Data.Gems})`
end
