--!strict
--[[
	SoundService.luau - Client-side audio manager
	
	Handles all game sounds:
	- Plant actions (shoot, place, explode)
	- Zombie sounds (groan, death)
	- Collection sounds (sun, coin)
	- UI sounds (click, error)
	- Background music with intensity levels
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local GameSignals = require(Shared.signals.GameSignals)
local ChanceUtils = require(Shared.utils.ChanceUtils)

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

-- Sound asset IDs (using Roblox library sounds)
local SOUNDS = {
	-- Plant sounds
	PeaShoot = "rbxassetid://116561468284287", -- Pop/shoot sound
	PeaImpact = "rbxassetid://83662029103234", -- Splat
	PlantPlaced = "rbxassetid://101826567553108", -- Dirt/place
	Explosion = "rbxassetid://100749525232283", -- Boom

	-- Zombie sounds
	ZombieGroan = "rbxassetid://122508006619291", -- Groan
	ZombieDeath = "rbxassetid://", -- Death groan
	ZombieBite = "rbxassetid://99729332638497", -- Chomp

	-- Collection sounds
	SunCollect = "rbxassetid://73530939144429", -- Sparkle/chime
	CoinCollect = "rbxassetid://98363900764760", -- Coin ding

	-- UI sounds
	UIClick = "rbxassetid://", -- Click
	UIError = "rbxassetid://", -- Error buzz
	UISuccess = "rbxassetid://", -- Success chime
	CardSelect = "rbxassetid://", -- Select card

	-- Game events
	WaveStart = "rbxassetid://81385124977604", -- Alert/horn
	Victory = "rbxassetid://", -- Fanfare
	Defeat = "rbxassetid://", -- Doom

	-- Music
	MusicCalm = "rbxassetid://", -- Peaceful background
	MusicWave = "rbxassetid://", -- Tense wave music
	MusicIntense = "rbxassetid://", -- Boss/intense
}

local _soundFolder: Folder = nil
local _cachedSounds: { [string]: Sound } = {}
local _currentMusic: Sound? = nil
local _musicVolume: number = 0.3
local _sfxVolume: number = 0.5
local _trove: any = nil

local AudioService = {}

-- Initialize sound folder
function AudioService.Initialize()
	_soundFolder = Instance.new("Folder")
	_soundFolder.Name = "GameSounds"
	_soundFolder.Parent = SoundService

	-- Pre-cache frequently used sounds
	AudioService._PreloadSound("PeaShoot")
	AudioService._PreloadSound("PeaImpact")
	AudioService._PreloadSound("SunCollect")
	AudioService._PreloadSound("ZombieDeath")
	AudioService._PreloadSound("PlantPlaced")

	-- Create Trove for signal connections
	_trove = Trove.new()

	-- Connect to combat signals (observer pattern)
	_trove:Connect(GameSignals.OnZombieDeath, function(data)
		AudioService.PlayZombieDeath(data.Position)
	end)

	_trove:Connect(GameSignals.OnProjectileImpact, function(data)
		AudioService.PlayPeaImpact(data.Position)
	end)

	_trove:Connect(GameSignals.OnSunCollected, function(data)
		AudioService.PlaySunCollect()
	end)

	-- Note: OnExplosion is handled via Network.ExplosionVFX -> VFXAudioSystem

	_trove:Connect(GameSignals.OnCoinGained, function(data)
		AudioService.PlayCoinCollect()
	end)

	Logger.Info("Audio", "AudioService initialized with signal listeners")
end

-- Preload a sound for faster playback
function AudioService._PreloadSound(soundName: string): Sound?
	local soundId = SOUNDS[soundName]
	if not soundId then
		Logger.Warn("Audio", `Unknown sound: {soundName}`)
		return nil
	end

	if _cachedSounds[soundName] then
		return _cachedSounds[soundName]
	end

	local sound = Instance.new("Sound")
	sound.Name = soundName
	sound.SoundId = soundId
	sound.Volume = _sfxVolume
	sound.Parent = _soundFolder

	_cachedSounds[soundName] = sound
	return sound
end

-- Play a sound effect
function AudioService.PlaySound(
	soundName: string,
	options: {
		Volume: number?,
		PlaybackSpeed: number?,
		Position: Vector3?,
	}?
)
	local opts = options or {}
	local sound = AudioService._PreloadSound(soundName)
	if not sound then
		return
	end

	-- Clone for overlapping sounds
	local playSound = sound:Clone()
	playSound.Volume = (opts.Volume or 1) * _sfxVolume
	playSound.PlaybackSpeed = opts.PlaybackSpeed or 1

	-- Positional audio (optional)
	if opts.Position then
		local part = Instance.new("Part")
		part.Name = "SoundEmitter"
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.new(0.1, 0.1, 0.1)
		part.Position = opts.Position
		part.Parent = _soundFolder

		playSound.Parent = part
		playSound:Play()

		-- Cleanup after sound ends
		playSound.Ended:Connect(function()
			part:Destroy()
		end)
	else
		playSound.Parent = _soundFolder
		playSound:Play()

		playSound.Ended:Connect(function()
			playSound:Destroy()
		end)
	end

	Logger.Debug("Audio", `Playing sound: {soundName}`)
end

--[[
	🌱 PLANT SOUNDS
]]
function AudioService.PlayPeaShoot(position: Vector3?)
	AudioService.PlaySound("PeaShoot", {
		Position = position,
		PlaybackSpeed = ChanceUtils.RandomPitch(1.0, 0.1), -- Slight variation
	})
end

function AudioService.PlayPeaImpact(position: Vector3?)
	AudioService.PlaySound("PeaImpact", {
		Position = position,
		Volume = 0.7,
	})
end

function AudioService.PlayPlantPlaced(position: Vector3?)
	AudioService.PlaySound("PlantPlaced", {
		Position = position,
	})
end

function AudioService.PlayExplosion(position: Vector3?)
	AudioService.PlaySound("Explosion", {
		Position = position,
		Volume = 1.2,
	})
end

--[[
	🧟 ZOMBIE SOUNDS
]]
function AudioService.PlayZombieGroan(position: Vector3?)
	AudioService.PlaySound("ZombieGroan", {
		Position = position,
		Volume = 0.5,
		PlaybackSpeed = ChanceUtils.RandomPitch(1.0, 0.2),
	})
end

function AudioService.PlayZombieDeath(position: Vector3?)
	AudioService.PlaySound("ZombieDeath", {
		Position = position,
	})
end

function AudioService.PlayZombieBite(position: Vector3?)
	AudioService.PlaySound("ZombieBite", {
		Position = position,
		Volume = 0.6,
	})
end

--[[
	☀️ COLLECTION SOUNDS
]]
function AudioService.PlaySunCollect()
	AudioService.PlaySound("SunCollect", {
		PlaybackSpeed = ChanceUtils.RandomPitch(1.0, 0.05),
	})
end

function AudioService.PlayCoinCollect()
	AudioService.PlaySound("CoinCollect")
end

--[[
	🖱️ UI SOUNDS
]]
function AudioService.PlayClick()
	AudioService.PlaySound("UIClick", { Volume = 0.6 })
end

function AudioService.PlayError()
	AudioService.PlaySound("UIError", { Volume = 0.7 })
end

function AudioService.PlaySuccess()
	AudioService.PlaySound("UISuccess")
end

function AudioService.PlayCardSelect()
	AudioService.PlaySound("CardSelect", { Volume = 0.5 })
end

--[[
	🎵 GAME EVENT SOUNDS
]]
function AudioService.PlayWaveStart()
	AudioService.PlaySound("WaveStart", { Volume = 0.8 })
end

function AudioService.PlayVictory()
	AudioService.PlaySound("Victory")
end

function AudioService.PlayDefeat()
	AudioService.PlaySound("Defeat", { Volume = 0.8 })
end

function AudioService.PlayStarEarned()
	AudioService.PlaySound("UISuccess", {
		Volume = 0.8,
		PlaybackSpeed = 1.2,
	})
end

function AudioService.PlayCoinCount()
	-- Rapid coin counting sound (lighter version)
	AudioService.PlaySound("CoinCollect", {
		Volume = 0.4,
		PlaybackSpeed = 1.3,
	})
end

--[[
	🎶 MUSIC SYSTEM
]]
export type MusicIntensity = "calm" | "wave" | "intense"

function AudioService.SetMusic(intensity: MusicIntensity)
	local soundId = if intensity == "calm"
		then SOUNDS.MusicCalm
		elseif intensity == "wave" then SOUNDS.MusicWave
		else SOUNDS.MusicIntense

	-- Same music already playing?
	if _currentMusic and _currentMusic.SoundId == soundId then
		return
	end

	-- Fade out current music
	if _currentMusic then
		local oldMusic = _currentMusic
		local fadeOut = TweenService:Create(oldMusic, TweenInfo.new(1), {
			Volume = 0,
		})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			oldMusic:Stop()
			oldMusic:Destroy()
		end)
	end

	-- Create new music
	local newMusic = Instance.new("Sound")
	newMusic.Name = "BackgroundMusic"
	newMusic.SoundId = soundId
	newMusic.Volume = 0
	newMusic.Looped = true
	newMusic.Parent = _soundFolder

	newMusic:Play()

	-- Fade in
	local fadeIn = TweenService:Create(newMusic, TweenInfo.new(1), {
		Volume = _musicVolume,
	})
	fadeIn:Play()

	_currentMusic = newMusic
	Logger.Info("Audio", `Music changed to: {intensity}`)
end

function AudioService.StopMusic()
	if _currentMusic then
		local fadeOut = TweenService:Create(_currentMusic, TweenInfo.new(1), {
			Volume = 0,
		})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			if _currentMusic then
				_currentMusic:Stop()
				_currentMusic:Destroy()
				_currentMusic = nil
			end
		end)
	end
end

--[[
	🔊 VOLUME CONTROL
]]
function AudioService.SetMusicVolume(volume: number)
	_musicVolume = math.clamp(volume, 0, 1)
	if _currentMusic then
		_currentMusic.Volume = _musicVolume
	end
end

function AudioService.SetSFXVolume(volume: number)
	_sfxVolume = math.clamp(volume, 0, 1)
end

function AudioService.GetMusicVolume(): number
	return _musicVolume
end

function AudioService.GetSFXVolume(): number
	return _sfxVolume
end

return AudioService
