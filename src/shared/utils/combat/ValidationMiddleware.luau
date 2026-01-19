--!strict
--[[
	ValidationMiddleware.luau - Centralized validation hooks system
	
	PURPOSE:
	Provides a middleware layer for intercepting and validating actions
	BEFORE they are executed. Validators can block actions by returning false.
	
	ARCHITECTURE:
	- Validators are registered per action type with a priority
	- Lower priority = executed first
	- If ANY validator returns false, the action is blocked
	- All validators are synchronous (no yielding)
	
	USAGE:
	```lua
	-- Register a validator
	ValidationMiddleware.Register("PlacePlant", function(context)
		if context.PlantType == "CobCannon" and context.Lane == 5 then
			return false, "CobCannon cannot be placed on lane 5"
		end
		return true
	end, { Priority = 10, Id = "CobCannonLaneRestriction" })
	
	-- In system code
	local allowed, reason = ValidationMiddleware.Validate("PlacePlant", {
		Player = player,
		PlantType = plantType,
		Column = column,
		Lane = lane,
	})
	if not allowed then
		-- Handle rejection
		return
	end
	```
	
	ACTION TYPES:
	- "PlacePlant": { Player, PlantType, Column, Lane }
	- "ShovelPlant": { Player, Column, Lane, EntityId }
	- "SpendSun": { Player, Amount, Reason }
	- "StartWave": { WaveNumber, TotalWaves }
	- "UsePlantFood": { Player, TargetEntity, PlantType }
	- "CollectSun": { Player, SunEntityId, Amount }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

-- ============================================
-- TYPE DEFINITIONS
-- ============================================

export type ValidationContext = {
	[string]: any,
}

export type ValidationResult = boolean

export type ValidatorCallback = (context: ValidationContext) -> (ValidationResult, string?)

export type ValidatorOptions = {
	Priority: number?, -- Lower = executed first (default: 100)
	Id: string?, -- Optional identifier for debugging/removal
	Description: string?, -- Human-readable description
}

type ValidatorEntry = {
	Id: string,
	Callback: ValidatorCallback,
	Priority: number,
	Description: string?,
}

-- ============================================
-- STATE
-- ============================================

local _validators: { [string]: { ValidatorEntry } } = {}
local _validatorCount = 0

-- ============================================
-- PRIVATE HELPERS
-- ============================================

local function sortValidators(actionType: string)
	local validators = _validators[actionType]
	if validators then
		table.sort(validators, function(a, b)
			return a.Priority < b.Priority
		end)
	end
end

local function generateId(): string
	_validatorCount += 1
	return `Validator_{_validatorCount}`
end

-- ============================================
-- PUBLIC API
-- ============================================

local ValidationMiddleware = {}

--[[
	Register a validator for an action type.
	
	@param actionType string - The action to validate ("PlacePlant", "SpendSun", etc.)
	@param callback ValidatorCallback - Function that returns (allowed, reason?)
	@param options ValidatorOptions? - Optional configuration
	@return string - The validator ID (for removal)
]]
function ValidationMiddleware.Register(
	actionType: string,
	callback: ValidatorCallback,
	options: ValidatorOptions?
): string
	local opts = options or {}
	local id = opts.Id or generateId()
	local priority = opts.Priority or 100
	
	if not _validators[actionType] then
		_validators[actionType] = {}
	end
	
	-- Check for duplicate ID
	for _, entry in _validators[actionType] do
		if entry.Id == id then
			Logger.Warn("ValidationMiddleware", `Validator '{id}' already exists for '{actionType}', replacing`)
			ValidationMiddleware.Unregister(actionType, id)
			break
		end
	end
	
	local entry: ValidatorEntry = {
		Id = id,
		Callback = callback,
		Priority = priority,
		Description = opts.Description,
	}
	
	table.insert(_validators[actionType], entry)
	sortValidators(actionType)
	
	Logger.Debug("ValidationMiddleware", `Registered validator '{id}' for '{actionType}' (priority {priority})`)
	
	return id
end

--[[
	Unregister a validator by ID.
	
	@param actionType string - The action type
	@param validatorId string - The validator ID to remove
	@return boolean - True if removed
]]
function ValidationMiddleware.Unregister(actionType: string, validatorId: string): boolean
	local validators = _validators[actionType]
	if not validators then
		return false
	end
	
	for i, entry in validators do
		if entry.Id == validatorId then
			table.remove(validators, i)
			Logger.Debug("ValidationMiddleware", `Unregistered validator '{validatorId}' from '{actionType}'`)
			return true
		end
	end
	
	return false
end

--[[
	Validate an action against all registered validators.
	
	@param actionType string - The action to validate
	@param context ValidationContext - Data passed to validators
	@return (boolean, string?) - (allowed, reason if rejected)
]]
function ValidationMiddleware.Validate(actionType: string, context: ValidationContext): (boolean, string?)
	local validators = _validators[actionType]
	
	-- No validators = allowed
	if not validators or #validators == 0 then
		return true, nil
	end
	
	-- Run all validators in priority order
	for _, entry in validators do
		local success, result, reason = pcall(entry.Callback, context)
		
		if not success then
			Logger.Error("ValidationMiddleware", `Validator '{entry.Id}' threw error: {result}`)
			-- Continue to next validator on error (fail-open)
			continue
		end
		
		if result == false then
			local rejectReason = reason or `Blocked by validator '{entry.Id}'`
			Logger.Debug("ValidationMiddleware", `Action '{actionType}' rejected: {rejectReason}`)
			return false, rejectReason
		end
	end
	
	return true, nil
end

--[[
	Check if any validators are registered for an action type.
	
	@param actionType string - The action type
	@return boolean
]]
function ValidationMiddleware.HasValidators(actionType: string): boolean
	local validators = _validators[actionType]
	return validators ~= nil and #validators > 0
end

--[[
	Get the count of validators for an action type.
	
	@param actionType string - The action type
	@return number
]]
function ValidationMiddleware.GetValidatorCount(actionType: string): number
	local validators = _validators[actionType]
	return if validators then #validators else 0
end

--[[
	Clear all validators for an action type.
	
	@param actionType string - The action type
]]
function ValidationMiddleware.ClearValidators(actionType: string)
	_validators[actionType] = nil
	Logger.Debug("ValidationMiddleware", `Cleared all validators for '{actionType}'`)
end

--[[
	Clear ALL validators (for testing/reset).
]]
function ValidationMiddleware.ClearAll()
	table.clear(_validators)
	Logger.Debug("ValidationMiddleware", "Cleared all validators")
end

--[[
	Get debug info about registered validators.
	
	@return { [string]: { { Id: string, Priority: number, Description: string? } } }
]]
function ValidationMiddleware.GetDebugInfo(): { [string]: { { Id: string, Priority: number, Description: string? } } }
	local info = {}
	
	for actionType, validators in _validators do
		info[actionType] = {}
		for _, entry in validators do
			table.insert(info[actionType], {
				Id = entry.Id,
				Priority = entry.Priority,
				Description = entry.Description,
			})
		end
	end
	
	return info
end

-- ============================================
-- PREDEFINED ACTION TYPES (Documentation)
-- ============================================

ValidationMiddleware.ActionTypes = table.freeze({
	PlacePlant = "PlacePlant",
	ShovelPlant = "ShovelPlant",
	SpendSun = "SpendSun",
	StartWave = "StartWave",
	UsePlantFood = "UsePlantFood",
	CollectSun = "CollectSun",
})

return table.freeze(ValidationMiddleware)
