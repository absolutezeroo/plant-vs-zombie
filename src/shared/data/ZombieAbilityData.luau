--!strict
--[[
	ZombieAbilityData.luau - Zombie Abilities Registry
	
	Defines reusable zombie abilities that can be composed onto zombie types.
	Separates behavior logic from ZombieData stats.
	
	Abilities can define:
	- Immunities: What effects the zombie is immune to
	- Lifecycle Hooks: OnSpawn, OnDamaged, OnHalfHealth, OnDeath, OnEat
	- Passive Effects: Continuous effects while alive
	
	This allows creating new zombies by combining existing abilities
	without duplicating code in the zombie systems.
]]

-- ============================================
-- TYPE DEFINITIONS
-- ============================================

-- Immunity types that can be applied to zombies
export type ImmunityType = 
	| "Slow"        -- Immune to slow effects (Snow Pea, Winter Melon)
	| "Freeze"      -- Immune to freeze effects (Ice-shroom)
	| "Burn"        -- Immune to fire damage (Torchwood-enhanced)
	| "Poison"      -- Immune to poison/toxic effects
	| "Knockback"   -- Immune to knockback effects
	| "InstantKill" -- Immune to instant-kill (Chomper, Squash) - for bosses
	| "Hypnosis"    -- Immune to Hypno-shroom
	| "Butter"      -- Immune to Kernel-pult butter stun

-- Ability hook context passed to handlers
export type AbilityContext = {
	EntityId: number,
	World: any, -- Matter world
	ZombieType: string,
	CurrentHealth: number,
	MaxHealth: number,
	DamageReceived: number?, -- For OnDamaged hook
	DamageSource: string?, -- "Projectile", "Explosion", "Trap", etc.
	KillerEntityId: number?, -- For OnDeath hook
}

-- Ability definition
export type ZombieAbility = {
	Id: string,
	Name: string,
	Description: string,
	
	-- Immunities granted by this ability
	Immunities: { ImmunityType }?,
	
	-- Lifecycle hooks (return true to cancel default behavior)
	OnSpawn: ((ctx: AbilityContext) -> boolean?)?,
	OnDamaged: ((ctx: AbilityContext) -> boolean?)?,
	OnHalfHealth: ((ctx: AbilityContext) -> boolean?)?,
	OnQuarterHealth: ((ctx: AbilityContext) -> boolean?)?,
	OnDeath: ((ctx: AbilityContext) -> boolean?)?,
	OnEat: ((ctx: AbilityContext, targetEntityId: number) -> boolean?)?,
	
	-- Passive effect (called every frame while zombie is alive)
	OnTick: ((ctx: AbilityContext, deltaTime: number) -> ())?,
}

-- ============================================
-- ABILITY DEFINITIONS
-- ============================================

local Abilities: { [string]: ZombieAbility } = {
	
	-- ========== IMMUNITY ABILITIES ==========
	
	IcyBody = {
		Id = "IcyBody",
		Name = "Icy Body",
		Description = "Immune to slow and freeze effects",
		Immunities = { "Slow", "Freeze" },
	},
	
	FireResistant = {
		Id = "FireResistant",
		Name = "Fire Resistant",
		Description = "Immune to fire and burn damage",
		Immunities = { "Burn" },
	},
	
	ToxicResistant = {
		Id = "ToxicResistant",
		Name = "Toxic Resistant",
		Description = "Immune to poison effects",
		Immunities = { "Poison" },
	},
	
	Immovable = {
		Id = "Immovable",
		Name = "Immovable",
		Description = "Cannot be knocked back",
		Immunities = { "Knockback" },
	},
	
	BossImmunity = {
		Id = "BossImmunity",
		Name = "Boss Immunity",
		Description = "Immune to instant-kill effects",
		Immunities = { "InstantKill", "Hypnosis" },
	},
	
	MindShield = {
		Id = "MindShield",
		Name = "Mind Shield",
		Description = "Immune to hypnosis effects",
		Immunities = { "Hypnosis" },
	},
	
	ButterProof = {
		Id = "ButterProof",
		Name = "Butter Proof",
		Description = "Immune to butter stun",
		Immunities = { "Butter" },
	},
	
	-- ========== BEHAVIOR ABILITIES ==========
	
	--[[
		Vault - Jump over the first plant encountered
		Used by: Pole Vaulter
	]]
	Vault = {
		Id = "Vault",
		Name = "Vault",
		Description = "Jumps over the first plant, then walks normally",
		-- Logic handled in ZombieMovementSystem via CanJump flag
		-- This ability just documents the behavior
	},
	
	--[[
		Rage - Speed up when armor is destroyed
		Used by: Newspaper Zombie
		Triggered: When health drops below 50%
	]]
	Rage = {
		Id = "Rage",
		Name = "Rage",
		Description = "Becomes enraged when armor is destroyed, moving and attacking faster",
		
		OnHalfHealth = function(ctx: AbilityContext): boolean?
			-- Apply rage speed boost via RageComponent
			local Components = require(script.Parent.Parent.components)
			if Components.RageComponent then
				ctx.World:insert(ctx.EntityId, Components.RageComponent({
					SpeedMultiplier = 2.0,
					DamageMultiplier = 1.5,
					ActivatedAt = os.clock(),
				}))
			end
			return false -- Don't cancel default behavior
		end,
	},
	
	--[[
		SpawnMinions - Spawn zombies at a health threshold
		Used by: Gargantuar (spawns Imp at 50% HP)
	]]
	SpawnMinions = {
		Id = "SpawnMinions",
		Name = "Spawn Minions",
		Description = "Spawns helper zombies at half health",
		
		OnHalfHealth = function(ctx: AbilityContext): boolean?
			-- Queue an Imp spawn at the Gargantuar's position
			-- We use a component to signal the spawn system instead of spawning directly
			local Components = require(script.Parent.Parent.components)
			if Components.SpawnMinionEvent then
				ctx.World:insert(ctx.EntityId, Components.SpawnMinionEvent({
					MinionType = "Imp",
					SpawnTime = os.clock(),
				}))
			end
			return false
		end,
	},
	
	--[[
		Flying - Fly over ground obstacles
		Used by: Balloon Zombie
	]]
	Flying = {
		Id = "Flying",
		Name = "Flying",
		Description = "Flies above ground, immune to most ground-based plants",
		-- Logic handled in collision/targeting systems via IsFlying flag
	},
	
	--[[
		ShieldCarrier - Has a shield that blocks projectiles
		Used by: Screen-Door, Ladder
	]]
	ShieldCarrier = {
		Id = "ShieldCarrier",
		Name = "Shield Carrier",
		Description = "Carries a shield that blocks projectiles until destroyed",
		-- Logic handled in ProjectileHitSystem via HasShield flag
	},
	
	-- ========== SPECIAL ABILITIES (Future) ==========
	
	--[[
		Digger - Digs underground and emerges behind plants
		Used by: Digger Zombie
	]]
	Digger = {
		Id = "Digger",
		Name = "Digger",
		Description = "Digs underground to bypass defenses, emerges at the back",
		Immunities = { "Slow", "Freeze" }, -- While underground
		
		OnSpawn = function(ctx: AbilityContext): boolean?
			-- Mark as digging (underground) on spawn
			local Components = require(script.Parent.Parent.components)
			if Components.HidingComponent then
				ctx.World:insert(ctx.EntityId, Components.HidingComponent({
					HideType = "Underground",
					HiddenAt = os.clock(),
					EmergenceColumn = 1, -- Emerge at column 1 (behind plants)
				}))
			end
			return false
		end,
		
		-- OnTick is handled by a dedicated DiggerSystem for emergence logic
	},
	
	--[[
		Dolphin - Rides dolphin in water lanes
		Used by: Dolphin Rider
	]]
	Dolphin = {
		Id = "Dolphin",
		Name = "Dolphin Rider",
		Description = "Rides a dolphin in water, jumps over the first plant",
		-- Water lane specific ability
	},
	
	--[[
		Catapult - Lobs projectiles at plants from range
		Used by: Catapult Zombie
	]]
	Catapult = {
		Id = "Catapult",
		Name = "Catapult",
		Description = "Launches basketballs at plants from a distance",
		-- OnTick: Check for targets in range, lob projectile
	},
	
	--[[
		Necromancer - Revives dead zombies
		Used by: Wizard Zombie
	]]
	Necromancer = {
		Id = "Necromancer",
		Name = "Necromancer",
		Description = "Periodically revives fallen zombies",
		-- OnTick: Check for dead zombie markers, spawn new zombies
	},
	
	--[[
		Teleport - Short range teleportation
		Used by: Wizard Zombie
	]]
	Teleport = {
		Id = "Teleport",
		Name = "Teleport",
		Description = "Can teleport short distances to avoid damage",
		-- OnDamaged: Chance to teleport and avoid damage
	},
	
	--[[
		SummonTombstones - Creates obstacles on the field
		Used by: Boss Zombies
	]]
	SummonTombstones = {
		Id = "SummonTombstones",
		Name = "Summon Tombstones",
		Description = "Creates tombstones that block plant placement",
		-- OnHalfHealth or OnTick: Spawn tombstone tile modifiers
	},
	
	--[[
		Regeneration - Slowly heals over time
		Used by: Healer Zombie (future)
	]]
	Regeneration = {
		Id = "Regeneration",
		Name = "Regeneration",
		Description = "Slowly regenerates health over time",
		
		OnTick = function(ctx: AbilityContext, deltaTime: number)
			-- Heal 2% of max health per second
			local healPerSecond = ctx.MaxHealth * 0.02
			local healAmount = healPerSecond * deltaTime
			
			if ctx.CurrentHealth < ctx.MaxHealth then
				local Components = require(script.Parent.Parent.components)
				local newHealth = math.min(ctx.MaxHealth, ctx.CurrentHealth + healAmount)
				ctx.World:insert(ctx.EntityId, Components.HealthComponent({
					Current = newHealth,
					Max = ctx.MaxHealth,
				}))
			end
		end,
	},
	
	--[[
		Explode - Explodes on death dealing area damage
		Used by: Jack-in-the-Box Zombie
	]]
	Explode = {
		Id = "Explode",
		Name = "Explode",
		Description = "Explodes on death, damaging nearby plants",
		
		OnDeath = function(ctx: AbilityContext): boolean?
			-- Queue an explosion event at zombie position
			-- We use a component to signal the combat system instead of dealing damage directly
			local Components = require(script.Parent.Parent.components)
			if Components.DeathExplosionEvent then
				ctx.World:insert(ctx.EntityId, Components.DeathExplosionEvent({
					Radius = 3,
					Damage = 100,
					DamagesPlants = true,
					TriggerTime = os.clock(),
				}))
			end
			return false
		end,
	},
	
	--[[
		Steal - Steals plants instead of eating them
		Used by: Bungee Zombie
	]]
	Steal = {
		Id = "Steal",
		Name = "Steal",
		Description = "Steals plants instead of eating them",
		-- OnEat: Remove plant instantly, fly away (requires OnEat hook)
	},
}

-- ============================================
-- ZOMBIE → ABILITIES MAPPING
-- ============================================

-- Maps zombie types to their ability IDs
local ZombieAbilities: { [string]: { string } } = {
	-- Basic types (no special abilities)
	Basic = {},
	Cone = {},
	Bucket = {},
	Flag = {},
	Imp = {},
	
	-- Special behavior types
	Pole = { "Vault" },
	Newspaper = { "Rage" },
	Football = { "Immovable" },
	ScreenDoor = { "ShieldCarrier" },
	Ladder = { "ShieldCarrier" },
	Balloon = { "Flying" },
	
	-- Boss types
	Gargantuar = { "BossImmunity", "Immovable", "SpawnMinions" },
	
	-- Future types (placeholder)
	-- Zomboni = { "IcyBody", "Immovable" },
	-- JackInTheBox = { "Explode" },
	-- Digger = { "Digger" },
	-- Catapult = { "Catapult" },
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

--[[
	Get an ability by ID
]]
local function GetAbility(abilityId: string): ZombieAbility?
	return Abilities[abilityId]
end

--[[
	Get all abilities for a zombie type
]]
local function GetAbilitiesForZombie(zombieType: string): { ZombieAbility }
	local abilityIds = ZombieAbilities[zombieType] or {}
	local result = {}
	
	for _, abilityId in abilityIds do
		local ability = Abilities[abilityId]
		if ability then
			table.insert(result, ability)
		end
	end
	
	return result
end

--[[
	Get all immunities for a zombie type
]]
local function GetImmunities(zombieType: string): { ImmunityType }
	local abilities = GetAbilitiesForZombie(zombieType)
	local immunities: { ImmunityType } = {}
	local seen: { [ImmunityType]: boolean } = {}
	
	for _, ability in abilities do
		if ability.Immunities then
			for _, immunity in ability.Immunities do
				if not seen[immunity] then
					seen[immunity] = true
					table.insert(immunities, immunity)
				end
			end
		end
	end
	
	return immunities
end

--[[
	Check if a zombie type has a specific immunity
]]
local function HasImmunity(zombieType: string, immunityType: ImmunityType): boolean
	local immunities = GetImmunities(zombieType)
	
	for _, immunity in immunities do
		if immunity == immunityType then
			return true
		end
	end
	
	return false
end

--[[
	Check if a zombie type has a specific ability
]]
local function HasAbility(zombieType: string, abilityId: string): boolean
	local abilityIds = ZombieAbilities[zombieType] or {}
	
	for _, id in abilityIds do
		if id == abilityId then
			return true
		end
	end
	
	return false
end

--[[
	Execute a lifecycle hook for all abilities on a zombie
	Returns true if any ability cancelled the default behavior
]]
local function ExecuteHook(
	hookName: "OnSpawn" | "OnDamaged" | "OnHalfHealth" | "OnQuarterHealth" | "OnDeath" | "OnEat",
	zombieType: string,
	context: AbilityContext,
	extraArg: any?
): boolean
	local abilities = GetAbilitiesForZombie(zombieType)
	
	for _, ability in abilities do
		local hook = (ability :: any)[hookName]
		if hook then
			local cancelled: boolean?
			if hookName == "OnEat" then
				cancelled = hook(context, extraArg)
			else
				cancelled = hook(context)
			end
			
			if cancelled then
				return true -- Cancel default behavior
			end
		end
	end
	
	return false -- Continue with default behavior
end

--[[
	Register a new zombie type with abilities (for runtime additions)
]]
local function RegisterZombieAbilities(zombieType: string, abilityIds: { string })
	ZombieAbilities[zombieType] = abilityIds
end

-- ============================================
-- EXPORT
-- ============================================

table.freeze(Abilities)

return {
	-- Types
	Abilities = Abilities,
	ZombieAbilities = ZombieAbilities,
	
	-- Ability access
	GetAbility = GetAbility,
	GetAbilitiesForZombie = GetAbilitiesForZombie,
	
	-- Immunity system
	GetImmunities = GetImmunities,
	HasImmunity = HasImmunity,
	HasAbility = HasAbility,
	
	-- Hook execution
	ExecuteHook = ExecuteHook,
	
	-- Runtime registration
	RegisterZombieAbilities = RegisterZombieAbilities,
}
