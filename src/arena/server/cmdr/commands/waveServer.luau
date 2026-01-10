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

return function(_context)
	-- Get WaveManagerSystem (which exports WaveManager API)
	local systems = Server:FindFirstChild("systems")
	if not systems then
		return "Systems folder not found"
	end
	
	local waveFolder = systems:FindFirstChild("wave")
	if not waveFolder then
		return "Wave systems folder not found"
	end
	
	local WaveManagerSystemModule = waveFolder:FindFirstChild("WaveManagerSystem")
	if not WaveManagerSystemModule then
		return "WaveManagerSystem not found"
	end
	
	local WaveManagerSystem = require(WaveManagerSystemModule)
	local WaveManager = WaveManagerSystem.WaveManager
	
	if not WaveManager then
		return "WaveManager API not available"
	end
	
	-- Show current wave info
	local currentWave = WaveManager.GetCurrentWave()
	local totalWaves = WaveManager.GetTotalWaves()
	local gameState = WaveManager.GetGameState()
	local worldId = WaveManager.GetCurrentWorldId()
	local difficulty = WaveManager.GetCurrentDifficulty()
	
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
