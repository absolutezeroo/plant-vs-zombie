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
    
    NEW SYSTEM (v2):
    - Uses WorldData + DifficultyData instead of StageData
    - World = map, mechanics, zombie pool
    - Difficulty = wave count, budget, multipliers
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local _Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local Logger = require(Shared.utils.Logger)

-- NEW: Data-driven world and difficulty
local WorldData = require(Shared.data.WorldData)
local DifficultyData = require(Shared.data.DifficultyData)

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

-- Stage config type (mirrors StageData.StageConfig for local use)
type StageConfig = {
    Id: string,
    Name: string,
    Description: string?,
    World: number,
    Level: number,
    MapId: string?,
    Waves: any?,
    TotalWaves: number,
    BaseBudget: number,
    BudgetScale: number,
    DefaultZombiePool: {string}?,
    SunGeneration: number?,
    StartingSun: number?,
    Rewards: any?,
    Stars: any?,
    UnlockRequirement: any?,
}

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

-- NEW: World + Difficulty instead of StageId
local _currentWorldId = "day"
local _currentDifficulty = "normal"
local _currentWorldConfig: WorldData.WorldConfig? = nil
local _currentDifficultyConfig: DifficultyData.DifficultyConfig? = nil
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

-- Track if current wave uses defined spawns
local _usingDefinedWave = false

-- Start a new wave
local function startWave(waveNumber: number, world: any?)
    _currentWave = waveNumber
    _zombiesSpawnedThisWave = 0
    _lastSpawnTime = os.clock()
    _waveStartTime = os.clock()
    
    -- Reset Plant Food tracking
    local PlantFoodSystemAPI = getPlantFoodSystem().API
    PlantFoodSystemAPI.ResetWaveTracking()
    
    -- Check if this wave has precise spawn definitions
    if _spawner:HasDefinedWave(waveNumber) then
        _usingDefinedWave = true
        local waveDef = _spawner:GetWaveDefinition(waveNumber)
        
        -- Apply pre-delay if specified
        local preDelay = waveDef and waveDef.PreDelay or 0
        if preDelay > 0 then
            task.delay(preDelay, function()
                if world then
                    _spawner:SpawnDefinedWave(world, waveNumber)
                end
            end)
        elseif world then
            _spawner:SpawnDefinedWave(world, waveNumber)
        end
        
        Logger.Info("WaveManager", `=== WAVE {waveNumber} START === (Defined spawns)`)
    else
        -- Fallback to budget-based system
        _usingDefinedWave = false
        _totalBudget = _spawner:CalculateBudget(waveNumber)
        _currentPhase = "Trickle"
        _phaseSpent = 0
        _phaseBudget = _spawner:GetPhaseBudget(_totalBudget, "Trickle")
        
        Logger.Info("WaveManager", `=== WAVE {waveNumber} START === Budget: {math.floor(_totalBudget)}`)
    end
    
    _broadcaster:BroadcastWaveStarted(waveNumber, 0)
end

-- Handle end game (victory/defeat)
local function handleGameEnd(isVictory: boolean)
    local PlayerDataService = getPlayerDataService()
    local EntityDeathSystem = getEntityDeathSystem()
    local ArenaService = getArenaService()
    
    local starRating = if isVictory then BaseHealth.GetStarRating() else 0
    local difficultyConfig = _currentDifficultyConfig
    
    -- Process rewards for each player
    for _, player in Players:GetPlayers() do
        local sessionStats = EntityDeathSystem.API.GetSessionStats(player)
        
        -- Calculate base rewards from difficulty config
        local baseCoins = if difficultyConfig then difficultyConfig.CoinReward else 100
        local baseXP = if difficultyConfig then difficultyConfig.XPReward else 50
        local waveMultiplier = _currentWave / (if _totalWaves > 0 then _totalWaves else 1)
        
        -- Calculate rewards
        local rewards = _rewardCalc:CalculateRewards({
            IsVictory = isVictory,
            WaveReached = _currentWave,
            SessionStats = {
                ZombiesKilled = sessionStats.ZombiesKilled,
                CoinsEarned = sessionStats.CoinsEarned,
                PlantsPlaced = sessionStats.PlantsPlaced or 0,
            },
            DifficultyConfig = difficultyConfig,
            WorldConfig = _currentWorldConfig,
            StarRating = starRating,
            BaseCoins = baseCoins,
            BaseXP = baseXP,
            WaveMultiplier = waveMultiplier,
            IsFirstClear = false,  -- No longer tracking per-stage completion
            IsNewBest = false,
        })
        
        -- Award rewards
        if isVictory then
            PlayerDataService.AddCoins(player, rewards.TotalCoins or (baseCoins * waveMultiplier))
        end
        
        local levelsGained = PlayerDataService.AddXP(player, rewards.XPEarned or baseXP)
        local newLevel = PlayerDataService.GetLevel(player)
        
        if rewards.GemsEarned and rewards.GemsEarned > 0 then
            PlayerDataService.AddGems(player, rewards.GemsEarned)
        end
        
        -- Update stats
        PlayerDataService.IncrementStat(player, "GamesPlayed", 1)
        if isVictory then
            PlayerDataService.IncrementStat(player, "GamesWon", 1)
        end
        
        -- Broadcast to client (World + Difficulty based)
        _broadcaster:BroadcastGameEndRewards(player, {
            WorldId = _currentWorldId,
            Difficulty = _currentDifficulty,
            Victory = isVictory,
            Stars = starRating,
            CoinsEarned = rewards.TotalCoins or baseCoins,
            XPEarned = rewards.XPEarned or baseXP,
            ZombiesKilled = sessionStats.ZombiesKilled,
            WavesCompleted = _currentWave,
            TotalWaves = _totalWaves,
            BonusCoins = rewards.BonusCoins or 0,
            StarRating = starRating,
            NewLevel = newLevel,
            LevelsGained = levelsGained,
        })
        
        Logger.Info("WaveManager", `{player.Name}: +{rewards.XPEarned or baseXP} XP, World={_currentWorldId}, Difficulty={_currentDifficulty}`)
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

function WaveManager.StartGame(worldId: string?, difficulty: string?): boolean
    -- If no worldId/difficulty provided, use defaults (for testing)
    if not worldId or not difficulty then
        if not _stateManager:CanStartGame() then
            return false
        end
        _currentWave = 0
        _stateManager:SetState("Playing")
        _waveStartTime = os.clock() + WaveConfig.FIRST_WAVE_DELAY
        Logger.Info("WaveManager", `Game started (default)! First wave in {WaveConfig.FIRST_WAVE_DELAY}s`)
        return true
    end
    
    if not _stateManager:CanStartGame() then
        Logger.Warn("WaveManager", `Cannot start game - already in progress`)
        return false
    end
    
    -- Load World config
    local worldConfig = WorldData.GetWorld(worldId)
    if not worldConfig then
        Logger.Error("WaveManager", `Invalid world ID: {worldId}`)
        return false
    end
    
    -- Load Difficulty config
    local difficultyConfig = DifficultyData.GetDifficulty(difficulty)
    if not difficultyConfig then
        Logger.Error("WaveManager", `Invalid difficulty: {difficulty}`)
        return false
    end
    
    -- Configure game session
    _currentWorldId = worldId
    _currentDifficulty = difficulty
    _currentWorldConfig = worldConfig
    _currentDifficultyConfig = difficultyConfig
    
    -- Determine wave count from difficulty
    _totalWaves = difficultyConfig.WaveCount or 10
    
    -- Build merged config for spawner (combine world + difficulty)
    local spawnerConfig = {
        -- From World
        Name = worldConfig.Name,
        MapId = worldConfig.MapId,
        ZombiePool = worldConfig.ZombiePool,
        Mechanics = worldConfig.Mechanics,
        -- From Difficulty (use existing field names)
        BaseZombieHP = difficultyConfig.ZombieHealthMult or 1.0,
        BaseBudgetMultiplier = difficultyConfig.ZombieDamageMult or 1.0, -- Use damage as budget proxy
        SpawnInterval = difficultyConfig.SpawnInterval or 2.5,
        TotalWaves = _totalWaves,
    }
    
    _spawner:SetWorldConfig(spawnerConfig)
    
    -- Update timing from difficulty
    local spawnInterval = spawnerConfig.SpawnInterval
    WaveConfig.TRICKLE_INTERVAL = spawnInterval + 1.5
    WaveConfig.ASSAULT_INTERVAL = spawnInterval
    WaveConfig.FLAG_INTERVAL = math.max(0.5, spawnInterval - 0.5)
    
    -- Start preparation phase
    _currentWave = 0
    _stateManager:SetState("Preparation")
    _waveStartTime = os.clock() + WaveConfig.FIRST_WAVE_DELAY
    
    Logger.Info("WaveManager", `=== {worldConfig.Name} | {difficultyConfig.Name} ({_totalWaves} waves) ===`)
    
    _broadcaster:BroadcastGameStarted(worldId, difficulty, worldConfig.Name, difficultyConfig.Name, _totalWaves)
    _broadcaster:BroadcastWaveStarted(0, 0)
    
    return true
end

-- Legacy function for compatibility
function WaveManager.StartStage(stageId: string): boolean
    -- Parse legacy format "world-difficulty" if needed
    local worldId, difficulty = stageId:match("^(%w+)%-(%w+)$")
    if worldId and difficulty then
        return WaveManager.StartGame(worldId, difficulty)
    end
    -- Default fallback
    return WaveManager.StartGame("day", "normal")
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

-- Legacy getter (deprecated)
function WaveManager.GetCurrentStageId(): string
    return `{_currentWorldId}-{_currentDifficulty}`
end

-- New getters for World + Difficulty system
function WaveManager.GetCurrentWorldId(): string
    return _currentWorldId
end

function WaveManager.GetCurrentDifficulty(): string
    return _currentDifficulty
end

function WaveManager.GetCurrentWorldConfig(): WorldData.WorldConfig?
    return _currentWorldConfig
end

function WaveManager.GetCurrentDifficultyConfig(): DifficultyData.DifficultyConfig?
    return _currentDifficultyConfig
end

function WaveManager.GetTotalWaves(): number
    return _totalWaves
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
    _totalWaves = 0
    _currentWorldId = ""
    _currentDifficulty = ""
    _currentWorldConfig = nil
    _currentDifficultyConfig = nil
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
    local state: string = _stateManager:GetState()
    
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
    if state :: string == "Preparation" then
        local remaining = math.ceil(_waveStartTime - currentTime)
        if remaining > 0 then
            -- Broadcast preparation time periodically
            if math.floor(currentTime) ~= math.floor(currentTime - 0.016) then
                _broadcaster:BroadcastPreparationTime(remaining)
            end
        else
            -- Start first wave
            _stateManager:SetState("Playing")
            startWave(1, world)
        end
        return
    end
    
    -- Intermission between waves
    if state :: string == "Intermission" then
        if currentTime - _waveStartTime >= WaveConfig.WAVE_DELAY then
            _stateManager:SetState("Playing")
            startWave(_currentWave + 1, world)
        end
        return
    end
    
    -- Wait for first wave
    if _currentWave == 0 then
        if currentTime >= _waveStartTime then
            startWave(1, world)
        end
        return
    end
    
    -- Check wave completion
    -- For defined waves: just check if all zombies are dead
    -- For budget waves: check if all phases are spent
    local waveComplete = false
    local activeZombies = 0
    local queryResult: any = world:query(ZombieTypeComponent)
    if queryResult then
        for _ in queryResult do
            activeZombies += 1
        end
    end
    
    if _usingDefinedWave then
        -- For defined waves, wave is complete when spawning is done and all zombies dead
        -- We consider spawning "done" after 15 seconds max or when all zombies spawned are dead
        local timeSinceWaveStart = currentTime - _waveStartTime
        if activeZombies == 0 and timeSinceWaveStart > 3 then
            waveComplete = true
        end
    else
        -- For budget waves, check phase completion
        local allSpawned = _phaseSpent >= _phaseBudget and _currentPhase == "Flag"
        if allSpawned and activeZombies == 0 then
            waveComplete = true
        end
    end
    
    if waveComplete then
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
    
    -- Budget-based spawning (only for non-defined waves)
    if not _usingDefinedWave then
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
end

return {
    system = WaveManagerSystem,
    priority = 100,
    WaveManager = WaveManager,
}
