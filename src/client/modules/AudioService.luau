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

-- Sound asset IDs (using Roblox library sounds)
local SOUNDS = {
	-- Plant sounds
	PeaShoot = "rbxassetid://9114386081", -- Pop/shoot sound
	PeaImpact = "rbxassetid://9114368485", -- Splat
	PlantPlaced = "rbxassetid://9114342410", -- Dirt/place
	Explosion = "rbxassetid://9114333311", -- Boom
	
	-- Zombie sounds
	ZombieGroan = "rbxassetid://9114384236", -- Groan
	ZombieDeath = "rbxassetid://9114374245", -- Death groan
	ZombieBite = "rbxassetid://9114367157", -- Chomp
	
	-- Collection sounds
	SunCollect = "rbxassetid://9114298767", -- Sparkle/chime
	CoinCollect = "rbxassetid://9114343710", -- Coin ding
	
	-- UI sounds
	UIClick = "rbxassetid://9114369169", -- Click
	UIError = "rbxassetid://9114341316", -- Error buzz
	UISuccess = "rbxassetid://9114340977", -- Success chime
	CardSelect = "rbxassetid://9114369169", -- Select card
	
	-- Game events
	WaveStart = "rbxassetid://9114275839", -- Alert/horn
	Victory = "rbxassetid://9114275839", -- Fanfare
	Defeat = "rbxassetid://9114333311", -- Doom
	
	-- Music
	MusicCalm = "rbxassetid://1837617252", -- Peaceful background
	MusicWave = "rbxassetid://1846453837", -- Tense wave music
	MusicIntense = "rbxassetid://1846453837", -- Boss/intense
}

local _soundFolder: Folder = nil
local _cachedSounds: { [string]: Sound } = {}
local _currentMusic: Sound? = nil
local _musicVolume: number = 0.3
local _sfxVolume: number = 0.5

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
	
	Logger.Info("Audio", "AudioService initialized")
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
function AudioService.PlaySound(soundName: string, options: {
	Volume: number?,
	PlaybackSpeed: number?,
	Position: Vector3?,
}?)
	local opts = options or {}
	local sound = AudioService._PreloadSound(soundName)
	if not sound then return end
	
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
		PlaybackSpeed = 0.9 + math.random() * 0.2, -- Slight variation
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
		PlaybackSpeed = 0.8 + math.random() * 0.4,
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
		PlaybackSpeed = 1 + math.random() * 0.1,
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

--[[
	🎶 MUSIC SYSTEM
]]
export type MusicIntensity = "calm" | "wave" | "intense"

function AudioService.SetMusic(intensity: MusicIntensity)
	local soundId = if intensity == "calm" then SOUNDS.MusicCalm
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
