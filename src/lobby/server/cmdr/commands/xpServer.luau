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

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return `Profile not loaded for {player.Name}`
	end

	profile.Data.XP = (profile.Data.XP or 0) + amount

	-- Level up logic
	local xpNeeded = profile.Data.TotalXPForNextLevel or 100
	local levelsGained = 0

	while profile.Data.XP >= xpNeeded do
		profile.Data.XP = profile.Data.XP - xpNeeded
		profile.Data.Level = (profile.Data.Level or 1) + 1
		levelsGained += 1
		xpNeeded = 100 + (profile.Data.Level * 50)
		profile.Data.TotalXPForNextLevel = xpNeeded
	end

	-- Sync to client
	PlayerDataService.SyncToClient(player)

	Logger.Info("Cmdr", `Gave {amount} XP to {player.Name}, now level {profile.Data.Level}`)

	if levelsGained > 0 then
		return `+{amount} XP to {player.Name} (Level {profile.Data.Level}, +{levelsGained} levels!)`
	end
	return `+{amount} XP to {player.Name} (Level {profile.Data.Level})`
end
