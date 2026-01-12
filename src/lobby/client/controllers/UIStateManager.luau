--!strict
--[[
    UIStateManager.luau - Centralized UI visibility management
    
    Allows controllers to register their GUI and hide/show them based on state.
    When player is in a queue (on a pad), other GUIs are hidden automatically.
    
    Usage:
        UIStateManager.Register("LobbyHUD", hudScreenGui)
        UIStateManager.Register("ZoneInteraction", zoneModal)
        
        -- When entering queue:
        UIStateManager.SetQueueMode(true)  -- Hides all except "PadLeaveUI"
        
        -- When leaving queue:
        UIStateManager.SetQueueMode(false) -- Shows all registered GUIs
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Value = Fusion.Value

-- Module
local UIStateManager = {}

-- State
local _scope = Fusion.scoped(Fusion)
local _isInQueue = Value(_scope, false)
local _registeredGUIs: { [string]: { Instance: GuiObject, OriginalVisible: boolean } } = {}

-- GUIs that should stay visible during queue
local QUEUE_VISIBLE_GUIS = {
	"PadLeaveUI",
	"TeleportTransition", -- Keep if we add it back
}

-- Check if a GUI should be visible during queue
local function shouldBeVisibleInQueue(name: string): boolean
	for _, allowed in ipairs(QUEUE_VISIBLE_GUIS) do
		if name == allowed then
			return true
		end
	end
	return false
end

--[[
    Register a GUI to be managed by UIStateManager
    @param name: Unique identifier for the GUI
    @param guiInstance: The ScreenGui or Frame to manage
]]
function UIStateManager.Register(name: string, guiInstance: GuiObject)
	if _registeredGUIs[name] then
		Logger.Warn("UIStateManager", `GUI "{name}" already registered, replacing`)
	end

	_registeredGUIs[name] = {
		Instance = guiInstance,
		OriginalVisible = true, -- Track if it should be visible when not in queue
	}

	Logger.Debug("UIStateManager", `Registered GUI: {name}`)
end

--[[
    Unregister a GUI
    @param name: Identifier of the GUI to remove
]]
function UIStateManager.Unregister(name: string)
	_registeredGUIs[name] = nil
	Logger.Debug("UIStateManager", `Unregistered GUI: {name}`)
end

--[[
    Set whether player is in queue mode (on a pad)
    Hides non-essential GUIs when true
    @param inQueue: true when player is on a pad, false otherwise
]]
function UIStateManager.SetQueueMode(inQueue: boolean)
	if Fusion.peek(_isInQueue) == inQueue then
		return -- No change
	end

	_isInQueue:set(inQueue)
	Logger.Info("UIStateManager", `Queue mode: {inQueue}`)

	for name, guiData in pairs(_registeredGUIs) do
		local gui = guiData.Instance

		if inQueue then
			-- Entering queue: hide non-essential GUIs
			if shouldBeVisibleInQueue(name) then
				-- Keep visible
			else
				-- Save current state and hide
				if gui:IsA("ScreenGui") then
					guiData.OriginalVisible = gui.Enabled
					gui.Enabled = false
				elseif gui:IsA("GuiObject") then
					guiData.OriginalVisible = gui.Visible
					gui.Visible = false
				end
			end
		else
			-- Leaving queue: restore original visibility
			if gui:IsA("ScreenGui") then
				gui.Enabled = guiData.OriginalVisible
			elseif gui:IsA("GuiObject") then
				gui.Visible = guiData.OriginalVisible
			end
		end
	end
end

--[[
    Get whether we're currently in queue mode
    @return: Fusion.Value<boolean> for reactive binding
]]
function UIStateManager.IsInQueue(): any
	return _isInQueue
end

--[[
    Manually set visibility of a specific GUI
    @param name: GUI identifier
    @param visible: Whether to show or hide
]]
function UIStateManager.SetVisible(name: string, visible: boolean)
	local guiData = _registeredGUIs[name]
	if not guiData then
		Logger.Warn("UIStateManager", `GUI "{name}" not registered`)
		return
	end

	local gui = guiData.Instance
	guiData.OriginalVisible = visible

	-- Only apply if not in queue, or if this GUI is allowed in queue
	if not Fusion.peek(_isInQueue) or shouldBeVisibleInQueue(name) then
		if gui:IsA("ScreenGui") then
			gui.Enabled = visible
		elseif gui:IsA("GuiObject") then
			gui.Visible = visible
		end
	end
end

--[[
    Hide all registered GUIs
]]
function UIStateManager.HideAll()
	for name, guiData in pairs(_registeredGUIs) do
		local gui = guiData.Instance
		if gui:IsA("ScreenGui") then
			gui.Enabled = false
		elseif gui:IsA("GuiObject") then
			gui.Visible = false
		end
	end
end

--[[
    Show all registered GUIs (restore original visibility)
]]
function UIStateManager.ShowAll()
	for name, guiData in pairs(_registeredGUIs) do
		local gui = guiData.Instance
		if gui:IsA("ScreenGui") then
			gui.Enabled = guiData.OriginalVisible
		elseif gui:IsA("GuiObject") then
			gui.Visible = guiData.OriginalVisible
		end
	end
end

return UIStateManager
