--!strict
--[[
	WaveManagerSystem.luau - Wave spawning ECS loop
	
	Priority: 100 (Simulation phase - early)
	
	This is a pure ECS system that handles the wave loop.
	All state and API are in WaveService - this system only:
	- Checks state transitions (Preparation → Playing → Intermission)
	- Spawns zombies based on phase/budget
	- Fires WaveStateEvents for UI/Audio
	
	For API calls, use: require(WaveService).StartGame(), etc.
]]

--------------------------------------------------------------------------------
-- [1] IMPORTS
--------------------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GameConstants = require(Shared.config.GameConstants)
local ChanceUtils = require(Shared.utils.ChanceUtils)

-- Service (contains state + API)
local Server = script.Parent.Parent.Parent
local WaveService = require(Server.services.WaveService)
local BaseHealth = require(Server.modules.BaseHealth)

--------------------------------------------------------------------------------
-- [2] CONFIG (frozen constants)
--------------------------------------------------------------------------------
local CONFIG = table.freeze({
	-- Wave timing from GameConstants
	TRICKLE_INTERVAL = GameConstants.Wave.TRICKLE_INTERVAL,
	ASSAULT_INTERVAL = GameConstants.Wave.ASSAULT_INTERVAL,
	FLAG_INTERVAL = GameConstants.Wave.FLAG_INTERVAL,
	WAVE_DELAY = GameConstants.Wave.WAVE_DELAY,
	FIRST_WAVE_DELAY = GameConstants.Wave.FIRST_WAVE_DELAY,
	-- Wave completion timing
	MIN_WAVE_TIME_FOR_COMPLETION = 3,
})

--------------------------------------------------------------------------------
-- [3] STATE (reference to WaveService.State)
-- Note: WaveManagerSystem uses WaveService.GetState() for mutable state
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- [4] PRIVATE HELPERS
--------------------------------------------------------------------------------

-- Get spawn interval for current phase
local function getSpawnInterval(phase: string): number
	if phase == "Trickle" then
		return CONFIG.TRICKLE_INTERVAL
	elseif phase == "Assault" then
		return CONFIG.ASSAULT_INTERVAL
	else
		return CONFIG.FLAG_INTERVAL
	end
end

-- Advance to next phase
local function advancePhase(world: any, state: any, spawner: any)
	if state.CurrentPhase == "Trickle" then
		state.CurrentPhase = "Assault"
		state.PhaseSpent = 0
		state.PhaseBudget = spawner:GetPhaseBudget(state.TotalBudget, "Assault")
		
		-- Fire phase change event
		world:spawn(Components.WaveStateEvent({
			StateType = "Phase",
			WaveNumber = state.CurrentWave,
			Phase = "Assault",
		}))
	elseif state.CurrentPhase == "Assault" then
		state.CurrentPhase = "Flag"
		state.PhaseSpent = 0
		state.PhaseBudget = spawner:GetPhaseBudget(state.TotalBudget, "Flag")
		
		-- Fire phase change event
		world:spawn(Components.WaveStateEvent({
			StateType = "Phase",
			WaveNumber = state.CurrentWave,
			Phase = "Flag",
		}))
		
		-- Spawn Flag zombie
		local lane = ChanceUtils.RandomLane()
		spawner:SpawnZombie(world, "Flag", lane, state.CurrentWave)
	end
end

-- Start a new wave
local function startWave(waveNumber: number, world: any, state: any, spawner: any, broadcaster: any)
	state.CurrentWave = waveNumber
	state.ZombiesSpawnedThisWave = 0
	state.LastSpawnTime = os.clock()
	state.WaveStartTime = os.clock()
	
	-- Fire WaveStateEvent for UI/Audio systems
	world:spawn(Components.WaveStateEvent({
		StateType = "Start",
		WaveNumber = waveNumber,
		TotalWaves = state.TotalWaves,
	}))
	
	-- Reset Plant Food tracking
	local PlantFoodService = WaveService.GetPlantFoodService()
	if PlantFoodService then
		PlantFoodService.ResetWaveTracking()
	end
	
	-- Check if this wave has precise spawn definitions
	if spawner:HasDefinedWave(waveNumber) then
		state.UsingDefinedWave = true
		local waveDef = spawner:GetWaveDefinition(waveNumber)
		
		-- Apply pre-delay if specified
		local preDelay = waveDef and waveDef.PreDelay or 0
		if preDelay > 0 then
			task.delay(preDelay, function()
				spawner:SpawnDefinedWave(world, waveNumber)
			end)
		else
			spawner:SpawnDefinedWave(world, waveNumber)
		end
	else
		-- Fallback to budget-based system
		state.UsingDefinedWave = false
		state.TotalBudget = spawner:CalculateBudget(waveNumber)
		state.CurrentPhase = "Trickle"
		state.PhaseSpent = 0
		state.PhaseBudget = spawner:GetPhaseBudget(state.TotalBudget, "Trickle")
	end
	
	broadcaster:BroadcastWaveStarted(waveNumber, 0)
end

--------------------------------------------------------------------------------
-- [5] ONSTEP (main loop - CANNOT yield)
--------------------------------------------------------------------------------
local function OnStep(world)
	local state = WaveService.GetState()
	local spawner = WaveService.GetSpawner()
	local broadcaster = WaveService.GetBroadcaster()
	
	if not spawner or not broadcaster then
		return -- Managers not yet initialized
	end
	
	local currentTime = os.clock()
	local gameState = WaveService.GetGameState()
	
	-- Auto-start when players join (testing only)
	if gameState == "Waiting" and state.AutoStartEnabled then
		if #Players:GetPlayers() > 0 then
			WaveService.StartGame()
		end
		return
	end
	
	-- Game over states stop processing
	if WaveService.IsGameOver() then
		return
	end
	
	-- Check defeat condition (only during active gameplay)
	if WaveService.IsPlaying() and BaseHealth.IsDefeated() and gameState ~= "Defeat" then
		WaveService.SetGameState("Defeat")
		return
	end
	
	-- Preparation phase countdown
	if gameState == "Preparation" then
		local remaining = math.ceil(state.WaveStartTime - currentTime)
		if remaining > 0 then
			-- Broadcast preparation time periodically
			if math.floor(currentTime) ~= math.floor(currentTime - 0.016) then
				broadcaster:BroadcastPreparationTime(remaining)
			end
		else
			-- Start first wave
			WaveService.SetGameState("Playing")
			startWave(1, world, state, spawner, broadcaster)
		end
		return
	end
	
	-- Intermission between waves
	if gameState == "Intermission" then
		if currentTime - state.WaveStartTime >= CONFIG.WAVE_DELAY then
			WaveService.SetGameState("Playing")
			startWave(state.CurrentWave + 1, world, state, spawner, broadcaster)
		end
		return
	end
	
	-- Wait for first wave
	if state.CurrentWave == 0 then
		-- In Studio Debug mode, don't auto-start
		if WaveService.IsStudioDebug() and state.WaveStartTime == 0 then
			return
		end
		
		if currentTime >= state.WaveStartTime then
			startWave(1, world, state, spawner, broadcaster)
		end
		return
	end
	
	-- Check wave completion
	local waveComplete = false
	local activeZombies = 0
	for _ in world:query(Components.ZombieTypeComponent) do
		activeZombies += 1
	end
	
	if state.UsingDefinedWave then
		-- For defined waves, complete when all zombies dead after min time
		local timeSinceWaveStart = currentTime - state.WaveStartTime
		if activeZombies == 0 and timeSinceWaveStart > CONFIG.MIN_WAVE_TIME_FOR_COMPLETION then
			waveComplete = true
		end
	else
		-- For budget waves, check phase completion
		local allSpawned = state.PhaseSpent >= state.PhaseBudget and state.CurrentPhase == "Flag"
		if allSpawned and activeZombies == 0 then
			waveComplete = true
		end
	end
	
	if waveComplete then
		-- Fire WaveStateEvent End for UI/Audio systems
		world:spawn(Components.WaveStateEvent({
			StateType = "End",
			WaveNumber = state.CurrentWave,
			TotalWaves = state.TotalWaves,
		}))
		
		broadcaster:BroadcastWaveCompleted(state.CurrentWave, true)
		
		-- Check victory
		if state.CurrentWave >= state.TotalWaves then
			WaveService.SetGameState("Victory")
			return
		end
		
		-- Start intermission
		WaveService.SetGameState("Intermission")
		state.WaveStartTime = currentTime
		return
	end
	
	-- Budget-based spawning (only for non-defined waves)
	if not state.UsingDefinedWave then
		if currentTime - state.LastSpawnTime >= getSpawnInterval(state.CurrentPhase) then
			if state.PhaseSpent >= state.PhaseBudget then
				if state.CurrentPhase ~= "Flag" then
					advancePhase(world, state, spawner)
				end
				return
			end
			
			local remainingBudget = state.PhaseBudget - state.PhaseSpent
			local zombieType = spawner:PickZombie(state.CurrentPhase, remainingBudget)
			
			if zombieType then
				local lane = ChanceUtils.RandomLane()
				spawner:SpawnZombie(world, zombieType, lane, state.CurrentWave)
				state.PhaseSpent += spawner:GetZombieCost(zombieType)
				state.LastSpawnTime = currentTime
				state.ZombiesSpawnedThisWave += 1
			else
				state.PhaseSpent = state.PhaseBudget
			end
		end
	end
end

--------------------------------------------------------------------------------
-- [6] INIT / DISPOSE
--------------------------------------------------------------------------------
local function Init(_world)
	-- WaveService handles manager initialization
end

local function Dispose()
	WaveService.ResetGameState()
end

--------------------------------------------------------------------------------
-- [7] EXPORT
--------------------------------------------------------------------------------
return {
	priority = 100,
	system = OnStep,
	Init = Init,
	Dispose = Dispose,
}
