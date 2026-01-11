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
local Promise = require(Packages:WaitForChild("Promise"))
local Trove = require(Packages:WaitForChild("Trove"))

-- Trove for server-level connection cleanup
local _serverTrove = Trove.new()

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ErrorHandler = require(Shared.utils.ErrorHandler)
local EntityPool = require(Shared.utils.EntityPool)
local PerformanceConfig = require(Shared.config.PerformanceConfig)
local NetworkConfig = require(Shared.config.NetworkConfig)
local MapConfig = require(Shared.config.MapConfig)
local TeleportData = require(Shared.data.TeleportData)
local TeleportDataHandler = require(Shared.services.TeleportDataHandler)
local SystemManager = require(Shared.utils.SystemManager)

-- Import components via index module
local Components = require(Shared.components)
local Tags = Components.Tags

-- Check if running in Studio (for debug mode)
local IS_STUDIO = RunService:IsStudio()

-- Import server services
local Server = script
local PlayerDataService = require(Server.services.PlayerDataService)
local ProgressionHandler = require(Server.handlers.ProgressionHandler)
local ArenaService = require(Server.services.ArenaService)
local MapLoader = require(Server.services.MapLoader)

-- Import MutationService for teleport data handling
local MutationService = require(Server.services.MutationService)
local StatsService = require(Server.services.StatsService)

-- Import server systems folder
-- Note: init.server.luau IS the Server script, so children are direct
local Systems = script:WaitForChild("systems")

-- ============================================
-- CRITICAL: Initialize TeleportDataHandler FIRST
-- This must happen BEFORE PlayerDataService to avoid race conditions
-- TeleportDataHandler needs to register its PlayerAdded callback first
-- so it can receive NotifyProfileLoaded calls from PlayerDataService
-- ============================================
TeleportDataHandler.InitializeArena({
	PlayerDataService = PlayerDataService,
	MutationService = MutationService,
	ArenaService = ArenaService,
	ProgressionHandler = ProgressionHandler,
})
Logger.Info("Server", "TeleportDataHandler initialized for Arena (EARLY)")

-- NOW initialize PlayerDataService (it will call NotifyProfileLoaded which TeleportDataHandler can receive)
PlayerDataService.Initialize()
Logger.Info("Server", "PlayerDataService initialized")

StatsService.Initialize()
Logger.Info("Server", "StatsService initialized")

-- Initialize handlers
ProgressionHandler.Initialize()
Logger.Info("Server", "ProgressionHandler initialized")

-- CRITICAL: Load map BEFORE MapConfig.Initialize()
-- MapConfig reads grid bounds from ArenaMap, so map must exist first
MapLoader.Initialize()
local defaultMapId = "Map_Day"
local mapLoaded = MapLoader.LoadMap(defaultMapId)
if mapLoaded then
	Logger.Info("Server", `Default map '{defaultMapId}' loaded for MapConfig initialization`)
else
	Logger.Warn("Server", `Failed to load default map '{defaultMapId}', MapConfig will use defaults`)
end

-- CRITICAL: Initialize MapConfig AFTER map is loaded, BEFORE Matter loop starts
-- This prevents yield errors in ECS systems that call MapConfig functions
MapConfig.Initialize()
Logger.Info("Server", "MapConfig initialized (pre-cached for ECS systems)")

-- Create Matter World
local world = Matter.World.new()

-- Create Matter Loop (debugger disabled - needs Plasma update)
-- TODO: Add Plasma to wally.toml and re-enable debugger
local loop = Matter.Loop.new(world)

Logger.Info("Server", "Matter World created")

-- Initialize Entity Pool with all components for cleanup on release
EntityPool.Initialize(world, Tags.InactiveTag, Components)
Logger.Info("Server", "Entity Pool initialized", EntityPool.GetStats())

-- Load all systems from systems folder (RECURSIVELY scan subfolders)
local function loadSystem(moduleScript: ModuleScript)
	local success, system = ErrorHandler.Try(function()
		return require(moduleScript)
	end, `LoadSystem.{moduleScript.Name}`)
	
	if success and system then
		SystemManager.Register(system, moduleScript.Name)
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

-- Start the loop at 60 Hz - store connections for cleanup
local loopConnections = loop:begin({
	default = RunService.Heartbeat,
})

-- Add loop connections to trove for proper cleanup
for _, connection in loopConnections do
	_serverTrove:Add(connection)
end

Logger.Info("Server", `ECS loop started at {NetworkConfig.TICK_RATE} Hz`)

-- Performance monitoring
local frameCount = 0
local lastMonitorTime = tick()

_serverTrove:Connect(RunService.Heartbeat, function(deltaTime)
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
-- STUDIO DEBUG MODE: Load map only, no gameplay
-- ============================================
if IS_STUDIO then
	Logger.Info("Server", "=== STUDIO DEBUG MODE ===")
	Logger.Info("Server", "Map already loaded during bootstrap")
	Logger.Info("Server", "Use Cmdr commands (F2) to test: loadmap, spawn, wave, sun, killall")
	
	-- Handle player join in Studio Debug mode
	_serverTrove:Connect(TeleportDataHandler.OnPlayerReady, function(player: Player, _teleportData: TeleportData.ArenaJoinData?)
		Logger.Info("Server", `[Studio Debug] Player {player.Name} joined`)
		
		-- Sync map config FIRST (client needs this for grid visualization)
		MapLoader.SyncConfigToPlayer(player)
		
		-- Load mutations from profile (Studio mode has no teleport data)
		local profileData = PlayerDataService.GetProfile(player)
		if profileData then
			MutationService.LoadMutationsFromProfile(player, profileData)
		end
		
		-- Sync player data
		if ProgressionHandler.SyncPlayerData then
			ProgressionHandler.SyncPlayerData(player)
		end
		if ProgressionHandler.SyncDeck then
			ProgressionHandler.SyncDeck(player)
		end
		
		-- Spawn character but DON'T start battle
		player:LoadCharacterAsync()
		Logger.Info("Server", `[Studio Debug] Spawned {player.Name} - use Cmdr to test!`)
	end)
else
	-- ============================================
	-- PRODUCTION MODE: Normal gameplay flow
	-- ============================================

-- Subscribe to OnPlayerReady signal to start battles
_serverTrove:Connect(TeleportDataHandler.OnPlayerReady, function(player: Player, teleportData: TeleportData.ArenaJoinData?)
	Logger.Info("Server", `Player {player.Name} is ready (profile loaded, teleport data applied)`)
	
	-- Sync map config FIRST (client needs this for grid visualization)
	MapLoader.SyncConfigToPlayer(player)
	
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
	
	-- NOW spawn the character (after map is loaded)
	-- CharacterAutoLoads is disabled, so we spawn manually
	player:LoadCharacterAsync()
	Logger.Info("Server", `Spawned character for {player.Name}`)
end)

end -- End of IS_STUDIO check

-- Clean up when player leaves
local function onPlayerRemoving(player: Player)
	-- Dispose player-specific resources in all systems
	SystemManager.DisposePlayer(player)
	
	MutationService.ClearPlayerMutations(player.UserId)
	ArenaService.OnPlayerRemoving(player)
	
	-- Check if this was the last player (after a short delay to let other systems process)
	task.defer(function()
		if #Players:GetPlayers() == 0 then
			Logger.Info("Server", "Last player left - stopping game loop")
			_serverTrove:Clean() -- This will disconnect the Matter loop
			SystemManager.DisposeAll()
		end
	end)
end

_serverTrove:Connect(Players.PlayerRemoving, onPlayerRemoving)

-- Teleport configuration
local TELEPORT_MAX_RETRIES = 3
local TELEPORT_RETRY_DELAY = 2

-- Teleport player back to Lobby with results (uses Promise.retry)
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
	
	Promise.retry(function()
		return Promise.new(function(resolve, reject)
			if player.Parent ~= Players then
				reject("Player left the game")
				return
			end
			
			TeleportService:TeleportAsync(TeleportData.PlaceIds.Lobby, { player }, teleportOptions)
			resolve()
		end)
	end, TELEPORT_MAX_RETRIES, function(attempt)
		Logger.Warn("Server", `Teleport to Lobby attempt {attempt} failed for {player.Name}, retrying...`)
		return TELEPORT_RETRY_DELAY * attempt
	end):andThen(function()
		Logger.Info("Server", `{player.Name} teleported to Lobby`)
	end):catch(function(err)
		Logger.Error("Server", `Failed to teleport {player.Name} to Lobby after {TELEPORT_MAX_RETRIES} attempts: {err}`)
	end)
end

-- ============================================
-- NETWORK HANDLERS
-- ============================================

-- Import Zap network
local Network = require(Shared.network.generated.server)

-- Handle "Ready" button - start waves immediately
Network.StartWaveRequest.SetCallback(function(player: Player, data: {RequestId: number}): {Success: boolean, ErrorCode: number}
	Logger.Info("Server", `{player.Name} pressed Ready button`)
	
	-- Get WaveService
	local WaveService = require(Server.services.WaveService)
	
	-- Try to start waves
	local success = WaveService.StartWaves()
	
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
	_serverTrove:Clean() -- Clean up all server-level connections (including Matter loop)
	TeleportDataHandler.Dispose() -- Clean up TeleportDataHandler
	SystemManager.DisposeAll()
	Logger.Info("Server", "Matter loop stopped")
end)

Logger.Info("Server", "Server bootstrap complete")
