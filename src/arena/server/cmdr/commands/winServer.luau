--!strict
--[[
	win Command (Server)
	
	Forces a victory for testing the VictoryDefeatScreen.
	Sends fake GameEndRewards event to the calling player.
	
	Usage: win [stars]
	Example: win 3
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.network.generated.server)
local Logger = require(Shared.utils.Logger)

return function(context, stars: number?)
	local player = context.Executor
	
	-- Default to 3 stars
	local starCount = math.clamp(stars or 3, 1, 3)
	
	-- Generate fake rewards data
	local rewardsData = {
		Victory = true,
		CoinsEarned = 150 * starCount,
		ZombiesKilled = 42 + (starCount * 10),
		WavesCompleted = 10,
		BonusCoins = 50,
		StarRating = starCount,
		XPEarned = 200 * starCount,
		GemsEarned = if starCount >= 3 then 5 else 0,
		NewLevel = 5,
		LevelsGained = 0,
	}
	
	-- Send to the player
	Network.GameEndRewards.Fire(player, rewardsData)
	
	Logger.Info("Cmdr", `Sent VICTORY to {player.Name} with {starCount} stars`)
	return `Victory! {starCount} stars, {rewardsData.CoinsEarned} coins, {rewardsData.XPEarned} XP`
end
