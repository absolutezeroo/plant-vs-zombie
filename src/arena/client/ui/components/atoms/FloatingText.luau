--!strict
--[[
	FloatingText.luau - Floating text display atom
	
	Creates a BillboardGui with animated text for damage numbers,
	sun collection, coin gains, etc.
	
	This is a procedural atom (not Fusion reactive) for performance
	since we create/destroy many of these rapidly.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Types
export type FloatingTextData = {
	Gui: BillboardGui,
	Label: TextLabel,
	Anchor: Part,
	StartTime: number,
	Duration: number,
	StartY: number,
	RiseSpeed: number,
}

export type FloatingTextStyle = {
	Color: Color3,
	FontSize: number,
	IsBig: boolean,
}

-- Preset styles
local Styles = {
	Damage = {
		Color = Color3.fromRGB(255, 80, 80), -- Red
		FontSize = 24,
		IsBig = false,
	},
	DamageCrit = {
		Color = Color3.fromRGB(255, 50, 255), -- Purple
		FontSize = 36,
		IsBig = true,
	},
	-- Damage type styles for mutations
	DamageFire = {
		Color = Color3.fromRGB(255, 140, 50), -- Orange
		FontSize = 26,
		IsBig = false,
	},
	DamageIce = {
		Color = Color3.fromRGB(100, 200, 255), -- Cyan
		FontSize = 26,
		IsBig = false,
	},
	DamageLightning = {
		Color = Color3.fromRGB(255, 255, 100), -- Yellow electric
		FontSize = 26,
		IsBig = false,
	},
	DamagePoison = {
		Color = Color3.fromRGB(100, 200, 100), -- Toxic green
		FontSize = 26,
		IsBig = false,
	},
	DamageSplash = {
		Color = Color3.fromRGB(200, 100, 255), -- Splash purple
		FontSize = 24,
		IsBig = false,
	},
	Sun = {
		Color = Color3.fromRGB(255, 220, 50), -- Yellow
		FontSize = 24,
		IsBig = false,
	},
	Coin = {
		Color = Color3.fromRGB(255, 200, 50), -- Gold
		FontSize = 24,
		IsBig = false,
	},
	Heal = {
		Color = Color3.fromRGB(100, 255, 100), -- Green
		FontSize = 24,
		IsBig = false,
	},
}

local FloatingText = {}
FloatingText.Styles = Styles

-- Constants
local DEFAULT_DURATION = 1.0
local DEFAULT_RISE_SPEED = 3

--[[
	Create a floating text at the given world position
	
	@param worldPosition Vector3 - Where to spawn the text
	@param text string - Text to display
	@param style FloatingTextStyle - Visual style
	@param duration number? - How long to display (default 1.0)
	@return FloatingTextData
]]
function FloatingText.Create(
	worldPosition: Vector3,
	text: string,
	style: FloatingTextStyle,
	duration: number?
): FloatingTextData
	local actualDuration = duration or DEFAULT_DURATION

	-- Create anchor part (invisible, just for positioning)
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

	-- Create BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatingText"
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(100, 40)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 100
	gui.Parent = anchor

	-- Create text label
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = style.Color
	label.TextSize = style.FontSize
	label.Font = Theme.Typography.Fonts.Title
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	return {
		Gui = gui,
		Label = label,
		Anchor = anchor,
		StartTime = tick(),
		Duration = actualDuration,
		StartY = 0,
		RiseSpeed = DEFAULT_RISE_SPEED,
	}
end

--[[
	Update the floating text animation
	
	@param data FloatingTextData
	@param progress number - 0 to 1 animation progress
]]
function FloatingText.UpdateAnimation(data: FloatingTextData, elapsed: number, progress: number)
	local yOffset = data.StartY + data.RiseSpeed * elapsed

	-- Ease out the fade
	local fadeAlpha = 1 - (progress * progress)

	-- Scale effect (pop in then shrink)
	local scale: number
	if progress < 0.1 then
		scale = progress / 0.1 * 1.2 -- Pop in
	elseif progress < 0.2 then
		scale = 1.2 - (progress - 0.1) / 0.1 * 0.2 -- Settle
	else
		scale = 1 - (progress - 0.2) / 0.8 * 0.3 -- Shrink out
	end

	data.Gui.StudsOffset = Vector3.new(0, yOffset, 0)
	data.Label.TextTransparency = 1 - fadeAlpha
	data.Label.TextStrokeTransparency = 1 - fadeAlpha * 0.5
	data.Label.TextSize = math.floor(24 * scale) -- Base size * scale
end

--[[
	Destroy a floating text and its anchor
	
	@param data FloatingTextData
]]
function FloatingText.Destroy(data: FloatingTextData)
	if data.Anchor and data.Anchor.Parent then
		data.Anchor:Destroy() -- This also destroys the child BillboardGui
	end
end

return FloatingText
