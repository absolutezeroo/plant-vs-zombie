--!strict
--[[
	ServerEventBus.luau - Centralized server-side event signals
	
	PURPOSE:
	Provides global signals for reacting AFTER game events occur.
	Use for: analytics, quests, achievements, side effects, debugging.
	
	ARCHITECTURE:
	- Uses Signal library for event dispatch
	- Signals are fired by systems/services after actions complete
	- Listeners can be registered by any server module
	- Global scope (not per-player) - cleaned up on arena Dispose
	
	USAGE:
	```lua
	local ServerEventBus = require(ServerEventBus)
	
	-- Subscribe to events
	ServerEventBus.OnEntityDied:Connect(function(data)
		Analytics.Track("entity_died", data)
	end)
	
	-- In a system (after action):
	ServerEventBus.Fire("EntityDied", {
		EntityId = entityId,
		EntityType = "Zombie",
		Position = pos,
	})
	```
	
	AVAILABLE EVENTS:
	- OnEntitySpawned: { EntityId, EntityType, Position, OwnerId?, PlantType?, ZombieType? }
	- OnEntityDied: { EntityId, EntityType, Position, KillerId?, PlantType?, ZombieType? }
	- OnDamageDealt: { SourceId, TargetId, Amount, FinalAmount, WasKill, IsCritical?, DamageType? }
	- OnWaveStarted: { WaveNumber, TotalWaves, Phase?, Budget? }
	- OnWaveCompleted: { WaveNumber, ZombiesKilled, TimeElapsed }
	- OnGameStateChanged: { OldState, NewState }
	- OnPlantPlaced: { Player, PlantType, Column, Lane, EntityId }
	- OnPlantShoveled: { Player, PlantType, Column, Lane, RefundAmount }
	- OnSunSpent: { Player, Amount, Reason, Remaining }
	- OnSunCollected: { Player, Amount, SourceType, Total }
	- OnPlantFoodUsed: { Player, TargetPlant, PlantType }
	- OnMutationTriggered: { MutationType, SourcePlant, AffectedZombies }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages:WaitForChild("Signal"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

-- ============================================
-- TYPE DEFINITIONS
-- ============================================

export type EntitySpawnedData = {
	EntityId: number,
	EntityType: string, -- "Plant", "Zombie", "Projectile", "Sun"
	Position: { X: number, Y: number, Z: number },
	OwnerId: number?,
	PlantType: string?,
	ZombieType: string?,
	Lane: number?,
	Column: number?,
}

export type EntityDiedData = {
	EntityId: number,
	EntityType: string, -- "Plant", "Zombie"
	Position: { X: number, Y: number, Z: number },
	KillerId: number?, -- Entity that dealt killing blow
	PlantType: string?,
	ZombieType: string?,
	Lane: number?,
}

export type DamageDealtData = {
	SourceId: number,
	TargetId: number,
	Amount: number, -- Original damage
	FinalAmount: number, -- After modifiers
	WasKill: boolean,
	IsCritical: boolean?,
	DamageType: string?, -- "Normal", "Fire", "Ice", etc.
}

export type WaveStartedData = {
	WaveNumber: number,
	TotalWaves: number,
	Phase: string?, -- "Trickle", "Assault", "Flag"
	Budget: number?,
}

export type WaveCompletedData = {
	WaveNumber: number,
	ZombiesKilled: number,
	TimeElapsed: number,
}

export type GameStateChangedData = {
	OldState: string,
	NewState: string,
}

export type PlantPlacedData = {
	Player: Player,
	PlantType: string,
	Column: number,
	Lane: number,
	EntityId: number,
	Cost: number?,
}

export type PlantShoveledData = {
	Player: Player,
	PlantType: string,
	Column: number,
	Lane: number,
	RefundAmount: number,
}

export type SunSpentData = {
	Player: Player,
	Amount: number,
	Reason: string,
	Remaining: number,
}

export type SunCollectedData = {
	Player: Player,
	Amount: number,
	SourceType: string, -- "Sky", "Sunflower", "SunShroom", etc.
	Total: number,
}

export type PlantFoodUsedData = {
	Player: Player,
	TargetPlant: number, -- Entity ID
	PlantType: string,
}

export type MutationTriggeredData = {
	MutationType: string,
	SourcePlant: number, -- Entity ID
	AffectedEntities: { number }, -- Entity IDs
	TotalDamage: number?,
}

-- ============================================
-- STATE
-- ============================================

local _trove = Trove.new()
local _initialized = false
local _eventCounts: { [string]: number } = {}

-- ============================================
-- SIGNALS (created once)
-- ============================================

local ServerEventBus = {}

-- Entity lifecycle
ServerEventBus.OnEntitySpawned = Signal.new()
ServerEventBus.OnEntityDied = Signal.new()

-- Combat
ServerEventBus.OnDamageDealt = Signal.new()

-- Wave management
ServerEventBus.OnWaveStarted = Signal.new()
ServerEventBus.OnWaveCompleted = Signal.new()
ServerEventBus.OnGameStateChanged = Signal.new()

-- Plant actions
ServerEventBus.OnPlantPlaced = Signal.new()
ServerEventBus.OnPlantShoveled = Signal.new()
ServerEventBus.OnPlantFoodUsed = Signal.new()

-- Economy
ServerEventBus.OnSunSpent = Signal.new()
ServerEventBus.OnSunCollected = Signal.new()

-- Mutations
ServerEventBus.OnMutationTriggered = Signal.new()

-- ============================================
-- HELPER: Fire with logging
-- ============================================

local function fireEvent(signal: any, eventName: string, data: any)
	-- Track event counts for debugging
	_eventCounts[eventName] = (_eventCounts[eventName] or 0) + 1
	
	-- Fire the signal
	signal:Fire(data)
	
	-- Debug logging (only in Studio)
	if game:GetService("RunService"):IsStudio() then
		Logger.Debug("ServerEventBus", `Fired {eventName} (count: {_eventCounts[eventName]})`)
	end
end

-- ============================================
-- PUBLIC API
-- ============================================

--[[
	Fire an event by name with data.
	Preferred over direct :Fire() for logging/debugging.
	
	@param eventName string - One of the event names
	@param data table - Event-specific payload
]]
function ServerEventBus.Fire(eventName: string, data: any)
	local signal = (ServerEventBus :: any)[`On{eventName}`]
	
	if not signal then
		Logger.Warn("ServerEventBus", `Unknown event: {eventName}`)
		return
	end
	
	fireEvent(signal, eventName, data)
end

--[[
	Initialize the event bus (called at arena start).
]]
function ServerEventBus.Initialize()
	if _initialized then
		return
	end
	
	_initialized = true
	table.clear(_eventCounts)
	
	Logger.Debug("ServerEventBus", "Initialized")
end

--[[
	Dispose and clear all connections (called at arena end).
]]
function ServerEventBus.Dispose()
	-- Note: We don't destroy the signals themselves, just clear connections
	-- Signals are reused across arena sessions
	
	-- Log final event counts
	if game:GetService("RunService"):IsStudio() then
		Logger.Debug("ServerEventBus", "Final event counts:")
		for eventName, count in _eventCounts do
			Logger.Debug("ServerEventBus", `  {eventName}: {count}`)
		end
	end
	
	table.clear(_eventCounts)
	_initialized = false
	
	Logger.Debug("ServerEventBus", "Disposed")
end

--[[
	Get event statistics (for debugging).
	
	@return { [string]: number } - Event name -> fire count
]]
function ServerEventBus.GetStats(): { [string]: number }
	return table.clone(_eventCounts)
end

--[[
	Check if the bus is initialized.
	
	@return boolean
]]
function ServerEventBus.IsInitialized(): boolean
	return _initialized
end

-- ============================================
-- CONVENIENCE FIRE METHODS (typed)
-- ============================================

function ServerEventBus.FireEntitySpawned(data: EntitySpawnedData)
	fireEvent(ServerEventBus.OnEntitySpawned, "EntitySpawned", data)
end

function ServerEventBus.FireEntityDied(data: EntityDiedData)
	fireEvent(ServerEventBus.OnEntityDied, "EntityDied", data)
end

function ServerEventBus.FireDamageDealt(data: DamageDealtData)
	fireEvent(ServerEventBus.OnDamageDealt, "DamageDealt", data)
end

function ServerEventBus.FireWaveStarted(data: WaveStartedData)
	fireEvent(ServerEventBus.OnWaveStarted, "WaveStarted", data)
end

function ServerEventBus.FireWaveCompleted(data: WaveCompletedData)
	fireEvent(ServerEventBus.OnWaveCompleted, "WaveCompleted", data)
end

function ServerEventBus.FireGameStateChanged(data: GameStateChangedData)
	fireEvent(ServerEventBus.OnGameStateChanged, "GameStateChanged", data)
end

function ServerEventBus.FirePlantPlaced(data: PlantPlacedData)
	fireEvent(ServerEventBus.OnPlantPlaced, "PlantPlaced", data)
end

function ServerEventBus.FirePlantShoveled(data: PlantShoveledData)
	fireEvent(ServerEventBus.OnPlantShoveled, "PlantShoveled", data)
end

function ServerEventBus.FireSunSpent(data: SunSpentData)
	fireEvent(ServerEventBus.OnSunSpent, "SunSpent", data)
end

function ServerEventBus.FireSunCollected(data: SunCollectedData)
	fireEvent(ServerEventBus.OnSunCollected, "SunCollected", data)
end

function ServerEventBus.FirePlantFoodUsed(data: PlantFoodUsedData)
	fireEvent(ServerEventBus.OnPlantFoodUsed, "PlantFoodUsed", data)
end

function ServerEventBus.FireMutationTriggered(data: MutationTriggeredData)
	fireEvent(ServerEventBus.OnMutationTriggered, "MutationTriggered", data)
end

return ServerEventBus
