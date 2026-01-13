--!strict
--[[
	PadLogicHandler.luau - Pure logic for teleport pad operations
	
	Location: src/shared/handlers/lobby/
	
	Handles:
	- Join validation logic
	- Leave validation logic
	- Countdown decision logic
	- Teleport validation
	
	This is a STATELESS module. It operates on data passed to it.
	LobbyService calls these functions and handles state/networking.
]]

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type PadConfig = {
	PadId: string,
	WorldId: string,
	Difficulty: string,
	MinPlayers: number,
	MaxPlayers: number,
	CountdownDuration: number,
	SpawnPosition: Vector3,
	TriggerPart: BasePart?,
	IsValid: boolean,
}

export type JoinValidation = {
	CanJoin: boolean,
	Reason: string?,
}

export type LeaveResult = {
	DidLeave: boolean,
	PreviousPadId: string?,
}

export type CountdownDecision = {
	ShouldStart: boolean,
	ShouldCancel: boolean,
	Reason: string?,
}

local PadLogicHandler = {}

--------------------------------------------------------------------------------
-- JOIN VALIDATION
--------------------------------------------------------------------------------

--[[
	Validate if a player can join a pad.
	
	@param config PadConfig - The pad configuration
	@param currentPlayerCount number - Current players on this pad
	@param playerCurrentPadId string? - Pad the player is currently on (if any)
	@return JoinValidation
]]
function PadLogicHandler.ValidateJoin(
	config: PadConfig,
	currentPlayerCount: number,
	playerCurrentPadId: string?
): JoinValidation
	-- Already on this pad?
	if playerCurrentPadId == config.PadId then
		return {
			CanJoin = false,
			Reason = "AlreadyOnPad",
		}
	end
	
	-- Pad is full?
	if currentPlayerCount >= config.MaxPlayers then
		return {
			CanJoin = false,
			Reason = "PadFull",
		}
	end
	
	-- Pad config invalid?
	if not config.IsValid then
		return {
			CanJoin = false,
			Reason = "InvalidPadConfig",
		}
	end
	
	return {
		CanJoin = true,
	}
end

--[[
	Check if player needs to leave current pad before joining new one.
	
	@param currentPadId string? - Player's current pad
	@param targetPadId string - Pad player wants to join
	@return boolean - True if player should leave current pad first
]]
function PadLogicHandler.ShouldLeaveCurrentPad(currentPadId: string?, targetPadId: string): boolean
	return currentPadId ~= nil and currentPadId ~= targetPadId
end

--------------------------------------------------------------------------------
-- COUNTDOWN LOGIC
--------------------------------------------------------------------------------

--[[
	Decide what countdown action to take based on player count.
	
	@param playerCount number - Current player count on pad
	@param minPlayers number - Minimum players to start countdown
	@param isCountdownActive boolean - Whether countdown is currently running
	@return CountdownDecision
]]
function PadLogicHandler.DecideCountdownAction(
	playerCount: number,
	minPlayers: number,
	isCountdownActive: boolean
): CountdownDecision
	-- Should we start countdown?
	if playerCount >= minPlayers and not isCountdownActive then
		return {
			ShouldStart = true,
			ShouldCancel = false,
			Reason = "MinPlayersReached",
		}
	end
	
	-- Should we cancel countdown?
	if playerCount < minPlayers and isCountdownActive then
		return {
			ShouldStart = false,
			ShouldCancel = true,
			Reason = "BelowMinPlayers",
		}
	end
	
	-- No action needed
	return {
		ShouldStart = false,
		ShouldCancel = false,
	}
end

--------------------------------------------------------------------------------
-- TELEPORT VALIDATION
--------------------------------------------------------------------------------

--[[
	Validate if a pad group can be teleported.
	
	@param playerCount number - Number of players on pad
	@param minPlayers number - Minimum required
	@return boolean, string? - canTeleport, reason
]]
function PadLogicHandler.CanTeleportGroup(playerCount: number, minPlayers: number): (boolean, string?)
	if playerCount < 1 then
		return false, "NoPlayers"
	end
	
	-- Note: We allow teleport even if below min, as countdown should handle this
	-- This is a safety check for edge cases
	return true, nil
end

--------------------------------------------------------------------------------
-- SPAWN POSITION
--------------------------------------------------------------------------------

--[[
	Calculate spawn offset for a player index (for spreading players).
	
	@param playerIndex number - Player's index in queue (1-based)
	@param totalPlayers number - Total players in queue
	@param spreadRadius number - Radius to spread players
	@return Vector3 - Offset from center spawn position
]]
function PadLogicHandler.CalculateSpawnOffset(playerIndex: number, totalPlayers: number, spreadRadius: number): Vector3
	if totalPlayers <= 1 then
		return Vector3.zero
	end
	
	-- Spread players in a circle
	local angle = (2 * math.pi * (playerIndex - 1)) / totalPlayers
	local x = math.cos(angle) * spreadRadius
	local z = math.sin(angle) * spreadRadius
	
	return Vector3.new(x, 0, z)
end

--[[
	Calculate the CFrame to teleport a player to after leaving a pad.
	
	@param leavePartPosition Vector3 - Position of the LeaveRoomPart
	@param heightOffset number? - Height offset above the part (default 3)
	@return CFrame
]]
function PadLogicHandler.CalculateLeaveCFrame(leavePartPosition: Vector3, heightOffset: number?): CFrame
	local offset = heightOffset or 3
	return CFrame.new(leavePartPosition + Vector3.new(0, offset, 0))
end

return PadLogicHandler
