--!strict
--[[
	init.luau - Plant Ability Handlers Initialization
	
	Loads and registers all plant ability handlers.
	Import this module to ensure all abilities are registered.
	
	USAGE:
	local PlantAbilities = require(Shared.handlers.abilities)
	-- Now all handlers are registered with PlantAbilityRegistry
	
	-- Access registry:
	local handler = PlantAbilities.Registry.GetHandler("Chomper")
	
	-- Access specific ability module (for special APIs like CobCannon.Fire):
	PlantAbilities.CobCannon.Fire(world, plantId, column, lane, time)
]]

-- Load registry first
local PlantAbilityRegistry = require(script.PlantAbilityRegistry)

-- Load all ability handlers (they auto-register on require)
local ChomperAbility = require(script.ChomperAbility)
local SquashAbility = require(script.SquashAbility)
local CobCannonAbility = require(script.CobCannonAbility)

-- ============================================
-- EXPORT
-- ============================================

return {
	-- Main registry
	Registry = PlantAbilityRegistry,
	
	-- Individual handlers (for direct access if needed)
	Chomper = ChomperAbility,
	Squash = SquashAbility,
	CobCannon = CobCannonAbility,
}
