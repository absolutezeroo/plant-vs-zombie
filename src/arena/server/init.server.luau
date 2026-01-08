--!strict
--[[
	Server Bootstrap - Initializes Matter ECS World and system loop
	
	Runs at 60 Hz (TICK_RATE from NetworkConfig)
	Uses SystemManager for proper system lifecycle (Init/System/Dispose).
	
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
local TeleportDataHandler = require(Shared.services.TeleportDataHandler)
local SystemManager = require(Shared.utils.SystemManager)

-- Import components via index module
local Components = require(Shared.components)
local Tags = Components.Tags

-- Import server services
local Server = script
local PlayerDataService = require(Server.services.PlayerDataService)
local ProgressionHandler = require(Server.handlers.ProgressionHandler)
local ArenaService = require(Server.services.ArenaService)

-- Import MutationApplySystem for its API (to load player mutations on join)
local MutationApplySystemModule = require(Server.systems.mutations.MutationApplySystem)

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
local function loadSystem(moduleScript: ModuleScript)
	local success, system = ErrorHandler.Try(function()
		return require(moduleScript)
	end, `LoadSystem.{moduleScript.Name}`)
	
	if success and system then
		SystemManager.Register(system)
		Logger.Debug("Server", `Registered system: {moduleScript.Name}`, {
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

Logger.Info("Server", `Registered {#SystemManager.GetMatterSystems()} systems`)

-- Initialize ALL systems BEFORE Matter loop starts (CAN yield here)
SystemManager.InitializeAll(world)
Logger.Info("Server", "All systems initialized")

-- Schedule systems in the loop
loop:scheduleSystems(SystemManager.GetMatterSystems())

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
-- ARENA: Initialize TeleportDataHandler (unified sync system)
-- ============================================

-- Initialize TeleportDataHandler with Arena dependencies
-- This handles ALL player join logic: profile waiting, teleport data, mutations, deck sync
TeleportDataHandler.InitializeArena({
	PlayerDataService = PlayerDataService,
	MutationApplySystem = MutationApplySystemModule.API,
	ArenaService = ArenaService,
	ProgressionHandler = ProgressionHandler,
})

Logger.Info("Server", "TeleportDataHandler initialized for Arena")

-- Subscribe to OnPlayerReady signal to start battles
TeleportDataHandler.OnPlayerReady:Connect(function(player: Player, teleportData: TeleportData.ArenaJoinData?)
	Logger.Info("Server", `Player {player.Name} is ready (profile loaded, teleport data applied)`)
	
	-- Sync player data and deck to client BEFORE starting battle
	-- This ensures the client has the correct deck/mutations
	if ProgressionHandler.SyncPlayerData then
		ProgressionHandler.SyncPlayerData(player)
	end
	if ProgressionHandler.SyncDeck then
		ProgressionHandler.SyncDeck(player)
	end
	
	if teleportData then
		-- Player came from Lobby with valid teleport data
		Logger.Info("Server", `Starting battle: World={teleportData.WorldId}, Difficulty={teleportData.Difficulty}, Deck={#teleportData.Deck} plants`)
		ArenaService.StartBattle(player, teleportData.WorldId, teleportData.Difficulty, teleportData.Deck)
	else
		-- Direct join (Studio testing) - use default values
		local defaultWorldId = "day"
		local defaultDifficulty = "normal"
		local defaultDeck = PlayerDataService.GetDeck(player)
		Logger.Info("Server", `Starting test battle: World={defaultWorldId}, Difficulty={defaultDifficulty}`)
		ArenaService.StartBattle(player, defaultWorldId, defaultDifficulty, defaultDeck)
	end
end)

-- Clean up when player leaves
local function onPlayerRemoving(player: Player)
	-- Dispose player-specific resources in all systems
	SystemManager.DisposePlayer(player)
	
	MutationApplySystemModule.API.ClearPlayerMutations(player.UserId)
	ArenaService.OnPlayerRemoving(player)
end

Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Teleport player back to Lobby with results
local function sendPlayerToLobby(player: Player, victory: boolean, wavesSurvived: number, coins: number, xp: number)
	local teleportOptions = Instance.new("TeleportOptions")
	
	-- Get player's world/difficulty from TeleportDataHandler
	local matchData = TeleportDataHandler.GetTeleportData(player)
	local worldId = matchData and matchData.WorldId or "world_1"
	local difficulty = matchData and matchData.Difficulty or "normal"
	
	-- Calculate stars based on waves (simplified)
	local stars = 0
	if victory then
		if wavesSurvived >= 10 then stars = 3
		elseif wavesSurvived >= 7 then stars = 2
		elseif wavesSurvived >= 5 then stars = 1
		end
	end
	
	local returnData = TeleportData.CreateLobbyReturnData(
		worldId,
		difficulty,
		victory,
		stars,
		wavesSurvived,
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

-- ============================================
-- NETWORK HANDLERS
-- ============================================

-- Import Zap network
local Network = require(Shared.network.generated.server)

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
_G.ArenaGetPlayerMatchData = function(player: Player) return TeleportDataHandler.GetTeleportData(player) end
_G.ArenaSendPlayerToLobby = sendPlayerToLobby

-- Cleanup when server shuts down
game:BindToClose(function()
	Logger.Info("Server", "Server shutting down - disposing all systems")
	SystemManager.DisposeAll()
end)

Logger.Info("Server", "Server bootstrap complete")
