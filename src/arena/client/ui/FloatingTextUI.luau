--!strict
--[[
	FloatingTextUI.luau - Floating damage/collect text system
	
	Displays floating text in the 3D world:
	- Damage numbers on zombies
	- +Sun on sun collection
	- +Coin on zombie kill
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- UI Components
local PvZTheme = require(ReplicatedStorage.Shared.ui.PvZTheme)

-- Active floating texts
type FloatingText = {
	Gui: BillboardGui,
	Label: TextLabel,
	StartTime: number,
	Duration: number,
	StartY: number,
	RiseSpeed: number,
}

local _floatingTexts: {FloatingText} = {}
local _scope = Fusion.scoped({})
local _trove = Trove.new()

local FloatingTextUI = {}

-- Configuration
local CONFIG = {
	DAMAGE_COLOR = Color3.fromRGB(255, 80, 80),       -- Red
	DAMAGE_CRIT_COLOR = Color3.fromRGB(255, 50, 255), -- Purple for big hits
	SUN_COLOR = Color3.fromRGB(255, 220, 50),         -- Yellow
	COIN_COLOR = Color3.fromRGB(255, 200, 50),        -- Gold
	HEAL_COLOR = Color3.fromRGB(100, 255, 100),       -- Green
	
	DURATION = 1.0,
	RISE_SPEED = 3,
	FONT_SIZE = 24,
	CRIT_THRESHOLD = 50, -- Damage above this uses crit styling
}

function FloatingTextUI.Initialize()
	-- Update loop for animating floating texts
	_trove:Connect(RunService.RenderStepped, function(dt)
		FloatingTextUI._Update(dt)
	end)
	Logger.Info("FloatingTextUI", "Initialized")
end

function FloatingTextUI._Update(dt: number)
	local currentTime = tick()
	local toRemove: {number} = {}
	
	for i, ft in _floatingTexts do
		local elapsed = currentTime - ft.StartTime
		local progress = elapsed / ft.Duration
		
		if progress >= 1 then
			toRemove = Sift.Array.push(toRemove, i)
			ft.Gui:Destroy()
		else
			-- Animate
			local yOffset = ft.StartY + ft.RiseSpeed * elapsed
			local alpha = 1 - progress
			
			-- Ease out the fade
			local fadeAlpha = 1 - (progress * progress)
			
			-- Scale effect (pop in then shrink)
			local scale = if progress < 0.1 
				then progress / 0.1 * 1.2  -- Pop in
				elseif progress < 0.2 
				then 1.2 - (progress - 0.1) / 0.1 * 0.2  -- Settle
				else 1 - (progress - 0.2) / 0.8 * 0.3  -- Shrink out
			
			ft.Gui.StudsOffset = Vector3.new(0, yOffset, 0)
			ft.Label.TextTransparency = 1 - fadeAlpha
			ft.Label.TextStrokeTransparency = 1 - fadeAlpha * 0.5
			ft.Label.TextSize = math.floor(CONFIG.FONT_SIZE * scale)
		end
	end
	
	-- Remove completed texts (reverse order to maintain indices)
	for i = #toRemove, 1, -1 do
		_floatingTexts = Sift.Array.removeIndex(_floatingTexts, toRemove[i])
	end
end

local function createFloatingText(
	worldPosition: Vector3,
	text: string,
	color: Color3,
	isBig: boolean?
): FloatingText
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatingText"
	gui.Adornee = nil -- Will be positioned manually
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(100, 40)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 100
	
	-- Create anchor part
	local anchor = Instance.new("Part")
	anchor.Name = "FloatingTextAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = worldPosition
	anchor.Parent = Workspace
	
	gui.Adornee = anchor
	
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = if isBig then CONFIG.FONT_SIZE * 1.5 else CONFIG.FONT_SIZE
	label.Font = Enum.Font.GothamBold
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	
	gui.Parent = anchor
	
	-- Schedule anchor cleanup
	task.delay(CONFIG.DURATION + 0.1, function()
		anchor:Destroy()
	end)
	
	return {
		Gui = gui,
		Label = label,
		StartTime = tick(),
		Duration = CONFIG.DURATION,
		StartY = 0,
		RiseSpeed = CONFIG.RISE_SPEED,
	}
end

-- Show damage number at position
function FloatingTextUI.ShowDamage(position: Vector3, damage: number)
	local isCrit = damage >= CONFIG.CRIT_THRESHOLD
	local color = if isCrit then CONFIG.DAMAGE_CRIT_COLOR else CONFIG.DAMAGE_COLOR
	local text = tostring(math.floor(damage))
	
	local ft = createFloatingText(position, text, color, isCrit)
	_floatingTexts = Sift.Array.push(_floatingTexts, ft)
end

-- Show sun collection
function FloatingTextUI.ShowSunCollect(position: Vector3, amount: number)
	local text = `+{amount}`
	local ft = createFloatingText(position, text, CONFIG.SUN_COLOR, false)
	_floatingTexts = Sift.Array.push(_floatingTexts, ft)
end

-- Show coin gain
function FloatingTextUI.ShowCoinGain(position: Vector3, amount: number)
	local text = `+{amount} {PvZTheme.Icons.Coin}`
	local ft = createFloatingText(position, text, CONFIG.COIN_COLOR, false)
	_floatingTexts = Sift.Array.push(_floatingTexts, ft)
end

-- Show heal amount
function FloatingTextUI.ShowHeal(position: Vector3, amount: number)
	local text = `+{amount}`
	local ft = createFloatingText(position, text, CONFIG.HEAL_COLOR, false)
	_floatingTexts = Sift.Array.push(_floatingTexts, ft)
end

-- Show custom text
function FloatingTextUI.ShowText(position: Vector3, text: string, color: Color3)
	local ft = createFloatingText(position, text, color, false)
	_floatingTexts = Sift.Array.push(_floatingTexts, ft)
end

-- Dispose: Clean up connections and floating texts
function FloatingTextUI.Dispose()
	Logger.Info("FloatingTextUI", "Disposing...")
	_trove:Clean()
	
	-- Destroy all remaining floating texts
	for _, ft in _floatingTexts do
		ft.Gui:Destroy()
	end
	_floatingTexts = {}
end

return FloatingTextUI
