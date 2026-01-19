--!strict
--[[
	LightingService.luau - Apply lighting presets per map/world
	
	This service applies LightingData presets to the game Lighting.
	Called by MapLoader when loading a new map.
	
	Features:
	- Smooth transitions between lighting presets
	- Creates/updates post-processing effects (Atmosphere, ColorCorrection, Bloom, SunRays)
	- Supports instant or tweened transitions
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LightingData = require(Shared.data.LightingData)
local Logger = require(Shared.utils.core.Logger)

-- Types (inline to avoid indexed access type issues)
type AtmosphereConfig = {
	Density: number,
	Offset: number,
	Color: Color3,
	Decay: Color3,
	Glare: number,
	Haze: number,
}

type ColorCorrectionConfig = {
	Brightness: number,
	Contrast: number,
	Saturation: number,
	TintColor: Color3,
}

type BloomConfig = {
	Intensity: number,
	Size: number,
	Threshold: number,
}

type SunRaysConfig = {
	Intensity: number,
	Spread: number,
}

type LightingPreset = LightingData.LightingPreset

-- State
local _currentTheme: string = "day"
local _isTransitioning = false

-- Cache effect instances
local _atmosphere: Atmosphere? = nil
local _colorCorrection: ColorCorrectionEffect? = nil
local _bloom: BloomEffect? = nil
local _sunRays: SunRaysEffect? = nil

-- Tween info for smooth transitions
local TRANSITION_INFO = TweenInfo.new(
	2, -- Duration
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.InOut
)

local LightingService = {}

--[[
	Get or create an effect in Lighting
]]
local function getOrCreateEffect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	
	-- Remove if wrong type
	if existing then
		existing:Destroy()
	end
	
	local effect = Instance.new(className :: any)
	effect.Name = name
	effect.Parent = Lighting
	return effect :: any
end

--[[
	Apply core Lighting properties (instant or tweened)
]]
local function applyCoreLighting(preset: LightingPreset, instant: boolean)
	if instant then
		Lighting.ClockTime = preset.ClockTime
		Lighting.GeographicLatitude = preset.GeographicLatitude
		Lighting.Brightness = preset.Brightness
		Lighting.Ambient = preset.Ambient
		Lighting.OutdoorAmbient = preset.OutdoorAmbient
		
		-- Legacy fog
		if preset.FogColor then
			Lighting.FogColor = preset.FogColor
			Lighting.FogStart = preset.FogStart or 0
			Lighting.FogEnd = preset.FogEnd or 10000
		else
			Lighting.FogEnd = 10000 -- Disable fog
		end
	else
		-- Tween core properties
		local tween = TweenService:Create(Lighting, TRANSITION_INFO, {
			ClockTime = preset.ClockTime,
			GeographicLatitude = preset.GeographicLatitude,
			Brightness = preset.Brightness,
			Ambient = preset.Ambient,
			OutdoorAmbient = preset.OutdoorAmbient,
			FogColor = preset.FogColor or Lighting.FogColor,
			FogStart = preset.FogStart or 0,
			FogEnd = preset.FogEnd or 10000,
		})
		tween:Play()
	end
end

--[[
	Apply Atmosphere effect
]]
local function applyAtmosphere(atmosphereConfig: AtmosphereConfig?, instant: boolean)
	if not atmosphereConfig then
		-- Remove atmosphere if not needed
		if _atmosphere then
			_atmosphere:Destroy()
			_atmosphere = nil
		end
		return
	end
	
	_atmosphere = getOrCreateEffect("Atmosphere", "WorldAtmosphere")
	
	-- Type guard
	local atmos = _atmosphere
	if not atmos then return end
	
	if instant then
		atmos.Density = atmosphereConfig.Density
		atmos.Offset = atmosphereConfig.Offset
		atmos.Color = atmosphereConfig.Color
		atmos.Decay = atmosphereConfig.Decay
		atmos.Glare = atmosphereConfig.Glare
		atmos.Haze = atmosphereConfig.Haze
	else
		local tween = TweenService:Create(atmos, TRANSITION_INFO, {
			Density = atmosphereConfig.Density,
			Offset = atmosphereConfig.Offset,
			Color = atmosphereConfig.Color,
			Decay = atmosphereConfig.Decay,
			Glare = atmosphereConfig.Glare,
			Haze = atmosphereConfig.Haze,
		})
		tween:Play()
	end
end

--[[
	Apply ColorCorrection effect
]]
local function applyColorCorrection(ccConfig: ColorCorrectionConfig?, instant: boolean)
	if not ccConfig then
		if _colorCorrection then
			_colorCorrection:Destroy()
			_colorCorrection = nil
		end
		return
	end
	
	_colorCorrection = getOrCreateEffect("ColorCorrectionEffect", "WorldColorCorrection")
	
	-- Type guard
	local cc = _colorCorrection
	if not cc then return end
	
	if instant then
		cc.Brightness = ccConfig.Brightness
		cc.Contrast = ccConfig.Contrast
		cc.Saturation = ccConfig.Saturation
		cc.TintColor = ccConfig.TintColor
	else
		local tween = TweenService:Create(cc, TRANSITION_INFO, {
			Brightness = ccConfig.Brightness,
			Contrast = ccConfig.Contrast,
			Saturation = ccConfig.Saturation,
			TintColor = ccConfig.TintColor,
		})
		tween:Play()
	end
end

--[[
	Apply Bloom effect
]]
local function applyBloom(bloomConfig: BloomConfig?, instant: boolean)
	if not bloomConfig then
		if _bloom then
			_bloom:Destroy()
			_bloom = nil
		end
		return
	end
	
	_bloom = getOrCreateEffect("BloomEffect", "WorldBloom")
	
	-- Type guard
	local bloom = _bloom
	if not bloom then return end
	
	if instant then
		bloom.Intensity = bloomConfig.Intensity
		bloom.Size = bloomConfig.Size
		bloom.Threshold = bloomConfig.Threshold
	else
		local tween = TweenService:Create(bloom, TRANSITION_INFO, {
			Intensity = bloomConfig.Intensity,
			Size = bloomConfig.Size,
			Threshold = bloomConfig.Threshold,
		})
		tween:Play()
	end
end

--[[
	Apply SunRays effect
]]
local function applySunRays(sunRaysConfig: SunRaysConfig?, instant: boolean)
	if not sunRaysConfig then
		if _sunRays then
			_sunRays:Destroy()
			_sunRays = nil
		end
		return
	end
	
	_sunRays = getOrCreateEffect("SunRaysEffect", "WorldSunRays")
	
	-- Type guard
	local sr = _sunRays
	if not sr then return end
	
	if instant then
		sr.Intensity = sunRaysConfig.Intensity
		sr.Spread = sunRaysConfig.Spread
	else
		local tween = TweenService:Create(sr, TRANSITION_INFO, {
			Intensity = sunRaysConfig.Intensity,
			Spread = sunRaysConfig.Spread,
		})
		tween:Play()
	end
end

--[[
	Initialize the LightingService
	Finds existing effects in Lighting or uses defaults
]]
function LightingService.Initialize()
	-- Cache existing effects
	_atmosphere = Lighting:FindFirstChild("WorldAtmosphere") :: Atmosphere?
	_colorCorrection = Lighting:FindFirstChild("WorldColorCorrection") :: ColorCorrectionEffect?
	_bloom = Lighting:FindFirstChild("WorldBloom") :: BloomEffect?
	_sunRays = Lighting:FindFirstChild("WorldSunRays") :: SunRaysEffect?
	
	Logger.Info("LightingService", "Initialized")
end

--[[
	Apply a lighting preset by theme name
	
	@param theme - Theme ID from WorldData (e.g., "day", "night", "fog")
	@param instant - If true, apply instantly; otherwise tween over 2 seconds
]]
function LightingService.ApplyPreset(theme: string, instant: boolean?)
	local preset = LightingData.GetPreset(theme)
	local isInstant = instant == true
	
	if _isTransitioning then
		Logger.Warn("LightingService", "Already transitioning, forcing instant apply")
		isInstant = true
	end
	
	Logger.Info("LightingService", `Applying lighting preset: {theme} (instant={isInstant})`)
	
	_isTransitioning = not isInstant
	_currentTheme = theme
	
	-- Apply all lighting components
	applyCoreLighting(preset, isInstant)
	applyAtmosphere(preset.Atmosphere :: AtmosphereConfig?, isInstant)
	applyColorCorrection(preset.ColorCorrection :: ColorCorrectionConfig?, isInstant)
	applyBloom(preset.Bloom :: BloomConfig?, isInstant)
	applySunRays(preset.SunRays :: SunRaysConfig?, isInstant)
	
	if not isInstant then
		-- Mark transition complete after duration
		task.delay(TRANSITION_INFO.Time, function()
			_isTransitioning = false
			Logger.Debug("LightingService", "Lighting transition complete")
		end)
	end
end

--[[
	Get the current theme
	@return Current theme ID
]]
function LightingService.GetCurrentTheme(): string
	return _currentTheme
end

--[[
	Check if currently transitioning between presets
	@return boolean
]]
function LightingService.IsTransitioning(): boolean
	return _isTransitioning
end

--[[
	Apply lighting from a WorldConfig directly
	Convenience method for MapLoader
	
	@param worldId - World ID to get theme from
	@param instant - If true, apply instantly
]]
function LightingService.ApplyFromWorld(worldId: string, instant: boolean?)
	local WorldData = require(Shared.data.WorldData)
	local world = WorldData.GetWorld(worldId)
	
	if not world then
		Logger.Warn("LightingService", `World not found: {worldId}, using day preset`)
		LightingService.ApplyPreset("day", instant)
		return
	end
	
	LightingService.ApplyPreset(world.Theme, instant)
end

return LightingService
