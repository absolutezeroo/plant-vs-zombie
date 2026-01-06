--!strict
--[[
	Server Bootstrap - Initializes Matter ECS World and system loop
	
	Runs at 60 Hz (TICK_RATE from NetworkConfig)
	Systems execute in priority order within phases:
	- Input Phase: Priority 0-99
	- Simulation Phase: Priority 100-299
	- Presentation Phase: Priority 300-399
	- Cleanup Phase: Priority 400+
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Wait for packages to be available
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ErrorHandler = require(Shared.utils.ErrorHandler)
local EntityPool = require(Shared.utils.EntityPool)
local PerformanceConfig = require(Shared.config.PerformanceConfig)
local NetworkConfig = require(Shared.config.NetworkConfig)

-- Import components via index module
local Components = require(Shared.components)
local Tags = Components.Tags
local GridPositionComponent = Components.GridPositionComponent
local HealthComponent = Components.HealthComponent

-- Import server services
local Server = script
local PlayerDataService = require(Server.services.PlayerDataService)
local ProgressionHandler = require(Server.handlers.ProgressionHandler)

-- Import server systems folder
-- Note: init.server.luau IS the Server script, so children are direct
local Systems = script:WaitForChild("systems")

-- Initialize services
PlayerDataService.Initialize()
Logger.Info("Server", "PlayerDataService initialized")

-- Initialize handlers
ProgressionHandler.Initialize()
Logger.Info("Server", "ProgressionHandler initialized")

-- Create Matter World
local world = Matter.World.new()

-- Create Matter Loop (debugger disabled - needs Plasma update)
-- TODO: Add Plasma to wally.toml and re-enable debugger
local loop = Matter.Loop.new(world)

Logger.Info("Server", "Matter World created")

-- Initialize Entity Pool
EntityPool.Initialize(world, Tags.InactiveTag)
Logger.Info("Server", "Entity Pool initialized", EntityPool.GetStats())

-- Load all systems from systems folder (RECURSIVELY scan subfolders)
local systemModules: {any} = {}

local function loadSystem(moduleScript: ModuleScript)
	local success, system = ErrorHandler.Try(function()
		return require(moduleScript)
	end, `LoadSystem.{moduleScript.Name}`)
	
	if success and system then
		table.insert(systemModules, system)
		Logger.Debug("Server", `Loaded system: {moduleScript.Name}`, {
			priority = system.priority or 0
		})
	end
end

-- Recursively load systems from all subfolders using GetDescendants
-- This supports the domain-driven folder structure (combat/, economy/, units/, etc.)
for _, descendant in Systems:GetDescendants() do
	if descendant:IsA("ModuleScript") then
		loadSystem(descendant)
	end
end

Logger.Info("Server", `Loaded {#systemModules} systems`)

-- Schedule systems in the loop
loop:scheduleSystems(systemModules)

-- Start the loop at 60 Hz
loop:begin({
	default = RunService.Heartbeat,
})

Logger.Info("Server", `ECS loop started at {NetworkConfig.TICK_RATE} Hz`)

-- Performance monitoring
local frameCount = 0
local lastMonitorTime = tick()

RunService.Heartbeat:Connect(function(deltaTime)
	frameCount = frameCount + 1
	
	-- Throttled performance logging (every 10 seconds)
	local now = tick()
	if now - lastMonitorTime >= PerformanceConfig.MONITOR_INTERVAL then
		local poolStats = EntityPool.GetStats()
		local avgFPS = frameCount / (now - lastMonitorTime)
		
		Logger.Performance("Server", "Performance stats", {
			FPS = math.floor(avgFPS),
			EntitiesInUse = poolStats.InUse,
			EntitiesAvailable = poolStats.Available,
			MemoryMB = math.floor(collectgarbage("count") / 1024),
		})
		
		frameCount = 0
		lastMonitorTime = now
		
		-- Memory warning check
		local memoryMB = collectgarbage("count") / 1024
		if memoryMB > PerformanceConfig.MEMORY_WARNING then
			Logger.Warn("Server", "Memory usage high", { MemoryMB = math.floor(memoryMB) })
		end
		if memoryMB > PerformanceConfig.MEMORY_EMERGENCY then
			Logger.Warn("Server", "EMERGENCY: Forcing garbage collection")
			collectgarbage("collect")
		end
	end
end)

Logger.Info("Server", "Server bootstrap complete")
