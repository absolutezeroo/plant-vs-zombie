--!strict
--[[
	Server Bootstrap - Initializes Matter ECS World and system loop
	
	Runs at 60 Hz (TICK_RATE from NetworkConfig)
	Systems execute in priority order within phases:
	- Input Phase: Priority 0-99
	- Simulation Phase: Priority 100-299
	- Presentation Phase: Priority 300-399
	- Cleanup Phase: Priority 400+
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- Wait for packages to be available
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ErrorHandler = require(Shared.utils.ErrorHandler)
local EntityPool = require(Shared.utils.EntityPool)
local PerformanceConfig = require(Shared.config.PerformanceConfig)
local NetworkConfig = require(Shared.config.NetworkConfig)
local TeleportData = require(Shared.data.TeleportData)

-- Import components via index module
local Components = require(Shared.components)
local Tags = Components.Tags
local _GridPositionComponent = Components.GridPositionComponent -- Reserved for future use
local _HealthComponent = Components.HealthComponent -- Reserved for future use

-- Import server services
local Server = script
local PlayerDataService = require(Server.services.PlayerDataService)
local ProgressionHandler = require(Server.handlers.ProgressionHandler)
local ArenaService = require(Server.services.ArenaService)

-- Import server systems folder
-- Note: init.server.luau IS the Server script, so children are direct
local Systems = script:WaitForChild("systems")

-- Initialize services
PlayerDataService.Initialize()
Logger.Info("Server", "PlayerDataService initialized")

-- Initialize handlers
ProgressionHandler.Initialize()
Logger.Info("Server", "ProgressionHandler initialized")

-- Create Matter World
local world = Matter.World.new()

-- Create Matter Loop (debugger disabled - needs Plasma update)
-- TODO: Add Plasma to wally.toml and re-enable debugger
local loop = Matter.Loop.new(world)

Logger.Info("Server", "Matter World created")

-- Initialize Entity Pool
EntityPool.Initialize(world, Tags.InactiveTag)
Logger.Info("Server", "Entity Pool initialized", EntityPool.GetStats())

-- Load all systems from systems folder (RECURSIVELY scan subfolders)
local systemModules: {any} = {}

local function loadSystem(moduleScript: ModuleScript)
	local success, system = ErrorHandler.Try(function()
		return require(moduleScript)
	end, `LoadSystem.{moduleScript.Name}`)
	
	if success and system then
		table.insert(systemModules, system)
		Logger.Debug("Server", `Loaded system: {moduleScript.Name}`, {
			priority = system.priority or 0
		})
	end
end

-- Recursively load systems from all subfolders using GetDescendants
-- This supports the domain-driven folder structure (combat/, economy/, units/, etc.)
for _, descendant in Systems:GetDescendants() do
	if descendant:IsA("ModuleScript") then
		loadSystem(descendant)
	end
end

Logger.Info("Server", `Loaded {#systemModules} systems`)

-- Schedule systems in the loop
loop:scheduleSystems(systemModules)

-- Start the loop at 60 Hz
loop:begin({
	default = RunService.Heartbeat,
})

Logger.Info("Server", `ECS loop started at {NetworkConfig.TICK_RATE} Hz`)

-- Performance monitoring
local frameCount = 0
local lastMonitorTime = tick()

RunService.Heartbeat:Connect(function(deltaTime)
	frameCount = frameCount + 1
	
	-- Throttled performance logging (every 10 seconds)
	local now = tick()
	if now - lastMonitorTime >= PerformanceConfig.MONITOR_INTERVAL then
		local poolStats = EntityPool.GetStats()
		local avgFPS = frameCount / (now - lastMonitorTime)
		
		-- gcinfo() returns memory in KB, convert to MB
		local memoryKB = gcinfo()
		local memoryMB = memoryKB / 1024
		
		Logger.Performance("Server", "Performance stats", {
			FPS = math.floor(avgFPS),
			EntitiesInUse = poolStats.InUse,
			EntitiesAvailable = poolStats.Available,
			MemoryMB = math.floor(memoryMB),
		})
		
		frameCount = 0
		lastMonitorTime = now
		
		-- Memory warning check
		if memoryMB > PerformanceConfig.MEMORY_WARNING then
			Logger.Warn("Server", "Memory usage high", { MemoryMB = math.floor(memoryMB) })
		end
		if memoryMB > PerformanceConfig.MEMORY_EMERGENCY then
			Logger.Warn("Server", "EMERGENCY: Memory critical - consider ending match")
			-- Note: Roblox doesn't support forced GC, memory is managed automatically
		end
	end
end)

-- ============================================
-- ARENA: Handle players teleporting from Lobby
-- ============================================

-- Storage for player teleport data (stageId, deck)
local playerTeleportData: { [Player]: TeleportData.ArenaJoinData } = {}

local function onPlayerAdded(player: Player)
	Logger.Info("Server", `Player {player.Name} joined Arena`)
	
	-- Get teleport data (if coming from Lobby)
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	
	if teleportData then
		local isValid, err = TeleportData.ValidateArenaJoinData(teleportData)
		if isValid then
			-- Cast after validation to get proper typing
			local validData = teleportData :: TeleportData.ArenaJoinData
			playerTeleportData[player] = validData
			Logger.Info("Server", `{player.Name} teleported from Lobby`, {
				stageId = validData.StageId,
				deckSize = #validData.Deck,
			})
			
			-- Wait for profile to load, then start battle
			task.spawn(function()
				-- Wait up to 10 seconds for profile
				local attempts = 0
				while attempts < 100 do
					local profileData = PlayerDataService.GetProfile(player)
					if profileData then
						-- Start battle with teleported stage/deck
						ArenaService.StartBattle(player, validData.StageId, validData.Deck)
						break
					end
					task.wait(0.1)
					attempts += 1
				end
				
				if attempts >= 100 then
					Logger.Error("Server", `Profile load timeout for {player.Name}`)
					-- Could teleport back to Lobby here
				end
			end)
		else
			Logger.Warn("Server", `Invalid teleport data for {player.Name}: {err}`)
			-- Teleport back to lobby with error
			-- TeleportService:Teleport(TeleportData.PlaceIds.Lobby, player)
		end
	else
		Logger.Info("Server", `{player.Name} joined directly (no teleport data)`)
		-- Player joined without going through Lobby
		-- For testing in Studio, start with default stage
		task.spawn(function()
			local attempts = 0
			while attempts < 100 do
				local profileData = PlayerDataService.GetProfile(player)
				if profileData then
					-- Start with first stage for testing
					local defaultStage = profileData.CurrentStage or "1-1"
					local defaultDeck = {"Sunflower", "Peashooter", "WallNut"}
					Logger.Info("Server", `Starting test battle with stage {defaultStage}`)
					ArenaService.StartBattle(player, defaultStage, defaultDeck)
					break
				end
				task.wait(0.1)
				attempts += 1
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	playerTeleportData[player] = nil
	ArenaService.OnPlayerRemoving(player)
end

-- Get player's current match data
local function getPlayerMatchData(player: Player): TeleportData.ArenaJoinData?
	return playerTeleportData[player]
end

-- Teleport player back to Lobby with results
local function sendPlayerToLobby(player: Player, victory: boolean, stars: number, coins: number, xp: number)
	local teleportOptions = Instance.new("TeleportOptions")
	local returnData = TeleportData.CreateLobbyReturnData(
		playerTeleportData[player] and playerTeleportData[player].StageId or "unknown",
		victory,
		stars,
		coins,
		xp
	)
	teleportOptions:SetTeleportData(returnData)
	
	local success, err = pcall(function()
		TeleportService:TeleportAsync(TeleportData.PlaceIds.Lobby, { player }, teleportOptions)
	end)
	
	if not success then
		Logger.Error("Server", `Failed to teleport {player.Name} to Lobby: {err}`)
	end
end

-- Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game (Studio testing)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- ============================================
-- NETWORK HANDLERS
-- ============================================

-- Import Zap network
local ServerScriptService = game:GetService("ServerScriptService")
local Network = require(ServerScriptService.Server.network.generated)

-- Handle "Ready" button - start waves immediately
Network.StartWaveRequest.SetCallback(function(player: Player, data: {RequestId: number}): {Success: boolean, ErrorCode: number}
	Logger.Info("Server", `{player.Name} pressed Ready button`)
	
	-- Get WaveManager
	local WaveManagerSystemModule = require(Server.systems.wave.WaveManagerSystem)
	local WaveManager = WaveManagerSystemModule.WaveManager
	
	-- Try to start waves
	local success = WaveManager.StartWaves()
	
	if success then
		return {Success = true, ErrorCode = 0}
	else
		return {Success = false, ErrorCode = 1} -- Not in preparation phase
	end
end)

Logger.Info("Server", "Network handlers registered")

-- Export functions for other modules
-- Note: In a real implementation, these would be in a separate ArenaService
_G.ArenaGetPlayerMatchData = getPlayerMatchData
_G.ArenaSendPlayerToLobby = sendPlayerToLobby

Logger.Info("Server", "Server bootstrap complete")
