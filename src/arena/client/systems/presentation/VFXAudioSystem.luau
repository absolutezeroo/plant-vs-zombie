--!strict
--[[
	VFXAudioSystem.luau - Client system for VFX initialization and music management
	
	Priority: 350 (after render systems)
	
	This system:
	- Initializes VFX and Audio services
	- Manages dynamic music based on game state
	- Wave music transitions (calm -> wave -> intense)
	
	LIFECYCLE:
	- Init(): Connect network listeners, initialize services
	- system(): No per-frame updates (event-driven)
	- Dispose(): Disconnect listeners, stop music
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Use FindFirstChild to avoid yielding (modules should exist from init.client.luau)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "VFXAudioSystem: Shared folder not found")
local Logger = require(Shared.utils.Logger)

-- Client root (script.Parent.Parent.Parent since we're in systems/presentation/)
local Client = script.Parent.Parent.Parent
local Modules = Client:FindFirstChild("modules")
assert(Modules, "VFXAudioSystem: modules folder not found")
local VFXService = require(Modules.VFXService)
local AudioService = require(Modules.AudioService)
local Network = require(Shared.network.generated.client)

-- State
local _isWaveActive = false
local _currentWave = 0

-- Connection tracking for cleanup
local _connections: {RBXScriptConnection | () -> ()} = {}

--------------------------------------------------------------------------------
-- INIT: Called once before Matter loop (CAN yield)
--------------------------------------------------------------------------------
local function Init(_world: any)
	VFXService.Initialize()
	AudioService.Initialize()
	
	-- Start with calm music
	AudioService.SetMusic("calm")
	
	-- Connect to wave events for music changes
	table.insert(_connections, Network.WaveStarted.On(function(data)
		_isWaveActive = true
		_currentWave = data.WaveNumber
		
		-- Wave 0 = preparation phase, don't play wave start sound
		if _currentWave == 0 then
			AudioService.SetMusic("calm")
			Logger.Debug("VFXAudio", "Preparation phase started - music: calm")
			return
		end
		
		-- Intense music for later waves
		if _currentWave >= 5 then
			AudioService.SetMusic("intense")
		else
			AudioService.SetMusic("wave")
		end
		
		-- Play wave start sound
		AudioService.PlayWaveStart()
		Logger.Debug("VFXAudio", `Wave {_currentWave} started - music: {if _currentWave >= 5 then "intense" else "wave"}`)
	end))
	
	table.insert(_connections, Network.WaveCompleted.On(function(_data)
		_isWaveActive = false
		-- Return to calm music between waves
		AudioService.SetMusic("calm")
		Logger.Debug("VFXAudio", `Wave completed - music: calm`)
	end))
	
	table.insert(_connections, Network.GameOver.On(function(data)
		-- Stop music and play end sound
		AudioService.StopMusic()
		if data.Victory then
			AudioService.PlayVictory()
		else
			AudioService.PlayDefeat()
		end
	end))
	
	-- Explosion VFX event
	table.insert(_connections, Network.ExplosionVFX.On(function(data)
		local pos = Vector3.new(data.PositionX, data.PositionY, data.PositionZ)
		VFXService.PlayExplosion(pos, data.Radius)
		AudioService.PlayExplosion(pos)
		VFXService.ScreenShake(0.8, 0.3)
		Logger.Debug("VFXAudio", `Explosion at {pos}`)
	end))
	
	Logger.Info("VFXAudioSystem", "Initialized VFX and Audio services")
end

--------------------------------------------------------------------------------
-- SYSTEM: Called every frame by Matter (CANNOT yield)
--------------------------------------------------------------------------------
local function VFXAudioSystem(_world: any)
	-- No per-frame updates needed
	-- All effects are triggered via network events
end

--------------------------------------------------------------------------------
-- DISPOSE: Called on cleanup (player leave, game end)
--------------------------------------------------------------------------------
local function Dispose(_player: Player?)
	if _player then
		-- Player-specific cleanup (none for this system)
		return
	end
	
	-- Full cleanup
	for _, conn in _connections do
		if typeof(conn) == "function" then
			conn() -- Zap uses unsubscribe functions
		elseif typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end
	table.clear(_connections)
	
	AudioService.StopMusic()
	_isWaveActive = false
	_currentWave = 0
	
	Logger.Debug("VFXAudioSystem", "Disposed")
end

--------------------------------------------------------------------------------
-- MODULE EXPORT
--------------------------------------------------------------------------------
return {
	_name = "VFXAudioSystem",
	priority = 350,
	system = VFXAudioSystem,
	Init = Init,
	Dispose = Dispose,
}
