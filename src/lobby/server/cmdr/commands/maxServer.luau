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

	local success = PlayerDataService.MaxResources(player)
	if not success then
		return `Profile not loaded for {player.Name}`
	end

	-- Sync to client
	PlayerDataService.SyncToClient(player)

	Logger.Info("Cmdr", `Maxed resources for {player.Name}`)
	return `Max resources for {player.Name}: 999999 coins, 9999 gems, level 50`
end
