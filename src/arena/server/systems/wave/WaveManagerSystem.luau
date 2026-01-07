--!strict
--[[
    WaveManagerSystem.luau - Wave management orchestrator
    
    Priority: 100 (Simulation phase - early)
    
    This is a thin orchestrator that delegates to:
    - GameStateManager: State transitions
    - WaveSpawner: Zombie spawning logic
    - RewardCalculator: End-game rewards
    - WaveBroadcaster: Network events
    
    Wave structure:
    - Preparation phase: Initial setup time
    - Trickle phase (20% budget): Slow spawns
    - Assault phase (50% budget): Main wave
    - Flag phase (30% budget): Final push
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local StageData = require(Shared.data.StageData)
local Logger = require(Shared.utils.Logger)

-- Managers
local Server = script.Parent.Parent.Parent
local GameStateManager = require(Server.managers.wave.GameStateManager)
local WaveSpawner = require(Server.managers.wave.WaveSpawner)
local RewardCalculator = require(Server.managers.wave.RewardCalculator)
local WaveBroadcaster = require(Server.managers.wave.WaveBroadcaster)
local BaseHealth = require(Server.modules.BaseHealth)

-- Components
local ZombieTypeComponent = Components.ZombieTypeComponent

-- Types
type GameState = GameStateManager.GameState
type SpawnPhase = WaveSpawner.SpawnPhase

-- Wave timing configuration
local WaveConfig = {
    FIRST_WAVE_DELAY = 20,    -- Preparation time
    WAVE_DELAY = 10,          -- Intermission between waves
    TRICKLE_INTERVAL = 4,
    ASSAULT_INTERVAL = 2,
    FLAG_INTERVAL = 1.5,
}

-- Wave state
local _currentWave = 0
local _totalWaves = 10
local _waveStartTime = 0
local _lastSpawnTime = 0
local _currentPhase: SpawnPhase = "Trickle"
local _phaseSpent = 0
local _phaseBudget = 0
local _totalBudget = 0
local _zombiesSpawnedThisWave = 0
local _currentStageId = "1-1"
local _currentStageConfig: StageData.StageConfig? = nil
local _autoStartEnabled = false

-- Manager instances
local _stateManager: GameStateManager.GameStateManager
local _spawner: WaveSpawner.WaveSpawner
local _rewardCalc: RewardCalculator.RewardCalculator
local _broadcaster: WaveBroadcaster.WaveBroadcaster

-- Lazy-load dependencies
local _playerDataService: any = nil
local function getPlayerDataService()
    if not _playerDataService then
        _playerDataService = require(Server.services.PlayerDataService)
    end
    return _playerDataService
end

local _entityDeathSystem: any = nil
local function getEntityDeathSystem()
    if not _entityDeathSystem then
        local Systems = script.Parent.Parent
        _entityDeathSystem = require(Systems.units.EntityDeathSystem)
    end
    return _entityDeathSystem
end

local _arenaService: any = nil
local function getArenaService()
    if not _arenaService then
        _arenaService = require(Server.services.ArenaService)
    end
    return _arenaService
end

local _plantFoodSystem: any = nil
local function getPlantFoodSystem()
    if not _plantFoodSystem then
        local Systems = script.Parent.Parent
        _plantFoodSystem = require(Systems.combat.PlantFoodSystem)
    end
    return _plantFoodSystem
end

--[[ ============================================
    PRIVATE: Wave logic helpers
============================================ ]]--

-- Get spawn interval for current phase
local function getSpawnInterval(): number
    if _currentPhase == "Trickle" then
        return WaveConfig.TRICKLE_INTERVAL
    elseif _currentPhase == "Assault" then
        return WaveConfig.ASSAULT_INTERVAL
    else
        return WaveConfig.FLAG_INTERVAL
    end
end

-- Advance to next phase
local function advancePhase(world: any)
    if _currentPhase == "Trickle" then
        _currentPhase = "Assault"
        _phaseSpent = 0
        _phaseBudget = _spawner:GetPhaseBudget(_totalBudget, "Assault")
        Logger.Debug("WaveManager", `Phase: Assault (budget: {math.floor(_phaseBudget)})`)
    elseif _currentPhase == "Assault" then
        _currentPhase = "Flag"
        _phaseSpent = 0
        _phaseBudget = _spawner:GetPhaseBudget(_totalBudget, "Flag")
        Logger.Debug("WaveManager", `Phase: Flag (budget: {math.floor(_phaseBudget)})`)
        
        -- Spawn Flag zombie
        local lane = math.random(1, GridConfig.GRID_LANES)
        _spawner:SpawnZombie(world, "Flag", lane, _currentWave)
        Logger.Info("WaveManager", "🚩 Flag zombie spawned!")
    end
end

-- Start a new wave
local function startWave(waveNumber: number)
    _currentWave = waveNumber
    _totalBudget = _spawner:CalculateBudget(waveNumber)
    _currentPhase = "Trickle"
    _phaseSpent = 0
    _phaseBudget = _spawner:GetPhaseBudget(_totalBudget, "Trickle")
    _zombiesSpawnedThisWave = 0
    _lastSpawnTime = os.clock()
    _waveStartTime = os.clock()
    
    -- Reset Plant Food tracking
    local PlantFoodSystemAPI = getPlantFoodSystem().API
    PlantFoodSystemAPI.ResetWaveTracking()
    
    Logger.Info("WaveManager", `=== WAVE {waveNumber} START === Budget: {math.floor(_totalBudget)}`)
    
    _broadcaster:BroadcastWaveStarted(waveNumber, 0)
end

-- Handle end game (victory/defeat)
local function handleGameEnd(isVictory: boolean)
    local PlayerDataService = getPlayerDataService()
    local EntityDeathSystem = getEntityDeathSystem()
    local ArenaService = getArenaService()
    
    local starRating = if isVictory then BaseHealth.GetStarRating() else 0
    
    -- Process rewards for each player
    for _, player in Players:GetPlayers() do
        local sessionStats = EntityDeathSystem.API.GetSessionStats(player)
        
        -- Check first clear
        local previousStars = PlayerDataService.GetStageStars(player, _currentStageId)
        local isFirstClear, isNewBest = false, false
        
        if isVictory then
            isFirstClear, isNewBest = PlayerDataService.CompleteStage(player, _currentStageId, starRating)
        end
        
        -- Calculate rewards
        local rewards = _rewardCalc:CalculateRewards({
            IsVictory = isVictory,
            WaveReached = _currentWave,
            SessionStats = {
                ZombiesKilled = sessionStats.ZombiesKilled,
                CoinsEarned = sessionStats.CoinsEarned,
                PlantsPlaced = sessionStats.PlantsPlaced or 0,
            },
            StageConfig = _currentStageConfig,
            StarRating = starRating,
            IsFirstClear = isFirstClear,
            IsNewBest = isNewBest,
        })
        
        -- Award rewards
        if isVictory then
            PlayerDataService.AddCoins(player, rewards.StageCoins + rewards.FirstClearBonus + rewards.BonusCoins)
        end
        
        local levelsGained = PlayerDataService.AddXP(player, rewards.XPEarned)
        local newLevel = PlayerDataService.GetLevel(player)
        
        if rewards.GemsEarned > 0 then
            PlayerDataService.AddGems(player, rewards.GemsEarned)
        end
        
        -- Update stats
        PlayerDataService.IncrementStat(player, "GamesPlayed", 1)
        if isVictory then
            PlayerDataService.IncrementStat(player, "GamesWon", 1)
        end
        
        -- Broadcast to client
        _broadcaster:BroadcastStageComplete(player, {
            StageId = _currentStageId,
            Victory = isVictory,
            Stars = starRating,
            CoinsEarned = rewards.TotalCoins,
            XPEarned = rewards.XPEarned,
            IsFirstClear = isFirstClear,
            IsNewBest = isNewBest,
            PreviousStars = previousStars,
        })
        
        _broadcaster:BroadcastGameEndRewards(player, {
            Victory = isVictory,
            CoinsEarned = rewards.TotalCoins,
            ZombiesKilled = sessionStats.ZombiesKilled,
            WavesCompleted = _currentWave,
            BonusCoins = rewards.BonusCoins,
            StarRating = starRating,
            XPEarned = rewards.XPEarned,
            GemsEarned = rewards.GemsEarned,
            NewLevel = newLevel,
            LevelsGained = levelsGained,
        })
        
        Logger.Info("WaveManager", `{player.Name}: +{rewards.XPEarned} XP, +{rewards.GemsEarned} gems`)
    end
    
    -- Teleport countdown
    task.spawn(function()
        for countdown = 5, 1, -1 do
            _broadcaster:BroadcastTeleportCountdown(countdown)
            task.wait(1)
        end
        
        -- Teleport all players
        for _, player in Players:GetPlayers() do
            ArenaService.EndBattle(player, isVictory, starRating, 0, 0)
        end
    end)
    
    -- Reset session stats
    EntityDeathSystem.API.ResetAllSessionStats()
    
    -- Broadcast game over
    _broadcaster:BroadcastGameOver(isVictory, _currentWave)
end

--[[ ============================================
    PUBLIC: WaveManager API
============================================ ]]--

local WaveManager = {}

function WaveManager.SetAutoStart(enabled: boolean)
    _autoStartEnabled = enabled
    Logger.Info("WaveManager", `Auto-start {if enabled then "enabled" else "disabled"}`)
end

function WaveManager.GetGameState(): GameState
    return _stateManager:GetState()
end

function WaveManager.GetCurrentWave(): number
    return _currentWave
end

function WaveManager.IsPlaying(): boolean
    return _stateManager:IsPlaying()
end

function WaveManager.SetGameState(state: GameState)
    local success = _stateManager:SetState(state)
    if success and (state == "Victory" or state == "Defeat") then
        handleGameEnd(state == "Victory")
    end
end

function WaveManager.StartGame()
    if not _stateManager:CanStartGame() then
        return false
    end
    
    _currentWave = 0
    _stateManager:SetState("Playing")
    _waveStartTime = os.clock() + WaveConfig.FIRST_WAVE_DELAY
    
    Logger.Info("WaveManager", `Game started! First wave in {WaveConfig.FIRST_WAVE_DELAY}s`)
    return true
end

function WaveManager.StartStage(stageId: string): boolean
    if not _stateManager:CanStartGame() then
        Logger.Warn("WaveManager", `Cannot start stage - game in progress`)
        return false
    end
    
    local stageConfig = StageData.GetStage(stageId)
    if not stageConfig then
        Logger.Error("WaveManager", `Invalid stage ID: {stageId}`)
        return false
    end
    
    -- Configure stage
    _currentStageId = stageId
    _currentStageConfig = stageConfig
    _totalWaves = stageConfig.WaveCount
    _spawner:SetStageConfig(stageConfig)
    
    -- Update timing from stage
    local spawnInterval = stageConfig.SpawnInterval or 2.5
    WaveConfig.TRICKLE_INTERVAL = spawnInterval + 1.5
    WaveConfig.ASSAULT_INTERVAL = spawnInterval
    WaveConfig.FLAG_INTERVAL = spawnInterval - 0.5
    
    -- Start preparation
    _currentWave = 0
    _stateManager:SetState("Preparation")
    _waveStartTime = os.clock() + WaveConfig.FIRST_WAVE_DELAY
    
    Logger.Info("WaveManager", `=== STAGE {stageId}: {stageConfig.Name} ===`)
    
    _broadcaster:BroadcastStageStarted(stageId, stageConfig.Name, stageConfig.WaveCount)
    _broadcaster:BroadcastWaveStarted(0, 0)
    
    return true
end

function WaveManager.StartWaves(): boolean
    if _stateManager:GetState() ~= "Preparation" then
        return false
    end
    
    _stateManager:SetState("Playing")
    _waveStartTime = os.clock()
    Logger.Info("WaveManager", "Preparation skipped - starting waves!")
    return true
end

function WaveManager.OnZombieDied()
    -- Called by EntityDeathSystem
end

function WaveManager.GetCurrentStageId(): string
    return _currentStageId
end

function WaveManager.ResetGameState()
    _stateManager:Reset()
    _currentWave = 0
    _waveStartTime = 0
    _lastSpawnTime = 0
    _currentPhase = "Trickle"
    _phaseSpent = 0
    _phaseBudget = 0
    _totalBudget = 0
    _zombiesSpawnedThisWave = 0
    Logger.Info("WaveManager", "Game state reset")
end

--[[ ============================================
    SYSTEM: Matter system function
============================================ ]]--

local function WaveManagerSystem(world)
    -- Initialize managers on first run
    if not _stateManager then
        _stateManager = GameStateManager.GetInstance()
        _spawner = WaveSpawner.GetInstance()
        _rewardCalc = RewardCalculator.GetInstance()
        _broadcaster = WaveBroadcaster.GetInstance()
    end
    
    local currentTime = os.clock()
    local state = _stateManager:GetState()
    
    -- Auto-start when players join (testing only)
    if state == "Waiting" and _autoStartEnabled then
        if #Players:GetPlayers() > 0 then
            WaveManager.StartGame()
        end
        return
    end
    
    -- Game over states stop processing
    if _stateManager:IsGameOver() then
        return
    end
    
    -- Check defeat condition
    if BaseHealth.IsDefeated() and state ~= "Defeat" then
        WaveManager.SetGameState("Defeat")
        Logger.Info("WaveManager", "💀 DEFEAT - Base destroyed!")
        return
    end
    
    -- Preparation phase countdown
    if state == "Preparation" then
        local remaining = math.ceil(_waveStartTime - currentTime)
        if remaining > 0 then
            -- Broadcast preparation time periodically
            if math.floor(currentTime) ~= math.floor(currentTime - 0.016) then
                _broadcaster:BroadcastPreparationTime(remaining)
            end
        else
            -- Start first wave
            _stateManager:SetState("Playing")
            startWave(1)
        end
        return
    end
    
    -- Intermission between waves
    if state == "Intermission" then
        if currentTime - _waveStartTime >= WaveConfig.WAVE_DELAY then
            _stateManager:SetState("Playing")
            startWave(_currentWave + 1)
        end
        return
    end
    
    -- Wait for first wave
    if _currentWave == 0 then
        if currentTime >= _waveStartTime then
            startWave(1)
        end
        return
    end
    
    -- Check wave completion
    local allSpawned = _phaseSpent >= _phaseBudget and _currentPhase == "Flag"
    local activeZombies = 0
    for _ in world:query(ZombieTypeComponent) do
        activeZombies += 1
    end
    
    if allSpawned and activeZombies == 0 then
        Logger.Info("WaveManager", `=== WAVE {_currentWave} COMPLETE ===`)
        
        _broadcaster:BroadcastWaveCompleted(_currentWave, true)
        
        -- Check victory
        if _currentWave >= _totalWaves then
            WaveManager.SetGameState("Victory")
            Logger.Info("WaveManager", "🏆 VICTORY! All waves completed!")
            return
        end
        
        -- Start intermission
        _stateManager:SetState("Intermission")
        _waveStartTime = currentTime
        Logger.Info("WaveManager", `Next wave in {WaveConfig.WAVE_DELAY}s`)
        return
    end
    
    -- Spawn zombies
    if currentTime - _lastSpawnTime >= getSpawnInterval() then
        if _phaseSpent >= _phaseBudget then
            if _currentPhase ~= "Flag" then
                advancePhase(world)
            end
            return
        end
        
        local remainingBudget = _phaseBudget - _phaseSpent
        local zombieType = _spawner:PickZombie(_currentPhase, remainingBudget)
        
        if zombieType then
            local lane = math.random(1, GridConfig.GRID_LANES)
            _spawner:SpawnZombie(world, zombieType, lane, _currentWave)
            _phaseSpent += _spawner:GetZombieCost(zombieType)
            _lastSpawnTime = currentTime
            _zombiesSpawnedThisWave += 1
        else
            _phaseSpent = _phaseBudget
        end
    end
end

return {
    system = WaveManagerSystem,
    priority = 100,
    WaveManager = WaveManager,
}
