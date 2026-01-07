--!strict
--[[
	SelectionState.luau - Client-side plant selection state
	
	Manages which plant card is currently selected.
	Used by CardDeck UI and GhostPreviewSystem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local SelectionState = {}

-- Fusion scope for reactive values
local scope = Fusion.scoped({})

-- Currently selected plant type (nil = nothing selected)
SelectionState.SelectedPlant = Fusion.Value(scope, nil :: string?)

-- Shovel mode active (mutually exclusive with plant selection)
SelectionState.ShovelMode = Fusion.Value(scope, false)

-- Card cooldowns: PlantType -> timestamp when available again
SelectionState.Cooldowns = Fusion.Value(scope, {} :: {[string]: number})

-- Player's sun count (synced from server)
SelectionState.SunCount = Fusion.Value(scope, 50) -- Start with 50 sun

--[[
	Select a plant card
	@param plantType string? - Plant type to select, nil to deselect
]]
function SelectionState.Select(plantType: string?)
	-- Deactivate shovel mode when selecting a plant
	if plantType then
		SelectionState.ShovelMode:set(false)
	end
	SelectionState.SelectedPlant:set(plantType)
end

--[[
	Toggle shovel mode
]]
function SelectionState.ToggleShovel()
	local currentShovel = Fusion.peek(SelectionState.ShovelMode)
	if currentShovel then
		SelectionState.ShovelMode:set(false)
	else
		-- Deselect plant and activate shovel
		SelectionState.SelectedPlant:set(nil)
		SelectionState.ShovelMode:set(true)
	end
end

--[[
	Check if shovel mode is active
	@return boolean
]]
function SelectionState.IsShovelActive(): boolean
	return Fusion.peek(SelectionState.ShovelMode)
end

--[[
	Deactivate shovel mode
]]
function SelectionState.DeactivateShovel()
	SelectionState.ShovelMode:set(false)
end

--[[
	Check if a plant type is on cooldown
	@param plantType string - Plant type to check
	@return boolean - True if on cooldown
]]
function SelectionState.IsOnCooldown(plantType: string): boolean
	local cooldowns = Fusion.peek(SelectionState.Cooldowns)
	local cooldownEnd = cooldowns[plantType]
	if not cooldownEnd then
		return false
	end
	return tick() < cooldownEnd
end

--[[
	Start cooldown for a plant type
	@param plantType string - Plant type
	@param duration number - Cooldown duration in seconds
]]
function SelectionState.StartCooldown(plantType: string, duration: number)
	local cooldowns = Fusion.peek(SelectionState.Cooldowns)
	local newCooldowns = table.clone(cooldowns)
	newCooldowns[plantType] = tick() + duration
	SelectionState.Cooldowns:set(newCooldowns)
end

--[[
	Cancel a cooldown (used when placement fails and needs refund)
	@param plantType string - Plant type to cancel cooldown for
]]
function SelectionState.CancelCooldown(plantType: string)
	local cooldowns = Fusion.peek(SelectionState.Cooldowns)
	local newCooldowns = table.clone(cooldowns)
	newCooldowns[plantType] = nil
	SelectionState.Cooldowns:set(newCooldowns)
end

--[[
	Get remaining cooldown time
	@param plantType string - Plant type to check
	@return number - Seconds remaining (0 if ready)
]]
function SelectionState.GetCooldownRemaining(plantType: string): number
	local cooldowns = Fusion.peek(SelectionState.Cooldowns)
	local cooldownEnd = cooldowns[plantType]
	if not cooldownEnd then
		return 0
	end
	return math.max(0, cooldownEnd - tick())
end

--[[
	Check if player can afford a plant
	@param cost number - Plant cost
	@return boolean - True if can afford
]]
function SelectionState.CanAfford(cost: number): boolean
	return Fusion.peek(SelectionState.SunCount) >= cost
end

--[[
	Deduct sun (optimistic update, server confirms)
	@param amount number - Amount to deduct
]]
function SelectionState.DeductSun(amount: number)
	local current = Fusion.peek(SelectionState.SunCount)
	SelectionState.SunCount:set(math.max(0, current - amount))
end

--[[
	Add sun
	@param amount number - Amount to add
]]
function SelectionState.AddSun(amount: number)
	local current = Fusion.peek(SelectionState.SunCount)
	SelectionState.SunCount:set(current + amount)
end

--[[
	Set sun count (from server sync)
	@param amount number - New sun total
]]
function SelectionState.SetSun(amount: number)
	SelectionState.SunCount:set(amount)
end

return SelectionState
