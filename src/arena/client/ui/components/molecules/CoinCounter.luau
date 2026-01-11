--!strict
--[[
	CoinCounter.luau - Displays player's coin balance with "Toon Pop" style
	
	Molecule component that shows the player's permanent currency (coins).
	Connects to PlayerDataClient for reactive coin updates.
	
	Visual: Compact rounded container with coin icon + text
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Path: client/ui/components/molecules/CoinCounter.luau
local Client = script.Parent.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local PlayerDataClient = require(Modules.PlayerDataClient)

local Design = script.Parent.Parent.Parent.design
local Theme = require(Design.Theme)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed

-- Constants
local ICON_SIZE = 24
local CONTAINER_WIDTH = 90  -- Fixed width to match SunCounter
local CONTAINER_HEIGHT = 40
local CONTAINER_PADDING = 6

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
	CoinCounter Component
	
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
	local coinText = Computed(scope, function(use): string
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
	
	return New(scope, "Frame") {
		Name = "CoinCounter",
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Size = UDim2.fromOffset(CONTAINER_WIDTH, CONTAINER_HEIGHT),
		BackgroundColor3 = Colors.Background,
		LayoutOrder = props.LayoutOrder or 0,
		
		[Children] = {
			-- Rounded corners
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 10),
			},
			
			-- Stroke
			New(scope, "UIStroke") {
				Color = Colors.Stroke,
				Thickness = 2,
			},
			
			-- Coin icon (left)
			New(scope, "TextLabel") {
				Name = "CoinIcon",
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				Position = UDim2.new(0, CONTAINER_PADDING, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = "👛",
				TextSize = 18,
				Font = Enum.Font.GothamBold,
			},
			
			-- Coin amount text
			New(scope, "TextLabel") {
				Name = "CoinAmount",
				Size = UDim2.new(1, -ICON_SIZE - CONTAINER_PADDING * 2, 1, 0),
				Position = UDim2.new(0, ICON_SIZE + CONTAINER_PADDING, 0, 0),
				BackgroundTransparency = 1,
				Text = coinText,
				TextColor3 = Colors.Text,
				TextStrokeColor3 = Colors.Stroke,
				TextStrokeTransparency = 0.5,
				Font = Theme.Typography.Fonts.Title,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			},
		},
	}
end

return CoinCounter
