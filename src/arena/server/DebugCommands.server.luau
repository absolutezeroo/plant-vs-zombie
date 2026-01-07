--!strict
--[[
	DebugCommands.server.luau - Debug chat commands for testing in Studio
	
	Chat commands (Studio only):
	- /loadmap World1_Day    -> Load a specific map
	- /spawn basic 3         -> Spawn zombie in lane 3
	- /skip                  -> Skip to next wave
	
	NO auto-loading - use normal game flow, then use commands as needed.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run in Studio
if not RunService:IsStudio() then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

Logger.Info("DebugCommands", "=== STUDIO DEBUG MODE ===")
Logger.Info("DebugCommands", "Chat commands: /loadmap, /spawn, /skip")

-- Lazy getters to avoid require during initialization
local function getMapLoader()
	local services = script.Parent:FindFirstChild("services")
	if services then
		local mod = services:FindFirstChild("MapLoader")
		if mod then return require(mod) end
	end
	return nil
end

-- Handle chat commands
local function onPlayerChatted(player: Player, message: string)
	if message:sub(1, 1) ~= "/" then
		return
	end
	
	local args = message:split(" ")
	local command = args[1]:lower()
	
	-- /loadmap <MapId>
	if command == "/loadmap" then
		local mapId = args[2] or "World1_Day"
		Logger.Info("DebugCommands", `Loading map: {mapId}`)
		
		task.spawn(function()
			local MapLoader = getMapLoader()
			if MapLoader then
				MapLoader.LoadMap(mapId)
			end
		end)
		return
	end
	
	-- /spawn <type> <lane> - Spawn zombie
	if command == "/spawn" then
		local zombieType = args[2] or "Basic"
		local lane = tonumber(args[3]) or math.random(1, 5)
		
		Logger.Info("DebugCommands", `Spawning {zombieType} in lane {lane}`)
		
		task.spawn(function()
			local managers = script.Parent:FindFirstChild("managers")
			if managers then
				local wave = managers:FindFirstChild("wave")
				if wave then
					local WaveSpawner = require(wave:FindFirstChild("WaveSpawner"))
					local spawner = WaveSpawner.GetInstance()
					if spawner then
						spawner:SpawnZombie(zombieType, lane)
					end
				end
			end
		end)
		return
	end
	
	-- /skip - Skip preparation / advance wave
	if command == "/skip" then
		task.spawn(function()
			local managers = script.Parent:FindFirstChild("managers")
			if managers then
				local wave = managers:FindFirstChild("wave")
				if wave then
					local WaveManager = require(wave:FindFirstChild("WaveManager"))
					local manager = WaveManager.GetInstance()
					if manager then
						manager:SkipPreparation()
						Logger.Info("DebugCommands", "Skipped preparation phase")
					end
				end
			end
		end)
		return
	end
end

-- Connect chat for all players
local function onPlayerAdded(player: Player)
	player.Chatted:Connect(function(message)
		onPlayerChatted(player, message)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
