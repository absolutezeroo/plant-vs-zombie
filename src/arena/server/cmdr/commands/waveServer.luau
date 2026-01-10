--!strict
--[[
	wave Command (Server)
	
	Shows current wave info.
	Usage: wave -> Show current wave status
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Server = script.Parent.Parent.Parent
local WaveService = require(Server.services.WaveService)

return function(_context)
	-- Show current wave info using WaveService
	local currentWave = WaveService.GetCurrentWave()
	local totalWaves = WaveService.GetTotalWaves()
	local gameState = WaveService.GetGameState()
	local worldId = WaveService.GetCurrentWorldId()
	local difficulty = WaveService.GetCurrentDifficulty()
	
	local lines = {
		"=== Wave Info ===",
		`Wave: {currentWave}/{totalWaves}`,
		`State: {gameState}`,
		`World: {worldId}`,
		`Difficulty: {difficulty}`,
	}
	
	Logger.Info("Cmdr", `Wave info requested: {currentWave}/{totalWaves} ({gameState})`)
	return table.concat(lines, "\n")
end
