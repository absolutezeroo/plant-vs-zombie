--!strict
--[[
    SystemManager.luau - Centralized system lifecycle management for Matter ECS
    
    PURPOSE:
    Separates initialization (can yield) from runtime (cannot yield) to prevent
    "System yielded! Its thread has been closed" errors in Matter ECS.
    
    ARCHITECTURE:
    ┌─────────────────────────────────────────────────────────────┐
    │                      INIT PHASE                              │
    │  (BEFORE Matter.loop - CAN yield)                           │
    ├─────────────────────────────────────────────────────────────┤
    │  1. SystemManager.RegisterAll(systems)                       │
    │  2. SystemManager.InitializeAll(world)                       │
    │     - Calls system.Init(world) for each system               │
    │     - Safe to WaitForChild, require, setup connections       │
    │     - Ordered by priority                                    │
    └─────────────────────────────────────────────────────────────┘
                                  ↓
    ┌─────────────────────────────────────────────────────────────┐
    │                      RUNTIME PHASE                           │
    │  (Matter.loop @ 60Hz - CANNOT yield)                        │
    ├─────────────────────────────────────────────────────────────┤
    │  3. Matter.loop:scheduleSystems(systems)                     │
    │  4. loop:begin()                                             │
    │     - system.system(world) or system.OnStep(world)          │
    │     - Pure computation only                                  │
    └─────────────────────────────────────────────────────────────┘
                                  ↓
    ┌─────────────────────────────────────────────────────────────┐
    │                      DISPOSE PHASE                           │
    │  (PlayerRemoving / GameOver)                                 │
    ├─────────────────────────────────────────────────────────────┤
    │  5. SystemManager.DisposePlayer(player)                      │
    │  6. SystemManager.DisposeAll()                               │
    └─────────────────────────────────────────────────────────────┘
    
    USAGE:
    ```lua
    local SystemManager = require(Shared.utils.SystemManager)
    
    -- Register systems (pass the module tables)
    SystemManager.RegisterAll({
        PlantRenderSystem,
        ZombieRenderSystem,
        -- etc.
    })
    
    -- Initialize all systems (before Matter loop)
    local success = SystemManager.InitializeAll(world)
    if not success then
        Logger.Error("Bootstrap", "System initialization failed")
        return
    end
    
    -- Get Matter-compatible systems for scheduling
    local matterSystems = SystemManager.GetMatterSystems()
    loop:scheduleSystems(matterSystems)
    loop:begin()
    
    -- Cleanup on player leave
    Players.PlayerRemoving:Connect(function(player)
        SystemManager.DisposePlayer(player)
    end)
    
    -- Cleanup on shutdown
    game:BindToClose(function()
        SystemManager.DisposeAll()
    end)
    ```
    
    SYSTEM CONTRACT:
    Systems should export:
    - priority: number (execution order, lower = earlier)
    - system: (world) -> () OR OnStep: (world, dt) -> ()  -- The Matter loop function
    - Init: (world) -> ()? -- Optional, called once before loop (can yield)
    - Dispose: (player: Player?) -> ()? -- Optional, cleanup function
    - API: {}? -- Optional, external interface
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sift = require(Packages.Sift)
local Logger = require(Shared.utils.Logger)

-- Types
export type SystemModule = {
	-- Required
	priority: number,
	system: ((world: any) -> ())?, -- Matter system function (original pattern)

	-- Lifecycle (optional)
	Init: ((world: any) -> ())?,
	Dispose: ((player: Player?) -> ())?,

	-- External API (optional)
	API: { [string]: any }?,

	-- Metadata
	_name: string?,
}

export type SystemEntry = {
	name: string,
	module: SystemModule,
	initialized: boolean,
	initTime: number?,
}

-- State
local _systems: { SystemEntry } = {}
local _systemsByName: { [string]: SystemEntry } = {}
local _world: any = nil
local _isInitialized = false

local SystemManager = {}

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

--[[
    Register a single system.
    @param systemModule The system module table
    @param name Optional name override (defaults to script name or "Unknown")
]]
function SystemManager.Register(systemModule: SystemModule, name: string?)
	local systemName = name or systemModule._name or "UnnamedSystem"

	if _systemsByName[systemName] then
		Logger.Warn("SystemManager", `System '{systemName}' already registered, skipping`)
		return
	end

	local entry: SystemEntry = {
		name = systemName,
		module = systemModule,
		initialized = false,
		initTime = nil,
	}

	_systems = Sift.Array.push(_systems, entry)
	_systemsByName[systemName] = entry

	Logger.Debug("SystemManager", `Registered system: {systemName}`, {
		priority = systemModule.priority or 0,
		hasInit = systemModule.Init ~= nil,
		hasDispose = systemModule.Dispose ~= nil,
		hasAPI = systemModule.API ~= nil,
	})
end

--[[
    Register multiple systems at once.
    @param systems Array of {module: SystemModule, name: string} or just SystemModule
]]
function SystemManager.RegisterAll(systems: { any })
	for _, entry in systems do
		if type(entry) == "table" then
			if entry.module then
				-- {module = X, name = "Y"} format
				SystemManager.Register(entry.module, entry.name)
			elseif entry.priority ~= nil then
				-- Direct module format
				SystemManager.Register(entry, entry._name)
			end
		end
	end

	-- Sort by priority after all registrations
	_systems = Sift.Array.sort(_systems, function(a, b)
		local priorityA = a.module.priority or 0
		local priorityB = b.module.priority or 0
		return priorityA < priorityB
	end)

	Logger.Info("SystemManager", `Registered {#_systems} systems`)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--[[
    Initialize all registered systems.
    This is the ONLY place where systems can yield (WaitForChild, etc.)
    
    @param world The Matter world instance
    @param timeout Max time per system init (default 10s)
    @return success: boolean
]]
function SystemManager.InitializeAll(world: any, timeout: number?): boolean
	if _isInitialized then
		Logger.Warn("SystemManager", "Already initialized, skipping")
		return true
	end

	_world = world
	local maxTimeout = timeout or 10
	local totalStart = os.clock()
	local failedSystems: { string } = {}

	Logger.Info("SystemManager", `Initializing {#_systems} systems...`)

	for _, entry in _systems do
		local initFn = entry.module.Init

		if initFn then
			local startTime = os.clock()
			local completed = false
			local initError: string? = nil

			-- Use task.spawn so yielding functions (task.wait, WaitForChild) work properly
			task.spawn(function()
				local success, err = pcall(function()
					initFn(world)
				end)

				if not success then
					initError = tostring(err)
				end
				completed = true
			end)

			-- Wait for completion with timeout
			local elapsed = 0
			while not completed and elapsed < maxTimeout do
				task.wait(0.1)
				elapsed += 0.1
			end

			if not completed then
				Logger.Error("SystemManager", `Init timeout for '{entry.name}' ({maxTimeout}s)`)
				failedSystems = Sift.Array.push(failedSystems, entry.name)
			elseif initError then
				Logger.Error("SystemManager", `Init failed for '{entry.name}': {initError}`)
				failedSystems = Sift.Array.push(failedSystems, entry.name)
			else
				entry.initialized = true
				entry.initTime = os.clock() - startTime
				Logger.Debug(
					"SystemManager",
					`Initialized '{entry.name}' in {string.format("%.2f", (entry.initTime or 0) * 1000)}ms`
				)
			end
		else
			-- No Init function = already initialized
			entry.initialized = true
			entry.initTime = 0
		end
	end

	local totalTime = os.clock() - totalStart

	if #failedSystems > 0 then
		Logger.Error(
			"SystemManager",
			`Failed to initialize {#failedSystems} systems: {table.concat(failedSystems, ", ")}`
		)
		return false
	end

	_isInitialized = true
	Logger.Info("SystemManager", `All systems initialized in {string.format("%.2f", totalTime * 1000)}ms`)

	return true
end

--------------------------------------------------------------------------------
-- Runtime (Matter Integration)
--------------------------------------------------------------------------------

--[[
    Get Matter-compatible system tables for scheduling.
    Returns array of {system = fn, priority = n} for Matter.Loop:scheduleSystems()
]]
function SystemManager.GetMatterSystems(): { any }
	local matterSystems: { any } = {}

	for _, entry in _systems do
		local systemFn = entry.module.system

		if systemFn then
			matterSystems = Sift.Array.push(matterSystems, {
				system = systemFn,
				priority = entry.module.priority or 0,
			})
		else
			Logger.Warn("SystemManager", `System '{entry.name}' has no system function, skipping`)
		end
	end

	return matterSystems
end

--------------------------------------------------------------------------------
-- Disposal
--------------------------------------------------------------------------------

--[[
    Clean up player-specific state in all systems.
    Call this on Players.PlayerRemoving.
    
    @param player The player who is leaving
]]
function SystemManager.DisposePlayer(player: Player)
	Logger.Debug("SystemManager", `Disposing player state: {player.Name}`)

	for _, entry in _systems do
		local disposeFn = entry.module.Dispose

		if disposeFn then
			local success, errorMsg = pcall(function()
				disposeFn(player)
			end)

			if not success then
				Logger.Warn("SystemManager", `Dispose failed for '{entry.name}' (player {player.Name}): {errorMsg}`)
			end
		end
	end
end

--[[
    Clean up all systems (full shutdown).
    Call this on game:BindToClose or match end.
]]
function SystemManager.DisposeAll()
	Logger.Info("SystemManager", "Disposing all systems...")

	-- Dispose in reverse priority order (cleanup high-level before low-level)
	for i = #_systems, 1, -1 do
		local entry = _systems[i]
		local disposeFn = entry.module.Dispose

		if disposeFn then
			local success, errorMsg = pcall(function()
				disposeFn(nil) -- nil = full cleanup
			end)

			if not success then
				Logger.Warn("SystemManager", `Dispose failed for '{entry.name}': {errorMsg}`)
			else
				Logger.Debug("SystemManager", `Disposed '{entry.name}'`)
			end
		end

		entry.initialized = false
	end

	_isInitialized = false
	Logger.Info("SystemManager", "All systems disposed")
end

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

--[[
    Get a system by name (for inter-system communication via API).
    
    @param name System name
    @return SystemEntry or nil
]]
function SystemManager.GetSystem(name: string): SystemEntry?
	return _systemsByName[name]
end

--[[
    Get a system's API by name.
    
    @param name System name
    @return API table or nil
]]
function SystemManager.GetAPI(name: string): { [string]: any }?
	local entry = _systemsByName[name]
	return entry and entry.module.API
end

--[[
    Check if all systems are initialized.
]]
function SystemManager.IsInitialized(): boolean
	return _isInitialized
end

--[[
    Get initialization stats for debugging.
]]
function SystemManager.GetStats(): {
	totalSystems: number,
	initializedSystems: number,
	systemTimes: { [string]: number },
}
	local stats = {
		totalSystems = #_systems,
		initializedSystems = 0,
		systemTimes = {},
	}

	for _, entry in _systems do
		if entry.initialized then
			stats.initializedSystems += 1
		end
		if entry.initTime then
			stats.systemTimes[entry.name] = entry.initTime
		end
	end

	return stats
end

--[[
    Reset all state (for testing or re-initialization).
]]
function SystemManager.Reset()
	SystemManager.DisposeAll()
	table.clear(_systems)
	table.clear(_systemsByName)
	_world = nil
	_isInitialized = false
end

return SystemManager
