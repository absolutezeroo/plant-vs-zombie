--!strict
--[[
	startgame Command (Server)
	
	Starts the game in Studio Debug mode.
	Usage: startgame         -> Start with day/normal
	Usage: startgame night   -> Start with night/normal
	Usage: startgame day hard -> Start with day/hard
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Server = script.Parent.Parent.Parent

return function(_context, worldId: string?, difficulty: string?)
	local world = worldId or "day"
	local diff = difficulty or "normal"
	
	-- Get WaveManagerSystem
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
	
	-- Check if game already running
	local currentState = WaveManager.GetGameState()
	if currentState ~= "Waiting" and currentState ~= nil then
		return `Game already running! State: {currentState}. Use 'reset' command first.`
	end
	
	-- Start the game
	local success = WaveManager.StartGame(world, diff)
	
	if success then
		Logger.Info("Cmdr", `Game started: {world}/{diff}`)
		return `🎮 Game started! World: {world}, Difficulty: {diff}`
	else
		return `Failed to start game with world={world}, difficulty={diff}`
	end
end
