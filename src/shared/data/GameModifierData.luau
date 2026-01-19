--!strict
--[[
	GameModifierData.luau - Global Game Modifiers Configuration
	
	Defines modifiers that can be applied to an entire match.
	Used for: Daily Challenges, Special Events, Custom Games, Practice Mode.
	
	Each modifier alters specific game stats through Operations:
	- "Mul" = Multiply the base value (1.5 = +50%)
	- "Add" = Add to the base value
	- "Set" = Override the base value completely
	
	Modifiers can be stacked unless marked as incompatible.
]]

-- ============================================
-- TYPE DEFINITIONS
-- ============================================

export type ModifierEffect = {
	Target: string, -- Stat to modify (see VALID_TARGETS below)
	Op: "Mul" | "Add" | "Set", -- Operation type
	Value: number, -- Value to apply
}

export type GameModifier = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string, -- rbxassetid://...
	Category: "Buff" | "Debuff" | "Neutral", -- For UI coloring
	
	-- Effects to apply
	Effects: { ModifierEffect },
	
	-- Compatibility
	IncompatibleWith: { string }?, -- Modifier IDs that can't be combined
	RequiresMode: { string }?, -- Only available in these modes (nil = all)
}

-- ============================================
-- VALID TARGETS (for reference)
-- ============================================
--[[
	Player Resources:
	- "StartingSun" - Sun at match start
	- "SunDropAmount" - Sun from sky drops
	- "SunProductionRate" - Sunflower production speed
	- "CoinDropRate" - Coin drop frequency
	
	Plant Stats:
	- "PlantCooldown" - Placement cooldown
	- "PlantCost" - Sun cost for plants
	- "PlantHealth" - All plant health
	- "PlantDamage" - All plant damage
	- "PlantAttackSpeed" - Attack speed multiplier
	
	Zombie Stats:
	- "ZombieHealth" - All zombie health
	- "ZombieSpeed" - Movement speed
	- "ZombieDamage" - Attack damage
	- "ZombieSpawnRate" - Wave spawn frequency
	
	Game Rules:
	- "WaveCount" - Number of waves
	- "PreparationTime" - Time before first wave
	- "FinalWaveMultiplier" - Boss wave difficulty
]]

-- ============================================
-- MODIFIER DEFINITIONS
-- ============================================

local Modifiers: { [string]: GameModifier } = {
	-- ========== BUFF MODIFIERS ==========
	
	DoubleSun = {
		Id = "DoubleSun",
		Name = "☀️ Double Sun",
		Description = "Sky sun drops are worth 2x",
		Icon = "rbxassetid://0",
		Category = "Buff",
		Effects = {
			{ Target = "SunDropAmount", Op = "Mul", Value = 2 },
		},
		IncompatibleWith = { "NoSunDrops", "HalfSun" },
	},
	
	NoCooldown = {
		Id = "NoCooldown",
		Name = "⚡ No Cooldown",
		Description = "Plants have no placement cooldown",
		Icon = "rbxassetid://0",
		Category = "Buff",
		Effects = {
			{ Target = "PlantCooldown", Op = "Set", Value = 0 },
		},
	},
	
	FreePlants = {
		Id = "FreePlants",
		Name = "🆓 Free Plants",
		Description = "All plants cost 0 sun",
		Icon = "rbxassetid://0",
		Category = "Buff",
		Effects = {
			{ Target = "PlantCost", Op = "Set", Value = 0 },
		},
		IncompatibleWith = { "ExpensivePlants" },
	},
	
	ToughPlants = {
		Id = "ToughPlants",
		Name = "🛡️ Tough Plants",
		Description = "Plants have 50% more health",
		Icon = "rbxassetid://0",
		Category = "Buff",
		Effects = {
			{ Target = "PlantHealth", Op = "Mul", Value = 1.5 },
		},
		IncompatibleWith = { "FragilePlants" },
	},
	
	PowerShots = {
		Id = "PowerShots",
		Name = "💥 Power Shots",
		Description = "Plant attacks deal 25% more damage",
		Icon = "rbxassetid://0",
		Category = "Buff",
		Effects = {
			{ Target = "PlantDamage", Op = "Mul", Value = 1.25 },
		},
	},
	
	StartingSunBoost = {
		Id = "StartingSunBoost",
		Name = "🌅 Head Start",
		Description = "Start with 200 extra sun",
		Icon = "rbxassetid://0",
		Category = "Buff",
		Effects = {
			{ Target = "StartingSun", Op = "Add", Value = 200 },
		},
	},
	
	ExtendedPrep = {
		Id = "ExtendedPrep",
		Name = "⏰ Extended Preparation",
		Description = "Double preparation time before waves",
		Icon = "rbxassetid://0",
		Category = "Buff",
		Effects = {
			{ Target = "PreparationTime", Op = "Mul", Value = 2 },
		},
		IncompatibleWith = { "NoPrep", "QuickStart" },
	},
	
	-- ========== DEBUFF MODIFIERS ==========
	
	FastZombies = {
		Id = "FastZombies",
		Name = "💨 Fast Zombies",
		Description = "Zombies move 50% faster",
		Icon = "rbxassetid://0",
		Category = "Debuff",
		Effects = {
			{ Target = "ZombieSpeed", Op = "Mul", Value = 1.5 },
		},
		IncompatibleWith = { "SlowZombies" },
	},
	
	ToughZombies = {
		Id = "ToughZombies",
		Name = "💪 Tough Zombies",
		Description = "Zombies have 50% more health",
		Icon = "rbxassetid://0",
		Category = "Debuff",
		Effects = {
			{ Target = "ZombieHealth", Op = "Mul", Value = 1.5 },
		},
		IncompatibleWith = { "WeakZombies" },
	},
	
	AggressiveZombies = {
		Id = "AggressiveZombies",
		Name = "😤 Aggressive Zombies",
		Description = "Zombies deal 25% more damage",
		Icon = "rbxassetid://0",
		Category = "Debuff",
		Effects = {
			{ Target = "ZombieDamage", Op = "Mul", Value = 1.25 },
		},
	},
	
	NoSunDrops = {
		Id = "NoSunDrops",
		Name = "🌑 No Sky Sun",
		Description = "No sun falls from the sky",
		Icon = "rbxassetid://0",
		Category = "Debuff",
		Effects = {
			{ Target = "SunDropAmount", Op = "Set", Value = 0 },
		},
		IncompatibleWith = { "DoubleSun", "HalfSun" },
	},
	
	HalfSun = {
		Id = "HalfSun",
		Name = "🌤️ Scarce Sun",
		Description = "Sky sun drops are worth 50% less",
		Icon = "rbxassetid://0",
		Category = "Debuff",
		Effects = {
			{ Target = "SunDropAmount", Op = "Mul", Value = 0.5 },
		},
		IncompatibleWith = { "DoubleSun", "NoSunDrops" },
	},
	
	ExpensivePlants = {
		Id = "ExpensivePlants",
		Name = "💰 Expensive Plants",
		Description = "All plants cost 50% more sun",
		Icon = "rbxassetid://0",
		Category = "Debuff",
		Effects = {
			{ Target = "PlantCost", Op = "Mul", Value = 1.5 },
		},
		IncompatibleWith = { "FreePlants" },
	},
	
	FragilePlants = {
		Id = "FragilePlants",
		Name = "🥀 Fragile Plants",
		Description = "Plants have 50% less health",
		Icon = "rbxassetid://0",
		Category = "Debuff",
		Effects = {
			{ Target = "PlantHealth", Op = "Mul", Value = 0.5 },
		},
		IncompatibleWith = { "ToughPlants" },
	},
	
	QuickStart = {
		Id = "QuickStart",
		Name = "⚡ Quick Start",
		Description = "No preparation time",
		Icon = "rbxassetid://0",
		Category = "Debuff",
		Effects = {
			{ Target = "PreparationTime", Op = "Set", Value = 0 },
		},
		IncompatibleWith = { "ExtendedPrep" },
	},
	
	ZombieSwarm = {
		Id = "ZombieSwarm",
		Name = "🧟 Zombie Swarm",
		Description = "Zombies spawn 50% faster",
		Icon = "rbxassetid://0",
		Category = "Debuff",
		Effects = {
			{ Target = "ZombieSpawnRate", Op = "Mul", Value = 1.5 },
		},
	},
	
	-- ========== NEUTRAL MODIFIERS ==========
	
	SlowZombies = {
		Id = "SlowZombies",
		Name = "🐢 Slow Zombies",
		Description = "Zombies move 30% slower but have 30% more health",
		Icon = "rbxassetid://0",
		Category = "Neutral",
		Effects = {
			{ Target = "ZombieSpeed", Op = "Mul", Value = 0.7 },
			{ Target = "ZombieHealth", Op = "Mul", Value = 1.3 },
		},
		IncompatibleWith = { "FastZombies" },
	},
	
	WeakZombies = {
		Id = "WeakZombies",
		Name = "🤕 Weak Zombies",
		Description = "Zombies have 50% less health but move 20% faster",
		Icon = "rbxassetid://0",
		Category = "Neutral",
		Effects = {
			{ Target = "ZombieHealth", Op = "Mul", Value = 0.5 },
			{ Target = "ZombieSpeed", Op = "Mul", Value = 1.2 },
		},
		IncompatibleWith = { "ToughZombies" },
	},
	
	GlassCannon = {
		Id = "GlassCannon",
		Name = "🔮 Glass Cannon",
		Description = "Plants deal 2x damage but have 50% less health",
		Icon = "rbxassetid://0",
		Category = "Neutral",
		Effects = {
			{ Target = "PlantDamage", Op = "Mul", Value = 2 },
			{ Target = "PlantHealth", Op = "Mul", Value = 0.5 },
		},
	},
	
	RapidFire = {
		Id = "RapidFire",
		Name = "🔥 Rapid Fire",
		Description = "Plants attack 50% faster but deal 25% less damage",
		Icon = "rbxassetid://0",
		Category = "Neutral",
		Effects = {
			{ Target = "PlantAttackSpeed", Op = "Mul", Value = 1.5 },
			{ Target = "PlantDamage", Op = "Mul", Value = 0.75 },
		},
	},
	
	LongGame = {
		Id = "LongGame",
		Name = "📜 Long Game",
		Description = "50% more waves but 50% more preparation time",
		Icon = "rbxassetid://0",
		Category = "Neutral",
		Effects = {
			{ Target = "WaveCount", Op = "Mul", Value = 1.5 },
			{ Target = "PreparationTime", Op = "Mul", Value = 1.5 },
		},
	},
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

--[[
	Get a modifier by ID
]]
local function GetModifier(modifierId: string): GameModifier?
	return Modifiers[modifierId]
end

--[[
	Get all modifiers in a category
]]
local function GetModifiersByCategory(category: "Buff" | "Debuff" | "Neutral"): { GameModifier }
	local result = {}
	for _, modifier in Modifiers do
		if modifier.Category == category then
			table.insert(result, modifier)
		end
	end
	return result
end

--[[
	Check if two modifiers are compatible
]]
local function AreCompatible(modifierId1: string, modifierId2: string): boolean
	local mod1 = Modifiers[modifierId1]
	local mod2 = Modifiers[modifierId2]
	
	if not mod1 or not mod2 then
		return false
	end
	
	-- Check mod1's incompatibility list
	if mod1.IncompatibleWith then
		for _, incompatibleId in mod1.IncompatibleWith do
			if incompatibleId == modifierId2 then
				return false
			end
		end
	end
	
	-- Check mod2's incompatibility list
	if mod2.IncompatibleWith then
		for _, incompatibleId in mod2.IncompatibleWith do
			if incompatibleId == modifierId1 then
				return false
			end
		end
	end
	
	return true
end

--[[
	Calculate the effective value for a stat with multiple modifiers applied.
	Order of operations: Set first (if any), then Add, then Mul
]]
local function CalculateEffectiveValue(
	baseValue: number,
	effects: { ModifierEffect }
): number
	local result = baseValue
	local hasSet = false
	local addTotal = 0
	local mulTotal = 1
	
	-- First pass: find Set operations (last one wins)
	for _, effect in effects do
		if effect.Op == "Set" then
			result = effect.Value
			hasSet = true
		end
	end
	
	-- If we had a Set, start from that value
	if hasSet then
		baseValue = result
	end
	
	-- Second pass: accumulate Add and Mul
	for _, effect in effects do
		if effect.Op == "Add" then
			addTotal = addTotal + effect.Value
		elseif effect.Op == "Mul" then
			mulTotal = mulTotal * effect.Value
		end
	end
	
	-- Apply: (base + adds) * muls
	result = (baseValue + addTotal) * mulTotal
	
	return result
end

--[[
	Get all effects for a specific target stat from a list of modifier IDs
]]
local function GetEffectsForTarget(
	modifierIds: { string },
	targetStat: string
): { ModifierEffect }
	local effects = {}
	
	for _, modifierId in modifierIds do
		local modifier = Modifiers[modifierId]
		if modifier then
			for _, effect in modifier.Effects do
				if effect.Target == targetStat then
					table.insert(effects, effect)
				end
			end
		end
	end
	
	return effects
end

-- ============================================
-- EXPORT
-- ============================================

table.freeze(Modifiers)

return {
	-- Data access
	Modifiers = Modifiers,
	GetModifier = GetModifier,
	GetModifiersByCategory = GetModifiersByCategory,
	
	-- Compatibility
	AreCompatible = AreCompatible,
	
	-- Calculation
	CalculateEffectiveValue = CalculateEffectiveValue,
	GetEffectsForTarget = GetEffectsForTarget,
}
