--!strict
--[[
	level Command (Server)
	
	Sets the player's level.
	Usage: level 10
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Server = script.Parent.Parent.Parent
local PlayerDataService = require(Server.services.PlayerDataService)

return function(context, level: number, target: Player?)
	local player = target or context.Executor
	
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return `Profile not loaded for {player.Name}`
	end
	
	level = math.clamp(level, 1, 100)
	profile.Data.Level = level
	profile.Data.XP = 0
	
	-- Sync to client
	PlayerDataService.SyncToClient(player)
	
	Logger.Info("Cmdr", `Set {player.Name} level to {level}`)
	return `{player.Name} level set to {level}`
end
