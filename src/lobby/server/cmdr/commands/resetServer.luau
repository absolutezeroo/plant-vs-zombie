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

	local success = PlayerDataService.ResetProfile(player)
	if not success then
		return `Profile not loaded for {player.Name}`
	end

	-- Sync to client
	PlayerDataService.SyncToClient(player)

	Logger.Info("Cmdr", `Reset all data for {player.Name}`)
	return `Data reset to defaults for {player.Name}`
end
