--!strict
--[[
	lose Command (Server)
	
	Forces a defeat for testing the VictoryDefeatScreen.
	Sends fake GameEndRewards event to the calling player.
	
	Usage: lose [wave]
	Example: lose 5
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.network.generated.server)
local Logger = require(Shared.utils.Logger)

return function(context, wave: number?)
	local player = context.Executor
	
	-- Default to wave 3
	local waveReached = math.clamp(wave or 3, 1, 10)
	
	-- Generate fake rewards data (reduced for defeat)
	local rewardsData = {
		Victory = false,
		CoinsEarned = 20 * waveReached,
		ZombiesKilled = 8 * waveReached,
		WavesCompleted = waveReached,
		BonusCoins = 0,
		StarRating = 0, -- No stars on defeat
		XPEarned = 30 * waveReached,
		GemsEarned = 0,
		NewLevel = 0,
		LevelsGained = 0,
	}
	
	-- Send to the player
	Network.GameEndRewards.Fire(player, rewardsData)
	
	Logger.Info("Cmdr", `Sent DEFEAT to {player.Name} at wave {waveReached}`)
	return `Defeat at wave {waveReached}. {rewardsData.CoinsEarned} coins, {rewardsData.XPEarned} XP`
end
