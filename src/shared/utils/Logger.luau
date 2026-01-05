--!strict
--[[
	Logger.lua - Structured logging with performance throttling
	
	RULES:
	- NEVER log inside loops or per-entity iteration
	- NEVER log every frame (max once per second for non-critical)
	- Use Debug() for hot paths (stripped in production)
	- Use throttled logging for monitoring (every 10 seconds)
]]

local RunService = game:GetService("RunService")

local Logger = {}

-- Environment detection
local isStudio: boolean = RunService:IsStudio()
local isClient: boolean = RunService:IsClient()
local realm: string = if isClient then "Client" else "Server"

-- Throttle tracking
local lastLogTime: {[string]: number} = {}

-- Log levels
export type LogLevel = "Debug" | "Info" | "Warn" | "Error"

--[[
	Internal logging function
]]
local function log(level: LogLevel, category: string, message: string, data: {[string]: any}?)
	local timestamp = os.date("%H:%M:%S")
	local prefix = `[{timestamp}][{level}][{realm}][{category}]`
	
	local output = `{prefix} {message}`
	
	-- Append data if provided
	if data then
		local dataStr = ""
		for key, value in data do
			dataStr = dataStr .. ` {key}={tostring(value)}`
		end
		output = output .. dataStr
	end
	
	if level == "Error" then
		warn(output)
	elseif level == "Warn" then
		warn(output)
	else
		print(output)
	end
end

--[[
	Debug log - ONLY outputs in Studio
	Use for development diagnostics, stripped in production
]]
function Logger.Debug(category: string, message: string, data: {[string]: any}?)
	if isStudio then
		log("Debug", category, message, data)
	end
end

--[[
	Info log - General information
	Use sparingly, never in hot paths
]]
function Logger.Info(category: string, message: string, data: {[string]: any}?)
	log("Info", category, message, data)
end

--[[
	Warning log - Potential issues
	Use for recoverable problems
]]
function Logger.Warn(category: string, message: string, data: {[string]: any}?)
	log("Warn", category, message, data)
end

--[[
	Error log - Serious problems
	Use with ErrorHandler for proper error tracking
]]
function Logger.Error(category: string, message: string, data: {[string]: any}?)
	log("Error", category, message, data)
end

--[[
	Throttled log - Only logs once per interval
	Use for monitoring (performance stats, memory usage)
	
	@param key - Unique key for throttle tracking
	@param intervalSeconds - Minimum seconds between logs
	@param level - Log level
	@param category - Log category
	@param message - Log message
	@param data - Optional structured data
	@return true if logged, false if throttled
]]
function Logger.Throttled(
	key: string,
	intervalSeconds: number,
	level: LogLevel,
	category: string,
	message: string,
	data: {[string]: any}?
): boolean
	local now = tick()
	local lastTime = lastLogTime[key] or 0
	
	if now - lastTime >= intervalSeconds then
		lastLogTime[key] = now
		log(level, category, message, data)
		return true
	end
	
	return false
end

--[[
	Performance log - Throttled to every 10 seconds by default
	Use for performance monitoring systems
]]
function Logger.Performance(category: string, message: string, data: {[string]: any}?)
	Logger.Throttled(`perf_{category}`, 10, "Info", category, message, data)
end

--[[
	Clear throttle state (useful for testing)
]]
function Logger.ResetThrottles()
	table.clear(lastLogTime)
end

return Logger
