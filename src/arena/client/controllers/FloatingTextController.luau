--!strict
--[[
	FloatingTextController.luau - Manages floating text display
	
	Controller that handles:
	- Creating floating texts for damage, sun, coins, heals
	- Animating all active floating texts
	- Listening to GameSignals for automatic display
	- Cleanup on dispose
	
	Follows Atomic Design: Controller uses FloatingText atom.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local GameSignals = require(Shared.signals.GameSignals)

local Atoms = script.Parent.Parent.ui.components.atoms
local FloatingText = require(Atoms.FloatingText)

-- Types
type FloatingTextData = FloatingText.FloatingTextData

-- Configuration
local CONFIG = {
	CRIT_THRESHOLD = 50,  -- Damage above this uses crit styling
	COIN_ICON = "🪙",
}

-- Map damage types to styles
local DAMAGE_TYPE_STYLES = {
	Normal = "Damage",
	Fire = "DamageFire",
	Ice = "DamageIce",
	Lightning = "DamageLightning",
	Poison = "DamagePoison",
	Splash = "DamageSplash",
}

-- Module state
local _activeTexts: {FloatingTextData} = {}
local _trove = Trove.new()
local _initialized = false

local FloatingTextController = {}

--[[
	Initialize the controller
	Sets up RenderStepped loop and signal listeners
]]
function FloatingTextController.Initialize()
	if _initialized then
		Logger.Warn("FloatingTextController", "Already initialized")
		return
	end
	_initialized = true
	
	-- Update loop for animating floating texts
	_trove:Connect(RunService.RenderStepped, function(_dt)
		FloatingTextController._Update()
	end)
	
	-- Connect to combat signals
	_trove:Connect(GameSignals.OnDamageDealt, function(data)
		local damageType = data.DamageType or "Normal"
		FloatingTextController.ShowDamage(data.Position, data.Amount, damageType)
	end)
	
	Logger.Info("FloatingTextController", "Initialized")
end

--[[
	Update all active floating texts
	Called every frame
]]
function FloatingTextController._Update()
	local currentTime = tick()
	local toRemove: {number} = {}
	
	for i, ft in _activeTexts do
		local elapsed = currentTime - ft.StartTime
		local progress = elapsed / ft.Duration
		
		if progress >= 1 then
			toRemove = Sift.Array.push(toRemove, i)
			FloatingText.Destroy(ft)
		else
			FloatingText.UpdateAnimation(ft, elapsed, progress)
		end
	end
	
	-- Remove completed texts (reverse order to maintain indices)
	for i = #toRemove, 1, -1 do
		_activeTexts = Sift.Array.removeIndex(_activeTexts, toRemove[i])
	end
end

--[[
	Show damage number at position
	
	@param position Vector3 - World position
	@param damage number - Damage amount
	@param damageType string? - Type of damage for coloring (Normal, Fire, Ice, etc.)
]]
function FloatingTextController.ShowDamage(position: Vector3, damage: number, damageType: string?)
	local isCrit = damage >= CONFIG.CRIT_THRESHOLD
	
	-- Get style based on damage type, defaulting to normal Damage
	local styleName = DAMAGE_TYPE_STYLES[damageType or "Normal"] or "Damage"
	local style = FloatingText.Styles[styleName] or FloatingText.Styles.Damage
	
	-- Override with crit style for very high damage (unless already special type)
	if isCrit and damageType == "Normal" then
		style = FloatingText.Styles.DamageCrit
	end
	
	local text = tostring(math.floor(damage))
	
	local ft = FloatingText.Create(position, text, style)
	_activeTexts = Sift.Array.push(_activeTexts, ft)
end

--[[
	Show sun collection text
	
	@param position Vector3 - World position
	@param amount number - Sun amount collected
]]
function FloatingTextController.ShowSunCollect(position: Vector3, amount: number)
	local text = `+{amount}`
	local ft = FloatingText.Create(position, text, FloatingText.Styles.Sun)
	_activeTexts = Sift.Array.push(_activeTexts, ft)
end

--[[
	Show coin gain text
	
	@param position Vector3 - World position  
	@param amount number - Coins gained
]]
function FloatingTextController.ShowCoinGain(position: Vector3, amount: number)
	local text = `+{amount} {CONFIG.COIN_ICON}`
	local ft = FloatingText.Create(position, text, FloatingText.Styles.Coin)
	_activeTexts = Sift.Array.push(_activeTexts, ft)
end

--[[
	Show heal amount text
	
	@param position Vector3 - World position
	@param amount number - Heal amount
]]
function FloatingTextController.ShowHeal(position: Vector3, amount: number)
	local text = `+{amount}`
	local ft = FloatingText.Create(position, text, FloatingText.Styles.Heal)
	_activeTexts = Sift.Array.push(_activeTexts, ft)
end

--[[
	Show custom text with custom color
	
	@param position Vector3 - World position
	@param text string - Text to display
	@param color Color3 - Text color
]]
function FloatingTextController.ShowText(position: Vector3, text: string, color: Color3)
	local customStyle = {
		Color = color,
		FontSize = 24,
		IsBig = false,
	}
	local ft = FloatingText.Create(position, text, customStyle)
	_activeTexts = Sift.Array.push(_activeTexts, ft)
end

--[[
	Dispose the controller
	Cleans up connections and all active floating texts
]]
function FloatingTextController.Dispose()
	Logger.Info("FloatingTextController", "Disposing...")
	_trove:Clean()
	
	-- Destroy all remaining floating texts
	for _, ft in _activeTexts do
		FloatingText.Destroy(ft)
	end
	_activeTexts = {}
	_initialized = false
end

return FloatingTextController
