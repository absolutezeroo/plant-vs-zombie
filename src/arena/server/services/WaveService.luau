--!strict
--[[
	WaveService.luau - Wave management service (stateful)
	
	Extracted from WaveManagerSystem to separate:
	- Service: API + State management (this file)
	- System: ECS loop for spawning (WaveManagerSystem)
	
	This service provides the public API that other systems call.
	It does NOT run an ECS loop - that's WaveManagerSystem's job.
	
	Uses handlers for pure logic:
	- GameEndHandler: Reward calculations
	- MultiplayerScalingHandler: Multiplayer scaling
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConstants = require(Shared.config.GameConstants)

-- Data modules
local WorldData = require(Shared.data.WorldData)
local DifficultyData = require(Shared.data.DifficultyData)

-- Shared handlers (pure logic)
local GameEndHandler = require(Shared.handlers.game.GameEndHandler)
local MultiplayerScalingHandler = require(Shared.handlers.game.MultiplayerScalingHandler)

-- Server modules
local Server = script.Parent.Parent
local GameStateManager = require(Server.managers.wave.GameStateManager)
local WaveSpawner = require(Server.managers.wave.WaveSpawner)
local RewardCalculator = require(Server.managers.wave.RewardCalculator)
local WaveBroadcaster = require(Server.managers.wave.WaveBroadcaster)
local BaseHealth = require(Server.modules.BaseHealth)
local SunService = require(Server.services.SunService)

-- Types
type GameState = GameStateManager.GameState
type SpawnPhase = WaveSpawner.SpawnPhase

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local CONFIG = table.freeze({
	IS_STUDIO_DEBUG = RunService:IsStudio(),
})

--------------------------------------------------------------------------------
-- STATE (mutable service state)
--------------------------------------------------------------------------------
local State = {
	-- Wave tracking
	CurrentWave = 0,
	TotalWaves = 10,
	WaveStartTime = 0,
	LastSpawnTime = 0,
	ZombiesSpawnedThisWave = 0,

	-- Phase tracking (budget-based)
	CurrentPhase = "Trickle" :: SpawnPhase,
	PhaseSpent = 0,
	PhaseBudget = 0,
	TotalBudget = 0,
	UsingDefinedWave = false,

	-- World + Difficulty config
	CurrentWorldId = "day",
	CurrentDifficulty = "normal",
	CurrentWorldConfig = nil :: WorldData.WorldConfig?,
	CurrentDifficultyConfig = nil :: DifficultyData.DifficultyConfig?,
	AutoStartEnabled = false,

	-- Manager instances (lazy-loaded)
	StateManager = nil :: GameStateManager.GameStateManager?,
	Spawner = nil :: WaveSpawner.WaveSpawner?,
	RewardCalc = nil :: RewardCalculator.RewardCalculator?,
	Broadcaster = nil :: WaveBroadcaster.WaveBroadcaster?,

	-- Lazy-loaded dependencies
	PlayerDataService = nil :: any,
	StatsService = nil :: any,
	ArenaService = nil :: any,
	PlantFoodService = nil :: any,
}

--------------------------------------------------------------------------------
-- LAZY LOADERS
--------------------------------------------------------------------------------
local function getPlayerDataService()
	if not State.PlayerDataService then
		State.PlayerDataService = require(Server.services.PlayerDataService)
	end
	return State.PlayerDataService
end

local function getStatsService()
	if not State.StatsService then
		State.StatsService = require(Server.services.StatsService)
	end
	return State.StatsService
end

local function getArenaService()
	if not State.ArenaService then
		-- Break cyclic dependency by using runtime path instead of relative require
		local ServerScriptService = game:GetService("ServerScriptService")
		local ServerFolder = ServerScriptService:FindFirstChild("Server")
		if ServerFolder then
			local services = ServerFolder:FindFirstChild("services")
			if services then
				local arenaServiceModule = services:FindFirstChild("ArenaService")
				if arenaServiceModule then
					State.ArenaService = require(arenaServiceModule)
				end
			end
		end
	end
	return State.ArenaService
end

local function getPlantFoodService()
	if not State.PlantFoodService then
		State.PlantFoodService = require(script.Parent.PlantFoodService)
	end
	return State.PlantFoodService
end

--------------------------------------------------------------------------------
-- MANAGER INITIALIZATION
--------------------------------------------------------------------------------
local function ensureManagers()
	if not State.StateManager then
		State.StateManager = GameStateManager.GetInstance()
		State.Spawner = WaveSpawner.GetInstance()
		State.RewardCalc = RewardCalculator.GetInstance()
		State.Broadcaster = WaveBroadcaster.GetInstance()
	end
end

-- Helper to get non-nil managers (asserts they exist)
local function getStateManager(): GameStateManager.GameStateManager
	ensureManagers()
	assert(State.StateManager, "StateManager not initialized")
	return State.StateManager
end

local function getSpawnerManager(): WaveSpawner.WaveSpawner
	ensureManagers()
	assert(State.Spawner, "Spawner not initialized")
	return State.Spawner
end

local function getRewardCalc(): RewardCalculator.RewardCalculator
	ensureManagers()
	assert(State.RewardCalc, "RewardCalc not initialized")
	return State.RewardCalc
end

local function getBroadcaster(): WaveBroadcaster.WaveBroadcaster
	ensureManagers()
	assert(State.Broadcaster, "Broadcaster not initialized")
	return State.Broadcaster
end

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------
local function handleGameEnd(isVictory: boolean)
	local PlayerDataService = getPlayerDataService()
	local StatsService = getStatsService()
	local ArenaService = getArenaService()
	local rewardCalc = getRewardCalc()
	local broadcaster = getBroadcaster()

	local starRating = if isVictory then BaseHealth.GetStarRating() else 0

	-- Build game end input for handler
	local gameEndInput: GameEndHandler.GameEndInput = {
		IsVictory = isVictory,
		StarRating = starRating,
		CurrentWave = State.CurrentWave,
		TotalWaves = State.TotalWaves,
		SessionStats = { ZombiesKilled = 0, CoinsEarned = 0, PlantsPlaced = 0 },
		DifficultyConfig = State.CurrentDifficultyConfig :: GameEndHandler.DifficultyConfig?,
		WorldConfig = State.CurrentWorldConfig :: GameEndHandler.WorldConfig?,
	}

	-- Process rewards for each player
	for _, player in Players:GetPlayers() do
		local sessionStats = StatsService.GetSessionStats(player)
		gameEndInput.SessionStats = {
			ZombiesKilled = sessionStats.ZombiesKilled,
			CoinsEarned = sessionStats.CoinsEarned,
			PlantsPlaced = sessionStats.PlantsPlaced or 0,
		}

		-- Use RewardCalculator for detailed calculation
		local baseCoins, baseXP = GameEndHandler.GetBaseRewards(gameEndInput.DifficultyConfig)
		local waveMultiplier = GameEndHandler.CalculateWaveMultiplier(State.CurrentWave, State.TotalWaves)

		local rewardCalcResult = rewardCalc:CalculateRewards({
			IsVictory = isVictory,
			WaveReached = State.CurrentWave,
			SessionStats = gameEndInput.SessionStats,
			DifficultyConfig = State.CurrentDifficultyConfig,
			WorldConfig = State.CurrentWorldConfig,
			StarRating = starRating,
			BaseCoins = baseCoins,
			BaseXP = baseXP,
			WaveMultiplier = waveMultiplier,
			IsFirstClear = false,
			IsNewBest = false,
		})

		-- Calculate final rewards via handler
		local rewards = GameEndHandler.CalculatePlayerRewards(gameEndInput, rewardCalcResult)

		-- Award rewards via PlayerDataService
		if isVictory then
			PlayerDataService.AddCoins(player, rewards.CoinsEarned)
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

		-- Build and broadcast payload via handler
		local payload = GameEndHandler.BuildBroadcastPayload(gameEndInput, rewards, newLevel, levelsGained)
		broadcaster:BroadcastGameEndRewards(player, payload)
	end

	-- Teleport countdown
	task.spawn(function()
		for countdown = 5, 1, -1 do
			broadcaster:BroadcastTeleportCountdown(countdown)
			task.wait(1)
		end

		-- Teleport all players
		for _, player in Players:GetPlayers() do
			ArenaService.EndBattle(player, isVictory, starRating, 0, 0)
		end
	end)

	-- Reset session stats
	StatsService.ResetAllSessionStats()

	-- Broadcast game over
	broadcaster:BroadcastGameOver(isVictory, State.CurrentWave)
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------
local WaveService = {}

function WaveService.SetAutoStart(enabled: boolean)
	State.AutoStartEnabled = enabled
end

function WaveService.GetAutoStartEnabled(): boolean
	return State.AutoStartEnabled
end

function WaveService.GetGameState(): GameState
	return getStateManager():GetState()
end

function WaveService.GetCurrentWave(): number
	return State.CurrentWave
end

function WaveService.GetTotalWaves(): number
	return State.TotalWaves
end

function WaveService.IsPlaying(): boolean
	return getStateManager():IsPlaying()
end

function WaveService.IsGameOver(): boolean
	return getStateManager():IsGameOver()
end

function WaveService.CanStartGame(): boolean
	return getStateManager():CanStartGame()
end

function WaveService.SetGameState(state: GameState)
	local success = getStateManager():SetState(state)
	if success and (state == "Victory" or state == "Defeat") then
		handleGameEnd(state == "Victory")
	end
end

function WaveService.StartGame(worldId: string?, difficulty: string?): boolean
	local stateManager = getStateManager()
	local spawner = getSpawnerManager()
	local broadcaster = getBroadcaster()

	local WaveConfig = GameConstants.Wave

	-- If no worldId/difficulty provided, use defaults (for testing)
	if not worldId or not difficulty then
		if not stateManager:CanStartGame() then
			return false
		end
		State.CurrentWave = 0
		stateManager:SetState("Playing")
		State.WaveStartTime = os.clock() + WaveConfig.FIRST_WAVE_DELAY
		return true
	end

	if not stateManager:CanStartGame() then
		return false
	end

	-- Load World config
	local worldConfig = WorldData.GetWorld(worldId)
	if not worldConfig then
		return false
	end

	-- Load Difficulty config
	local difficultyConfig = DifficultyData.GetDifficulty(difficulty)
	if not difficultyConfig then
		return false
	end

	-- Configure game session
	State.CurrentWorldId = worldId
	State.CurrentDifficulty = difficulty
	State.CurrentWorldConfig = worldConfig
	State.CurrentDifficultyConfig = difficultyConfig
	State.TotalWaves = difficultyConfig.WaveCount or 10

	-- Build spawner config via MultiplayerScalingHandler
	local playerCount = math.max(1, #Players:GetPlayers())
	local spawnerConfig = MultiplayerScalingHandler.BuildSpawnerConfig(
		worldConfig :: MultiplayerScalingHandler.WorldConfig,
		difficultyConfig :: MultiplayerScalingHandler.DifficultyConfig,
		playerCount
	)

	spawner:SetWorldConfig(spawnerConfig)

	-- Start preparation phase
	State.CurrentWave = 0
	stateManager:SetState("Preparation")
	State.WaveStartTime = os.clock() + WaveConfig.FIRST_WAVE_DELAY

	-- Initialize all players with starting sun from WorldData
	local startingSun = worldConfig.SunStarting or 50
	for _, player in Players:GetPlayers() do
		SunService.SetSun(player, startingSun)
		SunService.BroadcastSunUpdate(player)
	end

	broadcaster:BroadcastGameStarted(worldId, difficulty, worldConfig.Name, difficultyConfig.Name, State.TotalWaves)
	broadcaster:BroadcastWaveStarted(0, 0)

	return true
end

function WaveService.StartWaves(): boolean
	local stateManager = getStateManager()
	if stateManager:GetState() ~= "Preparation" then
		return false
	end

	stateManager:SetState("Playing")
	State.WaveStartTime = os.clock()
	return true
end

function WaveService.OnZombieDied()
	-- Called by EntityDeathSystem (hook for future use)
end

-- World + Difficulty getters
function WaveService.GetCurrentWorldId(): string
	return State.CurrentWorldId
end

function WaveService.GetCurrentDifficulty(): string
	return State.CurrentDifficulty
end

function WaveService.GetCurrentWorldConfig(): WorldData.WorldConfig?
	return State.CurrentWorldConfig
end

function WaveService.GetCurrentDifficultyConfig(): DifficultyData.DifficultyConfig?
	return State.CurrentDifficultyConfig
end

function WaveService.IsDay(): boolean
	local worldConfig = State.CurrentWorldConfig
	if worldConfig and worldConfig.Mechanics then
		-- Check if IsDay is defined in Mechanics (may be boolean or nil)
		local mechanics = worldConfig.Mechanics :: any
		if mechanics.IsDay ~= nil then
			return mechanics.IsDay == true
		end
	end
	return true -- Default to day
end

function WaveService.ResetGameState()
	local stateManager = getStateManager()
	stateManager:Reset()

	State.CurrentWave = 0
	State.WaveStartTime = 0
	State.LastSpawnTime = 0
	State.CurrentPhase = "Trickle"
	State.PhaseSpent = 0
	State.PhaseBudget = 0
	State.TotalBudget = 0
	State.ZombiesSpawnedThisWave = 0
	State.TotalWaves = 0
	State.CurrentWorldId = ""
	State.CurrentDifficulty = ""
	State.CurrentWorldConfig = nil
	State.CurrentDifficultyConfig = nil
	State.UsingDefinedWave = false

	-- Reset base health for new game
	BaseHealth.Reset()
end

--------------------------------------------------------------------------------
-- STATE ACCESSORS (for WaveManagerSystem)
--------------------------------------------------------------------------------
function WaveService.GetState()
	return State
end

function WaveService.GetSpawner(): WaveSpawner.WaveSpawner?
	ensureManagers()
	return State.Spawner
end

function WaveService.GetBroadcaster(): WaveBroadcaster.WaveBroadcaster?
	ensureManagers()
	return State.Broadcaster
end

function WaveService.GetPlantFoodService()
	return getPlantFoodService()
end

function WaveService.IsStudioDebug(): boolean
	return CONFIG.IS_STUDIO_DEBUG
end

return WaveService
