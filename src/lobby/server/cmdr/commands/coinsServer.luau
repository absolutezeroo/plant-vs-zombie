--!strict
--[[
	coins Command (Server)
	
	Gives coins to the player's account.
	Usage: coins 1000
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

	profile.Data.Coins = (profile.Data.Coins or 0) + amount

	-- Sync to client
	PlayerDataService.SyncToClient(player)

	Logger.Info("Cmdr", `Gave {amount} coins to {player.Name}`)
	return `+{amount} coins to {player.Name} (total: {profile.Data.Coins})`
end
