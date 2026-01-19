--!strict
--[[
	skip Command (Server)
	
	Skips the preparation phase and starts waves.
	Usage: skip
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = script.Parent.Parent.Parent
local Logger = require(ReplicatedStorage.Shared.utils.core.Logger)

local WaveService = require(Server.services.WaveService)

return function(_context)
	-- Check if game is in a skippable state
	local currentState = WaveService.GetGameState()

	if currentState == "Waiting" then
		return "Game not started yet. Use 'startgame' first."
	end

	if currentState == "Playing" then
		return "Already playing! No preparation to skip."
	end

	if currentState == "Victory" or currentState == "Defeat" then
		return `Game is over ({currentState}). Use 'reset' first.`
	end

	-- Start waves (skip preparation)
	Logger.Info("Cmdr", "Skipping preparation phase")

	local success = WaveService.StartWaves()

	if success then
		return "⏩ Skipped preparation - waves starting!"
	else
		return "Failed to skip preparation phase"
	end
end
