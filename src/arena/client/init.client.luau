--!strict
--[[
    Arena Client Bootstrap
    
    Initializes the Arena game client:
    - Matter ECS World for client-side systems
    - HUD (sun counter, card deck, wave indicator)
    - Victory/Defeat screen
    - Network event handling
    
    Uses ServiceLoader for structured initialization.
    Uses SystemManager for proper system lifecycle (Init/System/Dispose).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

-- Disable default Roblox UI elements
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ErrorHandler = require(Shared.utils.ErrorHandler)
local NetworkConfig = require(Shared.config.NetworkConfig)
local MapConfig = require(Shared.config.MapConfig)
local ServiceLoader = require(Shared.utils.ServiceLoader)
local SystemManager = require(Shared.utils.SystemManager)
local GameSignals = require(Shared.signals.GameSignals)

-- Client MUST wait for server to send MapConfigSync with authoritative values.
MapConfig.SetClientMode()

-- Get local player
local LocalPlayer = Players.LocalPlayer

-- Trove for connection cleanup
local _clientTrove = Trove.new()

-- ============================================
-- DEFERRED MODULE REFERENCES
-- ============================================
local Network: any
local PlayerDataClient: any
local HUDController: any
local FloatingTextUI: any
local VictoryDefeatScreen: any
local PlantTooltipController: any

-- Client ECS
local world: any
local loop: any

-- UI instances
local hud: any
local victoryScreen: any

-- Countdown state
local preparationStartTime = 0
local preparationDuration = 20
local intermissionStartTime = 0
local intermissionDuration = 10 -- Must match WaveConfig.WAVE_DELAY on server
local totalWaves = 10 -- Default, will be updated by GameStarted event

-- Create a scope for Fusion cleanup
local scope = Fusion.scoped(Fusion)

-- ============================================
-- LOADER INITIALIZATION
-- ============================================

local loader = ServiceLoader.new({
    stages = {
        { name = "Modules", tip = "Loading game modules..." },
        { name = "ECS", tip = "Setting up game systems..." },
        { name = "Network", tip = "Establishing connection..." },
        { name = "UI", tip = "Building interface..." },
        { name = "MapSync", tip = "Syncing map data..." },
        { name = "Ready", tip = "Entering the arena!" },
    }
})

-- ============================================
-- NETWORK EVENT LISTENERS
-- ============================================

--[[
    Setup early network listeners that must be ready BEFORE ECS systems init.
    This includes MapConfigSync which GridVisualizationSystem waits for.
]]
local function setupEarlyNetworkListeners()
    -- Map config sync (critical - must be ready before GridVisualization Init)
    Network.MapConfigSync.On(function(data)
        Logger.Info("ArenaClient", `Map config received: {data.MapId}, GridY={data.GridY}`)
        MapConfig.ApplyFromServer(data)
    end)

    -- Map loading started
    Network.MapLoadingStarted.On(function(data)
        Logger.Info("ArenaClient", `Map loading: {data.MapId} ({data.TotalAssets} assets)`)
    end)

    -- Map loading progress
    Network.MapLoadingProgress.On(function(data)
        local progress = data.LoadedAssets / math.max(data.TotalAssets, 1)
        Logger.Debug("ArenaClient", `Map progress: {math.floor(progress * 100)}%`)
    end)

    -- Map loading complete
    Network.MapLoadingComplete.On(function(data)
        Logger.Info("ArenaClient", `Map loaded: {data.MapId} (success={data.Success})`)
    end)
    
    Logger.Debug("ArenaClient", "Early network listeners setup complete")
end

--[[
    Setup network listeners that depend on HUD being ready.
    Called after UI is mounted.
]]
local function setupNetworkListeners()
    -- Game started event (receives total wave count)
    Network.GameStarted.On(function(data)
        Logger.Info("ArenaClient", `Game started: World={data.WorldId}, Difficulty={data.Difficulty}, Waves={data.WaveCount}`)
        totalWaves = data.WaveCount or 10
        
        -- Mark game as started (enables Ready button in HUD)
        hud:SetGameStarted(true)
        
        -- Fire initial wave change with MaxWaves
        GameSignals.OnWaveChanged:Fire({
            WaveNumber = 0,
            MaxWaves = totalWaves,
            IsPreparation = true,
        })
    end)
    
    -- Wave started event
    Network.WaveStarted.On(function(data)
        -- Fire signal for HUD to react (include MaxWaves)
        GameSignals.OnWaveChanged:Fire({
            WaveNumber = data.WaveNumber,
            MaxWaves = totalWaves,
            IsPreparation = data.WaveNumber == 0,
        })
        
        if data.WaveNumber == 0 then
            Logger.Info("ArenaClient", "Preparation phase started")
        else
            -- Reset intermission when new wave starts
            intermissionStartTime = 0
            hud:SetIntermissionTime(0) -- Clear intermission display
            Logger.Info("ArenaClient", `Wave {data.WaveNumber} started`)
        end
    end)

    -- Base health updated event
    Network.BaseHealthUpdated.On(function(data)
        -- Fire signal for HUD to react
        GameSignals.OnBaseHealthChanged:Fire({
            CurrentHealth = data.CurrentHealth,
            MaxHealth = data.MaxHealth,
            DamageAmount = data.DamageAmount,
        })
        
        if data.DamageAmount > 0 then
            Logger.Warn("ArenaClient", `Base took {data.DamageAmount} damage! ({data.CurrentHealth}/{data.MaxHealth})`)
        end
    end)

    -- Game over event
    Network.GameOver.On(function(data)
        Logger.Info("ArenaClient", `Game over: {if data.Victory then "Victory" else "Defeat"} at wave {data.WaveReached}`)
    end)

    -- Game end rewards event (detailed summary with animations)
    Network.GameEndRewards.SetCallback(function(data)
        Logger.Info("ArenaClient", `GameEndRewards: {if data.Victory then "Victory" else "Defeat"}`)
        Logger.Info("ArenaClient", `  Coins: {data.CoinsEarned}, XP: {data.XPEarned}, Gems: {data.GemsEarned}`)
        
        -- Fire signal for VictoryDefeatScreen to react
        GameSignals.OnBattleEnded:Fire({
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
    end)

    -- Wave completed event
    Network.WaveCompleted.On(function(data)
        Logger.Info("ArenaClient", `Wave {data.WaveNumber} completed!`)
        intermissionStartTime = tick()
        
        -- Initialize intermission timer in HUD
        hud:SetIntermissionTime(intermissionDuration)
        
        -- Fire signal for HUD intermission
        GameSignals.OnWaveCompleted:Fire({
            WaveNumber = data.WaveNumber,
            IntermissionDuration = intermissionDuration,
        })
    end)

    -- Teleport countdown event
    Network.TeleportCountdown.On(function(data)
        Logger.Info("ArenaClient", `Teleporting in {data.TimeRemaining}s`)
        
        -- Fire signal for HUD and VictoryScreen to react
        GameSignals.OnTeleportCountdown:Fire({
            TimeRemaining = data.TimeRemaining,
        })
    end)

    -- Request response
    Network.RequestResponse.On(function(data)
        if not data.Success and data.ErrorCode then
            Logger.Debug("ArenaClient", `Request {data.RequestId} failed: error {data.ErrorCode}`)
        end
    end)
    
    -- Note: MapConfigSync and Map loading listeners are in setupEarlyNetworkListeners
end

-- ============================================
-- COUNTDOWN LOOP (runs after UI is ready)
-- ============================================

local function startCountdownLoop()
    _clientTrove:Connect(RunService.RenderStepped, function()
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
                hud:SetPreparationTime(0)
            end
        else
            preparationStartTime = 0
        end
        
        -- Intermission countdown
        if intermissionTime > 0 then
            -- Initialize start time if not set (late join or missed event)
            if intermissionStartTime == 0 then
                intermissionStartTime = tick()
            end
            
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
end

-- ============================================
-- PERFORMANCE MONITORING
-- ============================================

local function startPerformanceMonitor()
    local frameCount = 0
    local lastMonitorTime = tick()
    
    _clientTrove:Connect(RunService.RenderStepped, function()
        frameCount = frameCount + 1
        
        local now = tick()
        if now - lastMonitorTime >= 30 then
            local avgFPS = frameCount / (now - lastMonitorTime)
            
            Logger.Performance("ArenaClient", "Performance stats", {
                FPS = math.floor(avgFPS),
                MemoryMB = math.floor(collectgarbage("count") / 1024),
            })
            
            frameCount = 0
            lastMonitorTime = now
        end
    end)
end

-- ============================================
-- LOADER STEPS
-- ============================================

-- Step 1: Load Modules
loader:AddStep("Modules", function()
    Network = require(Shared.network.generated.client)
    
    -- Setup early network listeners BEFORE ECS init (for MapConfigSync)
    setupEarlyNetworkListeners()
    
    local Modules = script:WaitForChild("modules")
    PlayerDataClient = require(Modules:WaitForChild("PlayerDataClient"))
    
    local Controllers = script:WaitForChild("controllers")
    HUDController = require(Controllers:WaitForChild("HUDController"))
    PlantTooltipController = require(Controllers:WaitForChild("PlantTooltipController"))
    
    local UI = script:WaitForChild("ui")
    FloatingTextUI = require(UI:WaitForChild("FloatingTextUI"))
    VictoryDefeatScreen = require(UI:WaitForChild("VictoryDefeatScreen"))
    
    Logger.Info("ArenaClient", "Modules loaded")
end, 1)

-- Step 2: Setup ECS
loader:AddStep("ECS", function()
    local Systems = script:WaitForChild("systems")
    
    -- The server is authoritative for map config.
    Logger.Info("ArenaClient", "MapConfig will be synced from server")
    
    -- Create client Matter World
    world = Matter.World.new()
    loop = Matter.Loop.new(world)
    
    Logger.Info("ArenaClient", "Matter World created")
    
    -- Load all client systems recursively
    for _, descendant in Systems:GetDescendants() do
        if descendant:IsA("ModuleScript") then
            local success, system = ErrorHandler.Try(function()
                return require(descendant)
            end, `LoadSystem.{descendant.Name}`)
            
            if success and system then
                SystemManager.Register(system, descendant.Name)
                Logger.Debug("ArenaClient", `Registered system: {descendant.Name}`)
            end
        end
    end
    
    Logger.Info("ArenaClient", `Registered {#SystemManager.GetMatterSystems()} client systems`)
    
    -- Initialize ALL systems BEFORE Matter loop starts (CAN yield here)
    SystemManager.InitializeAll(world)
    Logger.Info("ArenaClient", "All systems initialized")
    
    -- Schedule and start the loop (systems CANNOT yield after this)
    loop:scheduleSystems(SystemManager.GetMatterSystems())
    loop:begin({
        default = RunService.RenderStepped,
    })
    
    Logger.Info("ArenaClient", `ECS loop started at {NetworkConfig.TICK_RATE} Hz`)
end, 2)

-- Step 3: Initialize PlayerDataClient
loader:AddStep("Network", function()
    -- Initialize PlayerDataClient (network listeners setup in UI step after HUD is ready)
    PlayerDataClient.Initialize()
    Logger.Info("ArenaClient", "PlayerDataClient initialized")
end, 1)

-- Step 4: Mount UI
loader:AddStep("UI", function()
    -- Initialize floating text system
    FloatingTextUI.Initialize()
    Logger.Info("ArenaClient", "FloatingTextUI initialized")
    
    -- Create and mount HUD
    hud = HUDController.new()
    hud:Mount()
    
    -- Initialize plant tooltip system (click on plants to see info)
    PlantTooltipController.Initialize()
    Logger.Info("ArenaClient", "PlantTooltipController initialized")
    
    -- Create and mount Victory/Defeat screen
    victoryScreen = VictoryDefeatScreen.new()
    victoryScreen:Mount()
    
    -- Setup network listeners AFTER UI is ready
    setupNetworkListeners()
    
    -- Connect coin gains to signal (HUD listens to OnCoinGained)
    PlayerDataClient.OnCoinGained(function(event)
        GameSignals.OnCoinGained:Fire({
            Amount = event.Amount,
            PositionX = event.PositionX,
            PositionZ = event.PositionZ,
        })
    end)
    
    -- Start countdown loop
    startCountdownLoop()
    
    -- Start performance monitoring
    startPerformanceMonitor()
    
    Logger.Info("ArenaClient", "HUD and VictoryScreen mounted")
end, 1)

-- Step 5: Map Sync Ready
loader:AddStep("MapSync", function()
    -- Map sync is now event-driven via MapConfigSync listener
    -- GridVisualizationSystem listens for MapConfigSync and creates grid when received
    -- No polling needed - just mark step complete
    local status = if MapConfig.IsInitialized() then "synced" else "waiting for server"
    Logger.Info("ArenaClient", `Map sync ready ({status})`)
end, 0.5)

-- Step 6: Ready
loader:AddStep("Ready", function()
    Logger.Info("ArenaClient", "Arena client fully initialized")
end, 0.5)

-- ============================================
-- RUN LOADER
-- ============================================

Logger.Info("ArenaClient", `Initializing client for {LocalPlayer.Name}`)
loader:Run()
