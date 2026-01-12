--!strict
--[[
	CoinCounter.luau - Displays player's coin balance with "Toon Pop" style (Responsive)
	
	Molecule component that shows the player's permanent currency (coins).
	Connects to PlayerDataClient for reactive coin updates.
	
	Visual: Compact rounded container with coin icon + text
	
	Fully responsive using Scale-based sizing.
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Path: client/ui/components/molecules/CoinCounter.luau
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local PlayerDataClient = require(Modules.PlayerDataClient)

-- Fusion 0.3 primitives
local Children = Fusion.Children

-- Colors
local Colors = {
	Background = Color3.fromRGB(60, 50, 70),     -- Dark purple/grey
	Icon = Color3.fromRGB(255, 215, 0),          -- Gold
	Text = Color3.fromRGB(255, 255, 255),        -- White text
	Stroke = Color3.fromRGB(40, 35, 50),         -- Dark stroke
}

export type CoinCounterProps = {
	Scope: Fusion.Scope<any>,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

--[[
	CoinCounter Component (Responsive)
	
	Displays the player's coin balance in a compact container.
	Automatically subscribes to PlayerDataClient coins.
	
	@param props CoinCounterProps
	@return Frame
]]
local function CoinCounter(props: CoinCounterProps): Frame
	local scope = props.Scope
	
	-- Get reactive coins value from PlayerDataClient
	local coinsValue = PlayerDataClient.GetCoinsValue()
	
	-- Computed coin text with formatting
	local coinText = scope:Computed(function(use): string
		local coins = use(coinsValue)
		
		-- Format large numbers
		if coins >= 1000000 then
			return string.format("%.1fM", coins / 1000000)
		elseif coins >= 10000 then
			return string.format("%.0fK", coins / 1000)
		elseif coins >= 1000 then
			return string.format("%.1fK", coins / 1000)
		end
		return tostring(coins)
	end)
	
	return scope:New("Frame") {
		Name = "CoinCounter",
		Position = props.Position or UDim2.fromScale(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Size = UDim2.fromScale(0.08, 1), -- 8% width of screen, full height of parent
		BackgroundColor3 = Colors.Background,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Size constraints
			scope:New("UISizeConstraint") {
				MinSize = Vector2.new(70, 32),
				MaxSize = Vector2.new(120, 50),
			},
			
			-- Rounded corners
			scope:New("UICorner") {
				CornerRadius = UDim.new(0.3, 0),
			},
			
			-- Stroke
			scope:New("UIStroke") {
				Color = Colors.Stroke,
				Thickness = 2,
			},
			
			-- Padding
			scope:New("UIPadding") {
				PaddingLeft = UDim.new(0.08, 0),
				PaddingRight = UDim.new(0.08, 0),
			},
			
			-- Coin icon (left)
			scope:New("TextLabel") {
				Name = "CoinIcon",
				Size = UDim2.fromScale(0.35, 0.8),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = "👛",
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				
				[Children] = {
					scope:New("UITextSizeConstraint") {
						MaxTextSize = 20,
						MinTextSize = 10,
					},
				},
			},
			
			-- Coin amount text
			scope:New("TextLabel") {
				Name = "CoinAmount",
				Size = UDim2.fromScale(0.55, 0.8),
				Position = UDim2.fromScale(0.4, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = coinText,
				TextColor3 = Colors.Text,
				TextStrokeColor3 = Colors.Stroke,
				TextStrokeTransparency = 0.5,
				Font = Theme.Typography.Fonts.Title,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				
				[Children] = {
					scope:New("UITextSizeConstraint") {
						MaxTextSize = 18,
						MinTextSize = 10,
					},
				},
			},
		},
	}
end

return CoinCounter
