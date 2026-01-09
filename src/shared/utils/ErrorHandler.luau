--!strict
--[[
	ErrorHandler.lua - Hybrid fail-fast (dev) + graceful degradation (prod)
	
	In Studio: Fail fast to catch bugs during development
	In Production: Log errors but keep game running
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sift = require(Packages.Sift)

local ErrorHandler = {}

-- Detect environment
local isStudio: boolean = RunService:IsStudio()
local isClient: boolean = RunService:IsClient()
local realm: string = if isClient then "Client" else "Server"

-- Error severity levels
export type Severity = "Critical" | "Important" | "Minor"

-- Error record for logging
export type ErrorRecord = {
	Message: string,
	Context: string,
	Severity: Severity,
	Timestamp: number,
	Realm: string,
}

-- Recent errors for debugging (not persistent)
local recentErrors: {ErrorRecord} = {}
local MAX_RECENT_ERRORS = 50

--[[
	Report an error with severity classification
	
	@param message - Human readable error description
	@param context - Where the error occurred (system name, function)
	@param severity - Error importance level
]]
function ErrorHandler.Report(message: string, context: string, severity: Severity)
	local record: ErrorRecord = {
		Message = message,
		Context = context,
		Severity = severity,
		Timestamp = os.time(),
		Realm = realm,
	}
	
	-- Store recent errors (circular buffer with Sift)
	recentErrors = Sift.Array.push(recentErrors, record)
	if #recentErrors > MAX_RECENT_ERRORS then
		recentErrors = Sift.Array.removeIndex(recentErrors, 1)
	end
	
	-- Format output
	local prefix = `[{severity}][{realm}][{context}]`
	local fullMessage = `{prefix} {message}`
	
	-- Severity-based handling
	if severity == "Critical" then
		-- Always log critical errors
		warn(fullMessage)
		
		-- In Studio, also throw to halt execution
		if isStudio then
			error(fullMessage, 2)
		end
	elseif severity == "Important" then
		warn(fullMessage)
	else -- Minor
		-- Only log minor errors in Studio
		if isStudio then
			print(fullMessage)
		end
	end
end

--[[
	Wrap a function call with error handling
	Returns (success: boolean, result: any)
	
	@param fn - Function to execute
	@param context - Context string for error reporting
	@return success, result or error message
]]
function ErrorHandler.Try<T>(fn: () -> T, context: string): (boolean, T | string)
	local success, result = pcall(fn)
	
	if not success then
		-- Result is error message when pcall fails
		ErrorHandler.Report(tostring(result), context, "Important")
	end
	
	return success, result
end

--[[
	Get recent errors for debugging
	@return Array of recent error records
]]
function ErrorHandler.GetRecentErrors(): {ErrorRecord}
	return recentErrors
end

--[[
	Clear recent errors (useful after reviewing)
]]
function ErrorHandler.ClearRecentErrors()
	table.clear(recentErrors)
end

--[[
	Check if running in development environment
	@return true if in Roblox Studio
]]
function ErrorHandler.IsDevMode(): boolean
	return isStudio
end

return ErrorHandler
