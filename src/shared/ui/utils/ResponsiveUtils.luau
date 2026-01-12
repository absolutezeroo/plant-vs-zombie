--!strict
--[[
	ResponsiveUtils.luau - Responsive UI scaling utility
	
	Provides automatic UI scaling based on screen size.
	Designed for a base resolution of 1920x1080 (Full HD).
	
	Usage:
		local ResponsiveUtils = require(Shared.ui.utils.ResponsiveUtils)
		
		-- Get current scale factor (updates automatically)
		local scale = ResponsiveUtils.GetScale()
		
		-- Scale a pixel value
		local scaledSize = ResponsiveUtils.ScalePixels(100) -- Returns scaled value
		
		-- Get a UIScale instance for a container
		local uiScale = ResponsiveUtils.CreateUIScale(scope)
		
		-- Listen to scale changes
		ResponsiveUtils.OnScaleChanged:Connect(function(newScale)
			print("Scale changed to:", newScale)
		end)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Signal = require(Packages:WaitForChild("Signal"))

-- Fusion primitives
local New = Fusion.New
local Value = Fusion.Value
local Computed = Fusion.Computed
local peek = Fusion.peek

-- ============================================
-- CONFIGURATION
-- ============================================

-- Base design resolution (what the UI was designed for)
local BASE_WIDTH = 1920
local BASE_HEIGHT = 1080

-- Scale limits to prevent extreme sizes
-- For overlay screens (92% of screen), we cap at 1.0 to avoid overflow
-- For fixed-size elements, scaling helps on larger screens
local MIN_SCALE = 0.5  -- Minimum 50% (very small screens)
local MAX_SCALE = 2.5  -- Maximum 250% (large screens like 4K)

-- Responsive breakpoints
local BREAKPOINTS = {
	Mobile = 600,      -- Width < 600px = Mobile
	Tablet = 1024,     -- Width < 1024px = Tablet
	Desktop = 1920,    -- Width < 1920px = Desktop
	Large = math.huge, -- Width >= 1920px = Large
}

-- ============================================
-- STATE
-- ============================================

-- Internal scope for singleton Values
local _scope: any = Fusion.scoped({})
local _scale: any = Value(_scope, 1.0)
local _screenSize: any = Value(_scope, Vector2.new(BASE_WIDTH, BASE_HEIGHT))
local _deviceType: any = Value(_scope, "Desktop")
local _onScaleChanged = Signal.new()
local _initialized = false

-- ============================================
-- INTERNAL FUNCTIONS
-- ============================================

local function calculateScale(viewportSize: Vector2): number
	-- Calculate scale based on the smaller dimension ratio
	-- This ensures content fits on screen regardless of aspect ratio
	local widthScale = viewportSize.X / BASE_WIDTH
	local heightScale = viewportSize.Y / BASE_HEIGHT
	
	-- Use the smaller scale to ensure everything fits
	local scale = math.min(widthScale, heightScale)
	
	-- Clamp to reasonable limits
	scale = math.clamp(scale, MIN_SCALE, MAX_SCALE)
	
	return scale
end

local function getDeviceType(width: number): string
	if width < BREAKPOINTS.Mobile then
		return "Mobile"
	elseif width < BREAKPOINTS.Tablet then
		return "Tablet"
	elseif width < BREAKPOINTS.Desktop then
		return "Desktop"
	else
		return "Large"
	end
end

local function updateScale()
	local player = Players.LocalPlayer
	if not player then return end
	
	local camera = workspace.CurrentCamera
	if not camera then return end
	
	local viewportSize = camera.ViewportSize
	_screenSize:set(viewportSize)
	
	local newScale = calculateScale(viewportSize)
	local oldScale = peek(_scale)
	
	if math.abs(newScale - oldScale) > 0.01 then
		_scale:set(newScale)
		_deviceType:set(getDeviceType(viewportSize.X))
		_onScaleChanged:Fire(newScale)
	end
end

local function initialize()
	if _initialized then return end
	_initialized = true
	
	-- Initial calculation
	updateScale()
	
	-- Listen to viewport size changes
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	
	-- Handle camera changes (rare but possible)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCamera = workspace.CurrentCamera
		if newCamera then
			newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end)
end

-- ============================================
-- PUBLIC API
-- ============================================

local ResponsiveUtils = {}

--[[
	Get the current scale factor.
	Returns a number between MIN_SCALE and MAX_SCALE.
]]
function ResponsiveUtils.GetScale(): number
	initialize()
	return peek(_scale)
end

--[[
	Get the scale as a Fusion Value for reactive UI.
]]
function ResponsiveUtils.GetScaleValue(): any
	initialize()
	return _scale
end

--[[
	Get the current screen size as a Fusion Value.
]]
function ResponsiveUtils.GetScreenSizeValue(): any
	initialize()
	return _screenSize
end

--[[
	Get the current device type: "Mobile", "Tablet", "Desktop", or "Large"
]]
function ResponsiveUtils.GetDeviceType(): string
	initialize()
	return peek(_deviceType)
end

--[[
	Get the device type as a Fusion Value.
]]
function ResponsiveUtils.GetDeviceTypeValue(): any
	initialize()
	return _deviceType
end

--[[
	Scale a pixel value by the current scale factor.
	@param pixels The base pixel value (at 1920x1080)
	@return The scaled pixel value for the current screen
]]
function ResponsiveUtils.ScalePixels(pixels: number): number
	initialize()
	return math.round(pixels * peek(_scale))
end

--[[
	Create a Fusion Computed that scales a pixel value reactively.
	@param scope Fusion scope for cleanup
	@param pixels The base pixel value
	@return A Computed that updates when scale changes
]]
function ResponsiveUtils.ScaledPixels(scope: any, pixels: number): any
	initialize()
	return Computed(scope, function(use)
		return math.round(pixels * use(_scale))
	end)
end

--[[
	Create a UIScale instance that scales with screen size.
	Parent this to a container to scale all children.
	
	@param scope Fusion scope for cleanup
	@return UIScale instance
]]
function ResponsiveUtils.CreateUIScale(scope: any): any
	initialize()
	
	return scope:New("UIScale") {
		Name = "ResponsiveScale",
		Scale = scope:Computed(function(use)
			return use(_scale)
		end),
	}
end

--[[
	Check if we're on a mobile device (small screen).
]]
function ResponsiveUtils.IsMobile(): boolean
	initialize()
	return peek(_deviceType) == "Mobile"
end

--[[
	Check if we're on a tablet device (medium screen).
]]
function ResponsiveUtils.IsTablet(): boolean
	initialize()
	return peek(_deviceType) == "Tablet"
end

--[[
	Check if we're on a desktop or larger screen.
]]
function ResponsiveUtils.IsDesktopOrLarger(): boolean
	initialize()
	local device = peek(_deviceType)
	return device == "Desktop" or device == "Large"
end

--[[
	Signal fired when the scale changes.
	Callback receives the new scale factor.
]]
ResponsiveUtils.OnScaleChanged = _onScaleChanged

--[[
	Get recommended overlay size based on device.
	Mobile: Fullscreen (0.98)
	Tablet: Large (0.95)
	Desktop/Large: Standard (0.92)
]]
function ResponsiveUtils.GetOverlaySize(): UDim2
	initialize()
	local device = peek(_deviceType)
	
	if device == "Mobile" then
		return UDim2.fromScale(0.98, 0.98)
	elseif device == "Tablet" then
		return UDim2.fromScale(0.95, 0.95)
	else
		return UDim2.fromScale(0.92, 0.92)
	end
end

--[[
	Get recommended font size based on device.
	@param baseSize The base font size at 1920x1080
	@return Scaled font size
]]
function ResponsiveUtils.GetFontSize(baseSize: number): number
	initialize()
	local device = peek(_deviceType)
	local scale = peek(_scale)
	
	-- On mobile, bump up font size slightly for readability
	if device == "Mobile" then
		return math.round(baseSize * scale * 1.2)
	end
	
	return math.round(baseSize * scale)
end

-- Constants for external use
ResponsiveUtils.BASE_WIDTH = BASE_WIDTH
ResponsiveUtils.BASE_HEIGHT = BASE_HEIGHT
ResponsiveUtils.MIN_SCALE = MIN_SCALE
ResponsiveUtils.MAX_SCALE = MAX_SCALE
ResponsiveUtils.BREAKPOINTS = BREAKPOINTS

return ResponsiveUtils
