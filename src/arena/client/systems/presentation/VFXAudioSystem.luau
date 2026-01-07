--!strict
--[[
	VFXAudioSystem.luau - Client system for VFX initialization and music management
	
	Priority: 350 (after render systems)
	
	This system:
	- Initializes VFX and Audio services
	- Manages dynamic music based on game state
	- Wave music transitions (calm -> wave -> intense)
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
local ClientNetwork = Client:FindFirstChild("network")
assert(ClientNetwork, "VFXAudioSystem: network folder not found")
local Network = require(ClientNetwork.generated)

-- Game state for music
local _isWaveActive = false
local _currentWave = 0
local _initialized = false

local function VFXAudioSystem(world)
	-- Initialize services once (on first frame)
	if not _initialized then
		_initialized = true
		
		VFXService.Initialize()
		AudioService.Initialize()
		
		-- Start with calm music
		AudioService.SetMusic("calm")
		
		-- Connect to wave events for music changes
		Network.WaveStarted.On(function(data)
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
		end)
		
		Network.WaveCompleted.On(function(data)
			_isWaveActive = false
			-- Return to calm music between waves
			AudioService.SetMusic("calm")
			Logger.Debug("VFXAudio", `Wave completed - music: calm`)
		end)
		
		Network.GameOver.On(function(data)
			-- Stop music and play end sound
			AudioService.StopMusic()
			if data.Victory then
				AudioService.PlayVictory()
			else
				AudioService.PlayDefeat()
			end
		end)
		
		-- Explosion VFX event
		Network.ExplosionVFX.On(function(data)
			local pos = Vector3.new(data.PositionX, data.PositionY, data.PositionZ)
			VFXService.PlayExplosion(pos, data.Radius)
			AudioService.PlayExplosion(pos)
			VFXService.ScreenShake(0.8, 0.3)
			Logger.Debug("VFXAudio", `Explosion at {pos}`)
		end)
		
		Logger.Info("VFXAudioSystem", "Initialized VFX and Audio services")
	end
	
	-- No per-frame updates needed
	-- All effects are triggered via events in render systems
end

return {
	system = VFXAudioSystem,
	priority = 350,
}
