--!strict
--[[
	Client Bootstrap - Initializes client-side Matter World and Fusion UI
	
	Syncs with server at 60 Hz
	Client systems handle:
	- Input processing (Priority 0-99)
	- Ghost prediction (Priority 100-199)
	- Visual updates (Priority 300-399)
	- VFX, Audio, UI (Priority 300-399)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Wait for packages to be available
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ErrorHandler = require(Shared.utils.ErrorHandler)
local PerformanceConfig = require(Shared.config.PerformanceConfig)
local NetworkConfig = require(Shared.config.NetworkConfig)

-- Import client folders (init.client.luau IS the Client script, children are direct)
local Systems = script:WaitForChild("systems")
local UI = script:WaitForChild("ui")

-- Get local player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

Logger.Info("Client", `Initializing client for {LocalPlayer.Name}`)

-- Create client Matter World (separate from server world)
local world = Matter.World.new()

-- Create Matter Loop (debugger disabled - needs Plasma update)
-- TODO: Add Plasma to wally.toml and re-enable debugger
local loop = Matter.Loop.new(world)

Logger.Info("Client", "Client Matter World created")

-- Load all client systems from systems folder
local systemModules: {any} = {}

local function loadSystem(moduleScript: ModuleScript)
	local success, system = ErrorHandler.Try(function()
		return require(moduleScript)
	end, `LoadSystem.{moduleScript.Name}`)
	
	if success and system then
		table.insert(systemModules, system)
		Logger.Debug("Client", `Loaded system: {moduleScript.Name}`, {
			priority = system.priority or 0
		})
	end
end

-- Load systems
for _, child in Systems:GetChildren() do
	if child:IsA("ModuleScript") then
		loadSystem(child)
	end
end

Logger.Info("Client", `Loaded {#systemModules} client systems`)

-- Schedule systems in the loop
loop:scheduleSystems(systemModules)

-- Start the loop at 60 Hz (RenderStepped for client)
loop:begin({
	default = RunService.RenderStepped,
})

Logger.Info("Client", `Client ECS loop started at {NetworkConfig.TICK_RATE} Hz`)

--[[
	Initialize Fusion UI Root
	
	Fusion components will be mounted to PlayerGui
	The main HUD controller module handles UI creation
]]

-- Fusion scopes for cleanup
local scope = Fusion.scoped({
	-- Will add Fusion primitives here as needed
})

-- Store UI state (for reactivity)
local UIState = {
	SunCount = Fusion.Value(scope, 50),  -- Starting sun
	SelectedPlant = Fusion.Value(scope, nil :: string?),
	WaveNumber = Fusion.Value(scope, 0),
	GamePhase = Fusion.Value(scope, "pregame"),  -- pregame, wave, intermission, gameover
}

-- Export UIState for other modules
_G.ClientUIState = UIState

Logger.Info("Client", "Fusion UI state initialized")

-- Performance monitoring (less frequent on client to save cycles)
local frameCount = 0
local lastMonitorTime = tick()

RunService.RenderStepped:Connect(function(deltaTime)
	frameCount = frameCount + 1
	
	-- Throttled performance logging (every 30 seconds on client)
	local now = tick()
	if now - lastMonitorTime >= 30 then
		local avgFPS = frameCount / (now - lastMonitorTime)
		
		Logger.Performance("Client", "Performance stats", {
			FPS = math.floor(avgFPS),
			MemoryMB = math.floor(collectgarbage("count") / 1024),
		})
		
		frameCount = 0
		lastMonitorTime = now
	end
end)

Logger.Info("Client", "Client bootstrap complete")
