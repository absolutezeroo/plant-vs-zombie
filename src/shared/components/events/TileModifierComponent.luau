--!strict
--[[
	TileModifierComponent.luau - Tile/Cell modifier for map events
	
	Represents a temporary or permanent effect on a grid cell.
	Used for: craters, fire zones, ice patches, acid pools, tombstones, etc.
	
	MODIFIER TYPES:
	- Crater: Blocks planting (permanent until cleared)
	- Fire: Damages zombies walking through
	- Ice: Slows zombies walking through
	- Acid: Damages zombies and plants
	- Tombstone: Blocks planting, can spawn zombies
	- Blessed: Speeds up plants, buffs damage
	- Water: Allows aquatic plants only
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

-- ============================================
-- MODIFIER TYPES
-- ============================================

export type ModifierType = 
	| "Crater"      -- Blocks planting (DoomShroom)
	| "Fire"        -- Damages zombies (Jalapeno aftermath)
	| "Ice"         -- Slows zombies (Ice-shroom aftermath)
	| "Acid"        -- Damages everything (Zombie ability)
	| "Tombstone"   -- Blocks planting, may spawn zombies
	| "Blessed"     -- Buffs plants (Plantern aura)
	| "Water"       -- Water tile (aquatic plants only)
	| "Fog"         -- Reduces visibility
	| "Custom"      -- Generic modifier

-- ============================================
-- COMPONENT DEFINITION
-- ============================================

return Matter.component("TileModifier", {
	-- Grid position
	Column = 1,
	Lane = 1,
	
	-- Modifier type
	ModifierType = "Crater" :: ModifierType,
	
	-- Timing (nil = permanent)
	Duration = nil :: number?, -- Total duration in seconds
	AppliedAt = 0, -- os.clock() when applied
	
	-- Effects on zombies
	DamagePerSecond = 0, -- Damage dealt to zombies on tile
	SpeedMultiplier = 1.0, -- 0.5 = 50% slow, 1.5 = 50% faster
	
	-- Effects on plants
	PlantDamagePerSecond = 0, -- Damage to plants on tile
	PlantDamageBonus = 0, -- Multiplicative bonus (1.2 = +20%)
	PlantAttackSpeedBonus = 0, -- Multiplicative bonus
	
	-- Placement rules
	BlocksPlacement = false, -- Prevents planting
	AllowsAquatic = false, -- Allows Lily Pad, Cattail, etc.
	
	-- Visuals
	VisualAssetName = "", -- Asset name in ReplicatedStorage.Assets.TileEffects
	VisualColor = Color3.new(1, 1, 1), -- Tint color
	VisualTransparency = 0.5, -- Visual transparency
	
	-- Stacking
	Priority = 0, -- Higher priority effects override lower
	StackGroup = "", -- Modifiers in same group don't stack
})
