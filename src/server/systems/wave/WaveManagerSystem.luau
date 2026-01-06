--!strict
--[[
	WaveManagerSystem.luau - Server-side wave management
	
	Priority: 100 (Simulation phase - early)
	
	Manages zombie waves with budget-based spawning.
	Formula: Budget = 50 × 1.6^Wave
	
	Wave structure:
	- Trickle phase (20% budget): Slow spawns at start
	- Assault phase (50% budget): Main wave push
	- Flag phase (30% budget): Final push with stronger zombies
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local ZombieData = require(Shared.data.ZombieData)
local ProgressionData = require(Shared.data.ProgressionData)
local Logger = require(Shared.utils.Logger)

-- Network (script.Parent.Parent.Parent = server root, since we're in systems/wave/)
local Server = script.Parent.Parent.Parent
local Network = require(Server.network.generated)
local BaseHealth = require(Server.modules.BaseHealth)

-- Lazy-load to avoid circular deps
local _playerDataService: any = nil
local function getPlayerDataService()
	if not _playerDataService then
		_playerDataService = require(Server.services.PlayerDataService)
	end
	return _playerDataService
end

-- Lazy-load EntityDeathSystem for session stats
local _entityDeathSystem: any = nil
local function getEntityDeathSystem()
	if not _entityDeathSystem then
		-- EntityDeathSystem is in systems/units/
		local Systems = script.Parent.Parent
		_entityDeathSystem = require(Systems.units.EntityDeathSystem)
	end
	return _entityDeathSystem
end

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local MovementComponent = Components.MovementComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local PlantFoodComponent = Components.PlantFoodComponent

-- Lazy-load PlantFoodSystem for glowing zombie checks
local _plantFoodSystem: any = nil
local function getPlantFoodSystem()
	if not _plantFoodSystem then
		local Systems = script.Parent.Parent
		_plantFoodSystem = require(Systems.combat.PlantFoodSystem)
	end
	return _plantFoodSystem
end

-- Wave configuration
local WaveConfig = {
	TOTAL_WAVES = 10,         -- Total waves to complete for victory
	BASE_BUDGET = 50,         -- Base budget multiplier
	BUDGET_EXPONENT = 1.6,    -- Budget growth rate
	WAVE_DELAY = 30,          -- Seconds between waves
	FIRST_WAVE_DELAY = 20,    -- Delay before first wave starts
	SPAWN_X_OFFSET = 10,      -- Studs beyond grid edge
	
	-- Spawn timing per phase
	TRICKLE_INTERVAL = 4,     -- Seconds between spawns (slow)
	ASSAULT_INTERVAL = 2,     -- Seconds between spawns (fast)
	FLAG_INTERVAL = 1.5,      -- Seconds between spawns (fastest)
	
	-- Phase distribution
	TRICKLE_RATIO = 0.2,      -- 20% of budget
	ASSAULT_RATIO = 0.5,      -- 50% of budget
	FLAG_RATIO = 0.3,         -- 30% of budget
}

-- Default spawn cost fallback (if ZombieData doesn't specify)
local DEFAULT_SPAWN_COST = 10

-- Get zombie spawn cost from ZombieData (data-driven)
local function getZombieCost(zombieType: string): number
	local stats = ZombieData[zombieType]
	if stats and stats.SpawnCost then
		return stats.SpawnCost
	end
	Logger.Warn("WaveManager", `Zombie type {zombieType} missing SpawnCost, using default`)
	return DEFAULT_SPAWN_COST
end

-- Spawn pool per phase (weighted)
local SpawnPools = {
	Trickle = {"Basic", "Basic", "Basic", "Cone", "Imp"},
	Assault = {"Basic", "Basic", "Cone", "Cone", "Bucket", "Imp", "Imp"},
	Flag = {"Cone", "Cone", "Bucket", "Bucket", "Pole", "Imp"},
}

-- Game state
export type GameState = "Waiting" | "Playing" | "Intermission" | "Victory" | "Defeat"

local _gameState: GameState = "Waiting"
local _currentWave = 0
local _waveStartTime = 0
local _lastSpawnTime = 0
local _currentPhase: "Trickle" | "Assault" | "Flag" = "Trickle"
local _phaseSpent = 0
local _phaseBudget = 0
local _totalBudget = 0
local _zombiesKilledThisWave = 0
local _zombiesSpawnedThisWave = 0
local _spawnQueue: {{type: string, lane: number}} = {}

-- Module API for other systems to query state
local WaveManager = {}

function WaveManager.GetGameState(): GameState
	return _gameState
end

function WaveManager.GetCurrentWave(): number
	return _currentWave
end

function WaveManager.IsPlaying(): boolean
	return _gameState == "Playing" or _gameState == "Intermission"
end

function WaveManager.SetGameState(state: GameState)
	_gameState = state
	Logger.Info("WaveManager", `Game state changed to: {state}`)
	
	-- Handle end game rewards
	if state == "Victory" or state == "Defeat" then
		local isVictory = state == "Victory"
		local bonusCoins = if isVictory then _currentWave * ProgressionData.VICTORY_BONUS_PER_WAVE else 0
		
		-- Award bonus and send end game summary to each player
		local PlayerDataService = getPlayerDataService()
		local EntityDeathSystem = getEntityDeathSystem()
		
		-- Get star rating from BaseHealth module
		local starRating = if isVictory then BaseHealth.GetStarRating() else 0
		
		for _, player in Players:GetPlayers() do
			-- Get session stats
			local sessionStats = EntityDeathSystem.API.GetSessionStats(player)
			
			-- Award victory bonus coins
			if bonusCoins > 0 then
				PlayerDataService.AddCoins(player, bonusCoins)
			end
			
			-- Calculate XP earned
			local xpEarned = 0
			xpEarned += sessionStats.ZombiesKilled * ProgressionData.XP_PER_ZOMBIE
			xpEarned += _currentWave * ProgressionData.XP_PER_WAVE
			if isVictory then
				xpEarned += ProgressionData.XP_VICTORY_BONUS
				xpEarned += starRating * ProgressionData.XP_PER_STAR
			end
			
			-- Award XP and get levels gained
			local levelsGained = PlayerDataService.AddXP(player, xpEarned)
			local newLevel = PlayerDataService.GetLevel(player)
			
			-- Award gems for 3-star victory
			local gemsEarned = 0
			if isVictory and starRating == 3 then
				gemsEarned = ProgressionData.GEMS_VICTORY_3_STAR
				PlayerDataService.AddGems(player, gemsEarned)
			end
			
			-- Increment games played/won
			PlayerDataService.IncrementStat(player, "GamesPlayed", 1)
			if isVictory then
				PlayerDataService.IncrementStat(player, "GamesWon", 1)
			end
			
			-- Send detailed end game summary
			Network.GameEndRewards.Fire(player, {
				Victory = isVictory,
				CoinsEarned = sessionStats.CoinsEarned + bonusCoins,
				ZombiesKilled = sessionStats.ZombiesKilled,
				WavesCompleted = _currentWave,
				BonusCoins = bonusCoins,
				StarRating = starRating,
				XPEarned = xpEarned,
				GemsEarned = gemsEarned,
				NewLevel = newLevel,
				LevelsGained = levelsGained,
			})
			
			Logger.Info("WaveManager", `{player.Name}: +{xpEarned} XP, +{gemsEarned} gems, {levelsGained} level(s) gained`)
		end
		
		-- Reset session stats for next game
		EntityDeathSystem.API.ResetAllSessionStats()
		
		-- Send GameOver event
		Network.GameOver.FireAll({
			Victory = isVictory,
			WaveReached = _currentWave,
		})
		
		return
	end
	
	-- Broadcast wave state to clients
	local phaseEnum = ({
		Waiting = "Pregame",
		Playing = "Wave",
		Intermission = "Intermission",
		Victory = "GameOver",
		Defeat = "GameOver",
	})[state] or "Pregame"
	
	Network.WaveStarted.FireAll({
		WaveNumber = _currentWave,
		ZombieCount = 0, -- Will be updated as zombies spawn
	})
end

function WaveManager.StartGame()
	if _gameState ~= "Waiting" then
		return
	end
	
	_currentWave = 0
	_gameState = "Playing"
	_waveStartTime = os.clock() + WaveConfig.FIRST_WAVE_DELAY
	
	Logger.Info("WaveManager", `Game started! First wave in {WaveConfig.FIRST_WAVE_DELAY}s`)
end

function WaveManager.OnZombieDied()
	_zombiesKilledThisWave += 1
end

-- Calculate wave budget
local function calculateBudget(wave: number): number
	return WaveConfig.BASE_BUDGET * math.pow(WaveConfig.BUDGET_EXPONENT, wave)
end

-- Get spawn position for lane
local function getSpawnPosition(lane: number): Vector3
	local x = GridConfig.GRID_WIDTH + WaveConfig.SPAWN_X_OFFSET + GridConfig.GRID_ORIGIN_X
	local y = 0
	local z = (lane - 1) * GridConfig.CELL_SIZE + GridConfig.CELL_SIZE / 2 + GridConfig.GRID_ORIGIN_Z
	return Vector3.new(x, y, z)
end

-- Spawn a single zombie
local function spawnZombie(world: any, zombieType: string, lane: number): number
	local stats = ZombieData[zombieType]
	if not stats then
		Logger.Error("WaveManager", `Invalid zombie type: {zombieType}`)
		return -1
	end
	
	local spawnPos = getSpawnPosition(lane)
	
	local entityId = world:spawn(
		PositionComponent({
			X = spawnPos.X,
			Y = spawnPos.Y,
			Z = spawnPos.Z
		}),
		HealthComponent({
			Current = stats.Health,
			Max = stats.Health
		}),
		MovementComponent({
			VelocityX = -stats.Speed,
			VelocityY = 0,
			VelocityZ = 0
		}),
		ZombieTypeComponent({
			ZombieType = zombieType,
			Lane = lane,
			SpawnTime = os.clock()
		})
	)
	
	-- Check if this zombie should be a Plant Food carrier (glowing)
	local PlantFoodSystemAPI = getPlantFoodSystem().API
	if PlantFoodSystemAPI.ShouldZombieBeGlowing() then
		world:insert(entityId, PlantFoodComponent({
			IsGlowing = true,
		}))
		Logger.Info("WaveManager", `[Wave {_currentWave}] 🌟 GLOWING {zombieType} in lane {lane}`)
	end
	
	-- Broadcast to clients
	Network.ZombieSpawned.FireAll({
		EntityId = entityId,
		ZombieType = zombieType :: any,
		Lane = lane :: any,
		PositionX = spawnPos.X,
	})
	
	_zombiesSpawnedThisWave += 1
	
	Logger.Debug("WaveManager", `[Wave {_currentWave}] Spawned {zombieType} in lane {lane} (total: {_zombiesSpawnedThisWave})`)
	
	return entityId
end

-- Pick random zombie from pool
local function pickZombie(pool: {string}, budget: number): string?
	-- Filter pool by what we can afford (data-driven costs)
	local affordable = {}
	for _, zType in pool do
		if getZombieCost(zType) <= budget then
			table.insert(affordable, zType)
		end
	end
	
	if #affordable == 0 then
		return nil
	end
	
	return affordable[math.random(1, #affordable)]
end

-- Start a new wave
local function startWave(waveNumber: number)
	_currentWave = waveNumber
	_totalBudget = calculateBudget(waveNumber)
	_currentPhase = "Trickle"
	_phaseSpent = 0
	_phaseBudget = _totalBudget * WaveConfig.TRICKLE_RATIO
	_zombiesKilledThisWave = 0
	_zombiesSpawnedThisWave = 0
	_spawnQueue = {}
	_lastSpawnTime = os.clock()
	_waveStartTime = os.clock()
	
	-- Reset Plant Food glowing tracking for this wave
	local PlantFoodSystemAPI = getPlantFoodSystem().API
	PlantFoodSystemAPI.ResetWaveTracking()
	
	Logger.Info("WaveManager", `=== WAVE {waveNumber} START === Budget: {math.floor(_totalBudget)}`)
	
	-- Broadcast wave start
	Network.WaveStarted.FireAll({
		WaveNumber = waveNumber,
		ZombieCount = 0, -- Will increase as zombies spawn
	})
end

-- Advance to next phase
local function advancePhase(world: any)
	if _currentPhase == "Trickle" then
		_currentPhase = "Assault"
		_phaseSpent = 0
		_phaseBudget = _totalBudget * WaveConfig.ASSAULT_RATIO
		Logger.Debug("WaveManager", `Phase: Assault (budget: {math.floor(_phaseBudget)})`)
	elseif _currentPhase == "Assault" then
		_currentPhase = "Flag"
		_phaseSpent = 0
		_phaseBudget = _totalBudget * WaveConfig.FLAG_RATIO
		Logger.Debug("WaveManager", `Phase: Flag (budget: {math.floor(_phaseBudget)})`)
		
		-- Spawn a Flag zombie to announce the final wave
		local lane = math.random(1, GridConfig.GRID_LANES)
		spawnZombie(world, "Flag", lane)
		Logger.Info("WaveManager", "🚩 Flag zombie spawned!")
	end
end

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

-- Main system
local function WaveManagerSystem(world)
	local currentTime = os.clock()
	
	-- Auto-start game when first player joins (for testing)
	if _gameState == "Waiting" then
		if #Players:GetPlayers() > 0 then
			WaveManager.StartGame()
		end
		return
	end
	
	-- Victory/Defeat states pause the system
	if _gameState == "Victory" or _gameState == "Defeat" then
		return
	end
	
	-- Check for defeat (base destroyed)
	if BaseHealth.IsDefeated() and _gameState ~= "Defeat" then
		WaveManager.SetGameState("Defeat")
		Logger.Info("WaveManager", "💀 DEFEAT - Base destroyed!")
		return
	end
	
	-- Intermission between waves
	if _gameState == "Intermission" then
		if currentTime - _waveStartTime >= WaveConfig.WAVE_DELAY then
			-- Start next wave
			_gameState = "Playing"
			startWave(_currentWave + 1)
		end
		return
	end
	
	-- Wait for initial delay
	if _currentWave == 0 then
		if currentTime >= _waveStartTime then
			startWave(1)
		end
		return
	end
	
	-- Check if wave is complete (all zombies spawned and killed)
	local allSpawned = _phaseSpent >= _phaseBudget and _currentPhase == "Flag"
	local activeZombies = 0
	for _ in world:query(ZombieTypeComponent) do
		activeZombies += 1
	end
	
	if allSpawned and activeZombies == 0 then
		-- Wave complete!
		Logger.Info("WaveManager", `=== WAVE {_currentWave} COMPLETE ===`)
		
		-- Broadcast wave end
		Network.WaveCompleted.FireAll({
			WaveNumber = _currentWave,
			Survived = true,
		})
		
		-- Check for victory
		if _currentWave >= WaveConfig.TOTAL_WAVES then
			WaveManager.SetGameState("Victory")
			Logger.Info("WaveManager", "🏆 VICTORY! All waves completed!")
			return
		end
		
		-- Start intermission
		_gameState = "Intermission"
		_waveStartTime = currentTime
		Logger.Info("WaveManager", `Next wave in {WaveConfig.WAVE_DELAY}s`)
		return
	end
	
	-- Spawn zombies based on current phase
	if currentTime - _lastSpawnTime >= getSpawnInterval() then
		-- Check if phase is done
		if _phaseSpent >= _phaseBudget then
			if _currentPhase ~= "Flag" then
				advancePhase(world)
			end
			return
		end
		
		-- Pick a zombie to spawn
		local pool = SpawnPools[_currentPhase]
		local remainingBudget = _phaseBudget - _phaseSpent
		local zombieType = pickZombie(pool, remainingBudget)
		
		if zombieType then
			local lane = math.random(1, GridConfig.GRID_LANES)
			spawnZombie(world, zombieType, lane)
			_phaseSpent += getZombieCost(zombieType)
			_lastSpawnTime = currentTime
		else
			-- Can't afford anything, phase done
			_phaseSpent = _phaseBudget
		end
	end
end

-- Export WaveManager API alongside system
return {
	system = WaveManagerSystem,
	priority = 100,
	WaveManager = WaveManager,
}
