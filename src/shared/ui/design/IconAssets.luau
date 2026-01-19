--!strict
--[[
	IconAssets.luau - Centralized image asset IDs for UI icons
	
	USAGE:
	1. Upload your images to Roblox (Game Settings > Assets or via Asset Manager)
	2. Replace the placeholder IDs below with your actual rbxassetid:// URLs
	3. Use IconAssets.Get("IconName") in your UI components
	
	EXAMPLE:
		local IconAssets = require(Shared.ui.design.IconAssets)
		
		-- In Fusion component:
		New "ImageLabel" {
			Image = IconAssets.Get("Sun"),
			Size = UDim2.fromOffset(32, 32),
		}
]]

export type IconName = "Sun"
	-- Currency & Resources
	| "Coin"
	| "Gem"
	| "XP"
	| "Star"
	| "StarEmpty"
	-- UI Actions
	| "Lock"
	| "Check"
	| "Close"
	| "Back"
	| "Play"
	| "Shovel"
	| "PlantFood"
	| "Pointer"
	| "Search"
	-- Navigation
	| "Shop"
	| "Deck"
	| "Profile"
	| "Mutation"
	| "Settings"
	-- Mutations (Elements)
	| "Fire"
	| "Ice"
	| "Electric"
	| "Solar"
	| "Shadow"
	| "Armor"
	| "Poison"
	-- Game State
	| "Skull"
	| "Trophy"
	| "Heart"
	| "Shield"
	-- Entities
	| "Plant"
	| "Zombie"
	| "Seedling"
	| "Herb"
	-- Game Objects
	| "Base"
	| "Flag"
	-- World Icons
	| "DayWorld"
	| "NightWorld"
	| "BossWorld"

-- ============================================================
-- ASSET IDS - Replace these with your uploaded image IDs
-- ============================================================
-- Format: "rbxassetid://123456789"
-- To get asset ID: Upload image in Roblox Studio > Copy Asset ID

local ASSETS: { [IconName]: string } = {
	-- Currency & Resources
	Sun = "rbxassetid://0", -- TODO: Replace with sun icon
	Coin = "rbxassetid://91503104881376",
	Gem = "rbxassetid://101914949300245",
	XP = "rbxassetid://0", -- TODO: Replace with XP/experience icon
	Star = "rbxassetid://110437804922110",
	StarEmpty = "rbxassetid://0", -- TODO: Replace with empty star outline
	
	-- UI Actions
	Lock = "rbxassetid://87495587168402",
    Unlock = "rbxassetid://99930359231386",
	Check = "rbxassetid://72905064504250",
	Close = "rbxassetid://131395839901726",
	Back = "rbxassetid://0", -- TODO: Replace with back arrow icon
	Play = "rbxassetid://0", -- TODO: Replace with play button icon
	Shovel = "rbxassetid://116992508842967",
	PlantFood = "rbxassetid://0", -- TODO: Replace with plant food icon
	Pointer = "rbxassetid://88537343179981",
	Search = "rbxassetid://0", -- TODO: Replace with magnifying glass icon
	
	-- Navigation
	Shop = "rbxassetid://118391791840897",
	Deck = "rbxassetid://0", -- TODO: Replace with deck/cards icon
	Profile = "rbxassetid://110361201630423",
	Mutation = "rbxassetid://0", -- TODO: Replace with DNA/mutation icon
	Settings = "rbxassetid://0", -- TODO: Replace with gear/settings icon
	
	-- Mutations (Elements)
	Fire = "rbxassetid://0", -- TODO: Replace with fire/flame icon
	Ice = "rbxassetid://0", -- TODO: Replace with ice/snowflake icon
	Electric = "rbxassetid://101955885142473",
	Solar = "rbxassetid://0", -- TODO: Replace with sun rays icon
	Shadow = "rbxassetid://0", -- TODO: Replace with shadow/dark icon
	Armor = "rbxassetid://78513424205591",
	Poison = "rbxassetid://0", -- TODO: Replace with poison/skull icon
	
	-- Game State
	Skull = "rbxassetid://71826897653619",
	Trophy = "rbxassetid://99141582413139",
	Heart = "rbxassetid://111059481508710",
	Shield = "rbxassetid://78513424205591",
	
	-- Entities
	Plant = "rbxassetid://0", -- TODO: Replace with plant/seedling icon
	Zombie = "rbxassetid://0", -- TODO: Replace with zombie icon
	Seedling = "rbxassetid://0", -- TODO: Replace with small seedling icon
	Herb = "rbxassetid://97546540279147",
	
	-- Game Objects
	Base = "rbxassetid://121415191452000",
	Flag = "rbxassetid://0", -- TODO: Replace with flag icon
	
	-- World Icons
	DayWorld = "rbxassetid://0", -- TODO: Replace with sunny day icon
	NightWorld = "rbxassetid://0", -- TODO: Replace with moon/night icon
	BossWorld = "rbxassetid://71826897653619",
}

-- ============================================================
-- FALLBACK EMOJIS (used when image not yet uploaded)
-- ============================================================
local FALLBACK_EMOJIS: { [IconName]: string } = {
	Sun = "☀️",
	Coin = "💰",
	Gem = "💎",
	XP = "⭐",
	Star = "⭐",
	StarEmpty = "☆",
	Lock = "🔒",
	Check = "✓",
	Close = "✖",
	Back = "←",
	Play = "▶",
	Shovel = "🪴",
	PlantFood = "🌟",
	Pointer = "👉",
	Search = "🔍",
	Shop = "🛒",
	Deck = "🃏",
	Profile = "👤",
	Mutation = "🧬",
	Settings = "⚙️",
	Fire = "🔥",
	Ice = "❄️",
	Electric = "⚡",
	Solar = "☀️",
	Shadow = "🌑",
	Armor = "🛡️",
	Poison = "☠️",
	Skull = "💀",
	Trophy = "🏆",
	Heart = "❤️",
	Shield = "🛡️",
	Plant = "🌱",
	Zombie = "🧟",
	Seedling = "🌱",
	Herb = "🌿",
	Base = "🏠",
	Flag = "🚩",
	DayWorld = "☀️",
	NightWorld = "🌙",
	BossWorld = "💀",
}

-- ============================================================
-- MODULE API
-- ============================================================
local IconAssets = {}

--[[
	Get the image asset ID for an icon
	Returns "rbxassetid://0" if not found (which shows nothing)
]]
function IconAssets.Get(name: IconName): string
	return ASSETS[name] or "rbxassetid://0"
end

--[[
	Get the fallback emoji for an icon (for TextLabel fallback)
]]
function IconAssets.GetEmoji(name: IconName): string
	return FALLBACK_EMOJIS[name] or "?"
end

--[[
	Check if an icon has a valid image asset (not placeholder)
]]
function IconAssets.HasImage(name: IconName): boolean
	local asset = ASSETS[name]
	return asset ~= nil and asset ~= "rbxassetid://0"
end

--[[
	Get all icon names (for debugging/iteration)
]]
function IconAssets.GetAllNames(): { IconName }
	local names: { IconName } = {}
	for name in ASSETS do
		table.insert(names, name)
	end
	return names
end

--[[
	Mutation element name to IconName mapping
]]
local MUTATION_ICON_MAP: { [string]: IconName } = {
	Fire = "Fire",
	Inferno = "Fire",
	Ice = "Ice",
	Frost = "Ice",
	Electric = "Electric",
	Lightning = "Electric",
	Solar = "Solar",
	Radiant = "Solar",
	Shadow = "Shadow",
	Void = "Shadow",
	Armor = "Armor",
	Fortress = "Armor",
	Poison = "Poison",
	Toxic = "Poison",
}

--[[
	Get icon for a mutation element (handles aliases)
]]
function IconAssets.GetMutationIcon(elementName: string): string
	local iconName = MUTATION_ICON_MAP[elementName]
	if iconName then
		return ASSETS[iconName] or "rbxassetid://0"
	end
	return "rbxassetid://0"
end

--[[
	Get emoji fallback for a mutation element
]]
function IconAssets.GetMutationEmoji(elementName: string): string
	local iconName = MUTATION_ICON_MAP[elementName]
	if iconName then
		return FALLBACK_EMOJIS[iconName] or "?"
	end
	return "?"
end

return table.freeze(IconAssets)
