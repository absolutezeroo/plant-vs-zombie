--!strict
--[[
	MutationData.luau - Plant Mutation System Configuration
	
	Defines all available mutations that can be applied to plants.
	Mutations add new behaviors and effects rather than just stat boosts.
	
	Inspired by PvZ2's plant leveling system but with unique mutations.
]]

-- Mutation effect structure
export type MutationEffects = {
	-- Stat modifiers (multiplicative)
	DamageBonus: number?,        -- 1.2 = +20% damage
	HealthBonus: number?,        -- 1.5 = +50% health
	CooldownReduction: number?,  -- 0.8 = -20% cooldown
	AttackSpeedBonus: number?,   -- 1.3 = +30% attack speed
	
	-- Fire effects
	AddsBurnDamage: boolean?,
	BurnDamagePerSecond: number?,
	BurnDuration: number?,
	
	-- Ice effects
	AddsFreeze: boolean?,
	FreezeChance: number?,       -- 0.2 = 20% chance
	FreezeDuration: number?,
	EnhancedSlow: number?,       -- Extra slow percent (stacks with base)
	
	-- Electric effects
	AddsChainLightning: boolean?,
	ChainCount: number?,         -- Number of zombies to chain to
	ChainDamage: number?,        -- Damage per chain
	ChainRange: number?,         -- Studs to search for chain targets
	
	-- Toxic/Poison effects
	AddsPoisonCloud: boolean?,
	PoisonRadius: number?,
	PoisonDamagePerSecond: number?,
	PoisonDuration: number?,
	
	-- Shadow effects
	AddsLifesteal: boolean?,
	LifestealPercent: number?,   -- 0.15 = 15% of damage heals plant
	
	-- Solar effects
	AddsSunOnKill: boolean?,
	SunPerKill: number?,
	SunDropChance: number?,      -- For non-kill sun drops
	
	-- Reinforced effects
	ExtraHealth: number?,        -- Flat health bonus
	DamageReduction: number?,    -- 0.2 = 20% damage reduction
	
	-- Primal effects
	SplashDamage: boolean?,
	SplashRadius: number?,
	SplashPercent: number?,      -- 0.3 = 30% of damage to nearby
	Knockback: number?,          -- Studs to push back
}

-- Main mutation info structure
export type MutationInfo = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,                -- rbxassetid://...
	Color: Color3,               -- Theme color for UI and effects
	
	-- Costs and requirements
	Cost: number,                -- Coins to purchase
	RequiredLevel: number,       -- Player level minimum
	
	-- Effects
	Effects: MutationEffects,
	
	-- Compatibility
	CompatibleCategories: {string},  -- {"Attacker", "Defender", "Producer", "Special"}
	IncompatibleWith: {string}?,     -- Mutation IDs that can't be combined
	MaxPerPlant: number?,            -- Max instances of this mutation per plant (default 1)
}

-- All available mutations
local Mutations: {[string]: MutationInfo} = {
	-- ============================================
	-- FIRE MUTATIONS - Burn damage over time
	-- ============================================
	
	Fire = {
		Id = "Fire",
		Name = "🔥 Feu",
		Description = "Les attaques infligent des brûlures (5 dps pendant 3s)",
		Icon = "rbxassetid://0", -- TODO: Add real asset
		Color = Color3.fromRGB(255, 100, 0),
		
		Cost = 500,
		RequiredLevel = 5,
		
		Effects = {
			AddsBurnDamage = true,
			BurnDamagePerSecond = 5,
			BurnDuration = 3,
		},
		
		CompatibleCategories = {"Attacker"},
		IncompatibleWith = {"Ice"}, -- Can't be both fire and ice
	},
	
	Inferno = {
		Id = "Inferno",
		Name = "🔥 Inferno",
		Description = "Brûlures intenses (10 dps pendant 4s) et +15% dégâts",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(255, 50, 0),
		
		Cost = 1200,
		RequiredLevel = 25,
		
		Effects = {
			DamageBonus = 1.15,
			AddsBurnDamage = true,
			BurnDamagePerSecond = 10,
			BurnDuration = 4,
		},
		
		CompatibleCategories = {"Attacker"},
		IncompatibleWith = {"Ice", "Frost", "Fire"}, -- Replaces Fire
	},
	
	-- ============================================
	-- ICE MUTATIONS - Slow and freeze effects
	-- ============================================
	
	Ice = {
		Id = "Ice",
		Name = "❄️ Glace",
		Description = "20% de chance de geler les zombies pendant 2s",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(100, 200, 255),
		
		Cost = 500,
		RequiredLevel = 5,
		
		Effects = {
			AddsFreeze = true,
			FreezeChance = 0.20,
			FreezeDuration = 2,
		},
		
		CompatibleCategories = {"Attacker"},
		IncompatibleWith = {"Fire"},
	},
	
	Frost = {
		Id = "Frost",
		Name = "❄️ Givre",
		Description = "35% freeze, slow amélioré de 25%",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(150, 220, 255),
		
		Cost = 1100,
		RequiredLevel = 20,
		
		Effects = {
			AddsFreeze = true,
			FreezeChance = 0.35,
			FreezeDuration = 2.5,
			EnhancedSlow = 0.25,
		},
		
		CompatibleCategories = {"Attacker"},
		IncompatibleWith = {"Fire", "Inferno", "Ice"},
	},
	
	-- ============================================
	-- ELECTRIC MUTATIONS - Chain lightning
	-- ============================================
	
	Electric = {
		Id = "Electric",
		Name = "⚡ Électrique",
		Description = "Les attaques sautent à 2 zombies proches (50% dégâts)",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(255, 255, 100),
		
		Cost = 750,
		RequiredLevel = 10,
		
		Effects = {
			AddsChainLightning = true,
			ChainCount = 2,
			ChainDamage = 0.5, -- 50% of original damage
			ChainRange = 8,
		},
		
		CompatibleCategories = {"Attacker"},
	},
	
	Tesla = {
		Id = "Tesla",
		Name = "⚡ Tesla",
		Description = "Chain à 4 zombies (75% dégâts) et +20% vitesse d'attaque",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(200, 255, 50),
		
		Cost = 1500,
		RequiredLevel = 30,
		
		Effects = {
			AttackSpeedBonus = 1.20,
			AddsChainLightning = true,
			ChainCount = 4,
			ChainDamage = 0.75,
			ChainRange = 10,
		},
		
		CompatibleCategories = {"Attacker"},
		IncompatibleWith = {"Electric"},
	},
	
	-- ============================================
	-- TOXIC MUTATIONS - Poison and area denial
	-- ============================================
	
	Toxic = {
		Id = "Toxic",
		Name = "☠️ Toxique",
		Description = "Libère un nuage de poison à la mort (3 dps, 4s, rayon 6)",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(100, 255, 100),
		
		Cost = 600,
		RequiredLevel = 8,
		
		Effects = {
			AddsPoisonCloud = true,
			PoisonRadius = 6,
			PoisonDamagePerSecond = 3,
			PoisonDuration = 4,
		},
		
		CompatibleCategories = {"Defender", "Special"},
	},
	
	Venomous = {
		Id = "Venomous",
		Name = "☠️ Venimeux",
		Description = "Nuage mortel (8 dps, 5s, rayon 8) et +30% santé",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(50, 200, 50),
		
		Cost = 1300,
		RequiredLevel = 28,
		
		Effects = {
			HealthBonus = 1.30,
			AddsPoisonCloud = true,
			PoisonRadius = 8,
			PoisonDamagePerSecond = 8,
			PoisonDuration = 5,
		},
		
		CompatibleCategories = {"Defender", "Special"},
		IncompatibleWith = {"Toxic"},
	},
	
	-- ============================================
	-- SHADOW MUTATIONS - Lifesteal and dark effects
	-- ============================================
	
	Shadow = {
		Id = "Shadow",
		Name = "🌑 Ombre",
		Description = "15% des dégâts infligés soignent la plante",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(80, 40, 120),
		
		Cost = 800,
		RequiredLevel = 12,
		
		Effects = {
			AddsLifesteal = true,
			LifestealPercent = 0.15,
		},
		
		CompatibleCategories = {"Attacker"},
	},
	
	Void = {
		Id = "Void",
		Name = "🌑 Vide",
		Description = "25% lifesteal et +20% dégâts",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(40, 20, 80),
		
		Cost = 1600,
		RequiredLevel = 35,
		
		Effects = {
			DamageBonus = 1.20,
			AddsLifesteal = true,
			LifestealPercent = 0.25,
		},
		
		CompatibleCategories = {"Attacker"},
		IncompatibleWith = {"Shadow"},
	},
	
	-- ============================================
	-- SOLAR MUTATIONS - Sun generation
	-- ============================================
	
	Solar = {
		Id = "Solar",
		Name = "☀️ Solaire",
		Description = "Génère 10 sun par zombie tué",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(255, 220, 50),
		
		Cost = 700,
		RequiredLevel = 10,
		
		Effects = {
			AddsSunOnKill = true,
			SunPerKill = 10,
		},
		
		CompatibleCategories = {"Attacker"},
	},
	
	Radiant = {
		Id = "Radiant",
		Name = "☀️ Radiant",
		Description = "20 sun par kill, +15% vitesse d'attaque",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(255, 240, 100),
		
		Cost = 1400,
		RequiredLevel = 32,
		
		Effects = {
			AttackSpeedBonus = 1.15,
			AddsSunOnKill = true,
			SunPerKill = 20,
		},
		
		CompatibleCategories = {"Attacker"},
		IncompatibleWith = {"Solar"},
	},
	
	-- ============================================
	-- REINFORCED MUTATIONS - Defense and durability
	-- ============================================
	
	Reinforced = {
		Id = "Reinforced",
		Name = "🛡️ Renforcé",
		Description = "+50% santé et -15% dégâts reçus",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(150, 150, 170),
		
		Cost = 400,
		RequiredLevel = 3,
		
		Effects = {
			HealthBonus = 1.50,
			DamageReduction = 0.15,
		},
		
		CompatibleCategories = {"Defender", "Producer"},
	},
	
	Fortified = {
		Id = "Fortified",
		Name = "🛡️ Fortifié",
		Description = "+100% santé et -30% dégâts reçus",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(100, 100, 130),
		
		Cost = 1000,
		RequiredLevel = 22,
		
		Effects = {
			HealthBonus = 2.00,
			DamageReduction = 0.30,
		},
		
		CompatibleCategories = {"Defender", "Producer"},
		IncompatibleWith = {"Reinforced"},
	},
	
	-- ============================================
	-- PRIMAL MUTATIONS - Raw power and splash
	-- ============================================
	
	Primal = {
		Id = "Primal",
		Name = "🦴 Primitif",
		Description = "+25% dégâts avec splash (30% dégâts, rayon 4)",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(180, 140, 100),
		
		Cost = 900,
		RequiredLevel = 15,
		
		Effects = {
			DamageBonus = 1.25,
			SplashDamage = true,
			SplashRadius = 4,
			SplashPercent = 0.30,
		},
		
		CompatibleCategories = {"Attacker", "Special"},
	},
	
	Savage = {
		Id = "Savage",
		Name = "🦴 Sauvage",
		Description = "+40% dégâts, splash (50%, rayon 6) et knockback",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(140, 100, 60),
		
		Cost = 1800,
		RequiredLevel = 40,
		
		Effects = {
			DamageBonus = 1.40,
			SplashDamage = true,
			SplashRadius = 6,
			SplashPercent = 0.50,
			Knockback = 2,
		},
		
		CompatibleCategories = {"Attacker", "Special"},
		IncompatibleWith = {"Primal"},
	},
	
	-- ============================================
	-- UTILITY MUTATIONS - Cooldown and speed
	-- ============================================
	
	Swift = {
		Id = "Swift",
		Name = "💨 Véloce",
		Description = "-25% cooldown de placement",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(200, 230, 255),
		
		Cost = 350,
		RequiredLevel = 5,
		
		Effects = {
			CooldownReduction = 0.75, -- 25% reduction
		},
		
		CompatibleCategories = {"Attacker", "Defender", "Producer", "Special"},
	},
	
	Hasty = {
		Id = "Hasty",
		Name = "💨 Hâtif",
		Description = "-40% cooldown et +10% vitesse d'attaque",
		Icon = "rbxassetid://0",
		Color = Color3.fromRGB(150, 200, 255),
		
		Cost = 850,
		RequiredLevel = 18,
		
		Effects = {
			CooldownReduction = 0.60,
			AttackSpeedBonus = 1.10,
		},
		
		CompatibleCategories = {"Attacker", "Defender", "Producer", "Special"},
		IncompatibleWith = {"Swift"},
	},
}

-- Freeze tables
table.freeze(Mutations)

-- Helper functions
local MutationData = {}

-- Get all mutations
function MutationData.GetAll(): {[string]: MutationInfo}
	return Mutations
end

-- Get a specific mutation by ID
function MutationData.Get(mutationId: string): MutationInfo?
	return Mutations[mutationId]
end

-- Check if a mutation is compatible with a plant category
function MutationData.IsCompatibleWith(mutationId: string, category: string): boolean
	local mutation = Mutations[mutationId]
	if not mutation then return false end
	
	for _, compatibleCategory in mutation.CompatibleCategories do
		if compatibleCategory == category then
			return true
		end
	end
	return false
end

-- Check if two mutations can be combined
function MutationData.AreCompatible(mutationId1: string, mutationId2: string): boolean
	local mutation1 = Mutations[mutationId1]
	local mutation2 = Mutations[mutationId2]
	
	if not mutation1 or not mutation2 then return false end
	
	-- Check if mutation1 is incompatible with mutation2
	if mutation1.IncompatibleWith then
		for _, incompatible in mutation1.IncompatibleWith do
			if incompatible == mutationId2 then
				return false
			end
		end
	end
	
	-- Check if mutation2 is incompatible with mutation1
	if mutation2.IncompatibleWith then
		for _, incompatible in mutation2.IncompatibleWith do
			if incompatible == mutationId1 then
				return false
			end
		end
	end
	
	return true
end

-- Get mutations available for a player level
function MutationData.GetAvailableForLevel(playerLevel: number): {MutationInfo}
	local available = {}
	for _, mutation in Mutations do
		if mutation.RequiredLevel <= playerLevel then
			table.insert(available, mutation)
		end
	end
	return available
end

-- Get mutations compatible with a category
function MutationData.GetForCategory(category: string): {MutationInfo}
	local compatible = {}
	for _, mutation in Mutations do
		if MutationData.IsCompatibleWith(mutation.Id, category) then
			table.insert(compatible, mutation)
		end
	end
	return compatible
end

-- Calculate total mutation effects for a plant
function MutationData.CalculateCombinedEffects(mutationIds: {string}): MutationEffects
	local combined: MutationEffects = {
		DamageBonus = 1,
		HealthBonus = 1,
		CooldownReduction = 1,
		AttackSpeedBonus = 1,
	}
	
	for _, mutationId in mutationIds do
		local mutation = Mutations[mutationId]
		if mutation then
			local effects = mutation.Effects
			
			-- Multiplicative bonuses
			if effects.DamageBonus then
				combined.DamageBonus = (combined.DamageBonus or 1) * effects.DamageBonus
			end
			if effects.HealthBonus then
				combined.HealthBonus = (combined.HealthBonus or 1) * effects.HealthBonus
			end
			if effects.CooldownReduction then
				combined.CooldownReduction = (combined.CooldownReduction or 1) * effects.CooldownReduction
			end
			if effects.AttackSpeedBonus then
				combined.AttackSpeedBonus = (combined.AttackSpeedBonus or 1) * effects.AttackSpeedBonus
			end
			
			-- Boolean effects (last one wins, but they shouldn't conflict due to IncompatibleWith)
			if effects.AddsBurnDamage then
				combined.AddsBurnDamage = true
				combined.BurnDamagePerSecond = effects.BurnDamagePerSecond
				combined.BurnDuration = effects.BurnDuration
			end
			if effects.AddsFreeze then
				combined.AddsFreeze = true
				combined.FreezeChance = effects.FreezeChance
				combined.FreezeDuration = effects.FreezeDuration
				combined.EnhancedSlow = effects.EnhancedSlow
			end
			if effects.AddsChainLightning then
				combined.AddsChainLightning = true
				combined.ChainCount = effects.ChainCount
				combined.ChainDamage = effects.ChainDamage
				combined.ChainRange = effects.ChainRange
			end
			if effects.AddsPoisonCloud then
				combined.AddsPoisonCloud = true
				combined.PoisonRadius = effects.PoisonRadius
				combined.PoisonDamagePerSecond = effects.PoisonDamagePerSecond
				combined.PoisonDuration = effects.PoisonDuration
			end
			if effects.AddsLifesteal then
				combined.AddsLifesteal = true
				combined.LifestealPercent = effects.LifestealPercent
			end
			if effects.AddsSunOnKill then
				combined.AddsSunOnKill = true
				combined.SunPerKill = effects.SunPerKill
			end
			if effects.DamageReduction then
				-- Additive for damage reduction
				combined.DamageReduction = (combined.DamageReduction or 0) + effects.DamageReduction
			end
			if effects.ExtraHealth then
				combined.ExtraHealth = (combined.ExtraHealth or 0) + effects.ExtraHealth
			end
			if effects.SplashDamage then
				combined.SplashDamage = true
				combined.SplashRadius = effects.SplashRadius
				combined.SplashPercent = effects.SplashPercent
			end
			if effects.Knockback then
				combined.Knockback = effects.Knockback
			end
		end
	end
	
	return combined
end

return MutationData
