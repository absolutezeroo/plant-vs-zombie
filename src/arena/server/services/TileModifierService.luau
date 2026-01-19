--!strict
--[[
	TileModifierService.luau - Server-side tile modifier management
	
	Provides API to add, remove, and query tile modifiers.
	Integrates with GridService for placement validation.
	
	USAGE:
	local TileModifierService = require(Server.services.TileModifierService)
	
	-- Add a temporary fire zone
	TileModifierService.AddModifier(3, 2, {
		ModifierType = "Fire",
		Duration = 5,
		DamagePerSecond = 10,
	})
	
	-- Check if placement is blocked
	local blocked = TileModifierService.HasBlockingModifier(3, 2)
	
	-- Get all modifiers on a cell
	local mods = TileModifierService.GetModifiers(3, 2)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.core.Logger)
local EntityPool = require(Shared.utils.ecs.EntityPool)

-- Network (lazy load)
local Network: any = nil
local function getNetwork()
	if not Network then
		Network = require(Shared.network.generated.server)
	end
	return Network
end

-- ============================================
-- TYPES
-- ============================================

export type ModifierData = {
	ModifierType: string,
	Duration: number?,
	DamagePerSecond: number?,
	SpeedMultiplier: number?,
	PlantDamagePerSecond: number?,
	PlantDamageBonus: number?,
	PlantAttackSpeedBonus: number?,
	BlocksPlacement: boolean?,
	AllowsAquatic: boolean?,
	VisualAssetName: string?,
	VisualColor: Color3?,
	VisualTransparency: number?,
	Priority: number?,
	StackGroup: string?,
}

-- ============================================
-- STATE
-- ============================================

local _world: any = nil
local _trove = Trove.new()
local _initialized = false

-- Index: _modifiersByCell[column][lane] = { entityId1, entityId2, ... }
local _modifiersByCell: { [number]: { [number]: { number } } } = {}

-- ============================================
-- PRIVATE HELPERS
-- ============================================

local function getCellKey(column: number, lane: number): string
	return `{column},{lane}`
end

local function ensureCellIndex(column: number, lane: number)
	if not _modifiersByCell[column] then
		_modifiersByCell[column] = {}
	end
	if not _modifiersByCell[column][lane] then
		_modifiersByCell[column][lane] = {}
	end
end

local function addToIndex(column: number, lane: number, entityId: number)
	ensureCellIndex(column, lane)
	table.insert(_modifiersByCell[column][lane], entityId)
end

local function removeFromIndex(column: number, lane: number, entityId: number)
	if not _modifiersByCell[column] or not _modifiersByCell[column][lane] then
		return
	end
	
	local list = _modifiersByCell[column][lane]
	for i, id in list do
		if id == entityId then
			table.remove(list, i)
			break
		end
	end
end

-- ============================================
-- PUBLIC API
-- ============================================

local TileModifierService = {}

--[[
	Initialize the service with world reference
]]
function TileModifierService.Init(world: any)
	if _initialized then
		Logger.Warn("TileModifierService", "Already initialized")
		return
	end
	
	_world = world
	_initialized = true
	
	Logger.Info("TileModifierService", "Initialized")
end

--[[
	Dispose and cleanup
]]
function TileModifierService.Dispose()
	_trove:Clean()
	table.clear(_modifiersByCell)
	_world = nil
	_initialized = false
	
	Logger.Debug("TileModifierService", "Disposed")
end

--[[
	Add a tile modifier
	Returns the entity ID of the created modifier
]]
function TileModifierService.AddModifier(column: number, lane: number, data: ModifierData): number?
	if not _world then
		Logger.Error("TileModifierService", "Not initialized")
		return nil
	end
	
	local currentTime = os.clock()
	
	-- Check for stacking rules
	if data.StackGroup and data.StackGroup ~= "" then
		local existing = TileModifierService.GetModifiersByStackGroup(column, lane, data.StackGroup)
		if #existing > 0 then
			-- Replace existing modifier in same stack group
			for _, entityId in existing do
				TileModifierService.RemoveModifier(entityId)
			end
		end
	end
	
	-- Create component data
	local componentData = {
		Column = column,
		Lane = lane,
		ModifierType = data.ModifierType,
		Duration = data.Duration,
		AppliedAt = currentTime,
		DamagePerSecond = data.DamagePerSecond or 0,
		SpeedMultiplier = data.SpeedMultiplier or 1.0,
		PlantDamagePerSecond = data.PlantDamagePerSecond or 0,
		PlantDamageBonus = data.PlantDamageBonus or 0,
		PlantAttackSpeedBonus = data.PlantAttackSpeedBonus or 0,
		BlocksPlacement = data.BlocksPlacement or false,
		AllowsAquatic = data.AllowsAquatic or false,
		VisualAssetName = data.VisualAssetName or "",
		VisualColor = data.VisualColor or Color3.new(1, 1, 1),
		VisualTransparency = data.VisualTransparency or 0.5,
		Priority = data.Priority or 0,
		StackGroup = data.StackGroup or "",
	}
	
	-- Spawn entity
	local entityId = _world:spawn(Components.TileModifierComponent(componentData))
	
	-- Add to index
	addToIndex(column, lane, entityId)
	
	-- Broadcast to clients
	getNetwork().TileModifierApplied.FireAll({
		EntityId = entityId,
		Column = column,
		Lane = lane,
		ModifierType = data.ModifierType,
		Duration = data.Duration,
		VisualAssetName = data.VisualAssetName or "",
		VisualColorR = componentData.VisualColor.R,
		VisualColorG = componentData.VisualColor.G,
		VisualColorB = componentData.VisualColor.B,
		VisualTransparency = componentData.VisualTransparency,
	})
	
	Logger.Debug("TileModifierService", `Added {data.ModifierType} modifier at ({column}, {lane})`)
	
	return entityId
end

--[[
	Remove a tile modifier by entity ID
]]
function TileModifierService.RemoveModifier(entityId: number): boolean
	if not _world or not _world:contains(entityId) then
		return false
	end
	
	local modifier = _world:get(entityId, Components.TileModifierComponent)
	if not modifier then
		return false
	end
	
	-- Remove from index
	removeFromIndex(modifier.Column, modifier.Lane, entityId)
	
	-- Broadcast removal
	getNetwork().TileModifierExpired.FireAll({
		EntityId = entityId,
		Column = modifier.Column,
		Lane = modifier.Lane,
	})
	
	-- Despawn entity
	_world:despawn(entityId)
	
	Logger.Debug("TileModifierService", `Removed modifier {entityId} from ({modifier.Column}, {modifier.Lane})`)
	
	return true
end

--[[
	Get all modifiers on a cell
]]
function TileModifierService.GetModifiers(column: number, lane: number): { any }
	if not _world then
		return {}
	end
	
	if not _modifiersByCell[column] or not _modifiersByCell[column][lane] then
		return {}
	end
	
	local result = {}
	for _, entityId in _modifiersByCell[column][lane] do
		if _world:contains(entityId) then
			local modifier = _world:get(entityId, Components.TileModifierComponent)
			if modifier then
				table.insert(result, {
					EntityId = entityId,
					Modifier = modifier,
				})
			end
		end
	end
	
	return result
end

--[[
	Get modifiers by stack group
]]
function TileModifierService.GetModifiersByStackGroup(column: number, lane: number, stackGroup: string): { number }
	local modifiers = TileModifierService.GetModifiers(column, lane)
	local result = {}
	
	for _, data in modifiers do
		if data.Modifier.StackGroup == stackGroup then
			table.insert(result, data.EntityId)
		end
	end
	
	return result
end

--[[
	Check if any modifier blocks placement on a cell
]]
function TileModifierService.HasBlockingModifier(column: number, lane: number): boolean
	local modifiers = TileModifierService.GetModifiers(column, lane)
	
	for _, data in modifiers do
		if data.Modifier.BlocksPlacement then
			return true
		end
	end
	
	return false
end

--[[
	Check if cell allows aquatic plants
]]
function TileModifierService.AllowsAquatic(column: number, lane: number): boolean
	local modifiers = TileModifierService.GetModifiers(column, lane)
	
	for _, data in modifiers do
		if data.Modifier.AllowsAquatic then
			return true
		end
	end
	
	return false
end

--[[
	Get the effective speed multiplier for a cell (product of all modifiers)
]]
function TileModifierService.GetSpeedMultiplier(column: number, lane: number): number
	local modifiers = TileModifierService.GetModifiers(column, lane)
	local multiplier = 1.0
	
	for _, data in modifiers do
		multiplier = multiplier * data.Modifier.SpeedMultiplier
	end
	
	return multiplier
end

--[[
	Get the total DPS for zombies on a cell
]]
function TileModifierService.GetZombieDamagePerSecond(column: number, lane: number): number
	local modifiers = TileModifierService.GetModifiers(column, lane)
	local totalDPS = 0
	
	for _, data in modifiers do
		totalDPS = totalDPS + data.Modifier.DamagePerSecond
	end
	
	return totalDPS
end

--[[
	Get the total DPS for plants on a cell
]]
function TileModifierService.GetPlantDamagePerSecond(column: number, lane: number): number
	local modifiers = TileModifierService.GetModifiers(column, lane)
	local totalDPS = 0
	
	for _, data in modifiers do
		totalDPS = totalDPS + data.Modifier.PlantDamagePerSecond
	end
	
	return totalDPS
end

--[[
	Clear all modifiers on a cell
]]
function TileModifierService.ClearCell(column: number, lane: number)
	local modifiers = TileModifierService.GetModifiers(column, lane)
	
	for _, data in modifiers do
		TileModifierService.RemoveModifier(data.EntityId)
	end
end

--[[
	Clear all modifiers of a specific type
]]
function TileModifierService.ClearByType(modifierType: string)
	if not _world then
		return
	end
	
	local toRemove = {}
	
	for id, modifier in _world:query(Components.TileModifierComponent) do
		if modifier.ModifierType == modifierType then
			table.insert(toRemove, id)
		end
	end
	
	for _, entityId in toRemove do
		TileModifierService.RemoveModifier(entityId)
	end
	
	Logger.Debug("TileModifierService", `Cleared {#toRemove} modifiers of type {modifierType}`)
end

--[[
	Clear all modifiers (for arena reset)
]]
function TileModifierService.ClearAll()
	if not _world then
		return
	end
	
	local toRemove = {}
	
	for id in _world:query(Components.TileModifierComponent) do
		table.insert(toRemove, id)
	end
	
	for _, entityId in toRemove do
		TileModifierService.RemoveModifier(entityId)
	end
	
	table.clear(_modifiersByCell)
	
	Logger.Info("TileModifierService", `Cleared all {#toRemove} tile modifiers`)
end

-- ============================================
-- PRESET MODIFIERS (convenience functions)
-- ============================================

--[[
	Add a crater (permanent, blocks planting)
]]
function TileModifierService.AddCrater(column: number, lane: number): number?
	return TileModifierService.AddModifier(column, lane, {
		ModifierType = "Crater",
		BlocksPlacement = true,
		VisualAssetName = "Crater",
		VisualColor = Color3.fromRGB(50, 50, 50),
		VisualTransparency = 0.3,
		StackGroup = "ground",
	})
end

--[[
	Add a fire zone (temporary, damages zombies)
]]
function TileModifierService.AddFireZone(column: number, lane: number, duration: number, dps: number): number?
	return TileModifierService.AddModifier(column, lane, {
		ModifierType = "Fire",
		Duration = duration,
		DamagePerSecond = dps,
		VisualAssetName = "Fire",
		VisualColor = Color3.fromRGB(255, 100, 0),
		VisualTransparency = 0.4,
		StackGroup = "ground",
	})
end

--[[
	Add an ice zone (temporary, slows zombies)
]]
function TileModifierService.AddIceZone(column: number, lane: number, duration: number, slowPercent: number): number?
	return TileModifierService.AddModifier(column, lane, {
		ModifierType = "Ice",
		Duration = duration,
		SpeedMultiplier = 1.0 - slowPercent,
		VisualAssetName = "Ice",
		VisualColor = Color3.fromRGB(150, 200, 255),
		VisualTransparency = 0.5,
		StackGroup = "ground",
	})
end

--[[
	Add a tombstone (blocks planting, can be destroyed)
]]
function TileModifierService.AddTombstone(column: number, lane: number): number?
	return TileModifierService.AddModifier(column, lane, {
		ModifierType = "Tombstone",
		BlocksPlacement = true,
		VisualAssetName = "Tombstone",
		VisualColor = Color3.fromRGB(80, 80, 80),
		VisualTransparency = 0,
		Priority = 10, -- High priority
		StackGroup = "obstacle",
	})
end

-- ============================================
-- EXPORT
-- ============================================

return TileModifierService
