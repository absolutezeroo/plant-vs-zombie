--!strict
--[[
	LightingData.luau - Lighting presets per world/map
	
	Defines atmosphere, color correction, and lighting properties
	for each world theme (day, night, fog, pool, roof, boss).
	
	Applied by MapLoader when loading a new map.
]]

export type LightingPreset = {
	-- Core Lighting properties
	ClockTime: number, -- 0-24 (14 = 2pm, 0 = midnight)
	GeographicLatitude: number, -- Sun angle
	Brightness: number, -- Overall brightness
	Ambient: Color3, -- Shadow color
	OutdoorAmbient: Color3, -- Outdoor shadow color
	
	-- Atmosphere (optional)
	Atmosphere: {
		Density: number, -- 0-1 (fog density)
		Offset: number, -- 0-1
		Color: Color3, -- Atmosphere color
		Decay: Color3, -- Horizon decay color
		Glare: number, -- Sun glare
		Haze: number, -- Haze amount
	}?,
	
	-- ColorCorrection (optional)
	ColorCorrection: {
		Brightness: number, -- -1 to 1
		Contrast: number, -- -1 to 1
		Saturation: number, -- -1 to 1
		TintColor: Color3, -- Color tint
	}?,
	
	-- Bloom (optional)
	Bloom: {
		Intensity: number, -- 0-3
		Size: number, -- 4-56
		Threshold: number, -- 0-4
	}?,
	
	-- SunRays (optional)
	SunRays: {
		Intensity: number, -- 0-1
		Spread: number, -- 0-1
	}?,
	
	-- Fog (deprecated but some use cases)
	FogColor: Color3?,
	FogStart: number?,
	FogEnd: number?,
}

-- ============================================
-- LIGHTING PRESETS BY WORLD THEME
-- ============================================

local Presets: { [string]: LightingPreset } = {
	
	-- ============================================
	-- DAY - Bright sunny garden
	-- ============================================
	day = {
		ClockTime = 14, -- 2 PM
		GeographicLatitude = 35,
		Brightness = 2,
		Ambient = Color3.fromRGB(150, 150, 150),
		OutdoorAmbient = Color3.fromRGB(180, 180, 180),
		
		Atmosphere = {
			Density = 0.3,
			Offset = 0,
			Color = Color3.fromRGB(199, 220, 255),
			Decay = Color3.fromRGB(92, 123, 185),
			Glare = 0,
			Haze = 0.5,
		},
		
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.1,
			Saturation = 0.15,
			TintColor = Color3.fromRGB(255, 255, 255),
		},
		
		Bloom = {
			Intensity = 0.5,
			Size = 24,
			Threshold = 1,
		},
		
		SunRays = {
			Intensity = 0.2,
			Spread = 0.5,
		},
	},
	
	-- ============================================
	-- NIGHT - Full moon garden (mushrooms glow)
	-- ============================================
	night = {
		ClockTime = 0, -- Midnight
		GeographicLatitude = 35,
		Brightness = 1.5, -- Bright full moon
		Ambient = Color3.fromRGB(120, 130, 160), -- Soft blue moonlight shadows
		OutdoorAmbient = Color3.fromRGB(100, 110, 140), -- Visible outdoor areas
		
		Atmosphere = {
			Density = 0.3,
			Offset = 0,
			Color = Color3.fromRGB(100, 120, 180), -- Soft blue moonlit sky
			Decay = Color3.fromRGB(60, 80, 120),
			Glare = 0.05, -- Subtle moon glare
			Haze = 0.6,
		},
		
		ColorCorrection = {
			Brightness = 0.05, -- Slightly brighter
			Contrast = 0.15,
			Saturation = -0.1, -- Slightly desaturated
			TintColor = Color3.fromRGB(220, 230, 255), -- Soft blue tint
		},
		
		Bloom = {
			Intensity = 1.0, -- Strong bloom for glowing mushrooms
			Size = 36,
			Threshold = 0.7,
		},
		
		SunRays = nil, -- No sun rays at night
	},
	
	-- ============================================
	-- POOL - Daytime with water reflections
	-- ============================================
	pool = {
		ClockTime = 12, -- Noon
		GeographicLatitude = 35,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(160, 170, 180), -- Slight blue
		OutdoorAmbient = Color3.fromRGB(190, 200, 210),
		
		Atmosphere = {
			Density = 0.25,
			Offset = 0,
			Color = Color3.fromRGB(180, 210, 240), -- Light blue
			Decay = Color3.fromRGB(100, 140, 200),
			Glare = 0.1,
			Haze = 0.4,
		},
		
		ColorCorrection = {
			Brightness = 0.05,
			Contrast = 0.15,
			Saturation = 0.2,
			TintColor = Color3.fromRGB(245, 250, 255), -- Slight blue tint
		},
		
		Bloom = {
			Intensity = 0.6,
			Size = 28,
			Threshold = 1,
		},
		
		SunRays = {
			Intensity = 0.25,
			Spread = 0.4,
		},
	},
	
	-- ============================================
	-- FOG - Night with dense fog (limited visibility)
	-- ============================================
	fog = {
		ClockTime = 2, -- 2 AM
		GeographicLatitude = 35,
		Brightness = 0.3,
		Ambient = Color3.fromRGB(80, 80, 90),
		OutdoorAmbient = Color3.fromRGB(60, 60, 70),
		
		Atmosphere = {
			Density = 0.8, -- Dense fog!
			Offset = 0.25,
			Color = Color3.fromRGB(130, 130, 140), -- Gray fog
			Decay = Color3.fromRGB(80, 80, 90),
			Glare = 0,
			Haze = 2, -- Heavy haze
		},
		
		ColorCorrection = {
			Brightness = -0.15,
			Contrast = -0.1, -- Lower contrast in fog
			Saturation = -0.4, -- Very desaturated
			TintColor = Color3.fromRGB(200, 200, 210),
		},
		
		Bloom = {
			Intensity = 0.4,
			Size = 40, -- Larger bloom for fog glow
			Threshold = 0.6,
		},
		
		-- Legacy fog for extra density
		FogColor = Color3.fromRGB(120, 120, 130),
		FogStart = 50,
		FogEnd = 200,
	},
	
	-- ============================================
	-- ROOF - Day with angled sun (top-down view)
	-- ============================================
	roof = {
		ClockTime = 16, -- 4 PM (angled sun)
		GeographicLatitude = 40,
		Brightness = 1.8,
		Ambient = Color3.fromRGB(140, 130, 120), -- Warm shadows
		OutdoorAmbient = Color3.fromRGB(170, 160, 150),
		
		Atmosphere = {
			Density = 0.35,
			Offset = 0,
			Color = Color3.fromRGB(220, 200, 180), -- Warm
			Decay = Color3.fromRGB(150, 120, 90),
			Glare = 0.15,
			Haze = 0.6,
		},
		
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.1,
			Saturation = 0.1,
			TintColor = Color3.fromRGB(255, 250, 240), -- Warm tint
		},
		
		Bloom = {
			Intensity = 0.5,
			Size = 24,
			Threshold = 1.2,
		},
		
		SunRays = {
			Intensity = 0.3,
			Spread = 0.6,
		},
	},
	
	-- ============================================
	-- BOSS - Dramatic sunset/dusk
	-- ============================================
	boss = {
		ClockTime = 18.5, -- Sunset
		GeographicLatitude = 30,
		Brightness = 1.2,
		Ambient = Color3.fromRGB(100, 60, 60), -- Red shadows
		OutdoorAmbient = Color3.fromRGB(120, 80, 80),
		
		Atmosphere = {
			Density = 0.5,
			Offset = 0.1,
			Color = Color3.fromRGB(255, 150, 100), -- Orange sky
			Decay = Color3.fromRGB(200, 80, 50),
			Glare = 0.2,
			Haze = 1,
		},
		
		ColorCorrection = {
			Brightness = -0.05,
			Contrast = 0.25,
			Saturation = 0.1,
			TintColor = Color3.fromRGB(255, 230, 210), -- Warm dramatic
		},
		
		Bloom = {
			Intensity = 0.7,
			Size = 30,
			Threshold = 0.9,
		},
		
		SunRays = {
			Intensity = 0.4,
			Spread = 0.8,
		},
	},
}

-- ============================================
-- API
-- ============================================

local LightingData = {}

--[[
	Get lighting preset for a world theme
	@param theme - World theme ID (from WorldData.Theme)
	@return LightingPreset or default day preset
]]
function LightingData.GetPreset(theme: string): LightingPreset
	return Presets[theme] or Presets.day
end

--[[
	Get all available presets
	@return Dictionary of all presets
]]
function LightingData.GetAllPresets(): { [string]: LightingPreset }
	return Presets
end

--[[
	Check if a preset exists for theme
	@param theme - World theme ID
	@return boolean
]]
function LightingData.HasPreset(theme: string): boolean
	return Presets[theme] ~= nil
end

return table.freeze(LightingData)
