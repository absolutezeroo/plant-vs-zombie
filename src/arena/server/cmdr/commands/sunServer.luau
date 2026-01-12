--!strict
--[[
	sun Command (Server)
	
	Adds sun to the player's current match balance.
	Usage: sun 500
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Use SunService directly
local Server = script.Parent.Parent.Parent
local SunService = require(Server.services.SunService)

return function(context, amount: number)
	local player = context.Executor

	-- Add sun using SunService
	SunService.AddSun(player, amount)
	local newTotal = SunService.GetSun(player)

	-- Sync to client
	SunService.BroadcastSunUpdate(player)

	Logger.Info("Cmdr", `Added {amount} sun to {player.Name}`)
	return `Added {amount} sun (total: {newTotal})`
end
