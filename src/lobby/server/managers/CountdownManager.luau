--!strict
--[[
    CountdownManager.luau - Manages countdown timers for teleport pads
    
    Single Responsibility: Handle countdown state and timing for each pad
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)
local LobbyConfig = require(Shared.config.LobbyConfig)

export type CountdownState = {
	RemainingTime: number,
	TotalTime: number,
	Thread: thread?,
}

export type CountdownCallbacks = {
	OnTick: ((padId: string, remainingTime: number) -> ())?,
	OnComplete: ((padId: string) -> ())?,
	OnCancel: ((padId: string) -> ())?,
}

export type CountdownManager = {
	StartCountdown: (self: CountdownManager, padId: string, duration: number, callbacks: CountdownCallbacks) -> boolean,
	CancelCountdown: (self: CountdownManager, padId: string) -> boolean,
	GetRemainingTime: (self: CountdownManager, padId: string) -> number,
	IsCountdownActive: (self: CountdownManager, padId: string) -> boolean,
	Cleanup: (self: CountdownManager) -> (),
}

local CountdownManager = {}
CountdownManager.__index = CountdownManager

-- State
local _countdowns: { [string]: CountdownState } = {}

function CountdownManager.new(): CountdownManager
	local self = setmetatable({}, CountdownManager)
	return self
end

-- Start a countdown for a pad
function CountdownManager:StartCountdown(padId: string, duration: number, callbacks: CountdownCallbacks): boolean
	-- Cancel existing countdown if any
	if _countdowns[padId] then
		self:CancelCountdown(padId)
	end

	local countdownTime = duration or LobbyConfig.COUNTDOWN_DURATION

	local state: CountdownState = {
		RemainingTime = countdownTime,
		TotalTime = countdownTime,
		Thread = nil,
	}

	_countdowns[padId] = state

	Logger.Debug("CountdownManager", `Starting countdown for pad {padId}: {countdownTime}s`)

	-- Start countdown thread
	state.Thread = task.spawn(function()
		while state.RemainingTime > 0 do
			-- Notify tick
			if callbacks.OnTick then
				callbacks.OnTick(padId, state.RemainingTime)
			end

			task.wait(1)
			state.RemainingTime -= 1
		end

		-- Countdown complete
		Logger.Debug("CountdownManager", `Countdown complete for pad {padId}`)
		_countdowns[padId] = nil

		if callbacks.OnComplete then
			callbacks.OnComplete(padId)
		end
	end)

	return true
end

-- Cancel a countdown
function CountdownManager:CancelCountdown(padId: string): boolean
	local state = _countdowns[padId]
	if not state then
		return false
	end

	-- Stop thread
	if state.Thread then
		task.cancel(state.Thread)
	end

	_countdowns[padId] = nil
	Logger.Debug("CountdownManager", `Countdown cancelled for pad {padId}`)

	return true
end

-- Get remaining time for a pad countdown
function CountdownManager:GetRemainingTime(padId: string): number
	local state = _countdowns[padId]
	if state then
		return state.RemainingTime
	end
	return 0
end

-- Check if countdown is active
function CountdownManager:IsCountdownActive(padId: string): boolean
	return _countdowns[padId] ~= nil
end

-- Cleanup all countdowns
function CountdownManager:Cleanup()
	for padId, state in pairs(_countdowns) do
		if state.Thread then
			task.cancel(state.Thread)
		end
	end
	table.clear(_countdowns)
end

-- Singleton instance
local _instance: CountdownManager? = nil

function CountdownManager.GetInstance(): CountdownManager
	if not _instance then
		_instance = CountdownManager.new()
	end
	return _instance
end

return CountdownManager
