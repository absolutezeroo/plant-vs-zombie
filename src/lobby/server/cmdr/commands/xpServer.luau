--!strict
--[[
	xp Command (Server)
	
	Gives XP to the player (may trigger level up).
	Usage: xp 500
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Server = script.Parent.Parent.Parent
local PlayerDataService = require(Server.services.PlayerDataService)

return function(context, amount: number, target: Player?)
	local player = target or context.Executor

	local data = PlayerDataService.GetData(player)
	if not data then
		return `Profile not loaded for {player.Name}`
	end

	-- Use the proper AddXP method (handles level ups correctly)
	local levelsGained = PlayerDataService.AddXP(player, amount)

	-- Sync to client
	PlayerDataService.SyncToClient(player)

	Logger.Info("Cmdr", `Gave {amount} XP to {player.Name}, now level {data.Level}`)

	if levelsGained > 0 then
		return `+{amount} XP to {player.Name} (Level {data.Level}, +{levelsGained} levels!)`
	end
	return `+{amount} XP to {player.Name} (Level {data.Level})`
end
