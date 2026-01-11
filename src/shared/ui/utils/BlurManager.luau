--!strict
--[[
	BlurManager.luau - Manages blur effect for overlay screens
	
	Provides a simple API to add/remove blur when overlay screens are shown.
	Uses a reference counting system to handle multiple overlays.
	
	Usage:
		local BlurManager = require(Shared.ui.utils.BlurManager)
		
		-- When opening an overlay
		BlurManager.Enable()
		
		-- When closing an overlay
		BlurManager.Disable()
]]

local Lighting = game:GetService("Lighting")

local BLUR_NAME = "OverlayBlur"
local BLUR_SIZE = 24

local BlurManager = {}

local _refCount = 0
local _blur: BlurEffect? = nil

--[[
	Enable blur effect. Uses reference counting so multiple overlays
	can call Enable() and the blur stays until all call Disable().
]]
function BlurManager.Enable()
	_refCount = _refCount + 1
	
	if _refCount == 1 then
		-- Create blur only on first enable
		if not _blur then
			local blur = Instance.new("BlurEffect")
			blur.Name = BLUR_NAME
			blur.Size = BLUR_SIZE
			blur.Parent = Lighting
			_blur = blur
		end
	end
end

--[[
	Disable blur effect. Decrements reference count and removes
	blur when no more overlays need it.
]]
function BlurManager.Disable()
	_refCount = math.max(0, _refCount - 1)
	
	if _refCount == 0 and _blur then
		_blur:Destroy()
		_blur = nil
	end
end

--[[
	Force disable blur regardless of reference count.
	Useful for cleanup on game restart.
]]
function BlurManager.ForceDisable()
	_refCount = 0
	if _blur then
		_blur:Destroy()
		_blur = nil
	end
end

--[[
	Check if blur is currently active.
]]
function BlurManager.IsActive(): boolean
	return _blur ~= nil
end

return BlurManager
