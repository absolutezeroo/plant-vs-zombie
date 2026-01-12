--!strict
--[[
	CosmeticData.luau - Plant skins and cosmetics
	
	Cosmetics are purchased with GEMS only.
	They are purely visual and do not affect gameplay.
]]

export type SkinRarity = "Common" | "Rare" | "Epic" | "Legendary"

export type PlantSkin = {
	Id: string, -- Unique skin ID
	PlantType: string, -- Which plant this skin is for
	Name: string, -- Display name
	Description: string, -- Flavor text
	Rarity: SkinRarity, -- Rarity tier
	GemCost: number, -- Cost in gems

	-- Visuals
	ModelId: string?, -- Override model asset (nil = recolor only)
	PrimaryColor: Color3?, -- Primary color override
	SecondaryColor: Color3?, -- Secondary color override
	ParticleEffect: string?, -- Special particle effect ID

	-- Unlock conditions (optional)
	RequiredLevel: number?, -- Player level required to purchase
	LimitedTime: boolean?, -- Is this a limited-time skin?
}

export type TrailEffect = {
	Id: string,
	Name: string,
	Description: string,
	Rarity: SkinRarity,
	GemCost: number,
	ParticleId: string, -- Particle asset for projectile trails
	Color: Color3,
}

-- ============================================
-- PLANT SKINS
-- ============================================

local PlantSkins: { [string]: PlantSkin } = {

	-- ============================================
	-- PEASHOOTER SKINS
	-- ============================================
	peashooter_fire = {
		Id = "peashooter_fire",
		PlantType = "Peashooter",
		Name = "Pois de Feu",
		Description = "Brûle d'envie de combattre !",
		Rarity = "Rare",
		GemCost = 50,
		PrimaryColor = Color3.fromRGB(255, 100, 50),
		SecondaryColor = Color3.fromRGB(255, 200, 100),
		ParticleEffect = "fire_glow",
	},

	peashooter_ice = {
		Id = "peashooter_ice",
		PlantType = "Peashooter",
		Name = "Pois Glacé",
		Description = "Froid comme la glace.",
		Rarity = "Rare",
		GemCost = 50,
		PrimaryColor = Color3.fromRGB(100, 200, 255),
		SecondaryColor = Color3.fromRGB(200, 240, 255),
		ParticleEffect = "frost_sparkle",
	},

	peashooter_golden = {
		Id = "peashooter_golden",
		PlantType = "Peashooter",
		Name = "Pois Doré",
		Description = "Pour les vrais champions.",
		Rarity = "Legendary",
		GemCost = 200,
		PrimaryColor = Color3.fromRGB(255, 215, 0),
		SecondaryColor = Color3.fromRGB(255, 240, 150),
		ParticleEffect = "gold_sparkle",
		RequiredLevel = 25,
	},

	peashooter_shadow = {
		Id = "peashooter_shadow",
		PlantType = "Peashooter",
		Name = "Pois de l'Ombre",
		Description = "Né dans les ténèbres.",
		Rarity = "Epic",
		GemCost = 100,
		PrimaryColor = Color3.fromRGB(50, 30, 80),
		SecondaryColor = Color3.fromRGB(100, 50, 150),
		ParticleEffect = "shadow_mist",
	},

	-- ============================================
	-- SUNFLOWER SKINS
	-- ============================================
	sunflower_moonflower = {
		Id = "sunflower_moonflower",
		PlantType = "Sunflower",
		Name = "Fleur de Lune",
		Description = "Brille sous les étoiles.",
		Rarity = "Epic",
		GemCost = 100,
		PrimaryColor = Color3.fromRGB(150, 100, 255),
		SecondaryColor = Color3.fromRGB(50, 50, 100),
		ParticleEffect = "moon_glow",
	},

	sunflower_rainbow = {
		Id = "sunflower_rainbow",
		PlantType = "Sunflower",
		Name = "Arc-en-Ciel",
		Description = "Toutes les couleurs du bonheur !",
		Rarity = "Legendary",
		GemCost = 200,
		ParticleEffect = "rainbow_sparkle",
		RequiredLevel = 20,
	},

	sunflower_cherry = {
		Id = "sunflower_cherry",
		PlantType = "Sunflower",
		Name = "Fleur de Cerisier",
		Description = "Beauté printanière.",
		Rarity = "Rare",
		GemCost = 50,
		PrimaryColor = Color3.fromRGB(255, 180, 200),
		SecondaryColor = Color3.fromRGB(255, 100, 150),
	},

	-- ============================================
	-- WALL-NUT SKINS
	-- ============================================
	wallnut_steel = {
		Id = "wallnut_steel",
		PlantType = "WallNut",
		Name = "Noix d'Acier",
		Description = "Incassable.",
		Rarity = "Epic",
		GemCost = 100,
		PrimaryColor = Color3.fromRGB(150, 150, 170),
		SecondaryColor = Color3.fromRGB(100, 100, 120),
		ParticleEffect = "metal_shine",
	},

	wallnut_diamond = {
		Id = "wallnut_diamond",
		PlantType = "WallNut",
		Name = "Noix de Diamant",
		Description = "La défense ultime.",
		Rarity = "Legendary",
		GemCost = 250,
		PrimaryColor = Color3.fromRGB(150, 220, 255),
		SecondaryColor = Color3.fromRGB(255, 255, 255),
		ParticleEffect = "diamond_sparkle",
		RequiredLevel = 30,
	},

	wallnut_pumpkin = {
		Id = "wallnut_pumpkin",
		PlantType = "WallNut",
		Name = "Citrouille",
		Description = "Effrayant mais protecteur.",
		Rarity = "Rare",
		GemCost = 50,
		PrimaryColor = Color3.fromRGB(255, 150, 50),
		SecondaryColor = Color3.fromRGB(50, 100, 50),
		LimitedTime = true, -- Halloween special
	},

	-- ============================================
	-- REPEATER SKINS
	-- ============================================
	repeater_cyber = {
		Id = "repeater_cyber",
		PlantType = "Repeater",
		Name = "Cyber Pois",
		Description = "Technologie du futur.",
		Rarity = "Epic",
		GemCost = 120,
		PrimaryColor = Color3.fromRGB(0, 255, 200),
		SecondaryColor = Color3.fromRGB(0, 100, 150),
		ParticleEffect = "cyber_glow",
	},

	-- ============================================
	-- SNOW PEA SKINS
	-- ============================================
	snowpea_blizzard = {
		Id = "snowpea_blizzard",
		PlantType = "SnowPea",
		Name = "Tempête de Neige",
		Description = "Le froid absolu.",
		Rarity = "Epic",
		GemCost = 100,
		PrimaryColor = Color3.fromRGB(200, 230, 255),
		SecondaryColor = Color3.fromRGB(255, 255, 255),
		ParticleEffect = "blizzard_swirl",
	},

	-- ============================================
	-- CHERRY BOMB SKINS
	-- ============================================
	cherrybomb_nuke = {
		Id = "cherrybomb_nuke",
		PlantType = "CherryBomb",
		Name = "Bombe Nucléaire",
		Description = "BOOM !",
		Rarity = "Legendary",
		GemCost = 200,
		PrimaryColor = Color3.fromRGB(100, 255, 100),
		SecondaryColor = Color3.fromRGB(255, 255, 0),
		ParticleEffect = "radiation_glow",
		RequiredLevel = 35,
	},
}

-- ============================================
-- PROJECTILE TRAILS
-- ============================================

local ProjectileTrails: { [string]: TrailEffect } = {
	trail_fire = {
		Id = "trail_fire",
		Name = "Traînée de Feu",
		Description = "Laisse une traînée enflammée.",
		Rarity = "Rare",
		GemCost = 75,
		ParticleId = "fire_trail",
		Color = Color3.fromRGB(255, 150, 50),
	},

	trail_ice = {
		Id = "trail_ice",
		Name = "Traînée de Glace",
		Description = "Cristaux de glace scintillants.",
		Rarity = "Rare",
		GemCost = 75,
		ParticleId = "ice_trail",
		Color = Color3.fromRGB(150, 220, 255),
	},

	trail_rainbow = {
		Id = "trail_rainbow",
		Name = "Traînée Arc-en-Ciel",
		Description = "Toutes les couleurs !",
		Rarity = "Epic",
		GemCost = 150,
		ParticleId = "rainbow_trail",
		Color = Color3.fromRGB(255, 255, 255),
	},

	trail_shadow = {
		Id = "trail_shadow",
		Name = "Traînée d'Ombre",
		Description = "L'obscurité suit chaque tir.",
		Rarity = "Epic",
		GemCost = 150,
		ParticleId = "shadow_trail",
		Color = Color3.fromRGB(50, 30, 80),
	},

	trail_gold = {
		Id = "trail_gold",
		Name = "Traînée Dorée",
		Description = "Pour les champions.",
		Rarity = "Legendary",
		GemCost = 300,
		ParticleId = "gold_trail",
		Color = Color3.fromRGB(255, 215, 0),
	},
}

-- ============================================
-- RARITY COLORS (for UI)
-- ============================================

local RarityColors: { [SkinRarity]: Color3 } = {
	Common = Color3.fromRGB(150, 150, 150),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 180, 50),
}

-- ============================================
-- API
-- ============================================

local CosmeticData = {}

-- Get all skins for a specific plant
function CosmeticData.GetSkinsForPlant(plantType: string): { PlantSkin }
	local result: { PlantSkin } = {}
	for _, skin in PlantSkins do
		if skin.PlantType == plantType then
			table.insert(result, skin)
		end
	end
	table.sort(result, function(a, b)
		return a.GemCost < b.GemCost
	end)
	return result
end

-- Get a specific skin
function CosmeticData.GetSkin(skinId: string): PlantSkin?
	return PlantSkins[skinId]
end

-- Get all skins
function CosmeticData.GetAllSkins(): { PlantSkin }
	local result: { PlantSkin } = {}
	for _, skin in PlantSkins do
		table.insert(result, skin)
	end
	return result
end

-- Get all trails
function CosmeticData.GetAllTrails(): { TrailEffect }
	local result: { TrailEffect } = {}
	for _, trail in ProjectileTrails do
		table.insert(result, trail)
	end
	return result
end

-- Get a specific trail
function CosmeticData.GetTrail(trailId: string): TrailEffect?
	return ProjectileTrails[trailId]
end

-- Get rarity color
function CosmeticData.GetRarityColor(rarity: SkinRarity): Color3
	return RarityColors[rarity] or RarityColors.Common
end

-- Check if player can purchase (level requirement)
function CosmeticData.CanPurchase(skinId: string, playerLevel: number): boolean
	local skin = PlantSkins[skinId]
	if not skin then
		return false
	end
	if skin.RequiredLevel and playerLevel < skin.RequiredLevel then
		return false
	end
	return true
end

return table.freeze(CosmeticData)
