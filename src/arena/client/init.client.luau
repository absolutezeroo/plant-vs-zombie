--!strict
--[[
	Client Bootstrap - Initializes client-side Matter World and Fusion UI
	
	Syncs with server at 60 Hz
	Client systems handle:
	- Input processing (Priority 0-99)
	- Ghost prediction (Priority 100-199)
	- Visual updates (Priority 300-399)
	- VFX, Audio, UI (Priority 300-399)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Wait for packages to be available
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Now create the proper LoaderUI
local UI_Folder = script:WaitForChild("ui")
local LoaderUI = require(UI_Folder.LoaderUI)
local loader = LoaderUI.new()

loader:SetStage(1, "Initializing...")

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ErrorHandler = require(Shared.utils.ErrorHandler)
local PerformanceConfig = require(Shared.config.PerformanceConfig)
local NetworkConfig = require(Shared.config.NetworkConfig)
local MapConfig = require(Shared.config.MapConfig)

loader:SetStage(2, "Loading packages...")

-- Import client folders (init.client.luau IS the Client script, children are direct)
local Systems = script:WaitForChild("systems")
local UI = script:WaitForChild("ui")

-- Get local player
local LocalPlayer = Players.LocalPlayer

Logger.Info("Client", `Initializing client for {LocalPlayer.Name}`)

loader:SetStage(3, "Setting up ECS...")

-- Create client Matter World (separate from server world)
local world = Matter.World.new()

-- Create Matter Loop (debugger disabled - needs Plasma update)
-- TODO: Add Plasma to wally.toml and re-enable debugger
local loop = Matter.Loop.new(world)

Logger.Info("Client", "Client Matter World created")

loader:SetStage(4, "Loading systems...")

-- Load all client systems from systems folder (RECURSIVELY scan subfolders)
local systemModules: {any} = {}

local function loadSystem(moduleScript: ModuleScript)
	local success, system = ErrorHandler.Try(function()
		return require(moduleScript)
	end, `LoadSystem.{moduleScript.Name}`)
	
	if success and system then
		table.insert(systemModules, system)
		Logger.Debug("Client", `Loaded system: {moduleScript.Name}`, {
			priority = system.priority or 0
		})
	end
end

-- Recursively load systems from all subfolders using GetDescendants
-- This supports the domain-driven folder structure (input/, rendering/, presentation/)
for _, descendant in Systems:GetDescendants() do
	if descendant:IsA("ModuleScript") then
		loadSystem(descendant)
	end
end

Logger.Info("Client", `Loaded {#systemModules} client systems`)

-- Schedule systems in the loop
loop:scheduleSystems(systemModules)

loader:SetStage(5, "Preparing UI...")

-- Start the loop at 60 Hz (RenderStepped for client)
loop:begin({
	default = RunService.RenderStepped,
})

Logger.Info("Client", `Client ECS loop started at {NetworkConfig.TICK_RATE} Hz`)

--[[
	Initialize HUD using HUDController
	
	The HUD includes:
	- Sun counter (reactive)
	- Card deck (plant selection)
	- Wave indicator
]]

local UI = script:WaitForChild("ui")
local HUDController = require(UI.HUDController)
local FloatingTextUI = require(UI.FloatingTextUI)
local VictoryDefeatScreen = require(UI.VictoryDefeatScreen)

-- Initialize floating text system
FloatingTextUI.Initialize()
Logger.Info("Client", "FloatingTextUI initialized")

-- Create and mount HUD
local hud = HUDController.new()
hud:Mount()

-- Create and mount Victory/Defeat screen
local victoryScreen = VictoryDefeatScreen.new()
victoryScreen:Mount()

Logger.Info("Client", "HUD and VictoryScreen mounted")

loader:SetStage(6, "Syncing with server...")

-- Performance monitoring (less frequent on client to save cycles)
local frameCount = 0
local lastMonitorTime = tick()

RunService.RenderStepped:Connect(function(deltaTime)
	frameCount = frameCount + 1
	
	-- Throttled performance logging (every 30 seconds on client)
	local now = tick()
	if now - lastMonitorTime >= 30 then
		local avgFPS = frameCount / (now - lastMonitorTime)
		
		Logger.Performance("Client", "Performance stats", {
			FPS = math.floor(avgFPS),
			MemoryMB = math.floor(collectgarbage("count") / 1024),
		})
		
		frameCount = 0
		lastMonitorTime = now
	end
end)

-- Connect network events to HUD
local ClientNetwork = script:WaitForChild("network")
local Network = require(ClientNetwork.generated)

-- Initialize PlayerDataClient
local Modules = script:WaitForChild("modules")
local PlayerDataClient = require(Modules.PlayerDataClient)
PlayerDataClient.Initialize()
Logger.Info("Client", "PlayerDataClient initialized")

-- Connect coin gains to HUD
PlayerDataClient.OnCoinGained(function(event)
	hud:ShowCoinGain(event.Amount, event.PositionX, event.PositionZ)
end)

-- Wave started event
Network.WaveStarted.On(function(data)
	hud:SetWaveNumber(data.WaveNumber)
	
	if data.WaveNumber == 0 then
		-- Preparation phase started
		Logger.Info("Client", "Preparation phase started")
		hud:StartPreparation()
	else
		Logger.Info("Client", `Wave {data.WaveNumber} started`)
	end
end)

-- Countdown timer for preparation phase and intermission
local preparationStartTime = 0
local preparationDuration = 20
local intermissionStartTime = 0
local intermissionDuration = 30 -- WaveConfig.WAVE_DELAY from server

RunService.RenderStepped:Connect(function()
	local currentWave = hud._waveNumber and Fusion.peek(hud._waveNumber) or 0
	local inPreparation = hud._preparationPhase and Fusion.peek(hud._preparationPhase) or false
	local intermissionTime = hud._intermissionTime and Fusion.peek(hud._intermissionTime) or 0
	
	-- Preparation phase countdown
	if currentWave == 0 and inPreparation then
		if preparationStartTime == 0 then
			preparationStartTime = tick()
		end
		
		local elapsed = tick() - preparationStartTime
		local remaining = preparationDuration - elapsed
		
		if remaining > 0 then
			hud:SetPreparationTime(remaining)
		else
			-- Time's up, auto-start
			hud:SetPreparationTime(0)
		end
	else
		preparationStartTime = 0
	end
	
	-- Intermission countdown
	if intermissionTime > 0 and intermissionStartTime > 0 then
		local elapsed = tick() - intermissionStartTime
		local remaining = intermissionDuration - elapsed
		
		if remaining > 0 then
			hud:SetIntermissionTime(remaining)
		else
			hud:SetIntermissionTime(0)
			intermissionStartTime = 0
		end
	end
end)

-- Base health updated event
Network.BaseHealthUpdated.On(function(data)
	hud:SetBaseHealth(data.CurrentHealth, data.MaxHealth)
	if data.DamageAmount > 0 then
		Logger.Warn("Client", `Base took {data.DamageAmount} damage! ({data.CurrentHealth}/{data.MaxHealth})`)
	end
end)

-- Game over event
Network.GameOver.On(function(data)
	-- Basic game over (used as fallback, GameEndRewards has full data)
	Logger.Info("Client", `Game over received: {if data.Victory then "Victory" else "Defeat"} at wave {data.WaveReached}`)
	-- HUD gets basic update for overlay
	hud:SetGameOver(data.Victory, data.WaveReached)
end)

-- Game end rewards event (detailed summary with animations)
Network.GameEndRewards.SetCallback(function(data)
	Logger.Info("Client", `GameEndRewards received: {if data.Victory then "Victory" else "Defeat"}`)
	Logger.Info("Client", `  Coins: {data.CoinsEarned}, XP: {data.XPEarned}, Gems: {data.GemsEarned}`)
	Logger.Info("Client", `  Zombies: {data.ZombiesKilled}, Waves: {data.WavesCompleted}, Stars: {data.StarRating}`)
	
	-- Show the animated victory/defeat screen
	victoryScreen:Show({
		Victory = data.Victory,
		WaveReached = data.WavesCompleted,
		StarRating = data.StarRating,
		CoinsEarned = data.CoinsEarned,
		XPEarned = data.XPEarned,
		GemsEarned = data.GemsEarned,
		ZombiesKilled = data.ZombiesKilled,
		BonusCoins = data.BonusCoins,
		NewLevel = data.NewLevel,
		LevelsGained = data.LevelsGained,
	})
	
	-- Also update HUD (which has the old overlay - now hidden behind VictoryScreen)
	hud:SetGameOver(data.Victory, data.WavesCompleted, {
		StarRating = data.StarRating,
		CoinsEarned = data.CoinsEarned,
		XPEarned = data.XPEarned,
		GemsEarned = data.GemsEarned,
	})
end)

-- Wave completed event (start intermission countdown)
Network.WaveCompleted.On(function(data)
	Logger.Info("Client", `Wave {data.WaveNumber} completed!`)
	
	-- Start intermission countdown
	intermissionStartTime = tick()
	hud:SetIntermissionTime(intermissionDuration)
end)

-- Teleport countdown event
Network.TeleportCountdown.On(function(data)
	Logger.Info("Client", `Teleporting in {data.TimeRemaining}s`)
	if hud then
		hud:SetTeleportCountdown(data.TimeRemaining)
	end
	-- Also update VictoryDefeatScreen
	if victoryScreen then
		victoryScreen:SetTeleportCountdown(data.TimeRemaining)
	end
end)

-- Request response (for placement/collection confirmations)
Network.RequestResponse.On(function(data)
	if not data.Success and data.ErrorCode then
		Logger.Debug("Client", `Request {data.RequestId} failed with error code {data.ErrorCode}`)
	end
end)

-- ============================================
-- MAP ASSET LOADING
-- ============================================

-- Track if we're waiting for map assets
local mapLoadingComplete = false
local mapConfigReceived = false
local mapLoadingStage = 7  -- "Loading map assets..." stage index

-- Map config received from server (authoritative data)
-- This MUST be received before GridVisualization can work correctly
Network.MapConfigSync.On(function(data)
	Logger.Info("Client", `Map config received from server for: {data.MapId}`)
	Logger.Info("Client", `  GridY: {data.GridY}`)
	
	-- Apply the config (this is the authoritative source)
	MapConfig.ApplyFromServer(data)
	mapConfigReceived = true
	
	Logger.Info("Client", "MapConfig applied from server - systems can now use correct coordinates")
end)

-- Map loading started - switch loader to asset loading stage
Network.MapLoadingStarted.On(function(data)
	Logger.Info("Client", `Map loading started: {data.MapId} ({data.TotalAssets} assets)`)
	loader:SetStage(mapLoadingStage, `Loading {data.MapId}...`)
	loader:SetProgress(0)
end)

-- Map loading progress - update loader progress
Network.MapLoadingProgress.On(function(data)
	local progress = data.LoadedAssets / math.max(data.TotalAssets, 1)
	loader:SetProgress(progress)
	loader:SetStatus(`Loading assets... ({data.LoadedAssets}/{data.TotalAssets})`)
end)

-- Map loading complete - mark as done
Network.MapLoadingComplete.On(function(data)
	Logger.Info("Client", `Map loading complete: {data.MapId} (success={data.Success})`)
	mapLoadingComplete = true
	loader:SetProgress(1)
	loader:SetStatus("Map loaded!")
	
	-- Move to final "Ready!" stage
	task.delay(0.2, function()
		loader:CompleteStage()
	end)
end)

-- ============================================
-- LOADING COMPLETE
-- ============================================

-- Wait a moment for any map loading events, then complete
task.delay(1, function()
	-- If no map loading events received, skip to ready
	if not mapLoadingComplete then
		loader:SetStage(mapLoadingStage, "Loading map...")
		loader:SetProgress(1)
		task.wait(0.1)
		loader:CompleteStage()
	end
end)

-- Complete after map is loaded or timeout
task.spawn(function()
	-- Wait for map loading or 5 second timeout
	local timeout = 5
	local elapsed = 0
	while not mapLoadingComplete and elapsed < timeout do
		task.wait(0.1)
		elapsed += 0.1
	end
	
	-- Ensure we're at the Ready stage
	task.wait(0.3)
	loader:Complete(function()
		Logger.Info("Client", "Loading complete - UI visible")
	end)
end)

Logger.Info("Client", "Client bootstrap complete")
